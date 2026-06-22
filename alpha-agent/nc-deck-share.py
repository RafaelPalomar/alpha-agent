#!/usr/bin/env python3
"""nc-deck-share — share a NextCloud Deck board with a user.

Fills the one gap the nextcloud-mcp server leaves: it exposes board/stack/card
tools but NO board-ACL/sharing tool (and nc_share_create is the Files API, which
404s on a board).  This calls Deck's own ACL endpoint directly so Poppins can
create a board AND share it with the family.

Auth from env (same as family-cal): NC_URL, NC_USER, NC_APPPW (or NC_APPPW_FILE).

Usage:
  nc-deck-share acl   <board-id>                       # list the board's shares
  nc-deck-share share <board-id> <user> [--manage]     # add a user (edit by default)
                                       [--no-edit] [--can-share]
  nc-deck-share unshare <board-id> <acl-id>            # remove a share (by aclId)
"""

import argparse
import os
import sys

import requests

DECK = "/index.php/apps/deck/api/v1.0"
HDRS = {"OCS-APIRequest": "true", "Content-Type": "application/json"}


def creds():
    url = os.environ.get("NC_URL", "").rstrip("/")
    user = os.environ.get("NC_USER", "")
    pw = os.environ.get("NC_APPPW")
    if not pw:
        f = os.environ.get("NC_APPPW_FILE")
        if f and os.path.exists(f):
            pw = open(f).read().strip()
    if not (url and user and pw):
        sys.exit("nc-deck-share: NC_URL, NC_USER and NC_APPPW (or NC_APPPW_FILE) required")
    return url, user, pw


def main():
    ap = argparse.ArgumentParser(prog="nc-deck-share")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("acl", help="list a board's shares")
    p.add_argument("board_id", type=int)

    p = sub.add_parser("share", help="share a board with a user")
    p.add_argument("board_id", type=int)
    p.add_argument("user")
    p.add_argument("--no-edit", action="store_true", help="grant view-only (default: edit)")
    p.add_argument("--can-share", action="store_true", help="also allow them to re-share")
    p.add_argument("--manage", action="store_true", help="grant manage (create stacks etc.)")

    p = sub.add_parser("unshare", help="remove a share by aclId")
    p.add_argument("board_id", type=int)
    p.add_argument("acl_id", type=int)

    args = ap.parse_args()
    url, user, pw = creds()
    auth = (user, pw)

    if args.cmd == "acl":
        r = requests.get(f"{url}{DECK}/boards/{args.board_id}", headers=HDRS,
                         auth=auth, timeout=30)
        r.raise_for_status()
        acl = r.json().get("acl", []) or []
        if not acl:
            print("(no ACL entries — board is private to its owner)")
        for e in acl:
            who = (e.get("participant") or {}).get("uid", e.get("participant"))
            print("%-20s edit=%s share=%s manage=%s  aclId=%s"
                  % (who, e.get("permissionEdit"), e.get("permissionShare"),
                     e.get("permissionManage"), e.get("id")))
        return

    if args.cmd == "share":
        body = {"type": 0,  # 0 = user, 1 = group, 7 = circle
                "participant": args.user,
                "permissionEdit": not args.no_edit,
                "permissionShare": args.can_share,
                "permissionManage": args.manage}
        r = requests.post(f"{url}{DECK}/boards/{args.board_id}/acl", headers=HDRS,
                          auth=auth, json=body, timeout=30)
        if r.status_code >= 400:
            sys.exit("nc-deck-share: HTTP %s: %s" % (r.status_code, r.text[:300]))
        e = r.json()
        print("shared board %s with %s (edit=%s manage=%s); aclId=%s"
              % (args.board_id, args.user, body["permissionEdit"],
                 body["permissionManage"], e.get("id")))
        return

    if args.cmd == "unshare":
        r = requests.delete(f"{url}{DECK}/boards/{args.board_id}/acl/{args.acl_id}",
                            headers=HDRS, auth=auth, timeout=30)
        if r.status_code >= 400:
            sys.exit("nc-deck-share: HTTP %s: %s" % (r.status_code, r.text[:300]))
        print("removed share aclId=%s from board %s" % (args.acl_id, args.board_id))
        return


if __name__ == "__main__":
    main()
