#!/usr/bin/env python3
"""family-cal — Poppins's household calendar tool (NextCloud CalDAV).

Read the family agenda; STAGE proposed changes to a pending area for a human to
confirm (never writes to the live calendar — the stage-don't-commit guardrail).

Config via env (all overridable by flags):
  NC_URL        default https://nextcloud.drake-karat.ts.net
  NC_USER       default rafael
  NC_CALENDAR   default family
  NC_APPPW_FILE default ~/.cache/nc-apppw   (file containing ONLY the app password)
  POPPINS_STAGE_DIR default ~/.local/share/poppins/pending
"""
import argparse, os, sys, re, datetime, pathlib, uuid
import requests
from requests.auth import HTTPBasicAuth

NC_URL   = os.environ.get("NC_URL", "https://nextcloud.drake-karat.ts.net").rstrip("/")
NC_USER  = os.environ.get("NC_USER", "rafael")
NC_CAL   = os.environ.get("NC_CALENDAR", "family")
PWFILE   = os.path.expanduser(os.environ.get("NC_APPPW_FILE", "~/.cache/nc-apppw"))
STAGEDIR = pathlib.Path(os.path.expanduser(os.environ.get("POPPINS_STAGE_DIR", "~/.local/share/poppins/pending")))

def _auth():
    # Prefer NC_APPPW (value, injected by the wrapper like OPENROUTER_API_KEY);
    # fall back to a file path (NC_APPPW_FILE).
    pw = os.environ.get("NC_APPPW", "").strip()
    if not pw:
        try:
            pw = pathlib.Path(PWFILE).read_text().strip()
        except OSError as e:
            sys.exit(f"family-cal: no NC_APPPW set and cannot read {PWFILE}: {e}")
    if not pw:
        sys.exit("family-cal: empty app password (set NC_APPPW or NC_APPPW_FILE)")
    return HTTPBasicAuth(NC_USER, pw)

def _cal_url():
    return f"{NC_URL}/remote.php/dav/calendars/{NC_USER}/{NC_CAL}/"

def _z(dt):  # CalDAV UTC stamp
    return dt.strftime("%Y%m%dT%H%M%SZ")

def agenda(days):
    start = datetime.datetime.now(datetime.timezone.utc)
    end   = start + datetime.timedelta(days=days)
    body = f'''<?xml version="1.0" encoding="utf-8"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop><c:calendar-data/></d:prop>
  <c:filter><c:comp-filter name="VCALENDAR"><c:comp-filter name="VEVENT">
    <c:time-range start="{_z(start)}" end="{_z(end)}"/>
  </c:comp-filter></c:comp-filter></c:filter>
</c:calendar-query>'''
    r = requests.request("REPORT", _cal_url(), data=body.encode(), auth=_auth(),
                         headers={"Depth": "1", "Content-Type": "application/xml"}, timeout=20)
    if r.status_code not in (207, 200):
        sys.exit(f"family-cal: calendar query failed: HTTP {r.status_code}")
    # crude but sufficient: pull SUMMARY/DTSTART out of each returned VEVENT block
    events = []
    for ev in re.findall(r"BEGIN:VEVENT.*?END:VEVENT", r.text, re.S):
        summ = re.search(r"\nSUMMARY[^:]*:(.*)", ev)
        dts  = re.search(r"\nDTSTART[^:]*:(.*)", ev)
        events.append((dts.group(1).strip() if dts else "?",
                       summ.group(1).strip() if summ else "(no title)"))
    events.sort()
    if not events:
        print(f"No events in the next {days} days on '{NC_CAL}'.")
        return
    print(f"Agenda — next {days} days ('{NC_CAL}'):")
    for when, what in events:
        print(f"  {when}  {what}")

def stage(summary, start, end, member, note):
    STAGEDIR.mkdir(parents=True, exist_ok=True)
    sid = datetime.datetime.now().strftime("%Y%m%dT%H%M%S") + "-" + uuid.uuid4().hex[:6]
    uid = sid + "@poppins"
    ics = ("BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//poppins//family-cal//EN\nBEGIN:VEVENT\n"
           f"UID:{uid}\nSUMMARY:{summary}\nDTSTART:{start}\n" + (f"DTEND:{end}\n" if end else "") +
           "END:VEVENT\nEND:VCALENDAR\n")
    (STAGEDIR / f"{sid}.ics").write_text(ics)
    (STAGEDIR / f"{sid}.txt").write_text(
        f"PROPOSED calendar change (NOT yet committed)\n"
        f"  for member : {member or '(unspecified)'}\n  summary    : {summary}\n"
        f"  start      : {start}\n  end        : {end or '(none)'}\n"
        f"  triggered  : {note or '(none)'}\n  calendar   : {NC_CAL} ({NC_USER})\n"
        f"Confirm with: family-cal commit {sid}\n")
    print(f"Staged proposal {sid} — needs human confirmation. ('family-cal commit {sid}' to apply.)")

def commit(sid):
    f = STAGEDIR / f"{sid}.ics"
    if not f.exists():
        sys.exit(f"family-cal: no staged proposal {sid}")
    r = requests.put(f"{_cal_url()}{sid}.ics", data=f.read_text().encode(), auth=_auth(),
                     headers={"Content-Type": "text/calendar"}, timeout=20)
    if r.status_code not in (201, 204):
        sys.exit(f"family-cal: commit failed: HTTP {r.status_code}")
    print(f"Committed {sid} to '{NC_CAL}'.")

def main():
    p = argparse.ArgumentParser(prog="family-cal")
    sub = p.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("agenda"); a.add_argument("--days", type=int, default=14)
    s = sub.add_parser("stage")
    s.add_argument("summary"); s.add_argument("start"); s.add_argument("end", nargs="?")
    s.add_argument("--member"); s.add_argument("--note")
    c = sub.add_parser("commit"); c.add_argument("sid")
    args = p.parse_args()
    if args.cmd == "agenda": agenda(args.days)
    elif args.cmd == "stage": stage(args.summary, args.start, args.end, args.member, args.note)
    elif args.cmd == "commit": commit(args.sid)

if __name__ == "__main__":
    main()
