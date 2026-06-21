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
  POPPINS_USE_SESSION         "1" (default): thread a pi --session-id per MM
                              thread so a conversation keeps context
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
POPPINS_CMD = os.environ.get("POPPINS_CMD", "poppins")
USE_SESSION = os.environ.get("POPPINS_USE_SESSION", "1") == "1"

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
                           text=True, timeout=600)
        out = (p.stdout or "").strip()
        if p.returncode != 0 and args is not base:
            log("poppins rc", p.returncode, "with session; retrying plain. stderr:",
                (p.stderr or "")[:300])
            p = subprocess.run(base, input=text, capture_output=True,
                               text=True, timeout=600)
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
        ch, root, text = WORK.get()
        try:
            reply = run_poppins(text, ("mm-" + root) if root else None)
            post(ch, reply, root)
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
    if ALLOWED and ch not in ALLOWED:
        return
    msg = (p.get("message") or "").strip()
    if not msg:
        return
    # Keep a conversation together: reply under the thread root.
    root = p.get("root_id") or p.get("id")
    WORK.put((ch, root, msg))


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
    log(f"logged in as bot {BOT_ID}; allowed channels: {ALLOWED or 'ALL'}")
    threading.Thread(target=worker, daemon=True).start()
    while True:
        try:
            ws = websocket.WebSocketApp(
                ws_url(),
                header=["Authorization: Bearer " + TOKEN],
                on_message=on_message, on_open=on_open,
                on_error=on_error, on_close=on_close)
            ws.run_forever(ping_interval=30, ping_timeout=10)
        except Exception as e:
            log("run_forever crashed:", e)
        log("reconnecting in 5s...")
        time.sleep(5)


if __name__ == "__main__":
    main()
