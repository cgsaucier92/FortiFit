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
| Chart (Orange) | `#FFA600` | A potential color for chart lines or bars |
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
| Log Workout (new mode) | Use workout template | `doc.badge.arrow.up` |
| Log Workout (new mode) | Save as workout template | `square.and.arrow.down` |
| Edit Workout (Strength / HIIT only) | Use Template | `doc.badge.arrow.up` |
| Create Template (edit mode) | Share Template | `qrcode` |
| Workout Detail (Strength/HIIT only) | Save as workout template | `square.and.arrow.down` |
| Workout Detail (when `hiddenFromPlan == true`) | Show on Plan | `calendar.badge.plus` |
| Plan | Saved Templates | `doc.on.doc` |
| Trends | Add Charts | `chart.xyaxis.line` |
| Goals | Filter Goals | `line.3.horizontal.decrease.circle` |
| Goals | Expand All | `rectangle.expand.vertical` |
| Goals | Collapse All | `rectangle.compress.vertical` |

**Shared-symbol consistency:** "Save as workout template" uses the same symbol (`square.and.arrow.down`) wherever it appears (Log Workout ellipsis, Workout Detail ellipsis). "Saved Templates" navigation uses the same symbol (`doc.on.doc`) on both the Workouts and Plan ellipsis menus. "Use Template" / "Use workout template" uses the same symbol (`doc.badge.arrow.up`) on both Log Workout new-mode and Edit Workout (Strength / HIIT only) ellipsis menus — the Edit Workout label is shortened to "Use Template" since the ellipsis is screen-scoped to a single template-related action.

**Goals Expand/Collapse toggle:** The symbol swaps alongside the label based on dominant card state — `rectangle.expand.vertical` when most cards are collapsed (label: "Expand All"), `rectangle.compress.vertical` when most are expanded (label: "Collapse All"). See SCREENS.md § Goals Ellipsis Menu.

---

## Widget Context Menu SF Symbols

Icons displayed to the left of each option in the long-press context menu on Home widget cards. See SCREENS.md § Home Screen → Widget Context Menu.

| Widget | Option | SF Symbol |
|--------|--------|-----------|
| Today's Plan | Complete Workout | `checkmark.circle` |
| Training Load | See Info | `info.circle` |
| Power Level | See Info | `info.circle` |
| Training Load | Configure Settings | `gear` |
| Weekly Streak | Configure Settings | `gear` |

"Complete Workout" is conditional — rendered only on the Today's Plan widget, and only when an uncompleted `ScheduledWorkout` exists for today (see SCREENS.md § Home Screen → Widget Context Menu). "See Info" is conditional — rendered only on Training Load and Power Level widgets. "Configure Settings" is conditional — rendered only on configurable widgets (Training Load, Weekly Streak). "Reorder Widgets" and "Delete Widget" use no leading SF Symbols.

---

## Trends Chart Context Menu SF Symbols

Icons displayed to the left of each option in the long-press context menu on Trends chart cards. See SCREENS.md § Trends → Chart Card Context Menu.

| Option | SF Symbol |
|--------|-----------|
| See Info | `info.circle` |

"See Info" applies to every chart type. "Reorder Charts" and "Delete Chart" use no leading SF Symbols.

---

## Workout Detail Summary Icons

Icons rendered on the Workout Detail Summary stat-card grid and the Share Image Card stat-card grid (see SCREENS.md § Workout Detail → Summary and § Share Image Card). Each icon's color is defined in § Stat Card Colors below.

| Field | SF Symbol | Visible On |
|-------|-----------|-----------|
| Effort | `chart.bar.fill` | All workout types (when rated) |
| Duration | `clock` | All workout types (when recorded) |
| Distance | `ruler` | Cardio only (when recorded) |

**Rendering:** Icon size matches the label text size on the stat card. The Effort icon uses SwiftUI's palette rendering mode to color its three bars independently — see § Stat Card Colors and § Effort Color Mapping. All other icons render in a single color per § Stat Card Colors.

---

## Workout Detail Health Data Icons

Icons rendered on the Workout Detail Summary stat-card grid and the Share Image Card stat-card grid for HK-imported metrics (visible only when the corresponding field on `workout` is non-nil). Each icon's color is defined in § Stat Card Colors below.

| Field | SF Symbol | Visible When |
|-------|-----------|--------------|
| Avg Heart Rate | `heart.fill` | `avgHeartRate != nil` |
| Max Heart Rate | `heart.circle.fill` | `maxHeartRate != nil` |
| Active Calories | `flame.fill` | `activeEnergyKcal != nil` |
| Total Calories | `flame.circle.fill` | `totalEnergyBurnedKcal != nil` |
| Elevation Ascended | `mountain.2.fill` | `elevationAscendedMeters != nil` |
| Exercise Minutes | `timer` | `exerciseMinutes != nil` |

**Card pairing:** HR and calorie metrics pair side-by-side as separate stat cards on one grid row when both members of the pair are non-nil — see SCREENS.md § Workout Detail → Summary for the field order rules.

**Indoor/Outdoor:** removed from Summary in Phase 8.5. Not rendered as a stat card.

---

## Stat Card Colors

Colors applied to icons and values on every stat card in the Workout Detail Summary grid, the Metric Detail Sheet hero block, and the Share Image Card stat-card grid. Labels on cards and detail sheets are always Primary Text `#e5e5e5`; chevrons stay Muted Text. The unit text inline with numeric values (`bpm`, `kcal`, `min`, etc.) stays muted regardless of value color.

| Metric | Icon Color | Value Color | Sparkline Color (Detail Sheet) |
|---|---|---|---|
| Effort | Multi-color palette: short bar `#10b981`, middle bar `#C4F648`, tall bar `#ef4444` | Dynamic — maps from `workout.rpe` per § Effort Color Mapping | Per-segment color — each segment endpoint maps via § Effort Color Mapping |
| Duration | `#4B2893` (purple) | `#4B2893` | `#4B2893` |
| Distance | `#289193` (teal) | `#289193` | `#289193` |
| Avg HR | `#ef4444` (red) | `#ef4444` | `#ef4444` |
| Max HR | `#ef4444` (red) | `#ef4444` | `#ef4444` |
| Active kcal | `#934F28` (orange) | `#934F28` | `#934F28` |
| Total kcal | `#934F28` (orange) | `#934F28` | `#934F28` |
| Elevation Ascended | `#934F28` (orange) | `#934F28` | `#934F28` |
| Exercise Minutes | `#4B2893` (purple) | `#4B2893` | `#4B2893` |

**Notes on the table above:**
- All hex values reference tokens already defined in § Colors (Positive Green, Caution Yellow, Alert Red, Chart Purple, Chart Orange, Chart Teal). No new tokens introduced.
- Elevation and Exercise Minutes are not in the user's explicit color spec but inherit sensible defaults — Elevation tracks the calorie family (orange) since it represents "work performed against gravity," and Exercise Minutes tracks the Duration family (purple) since it's a time-based metric. Adjust if a different mapping is preferred.
- The Effort icon requires SwiftUI's palette rendering: `Image(systemName: "chart.bar.fill").symbolRenderingMode(.palette).foregroundStyle(.green, .yellow, .red)` (using the actual hex tokens). Layer order in `chart.bar.fill` is short → medium → tall, so the foreground style tuple maps to that order naturally; verify visually on first build in case Apple changes the layer order in a future SF Symbols release.

**The current workout's data point on every detail sheet sparkline** is highlighted with Primary Accent Blue `#3b82f6` (filled circle, larger radius) — uniform across all metrics regardless of line color, so users can always locate the current session in the chart.

---

## Effort Color Mapping

Maps the integer 1–10 effort score to a color. Used on the Workout Detail stat card (Effort value), the Metric Detail Sheet hero (Effort value at hero size), the Effort sparkline on the detail sheet (per-segment color), and the Share Image Card (Effort value).

| Score | Band | Color |
|---|---|---|
| 1 | Easy | `#10b981` (Positive Green) |
| 2 | Easy | `#10b981` |
| 3 | Light | `#10b981` |
| 4 | Light | `#10b981` |
| 5 | Moderate | `#C4F648` (Caution Yellow) |
| 6 | Moderate | `#C4F648` |
| 7 | Hard | `#ef4444` (Alert Red) |
| 8 | Hard | `#ef4444` |
| 9 | All Out | `#ef4444` |
| 10 | All Out | `#ef4444` |

Three-color collapse of the 5-band Effort Label Mapping (§ Effort Label Mapping above): Easy + Light → green, Moderate → yellow, Hard + All Out → red.

**Helper function** in `AppConstants` (e.g., `static func effortColor(for: Int) → Color`) returns the band color for a given integer. Views should never hardcode the mapping; pull from `AppConstants` everywhere.

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

## HealthKit Strings

Lives under `AppConstants.HealthKit.*`. Strings must be read from `AppConstants` — do not hardcode in views. SF symbols here are referenced by the Source Indicator Info Sheet redesign and the Log Workout edit-mode info popovers (see SCREENS.md § Workout Detail → Source Indicator Info Sheet, § Log Workout — HealthKit-Linked Workouts).

### Source Indicator Info Sheet

| Constant | Value |
|---|---|
| `infoSheetTitle` | "Imported from Apple Health" |
| `infoSheetLead` | "This workout was imported from Apple Health." |
| `infoSheetReadOnlyHeadline` | "Date, Start Time, Effort, and Duration are read-only here." |
| `infoSheetReadOnlySubline` | "Edit in Apple Health, or unlink to edit in FitNavi." |
| `infoSheetPermanentHeadline` | "Unlinking is permanent." |
| `infoSheetPermanentSubline` | "Future Apple Health edits won't sync to this workout." |
| `infoSheetDoneButton` | "Done" |
| `infoSheetUnlinkLink` | "Unlink from Apple Health" |
| `infoSheetActivityTypeLabel` | "Activity Type" |
| `infoSheetSourceLabel` | "Source" |
| `infoSheetImportedLabel` | "Imported" |
| `infoSheetLastSyncedLabel` | "Last synced" |

### Source Indicator Info Sheet — SF Symbols

| Constant | SF Symbol | Usage |
|---|---|---|
| `infoSheetHeaderIcon` | `heart.fill` | Header brand mark, 32pt, HealthKit Pink |
| `infoSheetReadOnlyIcon` | `pencil.slash` | Row 1 callout leading icon, 16pt, Muted Text |
| `infoSheetPermanentIcon` | `arrow.uturn.backward.slash` | Row 2 callout leading icon, 16pt, Alert Red `#ef4444` |

### Unlink Confirmation Dialog

| Constant | Value |
|---|---|
| `unlinkConfirmTitle` | "Unlink this workout?" |
| `unlinkConfirmMessage` | "You won't be able to link it back to Apple Health, and changes you make to it in Apple Health won't appear here anymore." |
| `unlinkConfirmDestructive` | "Unlink" |
| `unlinkConfirmCancel` | "Cancel" |
| `unlinkSuccessToast` | "Unlinked from Apple Health." |

### Log Workout — HealthKit-Linked Field Popovers

Inline `info.circle` icon (14pt, Muted Text) sits next to each disabled HK-owned field. Tap → SwiftUI `.popover` with the field-specific copy below. Popover dismisses on tap-outside.

| Field | Popover Copy |
|---|---|
| Date | "Date is sourced from Apple Health and can't be edited here. Unlink the workout to edit it in FitNavi." |
| Start Time | "Start time is sourced from Apple Health and can't be edited here. Unlink the workout to edit it in FitNavi." |
| Duration | "Duration is sourced from Apple Health and can't be edited here. Unlink the workout to edit it in FitNavi." |
| Distance | "Distance is sourced from Apple Health and can't be edited here. Unlink the workout to edit it in FitNavi." |

Constant: `AppConstants.HealthKit.fieldPopoverCopy(for: HKOwnedField) -> String`. Single source of truth — UI references the function rather than the literal strings.

### Source Name Display

| Constant | Value | Notes |
|---|---|---|
| `appleWorkoutName` | "Apple Workout" | Display string for `com.apple.Health` (Apple Watch) source |
| `unknownSourceName` | "another app" | Fallback when bundle ID resolution fails. Used in Source row, info sheet body, etc. |

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

Integers 1 through 10. Stored on `workout.rpe`; display layer renders the descriptive label per § Effort Label Mapping below.

---

## Effort Label Mapping

Maps the integer 1–10 effort score to a descriptive label. Used on the Workout Detail stat-card grid (label-only display, no number), the Metric Detail Sheet hero block (label + integer in parens), the Log Workout dropdown (`Label (Number)` format per option), the Share Image Card stat-card grid (label-only), and the Match Prompt Sheet FortiFit-side card metadata (`Effort: Label (Number)`).

| Score | Label |
|---|---|
| 1 | Easy |
| 2 | Easy |
| 3 | Light |
| 4 | Light |
| 5 | Moderate |
| 6 | Moderate |
| 7 | Hard |
| 8 | Hard |
| 9 | All Out |
| 10 | All Out |

Five bands × two integers each. Mirrors Apple's `workoutEffortScore` band convention.

**Surfaces that stay numeric (do NOT use this mapping):**
- Effort Trend chart on Trends — y-axis is 1–10 for chart precision; weekly average can be a decimal that doesn't map cleanly to a label (e.g., 5.4). Reference line at 7 may be annotated `Hard threshold` if desired.
- Workouts tab Filter By → Effort range — power-user surface; integer min/max stepper retained for granular filtering.
- Training Load algorithm and all other algorithmic consumers — they read `workout.rpe` as an integer directly; the label is purely a display concern.

**Strings live in `AppConstants`** — never hardcode in views. Helper function (e.g., `AppConstants.effortLabel(for: Int) → String`) returns the label for a given integer.

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
["trainingLoad", "weekStreak", "powerLevel", "todaysPlan"]
```

| Identifier | Display Name | Description |
|------------|-------------|-------------|
| `trainingLoad` | Training Load | Shows your accumulated training stress score and recovery readiness based on recent workout intensity, volume, and frequency. |
| `weekStreak` | Week Streak | Tracks how many consecutive weeks you've met your weekly workout target. |
| `powerLevel` | Power Level | Measures your average strength volume trend over the last 30 days across Strength Training and HIIT workouts. |
| `todaysPlan` | Today's Plan | Shows your scheduled workout for today so you can jump straight into logging. Long-press → "Complete Workout" opens the same compact confirmation sheet as the Plan tab. |

> **Removed widgets:** `workoutInfo` (Workout Info) was retired in this revision. It duplicated the Recent Workouts list directly below the widget stack and offered no decision-relevant signal beyond a vanity Total Workouts count. See SERVICES.md § HomeWidgetService → One-time migration for the cleanup of existing `workoutInfo` records on the upgrade build.

### Default Home Widgets (first launch)
```swift
["trainingLoad", "weekStreak"]
```
Power Level and Today's Plan not included by default — both available via Add Widgets menu.

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

## Chart Info Modal Copy

User-facing strings rendered in the Chart Info Modal (see SCREENS.md § Trends → Chart Info Modal). One entry per chart type. Each entry has a title, an intro paragraph, and an ordered list of named sections (each section a heading + body paragraph). Stored in `AppConstants` as a static dictionary keyed by `chartType` — never hardcoded in views. Sections render in the order listed below.

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

**Apple Health import:** If you record a workout on Apple Watch and rate its effort there (iOS 18 or later), that effort score imports into FortiFit automatically when the workout is linked — but only if you haven't already entered an effort rating yourself. Your manually entered ratings always win.

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

**The target line:** The dashed line is your target workout duration, set via long-press → Configure Settings on the Training Load widget. It's the same value FortiFit uses as a fallback in your training load score when a workout has no duration entered.

**Time range:** The 8 most recent calendar weeks, including the current in-progress week.

**Apple Health import:** Durations from Apple Watch and other Health-connected apps are imported automatically when you link a workout, so you don't need to re-enter them.

**Empty state:** At least one full Monday–Sunday week with at least one workout that has a recorded duration is needed before the chart renders.

---

## Widget Info Modal Copy

User-facing strings rendered in the See Info Modal (see SCREENS.md § Standard Patterns → See Info Modal) when invoked from a Home widget's long-press → "See Info". Mirrors the structure of § Chart Info Modal Copy. One entry per configurable widget (Training Load, Power Level). Stored in `AppConstants` as a static dictionary keyed by `widgetType`. Sections render in the order listed below.

### Training Load (`trainingLoad`)

**Title:** About Training Load

**Intro:** Training Load is a 0–100 score that summarizes how much training stress you've accumulated over the past 10 days. The zone label and advisory beneath it suggest whether to push, ease off, or rest today.

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

**Empty state:** If you haven't logged a workout in the last 10 days, the score sits at 0 (Resting) and the advisory shows "No recent training stress."

### Power Level (`powerLevel`)

**Title:** About Power Level

**Intro:** Power Level shows whether your strength training volume is rising, holding steady, or trending down compared to where you were a month ago. It answers "am I progressing?" at a glance.

**How it's calculated:** FortiFit averages your workout volume across the last 30 days and compares it to your average across the prior 30 days. Volume per workout is sets × reps × weight, summed across every exercise in the session.

**What workouts count:** Only Strength Training and HIIT workouts. Cardio, yoga, pilates, and other types don't track exercise sets, so they don't contribute to a volume comparison.

**Bodyweight exercises:** Sets logged without a weight value count as if the weight were 1, since they still represent work performed. This keeps bodyweight volume from disappearing entirely from the comparison.

**Status thresholds:**
- Rising (↑, green): current 30-day average is more than 10% higher than the prior 30 days
- Steady (—, blue): within 10% in either direction — your volume is holding consistent
- Deloading (↓, red): current 30-day average is more than 10% lower than the prior 30 days

**Empty state:** If you don't have any Strength Training or HIIT workouts logged, the widget shows a prompt to start logging. If you have current workouts but no prior 30-day baseline yet (less than 31 days of history), the status defaults to Steady until you build enough data.

---

## Share Image Card Styling

Visual tokens for the styled PNG image produced by `WorkoutShareService` (see `SCREENS.md` § Workout Detail → Share Image Card and `SERVICES.md` § WorkoutShareService).

| Element | Value |
|---------|-------|
| Background | `#0a0a0a` (app background) |
| Outer card border | 1px `#404040`, 12px corner radius |
| Inner padding | 20px |
| Header | "✦ FitNavi" in `#3b82f6`, 11px, 700 weight, uppercase, 2px spacing |
| Workout name | `#e5e5e5`, 20px, 900 weight |
| Date/time | `#737373`, 13px, 600 weight |
| Workout type | `#a3a3a3`, 13px, 600 weight |
| Stat card grid | 2-column grid of bordered stat cards mirroring the Workout Detail Summary grid (see SCREENS.md § Workout Detail → Summary). Cards render only when their underlying value is non-nil; grid wraps left-to-right, top-to-bottom. No tap behavior (static image). |
| Stat card container | `#1a1a1a` background, `#404040` 1px border, 12px corner radius, 14px horizontal × 12px vertical internal padding |
| Stat card label row | SF symbol + sentence-case label, both Muted Text `#737373`, 12px, 700 weight. No chevron in the share-image variant — there's no tap target. |
| Stat card value | Primary Text `#e5e5e5`, 22px, 800 weight, sentence case for label-style values (Effort), numeric for everything else with inline muted unit (`#a3a3a3`, 12px, 600 weight) |
| Stat card icons | SF Symbols per § Workout Detail Summary Icons (Effort uses `chart.bar.fill`) and § Workout Detail Health Data Icons. Rendered at same size and color as the label text. |
| Effort label rendering | Descriptive label only (e.g., `Hard`) per § Effort Label Mapping — no number shown on the share image |
| Exercise name | `#e5e5e5`, 15px, 700 weight |
| Set detail | `#a3a3a3`, 13px, 600 weight. Format: `{sets} × {reps} @ {weight} {unit}` or `{sets} × {reps} (BW)` |
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
