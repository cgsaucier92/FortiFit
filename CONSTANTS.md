# CONSTANTS.md: FitNavi Constants & Reference Values

> All values to define in `AppConstants.swift` and `Design/Theme/`. Do not invent additional options or modify these lists without updating this document.

---

## Colors (Colors.swift)

| Token | Hex | Usage |
|-------|-----|-------|
| Primary Accent (Blue) | `#3b82f6` | Brand mark, active tabs, CTAs, key data, headings |
| Secondary (Light Blue) | `#60a5fa` | Charts, gradient anchors, secondary emphasis |
| Background (Dark) | `#0a0a0a` | Primary screen background |
| Card Surface | `#1a1a1a` | Card backgrounds, tab bar, status bar |
| Elevated Surface | `#2d2d2d` | Toggle backgrounds, exercise pills, inputs, inner cards |
| Border | `#404040` | All card and divider borders |
| Primary Text | `#e5e5e5` | Headings, body content, data values |
| Muted Text | `#737373` | Labels, secondary info, inactive tabs, hints |
| Secondary Text | `#a3a3a3` | Tertiary data emphasis, exercise pill text, note text |
| Caution (Yellow) | `#C4F648` | Moderate load, cautionary warnings |
| Warning (Dark Yellow) | `#B7FF00` | Moderate-high load, more intense warnings |
| Positive (Green) | `#10b981` | Low load, PR indicators, weekly frequency goal |
| Alert (Red) | `#ef4444` | Peak load, high-intensity warnings |
| Chart (Purple) | `#4B2893` | A potential color for chart lines or bars |
| Chart (Orange) | `#934F28` | A potential color for chart lines or bars |
| Chart (Teal) |`#289193`| A potential color for chart lines or bars |
| Chart (Pink) | `#BB2BC0` | A potential color for chart lines or bars |
| Chart (Light Cyan) | `#8​FE6​F6` | A potential color for chart lines or bars |
| Chart (Deep Blue) | `#0845​AD` | A potential color for chart lines or bars |
| HealthKit Pink | `#FF2D55` | Source indicator heart icon on Workout Detail, peripheral glyphs on Home/Workouts/Plan, info sheet accents. Matches Apple's system pink used in the Health app. See HEALTHKIT.md § 15. |
---

## Ellipsis Menu SF Symbols

Icons displayed to the left of each option in the top-nav ellipsis (`…`) menus. All are rendered at the standard ellipsis-menu text-row size, colored per the standard menu-row text color.

| Screen | Option | SF Symbol |
|--------|--------|-----------|
| Home | Add Widgets | `plus.rectangle.on.rectangle` |
| Workouts | Create Workout Template | `square.and.pencil` |
| Workouts | View Saved Templates | `doc.on.doc` |
| Log Workout | Use workout template | `doc.badge.arrow.up` |
| Log Workout | Save as workout template | `square.and.arrow.down` |
| Create Template (edit mode) | Share Template | `qrcode` |
| Workout Detail (Strength/HIIT only) | Save as workout template | `square.and.arrow.down` |
| Workout Detail (when `hiddenFromPlan == true`) | Show on Plan | `calendar.badge.plus` |
| Plan | Saved Templates | `doc.on.doc` |
| Trends | Add Charts | `chart.xyaxis.line` |
| Goals | Filter Goals | `line.3.horizontal.decrease.circle` |
| Goals | Expand All | `rectangle.expand.vertical` |
| Goals | Collapse All | `rectangle.compress.vertical` |

**Shared-symbol consistency:** "Save as workout template" uses the same symbol (`square.and.arrow.down`) wherever it appears (Log Workout ellipsis, Workout Detail ellipsis). "Saved Templates" navigation uses the same symbol (`doc.on.doc`) on both the Workouts and Plan ellipsis menus.

**Goals Expand/Collapse toggle:** The symbol swaps alongside the label based on dominant card state — `rectangle.expand.vertical` when most cards are collapsed (label: "Expand All"), `rectangle.compress.vertical` when most are expanded (label: "Collapse All"). See SCREENS.md § Goals Ellipsis Menu.

---

## Workout Detail Summary Icons

Icons rendered to the left of each label in the Summary section of the Workout Detail screen. Also rendered on the Share Image Card summary pills for visual consistency (see § Share Image Card Styling).

| Field | SF Symbol | Visible On |
|-------|-----------|-----------|
| Effort | `heart.gauge.open` | All workout types (when rated) |
| Duration | `clock` | All workout types (when recorded) |
| Distance | `ruler` | Cardio only (when recorded) |

**Rendering (Workout Detail Summary):** Icon is rendered at the same size and color as the summary row label text, with standard spacing between icon and label. See SCREENS.md § Workout Detail.

**Rendering (Share Image Card):** Icon is rendered at the same size and color as the summary pill text, with standard spacing between icon and pill text. See § Share Image Card Styling and SCREENS.md § Share Image Card.

---

## Workout Detail Health Data Icons

Icons rendered to the left of each row in the **right column of the Summary two-column grid** on Workout Detail (visible only when `workout.healthKitUUID != nil` AND at least one HK measurement field is non-nil). The left column of that grid contains user-entered fields (see § Workout Detail Summary Icons above). See SCREENS.md § Workout Detail for the full layout — specifically the two-column variant of the Summary block.

| Field | SF Symbol | Visible When |
|-------|-----------|--------------|
| Avg Heart Rate | `heart.fill` | `avgHeartRate != nil` |
| Max Heart Rate | `heart.circle.fill` | `maxHeartRate != nil` |
| Active Calories | `flame.fill` | `activeEnergyKcal != nil` |
| Total Calories | `flame.circle.fill` | `totalEnergyBurnedKcal != nil` |
| Elevation Ascended | `mountain.2.fill` | `elevationAscendedMeters != nil` |
| Exercise Minutes | `timer` | `exerciseMinutes != nil` |
| Indoor | `building.2.fill` | `indoor == true` (inline badge) |
| Outdoor | `sun.max.fill` | `indoor == false` (inline badge) |

**Row ordering within the right column** (top to bottom, omitting nil values):
1. Heart Rate row (Avg HR · Max HR — paired on one row when both present)
2. Calories row (Active · Total — paired on one row when both present)
3. Elevation Ascended
4. Exercise Minutes
5. Indoor/Outdoor badge

**Rendering:** Same size and color as the left-column (user-entered) row labels. Pairs (Avg HR + Max HR; Active kcal + Total kcal) render together within a single right-column row with a `·` separator. Conditional — rows with nil values are omitted entirely, and the right column as a whole does not render if every HK measurement field is nil (Summary falls back to its single-column layout in that case).

---

## Workout Types

```swift
["Strength Training", "HIIT", "Cardio", "Yoga", "Pilates", "Other"]
```

"Other" is a catch-all for HealthKit imports whose activity type doesn't cleanly map to one of the first five categories (see § HealthKit Mapping below). It is also user-selectable in the Log Workout type dropdown, though most users will use it only for imported workouts.

**Sprints removed:** Prior versions of FortiFit included a "Sprints" workout type. Phase 8 removes it and runs a one-time migration that rewrites all existing Sprints workouts to Cardio (see HEALTHKIT.md § 18).

### Workout Type Modifiers (Training Load)

| Workout Type | Modifier | Rationale |
|---|---|---|
| Strength Training | 1.0 | Baseline. High neuromuscular demand. |
| HIIT | 1.1 | Combines metabolic + muscular stress. |
| Cardio | 0.7 | Sustained but lower peak intensity. |
| Pilates | 0.5 | Moderate muscular engagement. |
| Yoga | 0.3 | Primarily restorative. |
| Other | 0.7 | Unknown-stress default. Matches Cardio as a safe midpoint — most "Other" HK activities (team sports, martial arts, racquet sports, outdoor recreation) land in this stress range. |

### Workout Type SF Symbols

Icons rendered to the left of the workout type name on Workout Type cards (Workouts screen). Sourced from Apple's Fitness / Workout app conventions to match user expectations.

| Workout Type | SF Symbol |
|--------------|-----------|
| Strength Training | `dumbbell.fill` |
| HIIT | `figure.highintensity.intervaltraining` |
| Cardio | `figure.mixed.cardio` |
| Yoga | `figure.yoga` |
| Pilates | `figure.pilates` |
| Other | `figure` |

**Rendering:** Icon is rendered at the same size and color as the workout type name text on the card, with standard spacing between icon and text. See SCREENS.md § Workout Type Card for placement.

---

## HealthKit Mapping

Static lookup table mapping every `HKWorkoutActivityType` enum case to a FortiFit `workoutType` plus a friendly display string (stored on `Workout.healthKitActivityType`). Used by `HealthKitSyncService` at import time. See HEALTHKIT.md § 6 for the architectural rationale; see § 9 for where this table is consulted.

**Rules:**
- Every currently defined `HKWorkoutActivityType` has an explicit entry.
- Unknown types (introduced by future iOS versions after this table was authored) fall through to `Other` with the raw enum case name as the display string (Claude Code implements this as a `default` case in the mapping function).
- For activity types with indoor/outdoor variants (`running`, `cycling`, `rowing`, etc.), the display string is the base name; the `workout.indoor` flag layers on "Indoor"/"Outdoor" prefixing at display time in the UI (see SCREENS.md § Workout Detail).
- Static table. Not user-configurable.

### Mapping Table

| HKWorkoutActivityType | Display String | FortiFit `workoutType` |
|---|---|---|
| `americanFootball` | American Football | Other |
| `archery` | Archery | Other |
| `australianFootball` | Australian Rules Football | Other |
| `badminton` | Badminton | Other |
| `barre` | Barre | Other |
| `baseball` | Baseball | Other |
| `basketball` | Basketball | Other |
| `bowling` | Bowling | Other |
| `boxing` | Boxing | Other |
| `cardioDance` | Cardio Dance | Cardio |
| `climbing` | Climbing | Other |
| `cooldown` | Cooldown | Other |
| `coreTraining` | Core Training | Strength Training |
| `cricket` | Cricket | Other |
| `crossCountrySkiing` | Cross-Country Skiing | Cardio |
| `crossTraining` | Cross Training | HIIT |
| `curling` | Curling | Other |
| `cycling` | Cycling | Cardio |
| `discSports` | Disc Sports | Other |
| `downhillSkiing` | Downhill Skiing | Cardio |
| `elliptical` | Elliptical | Cardio |
| `equestrianSports` | Equestrian Sports | Other |
| `fencing` | Fencing | Other |
| `fishing` | Fishing | Other |
| `fitnessGaming` | Fitness Gaming | HIIT |
| `flexibility` | Flexibility | Other |
| `functionalStrengthTraining` | Functional Strength Training | Strength Training |
| `golf` | Golf | Other |
| `gymnastics` | Gymnastics | Other |
| `handCycling` | Hand Cycling | Cardio |
| `handball` | Handball | Other |
| `highIntensityIntervalTraining` | HIIT | HIIT |
| `hiking` | Hiking | Cardio |
| `hockey` | Hockey | Other |
| `hunting` | Hunting | Other |
| `jumpRope` | Jump Rope | Other |
| `kickboxing` | Kickboxing | Other |
| `lacrosse` | Lacrosse | Other |
| `martialArts` | Martial Arts | Other |
| `mindAndBody` | Mind and Body | Other |
| `mixedCardio` | Mixed Cardio | Cardio |
| `mixedMetabolicCardioTraining` | Mixed Metabolic Cardio Training | Cardio |
| `paddleSports` | Paddle Sports | Cardio |
| `pickleball` | Pickleball | Other |
| `pilates` | Pilates | Pilates |
| `play` | Play | Other |
| `preparationAndRecovery` | Preparation and Recovery | Other |
| `racquetball` | Racquetball | Other |
| `rowing` | Rowing | Cardio |
| `rugby` | Rugby | Other |
| `running` | Running | Cardio |
| `sailing` | Sailing | Other |
| `skatingSports` | Skating Sports | Cardio |
| `snowSports` | Snow Sports | Cardio |
| `snowboarding` | Snowboarding | Cardio |
| `soccer` | Soccer | Other |
| `socialDance` | Social Dance | Cardio |
| `softball` | Softball | Other |
| `squash` | Squash | Other |
| `stairClimbing` | Stair Climbing | Cardio |
| `stairs` | Stairs | Cardio |
| `stepTraining` | Step Training | Cardio |
| `surfingSports` | Surfing | Cardio |
| `swimBikeRun` | Swim Bike Run | Cardio |
| `swimming` | Swimming | Cardio |
| `tableTennis` | Table Tennis | Other |
| `taiChi` | Tai Chi | Other |
| `tennis` | Tennis | Other |
| `trackAndField` | Track and Field | Cardio |
| `traditionalStrengthTraining` | Traditional Strength Training | Strength Training |
| `transition` | Transition | Cardio |
| `underwaterDiving` | Underwater Diving | Other |
| `volleyball` | Volleyball | Other |
| `walking` | Walking | Cardio |
| `waterFitness` | Water Fitness | Cardio |
| `waterPolo` | Water Polo | Other |
| `waterSports` | Water Sports | Cardio |
| `wheelchairRunPace` | Wheelchair Run Pace | Cardio |
| `wheelchairWalkPace` | Wheelchair Walk Pace | Cardio |
| `wrestling` | Wrestling | Other |
| `yoga` | Yoga | Yoga |
| `other` | Other | Other |
| *(unknown future types)* | *raw enum name* | Other |

### Ambiguous Mappings (Judgment Calls)

The following HK types had plausible arguments for more than one FortiFit category. The selections above were made based on the activity's typical stress profile and the user's likely mental model. Flagged here so the call can be reviewed and changed if needed — the mapping is authoritative in the table above; this list is informational.

| HK Type | Chosen | Alternative | Rationale |
|---|---|---|---|
| `crossTraining` | HIIT | Strength Training | CrossFit-style mixed workouts blend both, but the metabolic intensity leans HIIT. |
| `fitnessGaming` | HIIT | Cardio | Wide variance, but most (Ring Fit, Beat Saber fitness modes) are interval-based. |
| `stepTraining` | Cardio | HIIT | Step aerobics is sustained moderate-intensity. |
| `wrestling` | Other | Strength Training | Team/competitive context dominates over strength character for most users. |
| `martialArts` | Other | HIIT | Huge variance (Krav Maga would be HIIT, Aikido would be closer to Other); "Other" is the safest default. |
| `trackAndField` | Cardio | Other | Most tracked events (running, sprinting) are cardio; field events are rare. |
| `paddleSports` | Cardio | Other | Kayaking/canoeing are sustained cardiovascular activity. |
| `surfingSports` | Cardio | Other | Active paddling and balance work; net cardiovascular demand. |
| `waterSports` | Cardio | Other | Generic water activities; leans cardio. |

**Resolved to Other by design:** `barre`, `boxing`, `kickboxing`, `jumpRope`, `gymnastics`, `mindAndBody`, `taiChi`, `flexibility`, `cooldown`, `preparationAndRecovery`. Earlier drafts placed several of these in Pilates, HIIT, Strength Training, or Yoga; during spec review they were moved to Other to keep the five primary categories tight and to avoid muddying their Training Load modifiers with activities that have high stress variance.

**Changing a mapping:** edit the table above, then verify the HK-to-category mapping unit test in `FortiFitTests` still passes (the test iterates every enum case and asserts the expected category — see TESTING.md § HealthKit Test Strategy).

---

## Exercise Options (for Goals dropdown)

```swift
["Bench Press", "Barbell Squats", "Deadlifts", "Overhead Press", "Barbell Rows", "Incline Bench Press", "Custom"]
```

All non-Custom values must exist in the Exercise Dictionary. When "Custom" is selected, the name input uses the same autocomplete behavior as Log Workout (ExerciseSuggestionService).

---

## Exercise Dictionary (for Autocomplete)

Curated list for ExerciseSuggestionService cold-start suggestions. Organized by category for maintainability, stored and queried as a flat `[String]` array at runtime.

- **Chest:** "Bench Press", "Incline Bench Press", "Decline Bench Press", "Dumbbell Bench Press", "Incline Dumbbell Press", "Dumbbell Flyes", "Incline Dumbbell Flyes", "Cable Crossovers", "Chest Dips", "Machine Chest Press", "Push-Ups"
- **Back:** "Barbell Rows", "Dumbbell Rows", "Pendlay Rows", "T-Bar Rows", "Seated Cable Rows", "Pull-Ups", "Chin-Ups", "Lat Pulldowns", "Face Pulls", "Straight-Arm Pulldowns", "Rack Pulls"
- **Shoulders:** "Overhead Press", "Dumbbell Shoulder Press", "Arnold Press", "Lateral Raises", "Front Raises", "Reverse Flyes", "Upright Rows", "Cable Lateral Raises", "Machine Shoulder Press"
- **Legs:** "Barbell Squats", "Front Squats", "Goblet Squats", "Bulgarian Split Squats", "Leg Press", "Hack Squats", "Lunges", "Walking Lunges", "Romanian Deadlifts", "Leg Extensions", "Leg Curls", "Hip Thrusts", "Glute Bridges", "Calf Raises", "Seated Calf Raises"
- **Arms:** "Barbell Curls", "Dumbbell Curls", "Hammer Curls", "Preacher Curls", "Concentration Curls", "Cable Curls", "Tricep Pushdowns", "Skull Crushers", "Overhead Tricep Extensions", "Tricep Dips", "Close-Grip Bench Press"
- **Compound / Full Body:** "Deadlifts", "Sumo Deadlifts", "Trap Bar Deadlifts", "Power Cleans", "Clean and Press", "Kettlebell Swings", "Farmers Walks", "Turkish Get-Ups"
- **Core:** "Planks", "Hanging Leg Raises", "Cable Crunches", "Ab Wheel Rollouts", "Russian Twists", "Woodchoppers"
- **HIIT / Cardio Exercises:** "Box Jumps", "Burpees", "Battle Ropes", "Sled Push", "Sled Pull", "Rowing Machine", "Assault Bike"

---

## Exercise Alias Map (for Autocomplete)

`[String: String]` dictionary. All alias keys matched case-insensitively.

```swift
"OHP": "Overhead Press",
"BB Rows": "Barbell Rows",
"BB Squats": "Barbell Squats",
"BB Curls": "Barbell Curls",
"DB Rows": "Dumbbell Rows",
"DB Bench": "Dumbbell Bench Press",
"DB Press": "Dumbbell Shoulder Press",
"DB Curls": "Dumbbell Curls",
"DB Flyes": "Dumbbell Flyes",
"RDL": "Romanian Deadlifts",
"RDLs": "Romanian Deadlifts",
"SLDL": "Romanian Deadlifts",
"BSS": "Bulgarian Split Squats",
"CG Bench": "Close-Grip Bench Press",
"CGBP": "Close-Grip Bench Press",
"Skull Crusher": "Skull Crushers",
"Tri Pushdown": "Tricep Pushdowns",
"Tri Pushdowns": "Tricep Pushdowns",
"Lat Raise": "Lateral Raises",
"Lat Raises": "Lateral Raises",
"Lat Pulldown": "Lat Pulldowns",
"Face Pull": "Face Pulls",
"Hip Thrust": "Hip Thrusts",
"Calf Raise": "Calf Raises",
"KB Swings": "Kettlebell Swings"
```

All alias targets must exist in the Exercise Dictionary.

---

## Experience Levels

```swift
[Beginner (< 1 year), Intermediate (1–3 years), Advanced (3+ years)]
// Stored as Int: 0, 1, 2
```

---

## Effort Scale

Integers 1 through 10.

---

## Goal Types

```swift
["Strength PR", "Repetitions PR", "Speed and Distance", "Number of Weekly Workouts"]
```

### Goal Card Header Labels

The first label in the Goal Card's three-section left column (see `SCREENS.md` § Goal Card Design → Header Labels by goal type) is type-dependent. For Speed and Distance goals, the label additionally depends on which targets are set.

| Goal Type | Sub-case | Header Label |
|-----------|----------|--------------|
| `exercisePR` (Strength PR) | — | `STRENGTH GOAL` |
| `repsPR` (Repetitions PR) | — | `REPS GOAL` |
| `speedDistance` | `targetDistance != nil && targetDuration != nil` | `SPEED GOAL` |
| `speedDistance` | `targetDistance == nil && targetDuration != nil` | `ENDURANCE GOAL` |
| `speedDistance` | `targetDistance != nil && targetDuration == nil` | `DISTANCE GOAL` |
| `weeklyWorkouts` (Number of Weekly Workouts) | — | `FREQUENCY GOAL` |

Strings must be read from `AppConstants` — do not hardcode in views. Uses the standard sentence-case label treatment (11px, 700 weight, 2px letter-spacing, Primary Accent `#3b82f6`).

### Goal Colors (cycling assignment)

| Index | Color | Hex |
|-------|-------|-----|
| 0 | Orange | `#934F28` |
| 1 | Pink | `#BB2BC0` |
| 2 | Green | `#10b981` |
| 3 | Red | `#ef4444` |

Assigned via `colorIndex % 4`.

### Goal Card SF Symbol Silhouettes

| Goal Type | SF Symbol |
|-----------|-----------|
| Strength PR (`exercisePR`) | `dumbbell.fill` |
| Repetitions PR (`repsPR`) | `figure.strengthtraining.traditional` |
| Speed and Distance (`speedDistance`) | `figure.run` |
| Number of Weekly Workouts (`weeklyWorkouts`) | `calendar` |

### Goal Silhouette Opacity

| Progress | Opacity |
|----------|---------|
| 0% | 10% (floor) |
| 50% | ~25% (linear interpolation) |
| 100% | ~40% |
| Completed (100%) | 85–100% |

Scales linearly from 10% at 0% progress to ~40% at 100%. Completed state bumps to 85–100% so the silhouette reads as "lit up" rather than dim — see § Goal Card Completed State Treatment for the completed-state silhouette tint color. Exact curve tunable during implementation; 10% floor is fixed.

### Speed and Distance Dual-Arc Ring Colors

| Arc | Metric | Color | Hex |
|-----|--------|-------|-----|
| Outer | Distance | Purple | `#4B2893` |
| Inner | Duration | Light Cyan | `#8FE6F6` |

When only one target is set, a single ring is used with the corresponding color (purple for distance-only, light cyan for duration-only).

### Goal Card Progress Ring Sizing

| Property | Value |
|----------|-------|
| Ring diameter | ~120–140pt |
| Placement | Trailing edge of card, right-justified (consistent across all goal types — no centering offset for Speed and Distance) |
| Center content | SF Symbol silhouette only (overall progress percentage is surfaced via tap tooltip — see SCREENS.md § Goals → Ring Tap Behavior) |

### Goal Card Completed State Treatment

| Element | Value |
|---------|-------|
| Card border | Primary Accent Blue `#3b82f6` |
| Card surface wash | Primary Accent Blue at **3% opacity** overlaid on Card Surface |
| Top-center label | "COMPLETED [formal date]" (e.g., "COMPLETED APR 17, 2026") |
| Label color | Secondary Text `#a3a3a3` |
| Label style | 11px, 700 weight, 2px letter-spacing, uppercase |
| Date format | Formal: "MMM D, YYYY" (e.g., "Apr 17, 2026" → uppercased to "APR 17, 2026") |
| Date source | `Goal.lastCelebratedDate` |
| Silhouette opacity | 85–100% (per Goal Silhouette Opacity table above) |
| Silhouette color | Primary Accent Blue `#3b82f6` — applies to all goal-type silhouettes (`dumbbell.fill`, `figure.strengthtraining.traditional`, `figure.run`, `calendar`) on completion |
| Silhouette completion transition | 0.2–0.3s ease crossfade from active-state appearance to completed blue/lit state, synchronized with border/wash/label appearing |
| Ring fill | 100% (fully filled arc) |

The previous "✦ VICTORY ✦" label is removed and replaced entirely by the COMPLETED treatment above.

### Goal Completion Pulse Animation

| Property | Value |
|----------|-------|
| Trigger | User navigates to Goals screen AND a goal's `lastCelebratedDate` == today (local date) |
| Frequency | Once per visit to the Goals screen. Re-fires only on subsequent visits while condition remains true. |
| Duration | ~1–1.5 seconds total |
| Visual | Soft halo/glow emanating from the ring that matches the ring color, settling back into static completed state |
| Scope | Per-card — each newly-completed goal pulses on the visit; other completed goals (with older `lastCelebratedDate`) do not pulse |

### Goal Card Tease Animation

Goal cards use the **same long-press tease animation as Home screen widget cards** (slight lift/scale on press hold). Implementation must reference the existing Home widget tease pattern — do not invent new animation parameters.

---

## Widget Types

```swift
["trainingLoad", "workoutInfo", "weekStreak", "powerLevel", "todaysPlan"]
```

| Identifier | Display Name | Description |
|------------|-------------|-------------|
| `trainingLoad` | Training Load | Shows your accumulated training stress score and recovery readiness based on recent workout intensity, volume, and frequency. |
| `workoutInfo` | Workout Info | Displays your most recent workout and total workout count at a glance. |
| `weekStreak` | Week Streak | Tracks how many consecutive weeks you've met your weekly workout target. |
| `powerLevel` | Power Level | Measures your average strength volume trend over the last 30 days across Strength Training and HIIT workouts. |
| `todaysPlan` | Today's Plan | Shows your scheduled workout for today so you can jump straight into logging. |

### Default Home Widgets (first launch)
```swift
["trainingLoad", "workoutInfo", "weekStreak"]
```
Power Level not included by default.

---

## Chart Types (Trends Screen)

```swift
["strengthTracker", "trainingFrequency", "personalRecords", "trainingLoadTrend",
 "workoutVolume", "rpeTrend", "workoutTypeBreakdown", "sessionDuration"]
```

| Identifier | Display Name | Description |
|------------|-------------|-------------|
| `strengthTracker` | Strength Tracker | Tracks your max weight for a selected exercise over time so you can see strength progression at a glance. |
| `trainingFrequency` | Training Frequency | Shows how many workouts you completed each week, compared against your weekly target. |
| `personalRecords` | Personal Records | Compares your latest personal record against the previous record for each exercise. |
| `trainingLoadTrend` | Training Load Trend | Visualizes your daily training load score over the last two weeks so you can spot overtraining or recovery windows. |
| `workoutVolume` | Workout Volume | Tracks your total training volume per session over time to reveal whether you're progressively overloading. |
| `rpeTrend` | Effort Trend | Shows your average perceived exertion per week so you can monitor training intensity over time. |
| `workoutTypeBreakdown` | Workout Type Breakdown | Shows the distribution of your workout types so you can see if your training is balanced. |
| `sessionDuration` | Session Duration | Tracks your average workout duration per week to help you manage your time in the gym. |

### Default Trends Charts (first launch)
```swift
["strengthTracker", "trainingFrequency", "personalRecords", "trainingLoadTrend"]
```
Workout Volume, Effort Trend, Workout Type Breakdown, and Session Duration are available via Add Charts but not included by default.

### Workout Type Chart Colors

| Workout Type | Color | Hex |
|---|---|---|
| Strength Training | Primary Accent Blue | `#3b82f6` |
| HIIT | Secondary Blue | `#60a5fa` |
| Cardio | Positive Green | `#10b981` |
| Yoga | Warning Yellow | `#B7FF00` |
| Pilates | Alert Red | `#ef4444` |
| Other | Caution Yellow | `#C4F648` |

Used by the Workout Type Breakdown chart.

---

## Training Load Zones

| Score Range | Zone Label | Color |
|---|---|---|
| 0 | Resting | Muted |
| 1–30 | Low | Green (`#10b981`) |
| 31–55 | Moderate | Yellow (`#C4F648`) |
| 56–80 | High | Dark Yellow (`#B7FF00`) |
| 81–100 | Peak | Red (`#ef4444`) |

### Advisory Text (Context-Aware)

If user has NOT logged a workout today → readiness variant. If user HAS → post-training variant.

| Zone | Readiness (no workout today) | Post-Training (trained today) |
|---|---|---|
| Resting | "No recent training stress. Ready for a full session." | *(cannot occur — floor > 0 if trained today)* |
| Low | "Well recovered. Today is a good day to train hard." | "Session logged. Still feeling fresh." |
| Moderate | "Some muscle fatigue. A moderate session would be ideal." | "Good work today. Rest up." |
| High | "Significant muscle fatigue. Consider a lighter session or active recovery." | "Heavy day. Recovery is the priority." |
| Peak | "High physical stress. Rest or very light activity recommended." | "You've been pushing hard. Time to rest." |

---

## Streak Flame Tiers

| Streak | Tier | Flame Style | Card Border |
|--------|------|------------|-------------|
| 0 | Dormant | Gray silhouette (#404040), 35% opacity, small scale | Default (#404040) |
| 1–3 | Building | Small, #1e40af → #3b82f6 → #93c5fd gradient, subtle glow | Default (#404040) |
| 4–7 | Committed | Medium, #1e3a8a → #3b82f6 → #bfdbfe gradient, stronger glow | Blue (#3b82f6) |
| 8+ | Elite | Large, #1e3a8a → #60a5fa → #eff6ff gradient, white-hot core, strongest glow | Light Blue (#60a5fa) |

### Streak Motivational Messages

| Streak | Message |
|--------|---------|
| 0 | "Hit your weekly target to start a streak" |
| 1 | "One week down. Keep the flame alive" |
| 2 | "Two weeks strong. Building momentum" |
| 3 | "Three weeks in. Consistency is power" |
| 4 | "A full month of hitting your target" |
| 5 | "Five weeks. You're relentless" |
| 6 | "Six weeks. This is who you are now" |
| 7 | "Seven weeks. The flame burns bright" |
| 8 | "Eight weeks. Entering beast mode" |
| 9 | "Nine weeks. Nothing stops you" |
| 10 | "Ten weeks. Double digits. Legendary" |
| 11 | "Eleven weeks. Almost three months strong" |
| 12+ | "Unstoppable" |

---

## Power Level Statuses

| Status | Directional Indicator | Color | Contextual Message |
|--------|----------------------|-------|-------------------|
| Deloading | ↓ | Red (#ef4444) | "Your volume has decreased over the last 30 days." |
| Steady | — | Blue (#3b82f6) | "Your volume has been consistent over the last 30 days." |
| Rising | ↑ | Green (#10b981) | "Your volume has been increasing over the last 30 days." |
| No data | — | — | "Log Strength Training or HIIT workouts to track your power level." |

Thresholds: < −10% = Deloading, −10% to +10% = Steady, > +10% = Rising.

---

## Chart Data Thresholds (Trends Screen)

| Chart | Minimum Data | Empty Message |
|-------|-------------|--------------|
| Strength Tracker | 2 workouts with selected exercise + recorded weight | "Log more workouts to display strength trends" |
| Training Frequency | 1 full Mon–Sun week with ≥ 1 workout | "Complete your first full week to see frequency trends" |
| Personal Records | 1 exercise with ≥ 1 PR event | "Log more workouts to display personal records" |
| Training Load Trend | 3 days with ≥ 1 workout in last 14 days | "Log more workouts to display load trends" |
| Workout Volume | 2 Strength Training or HIIT workouts with ≥ 1 ExerciseSet | "Log more Strength or HIIT workouts to display volume trends" |
| Effort Trend | 1 full Mon–Sun week with ≥ 1 workout with recorded RPE | "Log workouts with RPE ratings to display effort trends" |
| Workout Type Breakdown | 2 workouts of any type | "Log more workouts to display your training breakdown" |
| Session Duration | 1 full Mon–Sun week with ≥ 1 workout with recorded duration | "Log workouts with duration to display session length trends" |

---

## Share Image Card Styling

Visual tokens for the styled PNG image produced by `WorkoutShareService` (see `SCREENS.md` § Workout Detail → Share Image Card and `SERVICES.md` § WorkoutShareService).

| Element | Value |
|---------|-------|
| Background | `#0a0a0a` (app background) |
| Card border | 1px `#404040`, 12px corner radius |
| Inner padding | 20px |
| Header | "✦ FitNavi" in `#3b82f6`, 11px, 700 weight, uppercase, 2px spacing |
| Workout name | `#e5e5e5`, 20px, 900 weight |
| Date/time | `#737373`, 13px, 600 weight |
| Workout type | `#a3a3a3`, 13px, 600 weight |
| Summary pills | `#2d2d2d` background, `#404040` border, 8px corner radius. Label: `#737373` 11px uppercase 700w. Value: `#e5e5e5` 15px 700w |
| Summary pill icons | SF Symbols per § Workout Detail Summary Icons, rendered at same size and color as the pill label text, with standard spacing between icon and label |
| Exercise name | `#e5e5e5`, 15px, 700 weight |
| Set detail | `#a3a3a3`, 13px, 600 weight. Format: `{sets} × {reps} @ {weight} {unit}` or `{sets} × {reps} (BW)` |
| Distance | Same style as set detail |
| Section dividers | `#404040` thin line with muted header text |
| Footer | "✦ FitNavi" in `#3b82f6`, 11px, 700 weight, uppercase, 2px spacing, centered |
| Image width | 390pt |
| Image scale | @3x for share-quality resolution |

---

## Template Sharing

### URL Scheme

```swift
"fitnavi"  // Registered in Info.plist as a custom URL type
```

### Deep Link Format

```
fitnavi://template?v=1&data=<base64url-encoded-JSON>
```

### Payload Version

```swift
1  // Current version. Increment when payload format changes.
```

### QR Code Limits

| Constraint | Value | Notes |
|------------|-------|-------|
| Max encoded URL size | 2,331 bytes | QR version 40, error correction M (binary mode) |
| Error correction level | M | 15% recovery — balance of density and damage tolerance |
| Display size | ~250pt | Comfortable scanning from phone screen |

### Error Messages

| Scenario | Message |
|----------|---------|
| QR data unreadable | "This QR code couldn't be read. It may be damaged or from an incompatible version of FitNavi." |
| Template too large for QR | "Template is too large to share via QR code." |

---

## Scheduled Workout Statuses

```swift
["planned", "completed", "skipped"]
```

---

## Recurrence Rules

```swift
["weekly", "biweekly"]
```

### Recurrence Constants

| Constant | Value | Notes |
|----------|-------|-------|
| Recurrence lookahead | 12 weeks | Number of future instances generated on creation |
| Regeneration threshold | 4 instances | When fewer than 4 future instances remain, auto-generate to restore 12-week lookahead |

## Toast Style

All in-app toast notifications use a unified capsule style.

| Property | Value | Notes |
|----------|-------|-------|
| Shape | `Capsule` | Fully rounded pill |
| Background | `FortiFitColors.primaryAccent` | Blue fill — same for all toasts including errors |
| Text color | `.white` | All toast label text |
| Text font | `FortiFitTypography.bodySmall` | 13pt system |
| Action link color | `.white` | E.g. "Undo" on removal toast |
| Action link weight | `.semibold` | Distinguishes tappable link from label |
| Horizontal padding | `FortiFitSpacing.cardPadding` | Inner content padding |
| Vertical padding | `FortiFitSpacing.elementSpacing` | Inner content padding |
| Position | Top of screen, `FortiFitSpacing.screenTop` inset | Aligned to top edge |
| Auto-dismiss | 2–4 seconds | 2s for informational, 4s for toasts with undo action |
| Animation | `.easeInOut(duration: 0.2)` | Entrance and exit |
