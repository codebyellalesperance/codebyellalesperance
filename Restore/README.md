# Restore — iOS app (v1)

A calming trainer who understands you. Blueprint framework: the app is the
delivery layer; training plans are data (`Resources/seed-plan.json`), built
with Claude and imported via Settings → Import plan.

## What's in v1

- **Today** — the day as a timeline of blocks (morning stretch, desk resets,
  gym session, evening check-in), Monday-start week strip, cycle-phase header,
  rules-based suggestions (sleep, cycle, yesterday's workout).
- **Audio player** — hands-free morning block: speaks each exercise + cue,
  counts every set/side, chimes transitions, auto-advances (toggleable),
  short version on tap, auto-completes the block.
- **Gym sessions** — goal-threaded lifts, last-session beside today's entry,
  automatic rest timer, "Where should I feel this?", per-day exercise swaps,
  bump-to-tomorrow / skip via long-press on the Today row.
- **Log** — reverse-chronological record of everything, plus external
  activities (run/class) with post-activity questions.
- **Progress** — per-exercise trend + table, neck-tension 14-day trend
  (the one dark panel), last-7-days block picture. No streaks, no badges.
- **Settings** — push level, tone, cycle-aware toggle, auto-advance toggle,
  evening check-in toggle, gym weekdays, Apple Health connect,
  plan import/export (JSON), log export, double-confirmed clear-all.
- **Intake** — 5-step first-run setup.
- **HealthKit (read-only)** — sleep, steps, workouts, menstrual data,
  nutrition (MyFitnessPal arrives via its Apple Health sync).

## Build (on your Mac)

1. Install XcodeGen once: `brew install xcodegen`
2. In this `Restore/` folder: `xcodegen generate`
3. Open `Restore.xcodeproj` in Xcode.
4. Target **Restore** → Signing & Capabilities → pick your Team
   (personal bundle id is `com.ellalesperance.Restore`; change if you like).
5. Plug in your iPhone, select it as the run destination, hit **Run**.
6. First run on device: Settings → General → VPN & Device Management →
   trust your developer certificate (only needed once).

If Xcode shows build errors, paste them back to Claude — this project was
written without a compiler in the loop, so expect one quick fix-up round.

## Design

The visual system (glass over sky and pine mist, thin Hanken Grotesk,
hairlines, muted pine/clay/grey-blue) comes from the living wireframe in
`../docs/restore-wireframes.html`. Product decisions live in
`../docs/restore-blueprint.md`.

## Roadmap

- **v1.5** — Claude API in-app: daily free-text ("my neck hurts today") →
  mobility guidance; smarter post-activity adaptation; plan revisions in-app.
- **v2** — plan library, AI/trainer-authored plans, multi-user.
