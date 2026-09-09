#!/usr/bin/env python3
"""Fetch your ESPN Fantasy Football team via ESPN's fantasy API.

Usage:
    python fetch_team.py --league-id 12345 [--year 2025] [--team-id 3]

For private leagues, set these environment variables with cookie values
copied from a logged-in Chrome session (see espn-fantasy/README.md):
    ESPN_S2  - the "espn_s2" cookie
    ESPN_SWID - the "SWID" cookie (including the curly braces)

Public leagues need no cookies.
"""

import argparse
import json
import os
import sys
import urllib.request

API_BASE = "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons"


def fetch_league(league_id: str, year: int, views: list[str]) -> dict:
    query = "&".join(f"view={v}" for v in views)
    url = f"{API_BASE}/{year}/segments/0/leagues/{league_id}?{query}"
    req = urllib.request.Request(url, headers={"Accept": "application/json"})

    espn_s2 = os.environ.get("ESPN_S2")
    swid = os.environ.get("ESPN_SWID")
    if espn_s2 and swid:
        req.add_header("Cookie", f"espn_s2={espn_s2}; SWID={swid}")

    try:
        with urllib.request.urlopen(req) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        if e.code == 401:
            sys.exit(
                "401 Unauthorized: this league is private. Set the ESPN_S2 and "
                "ESPN_SWID environment variables (see espn-fantasy/README.md)."
            )
        if e.code == 404:
            sys.exit(f"404 Not Found: no league {league_id} for season {year}.")
        raise


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--league-id", required=True, help="ESPN league ID (from the league URL)")
    parser.add_argument("--year", type=int, default=2025, help="Season year (default: 2025)")
    parser.add_argument("--team-id", type=int, help="Only show this team ID")
    args = parser.parse_args()

    data = fetch_league(args.league_id, args.year, ["mTeam", "mRoster", "mSettings"])

    league_name = data.get("settings", {}).get("name", "(unknown league)")
    print(f"League: {league_name} — season {args.year}\n")

    for team in data.get("teams", []):
        if args.team_id is not None and team.get("id") != args.team_id:
            continue
        name = team.get("name") or f"{team.get('location', '')} {team.get('nickname', '')}".strip()
        record = team.get("record", {}).get("overall", {})
        wins, losses, ties = record.get("wins", 0), record.get("losses", 0), record.get("ties", 0)
        print(f"Team {team.get('id')}: {name}  ({wins}-{losses}-{ties})")

        roster = team.get("roster", {}).get("entries", [])
        for entry in roster:
            player = entry.get("playerPoolEntry", {}).get("player", {})
            slot = entry.get("lineupSlotId")
            print(f"    [{slot:>2}] {player.get('fullName', '?')}")
        print()


if __name__ == "__main__":
    main()
