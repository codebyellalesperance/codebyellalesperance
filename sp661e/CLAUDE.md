# Claude briefing: SP661E under-cabinet lights (Mac mini)

You are running on Ella's Mac mini, which is within Bluetooth range of the
LANXEE COB under-cabinet strip driven by a BanlanX SP661E BLE controller.
`sp661e.py` in this directory controls it. Your job here is to operate and
schedule the lights.

## First-time setup (do these in order, verifying each)

1. `pip3 install -r requirements.txt` (use a venv if the system Python is
   externally managed: `python3 -m venv .venv && .venv/bin/pip install -r
   requirements.txt`, then invoke via `.venv/bin/python`).
2. Bluetooth permission: on macOS the invoking app (Terminal, iTerm, or the
   Claude app) needs Bluetooth access — System Settings → Privacy &
   Security → Bluetooth. If a scan returns nothing or errors with a
   permission denial, ask Ella to grant it there, then retry.
3. Make sure the BanlanX phone app is force-quit — the controller accepts
   only one BLE connection.
4. `python3 sp661e.py scan` — on macOS this prints a UUID per device, not
   a MAC. Pick the device whose name starts with `SP` (expect `SP661E`).
5. Save it: write `LIGHTS_ADDR=<uuid>` to a `lights.env` file in this
   directory so future runs (and scheduled runs) don't need to rescan.
   `lights.env` is gitignored — never commit it.
6. Prove control end to end: `off`, wait, `on`, then `brightness 60`.
   Confirm with Ella that the strip actually responded before scheduling
   anything.
7. If the strip connects but ignores commands, retry with `--protocol v2`;
   whichever dialect works, record it in `lights.env` as
   `LIGHTS_PROTOCOL=...` and use it consistently.

## Scheduled runs

Ella wants the lights on a schedule driven by Claude. Ask her what
schedule she wants if she hasn't said (earlier idea: fade up weekday
mornings ~6:30am, dim to 20% at 9pm, off at midnight). Then create
scheduled tasks on THIS machine (they must run here — cloud sessions have
no Bluetooth), each invoking e.g.:

    cd <this directory> && source lights.env && \
      python3 sp661e.py -a "$LIGHTS_ADDR" -p "${LIGHTS_PROTOCOL:-6xx}" brightness 20

Notes for reliable unattended runs:
- The Mac must be awake at fire time. If runs are missed, suggest
  `sudo pmset repeat wakeorpoweron MTWRFSU 06:25:00` or disabling sleep
  (System Settings → Energy) — ask before changing power settings.
- BLE occasionally fails to connect on the first try; retry a failed
  command up to 3 times with a few seconds between attempts before
  reporting failure.
- Keep runs quiet on success; surface only failures.
