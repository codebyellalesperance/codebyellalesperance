# ESPN Fantasy Football access

Claude (and any script) can't reach into your Chrome browser directly, but it
can call ESPN's fantasy API using your existing Chrome login. Chrome stores
your ESPN session in two cookies — copy them once and the script here can read
your league and team.

## 1. Find your league ID

Open your league in Chrome. The URL looks like:

```
https://fantasy.espn.com/football/team?leagueId=1234567&teamId=3
```

`leagueId` is the number you need (and `teamId` if you want just your team).

## 2. Copy your session cookies (private leagues only)

Public leagues skip this step.

1. While on fantasy.espn.com and logged in, press **F12** (or right-click →
   Inspect) to open Chrome DevTools.
2. Go to the **Application** tab → **Cookies** → `https://fantasy.espn.com`.
3. Copy the value of the `espn_s2` cookie (it's long) and the `SWID` cookie
   (it looks like `{XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}` — keep the braces).

These cookies grant access to your ESPN account, so treat them like a
password: don't commit them to the repo or paste them anywhere public.
They expire periodically; re-copy them if you start getting 401 errors.

## 3. Run the script

```bash
export ESPN_S2='paste-espn_s2-value-here'
export ESPN_SWID='{paste-SWID-value-here}'

python espn-fantasy/fetch_team.py --league-id 1234567 --team-id 3
```

The script prints the league name, each team's record, and rosters. It uses
only the Python standard library — no packages to install.

## Going further

The same API (and the `espn-api` package on PyPI) supports matchups, free
agents, box scores, and historical seasons if you want to build more on top
of this.
