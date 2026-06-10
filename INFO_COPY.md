# INFO_COPY.md: User-Facing Modal & Popover Copy

> User-facing strings for:
> - The Chart Info Modal (Trends → long-press chart → "See Info") and the Widget Info Modal (Home → long-press widget → "See Info"), which share the See Info Modal component (SCREENS.md § Standard Patterns → See Info Modal).
> - Inline `info.circle` popovers (Phase 8.7+) — short explanatory popovers attached to specific form fields and toggles.
>
> Stored in `AppConstants` as static dictionaries keyed by identifier. Never hardcoded in views. Sections render top-to-bottom in the order listed.

---

## Chart Info Modal Copy

One entry per chart type. Each entry: title + intro paragraph + ordered list of named sections (heading + body).

### Strength Tracker (`strengthTracker`)

**Title:** About Strength Tracker

**Intro:** Strength Tracker shows how the heaviest weight you lift for a single exercise changes over time. Pick an exercise from the dropdown to see how your top set has trended in recent sessions.

**How it's calculated:** Each data point on the chart is the heaviest weight you lifted for the selected exercise on that date, taken from the top set across all of that day's matching workouts. If you trained the same exercise twice in one day, only the heavier of the two sets is plotted.

**Time range:** Toggle 30, 60, or 90 days to widen or narrow the view. The chart re-renders immediately on switch.

**What's tracked:** Only sets with a recorded weight count toward the trend. Bodyweight exercises (logged without a weight value) aren't included — they don't have a number to plot. Exercise names are matched case-insensitively, so "Bench Press" and "bench press" share the same line.

**Empty state:** At least 2 workouts containing the selected exercise with a recorded weight are needed before the chart can render. Until then, you'll see a prompt to log more sessions.

### Training Frequency (`trainingFrequency`)

**Title:** About Training Frequency

**Intro:** Training Frequency shows how many workouts you've completed each week over the last 8 weeks, side by side with your weekly target.

**How it's calculated:** Each bar is the count of workouts whose date falls within that calendar week (Monday 12:00 AM through Sunday 11:59 PM). Every workout type counts equally — a yoga session and a strength session each add one to the bar for that week.

**Your target line:** The dashed blue line is your target workouts per week, set on the Weekly Streak widget via long-press → Configure Settings. Bars at or above the line mean you hit your target that week; bars below it mean you didn't.

**Time range:** The 8 most recent calendar weeks, including the current in-progress week. Older weeks roll off as new ones begin.

**Empty state:** You need at least one full Monday–Sunday week with at least one logged workout before the chart renders.

### Personal Records (`personalRecords`)

**Title:** About Personal Records

**Intro:** Personal Records compares your most recent PR for an exercise against the PR before it, so you can see how much you improved on your latest breakthrough.

**What counts as a PR:** A PR is recorded the first time you exceed your previous heaviest weight for a given exercise. The very first time you log an exercise establishes your baseline — that workout isn't a PR by itself. Every subsequent workout that beats your highest weight to date logs a new PR event.

**How records are tracked:** PR events are calculated per exercise name (case-insensitive) and ordered chronologically by workout date. If you log the same exercise on multiple days at the same weight, no new PR is logged — the weight has to exceed the previous record. Bodyweight exercises (logged without a weight) aren't tracked because there's no number to compare.

**What you'll see:** The dropdown lists every exercise that has at least one PR event, sorted alphabetically. Selecting an exercise shows two bars: your previous record on the left and your most recent record on the right, with the date each was set.

**Empty state:** At least one exercise needs at least one PR event before the chart renders. If you've only ever lifted the same weight on a given exercise, no PR exists yet.

### Training Load Trend (`trainingLoadTrend`)

**Title:** About Training Load Trend

**Intro:** Training Load Trend plots your daily training load score over the last 14 days, color-coded by zone, so you can spot overtraining patterns and recovery windows at a glance.

**How training load is calculated:** Each day's score is a 0–100 rating that combines the volume, intensity, and recency of your recent workouts. Recent sessions count more than older ones — stress decays over about 10 days. Your experience level (set via long-press → Configure Settings on the Training Load widget) affects how quickly stress decays and how much load you can absorb before the score climbs.

**Zones:** Each dot is colored by its zone:
- Low (1–30, green): well recovered
- Moderate (31–55, yellow): some accumulated fatigue
- High (56–80, dark yellow): significant fatigue
- Peak (81–100, red): high stress, prioritize recovery

**The 7-day average line:** The dashed blue line is your 7-day rolling average, smoothing out single-day spikes so you can see the underlying trend. A rising line over a flat dot pattern means your overall load is climbing; a falling line means you're tapering.

**About this chart's calculation (Phase 11):** Each daily score on this chart is captured at midnight in your local timezone. If you have Recovery Status linked with Training Load on the Home screen, that day's score is sleep-adjusted — otherwise it's the baseline calculation. You can see which state is active in the **Recovery Status** widget on your Home screen.

Toggling linking changes which calculation captures going forward. Past days remain as they were captured.

**Empty state:** At least 3 days with at least one workout each in the last 14 days are needed before the chart renders.

### Workout Volume (`workoutVolume`)

**Title:** About Workout Volume

**Intro:** Workout Volume tracks the total weight you've moved per session over time. Each data point is one workout — together they show whether you're progressively overloading.

**How volume is calculated:** For every set in a workout, volume is `sets × reps × weight`. Those values are summed across all exercises in the session to produce a single workout volume number. Bodyweight exercises (logged without a weight) count as if the weight were 1, since they still represent work performed.

**What's included:** Only Strength Training and HIIT workouts appear on the chart. Cardio, yoga, pilates, and other types don't track exercise sets the same way, so including them would distort the trend.

**Time range:** Toggle 30, 60, or 90 days. The chart re-renders immediately on switch.

**Empty state:** At least 2 Strength Training or HIIT workouts with at least one logged exercise set are needed before the chart renders.

### Effort Trend (`rpeTrend`)

**Title:** About Effort Trend

**Intro:** Effort Trend shows your average perceived effort per week, so you can see whether your training intensity is creeping up, holding steady, or trending down.

**How it's calculated:** Effort uses a 1–10 scale where 1 is barely a warm-up and 10 is an all-out max effort. Each bar is the average of every effort rating you logged within that calendar week (Monday through Sunday). Workouts you didn't rate aren't counted — they don't pull the average up or down.

**The reference line:** The dashed line at Effort 7 marks the rough threshold between hard and very hard sessions. Several weeks averaging well above 7 in a row may signal it's time for a deload.

**Time range:** The 8 most recent calendar weeks, including the current in-progress week.

**Apple Health import:** If you record a workout on Apple Watch and rate its effort there (iOS 18 or later), that effort score imports into FitNavi automatically when the workout is linked — but only if you haven't already entered an effort rating yourself. Your manually entered ratings always win.

**Empty state:** At least one full Monday–Sunday week with at least one workout that has a recorded effort rating is needed before the chart renders.

### Workout Type Breakdown (`workoutTypeBreakdown`)

**Title:** About Workout Type Breakdown

**Intro:** Workout Type Breakdown shows how your training is distributed across workout types, so you can see whether your routine is balanced or concentrated in one area.

**How it's calculated:** Each segment of the donut is the count of workouts of that type within the selected time range, divided by your total workout count. A 50% Strength Training slice means half of all your sessions in the period were Strength Training.

**Workout types:** Six categories — Strength Training, HIIT, Cardio, Yoga, Pilates, and Other. Each has a fixed color shown in the legend. Workouts imported from Apple Health are mapped to one of these six based on their HealthKit activity type.

**Time range:** Toggle 30 days, 60 days, 90 days, or All Time. "All Time" includes every workout you've ever logged.

**Empty state:** At least 2 workouts of any type are needed before the chart renders.

### Session Duration (`sessionDuration`)

**Title:** About Session Duration

**Intro:** Session Duration shows how long your workouts have been on average each week, so you can manage your time and pacing.

**How it's calculated:** Each bar is the average duration in minutes of all logged workouts within that calendar week (Monday through Sunday). Workouts you didn't enter a duration for aren't counted — they don't have a number to average.

**The target line:** The dashed line is your target workout duration, set via long-press → Configure Settings on the Training Load widget. It's the same value FitNavi uses as a fallback in your training load score when a workout has no duration entered.

**Time range:** The 8 most recent calendar weeks, including the current in-progress week.

**Apple Health import:** Durations from Apple Watch and other Health-connected apps are imported automatically when you link a workout, so you don't need to re-enter them.

**Empty state:** At least one full Monday–Sunday week with at least one workout that has a recorded duration is needed before the chart renders.

---

## Widget Info Modal Copy

One entry per "See Info"-eligible widget (Training Load, Power Level, Activity Rings). Same structure as Chart Info Modal Copy. Stored as a static dictionary keyed by `widgetType`.

### Training Load (`trainingLoad`)

**Title:** About Training Load

**Intro:** Training Load is a 0–100 score that summarizes how much training stress you've accumulated over the past 10 days. The gradient bar and advisory beneath it suggest whether to push, ease off, or rest today.

**How it's calculated:** Each workout you've logged in the last 10 days contributes a stress value based on your Effort rating for that session, how long it lasted, the workout type, and the volume you put in (sets × reps for Strength and HIIT). Recent sessions count more than older ones — stress decays over about 10 days.

**Your experience level:** Set via long-press → Configure Settings on the widget. Beginner, Intermediate, and Advanced each have a different recovery rate and stress capacity. Higher experience means stress decays faster and you can absorb more training before the score climbs into peak territory.

**Consecutive training days:** Stacking training days back-to-back adds a small multiplier to your score, up to 32% extra at five or more consecutive days. Take a rest day and the multiplier resets.

**Same-day floor:** If you've already trained today, the score won't drop low enough to suggest "train hard" — there's a built-in floor based on what you logged today that lifts on its own tomorrow.

**Zones:**
- Low (1–30, green): well recovered
- Moderate (31–55, yellow): some accumulated fatigue
- High (56–80, dark yellow): significant fatigue
- Peak (81–100, red): high stress, prioritize recovery

**What's not counted:** Workouts logged with no exercises, no Effort rating, and no duration are skipped — they're treated as placeholder entries with no meaningful stress to add.

**Linking with Recovery Status (Phase 11):** If you've added the Recovery Status widget to your Home screen, you can link the two by placing them directly above or below each other. When linked, last night's sleep slows your stress decay — your Training Load score reflects how recovered you actually are, not just how much time has passed. See the Recovery Status info sheet for details.

**Empty state:** If you haven't logged a workout in the last 10 days, the score sits at 0 (Resting) and the advisory shows "No recent training stress."

### Power Level (`powerLevel`)

**Title:** About Power Level

**Intro:** Power Level shows whether your strength training volume is rising, holding steady, or trending down compared to where you were a month ago. It answers "am I getting stronger?" at a glance.

**How it's calculated:** FitNavi averages your workout volume across the last 30 days and compares it to your average across the prior 30 days. Volume per workout is sets × reps × weight, summed across every exercise in the session.

**What workouts count:** Only Strength Training and HIIT workouts. Cardio, yoga, pilates, and other types don't track exercise sets, so they don't contribute to a volume comparison.

**Bodyweight exercises:** Sets logged without a weight value count as if the weight were 1, since they still represent work performed. This keeps bodyweight volume from disappearing entirely from the comparison.

**Status thresholds:**
- Rising (↑, green): current 30-day average is more than 10% higher than the prior 30 days
- Steady (—, grey): within 10% in either direction — your volume is holding consistent
- Deloading (↓, red): current 30-day average is more than 10% lower than the prior 30 days

**Empty state:** If you don't have any Strength Training or HIIT workouts logged, the widget shows a prompt to start logging. If you have current workouts but no prior 30-day baseline yet (less than 31 days of history), the status defaults to Steady until you build enough data.

### Activity Rings (`appleActivity`)

**Title:** About Activity Rings

**Intro:** Activity Rings shows your daily Move, Exercise, and Stand progress pulled live from Apple Health, measured against goals you set in FitNavi. It's the same three-ring view you see on Apple Watch, brought into FitNavi so you can keep your activity tracking and your strength tracking in one place.

**The three rings:**
- **Move** (red): active calories burned today. Counts movement of any kind — walks, workouts, fidgeting at your desk. Goal default is 500 cal; you can set it 1–2000 in 10-cal increments.
- **Exercise** (green): minutes of brisk activity today. The Watch decides what counts based on heart rate and motion. Goal default is 30 min; you can set it 1–240 in 5-min increments.
- **Stand** (blue): hours where you stood and moved for at least one minute. Goal default is 12 hours; you can set it 1–24 in 1-hr increments.

**How goals are set:** When you first add the widget, FitNavi imports the goals you've already set in Apple Health. After that, your FitNavi goals are independent — change them in Configure Settings, or use the "Import from Apple Health" button to re-sync if you change them on your watch later.

**Workout contribution:** Below each ring's value, you'll see how much of today's progress came from a workout you logged in FitNavi (only workouts linked to Apple Watch contribute — manually-logged workouts that aren't HK-linked won't show up here, since their data isn't in HealthKit).

**Weekly closure rate:** The chip below the rings tells you how many days this week you closed all three rings — a quick read on your week-over-week consistency.

**Tap the widget** to open a detailed breakdown with sparklines and a calendar heatmap of which days you closed your rings (toggle between 7-day and 30-day views).

**Requirements:** You'll need an Apple Watch and Apple Health enabled in FitNavi Settings. If either is missing, the widget shows a message explaining what to do next.

### Recovery Status (`recoveryStatus`) — Phase 11

**Title:** About Recovery Status

**Intro:** Recovery Status surfaces two signals that influence how ready you are for your next workout: how long you slept last night, and how long it's been since your last training session. Together they help you decide whether to push, ease off, or rest.

**How sleep is measured:** FitNavi reads sleep data from Apple Health. Any device that writes sleep to Apple Health contributes — Apple Watch, Oura Ring, Whoop, AutoSleep, and others.

Sleep is attributed to your wake-up day. A session ending Tuesday morning belongs to Tuesday's data. FitNavi uses a 6pm-to-6pm window (matching the Apple Health app) so late-evening naps and overnight sessions land on the day you'd expect.

If you nap during the day, those minutes are added to your total — your hero value is your total sleep across the window.

**About sleep stages:** Modern sleep trackers classify your sleep into four stages:

- **Deep** — slow-wave sleep that drives physical recovery
- **REM** — dream sleep that drives cognitive recovery
- **Core** — lighter sleep, the bulk of a typical night
- **Awake** — brief periods of wakefulness during the sleep window

The deep-sleep percentage you see is the proportion of your total sleep time spent in the deep stage.

A note on accuracy: Apple Watch's sleep stage classification is meaningfully less accurate than clinical polysomnography. Other sources (Oura, Whoop, etc.) may classify stages with different accuracy. Treat deep sleep percentages as a directional signal, not a diagnostic.

**About sleep efficiency:** Sleep efficiency is the percentage of your time in bed actually spent asleep. Tossing and turning, brief wake-ups, and trouble falling asleep all lower the number.

Efficiency requires your sleep tracker to record both time-in-bed and time-asleep. Apple Watch records both; some third-party sources record only sleep time. If efficiency isn't shown in your detail sheet, the source didn't provide in-bed data.

**Linking with Training Load:** Place Recovery Status directly above or below the Training Load widget on your Home screen to link them. Both card borders turn blue and the cards merge into one continuous block.

When linked, last night's sleep is factored into your Training Load score: poor sleep slows your stress decay, so your score better reflects how recovered you actually are — not just how much time has passed.

To unlink, reorder either widget so they're no longer adjacent. Adding a widget between them, or removing either one, also unlinks them. You can also unlink directly via the linked pair's long-press menu.

**What to expect when you're starting out:** The widget needs last night's sleep to fill in. If you forgot your sleep tracking device, the hero will show `NO DATA` for the night — the timer still works.

The detail sheet's sparkline starts to fill out after about three nights of sleep data; trends become meaningful around two weeks in.

### Linked Recovery & Load (`linkedRecoveryLoad`) — Phase 11

**Title:** About Recovery & Load

**Intro:** Training Load is a 0–100 score from your recent workouts that reflects your physical stress. When the recovery and load widgets are linked, sleep adjusts the score to reflect the impact of your rest patterns on your physical stress levels.

**What feeds your Training Load:** Your score reflects each recent workout's effort, duration, type, and volume (sets × reps for Strength and HIIT). Recent sessions count more — stress decays over about 10 days.

**Zones:**
- Low (1–30, green): well recovered
- Moderate (31–55, yellow): some accumulated fatigue
- High (56–80, dark yellow): significant fatigue
- Peak (81–100, red): high stress, prioritize recovery

**How linking changes Training Load:** Without linking, Training Load decays at a fixed rate over ~10 days regardless of how rested you are.

With linking, a poor night slows that decay, so your score sits higher until you recover. A few rough nights can push the score 10–25% higher than the unlinked version.

**How sleep slows stress decay:** FitNavi compares last night's sleep to your target. *(Long-press either card → "Configure Settings" to change it.)*

- **At or above target** — normal decay.
- **Below target** — decay slows proportionally, up to ~40%.
- **No data** — that day falls back to the unlinked rate. The link stays active.

**About sleep data:** FitNavi reads sleep from Apple Health. Apple Watch, Oura, Whoop, AutoSleep, and others all contribute.

Sleep is attributed to your wake-up day, using a 6pm-to-6pm window so late nights and naps land where you'd expect.

Trackers classify sleep into four stages:

- **Deep** — physical recovery
- **REM** — cognitive recovery
- **Core** — lighter sleep, the bulk of the night
- **Awake** — brief wake-ups

Stage accuracy varies by device — treat it as directional, not clinical.

**Unlinking these widgets:** Long-press either card → "Unlink Widgets." You can also unlink by reordering them apart or deleting one. To re-link, drag them back into adjacent positions.

**What to expect when you're starting out:** Your linked score updates once last night's sleep syncs from Apple Health, usually within a few hours of waking. Missed a night? That day falls back to the unlinked rate; the link resumes the next night with data.

The 14-day chart shows current-calculation history — older days use whatever method was active then, so you may see a small step where you linked.

---

## Inline Popover Copy (Phase 8.7+)

Short explanatory popovers attached to specific form fields and toggles via inline `info.circle` icons. Distinct from the See Info Modal pattern — no headers, no scrollable body, no close button. SwiftUI `.popover` modifier anchored to the icon, ~260pt width, dismissed on tap-outside.

Stored in `AppConstants` as static strings or via a small accessor function. Never hardcoded in views.

### Rest Per Set (`exerciseCard_restPerSetInfoPopover`)

Anchor: `info.circle` icon (14pt, Muted Text) trailing the "REST PER SET" label on each exercise card. Surfaced in Create Workout Template, Edit Template, Log Workout, and Edit Planned Workout (SCREENS.md § Log Workout → Exercise Card Additions).

> Rest period between each set of this exercise. On Apple Watch, the rest period appears as a countdown timer.

Constant: `AppConstants.AppleWatch.restPerSetPopover`.

### Watch Sync Toggle (`editScheduledWorkout_watchSyncInfoPopover` and `scheduleWorkout_pushToAppleWatchInfoPopover`)

Anchor: `info.circle` icon trailing the "Push to Apple Watch" toggle on the **Plan Workout sheet** (SCREENS.md § Plan → Push to Apple Watch Toggle) and the **Edit Planned Workout screen** (SCREENS.md § Edit Planned Workout). Single string, reused on both surfaces.

> Pushes this workout to your Apple Watch's Fitness app. Appears in the Scheduled section on the workout's day. Rest timers defined in your workout template will appear as a countdown timer on Apple Watch between sets.

Constant: `AppConstants.AppleWatch.watchSyncInfoPopover`.

---

## Power Level Nudge Copy (Phase 8.8)

Calculated contextual suggestion surfaced on the Power Level Breakdown Sheet (SCREENS.md § Power Level Breakdown Sheet → block 5). Generated by `PowerLevelService.computeNudge()` (SERVICES.md § Power Level Algorithm → Nudge Computation). Stored in `AppConstants.PowerLevel.nudgeCopy` as a dictionary keyed by archetype.

Copy uses `{placeholder}` syntax. The service supplies values via `NudgeInputs`; the UI interpolates with `String(format:locale:)` or SwiftUI `LocalizedStringResource`.

### Deloading (`deloading`)

Template: `You've logged {currentSessionCount30d} sessions in the last 30 days vs {previousSessionCount30d} in the prior 30. Adding 1 Strength or HIIT session this week can stabilize your volume.`

Example interpolations:

> You've logged 4 sessions in the last 30 days vs 8 in the prior 30. Adding 1 Strength or HIIT session this week can stabilize your volume.

> You've logged 6 sessions in the last 30 days vs 12 in the prior 30. Adding 1 Strength or HIIT session this week can stabilize your volume.

**Notes:** Mention both counts; do not soften the comparison. The phrase "can stabilize" is intentionally non-prescriptive (avoids "you should"). If `currentSessionCount30d == 0`, the cold-start guard fires first and this template never renders.

### Steady (`steady`)

Template: `Volume on {topExerciseName} is flat over the last 30 days. Adding ~5% weight or 1–2 reps could push you into Rising.`

Example interpolations:

> Volume on Bench Press is flat over the last 30 days. Adding ~5% weight or 1–2 reps could push you into Rising.

> Volume on Squats is flat over the last 30 days. Adding ~5% weight or 1–2 reps could push you into Rising.

**Notes:** Uses `topContributingExercises(limit: 1).first` as `topExerciseName`. When that returns nil (no exercise passes the ≥ 3-session filter), the service falls back to the cold-start template — the steady-with-no-top-exercise case effectively becomes cold-start copy. Do not render this template with a nil exercise name.

### Rising (`rising`)

Template (with top exercise): `Up {deltaPct}% this month — hold your current {avgSessionsPerWeek30d} sessions/week to keep climbing. {topExerciseName} is your biggest gainer.`

Template (without top exercise — fallback when ≥ 3-session filter excludes everything): `Up {deltaPct}% this month — hold your current {avgSessionsPerWeek30d} sessions/week to keep climbing.`

Example interpolations:

> Up 11% this month — hold your current 3 sessions/week to keep climbing. Bench Press is your biggest gainer.

> Up 18% this month — hold your current 4 sessions/week to keep climbing.

**Notes:** `deltaPct` is the same `pct_change` from § Step 3 of the Power Level algorithm — never recomputed. `avgSessionsPerWeek30d` is rounded to 1 decimal in storage and displayed without trailing zeros (3.0 → "3", 3.5 → "3.5").

### Cold-Start (`coldStart`)

Template: `Log a few more Strength or HIIT workouts to unlock personalized suggestions.`

**Notes:** Fires when `qualifyingWorkoutsInCurrentWindow.count < 3` regardless of status. No placeholders. This is also the fallback copy when the steady archetype's `topExerciseName` resolves to nil. Identical to the Power Level Breakdown Sheet's nudge-block per-block empty state.

### No Baseline (`noBaseline`)

Template: `Power Level trend comparisons use the prior 30 days as a baseline. Keep logging — once you've entered enough exercise data, you'll see personalized trend advice here.`

**Notes:** Fires when `qualifyingWorkoutsInCurrentWindow.count >= 3` AND `qualifyingWorkoutsInPreviousWindow.isEmpty` — the user has enough current-window data to populate the sheet, but no prior 30-day window to compare against. Phrased softly ("enough exercise data") rather than committing to a specific day count, since the actual unlock condition is "≥ 1 qualifying workout dated 31–60 days ago" — a hard "60 days of history" promise overstated the requirement and broke when satisfied. No placeholders surface in the copy (`currentSessionCount30d` is captured for analytics but not interpolated in v1). Per-exercise rows in the same scenario render an em-dash (`—`) in place of "+0%" so the row delta and the nudge message are consistent.

Constant block:

```swift
AppConstants.PowerLevel.nudgeCopy = [
    "deloading":  "You've logged {currentSessionCount30d} sessions in the last 30 days vs {previousSessionCount30d} in the prior 30. Adding 1 Strength or HIIT session this week can stabilize your volume.",
    "steady":     "Volume on {topExerciseName} is flat over the last 30 days. Adding ~5% weight or 1–2 reps could push you into Rising.",
    "rising":     "Up {deltaPct}% this month — hold your current {avgSessionsPerWeek30d} sessions/week to keep climbing. {topExerciseName} is your biggest gainer.",
    "risingNoTop":"Up {deltaPct}% this month — hold your current {avgSessionsPerWeek30d} sessions/week to keep climbing.",
    "coldStart":  "Log a few more Strength or HIIT workouts to unlock personalized suggestions.",
    "noBaseline": "Power Level trend comparisons use the prior 30 days as a baseline. Keep logging — once you've entered enough exercise data, you'll see personalized trend advice here."
]
```

---

## Widget Detail Sheet Empty States (Phase 8.8)

Per-block empty-state copy for the four new detail sheets. Stored in `AppConstants.WidgetDetail.emptyState.*`. Full block-level rules live in SCREENS.md per sheet — this section is the user-facing copy source of truth.

### Today's Plan Detail Sheet

| Key | Copy |
|---|---|
| `todaysPlan.empty.noWorkouts` | `No workouts planned for today.` |
| ~~`todaysPlan.empty.scheduleChip`~~ | _Retired (Phase 8.8 follow-up — chip removed from sheet)._ |

### Training Load Detail Sheet

| Key | Copy |
|---|---|
| `trainingLoad.empty.chart` | `Not enough data yet to chart your daily training load. Keep logging.` |
| `trainingLoad.empty.contributingWorkouts` | `No workouts in the last 7 days.` |
| `trainingLoad.empty.coldStart` | `Log a few more workouts with exercises to see your training load breakdown.` |

### Weekly Streak Insights Sheet

| Key | Copy |
|---|---|
| `weeklyStreak.empty.thisWeekTargetZero` | `Set a weekly workout target in Configure Settings to see this week's progress.` |
| `weeklyStreak.empty.heatmap` | `Log a workout to start your streak history.` |
| `weeklyStreak.hero.subline.zero` | `Hit your weekly target to start a streak!` (reused from CONSTANTS § Streak Motivational Messages tier 0) |

### Power Level Breakdown Sheet

| Key | Copy |
|---|---|
| `powerLevel.empty.hero` | `Log a few more Strength or HIIT workouts to see your power level.` |
| `powerLevel.empty.topExercises` | `Log a few more sessions on the same exercises to surface your top drivers.` |
| `powerLevel.empty.nudge` | (reuses `coldStart` from § Power Level Nudge Copy above) |

---

## Widget Detail Sheet Empty States (Phase 11)

Per-block empty-state copy for the Recovery Status and Linked Recovery & Load detail sheets. Stored in `AppConstants.WidgetDetail.emptyState.*`.

### Recovery Status Detail Sheet

| Key | Copy |
|---|---|
| `recoveryStatus.empty.sparkline` | `Not enough sleep data yet to chart trends.` |
| `recoveryStatus.empty.timeSinceWorkout` | `No workouts logged yet.` (paired with full-width `Log a Workout` CTA — see SCREENS.md § Recovery Status Detail Sheet → Cold-Start Empty State) |
| `recoveryStatus.empty.efficiency` | *(no copy — caption is hidden entirely when `inBedMinutes == nil`)* |
| `recoveryStatus.cta.logWorkout` | `Log a Workout` |
| `recoveryStatus.cta.connectAppleHealth` | `Connect` |
| `recoveryStatus.cta.openIOSSettings` | `Open Settings` (sleep access denied state CTA) |

### Linked Recovery & Load Detail Sheet

| Key | Copy |
|---|---|
| `linkedRecoveryLoad.empty.contributingWorkouts` | `No workouts in the last 7 days.` (reuses Training Load Detail Sheet copy) |
| `linkedRecoveryLoad.toast.hkRevoked` | `Recovery Status disconnected from Apple Health.` (Toast Style — fires when the user revokes sleep scope via iOS Settings while the linked detail sheet is presented; the sheet auto-dismisses) |

---

## Training Load Zones → Linked Advisory Copy (Phase 11 — BUG-061)

Joint Training Load + sleep advisory used by the linked Recovery & Load composite only. Replaces the prior "concatenated qualifier" pattern (an independent sleep sentence appended to the zone advisory), which could produce contradictions like *"Well recovered. Ready to train. You're significantly under-slept."* — see BUG-061.

Computed by `RecoveryStatusService.computeLinkedAdvisory(baseAdvisory:zone:trainedToday:sleepHours:targetSleepHours:)`. Stored in `AppConstants.TrainingLoad.linkedAdvisoryText` as a dictionary keyed by `"<zone>|<trainedToday>|<sleepBucket>"`. Met-target (`0.85–0.99`) and missing-data nights pass `baseAdvisory` through unchanged.

Sleep buckets:

| Sleep ratio (`sleepHours / targetSleepHours`) | Bucket | Behavior |
|---|---|---|
| `≥ 1.0` | `strong` | Joint sentence — positive sleep note appended. |
| `0.85 – 0.99` | `metTarget` | `baseAdvisory` returned unchanged. |
| `0.70 – 0.84` | `moderatelyBelow` | Joint sentence — recommendation downgraded one notch. |
| `< 0.70` | `significantlyBelow` | Joint sentence — recommendation clamped at light / rest. |
| `nil` | n/a | `baseAdvisory` returned unchanged. |

Surfaces in:

- The Training Load widget body inside the Linked Recovery & Load composite (replaces the bare `LoadResult.advisory` text)
- The Linked Recovery & Load Detail Sheet's Recovery Readiness callout (SCREENS.md § Linked Recovery & Load Detail Sheet → block 10)

The standalone Training Load widget and the standalone Training Load Detail Sheet are unchanged — they continue to render `ExerciseLoadService.LoadResult.advisory` directly. See CONSTANTS.md § Training Load Zones → Advisory Text (Standalone Training Load Widget).

**Constant block** — 27 strings, keyed `"<zone>|<trainedToday>|<sleepBucket>"`. `trainedToday` is `"trained"` or `"untrained"`. Resting × trained pairings are omitted (suppressed by the same-day floor in `ExerciseLoadService.calculateLoad`).

```swift
AppConstants.TrainingLoad.linkedAdvisoryText = [
    // Resting
    "Resting|untrained|strong":              "No recent training stress and sleep was solid — a great day to push hard.",
    "Resting|untrained|moderatelyBelow":     "No recent training stress, but sleep was short. Favor a moderate session over a hard one.",
    "Resting|untrained|significantlyBelow":  "No recent training stress, but sleep was significantly short. Keep today light or rest.",
    // Low
    "Low|untrained|strong":                  "Well recovered and sleep was solid — a great day to train hard.",
    "Low|untrained|moderatelyBelow":         "Your body is recovered, but sleep was short. Favor a moderate session over a hard one.",
    "Low|untrained|significantlyBelow":      "Your body is recovered, but sleep was significantly short. Keep today light or rest.",
    "Low|trained|strong":                    "Session logged. Sleep was solid — you have capacity for more if you choose.",
    "Low|trained|moderatelyBelow":           "Session logged, but sleep was short. Wrap up your day and let your body recover.",
    "Low|trained|significantlyBelow":        "Session logged, but sleep was significantly short. Stop here and prioritize recovery.",
    // Moderate
    "Moderate|untrained|strong":             "Some muscle fatigue, but sleep was solid — a moderate session is well within reach.",
    "Moderate|untrained|moderatelyBelow":    "Some muscle fatigue and sleep was short. Favor a light session today.",
    "Moderate|untrained|significantlyBelow": "Some muscle fatigue and sleep was significantly short. Keep today light or rest.",
    "Moderate|trained|strong":               "Good work today. Sleep was strong — recovery should come quickly.",
    "Moderate|trained|moderatelyBelow":      "Good work today. Sleep was short — rest is especially important.",
    "Moderate|trained|significantlyBelow":   "Good work today. Sleep was significantly short — make rest the priority.",
    // High
    "High|untrained|strong":                 "Significant muscle fatigue. Sleep was solid — a lighter session or active recovery still fits.",
    "High|untrained|moderatelyBelow":        "Significant muscle fatigue and sleep was short. Active recovery or rest today.",
    "High|untrained|significantlyBelow":     "Significant muscle fatigue and sleep was significantly short. Rest today.",
    "High|trained|strong":                   "Rest is the priority. Sleep was solid — that'll help with muscle recovery.",
    "High|trained|moderatelyBelow":          "Recovery is the priority. Sleep was short — prioritize resting if you're able.",
    "High|trained|significantlyBelow":       "Recovery is the priority. Sleep was significantly short — prioritize rest.",
    // Peak
    "Peak|untrained|strong":                 "High physical stress. Sleep was solid, but keep today to rest or very light activity.",
    "Peak|untrained|moderatelyBelow":        "High physical stress and sleep was short. Rest today.",
    "Peak|untrained|significantlyBelow":     "High physical stress and sleep was significantly short. Full rest today.",
    "Peak|trained|strong":                   "You've been pushing hard. Time to rest — sleep was solid, recovery should come quickly.",
    "Peak|trained|moderatelyBelow":          "You've been pushing hard. Time to rest — sleep was short, recovery needs the time.",
    "Peak|trained|significantlyBelow":       "You've been pushing hard. Time to rest — sleep was significantly short, your body needs it."
]
```

Bucket boundaries (CONSTANTS.md § Training Load Zones → Linked Advisory Copy) are the canonical source. Missing keys (any combination not in the table — including `Resting|trained|*`) return `baseAdvisory` as a safety fallback rather than empty string.
