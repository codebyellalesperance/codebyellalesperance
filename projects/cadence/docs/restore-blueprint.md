# Restore — Product Blueprint

**One-liner:** a calming trainer who understands you, has your best interest in mind, and wants you to succeed. The brain of your fitness — so you don't have to think about it anymore.

*Compiled entirely from Ella's intake answers, Aug 7. Nothing below is invented; open items are marked ⚑.*

---

## The pivot

Restore is **not** a single hardcoded program. It's a **blueprint framework**: any training plan plugs into it, and an intake builds yours. Ella's specific programming (the posture/neck work from her earlier Claude research) becomes *content* loaded into the framework — paused for now, revisited as a secondary step after the framework exists.

- **v1:** one user (Ella), one active plan, framework architecture underneath.
- **v2:** plan library — plans added by AI or by trainers, multi-user.

---

## Core concepts

### 1 · Intake (first run)
A questionnaire that shapes everything:
- Goals, ranked (Ella's: **1 physique/look · 2 pain & tension gone · 3 energy · 4 strength**)
- Gym access + equipment inventory (user-declared, editable anytime — gyms change)
- Realistic gym days/week (**user-selected**; Ella's initial pick: 4–6)
- Morning block time budget (Ella: mornings free but short — well under 30 min ⚑ exact target TBD)
- How you're best coached + tone preference (user-chosen voice)
- **Push level** — a setting, not an assumption: from "really push me, notifications and all" to "I'm self-motivated, stay quiet" (Ella: self-motivated, low push)
- Cycle-aware training: **opt-in toggle**, backed by evidence-based guidance when on
- Audio player: auto-advance default with a **toggle** for tap-to-advance

### 2 · Plan structure — prescriptive, but breathing
- **3–4 anchor days** + movable days. A Tuesday session can bump to Wednesday, or be skipped outright. Skipping is a first-class action, never a failure state.
- **Short versions**: every block has a low-energy variant, one tap.
- **Equipment-adaptive day-of**: "thought I'd be at the gym, I'm at home" → the session re-renders for what's actually available.
- Grows with you: starts prescriptive, learns how you like to train from what you actually do and how you respond.

### 3 · Blocks (the day)
- **Morning stretch** — audio-guided, hands-free, short.
- **Desk resets** — subtle, chair-friendly, hybrid-aware. Present but never pushy.
- **Gym session** — goal-threaded lifts, last-session comparison, rest timer, minimal tapping (tap-to-skip anything).
- **Evening check-in** — optional (setting). Tension, cycle event, one-line note.

### 4 · Exercise experience
- Every exercise: demo video (pre-selected by Claude, user can replace), prescription, and an on-demand **"Where should I feel this?"** — tap it to get engagement cues; from there, watch the video or **swap the exercise**. (Direct answer to the Ladder pain point: substitutions everywhere, easy.)

### 5 · External activity
Went for a run or a workout class? Add it. The app asks a few questions afterward — what it focused on, how hard it was — and **adjusts the plan** around what you actually did.

### 6 · Data in (Apple Health is the hub)
- Pull: workouts, heart rate, sleep, steps/walking, cycle (from her tracker via Health), nutrition (MyFitnessPal → Health).
- **Sleep-informed**: bad night → *recommend* an easier/shorter session, Garmin-style. Recommend, never force.
- **Cycle-informed** (when opted in): push or ease around phases using backed research.
- **Walking** and other ambient activity filters into the plan automatically.
- Function-lab results: a consideration for high/low-intensity programming during plan building — not centered in the app.

### 7 · Nutrition
- Per-phase emphasis ("more iron-rich food this week") + daily suggestions + macro targets tied to that day's training.
- MyFitnessPal data (via Health) influences the picture; the more logged, the smarter it gets.

### 8 · Adaptation engine — the honest architecture split
- **v1 — rules engine (deterministic, no server):** skip/bump logic, short versions, sleep thresholds → suggestions, cycle phase → intensity notes, equipment re-rendering. All config + Health data. Reliable, offline, buildable now.
- **v1.5 — the AI brain (Claude API in the native app):** free-text daily input — "my neck hurts today," "that class wrecked my calves" — answered with what to roll/stretch/do; plan revisions in-app; post-activity Q&A that actually understands. Needs API calls; personal app + Ella's API key.
- Plan *creation* stays with Claude-in-chat until v2 regardless.

### 9 · Never
No guilt. No streaks, badges, confetti. Never mandates — suggests. The app's feeling at 7am: **a calming trainer who understands you.**

---

## Ella — seed profile (from intake)
23 · 5'6"–5'7" · 160 lb → goal 135–140 · desk job, open-plan, hybrid · mornings free but short · gym before or after work · initial 4–6 gym days/wk (self-selected) · regular cycle, tracked via Health · MyFitnessPal user (would use more if it fed the plan) · walker · self-motivated (low push setting) · Pilates this year — liked it, felt "soft," wants to feel *stronger* · used Ladder — didn't like the lifts, no easy substitutions · wants more from less · 6-month dream-fitness horizon · no medical conditions/meds · injuries self-assessed, desk-driven neck/posture tension · Function labs on hand, recent.

---

## Build sequence
1. **Living wireframe** (rounds 1–6) — remains the design source of truth. ✅
2. **v1 SwiftUI iOS app** — Ella's phone only: framework + intake + blocks + audio player + gym logging + rules-based adaptation + HealthKit read + her compiled plan.
3. **v1.5** — Claude API integration: the daily AI brain.
4. **v2** — plan library, trainer/AI-authored plans, multi-user.

## Open items ⚑
1. Morning block exact time budget (10 min?).
2. Confirm: skip the standalone HTML app entirely, build straight to SwiftUI? (HealthKit-dependent features argue yes.)
3. v1.5 timing + Anthropic API key logistics — decide after v1 is on her phone.
4. Her actual program content — compiled next, as step one of the build.
