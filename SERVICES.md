# SERVICES.md: FitNavi Service Specifications

> Implement each algorithm exactly as specified. Do not invent alternative formulas or add variables beyond what is defined here.
> For data models, see `PRD.md` Section 5. For constants, see `CONSTANTS.md`.

---

## Training Load Algorithm (ExerciseLoadService.swift)

**Purpose:** Daily training load score (0–100) reflecting accumulated training stress. Answers: "Should I train today, and how hard?" Drives the Training Load widget (Home) and Training Load Trend chart (Progress). Updates daily — including rest days — because stress decays over time.

`targetWorkoutsPerWeek` is NOT an input to this algorithm. It is used exclusively by Streak.

### Lookback Window
All workouts within the **last 10 days**. Anything older is ignored.

### Inputs — Per Workout (within 10-day window)

| Input | Source | Nil Handling |
|---|---|---|
| RPE | `workout.rpe` | Nil → assume **5** |
| Duration | `workout.durationMinutes` | Nil → use `targetMinutesPerWorkout` from UserSettings |
| Workout Type | `workout.workoutType` | Required (never nil) |
| Exercise Sets | `workout.exerciseSets` | Empty → volume modifier defaults to 1.0 |
| Date | `workout.date` | Required (never nil) |

### Inputs — Global

| Input | Source |
|---|---|
| Experience Level | `UserSettings.experienceLevel` |
| Target Minutes/Workout | `UserSettings.targetMinutesPerWorkout` (nil-duration fallback only) |

### Pre-Filter — Empty Workout Exclusion
Before processing, discard any workout in the 10-day window where **all three** conditions are true:
1. `exerciseSets` is empty (zero exercises)
2. `rpe` is nil
3. `durationMinutes` is nil

These workouts contain no meaningful training data (placeholder/shell entries) and must be excluded from the entire algorithm: they do not contribute to `session_stress` (Steps 1–5), do not count toward `consecutive_days` (Step 6), and do not factor into `today_stress` (Step 9).

A workout that has zero exercises but provides RPE and/or duration (e.g., a Yoga session with RPE 7, 45 min) passes the filter and is processed normally — the nil-handling defaults in the Inputs table above still apply.

**Scope:** This exclusion applies only to Training Load. Streak, Power Level, Weekly Workouts goal, and all other algorithms count these workouts normally.

### Step 1 — Workout Type Modifier
See `CONSTANTS.md` for modifier values per type. These are defined in AppConstants.

### Step 2 — Volume Modifier
For **Strength Training and HIIT** with ExerciseSets:
```
total_sets = sum of `sets` across all ExerciseSets
volume_modifier = clamp(0.5 + (total_sets / 20), min: 0.5, max: 1.5)
```
0 sets → 0.5, 10 sets → 1.0, 20+ sets → 1.5. Uses set count (not tonnage) because bodyweight exercises have nil weight.

For **all other types** (no ExerciseSets): `volume_modifier = 1.0`.

### Step 3 — Per-Session Stress
```
session_stress = RPE × (duration_minutes / 60) × type_modifier × volume_modifier
```
Duration divided by 60 normalizes to hours. Typical session (RPE 7, 60 min, Strength, 10 sets) = 7.0.

### Step 4 — Experience-Based Decay Constant (τ)

| Experience Level | τ (days) | Effect |
|---|---|---|
| Beginner (0) | 3.0 | Stress lingers longest. ~37% remains after 3 days. |
| Intermediate (1) | 2.0 | ~37% remains after 2 days. |
| Advanced (2) | 1.5 | Fastest recovery. ~37% remains after 1.5 days. |

### Step 5 — Time-Decayed Contribution
```
days_ago = (now - workout.date) in fractional days
decayed_stress = session_stress × e^(-days_ago / τ)
```
Uses fractional days — a workout 8 hours ago contributes more than one 20 hours ago.

### Step 6 — Consecutive Training Days Multiplier
Count consecutive calendar days (each with ≥1 qualifying workout — see Pre-Filter above), ending on today or yesterday. If most recent workout was 2+ days ago, `consecutive_days = 0`.
```
consecutive_multiplier = 1.0 + max(consecutive_days - 1, 0) × 0.08
```
Capped at 5+ days:

| Consecutive Days | Multiplier |
|---|---|
| 0 or 1 | 1.00 |
| 2 | 1.08 |
| 3 | 1.16 |
| 4 | 1.24 |
| 5+ | 1.32 (cap) |

### Step 7 — Stress Capacity (Normalization)

| Experience Level | Stress Capacity |
|---|---|
| Beginner (0) | 15 |
| Intermediate (1) | 20 |
| Advanced (2) | 25 |

### Step 8 — Final Score
```
raw_stress = sum of decayed_stress for all workouts in the 10-day window
adjusted_stress = raw_stress × consecutive_multiplier
load_score = clamp((adjusted_stress / stress_capacity) × 100, min: 0, max: 100)
```

### Step 9 — Same-Day Training Floor
Prevents the score from advising "train hard" on a day the user already trained. Only qualifying workouts count (see Pre-Filter above).
```
today_stress = sum of session_stress for all workouts on today's calendar date
               (raw values — no decay, since they are from today)
floor = clamp((today_stress / stress_capacity) × 150, min: 0, max: 80)
load_score = max(load_score, floor)
```
The `× 150` multiplier makes today's sessions count 1.5× for floor purposes. Cap at 80 prevents floor alone from reaching Peak. Floor lifts automatically next day (today_stress = 0 → floor = 0).

### Step 10 — Zone Classification
See `CONSTANTS.md` for zone ranges, colors, and advisory text tables.

### Detail Sheet Helpers (Phase 8.8)

Three pure-read helpers used exclusively by the Training Load Detail Sheet (SCREENS.md § Training Load Detail Sheet). All synchronous reads against the existing 14-day-ish workout set.

```swift
struct TrainingLoadDailyScore: Hashable {
    let date: Date            // calendar-local day boundary (midnight)
    let score: Int            // 0–100, computed via the standard algorithm using that day's window
    let zone: TrainingLoadZone
}

func fourteenDayDailyScores() -> [TrainingLoadDailyScore]
```

- Returns exactly 14 entries (today inclusive), oldest first → most recent last.
- Each entry's score is the algorithm output evaluated as if `today = entry.date`. Effectively a daily replay over the 14-day window.
- Drives the 14-day chart (SCREENS.md § Training Load Detail Sheet → block 2). **Fixed 14-day range — no toggle.**

```swift
struct TrainingLoadContributor: Hashable {
    let workoutId: PersistentIdentifier
    let workoutName: String
    let date: Date
    let tssContribution: Double         // the time-decayed per-session stress this workout adds to today's score
    let percentOfWeeklyLoad: Double     // tssContribution / sum(last7DaysTssContributions) × 100, 0 when divisor is 0
}

func contributingWorkouts(daysBack: Int = 7, limit: Int = 5) -> [TrainingLoadContributor]
```

- Returns up to 5 entries sorted by `tssContribution` descending, ties broken by `date` descending (most recent first).
- Drives the Contributing Workouts block (SCREENS.md § Training Load Detail Sheet → block 3).
- The stress-load (`tssContribution`) per workout is the per-session stress × time-decay factor already computed in `§ Step 5 — Time-Decayed Contribution`. The helper surfaces those intermediates rather than recomputing. Internal field name retains `tss` for code-level continuity; user-facing copy says "stress load" (Phase 8.8 rename).

```swift
struct TrainingLoadWeekComparison {
    let currentWeekTss: Int             // sum of raw session_stress across Mon-through-current-weekday of this ISO week, today inclusive
    let previousWeekTss: Int            // sum of raw session_stress across Mon-through-the-same-weekday of the prior ISO week
    let deltaPct: Int                   // (current - previous) / previous × 100, rounded; 0 when previous == 0
    let matchedDayCount: Int            // inclusive day count of the matched window (1 Mon, 4 Thu, 7 Sun)
}

func weekOverWeekComparison() -> TrainingLoadWeekComparison
```

- Drives the Week-over-Week Comparison band (SCREENS.md § Training Load Detail Sheet → block 4) and the Linked Recovery & Load Detail Sheet's Window Comparison band (SCREENS.md § Linked Recovery & Load Detail Sheet → block 4).
- Uses the same Mon-through-current-weekday window on both sides — Mon–Thu vs Mon–Thu on a Thursday, Mon–Sun vs Mon–Sun on a Sunday. Prevents the partial-week-vs-full-week asymmetry that made a Thursday-morning user see "↑ 420% vs last week" simply because 4 days of stress were being divided by 7 (BUG-066).
- Uses the same ISO Mon definition as `StreakService` (consistency).
- **Sums raw `session_stress`, not the time-decayed `tssContribution`.** Time decay is appropriate for live readiness/fatigue (the Training Load score and the Contributing Workouts breakdown), but applying it to a week-over-week comparison would make the prior week's contributions arbitrarily smaller than the current week's purely because of the 7–13 day age offset relative to `now`, producing absurd deltas (BUG-057). The week-over-week band describes *workload performed*, so it uses the un-decayed per-session stress totals.
- Callers should render `Not enough data` instead of a delta when `matchedDayCount < 2` (early Monday) to avoid showing a single-data-point comparison as a confident delta.

**Cache invalidation:** All three helpers are pure reads. The sheet's ViewModel computes them on appear and re-computes when the Workout Cascade fires while the sheet is presented.

### Settings Change Behavior
Always uses current `experienceLevel` at calculation time. Changing experience recalculates immediately using new τ and stress capacity for all workouts in the 10-day window. No per-workout versioning.

### Sleep-Adjusted Decay (when linked) — Phase 11

When the Recovery Status widget is linked to Training Load (`HomeWidgetService.isLinkedActive(widgets:settings:) == true`), the per-day decay rate (`λ` from Step 5 — Time-Decayed Contribution) is modulated by a per-day **sleep factor** so under-slept days retain more accumulated stress and well-slept days recover normally. When not linked, the algorithm is unchanged — pure baseline decay.

```swift
func computeCurrentScore(workouts: [Workout], sleepData: [DailySleepSnapshot]?, targetSleepHours: Double) -> Int
```

**Sleep factor (per wake-up day d):**

```
sleepRatio(d)  = totalSleepMinutes(d) / 60.0 / targetSleepHours
sleepFactor(d) = clamp(0.60 + 0.40 × min(sleepRatio(d), 1.0), 0.60, 1.0)
```

| Sleep ratio | sleepFactor | Behavior |
|---|---|---|
| `≥ 1.0` (sleep met or exceeded target) | `1.0` | Full normal decay — same as baseline |
| `0.85` | `0.94` | ~6% slower decay |
| `0.5` (half target — e.g., 3.5h of a 7h target) | `0.80` | ~20% slower decay |
| `≤ 0.0` or missing | `0.60` | Floor — 40% slower decay |

Aggressive curve: even moderate sleep loss meaningfully slows recovery, matching the locked-spec design intent.

**Per-workout contribution (modified Step 5):**

For each workout `w` in the 10-day window, baseline contribution is now multiplied across each intervening calendar day:

```
contribution(w, today) = baselineStress(w) × ∏(1 − λ × sleepFactor(d))
                                              d = (log_date + 1) to today
```

Where `λ` is the existing baseline daily decay rate from Step 5 and `sleepFactor(d)` per the formula above. Days without a `DailySleepSnapshot` use `sleepFactor(d) = 1.0` (missing-data fallback — silent, conservative, baseline behavior).

The remaining steps (6 Consecutive-Days Multiplier, 7 Stress Capacity, 8 Final Score, 9 Same-Day Floor, 10 Zone Classification) are unchanged. The score is still clamped to 0–100.

**Recompute triggers** (in addition to existing Workout Cascade triggers): sleep observer fire while linked, linking state change (any input to `isLinkedActive` flips), `targetSleepHours` changes while linked. All recomputes debounced 500ms across triggers — see § Sleep Cascade.

**Animation on link/unlink:** When `isLinkedActive` flips, the displayed score number tweens from baseline → adjusted (or adjusted → baseline) over 0.4s; the gradient bar fill animates in parallel. Reduce Motion: snap. See CONSTANTS.md § Linked Recovery & Load → Animation Timing.

### Daily Snapshot Capture — Phase 11

Persisted `DailyTrainingLoadSnapshot` records back the Trends `trainingLoadTrend` chart and the linked Recovery & Load detail sheet's 14-day TL chart. Historical days render from snapshot values (immutable); today's value is recomputed live on demand.

```swift
struct DailyTrainingLoadSnapshotInputs {
    let date: Date              // calendar-local day boundary (midnight)
    let score: Int              // result of computeCurrentScore() for that date
    let wasSleepAdjusted: Bool  // whether isLinkedActive was true at capture time
}

func captureDailySnapshot(date: Date = .now) -> DailyTrainingLoadSnapshot
```

**Capture triggers:**

| Trigger | Behavior |
|---|---|
| Local midnight rollover (yesterday's score) | App-launch / first-foreground check: if no snapshot exists for yesterday, compute and persist. Idempotent. |
| Workout Cascade (today only) | Recompute today's score and upsert today's snapshot with the current `wasSleepAdjusted` value. Historical snapshots not touched. |
| Sleep Cascade (today only, when linked) | Same as above — recompute and rewrite today's record. |
| Linking state change (today only) | Recompute today's score on the new path (linked or unlinked) and rewrite today's snapshot with the updated `wasSleepAdjusted` value. |
| User changes `targetSleepHours` while linked | Recompute today's score and rewrite today's snapshot. |

**Upsert by date:** primary key is the calendar-local day. New writes for today replace the existing record; historical records are immutable (no rewrite path).

**Reads:**

```swift
func snapshots(for range: DateInterval) -> [DailyTrainingLoadSnapshot]
```

- Returns one snapshot per day in the inclusive range, oldest first.
- Days without a snapshot are returned as nil (caller treats as gap).
- Drives the Trends `trainingLoadTrend` chart (full historical render) and the linked detail sheet's 14-day TL chart.

**Idempotency:** if `captureDailySnapshot()` is called and a snapshot for that date already exists with the same `score` and `wasSleepAdjusted`, no write occurs (avoid SwiftData churn).

---

## Sleep Cascade (Phase 11)

Mirrors the Workout Cascade pattern but for sleep-input changes. Documented separately because inputs and consumers differ — Workout Cascade reads workouts, Sleep Cascade reads `DailySleepSnapshot` records.

**Triggers** (any of these → Sleep Cascade fires):

| Trigger | Source |
|---|---|
| Sleep `HKObserverQuery` fires | `HealthKitSyncService` → `RecoveryStatusService.handleSleepObserverFire()` |
| Sleep catch-up after 6pm local | `HealthKitSyncService` → `RecoveryStatusService.refresh(forceCatchUp: true)` |
| Background refresh task fires | `HealthKitSyncService` (combined workout + sleep refresh) |
| User taps Recovery Status widget → Recovery Status Detail Sheet "Sync Now"-style refresh (if implemented) | View layer |

**Cascade steps:**

1. **Upsert `DailySleepSnapshot` for affected wake-up day(s).** `RecoveryStatusService` aggregates `.asleep*` and `.inBed` samples per HEALTHKIT.md § 21 and writes the snapshot. Most fires touch only today's snapshot; multi-day fires (catch-up backfill) touch a range.
2. **Refresh in-memory 30-day cache** — append/replace the affected day(s).
3. **Refresh Recovery Status widget view-model** — hero value, deep caption, no-sleep-last-night sub-state detection.
4. **If `HomeWidgetService.isLinkedActive(...) == true`:** recompute today's `computeCurrentScore(...)` on the sleep-adjusted path → upsert today's `DailyTrainingLoadSnapshot` (`wasSleepAdjusted = true`) → refresh the Training Load widget's score display and Sleep Impact Chip.
5. **If a detail sheet is currently presented** (unlinked OR linked): the sheet's ViewModel re-fetches `RecoveryStatusService.recent30DaySleep`, `RecoveryStatusService.computeSleepLoadCorrelation()`, `RecoveryStatusService.computePersonalInsights()`, plus (linked only) `ExerciseLoadService.fourteenDayDailyScores(sleepAdjusted: true)`. Re-render in place. Sheets that are not presented do nothing.

**Debounce:** 500ms across all triggers. Implementation: a single `Timer` reset on each trigger; the cascade body runs at the trailing edge. Prevents thrash when HK fires multiple observer callbacks in rapid succession (common at end-of-night when a Watch syncs a long sleep session in chunks).

**No interaction with the Workout Cascade.** The Sleep Cascade does NOT recompute PRs, streak, Power Level, goals, or chart header summaries. Workout-dependent surfaces are untouched. The only overlap is today's `DailyTrainingLoadSnapshot` — both cascades can rewrite it, and the last writer wins (acceptable: the snapshot is a cache, not a source of truth).

---

## Streak Algorithm (StreakService.swift)

**Purpose:** Consecutive-week workout streak driving the streak widget on Home.

**Completed week:** Monday 00:00:00 through Sunday 23:59:59. Completed when workout count in that range ≥ `targetWorkoutsPerWeek`.

**Calculation** (on app launch, after each workout save/edit/delete, and after Settings changes):

1. Start from the most recently completed week (last full Mon–Sun that ended). Walk backward.
2. For each week, count workouts where `workout.date` falls within Mon–Sun.
3. If count ≥ target → counts toward streak; continue to prior week.
4. If count < target → stop. Streak = number of consecutive completed weeks.
5. If current in-progress week already has count ≥ target → add 1 (provisional extension).
6. If `targetWorkoutsPerWeek` is 0 → streak always 0 (dormant state).
7. Update `currentStreak`. If > `longestStreak`, update `longestStreak`.

**Settings change:** Changing target recalculates retroactively for all historical weeks.

**Flame tiers and motivational messages:** See `CONSTANTS.md`.

### Weekly Streak Insights Helpers (Phase 8.8)

Three pure-read helpers used exclusively by the Weekly Streak Insights Sheet (SCREENS.md § Weekly Streak Insights Sheet). All synchronous — they query the existing in-memory workout set; no new persistence.

```swift
struct StreakHeatmapCell: Hashable {
    let weekStartDate: Date     // Monday 00:00:00 (local) of the week
    let workoutCount: Int       // count for that Mon–Sun range
    let target: Int             // snapshot of UserSettings.targetWorkoutsPerWeek at compute time
    var status: Status { /* untracked | belowTarget | targetMet | inProgress (current week only) */ }
}

func fetchHeatmap(weeks: Int = 26) -> [StreakHeatmapCell]
```

- Returns exactly `weeks` cells (default 26 — fixed per SCREENS.md § Weekly Streak Insights Sheet).
- Index 0 = most recent week (the current in-progress week); subsequent indices walk backward in time.
- `status == .untracked` when the week predates the first logged workout (the cell renders as a Card Surface outline per CONSTANTS § Weekly Streak Heatmap → Color Ramp).
- `status == .inProgress` only for index 0; downstream UI applies its outlined treatment.

```swift
struct ThisWeekProgress {
    let currentCount: Int
    let target: Int
    let daysRemainingThisWeek: Int   // 0–6, computed as days until Sunday 23:59 local
}

func thisWeekProgress() -> ThisWeekProgress
```

- Used by the This Week's Progress arc (SCREENS.md § Weekly Streak Insights Sheet → block 3).
- `target` reads live from `UserSettings.targetWorkoutsPerWeek`.

```swift
struct StreakHistorySummary {
    let currentStreak: Int           // mirrors existing currentStreak
    let longestStreakAllTime: Int    // mirrors existing longestStreak
    let totalWeeksLogged: Int        // count of historical weeks where workoutCount >= target (using the target in effect now)
    let unlockedMilestones: [Int]    // subset of CONSTANTS § Weekly Streak Insights → Milestone Marks where currentStreak >= mark
    let nextUnlockedMilestone: Int?  // lowest mark > currentStreak; nil if all unlocked
}

func historySummary() -> StreakHistorySummary
```

- Drives the Stat Row and Milestone Shelf (SCREENS.md § Weekly Streak Insights Sheet → blocks 2 and 5).
- `totalWeeksLogged` walks all historical weeks under the **current** `targetWorkoutsPerWeek` (not historical-target-aware). Intentional simplification — matches how the streak itself is recomputed retroactively on target change.

**Cache invalidation:** All three helpers are pure reads against the workout set; no caching at the service level. The sheet's ViewModel computes them on appear and re-computes when the Workout Cascade fires (§ Workout Cascade).

---

## Power Level Algorithm (PowerLevelService.swift)

**Purpose:** Status (Deloading/Steady/Rising) reflecting average strength volume trend over 30 days vs. prior 30-day baseline. Answers: "Is my training volume trending up, down, or steady?"

**Scope:** Only **Strength Training** and **HIIT** workouts. All others excluded.

### Volume Formula — Per Workout
```
workout_volume = sum of (sets × reps × effective_weight) across all ExerciseSets
```
If `weightKg` is nil (bodyweight): `effective_weight = 1.0`.

### Time Windows

| Window | Range |
|---|---|
| Current period | Today − 30 days through today |
| Baseline period | Today − 60 days through today − 31 days |

Both windows use calendar days, inclusive.

### Step 1 — Current Average
```
current_avg = sum of workout_volume / count of qualifying workouts in current period
```
Empty → `current_avg = 0`.

### Step 2 — Baseline Average
```
baseline_avg = sum of workout_volume / count of qualifying workouts in baseline period
```
Empty → `baseline_avg = 0`.

### Step 3 — Percentage Change
```
If baseline_avg = 0: status = Steady
Else: pct_change = ((current_avg - baseline_avg) / baseline_avg) × 100
```

### Step 4 — Status Classification

| Condition | Status |
|---|---|
| No baseline data (baseline_avg = 0) | Steady |
| No current data (current_avg = 0, baseline > 0) | Deloading |
| pct_change < −10% | Deloading |
| −10% ≤ pct_change ≤ +10% | Steady |
| pct_change > +10% | Rising |

**Contextual messages and indicators:** See `CONSTANTS.md`.

**Edge cases:** < 31 days history → baseline empty → Steady. Zero qualifying workouts in both → "No data" message. Recalculates on workout log/edit/delete.

**No dependency on UserSettings.** Purely data-driven.

### Top Contributing Exercises (Phase 8.8)

Used exclusively by the Power Level Breakdown Sheet (SCREENS.md § Power Level Breakdown Sheet → block 3).

```swift
struct PowerLevelTopExercise: Hashable {
    let exerciseName: String          // case-insensitive normalized; display uses the most recent capitalization observed
    let currentWindowVolume: Double   // sum of workout_volume contributions in the current 30d window for this exercise
    let previousWindowVolume: Double  // same for the previous 30d window
    let deltaPct: Double              // (current - previous) / previous × 100; nil-coalesced to 0 when previous == 0
    let sessionCountInWindow: Int     // number of distinct in-scope workouts containing this exercise in the current 30d window
    let sparkline30d: [Double]        // 30 entries (today inclusive), one per calendar day; days with no session = 0
}

func topContributingExercises(limit: Int = 3) -> [PowerLevelTopExercise]
```

**Rules:**
- Scope: Strength Training + HIIT only (same scope as Power Level itself).
- **≥ 3-session filter:** Exercises with `sessionCountInWindow < 3` are excluded. This prevents single-session outliers from dominating the "what's driving the trend" surface (per Phase 8.8 product decision).
- Returns 0–3 entries. Fewer than 3 surviving the filter is acceptable (UI handles the empty-block state).
- Exercise-name matching is case-insensitive (mirrors the Strength PR auto-update rule, § Strength PR Goals).
- Sort order: descending `currentWindowVolume`, ties broken by descending `sessionCountInWindow`, then by exercise name ascending.

### Window Comparison Computation (Phase 8.8)

Used by the Window Comparison band (SCREENS.md § Power Level Breakdown Sheet → block 4).

```swift
struct PowerLevelWindowComparison {
    let current30dAvg: Double         // current_avg from § Step 1
    let previous30dAvg: Double        // baseline_avg from § Step 2
    let deltaPct: Double              // pct_change from § Step 3 (0 when baseline_avg == 0)
}

func windowComparison() -> PowerLevelWindowComparison
```

Surfaces the same three intermediates the algorithm already computes. The UI hides the block entirely when `current30dAvg == 0` OR `previous30dAvg == 0`.

### Nudge Computation (Phase 8.8)

Calculated, data-driven recommendation surfaced as a single muted line on the Power Level Breakdown Sheet (SCREENS.md § Power Level Breakdown Sheet → block 5). Copy templates live in INFO_COPY § Power Level Nudge Copy — never hardcoded in the service.

```swift
enum PowerLevelNudgeArchetype: String {
    case deloading       // status == .deloading
    case steady          // status == .steady
    case rising          // status == .rising
    case coldStart       // < 3 Strength/HIIT workouts in the current 30d window
    case noBaseline      // ≥ 3 in the current 30d window, but 0 in the prior 30d window
}

struct PowerLevelNudge {
    let archetype: PowerLevelNudgeArchetype
    let inputs: NudgeInputs        // values for the copy template's placeholders (see below)
    var messageKey: String { archetype.rawValue }  // INFO_COPY lookup key
}

struct NudgeInputs {
    // Deloading
    let currentSessionCount30d: Int?   // count of Strength/HIIT workouts in current 30d window
    let previousSessionCount30d: Int?  // same for previous 30d window
    // Steady
    let topExerciseName: String?       // from topContributingExercises().first when present; nil-fallback
    // Rising
    let avgSessionsPerWeek30d: Double? // currentSessionCount30d / (30/7), 1-decimal rounded
}

func computeNudge() -> PowerLevelNudge
```

**Resolution order (cold-start guard runs first, no-baseline guard second):**

1. If `qualifyingWorkoutsInCurrentWindow.count < 3` → `coldStart`. Inputs are all nil. The UI substitutes the cold-start copy verbatim.
2. Else if `qualifyingWorkoutsInPreviousWindow.isEmpty` → `noBaseline`. Populate `currentSessionCount30d` only. Trend percentages can't be computed against an empty baseline, so the sheet must surface the 60-day comparison window limitation explicitly instead of falling into the steady "flat" copy. The corresponding per-exercise rows render an em-dash (`—`) in place of "+0%" whenever `PowerLevelTopExercise.previousWindowVolume == 0`.
3. Else, branch on `status`:
   - `.deloading` → archetype `.deloading`. Populate `currentSessionCount30d` and `previousSessionCount30d`.
   - `.steady` → archetype `.steady`. Populate `topExerciseName` from `topContributingExercises(limit: 1).first?.exerciseName`. **Per-exercise baseline check:** if the cited top exercise's `previousWindowVolume == 0` (i.e., it's brand-new in the current window even though the broader prior window has other workouts), degrade to `noBaseline` so the "Volume on {top} is flat" copy doesn't lie about an exercise that has no comparable prior data. If no exercise passes the ≥ 3-session filter at all, the UI falls back to the cold-start copy with the steady archetype's key — i.e., the message gracefully degrades to *"Log a few more sessions on the same exercises to surface your top drivers."*
   - `.rising` → archetype `.rising`. Populate `avgSessionsPerWeek30d` and `topExerciseName` (best-effort). **Per-exercise baseline check:** if the cited top exercise's `previousWindowVolume == 0`, suppress `topExerciseName` so the copy falls back to `risingNoTop` — calling a brand-new exercise the "biggest gainer" would be inaccurate.

**Triggers:** Recomputed on demand by the sheet (not cached at service level). The Workout Cascade does not need to pre-emptively recompute the nudge — sheet ViewModel handles it on appear and after each cascade fire while the sheet is presented.

**Localization:** Copy templates use `{placeholder}` syntax matched by `String(format:locale:)` or SwiftUI's `LocalizedStringResource` interpolation. All counts and percentages are integers in v1 (no fractional sessions surfaced).

---

## Goal Auto-Update (GoalService.swift)

### Reset Scoping (applies to all auto-updated goal types)
All auto-update scans (Strength PR, Repetitions PR, Speed and Distance) filter workouts against each goal's `resetDate`. A workout is **in-scope** for a goal if any of the following is true:
- `goal.resetDate` is nil (goal has never been reset, or was cleared by editing the goal definition), OR
- `workout.date > goal.resetDate`, OR
- `workout.lastModifiedDate > goal.resetDate` (workout was created or edited after the reset, regardless of its `date` — includes cosmetic edits).

Workouts that are out-of-scope are invisible to the goal's auto-update and to GoalSnapshotService until either the goal is edited (clearing `resetDate`) or the workout is modified (refreshing `lastModifiedDate`). The `lastModifiedDate` bump applies uniformly to ALL workout edits, including cosmetic changes (name, notes, time) — there is no allowlist of "meaningful" fields.

This scoping applies to Weekly Workouts as well in principle, but in practice Weekly Workouts has no "Reset Goal Progress" action (its current value is runtime-derived) so `resetDate` is always nil for that type.

### Strength PR Goals
After each workout save: scan **in-scope** workouts (per § Reset Scoping). For all Strength PR goals, compare title (case-insensitive) against exerciseNames in the in-scope workouts' ExerciseSets. `currentValueKg` is set to the **highest matching weightKg across all in-scope workouts** (best-ever within scope) — not incrementally compared against the prior value. This ensures the ring correctly reflects the current best after edits, deletions, and resets.

On workout deletion: recalculate currentValueKg by scanning all remaining in-scope workouts for highest matching weightKg. No in-scope matches → reset to 0.

Custom-titled goals not matching any exerciseName are never auto-updated.

### Repetitions PR Goals
Same matching logic as Strength PR, but compares `reps` instead of weightKg. `currentReps` is set to the **highest matching reps across all in-scope workouts**. On deletion, recalculates from remaining in-scope data; resets to 0 if no matches.

### Speed and Distance Goals
Auto-updated by matching on **workout type** (e.g., all "Cardio" workouts update linked Speed and Distance goals), scoped to in-scope workouts only (per § Reset Scoping).

Auto-update rule by sub-type (best-ever within scope):
- **Distance-only:** `currentDistanceKm` = highest `distanceKm` across all in-scope matching workouts. No in-scope matches → 0.
- **Duration-only (endurance):** `currentDurationMinutes` = highest `durationMinutes` across all in-scope matching workouts (higher is better per § Goal Progress Calculation). No in-scope matches → 0.
- **Speed-target (both distance and duration set):** Compute each in-scope matching workout's `overallProgress %` using the existing speed target logic (§ Goal Progress Calculation). Select the workout with the highest `overallProgress %` and copy its `distanceKm` → `currentDistanceKm` and `durationMinutes` → `currentDurationMinutes` (take the full workout, never a composite across separate runs). Ties broken by most recent `date`. No in-scope matches → both current values = 0.

On workout deletion or edit affecting matching workouts: recalculate per the rule above across remaining in-scope matching workouts.

### Number of Weekly Workouts Goals
This goal type is a visual tracker that reads its target from `UserSettings.targetWorkoutsPerWeek` and computes its current value at runtime. It does not store target or current values on the Goal model — both are derived:
- **Target:** Read from `UserSettings.targetWorkoutsPerWeek` at display time. If the user changes the target in Settings, the goal card reflects the new target immediately.
- **Current value:** Count of all workouts where `workout.date` falls within the current Monday 00:00:00 – Sunday 23:59:59 week. Uses the same week definition as the Streak algorithm.
- **Progress:** current / target × 100. If target is 0, progress is 0%.
- **Victory:** Achieved when current ≥ target (and target > 0). Resets each Monday when the new week begins.
- **Auto-update:** Recalculates after each workout save, edit, or delete (same triggers as Streak).
- **Singleton:** Only one weeklyWorkouts goal can exist at a time. GoalService enforces this on creation.
- **Deletion:** Deletable like any other goal via the long-press context menu. Deleting it does not affect `targetWorkoutsPerWeek` in Settings or the Streak algorithm.

### Goal Progress Calculation
- **exercisePR:** currentValueKg / targetValueKg × 100
- **repsPR:** currentReps / targetReps × 100
- **speedDistance (distance only):** currentDistanceKm / targetDistanceKm × 100
- **speedDistance (duration only, endurance):** currentDurationMinutes / targetDurationMinutes × 100 (higher = better — "higher is better" endurance semantics)
- **speedDistance (both — speed target):** A speed target means "complete the distance in at or below the duration." Logic:
  - `distanceProgress = clamp((currentDistanceKm / targetDistanceKm) × 100, 0, 100)`
  - `durationProgress`:
    - If `currentDurationMinutes <= targetDurationMinutes` (at or under target time): `durationProgress = 100` (user met or beat the time goal)
    - If `currentDurationMinutes > targetDurationMinutes` (over target time — running too slow): `durationProgress = clamp((targetDurationMinutes / currentDurationMinutes) × 100, 0, 100)`
  - `overallProgress = min(distanceProgress, durationProgress)` — overall progress percentage (used for ring display, sparkline value, and completion check).
  - **Completion:** `currentDistanceKm >= targetDistanceKm` AND `currentDurationMinutes <= targetDurationMinutes`. Beating the target time (running faster than required) still counts as completion.
  - **Example:** Goal is 5 miles in 30 minutes. User runs 5 miles in 20 minutes → distance = 100%, duration = 100% (clamped — user beat the time), overall = 100%, goal completes. User runs 5 miles in 45 minutes → distance = 100%, duration ≈ 67% (30/45), overall = 67%, goal does not complete.

**Note:** The speed target logic (above) applies ONLY when both distance and duration targets are set. Duration-only (endurance) goals continue to use the original "higher is better" logic unchanged.

### Goal Completion Date Tracking
After every goal auto-update, GoalService checks if any goal has crossed 100%. If so:
1. Check `goal.lastCelebratedDate`. If `lastCelebratedDate` is nil or the current date is strictly after `lastCelebratedDate`, proceed; otherwise skip.
2. Set `goal.lastCelebratedDate` to the current date.

This drives the "COMPLETED [date]" micro-label and the Completion Pulse Animation on the Goals screen (see `SCREENS.md` § Goals).

**Re-completion edge case:** If a workout edit causes a goal to drop below 100% and it later crosses 100% again, `lastCelebratedDate` only updates if the new completion date is strictly after the existing value (per step 1 above).

**Trigger paths:** The setter fires from all workout-save cascades — direct workout logging, Plan tab completion (PlanService), and Today's Plan HomeWidget completion. All paths call the same GoalService auto-update logic.

### Reset Goal Progress
Called from the long-press context menu "Reset Goal Progress" option on individual goal cards.
- **exercisePR:** Set `currentValueKg` to 0.
- **repsPR:** Set `currentReps` to 0.
- **speedDistance:** Set `currentDistanceKm` to 0 and `currentDurationMinutes` to 0.
- **weeklyWorkouts:** Not applicable — this goal type derives its current value at runtime. The "Reset Goal Progress" option is hidden for this goal type.
- Set `resetDate` to `.now`. All existing workouts are now out-of-scope for this goal (per § Reset Scoping) until they are edited (refreshing `lastModifiedDate`) or new workouts are logged.
- Clear `lastCelebratedDate` to nil (removes the "COMPLETED [date]" label and allows the Completion Pulse to re-fire if the goal is achieved again).
- **Wipe GoalSnapshot history:** Delete all GoalSnapshot records for this goal via `GoalSnapshotService.deleteSnapshots(goalId:)`. The sparkline restarts from scratch — it will show the brand-new skeleton state until new in-scope workouts generate snapshots. Do NOT append a zero-valued snapshot.

**Clearing `resetDate`:** `resetDate` is cleared to nil when the user edits the goal definition via the Add/Edit Goal flow (e.g., changing target weight, target distance, exercise name). Editing the goal is treated as a deliberate re-baselining action — pre-reset workouts come back into scope. `resetDate` is not cleared by any other path; workout edits alone do not clear it (they just bump `lastModifiedDate` on the workout, which re-scopes that specific workout).

---

## Deletion Cascading Behavior

### Workout Cascade (shared definition)

Any time a workout is logged, edited, deleted, or batch-deleted via workout type deletion, the following cascade runs against the resulting workout set. HealthKit import (auto-create or link — see HEALTHKIT.md § 10, § 12) and HealthKit upstream update (see § HealthKit Upstream Update below) route through the same cascade entry points (`WorkoutService.log()` and `WorkoutService.update()` respectively) — there is no separate HealthKit cascade. Individual cascade sections below reference this block rather than restating it.

**Recalculations:**
- **PR timeline** — remove unsupported PRs; recompute from remaining data.
- **Training Load score** — remove affected workouts from the 10-day window; `consecutive_days` may change.
- **Home screen** — Recent Workouts list, Training Load widget, Today's Plan widget refresh. **Activity Rings widget** refreshes only when the workout has `healthKitUUID != nil` (manual logs can't have changed HK daily totals — see § AppleActivityService).
- **Charts** — Strength Tracker reflects current state; Training Frequency re-counts affected week(s); every chart card's header summary value (and Workout Type Breakdown's donut center label) recomputes per § TrendsChartService → Header Summary Computation.
- **Goal auto-update** — recompute Strength PR (`currentValueKg`), Reps PR (`currentReps`), and Speed/Distance (`currentDistanceKm` + `currentDurationMinutes`) per § Goal Auto-Update across remaining in-scope workouts. No in-scope matches → reset to 0.
- **GoalSnapshot records** — recompute snapshots on affected date(s) per § GoalSnapshotService. If no in-scope matching workouts remain on a given date, delete that goal's snapshot for that date.
- **Weekly streak** — recalculate across affected weeks.
- **Power Level** — recalculate if Strength Training or HIIT was involved.
- **Workout Type card** — update count. If last workout of a type is gone, remove the card and delete the WorkoutTypeOrder record.
- **Scheduled workout linkage** — if the deleted workout's ID matches any `ScheduledWorkout.completedWorkoutId`, null that field and revert status to "planned". If the reverted `ScheduledWorkout` had `syncToAppleWatch == true` and gates still pass, `WatchScheduleService.schedule(_:)` is called to re-register the plan on Watch (the user will probably want to redo the session).
- **Widget Detail Sheet derived data (Phase 8.8)** — when any of the four new detail sheets (Today's Plan, Training Load, Weekly Streak, Power Level) is currently presented, its ViewModel re-fetches its helpers (`StreakService.fetchHeatmap`, `StreakService.thisWeekProgress`, `StreakService.historySummary`, `ExerciseLoadService.fourteenDayDailyScores`, `ExerciseLoadService.contributingWorkouts`, `ExerciseLoadService.weekOverWeekComparison`, `PowerLevelService.topContributingExercises`, `PowerLevelService.windowComparison`, `PowerLevelService.computeNudge`, `PlanService.fetchTodaysScheduledWorkouts`) and re-renders. No caching at the service level; ViewModels recompute on each cascade fire while presented. Sheets that are not presented do nothing — no global recompute.
- **`DailyTrainingLoadSnapshot` for today (Phase 11)** — after the Training Load score recomputes, `ExerciseLoadService.captureDailySnapshot()` upserts today's `DailyTrainingLoadSnapshot` with the new score and the current `wasSleepAdjusted` flag (true iff `HomeWidgetService.isLinkedActive(widgets:settings:) == true` at capture time). Historical snapshots are immutable — only today's record is rewritten by cascade. Powers the Trends `trainingLoadTrend` chart and the linked Recovery & Load detail sheet's 14-day TL chart. See § Training Load Algorithm → Daily Snapshot Capture.
- **Recovery Status widget (Phase 11)** — the widget's timer line bumps on every cascade (the time-since-last-workout calculation depends on the latest workout's date). The widget hero block (`SLEEP {h}h {mm}m`) does **not** refresh — sleep inputs flow through the Sleep Cascade, not the Workout Cascade. The `Workout.lastModifiedDate` change does trigger `RecoveryStatusService.refreshTimerLine()` for any presented widget instance.
- **Linked Recovery & Load detail sheet (Phase 11)** — when presented, the sheet's ViewModel re-fetches `ExerciseLoadService.fourteenDayDailyScores(sleepAdjusted: true)`, `RecoveryStatusService.recent30DaySleep`, `RecoveryStatusService.computeSleepLoadCorrelation()`, and `RecoveryStatusService.computePersonalInsights()`.
- **Sleep Impact Chip on Training Load widget (Phase 11)** — recomputes only when linked. If `isLinkedActive == false`, the chip is hidden and no recompute fires. The chip value derives from `currentLinkedScore - whatBaselineWouldBe`, both of which depend on the same workout inputs that just changed.

### Workout Deletion
Apply the Workout Cascade to remaining data.

### Workout Edit
Apply the Workout Cascade to updated data. Additionally, **every workout edit sets `workout.lastModifiedDate = .now`** regardless of which fields changed (including cosmetic edits to name, notes, or time). This refreshes the workout's scope against any goal `resetDate` per § Reset Scoping.

Edit-specific notes:
- **Date changed** — the cascade runs against both the old and new `workout.date` (Training Frequency hits both weeks; GoalSnapshot recomputes both the old-date and new-date snapshots).
- **Cosmetic-only change** (name/notes/time with no value-affecting fields) — `lastModifiedDate` still bumps, which re-scopes the workout against any goal `resetDate` and triggers full goal auto-update and snapshot recalc. No Training Load / chart recalc beyond this.

### Workout Type Deletion
When a workout type is deleted via the context menu, ALL workouts of that type are deleted in a single batch operation. Apply the Workout Cascade as a batch across every deleted workout, plus:
- All ExerciseSets across all deleted workouts are cascade-deleted from SwiftData.
- The WorkoutTypeOrder record for the deleted type is removed; the Workout Type card disappears from the Workouts screen.
- Remaining WorkoutTypeOrder records do NOT re-index `sortOrder` — the gap is acceptable; relative order preserved.
- Any linked ScheduledWorkout slots revert to "planned" (via the Workout Cascade's Scheduled workout linkage rule).

### Goal Deletion
Remove goal from SwiftData. Cascade-delete all associated GoalSnapshot records (matching goalId). Re-index remaining goals' sortOrder.

### Template Deletion
Remove WorkoutTemplate + all TemplateExerciseSets (cascade). No effect on any other data.

### Widget Deletion
Remove HomeWidget record only. No underlying data affected. Widget re-addable via Add Widget menu. Remaining widgets re-index sortOrder.

### Chart Deletion
Remove TrendsChart record only. No underlying data affected. Chart re-addable via Add Charts menu. Remaining charts re-index sortOrder. Identical behavior to Widget Deletion.

### Scheduled Workout Deletion
Remove `ScheduledWorkout` record. **If `appleWorkoutPlanId != nil`, also call `WatchScheduleService.removePlan(_:)` to clear any Watch-side registration before deletion** (Phase 8.7+; see WORKOUTKIT.md § 12). The UUID is wiped along with the record. No effect on any other data (no Workout is created until completion). For recurring workouts, "Remove from Plan → This and future" removes this instance and all future instances sharing the same `recurrenceGroupId` — each with a separate `removePlan` call if synced — past completed/skipped instances are preserved.

**Completed scheduled workout removed via Plan ("Remove from Plan" dual-action):** The `ScheduledWorkout` record is deleted AND the linked `Workout` has `hiddenFromPlan` set to `true`. See SERVICES.md § PlanService → Remove from Plan for full semantics. The underlying `Workout` is otherwise unaffected — all cascades (PR, Training Load, streaks, goals, charts) continue to include it.

### Workout Hide from Plan (hiddenFromPlan flag)
`hiddenFromPlan` is a pure display flag on the `Workout` model. Setting or clearing it **does not trigger any cascade** — PR timelines, Training Load, streaks, Power Level, goals, GoalSnapshot records, and all charts are unaffected. The flag exclusively controls whether the `Workout` surfaces on the Plan screen (see SERVICES.md § PlanService → Retrieval → Fetch Plan surface). No cascade recalculations are needed when the flag changes.

### HealthKit Auto-Create / Link
When `WorkoutMatcher` returns a high-confidence match (auto-link) or when no match exists and `HealthKitSyncService` creates a new `Workout` from an HK import (auto-create), the Workout Cascade fires via `WorkoutService.log()`. See HEALTHKIT.md § 10, § 12. No HK-specific cascade rules beyond the shared definition — all algorithms recalculate exactly as they would for any manually logged workout.

### HealthKit Upstream Update
HK-linked workout's HK-owned fields changed upstream (e.g., duration edited in the Health app) → apply via `WorkoutService.update()`. HK wins on HK-owned fields, user-owned fields untouched (see HEALTHKIT.md § 7 for the ownership list). Bump `lastModifiedDate = .now`; fire full Workout Cascade. Date-change rule from § Workout Edit applies.

### HealthKit Upstream Delete
`deletedObjectHandler` fires for an HK workout matching an existing `Workout.healthKitUUID`:

1. Clear the three HK pointer fields (`healthKitUUID`, `healthKitSourceBundleID`, `healthKitActivityType`) to nil.
2. Retain all HK-sourced numeric values as-is — workout is promoted to manual, fields become editable.
3. Bump `lastModifiedDate = .now` (re-scopes against goal `resetDate` per § Reset Scoping).
4. **Do NOT fire the deletion cascade** — this is a promotion to manual, not a delete.

See HEALTHKIT.md § 11 for rationale. Non-destructive: user keeps training history even if they clean up HK upstream.

### HealthKit Unlink (user-initiated, one-way, destructive on summary data)
Triggered from Workout Detail's ellipsis menu or the source indicator info sheet. Always gated by `.confirmationDialog` (HEALTHKIT.md § 14).

1. Capture `healthKitUUID` into a local.
2. Clear the three HK pointer fields to nil (`healthKitUUID`, `healthKitSourceBundleID`, `healthKitActivityType`).
3. **Clear the six HK-only summary fields** to nil: `avgHeartRate`, `maxHeartRate`, `activeEnergyKcal`, `totalEnergyBurnedKcal`, `elevationAscendedMeters`, `exerciseMinutes`.
4. **Conditionally clear `rpe`:** if `workout.rpeFromHK == true`, set `rpe = nil`. Set `rpeFromHK = false` regardless.
5. Retain `durationMinutes`, `distanceKm`, `date`, `time`, `indoor`, `name`, `note`, and `ExerciseSets` as-is — they have manual-entry paths or are user-owned.
6. Bump `lastModifiedDate = .now`.
7. **Fire the full Workout Cascade** (see § Workout Cascade). Effort Trend points, Training Load (if `rpe` was cleared), Power Level, header summary, and GoalSnapshot recompute. Behavior change from prior spec.
8. **Write a `WorkoutMatchRejection`** with `(healthKitUUID: capturedUUID, workoutId: workout.id, reason: .unlinked)`. Makes unlink one-way — matcher will skip this `(uuid, workoutId)` pair forever. Re-import of the same HK UUID auto-creates a new workout; auto-link to *this* FitNavi workout is short-circuited.

Contrast with § HealthKit Upstream Delete: upstream delete retains measurements and does NOT fire the cascade because it's non-destructive (the workout promotes to manual without losing data). Unlink is the destructive path — the user explicitly confirmed via the dialog.

See HEALTHKIT.md § 14 for full rationale and copy.

---

## WorkoutService (WorkoutService.swift)

CRUD wrapper for workouts via SwiftData:
- **Log:** Create workout + ExerciseSets. Set `workout.lastModifiedDate = .now`. Trigger PR recalculation and goal auto-update. **Dual entry point:** also called by `HealthKitSyncService` on HK import (auto-create path, after `WorkoutMatcher` returns no match) and by `WorkoutMatcher` on auto-link (applies HK-owned field values from the HK record to an existing manual workout). On the manual-log path, call `WorkoutMatcher.findMatch(forNewManualWorkout:)` immediately after save — if a high-confidence match exists, auto-link; if a lower-confidence match exists, queue for prompt; otherwise proceed normally. See HEALTHKIT.md § 11, § 12.
- **Retrieve:** Sorted by date (newest first).
- **Update:** Full workout (name, date, time, RPE, duration, distance, add/modify/delete ExerciseSets). Set `workout.lastModifiedDate = .now` on every update regardless of which fields changed (including cosmetic edits — see § Workout Edit cascade). Trigger PR recalc and goal auto-update. **HK-linked workouts:** when `workout.healthKitUUID != nil`, `durationMinutes`, `distanceKm`, and `date` are read-only at the UI layer (see SCREENS.md § Log Workout). Update must still tolerate these values being non-nil (they are populated by HK sync, not the user). HK upstream updates flow through this same method — see § HealthKit Upstream Update.
- **Update notes:** Inline note edit. Sets `workout.lastModifiedDate = .now` (cosmetic edit per § Reset Scoping).
- **Delete:** Cascade-delete all ExerciseSets. Trigger all cascading recalculations (see Deletion Behavior above). If the deleted workout is linked to a `ScheduledWorkout` (via `completedWorkoutId`), notify PlanService to revert that slot to "planned". **HK-linked workouts delete normally** — deletion removes the FitNavi record but does not propagate to HealthKit (no write-back in MVP). Orphan `WorkoutMatchRejection` records pointing at the deleted workout are retained; harmless.
- **Delete all for type:** Accept a workoutType string, fetch all workouts matching that type, cascade-delete each with ExerciseSets, then trigger all cascading recalculations once (see Workout Type Deletion above). Remove the corresponding WorkoutTypeOrder record. Revert any linked ScheduledWorkout slots to "planned".
- **Unlink (HK-linked workouts):** Invoked via Workout Detail's ellipsis menu or the source indicator info sheet. Clears the three HK pointer fields and the six HK-only summary fields, conditionally clears `rpe` based on `rpeFromHK`, fires the Workout Cascade, and writes a `WorkoutMatchRejection`. See § HealthKit Unlink for the full ordered sequence.

---

## HealthKitClient (HealthKitClient.swift)

**Purpose:** Protocol abstraction over Apple's HealthKit framework. All HealthKit access in FitNavi goes through this protocol. The concrete implementation (`DefaultHealthKitClient`) is the only file in the codebase that imports `HealthKit`. Integration tests inject `StubHealthKitClient` from `TestFixtures.swift` instead (see TESTING.md § HealthKit Test Strategy).

See HEALTHKIT.md § 4 for the architectural rationale.

### Protocol Surface

The protocol defines the following operations (exact Swift signatures to be finalized by Claude Code; shape documented here):

| Operation | Purpose |
|---|---|
| `requestAuthorization() async throws` | Invoke Apple's authorization prompt with the read permission list. See HEALTHKIT.md § 17. |
| `authorizationStatus() → HealthKitAuthorizationStatus` | Returns one of: `.notDetermined`, `.granted`, `.denied`. Used by Settings to render the status line. |
| `fetchWorkouts(since anchor: HKQueryAnchor?) async throws → (workouts: [HKWorkoutSnapshot], deletedUUIDs: [UUID], newAnchor: HKQueryAnchor)` | Anchored query returning workouts added or modified since the anchor, plus a list of UUIDs for workouts deleted upstream. Drives catch-up-on-launch and live sync. |
| `observeWorkoutChanges(handler: @escaping () → Void)` | Register an `HKObserverQuery` with `enableBackgroundDelivery`. Handler fires (on a background thread) when HK has new or changed workout data. `HealthKitSyncService` hops to `@MainActor` before acting. |
| `fetchEffortScore(for hkWorkoutUUID: UUID) async throws → Int?` | Query the user-entered `workoutEffortScore` sample related to an HK workout. Returns nil if no user-entered score exists. Ignores `estimatedWorkoutEffortScore`. iOS 18+ only — gated `if #available(iOS 18, *)`. See HEALTHKIT.md § 8. |
| `sourceName(for bundleID: String) → String` | Resolves an `HKSource` bundle ID to a clean human-readable name. **Never returns a raw bundle ID.** Resolution rules: (1) Apple Watch source bundle → `"Apple Workout"` (rebrand from "Apple Watch"). (2) Other recognized sources → their `HKSource.name` value (e.g., `"Strava"`, `"Peloton"`). (3) Unrecognized / unresolvable bundle IDs → `"another app"` (graceful fallback). Used by the Workout Detail source indicator (inline format `{healthKitActivityType} · {sourceName} [glyph]`) and the Source Indicator Info Sheet body copy (`This workout was imported from Apple Health via {sourceName}.`). The caller never has to handle nil; the fallback string is always serviceable in either rendering surface. See SCREENS.md § Workout Detail → Source Indicator. |
| `fetchSleepSamples(from start: Date, to end: Date) async throws → [HKSleepSampleSnapshot]` (Phase 11) | Anchored query for `HKCategoryTypeIdentifierSleepAnalysis` samples in the range. Returns one `HKSleepSampleSnapshot` per sample (struct mirroring the same protocol-boundary pattern as `HealthKitWorkoutSnapshot` — see below). Includes all stage values (`.asleepDeep`, `.asleepREM`, `.asleepCore`, `.asleepUnspecified`, `.awake`, `.inBed`) so `RecoveryStatusService` can compute durations, efficiency, and the stages bar without re-querying. See HEALTHKIT.md § 21. |
| `observeSleepChanges(handler: @escaping () → Void)` (Phase 11) | Register an `HKObserverQuery` with `enableBackgroundDelivery` for `HKCategoryTypeIdentifierSleepAnalysis`. Handler fires on a background thread; `RecoveryStatusService` hops to `@MainActor` before any SwiftData write. Same pattern as `observeWorkoutChanges`. |
| `fetchSleepDurationGoal() async throws → TimeInterval?` (Phase 11) | Protocol method retained for forward compatibility, but HealthKit does not expose a `sleepDurationGoal` characteristic in its public API (BUG-048 — only `activityMoveMode`, `biologicalSex`, `bloodType`, `dateOfBirth`, `fitzpatrickSkinType`, `wheelchairUse` are public). The concrete implementation returns `nil` unconditionally. Called only from the "Import from Apple Health" action in the Recovery Status Settings Modal (see § RecoveryStatusService → Sleep Goal Import); the consumer always emits the documented "No sleep goal set in Apple Health." toast. |
| `hasRecentSleepData(within days: Int = 14) async throws → Bool` (Phase 11) | Cheap aggregate over sleep-analysis samples scoped to the lookback window. Returns true on the first `.asleep*` match. Drives the Recovery Status widget's `live` vs `noSleepTracker` gating decision (see SCREENS.md § Home Screen → Recovery Status → States). |

### HealthKitWorkoutSnapshot

A plain Swift struct (not an `HKWorkout`) containing exactly the fields FitNavi cares about. Returned by `fetchWorkouts`. Keeps the protocol boundary free of Apple framework types so the stub and tests don't need to construct real `HKWorkout` instances.

Fields: `uuid`, `activityTypeRawValue`, `activityTypeDisplayString`, `sourceBundleID`, `startDate`, `endDate`, `durationMinutes`, `distanceKm?`, `avgHeartRate?`, `maxHeartRate?`, `activeEnergyKcal?`, `totalEnergyBurnedKcal?`, `elevationAscendedMeters?`, `exerciseMinutes?`, `indoor?`, `isDeleted` (flag indicating this entry represents an upstream delete rather than an addition/update).

### HKSleepSampleSnapshot (Phase 11)

A plain Swift struct returned by `fetchSleepSamples(from:to:)`. Same protocol-boundary pattern as `HealthKitWorkoutSnapshot` — keeps `HKCategorySample` out of consumer code.

Fields: `uuid`, `stage` (enum: `.asleepDeep` / `.asleepREM` / `.asleepCore` / `.asleepUnspecified` / `.awake` / `.inBed`), `startDate`, `endDate`, `durationSeconds` (computed: `endDate - startDate` as raw `TimeInterval`; aggregation must sum these and round once at the very end — see BUG-052), `sourceBundleID`, `isDeleted`.

`RecoveryStatusService` consumes these snapshots and produces one `DailySleepSnapshot` per wake-up date (see HEALTHKIT.md § 21 for aggregation rules).

### Rules

- **No other service imports `HealthKit`.** Only `DefaultHealthKitClient` does. Enforced by convention in code review and by TESTING.md § HealthKit Test Strategy.
- **Threading is the client's contract.** The protocol methods may be called from any actor. The concrete implementation marshals internal HK framework calls appropriately. Callers assume results are returned on the calling actor.
- **Authorization is fire-and-forget.** `requestAuthorization()` completes when the user responds to the iOS prompt. The client does not cache the result — callers re-query `authorizationStatus()` as needed.

---

## HealthKitSyncService (HealthKitSyncService.swift)

**Purpose:** Orchestrate the full HealthKit sync lifecycle — authorization, catch-up queries on launch, live observer queries, background refresh, upstream updates, upstream deletes, and manual "Sync Now" from Settings. Routes imports through `WorkoutMatcher` and ultimately through `WorkoutService.log()` / `update()` so the full Workout Cascade fires on every imported change.

See HEALTHKIT.md § 9 for the sync lifecycle overview.

### Responsibilities

- Own the `HKQueryAnchor` persisted in UserDefaults (`UserSettings.healthKitAnchor`).
- Register the `HKObserverQuery` with `enableBackgroundDelivery` on launch (Phase 2 only — see HEALTHKIT.md § 3 Phases).
- **Phase 11:** Register a second `HKObserverQuery` for `HKCategoryTypeIdentifierSleepAnalysis` alongside the workout observer. Sleep observer is registered only when `UserSettings.healthKitEnabled == true` AND sleep scope is granted. Callbacks fire on a background thread; the handler calls `RecoveryStatusService.handleSleepObserverFire()` after hopping to `@MainActor`. See HEALTHKIT.md § 21.
- Register the `BGAppRefreshTask` handler on launch (Phase 2). **Phase 11:** the single `BGAppRefreshTask` handler now performs both workout sync AND sleep sync — no second task identifier. On fire, the handler runs `importPendingWorkouts()` followed by `RecoveryStatusService.refreshFromBackground()` so morning app opens have fresh data without a spinner.
- Run a catch-up anchored query on every cold launch and foreground transition (Phase 1 — mandatory).
- **Phase 11:** Run a 6pm-cutoff sleep catch-up on the first `scenePhase == .active` after local 6pm regardless of sleep observer activity — bridges any missed background fires. Single `lastSleepCatchUpDate` UserDefaults entry guards against double-firing within the same 6pm window.
- On each sync event: fetch workouts since anchor, process each via `importPendingWorkouts()`, update anchor on success.
- Update `UserSettings.healthKitLastSyncDate` to `.now` after each successful sync.
- Expose `lastSyncDate(for workout: Workout) -> Date?` — returns the most recent sync timestamp at which the workout's HK record was observed (read from `UserSettings.healthKitLastSyncDate`, scoped to the workout's `healthKitUUID`). Used by the Source Indicator Info Sheet's "Last synced · {relative}" footer row (see SCREENS.md § Workout Detail → Source Indicator Info Sheet). Returns nil for workouts that have never synced.

### Triggers

| Source | Phase | Behavior |
|---|---|---|
| App launch (cold) | 1 | Run catch-up anchored query. |
| App foreground transition | 1 | Run catch-up anchored query. |
| Manual "Sync Now" button in Settings | 1 | Run catch-up anchored query immediately. |
| `HKObserverQuery` fires | 2 | Run anchored query on background thread, marshal to `@MainActor` for SwiftData writes. |
| `BGAppRefreshTask` executes | 2 | Run anchored query; update anchor; complete task. |
| `UserSettings.healthKitEnabled` flipped off | 1 | Cancel any in-flight queries. Retain anchor (for re-enable). Existing linked workouts unchanged — see HEALTHKIT.md § 16. |
| `UserSettings.healthKitEnabled` flipped on (first time) | 1 | Call `client.requestAuthorization()`. On grant, run catch-up. On deny, update Settings status line. |
| Sleep `HKObserverQuery` fires (Phase 11) | 11 | Marshal to `@MainActor`, call `RecoveryStatusService.handleSleepObserverFire()` (refresh today's `DailySleepSnapshot`, fire Sleep Cascade). Workout matcher does NOT run. |
| `BGAppRefreshTask` executes (Phase 11 update) | 2 + 11 | Existing workout `importPendingWorkouts()` runs first; then `RecoveryStatusService.refreshFromBackground()` runs to fetch any pending sleep samples and fire the Sleep Cascade if today's snapshot changed. |
| First `scenePhase == .active` after local 6pm (Phase 11) | 11 | Run sleep catch-up via `RecoveryStatusService.refresh(forceCatchUp: true)`. Guarded by `lastSleepCatchUpDate` to prevent re-firing within the same 6pm window. |
| Sleep scope first granted via iOS prompt (Phase 11) | 11 | Register the sleep observer (was suppressed prior to grant) and run an immediate full sleep catch-up to backfill `DailySleepSnapshot` records for the last 30 days. |

### Import Pipeline (`importPendingWorkouts()`)

For each `HealthKitWorkoutSnapshot` returned by the anchored query:

0. **Plan-ID Fast-Path (Phase 8.7+).** If `snapshot.workoutPlanId` is present (populated via `HKWorkout.workoutPlan?.id`, a WorkoutKit async extension), query `PlanService.findByPlanId(_:)` for a `ScheduledWorkout` with matching `appleWorkoutPlanId`. If found AND the matched `ScheduledWorkout.status == "planned"` AND no FitNavi `Workout` already exists with `healthKitUUID == snapshot.uuid`, route through `PlanService.completeFromWatch(scheduledWorkout:hkSnapshot:)` and skip the matcher entirely. See WORKOUTKIT.md § 8 for full mechanics. If the matched `ScheduledWorkout` is already completed/skipped, or if the plan ID doesn't resolve, fall through to the standard pipeline (Steps 1–4) — better to create a duplicate manual workout than silently overwrite a completed slot.
1. **If `snapshot.isDeleted == true` → Upstream Delete handler.** Find the FitNavi `Workout` with matching `healthKitUUID`. If found, apply § HealthKit Upstream Delete rules (null out pointer fields, bump `lastModifiedDate`, no cascade). If not found, no-op.
2. **Else if a FitNavi `Workout` exists with `healthKitUUID == snapshot.uuid` → Upstream Update handler.** Apply § HealthKit Upstream Update rules via `WorkoutService.update()`. HK wins on HK-owned fields; user-owned fields untouched. Full cascade fires.
3. **Else (new HK workout) → Matcher path.** Call `WorkoutMatcher.findMatch(forIncomingHKWorkout: snapshot)`. Three possible outcomes:
   - **High-confidence match:** matcher auto-links the snapshot to the existing FitNavi `Workout` (see WorkoutMatcher § Link Application below). No new `Workout` created.
   - **Lower-confidence match:** matcher queues the pairing for the Match Prompt Sheet. No new `Workout` created yet. Pairing waits for user decision.
   - **No match:** proceed to step 4.
4. **Auto-create.** If `snapshot.durationMinutes < 2`, skip entirely (minimum-duration floor — see HEALTHKIT.md § 9). Otherwise, build a new `Workout` with the default field values from HEALTHKIT.md § 10 and route through `WorkoutService.log()`. Full cascade fires.

After processing all snapshots, persist the new anchor to `UserSettings.healthKitAnchor` and update `healthKitLastSyncDate`.

### Effort Score Handling (iOS 18+)

After auto-create or link, if `rpe` is nil and the device is iOS 18+, call `client.fetchEffortScore(for: healthKitUUID)`. If a non-nil result is returned, set `workout.rpe = result`. Never overwrites a user-entered RPE (see HEALTHKIT.md § 8). Runs as part of the same cascade — subsequent Training Load, goal auto-update, and snapshot recalculations see the populated RPE.

### Threading

All `WorkoutService` and `ModelContext` calls execute on `@MainActor`. Observer query callbacks (background thread) marshal via `await MainActor.run { ... }` before any SwiftData write. Anchored query fetches may run on a background thread; only the import pipeline's write step is main-bound.

### Error Handling

- **Authorization denial:** no workouts imported. Settings status line shows "Permission denied in iOS Settings" with deep-link button.
- **Anchored query failure:** log to `BUGS.md` if recurring. Retry on next trigger. Anchor not updated on failure (next sync re-attempts from the last good anchor).
- **Individual snapshot processing failure:** log, skip that snapshot, continue processing remaining snapshots. Do not abort the full sync for a single bad record.


---

## WorkoutMatcher (WorkoutMatcher.swift)

**Purpose:** Bidirectional deduplication between HealthKit-imported workouts and manually logged FitNavi workouts. Determines whether an incoming workout should be auto-linked to an existing record, prompt the user for resolution, or proceed as a separate record.

See HEALTHKIT.md § 12 for the architectural overview.

### Entry Points

Single service, called from two places:

| Caller | Method | When |
|---|---|---|
| `HealthKitSyncService.importPendingWorkouts()` | `findMatch(forIncomingHKWorkout: HealthKitWorkoutSnapshot) → MatchResult` | Before auto-creating a new `Workout` from an HK import. |
| `WorkoutService.log()` | `findMatch(forNewManualWorkout: Workout) → MatchResult` | Immediately after saving a manual workout. |

Both methods apply the same matching rules. Differences:
- HK-side match returns candidate `Workout` IDs to link the incoming snapshot to.
- Manual-side match returns candidate `HealthKitWorkoutSnapshot`s (from the current HK candidate pool) to link the just-saved Workout to.

### MatchResult

Enum with three cases:

| Case | Meaning | Next Step |
|---|---|---|
| `.highConfidence(matchedWorkoutId)` / `.highConfidence(matchedSnapshot)` | Overlapping time windows, same FortiFit type. | Caller auto-links immediately. |
| `.lowerConfidence(candidateId)` / `.lowerConfidence(candidateSnapshot)` | Same FortiFit type, same calendar day, non-overlapping, start times within 4 hours. | Caller queues a pending match for the Match Prompt Sheet. |
| `.noMatch` | Outside both windows, or different FortiFit type, or different calendar day. | Caller proceeds with auto-create or keeps the manual log as-is. |

### Matching Rules

**High-confidence (auto-link):**
- Same FortiFit `workoutType` (after HK-to-category mapping for the HK side — see HK_MAPPING.md).
- `|startA − startB| ≤ 5 minutes` AND `|endA − endB| ≤ 5 minutes`.

**Lower-confidence (prompt):**
- Same FortiFit `workoutType`.
- Same calendar day.
- Time windows do NOT overlap (per the high-confidence rule above — if they overlap, it's high-confidence, not lower).
- `|startA − startB| ≤ 4 hours`.

**No match:**
- Any of the above conditions fail.
- Note: same-day same-type workouts MORE than 4 hours apart (typical AM+PM splits) are expected to be separate records. No prompt. See HEALTHKIT.md § 12.

### Rejection Check

Before returning `.highConfidence` or `.lowerConfidence`, query for an existing `WorkoutMatchRejection` with matching `(healthKitUUID, workoutId)`. If found, return `.noMatch` instead.

Rejection lookup is by UUID pair, not by `@Relationship`. Orphan rejections (created when a linked `Workout` is deleted) are harmless and retained — see PRD.md § Data Model (WorkoutMatchRejection).

### Link Application

When a caller receives `.highConfidence` and performs auto-link (or when the user taps "Link these workouts" in the Match Prompt Sheet), `WorkoutMatcher.applyLink(workout:snapshot:)` performs:

1. Set `workout.healthKitUUID = snapshot.uuid`.
2. Set `workout.healthKitSourceBundleID = snapshot.sourceBundleID`.
3. Set `workout.healthKitActivityType = snapshot.activityTypeDisplayString`.
4. Apply HK-owned field values from `snapshot`:
   - `workout.date = snapshot.startDate`
   - `workout.durationMinutes = snapshot.durationMinutes`
   - `workout.distanceKm = snapshot.distanceKm` (if snapshot has it)
   - `workout.avgHeartRate`, `workout.maxHeartRate`, `workout.activeEnergyKcal`, `workout.totalEnergyBurnedKcal`, `workout.elevationAscendedMeters`, `workout.exerciseMinutes`, `workout.indoor` — all copied from snapshot.
5. User-owned fields (`name`, `note`, `time`, `ExerciseSets`, `rpe`) are NOT touched.
6. Bump `workout.lastModifiedDate = .now`.
7. Fire Workout Cascade via `WorkoutService.update()` (measured-field changes may affect Training Load, goals, snapshots).

On iOS 18+, after link, run the effort-score nil-fill step (see HealthKitSyncService § Effort Score Handling).

### Prompt Queue

Lower-confidence matches are queued via `WorkoutMatcher.queuePendingMatch(workoutId:snapshot:)`. The queue is a simple in-memory list (non-persistent — acceptable because pending matches re-surface on next sync if unresolved). Match Prompt Sheet UI drains the queue on foreground (see HEALTHKIT.md § 13).

Queue API: `pendingMatches()`, `resolvePending(workoutId: UUID, snapshot: HealthKitWorkoutSnapshot, decision: MatchDecision)` where `MatchDecision` is `.link` / `.keepSeparate` / `.decideLater`.

- `.link` → apply link via `applyLink(workout:snapshot:)`; remove from queue.
- `.keepSeparate` → create a `WorkoutMatchRejection(healthKitUUID: snapshot.uuid, workoutId: workoutId, rejectedDate: .now)`; remove from queue.
- `.decideLater` → leave in queue; re-surface on next foreground.


---

## WorkoutMetricService (WorkoutMetricService.swift)

**Purpose:** Read-only aggregate query layer powering the Workout Detail Metric Detail Sheet (see SCREENS.md § Workout Detail → Metric Detail Sheet). Provides three operations: comparative average, 30-day sparkline data, and personal-best detection — all scoped to a single metric and Workout Type. Stateless. No model changes, no cascade impact.

### WorkoutMetric Enum

```swift
enum WorkoutMetric {
    case effort, duration, distance,
         avgHR, maxHR,
         activeKcal, totalKcal,
         elevation, exerciseMinutes
}
```

Callers pass the enum case rather than a field name string. Each case maps to a `KeyPath` on `Workout` internally; the service centralizes the field-extraction logic so views stay clean.

### Operations

| Method | Purpose |
|---|---|
| `comparativeAverage(for metric: WorkoutMetric, workoutType: String, context: ModelContext) → Double?` | Returns the all-time average of the metric across all logged `Workout` records of `workoutType` where the metric is non-nil. Returns nil when fewer than 3 such workouts exist (the data-sufficiency threshold — see SCREENS.md § Metric Detail Sheet → Empty States). |
| `sparklineData(for metric: WorkoutMetric, workoutType: String, days: Int = 30, context: ModelContext) → [(date: Date, value: Double)]` | Returns time-series data points for the metric across the last `days` days of same-`workoutType` workouts where the metric is non-nil. Sorted ascending by date. Empty array if fewer than 3 data points exist. |
| `isPersonalBest(for metric: WorkoutMetric, workout: Workout, context: ModelContext) → Bool` | Returns true when `workout`'s value for `metric` is the maximum across all in-scope same-`workoutType` workouts. Returns false for PR-ineligible metrics regardless of value (see § PR Eligibility below). Returns false when fewer than 2 workouts of that type have the metric set (need at least one comparison point). |

### PR Eligibility

| Metric | PR-Eligible? | Rationale |
|---|---|---|
| Distance | ✓ | Longer cardio session is a clear achievement |
| Active kcal | ✓ | More calories burned = more effort |
| Total kcal | ✓ | Same as Active |
| Elevation Ascended | ✓ | More climbing is a clear achievement |
| Effort | ✗ | High effort is not a goal |
| Avg HR / Max HR | ✗ | Higher HR is not a goal |
| Duration | ✗ | Longer is not always better; could distort across workout types |
| Exercise Minutes | ✗ | Correlated with Duration; same concern |

`isPersonalBest` returns false unconditionally for non-eligible metrics. Caller (the Metric Detail Sheet) never renders the Personal Best chip in those cases.

### Computation Rules

- **All-time scope:** comparative average and PR detection scan all logged `Workout` records of the matching type — no time-window filter (unlike sparkline which is bounded to 30 days).
- **Nil handling:** records where the metric value is nil are excluded entirely from averages, sparklines, and PR comparisons. Nil data does not pull averages down.
- **Same-type filter:** all queries filter by `workout.workoutType == workoutType` (exact match, case-sensitive — workout types are AppConstants enum-style strings).
- **Excludes the current workout from comparisons:** when computing comparative average for the workout being viewed, the current workout's own value is **not** included in the average. The detail sheet's "your typical session" comparison reads against everyone else of the same type, so the user sees how this session relates to their baseline.
- **Unit handling:** values are returned in storage units (kg, km, meters) — formatting/conversion happens in the view layer per `useLbs` / `useMiles` user settings.
- **Read-only:** no mutations, no cascades. Pure query service. Safe to call from any actor; SwiftData fetches are main-actor-bound by `ModelContext` convention.

### Cascade Impact

**None.** This service does not modify any data. The detail sheet re-queries on every open, so changes elsewhere (workout edits, deletes) are reflected automatically without invalidation logic.


---

## WorkoutTypeOrderService (WorkoutTypeOrderService.swift)

- **Create:** When a workout is saved and no WorkoutTypeOrder exists for that type → create with sortOrder = max + 1, isExpanded = false, activeSortOption = "newestFirst", activeFiltersJSON = nil.
- **Delete:** When last workout of a type is deleted → remove the WorkoutTypeOrder record.
- **Reorder:** Accept array of workoutType strings, re-index sortOrder starting from 0.
- **Toggle expand/collapse:** Flip isExpanded for a given type.
- **Update sort/filter:** Persist activeSortOption and activeFiltersJSON per type.

---

## WorkoutTemplateService (WorkoutTemplateService.swift)

- **Create:** Template + TemplateExerciseSets. workoutType restricted to Strength Training / HIIT.
- **Retrieve:** All templates sorted by dateCreated (newest first).
- **Retrieve filtered by type:** `templates(matching workoutType: String) -> [WorkoutTemplate]` — returns only templates with matching `workoutType`. Used by the Edit Workout ellipsis "Use Template" selector to constrain choices to the current workout's type (see SCREENS.md § Log Workout → Edit Mode Ellipsis Menu).
- **Update:** Name, duration, add/modify/delete TemplateExerciseSets.
- **Delete:** Cascade-delete all TemplateExerciseSets. No effect on other data.
- **Apply (new-workout mode, Log Workout):** Return data snapshot (not a reference) for pre-populating the empty Log Workout form. Pre-populates name, type, duration, and exercises. Date/time default to now, Effort empty. Existing call sites unchanged.
- **Apply to existing workout (edit mode):** `applyToExistingWorkout(template: WorkoutTemplate, workout: Workout) -> Void` — mutates the in-memory `Workout` (not yet persisted). Rules:
   1. **Exercises (always applied):** for each `TemplateExerciseSet` on the template, create a new `ExerciseSet` and append it to `workout.exerciseSets`. The new sets get `sortOrder` values continuing from `(workout.exerciseSets.map(\.sortOrder).max() ?? -1) + 1` so they sit after existing rows. Do not modify or remove any existing `ExerciseSet`. No dedupe by name.
   2. **Name (fill-if-empty):** if `workout.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty`, set `workout.name = template.name`. Otherwise leave `workout.name` alone.
   3. **Duration (fill-if-empty, non-HK-linked only):** if `workout.healthKitUUID == nil` AND `workout.durationMinutes == nil`, set `workout.durationMinutes = template.durationMinutes`. Otherwise leave `workout.durationMinutes` alone — for HK-linked workouts the field is HK-owned and read-only (see HEALTHKIT.md § 7); for non-linked workouts with a duration already set, the user's value wins.
   4. **Type, effort, date, time, distance:** never applied. Type is locked in Edit Mode and the selector filter ensures match anyway. Effort is per-session. Date/time/distance aren't carried by templates.

   This method does not call `WorkoutService.update()` and does not bump `lastModifiedDate`. Persistence is the caller's responsibility — the typical caller is the Edit Workout view, which mutates the in-memory `@State` workout and persists on the user's "Save Changes" tap. The Workout Cascade fires through that save path normally.

   **Why a separate method from "Apply (new-workout mode)":** the new-workout call site populates an empty form (overwrite is fine because there's nothing to overwrite). The edit-mode call site has existing user data and must respect it (append + fill-if-empty + HK-aware skip). Keeping the two methods distinct prevents accidental data loss in edit flows.

---

## PlanService (PlanService.swift)

**Purpose:** CRUD for scheduled workouts, recurrence generation, date resolution, scheduled-workout snapshot encoding/decoding, and completion flow (including Watch-completion fast-path).

### Scheduled Workout Snapshot

When a user schedules a template, the exercise data (names, sets, reps, weights, restSeconds, displayAsTime, sort order) is serialized into `ScheduledWorkout.scheduledWorkoutSnapshot` as a JSON blob at scheduling time. **Renamed from `templateSnapshot` in Phase 8.7** to reflect the post-Phase-8.7 semantics: the `ScheduledWorkout` is the source of truth for everything Watch-relevant, and Edit Planned Workout (SCREENS.md § Edit Planned Workout) freely deviates the snapshot from the originating template. This ensures:

- Editing a template after scheduling does not silently alter planned workouts (existing semantics, unchanged).
- Editing a `ScheduledWorkout` mutates only that instance's snapshot (or "this and future" recurrences via the prompt — see § editScheduledWorkout below).
- Deleting a template does not orphan scheduled workouts.
- The "Complete Planned Workout" flow always has exercise data to populate.
- The new per-exercise `restSeconds` and `displayAsTime` fields drive the Apple Watch CustomWorkout composition (WORKOUTKIT.md § 6).

**encodeSnapshot(template: WorkoutTemplate) → Data:** Serializes the template's TemplateExerciseSets into a JSON array of `{ exerciseName, sets, reps, weightKg, sortOrder, restSeconds, displayAsTime }` objects. The two new fields (Phase 8.7) are nullable — decoders default to nil for snapshots written before Phase 8.7.

**encodeSnapshot(exercises: [SnapshotExercise]) → Data:** Re-encodes a mutated exercise list back into the JSON blob. Used by the Edit Planned Workout flow's decode-edit-re-encode pattern.

**decodeSnapshot(data: Data) → [SnapshotExercise]:** Deserializes the JSON blob back into an array of exercise structs for populating Log Workout, Edit Planned Workout, creating a Workout directly, or building the WorkoutKit `CustomWorkout` (via `WatchScheduleService`).

### Scheduling

- **Schedule:** Create a `ScheduledWorkout` record. Copy name, workoutType, durationMinutes from the selected template. Encode template exercises (with the new `restSeconds` and `displayAsTime` fields) into `scheduledWorkoutSnapshot`. Set status = "planned". `scheduledDate` must be today or in the future — past dates are rejected. `syncToAppleWatch` is captured at sheet save time from the Plan Workout sheet's "Push to Apple Watch" toggle (Phase 8.7.1+ — see SCREENS.md § Plan → Push to Apple Watch Toggle). Toggle default at sheet open is driven by `UserSettings.syncPlanToAppleWatchEnabled` AND WorkoutKit auth state: `true` when both pass, `false` (greyed, non-interactive) otherwise. After save, if `syncToAppleWatch == true`, gates are validated server-side; on pass, `WatchScheduleService.schedule(_:)` is invoked.
- **Schedule recurring:** Accept a recurrence rule ("weekly" / "biweekly") and generate individual `ScheduledWorkout` records for the next 12 weeks, each sharing the same `recurrenceGroupId` (a new UUID). Each instance gets its own `scheduledWorkoutSnapshot` copied at creation time. All instances inherit the `syncToAppleWatch` and `scheduledTime` values captured from the Plan Workout sheet (Phase 8.7.1+) — applied to each instance's own date. If the inherited `syncToAppleWatch == true`, `WatchScheduleService.schedule(_:)` fires for each new instance.
- **Regenerate recurrence:** When the user opens the Plan tab and fewer than 4 future instances remain for a `recurrenceGroupId`, auto-generate additional instances to maintain a 12-week lookahead. Silent background operation. **Watch sync intent inheritance:** each newly-generated instance inherits `syncToAppleWatch` from the most recent existing instance in the same `recurrenceGroupId` (mirrors the user's expressed pattern). Each new instance with `syncToAppleWatch == true` triggers `WatchScheduleService.schedule(_:)` after creation. Each new instance gets a fresh `appleWorkoutPlanId` UUID stamped at first sync. See WORKOUTKIT.md § 13.

### Retrieval

- **Fetch for date range:** Return all `ScheduledWorkout` records within a given date range, sorted by `scheduledDate` then `scheduledTime`.
- **Fetch for date:** Return all records for a specific calendar day.
- **Fetch today's planned:** Return the first `ScheduledWorkout` for today with status "planned" (used by Today's Plan widget left column).
- **Fetch today's scheduled workouts (Phase 8.8):** Return **all** `ScheduledWorkout` records where `scheduledDate == today` (calendar-local), regardless of status (`planned`, `completed`, `skipped`). Sort: planned/skipped rows first, completed rows last (mirrors the Plan tab day-detail stack order); within each group, ordered by `scheduledTime` ascending (nil times sort last), then by `dateCreated`. Used by the Today's Plan Detail Sheet (SCREENS.md § Today's Plan Detail Sheet). The "completed rows stay visible only on the day they were completed" behavior is enforced by this date filter — no separate completion-window logic.
- **Fetch Plan surface for date range:** Unified fetch used by the Plan screen calendar dots and Day Detail Area. Returns a merged collection of:
  1. All `ScheduledWorkout` records in the range (all statuses).
  2. All `Workout` records in the range **where** no `ScheduledWorkout` has `completedWorkoutId == workout.id` AND `workout.hiddenFromPlan == false`.
  
  The filter on condition (1) prevents duplicate representation of completed scheduled workouts (once as their `ScheduledWorkout`, once as the linked `Workout`). Callers distinguish the two record types and render logged-only cards vs. scheduled cards accordingly (see SCREENS.md § Plan → Day Detail Area).

  **Sort order:** Primary key is date ascending. Secondary key is `dayOrderPriority` so within a single day, planned/skipped scheduled workouts (priority 0) sort before completed scheduled workouts and logged-only workouts (priority 1) — finished work sinks to the bottom of the day's stack so upcoming items stay visually anchored on top.
- **Fetch Plan surface for date:** Same logic scoped to a single calendar day. Used by Day Detail Area and by the Today's Plan widget calendar square (for green dot presence on today).

### Completion

- **Complete:** Accept a `ScheduledWorkout`, RPE (optional), and duration (optional). Decode `scheduledWorkoutSnapshot`, create a `Workout` + `ExerciseSet` records from the snapshot data (preserving `restSeconds` and `displayAsTime` per exercise) plus RPE and duration. Set `ScheduledWorkout.status` = "completed" and `completedWorkoutId` = new Workout's ID. **If `syncToAppleWatch == true` and `appleWorkoutPlanId != nil`, call `WatchScheduleService.removePlan(_:)` to clear the now-stale Watch entry** (the workout is completed; no need for it to remain in the Scheduled section). Trigger all standard workout-save cascades (PR recalc, goal auto-update, Training Load, streak, Power Level).
- **Complete via Log Workout:** When the user taps "Modify Exercises," pass the `ScheduledWorkout.id` through to Log Workout. On workout save, call back to PlanService to mark the slot completed and link the workout ID. Same `WatchScheduleService.removePlan(_:)` call applies if synced.
- **Complete from Watch (Phase 8.7):** New entry point invoked by `HealthKitSyncService.importPendingWorkouts()` Step 0 (Plan-ID Fast-Path). Method signature: `completeFromWatch(scheduledWorkout: ScheduledWorkout, hkSnapshot: HealthKitWorkoutSnapshot)`. Flow:
  1. Decode `scheduledWorkoutSnapshot`.
  2. Build a `Workout` with: `name = scheduledWorkout.workoutName`, `workoutType = scheduledWorkout.workoutType`, `date = hkSnapshot.startDate`, `time = hkSnapshot.startDate` (time component), `healthKitUUID = hkSnapshot.uuid`, `healthKitSourceBundleID = hkSnapshot.sourceBundleID`, `healthKitActivityType = hkSnapshot.activityTypeDisplayString`, and all HK-owned fields (duration, distance, HR, calories, elevation, exerciseMinutes, indoor) populated from the snapshot.
  3. Build `ExerciseSet` records from the decoded snapshot exercises (preserving `restSeconds` and `displayAsTime` per exercise).
  4. Persist the `Workout` and its `ExerciseSet`s through `WorkoutService.log()` — this fires the standard Workout Cascade (PR recalc, goal auto-update, Training Load, streak, Power Level, GoalSnapshot).
  5. Set `scheduledWorkout.status = "completed"` and `completedWorkoutId = workout.id`.
  6. Call `WatchScheduleService.removePlan(scheduledWorkout.appleWorkoutPlanId)` to clear the Watch-side registration (workout is completed; no longer needs to be in the Scheduled section).
  7. iOS 18+: if no RPE was set on the snapshot exercises and HK has a `workoutEffortScore` for this workout, run the standard nil-fill path (HEALTHKIT.md § 8).

  **Bypasses `WorkoutMatcher` entirely** — plan-ID match is deterministic. See WORKOUTKIT.md § 8 for full mechanics and edge cases.

- **findByPlanId(_ planId: UUID) → ScheduledWorkout?:** Lookup helper used by `HealthKitSyncService` Step 0. Queries SwiftData for a `ScheduledWorkout` whose `appleWorkoutPlanId == planId`. Returns nil if not found (e.g., the `ScheduledWorkout` was deleted between scheduling and Watch completion).

### Edit Planned Workout (Phase 8.7)

`editScheduledWorkout(_ scheduledWorkout: ScheduledWorkout, edits: ScheduledWorkoutEdits, applyTo: RecurrenceScope)` — invoked from the Edit Planned Workout screen on Save (SCREENS.md § Edit Planned Workout).

Where:
- `ScheduledWorkoutEdits` is a struct carrying all editable fields: `workoutName`, `scheduledDate`, `scheduledTime`, `durationMinutes`, `exercises: [SnapshotExercise]`, `syncToAppleWatch`.
- `RecurrenceScope` is an enum: `.thisOnly` / `.thisAndFuture`. Caller resolves by prompting the user when `recurrenceGroupId != nil`. Single-instance edits skip the prompt and pass `.thisOnly`.

Flow:

1. Apply edits to the target `ScheduledWorkout`(s):
   - For `.thisOnly`: this instance only. Re-encode `exercises` into `scheduledWorkoutSnapshot`. Update `workoutName`, `scheduledDate`, `scheduledTime`, `durationMinutes`, `syncToAppleWatch` directly on this record.
   - For `.thisAndFuture`: this instance plus all future instances in the same `recurrenceGroupId` (`scheduledDate >= this instance's date`). Apply the same field updates to each. Past completed/skipped instances untouched.
2. **Date-change rule:** if `scheduledDate` changed and `recurrenceGroupId != nil`, force `applyTo = .thisOnly` regardless of caller's choice — applying a date change to a series doesn't have coherent semantics. Caller's UI should suppress the "this and future" option when a date change is detected (SCREENS.md § Edit Planned Workout).
3. **Watch sync re-sync:** for each affected `ScheduledWorkout` whose `syncToAppleWatch == true` after the edits AND whose gates pass, call `WatchScheduleService.resync(_:)` — `removePlan(uuid)` followed by `schedule(plan, at:)` with the same `appleWorkoutPlanId`. For `.thisAndFuture`, each affected instance is re-synced individually with its own UUID. Errors surface via the standard error toast (WORKOUTKIT.md § 11); per-card flags retained.
4. No cascade fires (the `ScheduledWorkout` doesn't drive any algorithm until completion).

### Date Resolution

Determine the appropriate workout date when completing a planned workout:

- **Scheduled date is today:** Return today. No prompt needed.
- **Scheduled date is in the past:** Return both the scheduled date and today as options. Caller presents prompt to user.
- **Scheduled date is in the future:** Return today as the only valid date. Caller presents prompt. Post-dating is prohibited.

### Skip / Restore

- **Skip:** Set status = "skipped". No `Workout` record created. Reversible.
- **Restore:** Set status back to "planned" (from "skipped" only).

### Remove from Plan

The unified "Remove from Plan" action supports all non-planned card types on the Plan screen (planned and skipped `ScheduledWorkout`s, completed `ScheduledWorkout`s, and logged-only `Workout`s). Behavior varies by underlying record type:

- **Planned or skipped `ScheduledWorkout` (single):** Delete the `ScheduledWorkout` record. Standard delete confirmation required by caller.
- **Planned or skipped `ScheduledWorkout` (recurring):** Caller presents "This workout only / This and future workouts" prompt first. "This workout only" deletes this instance. "This and future" deletes this instance and all future instances sharing the same `recurrenceGroupId` with `scheduledDate` ≥ this instance's date. Past completed/skipped instances are never deleted.
- **Completed `ScheduledWorkout` (single) — dual-action:** Execute atomically:
  1. Delete the `ScheduledWorkout` record.
  2. Set `workout.hiddenFromPlan = true` on the linked `Workout` (resolved via `completedWorkoutId`).
  
  Without step 2, the dedup rule in § Retrieval → Fetch Plan surface would immediately re-surface the `Workout` as a logged-only card. The underlying `Workout` record is fully preserved in the Workouts screen and in all cascades — only its visibility on Plan is removed.
- **Completed `ScheduledWorkout` (recurring):** Caller presents "This workout only / This and future workouts" prompt. "This workout only" executes the dual-action on this instance. "This and future" executes the dual-action on this instance, plus deletes all future **planned** instances in the same `recurrenceGroupId` (existing recurring delete rule — past completed/skipped untouched).
- **Logged-only `Workout`:** Set `workout.hiddenFromPlan = true`. No `ScheduledWorkout` involved.

**Undo:** All variants emit a "Removed from Plan. [Undo]" toast (~4s auto-dismiss). Undo reverses the action:
- For logged-only and completed-scheduled variants, undo sets `workout.hiddenFromPlan = false`. The card reappears as a **logged-only card** (the deleted `ScheduledWorkout` record is not restored — this is acceptable behavior consistent with the dual-action's lineage-destroying semantics).
- For planned/skipped variants, undo restores the deleted `ScheduledWorkout` record from the pre-delete snapshot held in memory for the toast's lifetime. If the toast auto-dismisses before the user taps Undo, the deletion is permanent.

### Delete (legacy — now subsumed by Remove from Plan)

Historical note: the action previously named "Delete from Schedule" has been renamed to "Remove from Plan" and unified across all card types. Callers that previously invoked a plain `delete(scheduledWorkout:)` now invoke `removeFromPlan(card:)` with the card's underlying record. The SwiftData operations are unchanged for planned/skipped cases — only naming and the addition of the completed-card dual-action branch.

### Workout Deletion Linkage

When a `Workout` that is linked to a `ScheduledWorkout` (via `completedWorkoutId`) is deleted, PlanService sets `completedWorkoutId` to nil and reverts status to "planned". This allows the user to re-complete the scheduled slot.

---

## WorkoutSchedulerProtocol (WorkoutSchedulerProtocol.swift) — Phase 8.7

**Purpose:** Protocol abstraction over Apple's WorkoutKit framework. All WorkoutKit access in FitNavi goes through this protocol. The concrete implementation (`DefaultWorkoutScheduler`) is the only file in the codebase that imports `WorkoutKit` (besides the model-builder helpers in `WatchScheduleService` for `CustomWorkout` / `IntervalBlock` types). Integration tests inject `StubWorkoutScheduler` from `TestFixtures.swift` instead.

See WORKOUTKIT.md § 4 (Architecture Decisions) for the rationale (mirrors `HealthKitClient`).

### Protocol Surface

```swift
protocol WorkoutSchedulerProtocol {
    func authorizationState() async -> WorkoutSchedulerAuthState  // .notDetermined | .granted | .denied
    func requestAuthorization() async -> WorkoutSchedulerAuthState
    func schedule(_ plan: WorkoutPlan, at date: Date) async throws
    func removePlan(id: UUID) async throws
    func scheduledPlans() async -> [ScheduledPlanInfo]  // for reconciliation: returns IDs + scheduled dates
}
```

`StubWorkoutScheduler` records every call and exposes assertion helpers (e.g., `assertScheduled(uuid:atDate:)`, `assertRemoved(uuid:)`). No test file outside the stub itself imports `WorkoutKit`.

---

## WatchScheduleService (WatchScheduleService.swift) — Phase 8.7

**Purpose:** Orchestrate the full WorkoutKit outbound scheduling lifecycle — schedule plans for synced `ScheduledWorkout`s, remove plans on toggle-off / completion / deletion, reconcile state on master-toggle and foreground transitions, and surface errors via the standard error toast. All `WorkoutSchedulerProtocol` interactions are serialized through this service to prevent races.

See WORKOUTKIT.md § 7 for the lifecycle overview.

### Responsibilities

- Own the lone reference to `WorkoutSchedulerProtocol`.
- Build `WorkoutPlan` (containing a `WorkoutComposition` of type `.custom`) from a `ScheduledWorkout` per WORKOUTKIT.md § 6 plan composition rules.
- Call `requestAuthorization()` when invoked from the master-toggle on path.
- Maintain in-memory effective-state cache: `(scheduledWorkoutId: UUID, planId: UUID, scheduledAt: Date, snapshotHash: String)` for reconciliation diffing.
- Marshal all calls onto a serial actor or single-threaded queue to prevent race conditions when multiple per-card toggles fire concurrently.
- Surface failures via error toast (caller-provided closure).

### Triggers

| Source | Behavior |
|---|---|
| Per-card toggle on (Plan card glyph or Edit Planned Workout toggle) | `schedule(scheduledWorkout:)` |
| Per-card toggle off | `removePlan(scheduledWorkout.appleWorkoutPlanId)` |
| Edit Planned Workout save (synced instance) | `resync(scheduledWorkout:)` — `removePlan` + `schedule` with same UUID |
| `ScheduledWorkout` skipped, completed (in-app or Watch path), removed-from-plan, deleted | `removePlan(uuid)` if `appleWorkoutPlanId != nil` |
| Settings master toggle on | `requestAuthorization()` (if `.notDetermined`); on grant, `reconcile()` |
| Settings master toggle off | Loop: `removePlan` for every `ScheduledWorkout` with `syncToAppleWatch == true` and `appleWorkoutPlanId != nil` |
| App foreground transition | `reconcile()` (defensive sweep + past-dated cleanup) |
| WorkoutKit auth state change (granted ↔ denied) | `reconcile()` |
| 12-week recurrence regeneration creates new instances | `schedule(_:)` for each new instance with inherited `syncToAppleWatch == true` |
| "This and Future" recurrence edit | `resync(_:)` for each affected synced instance |

### Plan Composition (`buildPlan(scheduledWorkout:)`)

See WORKOUTKIT.md § 6 for full mechanics. Summary:

1. Decode `scheduledWorkoutSnapshot`.
2. Map `scheduledWorkout.workoutType` → `HKWorkoutActivityType` via the outbound table in HK_MAPPING.md § Outbound Mapping.
3. For each exercise, resolve display mode: `displayAsTime ?? ExerciseSuggestionService.isIsometric(exerciseName)`.
4. Build one `IntervalBlock` per exercise with one `IntervalStep(.work, goal:)` per set, plus `IntervalStep(.recovery, goal: .time(restSeconds, .seconds))` between sets when `restSeconds != nil`. No recovery after final set in each block.
5. Set step display name per WORKOUTKIT.md § 6 formatting table.
6. Wrap in `WorkoutPlan(id: scheduledWorkout.appleWorkoutPlanId, ...)`.

### Schedule Date Resolution

`schedule(_:at:)` requires a real `Date`. Computed from `scheduledWorkout.scheduledDate` + `scheduledWorkout.scheduledTime`. When `scheduledTime` is nil, the service falls back to noon (12:00 PM) on the scheduled date. Apple Watch does not surface the scheduled time to users, and the writeback uses the actual start time from iOS/watchOS.

### Sync Gates (assertion before any operation)

Before calling `schedule(_:)` for any `ScheduledWorkout`, assert all of:
1. `UserSettings.syncPlanToAppleWatchEnabled == true`
2. `authorizationState() == .granted`
3. `scheduledWorkout.scheduledDate >= today`
4. `scheduledWorkout.scheduledWorkoutSnapshot` decodes to ≥1 exercise

If any fail, the schedule call is skipped and the caller is responsible for reflecting the gate failure in the UI (disabled glyph, popover). Defensive — UI should already be gating, but service must not silently produce broken Watch state.

### Error Handling

- **Auth not granted:** caught at gate-check; service no-ops. UI updates Settings status line to denied state.
- **Auth revoked mid-session:** detected on next operation. Service updates internal auth-state cache to denied, triggers UI refresh, surfaces no error toast (it's a deliberate state, not a transient failure).
- **Internal WorkoutKit error:** surfaced via error toast with [Retry]. Per-card flag retained.
- **Plan ID collision (theoretical):** logged internally. No user-visible action.

See WORKOUTKIT.md § 11 for full error matrix.

### Reconciliation (`reconcile()`)

Called from foreground, master-toggle on, auth-state change, and post-recurrence-regen. Loop:

1. Query `WorkoutSchedulerProtocol.scheduledPlans()` to enumerate currently-registered plans on Watch.
2. Build expected set: every `ScheduledWorkout` where `syncToAppleWatch == true` AND all gates pass.
3. For each expected `ScheduledWorkout`:
   - If its `appleWorkoutPlanId` is not in `scheduledPlans()`: schedule it.
   - If it is in `scheduledPlans()` but the `(snapshotHash, scheduledAt)` doesn't match the cached effective state: `removePlan` + `schedule` (content drifted; re-register).
4. For each plan in `scheduledPlans()` whose UUID isn't in any expected `ScheduledWorkout`: `removePlan` (orphan from prior session, deletion, or completion).
5. **Past-dated sweep:** for any `ScheduledWorkout` with `syncToAppleWatch == true` AND `scheduledDate < today` AND `status == "planned"`, call `removePlan` (the plan is stale on Watch). Per-card flag retained.

Reconciliation is idempotent — running it twice in succession produces no additional Watch operations.

### Threading

WorkoutKit's `WorkoutScheduler.shared` is documented as thread-safe, but `WatchScheduleService` serializes all calls through a single actor (or `DispatchQueue` with a serial executor) to ensure FitNavi-side state mutations are race-free. UI callbacks (toast, glyph state updates) marshal to `@MainActor`.

---

## HomeWidgetService (HomeWidgetService.swift)

- **Seed defaults:** On first launch (hasSeededDefaultWidgets = false), create HomeWidget records for **Today's Plan, Training Load, Power Level** in that order. Set hasSeededDefaultWidgets = true. Add-only widgets (not in the default seed) are **Week Streak** and **Activity Rings**. The historical Workout Info widget has been removed from the product entirely — see § One-time migration below.
- **Add:** Create HomeWidget at max sortOrder + 1. No duplicate widgetType allowed. Add Widgets menu lists every entry in CONSTANTS.md § Widget Types not currently present on the user's home — `workoutInfo` is no longer in that list. The `appleActivity` row is **always listed** regardless of HealthKit / Apple Watch availability — gating moved into the widget card itself (see SCREENS.md § Home Screen → Activity Rings widget for the three dynamic states).
- **Delete:** Remove HomeWidget record. Re-index remaining sortOrder.
- **Reorder:** Accept array of widgetType strings, re-index sortOrder starting from 0.

### One-time migration: remove `workoutInfo` HomeWidget records
On launch, before any home rendering:
1. Fetch every `HomeWidget` where `widgetType == "workoutInfo"`.
2. If any exist, delete them and re-index remaining `sortOrder` starting from 0 (preserve relative order of the surviving widgets).
3. Persist a one-shot migration flag (`UserSettings.hasMigratedWorkoutInfoRemoval = true`) so the cleanup is idempotent across subsequent launches.

This is a destructive migration — there is no replacement widget. If a user previously had Workout Info, Training Load, and Week Streak in that order, after migration they have Training Load and Week Streak. The user can re-add any widget from the Add Widgets menu.

### Widget Linking — `isLinkedActive(widgets:settings:)` (Phase 11)

Helper that decides whether the Recovery Status + Training Load pair should render as a single `FortiFitLinkedRecoveryLoadComposite` (shared border, zero padding) or as two independent cards. Pure function over the home widget array and `UserSettings` — no side effects, no SwiftData reads. Called from `HomeViewModel` on every widget array change.

```swift
func isLinkedActive(widgets: [HomeWidget], settings: UserSettings) -> Bool
```

**Rules:**

1. `settings.recoveryLoadManuallyUnlinked == true` → return `false` (sticky manual override).
2. `widgets` does not contain both `"recoveryStatus"` AND `"trainingLoad"` → return `false`.
3. The two widgets are NOT adjacent in `sortOrder` (i.e., `|recoveryStatusSortOrder - trainingLoadSortOrder| != 1`) → return `false`.
4. The Recovery Status widget's gating state is NOT `live` (i.e., `.connectAppleHealth`, `.sleepAccessDenied`, or `.noSleepTracker`) → return `false`. Note: `RecoveryStatusGatingState` lives on `RecoveryStatusService` — this helper queries `RecoveryStatusService.currentGatingState` rather than recomputing from settings.
5. All gates passed → return `true`.

**Auto-unlink:** the function is re-evaluated whenever any of the inputs change (widget reorder, widget delete, sleep observer fire that changes gating state, `recoveryLoadManuallyUnlinked` flip). The composite container appears/disappears with the 0.2s border-swap + padding-collapse animation defined in CONSTANTS.md § Linked Recovery & Load → Animation Timing.

**Manual unlink:** Triggered from the linked composite's combined long-press context menu → "Unlink Widgets" item. The handler sets `settings.recoveryLoadManuallyUnlinked = true` and the composite collapses to two independent cards. The flag is sticky — adjacency alone is not enough to re-link.

**Clearing the manual flag:** Set `recoveryLoadManuallyUnlinked = false` whenever any reorder operation in Widget Edit Mode actually changes the `sortOrder` of either Recovery Status or Training Load (see SCREENS.md § Home Screen → Widget Edit Mode → Manual-unlink flag clearing on drag). Entering edit mode without dragging does NOT clear the flag — no `sortOrder` change occurred. Deleting one of the pair via long-press → "Delete Widget" → confirm also clears the flag (the next re-add of that widget can re-establish auto-link if the user lands it adjacent to the other). Note: there is no "x" delete button on widgets in edit mode — deletion is exclusively via the long-press context menu (see SCREENS.md § Home Screen → Widget Edit Mode and BUGS.md doc-drift entry).

### Today's Plan — Complete Workout from context menu
The Today's Plan widget exposes a "Complete Workout" item in its long-press context menu (see SCREENS.md § Home Screen → Widget Context Menu). Visibility rule: the item is rendered if and only if `PlanService.fetchTodaysPlanned()` returns a non-nil `ScheduledWorkout` (i.e., at least one uncompleted plan for today). The action delegates to the same compact confirmation sheet used by the Plan tab (`PlanService.completeScheduled(workoutId:)` flow). On confirm, the widget refresh (see Workout Cascade above) repopulates the left column with the next planned workout for today, or falls back to the "All planned workouts completed." state when no more remain.

### Widget Tap Routing (Phase 8.8)

Every Home widget card opens a per-widget detail sheet on tap (SCREENS.md § Standard Patterns → Home Widget Tap-to-Open). Tap routing is owned by the home view layer (`HomeViewModel`), not the service — `HomeWidgetService` is a SwiftData CRUD shop and stays that way. This section documents the contract the view layer is expected to honor.

```swift
enum WidgetDetailRoute {
    case todaysPlan
    case trainingLoad
    case weeklyStreak
    case powerLevel
    case appleActivityLive          // existing — opens Activity Detail Sheet
    case appleActivityConnectHK     // existing — navigates to Settings → Apple Health
    case appleActivityPairWatch     // existing — no-op
    case recoveryStatusLive         // Phase 11 — opens Recovery Status Detail Sheet
    case recoveryStatusConnectHK    // Phase 11 — navigates to Settings → Apple Health
    case recoveryStatusSleepDenied  // Phase 11 — deep-links to iOS Settings (UIApplication.openSettingsURLString)
    case recoveryStatusNoTracker    // Phase 11 — no-op (No Sleep Tracker state)
    case linkedRecoveryLoad         // Phase 11 — opens Linked Recovery & Load Detail Sheet (both cards route here when isLinkedActive == true)
    case suppressed                 // home is in Widget Edit Mode
}

func tapRoute(for widget: HomeWidget, isEditMode: Bool) -> WidgetDetailRoute
```

**Rules:**
- `isEditMode == true` → always returns `.suppressed`. The view layer's tap handler short-circuits and does nothing (taps still reach the existing delete-and-drag chrome inside the card).
- `widgetType == "appleActivity"` → returns the existing three-state branch (`.appleActivityLive` / `.appleActivityConnectHK` / `.appleActivityPairWatch`) per the existing Activity Rings widget state table (SCREENS.md § Home Screen → Activity Rings widget).
- `widgetType == "recoveryStatus"` (Phase 11) AND `isLinkedActive(widgets:settings:) == true` → returns `.linkedRecoveryLoad` (opens the combined detail sheet). Otherwise branches on `RecoveryStatusService.currentGatingState`: `.live` → `.recoveryStatusLive`, `.connectAppleHealth` → `.recoveryStatusConnectHK`, `.sleepAccessDenied` → `.recoveryStatusSleepDenied`, `.noSleepTracker` → `.recoveryStatusNoTracker`.
- `widgetType == "trainingLoad"` (Phase 11) AND `isLinkedActive == true` → returns `.linkedRecoveryLoad` (the TL card on the linked composite opens the same combined sheet). Otherwise returns `.trainingLoad` (Phase 8.8 unlinked behavior).
- All other widget types map 1:1 to their new detail-sheet route value.

**Detail-sheet lifecycle:** Sheets are presented via SwiftUI `.sheet(item:)` from `HomeView`. Sheet ViewModels subscribe to the same Workout Cascade publishers the widget cards already use — when the cascade fires while a sheet is presented, the sheet re-fetches its helpers (StreakService.fetchHeatmap, etc.) and re-renders in place. Sheet dismissal does NOT clear that subscription — it is owned by the sheet's ViewModel lifecycle.

**Footer routing:** When a detail sheet's footer button (`See Info` or `Configure Settings`) is tapped, the sheet dismisses first via its `presentationMode` binding, and the corresponding modal opens after a 0.2s delay (matches the iOS sheet-dismiss animation). Never stacked sheet-on-sheet. Implementation in `HomeViewModel` — sheet ViewModels emit a `RequestFollowupModal` enum event.

---

## AppleActivityService (AppleActivityService.swift)

**Purpose:** Owns daily Move / Exercise / Stand totals for the Activity Rings widget and the Activity Detail Sheet. Routes all HK access through `HealthKitClient` (see HEALTHKIT.md § 20 for the read methods and source-detection helper). Exposed as `@Observable` so the widget binds reactively.

### Responsibilities

- Fetch today's `HKActivitySummary` and expose Move (`activeEnergyKcal`), Exercise (minutes), Stand (hours) as derived properties.
- Subscribe to `HealthKitClient.observeActivitySummaryChanges` and refresh derived state on each fire.
- Detect Apple Watch presence via `HealthKitClient.hasAppleWatchData(within:)` and expose a derived `appleWatchDetected: Bool` (cached for the lifetime of an app foreground; refreshed on every foreground transition).
- Compute the **weekly closure rate** (`closedAllRingsDayCount: Int` over the last 7 calendar days) by iterating `fetchActivitySummaries(from:to:)` results.
- Compute **per-workout ring contribution** for the widget caption — sums `activeEnergyKcal` and `exerciseMinutes` across today's `Workout` records where `healthKitUUID != nil`. Manual logs without HK linkage do not contribute.
- Provide the `importGoalsFromAppleHealth()` flow used on first config and on the manual "Import from Apple Health" button (see HEALTHKIT.md § 20 → First-Config Goal Import).

### Derived State (read-only, reactive)

```swift
@Observable
final class AppleActivityService {
    // From HKActivitySummary (today)
    var moveCalories: Int           // current / numerator for Move ring
    var exerciseMinutes: Int        // current / numerator for Exercise ring
    var standHours: Int             // current / numerator for Stand ring

    // From UserSettings (configurable; nil → fall back to defaults)
    var moveGoal: Int               // denominator
    var exerciseGoal: Int           // denominator
    var standGoal: Int              // denominator

    // Derived
    var moveProgress: Double        // moveCalories / moveGoal (0.0 — uncapped, can exceed 1.0)
    var exerciseProgress: Double
    var standProgress: Double
    var allRingsClosedToday: Bool   // all three >= 1.0
    var closedAllRingsDayCount: Int // last 7 days

    // Workout-side contributions (today's HK-linked workouts)
    var todayMoveContributionFromWorkouts: Int   // sum of activeEnergyKcal across HK-linked workouts logged today
    var todayExerciseContributionFromWorkouts: Int

    // Watch detection
    var appleWatchDetected: Bool    // true if HK has any Watch-sourced sample in the last 7 days
}
```

### Goal Import

`importGoalsFromAppleHealth() async`:
1. Call `HealthKitClient.fetchActivitySummary(for: .now)`.
2. If returned summary has non-zero `*Goal` fields, write them into `UserSettings.targetMoveCalories`, `targetExerciseMinutes`, `targetStandHours` after rounding to the slider increment (10 / 5 / 1 respectively).
3. If HK returns no summary or all goals are zero, write FitNavi defaults: 500 / 30 / 12.
4. Persist UserSettings.

Called from two places: (a) the first time the Activity Rings widget is added (`HomeWidgetService.add(.appleActivity)` triggers this for any goal field still nil), (b) the manual "Import from Apple Health" button in the Activity Rings Settings Modal (which always overwrites whatever is currently in UserSettings).

### Day Boundary

Local midnight. At rollover, the next observer-query fire (or the next foreground transition) refetches today's summary and renders 0/goal across all three rings until movement registers.

### Refresh Triggers

- **App foreground:** existing HK catch-up sync triggers a refetch via the observer query handler.
- **Activity-summary observer query fires:** standard observer pattern (see HEALTHKIT.md § 20).
- **Workout Cascade fires AND the saved/edited workout has `healthKitUUID != nil`:** explicit refresh hook in `WorkoutService.log()` and `WorkoutService.update()` paths checks the flag and calls `AppleActivityService.refresh()` only when true. See § Workout Cascade.

### Apple Watch Empty-State Detection

`appleWatchDetected` is recomputed on every app foreground transition (cached for the active session). The widget renders one of three states based on the combination of `UserSettings.healthKitEnabled` and `appleWatchDetected`:

| `healthKitEnabled` | `appleWatchDetected` | State |
|---|---|---|
| false | (any) | "Connect Apple Health" — see SCREENS.md § Activity Rings widget States |
| true | false | "Pair an Apple Watch" — see SCREENS.md |
| true | true | Live rings — see SCREENS.md |


---

## TrendsChartService (TrendsChartService.swift)

Mirrors `HomeWidgetService` for the Trends screen.

- **Seed defaults:** On first launch (hasSeededDefaultTrendsCharts = false), create TrendsChart records for Strength Tracker, Training Frequency, Personal Records, Training Load Trend in that order. Set hasSeededDefaultTrendsCharts = true.
- **Add:** Create TrendsChart at max sortOrder + 1. No duplicate chartType allowed.
- **Delete:** Remove TrendsChart record. Re-index remaining sortOrder. No underlying workout data affected.
- **Reorder:** Accept array of chartType strings, re-index sortOrder starting from 0.

### Header Summary Computation

Phase 6.1 adds per-chart hero + caption values that render above each chart's plot area (see CONSTANTS.md § Trends Chart Visual Tokens → Header Summary Block and SCREENS.md § Standard Patterns → Trends Chart Card Visual Treatment). The service exposes one entry point and one computation per chart type.

- **`func headerSummary(for chartType: ChartType, exerciseName: String? = nil) -> ChartSummary?`** — entry point. Returns `nil` when the chart's data threshold (CONSTANTS.md § Chart Data Thresholds) is not met; the view renders the empty state instead. `exerciseName` is required only for `strengthTracker` and `personalRecords` (whose values depend on the active exercise dropdown selection).
- **`ChartSummary`** — value type with `hero: String` and `caption: String`. Caption strings live in `AppConstants` (e.g., `AppConstants.Trends.captionLatest`, `captionAvgPerSession`, etc.) — never hardcoded in views.

#### Per-Chart Calculation

| Chart (id) | Source data | Hero formula | Notes |
|---|---|---|---|
| `strengthTracker` | All ExerciseSets matching `exerciseName` (case-insensitive), chronologically | Latest non-nil `weightKg`, formatted per `useLbs` with unit | Threshold: ≥ 2 workouts with the exercise + recorded weight |
| `trainingFrequency` | Last 8 full Mon–Sun weeks | Mean workouts per week, 1 decimal place | Threshold: ≥ 1 full Mon–Sun week with ≥ 1 workout |
| `personalRecords` | PR timeline for `exerciseName` per § Goal Auto-Update | `+{current − previous} {unit}` formatted per `useLbs`. If only baseline + first PR, delta = first PR − baseline. | Threshold: 1 exercise with ≥ 1 PR event |
| `trainingLoadTrend` | Today's Training Load score (per § Training Load Algorithm) | Integer score, no unit suffix | Threshold: ≥ 3 days with ≥ 1 workout in last 14 days |
| `workoutVolume` | Last 30/60/90 days (per active toggle) of Strength + HIIT workouts | Mean session volume (sets × reps × weightKg, summed per workout, averaged across workouts), formatted with `K`/`M` suffix when ≥ 1,000 / ≥ 1,000,000; weight unit per `useLbs` | Threshold: ≥ 2 Strength/HIIT workouts with ≥ 1 ExerciseSet |
| `rpeTrend` | Last 8 full Mon–Sun weeks of workouts with non-nil `rpe` | Mean RPE across all qualifying workouts, 1 decimal place | Threshold: ≥ 1 full Mon–Sun week with ≥ 1 workout with recorded RPE |
| `workoutTypeBreakdown` | Workouts within active toggle (30D / 60D / 90D / All Time) | Total workout count (integer); rendered inside the donut center, NOT the header summary slot | Threshold: ≥ 2 workouts of any type. Caption is `WORKOUTS` per CONSTANTS.md § Donut Center Label. |
| `sessionDuration` | Last 8 full Mon–Sun weeks of workouts with non-nil `durationMinutes` | `{mean duration} min`, integer minutes | Threshold: ≥ 1 full Mon–Sun week with ≥ 1 workout with recorded duration. Workouts without recorded duration are excluded from the average. |

#### Cascade Behavior

Header summary values are computed on demand by the view (no persistent cache). The Workout Cascade (§ Workout Cascade) lists "every chart card's header summary value" under its **Charts** bullet — this is informational; in practice the chart views observe SwiftData changes and rebuild via `headerSummary(for:)` on the next render. No service-level recompute method is required.

For `strengthTracker` and `personalRecords`, the view also rebuilds when the user changes the exercise dropdown selection. For charts with toggles (`workoutVolume`, `workoutTypeBreakdown`), the view rebuilds on toggle change.

### Comparison Delta Computation

Phase 6.2 adds a comparison-delta band to the chart detail view's header summary (see CONSTANTS.md § Trends Chart Detail View → Header Summary (Detail Variant) and SCREENS.md § Trends Chart Detail).

- **`func comparisonDelta(for chartType: ChartType, exerciseName: String? = nil, range: TimeRange) -> ChartDelta?`** — entry point. Returns `nil` when below the chart's data threshold (CONSTANTS.md § Chart Data Thresholds). Otherwise returns a `ChartDelta` with `hero` + `caption` (matching what `headerSummary(for:exerciseName:)` would return for the *current* `range`), plus a `delta: String?` and `direction: DeltaDirection`.
- **`ChartDelta`** — `hero: String`, `caption: String`, `delta: String?`, `direction: DeltaDirection`. `delta` is `nil` when no prior-period data exists; `direction` is `.flat` in that case. Caption strings live in `AppConstants.Trends`; never hardcoded.
- **`enum DeltaDirection { case up, down, flat }`** — drives the arrow icon and color in the view (Positive Green up, Alert Red down, Muted Text flat).

#### Per-Chart Comparison Window

For each `range`, the prior period is the immediately preceding window of the same length. For event-driven charts (`personalRecords`), comparison is event-relative.

| Chart (id) | Current Window | Prior Window | Delta Formula |
|---|---|---|---|
| `strengthTracker` | Trailing `range` ending today | Same length, ending the day before the current window starts | Latest `weightKg` in current − latest `weightKg` in prior, formatted per `useLbs` |
| `trainingFrequency` | Trailing `range` of full Mon–Sun weeks | Same number of weeks immediately before | Mean workouts/week (current) − mean workouts/week (prior), 1 decimal |
| `personalRecords` | Most recent PR event | Second-most-recent PR event | `(current PR weight − prior PR weight)` per `useLbs`. If only baseline + first PR, prior = baseline. |
| `trainingLoadTrend` | Today's score | 7 days ago's score | Today − 7 days ago, integer |
| `workoutVolume` | Trailing `range` ending today | Same length, ending the day before | Mean session volume (current) − mean session volume (prior), formatted with same K/M suffix logic as the hero |
| `rpeTrend` | Trailing `range` of weeks | Same number of weeks immediately before | Mean RPE (current) − mean RPE (prior), 1 decimal |
| `workoutTypeBreakdown` | Total workouts in trailing `range` | Total workouts in same prior length | Current count − prior count, integer (rendered alongside donut center label, not in the suppressed header summary) |
| `sessionDuration` | Trailing `range` of weeks | Same number of weeks immediately before | Mean duration (current) − mean duration (prior), integer minutes |

`direction` is `.up` when the delta is strictly positive, `.down` when strictly negative, `.flat` when zero or when the prior window has insufficient data to compute. Ties always read `.flat`.

### Data Point Fetch (Detail View)

- **`func dataPoints(for chartType: ChartType, exerciseName: String? = nil, range: TimeRange) -> [ChartDataPoint]`** — returns the chart's plot data at any supported `TimeRange`. `ChartDataPoint` carries `(x: Date, y: Double, label: String)`. Identical computation rules to the compact card but parameterized over `TimeRange` instead of fixed 30D / 60D / 90D / 8-week. Out-of-eligible-range pairs (e.g., `(.personalRecords, .d)`) return an empty array — the view gates eligible toggles up-front so this should never fire in production.

### PR Timeline Fetch (Personal Records detail only)

- **`func fullPRTimeline(for exerciseName: String) -> [PRTimelineEvent]`** — returns every PR event for the named exercise, chronologically. `PRTimelineEvent` carries `(date: Date, weightKg: Double, deltaKg: Double)`. Empty array → empty state on the detail view. Excludes baseline (per § PR Definition in SCREENS.md). Bodyweight exercises (nil `weightKg`) are excluded.

### Type Breakdown Percentages (Workout Type Breakdown detail only)

- **`func breakdownPercentages(range: TimeRange) -> [WorkoutTypeBreakdownRow]`** — returns one row per workout type with non-zero count in the active `range`. `WorkoutTypeBreakdownRow` carries `(type: String, count: Int, percent: Double, avgDurationMinutes: Int?)`. Percentages sum to 100.0 (rounding tie-broken toward the largest type). `avgDurationMinutes` is `nil` when no workouts of that type in the range have a recorded duration.

---

## ExerciseSuggestionService (ExerciseSuggestionService.swift)

**Purpose:** Hybrid autocomplete for exercise name inputs across Log Workout, Create Workout Template, and Create Goal (Custom exercise).

### Data Sources
1. **User history:** Exercise names from all previously logged workouts. Refreshed after workout save/delete.
2. **Static dictionary:** Curated list in AppConstants (see `CONSTANTS.md`).
3. **Alias map:** Abbreviations → canonical names (see `CONSTANTS.md`).

### Suggestion Ranking (highest to lowest priority)
1. **Prefix match** from user history (e.g., "Ben" → "Bench Press" from history)
2. **Prefix match** from dictionary (e.g., "Ben" → "Bench Press" from dictionary)
3. **Word-boundary match** from user history (e.g., "Press" → "Bench Press")
4. **Word-boundary match** from dictionary
5. **Contains match** from user history (e.g., "bell" → "Barbell Rows")
6. **Contains match** from dictionary
7. **Alias resolution:** If input matches an alias key (case-insensitive), include the canonical name as a suggestion.

### Closest-Match Nudge
If no candidates match via prefix/word-boundary/contains, check Levenshtein edit distance. Surface the closest match within edit distance ≤ 2 as the top suggestion (e.g., "Bech Press" → "Bench Press"). No special visual distinction. Edit distance 3+ → no nudge.

### Rules
- Maximum 5 suggestions returned
- Empty or whitespace-only query → empty list
- Deduplication: case-insensitive. If same exercise exists in history + dictionary, history version wins.
- All matching is case-insensitive
- `refreshHistory()` updates the history source after workout save/delete

### isIsometric Lookup (Phase 8.7)

`isIsometric(_ exerciseName: String) -> Bool` — resolves the dictionary's intended display mode for an exercise name. Used by:

- The template editor / Log Workout / Edit Planned Workout UI to set the initial REPS/TIME segmented control state (SCREENS.md § Log Workout → Exercise Card Additions).
- `WatchScheduleService` to resolve `displayAsTime ?? isIsometric(exerciseName)` for plan composition (WORKOUTKIT.md § 6).

Resolution order:
1. Resolve aliases first (e.g., "Plank" → "Planks") via the alias map.
2. Check `CONSTANTS.md § Isometric Exercise Names` set membership. Return `true` if found.
3. Check `CONSTANTS.md § Ambiguous Exercise Default Modes` map. Return the configured default if found (e.g., "Battle Ropes" → true; "Burpees" → false).
4. Default: return `false` (rep-based).

Stateless and pure. No history dependency — uses only the static dictionary plus alias map.

### FortiFitExerciseAutocomplete Component
Dropdown overlay below input. Elevated surface (#2d2d2d), border (#404040). Each row: 44pt min height, 13px 600-weight #e5e5e5 text. First row highlighted (#3b82f6 at 10% opacity). Appears when ≥1 character typed and suggestions exist. Tap suggestion → populates input, dismisses immediately. Tap outside / press return / lose focus → dismisses, accepts typed text. Renders above sibling cards via zIndex. 0.15s opacity fade-in. Identical behavior across Log Workout, Create Workout Template, and Create Goal.

---

## GoalSnapshotService (GoalSnapshotService.swift)

**Purpose:** Manages `GoalSnapshot` records that power the 30-day sparkline on goal cards. Captures **per-workout session values** anchored to each matching workout's `date`, so the sparkline reflects what the user actually did on each training day — including regressions, light sessions, and time between PRs — not just PR events.

### Snapshot Model
The sparkline and the ring are two different lenses on the same goal:
- **Ring** reflects the all-time best within scope (`currentValueKg`, `currentReps`, or `currentDistanceKm` / `currentDurationMinutes`) — unchanged from existing behavior.
- **Sparkline** reflects per-workout performance: each matching workout produces a snapshot anchored to its `workout.date`, using that workout's best-of-day session value. Multiple matching workouts on the same date collapse to a single snapshot with the best-of-day value.

### Snapshot Triggers
Snapshots are computed/recomputed whenever matching workout data changes:
- After workout log → snapshot appended/updated on `workout.date` for each affected goal.
- After workout edit → snapshot recomputed on the workout's `date`. If the edit changed `date`, both old-date and new-date snapshots recompute.
- After workout deletion → snapshot on the deleted workout's `date` recomputes from remaining matching in-scope workouts on that date. If no remaining in-scope workouts on that date, the snapshot is deleted.
- After workout type deletion → bulk recompute across all affected dates per the per-workout rules above.
- After goal definition edit (Add/Edit Goal) → if `resetDate` was cleared, previously out-of-scope workouts may now qualify; rebuild snapshots for affected dates from in-scope workouts. GoalSnapshotService exposes a `rebuildSnapshots(goal:)` operation for this path.
- **Not on `lastCelebratedDate` change or ring display changes alone** — only on actual underlying workout or scope changes.

Weekly Workouts is a special case: its value is a runtime count, so a snapshot is written on any day a matching workout is logged (today), with `value` = current week's workout count at end-of-day. Its existing behavior is unchanged.

### Per-Workout Value Computation (best-of-day)
For a given goal and calendar date, the snapshot `value` is computed from all **in-scope, matching** workouts on that date (per § Reset Scoping). "Best-of-day" applies the same per-goal-type arithmetic as the ring's "best-ever within scope" logic (see § Goal Auto-Update), but scoped to a single date rather than the full goal history:

| Goal Type | Best-of-day input | Snapshot `value` |
|---|---|---|
| exercisePR (Strength PR) | Top `weightKg` across matching ExerciseSets on that date (name match, case-insensitive) | That weight in kg. No matching sets → no snapshot written (or existing one deleted on recompute). |
| repsPR (Repetitions PR) | Highest `reps` across matching ExerciseSets on that date | That rep count as `Double`. Same no-match behavior as exercisePR. |
| speedDistance — distance-only | Highest `distanceKm` across matching-type workouts on that date | Distance progress % (`distanceKm / targetDistanceKm × 100`, clamped 0–100). |
| speedDistance — duration-only (endurance) | Highest `durationMinutes` across matching-type workouts on that date | Duration progress % (`durationMinutes / targetDurationMinutes × 100`, clamped 0–100). |
| speedDistance — speed target (both set) | Per-workout `overallProgress %` per § Goal Progress Calculation; take the highest. Ties broken by most recent workout. | That `overallProgress %`. |
| weeklyWorkouts | Runtime count (special case — see below) | `Double(current workout count this week)` at end of day. |

### Rules
- **One snapshot per goal per day:** Deduplicates by `goalId` + calendar date (time component zeroed). Best-of-day computation applies when multiple matching workouts exist on the same date.
- **No backfilling for brand-new goals:** Snapshots are only computed for dates on which a matching in-scope workout exists. There is no historical scan at goal creation. The sparkline carries forward the last known value for days with no snapshot.
- **No automatic pruning:** Snapshots persist for the lifetime of the goal. Snapshots are deleted only by: (a) goal deletion cascade, (b) Reset Goal Progress (wipes all), or (c) workout-change cascade that removes the last supporting in-scope workout on a given date.
- **Out-of-scope filtering:** All per-workout computations ignore workouts where `workout.date <= goal.resetDate` AND `workout.lastModifiedDate <= goal.resetDate` (per § Reset Scoping). A snapshot is not written for dates that have no in-scope matching workout.
- **Migration:** Existing GoalSnapshot records written under the prior PR-event model are left alone. They will be gradually superseded as new snapshots are written and as edit/delete cascades recompute dates; there is no one-time historical rebuild at update. Old and new snapshots coexist on the sparkline during the transition.

### Responsibilities
- **recomputeSnapshot(goal, date, context):** Computes and writes (or deletes) the snapshot for a given goal and date based on currently stored in-scope matching workouts. Called from goal auto-update, workout delete/edit cascades. Idempotent.
- **recomputeSnapshotsForWorkout(workout, affectedGoals, context):** For each affected goal, recomputes the snapshot on `workout.date`. If the caller also supplies a prior date (on edit with date change), recomputes that too.
- **rebuildSnapshots(goal, context):** Drops all existing snapshots for this goal and rebuilds from all in-scope matching workouts. Called on goal definition edit when `resetDate` clears.
- **fetchSnapshots(goalId, days: 30, context) → [GoalSnapshot]:** Returns snapshots for the given goal within the last N days, sorted by date ascending.
- **deleteSnapshots(goalId, context):** Removes all snapshots for a given goal. Called on goal deletion cascade and on Reset Goal Progress.


---

## WorkoutShareService (WorkoutShareService.swift)

**Purpose:** Renders a single workout as a styled PNG image card and presents the iOS share sheet from the Workout Detail screen. See `SCREENS.md` § Workout Detail (Share Image Card) for full card layout, styling, and edge cases.

### Responsibilities

- **renderShareImage(workout: Workout, userSettings: UserSettings) → UIImage:** Builds a `WorkoutShareCardView` (a pure SwiftUI view not displayed on screen), renders it via `ImageRenderer` at @3x scale. Respects `useLbs` and `useMiles` from UserSettings for unit display. Returns the rendered `UIImage`.
- **presentShareSheet(image: UIImage):** Presents `UIActivityViewController` via a `UIViewControllerRepresentable` wrapper. Activity items: `[UIImage]`. No excluded activity types (allow all system share targets).

### Rendering Rules

- Uses the same color tokens and typography from `Theme/` — no hardcoded values.
- Weight display: `weightKg` converted via `UnitConversion` if `useLbs == true`.
- Distance display: `distanceKm` converted via `UnitConversion` if `useMiles == true`.
- Exercise list capped at 10. If workout has more than 10, show first 10 followed by muted "+X more exercises" line.
- Date/time format follows device locale (matches Workout Detail screen behavior). When `workout.time` is nil, omit time component.
- Summary pills with nil values omitted entirely.
- Session notes excluded from the image.

### Error Handling

If `ImageRenderer` returns nil (render failure), show a brief toast: "Couldn't generate image. Try again." (auto-dismiss ~2s, matching existing toast pattern). Do not present the share sheet.


---

## TemplateShareService (TemplateShareService.swift)

**Purpose:** Encodes workout templates into QR code URLs, generates QR code images, decodes incoming QR URLs, and handles template import with duplicate name resolution. See `SCREENS.md` § Workout Templates List (Share Template QR Modal) and `SCREENS.md` § Template Import Prompt for UI specs.

### URL Scheme

```
fitnavi://template?v=1&data=<base64-encoded-JSON>
```

- **Scheme:** `fitnavi` — registered in Info.plist as a custom URL type.
- **Host:** `template` — identifies the payload type for future extensibility.
- **v:** Payload version (integer). Current version: `1`. Used for forward compatibility — if the payload format changes, the decoder can handle or reject older/newer versions.
- **data:** Base64url-encoded JSON string containing the full template data.

### Payload Format (v1)

```json
{
  "v": 1,
  "name": "Push Day",
  "workoutType": "Strength Training",
  "durationMinutes": 60,
  "exercises": [
    {
      "exerciseName": "Bench Press",
      "sets": 4,
      "reps": 8,
      "weightKg": 84.0,
      "sortOrder": 0
    },
    {
      "exerciseName": "Push-Ups",
      "sets": 3,
      "reps": 15,
      "weightKg": null,
      "sortOrder": 1
    }
  ]
}
```

- `durationMinutes`: null when not set.
- `weightKg`: null for bodyweight exercises.
- `workoutType`: Must be "Strength Training" or "HIIT". Any other value is treated as malformed.
- Exercises ordered by `sortOrder`.

### Responsibilities

- **encodeTemplate(template: WorkoutTemplate) → URL:** Serializes the template and its TemplateExerciseSets into the v1 JSON payload, base64url-encodes it, and constructs the `fitnavi://` URL.
- **generateQRCode(from url: URL) → UIImage?:** Uses Core Image `CIQRCodeGenerator` to produce a QR code image from the URL string. Returns nil on failure. Native framework — no third-party dependency.
- **decodeTemplateURL(url: URL) → TemplatePayload?:** Parses the incoming URL, extracts the `data` parameter, base64url-decodes it, deserializes the JSON into a `TemplatePayload` struct. Returns nil if any step fails (malformed URL, invalid base64, JSON parse error, missing required fields, invalid workoutType).
- **importTemplate(payload: TemplatePayload, context: ModelContext) → WorkoutTemplate:** Creates a new WorkoutTemplate + TemplateExerciseSets in SwiftData from the decoded payload. Calls `resolveTemplateName` to handle duplicates before saving.
- **resolveTemplateName(name: String, context: ModelContext) → String:** Checks if a template with the given name exists. If not, returns the name as-is. If so, appends " (1)", " (2)", etc., incrementing until a unique name is found.

### QR Code Generation Rules

- Uses `CIQRCodeGenerator` from Core Image (native, no third-party).
- Error correction level: `M` (medium — 15% recovery, good balance of data density and damage tolerance).
- Output scaled to ~250pt for comfortable scanning from a phone screen.
- QR image rendered as white modules on transparent background, displayed on Card Surface (#1a1a1a) in the modal.

### QR Code Size Limits

QR codes (version 40, error correction M) can hold ~2,331 bytes in binary mode. A template with 10 exercises and typical field lengths encodes to approximately 500–800 bytes after base64, well within limits. Templates with 20+ exercises or very long names may approach the limit. If the encoded URL exceeds 2,331 bytes, show a toast: "Template is too large to share via QR code." (~2s auto-dismiss). Do not generate the QR code.

### Deep Link Handling

The app must register `fitnavi` as a custom URL scheme in Info.plist. In `FortiFitApp.swift`, handle incoming URLs via `.onOpenURL { url in ... }`. When a `fitnavi://template` URL is received:

1. Call `decodeTemplateURL(url:)`.
2. If decoding succeeds → present the Template Import Prompt (see `SCREENS.md` § Template Import Prompt).
3. If decoding fails → present the error modal with "This QR code couldn't be read." message.

---

## RecoveryStatusService (RecoveryStatusService.swift) — Phase 11

**Purpose:** Single owner of all sleep data orchestration, the Recovery Status widget's gating state, the 30-day sleep cache, sleep efficiency, sleep-load correlation, smart workout suggestions, and personal pattern insights. Sits between `HealthKitClient` (sleep methods, see § HealthKitClient) and the widget / detail-sheet view layer. Does not own the sleep observer subscription itself — `HealthKitSyncService` owns that and dispatches into this service. Does own everything downstream.

### Responsibilities

- **Sleep aggregation.** Translate `HKSleepSampleSnapshot` arrays into `DailySleepSnapshot` records per HEALTHKIT.md § 21 (6pm-to-6pm wake-up-date window, all `.asleep*` stages summed, optional `.inBed` for efficiency).
- **30-day in-memory cache.** Rolling cache of `DailySleepSnapshot` records loaded from the SwiftData store on launch and kept current via observer fires + 6pm-cutoff catch-ups. Drives the detail sheet's sparkline + last-7-nights stat row without on-demand HK queries.
- **Gating state computation.** `RecoveryStatusGatingState` enum (`connectAppleHealth`, `sleepAccessDenied`, `noSleepTracker`, `live`) — see SCREENS.md § Home Screen → Recovery Status widget → States for derivation rules. Computed from `UserSettings.healthKitEnabled`, `HealthKitClient.authorizationStatus()` for sleep scope, and `hasRecentSleepData(within: 14)`.
- **Sleep efficiency.** Compute and cache `sleepEfficiencyPercent = round(asleepDuration / inBedDuration × 100)`. When the source writes explicit `.inBed` samples (Oura, Whoop, AutoSleep, manual logging), `inBedDuration` is the Σ of those samples. When the source omits them — Apple Watch's native sleep tracker on watchOS 9+ does, see BUG-059 — `inBedDuration` falls back to `totalSleepMinutes + awakeMinutes` so efficiency surfaces for the most common HK source. Nil only when neither path yields data (e.g., zero asleep minutes). `reloadCacheFromStore` also backfills the same fallback into legacy snapshots written before BUG-059 shipped, so pre-fix data repairs on next launch instead of waiting for a fresh HK ingest.
- **Personal Pattern Insights.** `computePersonalInsights()` returns up to 3 auto-detected patterns from ≥ 21 days of paired (sleep, next-day-score) data. Detection types: score-by-sleep-bucket, sleep-by-workout-type, multi-week aggregates. Per-pattern detection thresholds and selection priority are defined inline in the service implementation.
- **Sleep-Load correlation.** `computeSleepLoadCorrelation()` — median-split paired data at the 7h sleep mark; return `correlationDelta = mean(highSleepScores) - mean(lowSleepScores)` and a copy variant (high-sleep / low-sleep / no-pattern). Copy variants live in CONSTANTS.md § Linked Recovery & Load Detail Sheet → Correlation Callout; the three variants are selected by sign + magnitude (`correlationDelta <= -5` / `correlationDelta >= +5` / `|correlationDelta| < 5`).
- **Linked Recovery & Load advisory.** `computeLinkedAdvisory(baseAdvisory:zone:trainedToday:sleepHours:targetSleepHours:)` returns a single coherent sentence drawn from `AppConstants.TrainingLoad.linkedAdvisoryText`, keyed on the TL zone, whether the user trained today, and the sleep-to-target ratio bucket. Met-target (`0.85–0.99`) and missing-data nights pass `baseAdvisory` through unchanged. Used **only** by the linked Recovery & Load composite (TL widget body in the linked pair + Linked Recovery & Load Detail Sheet's Recovery Readiness callout); the standalone TL widget keeps rendering `LoadResult.advisory` directly. Replaces the prior `computeSleepQualifier` concat pattern that produced contradictions (BUG-061). Copy in CONSTANTS.md § Training Load Zones → Linked Advisory Copy.
- **Time-since-last-workout.** `timeSinceLastWorkout()` reads the most recent `Workout.date` across all workouts (manual or HK-imported, any of the 6 types), formats with the trailing "since your last workout" descriptor used by the detail sheet's headline row. Per-type variant `timeSinceLastWorkout(for type: String)` for the detail sheet's per-type rows. The bare-value variant `lastWorkoutHero()` (no trailing descriptor — `4h 12m` / `NO DATA` on cold start) drives the Recovery Status widget's SINCE LAST WORKOUT hero column per CONSTANTS.md § Recovery Status Widget → Since Last Workout Hero Value.
- **Apple Health sleep goal import.** `importSleepGoalFromAppleHealth()` reads `HealthKitClient.fetchSleepDurationGoal()`. If non-nil, write the value (rounded to 0.5 hr increment) into `UserSettings.targetSleepHours`. If nil, emit a Toast Style toast: `"No sleep goal set in Apple Health."` Called only from the "Import from Apple Health" actions in the Recovery Status Settings Modal and the Linked Recovery & Load Settings Modal.

### Derived State (read-only, reactive)

The service exposes these as `@Observable` properties consumed by the widget and detail-sheet view layer:

| Property | Type | Refresh trigger |
|---|---|---|
| `currentGatingState` | `RecoveryStatusGatingState` | App launch, HK auth change, `UserSettings.healthKitEnabled` flip, sleep observer fire (`hasRecentSleepData` re-evaluation), 14-day sleep window rollover |
| `todaysSnapshot` | `DailySleepSnapshot?` | Sleep observer fire, app launch catch-up, 6pm-cutoff |
| `recent30DaySleep` | `[DailySleepSnapshot]` | Same as above |
| `timeSinceLastWorkoutFormatted` | `String` | Foreground entry, 60s timer while Home tab visible, Workout Cascade |
| `lastWorkoutHeroFormatted` | `String` (bare value — `4h 12m` / `NO DATA`) | Same as `timeSinceLastWorkoutFormatted` (refreshed alongside it in `refreshTimerLine`) |
| `currentSleepEfficiencyPercent` | `Int?` | Sleep Cascade |

The linked advisory copy is *not* cached on the service — the joint string depends on the live TL zone + `trainedToday` signal in addition to sleep, so call sites compute it on demand via `computeLinkedAdvisory(...)` (BUG-061).

### Refresh Triggers

| Trigger | Behavior |
|---|---|
| App launch | Run `refresh(forceCatchUp: true)` — anchored sleep query for new samples since `UserSettings.healthKitAnchor`, rebuild 30-day cache from `DailySleepSnapshot` store, evaluate `currentGatingState`. |
| Sleep observer fires (via `HealthKitSyncService`) | `handleSleepObserverFire()` — fetch any new sleep samples, upsert affected `DailySleepSnapshot` records, append to cache, fire Sleep Cascade. |
| 6pm-cutoff catch-up (via `HealthKitSyncService`) | `refresh(forceCatchUp: true)` — same as launch, but only for sleep. |
| `BGAppRefreshTask` (via `HealthKitSyncService`) | `refreshFromBackground()` — fetch any new sleep samples, upsert today's snapshot if changed, fire Sleep Cascade. |
| `UserSettings.targetSleepHours` change | If linked, trigger Sleep Cascade (TL score depends on `targetSleepHours`). The linked advisory copy isn't cached — it re-computes on every render of the linked composite. |
| Workout Cascade fires | Bump `timeSinceLastWorkoutFormatted` and `lastWorkoutHeroFormatted` only. Does NOT re-query sleep — sleep inputs flow through Sleep Cascade. |
| Local midnight rollover | Roll the wake-up day forward — yesterday's snapshot becomes historical, today starts empty. |

### Threading

All public methods are `@MainActor`-isolated. Internal `HealthKitClient` calls run on whatever actor the client elects; the result handlers hop back to MainActor before any SwiftData write or `@Observable` property mutation.

### Cascade Impact

`RecoveryStatusService` is the entry point for the Sleep Cascade (see § Sleep Cascade). It is NOT a participant in the Workout Cascade — workout changes only bump the timer line and last-workout hero value.

When `currentGatingState` transitions from `live` to anything else, `HomeWidgetService.isLinkedActive(...)` re-evaluates → if currently linked, the composite auto-unlinks (per CONSTANTS.md § Linked Recovery & Load → Animation Timing). Conversely, transitioning from any non-`live` state to `live` re-evaluates `isLinkedActive` → if the pair is adjacent AND `recoveryLoadManuallyUnlinked == false`, the composite auto-links.

