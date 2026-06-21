#!/usr/bin/env python3
"""poppins-bridge — connect the pi-based Mary Poppins agent to Mattermost.

Transport only.  This daemon logs in to the family Mattermost as the
`ms-poppins' bot, listens for messages in the allowed channel(s) (the family
`#household'), and for each one shells out to `poppins -p' and posts the reply
back in-thread.  It owns NO credentials of its own beyond the Mattermost bot
token: the `poppins' wrapper it spawns injects the OpenRouter + NextCloud
secrets and runs the agent in its L1 sandbox.  Keeping the bridge dumb is the
point — the trust/data boundary lives in the agent, not the chat plumbing.

Config (environment):
  MATTERMOST_URL              base URL, e.g. http://127.0.0.1:8065
  MATTERMOST_TOKEN            ms-poppins bot personal-access token
  MATTERMOST_ALLOWED_CHANNELS comma-separated channel IDs; if empty, respond in
                              every channel the bot is a member of
  POPPINS_CMD                 the poppins launcher on PATH (default: "poppins")
  POPPINS_USE_SESSION         "1" (default): also pass a pi --session-id
  POPPINS_STM_DIR             where per-conversation transcripts live
                              (default ~/.local/share/poppins/conversations)
  POPPINS_STM_TURNS           recent turns replayed for continuity (default 16)

Short-term memory: the bridge keeps a per-conversation transcript and replays
the recent window to `poppins -p' each message (pi is stateless per call).  Chat
controls handled locally: /clear (/new) forgets the recent chat, /help lists them.
"""

import json
import os
import queue
import subprocess
import sys
import threading
import time

import requests
import websocket  # python-websocket-client


URL = os.environ["MATTERMOST_URL"].rstrip("/")
TOKEN = os.environ["MATTERMOST_TOKEN"]
ALLOWED = {c for c in os.environ.get("MATTERMOST_ALLOWED_CHANNELS", "").split(",") if c}
# MM's WS upgrader blocks any Origin != its SiteURL. We connect over loopback,
# so the Origin must be set explicitly to the SiteURL (not the connect URL).
ORIGIN = os.environ.get("MATTERMOST_ORIGIN", URL)
POPPINS_CMD = os.environ.get("POPPINS_CMD", "poppins")
USE_SESSION = os.environ.get("POPPINS_USE_SESSION", "1") == "1"
# Spawn the agent off the personal home so its cwd isn't /home/rafael.
RUNDIR = os.environ.get("POPPINS_RUNDIR", "/tmp")

# --- short-term memory (STM): a per-conversation transcript the bridge replays.
# pi is stateless per `-p' call (its config dir is wiped each time), so the
# bridge owns conversational continuity.  Held on the host, OUT of pks-personal
# so raw chat doesn't sync to NextCloud.  (Self-compact + autolog to PKS is a
# later slice; for now we just window and replay.)
STM_DIR = os.environ.get(
    "POPPINS_STM_DIR", os.path.expanduser("~/.local/share/poppins/conversations"))
STM_TURNS = int(os.environ.get("POPPINS_STM_TURNS", "16"))  # recent turns replayed
_stm_lock = threading.Lock()

HELP = ("Here's what I understand:\n"
        "• /clear (or /new) — set aside our recent chat and start fresh\n"
        "• /help — show this message\n"
        "Otherwise just talk to me normally.")


def _stm_path(ch):
    return os.path.join(STM_DIR, ch + ".json")


def stm_load(ch):
    try:
        with open(_stm_path(ch)) as f:
            return json.load(f)
    except Exception:
        return []


def stm_save(ch, turns):
    try:
        os.makedirs(STM_DIR, exist_ok=True)
        tmp = _stm_path(ch) + ".tmp"
        with open(tmp, "w") as f:
            json.dump(turns, f)
        os.replace(tmp, _stm_path(ch))
    except Exception as e:
        log("stm save failed:", e)


def stm_clear(ch):
    try:
        os.remove(_stm_path(ch))
    except FileNotFoundError:
        pass
    except Exception as e:
        log("stm clear failed:", e)


def history_block(turns):
    if not turns:
        return ""
    lines = []
    for t in turns[-STM_TURNS:]:
        who = "you" if t.get("role") == "assistant" else t.get("sender", "someone")
        lines.append("%s: %s" % (who, t.get("text", "")))
    return ("[Recent conversation in this chat, oldest first — \"you\" are your "
            "own earlier replies:]\n" + "\n".join(lines) + "\n\n")


API = URL + "/api/v4"
HDR = {"Authorization": "Bearer " + TOKEN}


def log(*a):
    print("poppins-bridge:", *a, file=sys.stderr, flush=True)


def whoami():
    r = requests.get(API + "/users/me", headers=HDR, timeout=30)
    r.raise_for_status()
    return r.json()["id"]


def post(channel_id, message, root_id=""):
    body = {"channel_id": channel_id, "message": message}
    if root_id:
        body["root_id"] = root_id
    try:
        r = requests.post(API + "/posts", headers=HDR, json=body, timeout=30)
        r.raise_for_status()
    except Exception as e:
        log("post failed:", e)


def run_poppins(text, session):
    """Run `poppins -p' on TEXT, returning its stdout.  Falls back to a
    session-less call if the launcher rejects --session-id."""
    base = [POPPINS_CMD, "-p"]
    args = base + (["--session-id", session] if (USE_SESSION and session) else [])
    try:
        p = subprocess.run(args, input=text, capture_output=True,
                           text=True, timeout=600, cwd=RUNDIR)
        out = (p.stdout or "").strip()
        if p.returncode != 0 and args is not base:
            log("poppins rc", p.returncode, "with session; retrying plain. stderr:",
                (p.stderr or "")[:300])
            p = subprocess.run(base, input=text, capture_output=True,
                               text=True, timeout=600, cwd=RUNDIR)
            out = (p.stdout or "").strip()
        if not out:
            log("poppins gave no stdout; stderr:", (p.stderr or "")[:500])
            out = "Sorry — I couldn't come up with a reply just now."
        return out
    except subprocess.TimeoutExpired:
        return "Sorry — that took too long; please try again."
    except Exception as e:
        log("poppins error:", e)
        return "Sorry — something went wrong on my end."


WORK = queue.Queue()


def worker():
    while True:
        ch, root, text, sender, ctype = WORK.get()
        try:
            where = ("a direct message" if ctype in ("D", "G")
                     else "the family #household channel")
            with _stm_lock:
                hist = history_block(stm_load(ch))
            preamble = ("(This message is from family member '%s', sent via %s. "
                        "Reply to them directly and address them by name.)\n\n"
                        % (sender, where))
            prompt = hist + preamble + sender + ": " + text
            session = (("mm-dm-" + ch) if ctype in ("D", "G")
                       else ("mm-th-" + root))
            reply = run_poppins(prompt, session if USE_SESSION else None)
            post(ch, reply, root)
            # Record both turns (cap stored history at ~2x the replay window).
            with _stm_lock:
                turns = stm_load(ch)
                turns.append({"role": "user", "sender": sender, "text": text})
                turns.append({"role": "assistant", "sender": "Mary Poppins",
                              "text": reply})
                stm_save(ch, turns[-(STM_TURNS * 2):])
            log("-> replied to %s (%d chars)" % (sender, len(reply)))
        except Exception as e:
            log("worker error:", e)
        finally:
            WORK.task_done()


def on_message(ws, raw):
    try:
        ev = json.loads(raw)
    except Exception:
        return
    if ev.get("event") != "posted":
        return
    data = ev.get("data", {})
    try:
        p = json.loads(data["post"])
    except Exception:
        return
    # Skip our own posts, system messages, and other bots (avoid loops).
    if p.get("user_id") == BOT_ID:
        return
    if str(p.get("type", "")).startswith("system_"):
        return
    if (data.get("props") or {}).get("from_bot") == "true":
        return
    if (p.get("props") or {}).get("from_bot") == "true":
        return
    ch = p.get("channel_id", "")
    ctype = data.get("channel_type", "")
    # Always answer direct ("D") and group ("G") messages; for public/private
    # channels ("O"/"P") require the allow-list (the family #household).
    if ctype not in ("D", "G") and ALLOWED and ch not in ALLOWED:
        return
    msg = (p.get("message") or "").strip()
    if not msg:
        return
    sender = data.get("sender_name") or "someone"
    # Keep a conversation together: reply under the thread root.
    root = p.get("root_id") or p.get("id")
    # Bridge-level chat controls — handled locally, never sent to the model.
    if msg.startswith("/"):
        cmd = msg.split()[0].lower()
        if cmd in ("/clear", "/new"):
            with _stm_lock:
                stm_clear(ch)
            log(f"<- [{ctype or '?'}] {sender}: {cmd} -> cleared STM")
            post(ch, "🧹 Done — I've set aside our recent chat; we can start fresh.", root)
        elif cmd == "/help":
            post(ch, HELP, root)
        else:
            post(ch, "I don't recognise that command — try /help.", root)
        return
    log(f"<- [{ctype or '?'}] {sender}: {msg[:80]}")
    WORK.put((ch, root, msg, sender, ctype))


def on_open(ws):
    # Belt and braces: header auth on the handshake AND the documented
    # authentication_challenge frame.
    ws.send(json.dumps({"seq": 1, "action": "authentication_challenge",
                        "data": {"token": TOKEN}}))
    log("websocket open; auth sent")


def on_error(ws, err):
    log("websocket error:", err)


def on_close(ws, *a):
    log("websocket closed:", a)


def ws_url():
    return URL.replace("https://", "wss://").replace("http://", "ws://") \
        + "/api/v4/websocket"


def main():
    global BOT_ID
    BOT_ID = whoami()
    os.makedirs(STM_DIR, exist_ok=True)
    log(f"logged in as bot {BOT_ID}; allowed channels: {ALLOWED or 'ALL'}; "
        f"STM window {STM_TURNS} turns at {STM_DIR}")
    threading.Thread(target=worker, daemon=True).start()
    while True:
        try:
            ws = websocket.WebSocketApp(
                ws_url(),
                header=["Authorization: Bearer " + TOKEN],
                on_message=on_message, on_open=on_open,
                on_error=on_error, on_close=on_close)
            # MM's WS upgrader blocks the handshake ("URL Blocked because of
            # CORS") unless Origin matches its SiteURL.  Set it via the origin=
            # kwarg, NOT a custom header — websocket-client otherwise auto-fills
            # Origin from the connect URL (the loopback) and that one wins.
            ws.run_forever(ping_interval=30, ping_timeout=10, origin=ORIGIN)
        except Exception as e:
            log("run_forever crashed:", e)
        log("reconnecting in 5s...")
        time.sleep(5)


if __name__ == "__main__":
    main()
