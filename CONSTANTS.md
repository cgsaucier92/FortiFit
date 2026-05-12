# CONSTANTS.md: FitNavi Constants & Reference Values

> All values to define in `AppConstants.swift` and `Design/Theme/`. Do not invent additional options or modify these lists without updating this document.
>
> **Two large reference sets live in companion files:**
> - **`HK_MAPPING.md`** — `HKWorkoutActivityType` → FortiFit `workoutType` lookup table (~80 entries) and ambiguous-mapping notes
> - **`INFO_COPY.md`** — Chart Info Modal Copy and Widget Info Modal Copy (the user-facing strings rendered in See Info modals)

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
| Chart (Orange) | `#FFBF51` | A potential color for chart lines or bars |
| Chart (Teal) |`#289193`| A potential color for chart lines or bars |
| Chart (Pink) | `#BB2BC0` | A potential color for chart lines or bars |
| Chart (Light Cyan) | `#8​FE6​F6` | A potential color for chart lines or bars |
| Chart (Deep Blue) | `#0845​AD` | A potential color for chart lines or bars |
| HealthKit Pink | `#FF2D55` | Source indicator heart icon and leading glyph on Workout Detail, info sheet accents. Matches Apple's system pink used in the Health app. See HEALTHKIT.md § 15. |
---

## Ellipsis Menu SF Symbols

Icons displayed to the left of each option in the top-nav ellipsis (`…`) menus. All are rendered at the standard ellipsis-menu text-row size, colored per the standard menu-row text color.

| Screen | Option | SF Symbol |
|--------|--------|-----------|
| Home | Add Widgets | `plus.rectangle.on.rectangle` |
| Workouts | Create Workout Template | `square.and.pencil` |
| Workouts | View Workout Templates | `doc.on.doc` |
| Log Workout (new mode) | Use workout template | `doc.badge.arrow.up` |
| Log Workout (new mode) | Save as workout template | `square.and.arrow.down` |
| Edit Workout (Strength / HIIT only) | Use Template | `doc.badge.arrow.up` |
| Create Workout Template (edit mode) | Share Template | `qrcode` |
| Workout Detail (Strength/HIIT only) | Save as workout template | `square.and.arrow.down` |
| Workout Detail (when `hiddenFromPlan == true`) | Show on Plan | `calendar.badge.plus` |
| Plan | Workout Templates | `doc.on.doc` |
| Trends | Add Charts | `chart.xyaxis.line` |
| Goals | Filter Goals | `line.3.horizontal.decrease.circle` |
| Goals | Expand All | `rectangle.expand.vertical` |
| Goals | Collapse All | `rectangle.compress.vertical` |

**Shared-symbol consistency:** "Save as workout template" uses the same symbol (`square.and.arrow.down`) wherever it appears (Log Workout ellipsis, Workout Detail ellipsis). "Workout Templates" navigation uses the same symbol (`doc.on.doc`) on both the Workouts and Plan ellipsis menus. "Use Template" / "Use workout template" uses the same symbol (`doc.badge.arrow.up`) on both Log Workout new-mode and Edit Workout (Strength / HIIT only) ellipsis menus — the Edit Workout label is shortened to "Use Template" since the ellipsis is screen-scoped to a single template-related action.

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

> **Moved to `HK_MAPPING.md`.** The full `HKWorkoutActivityType` → FortiFit `workoutType` lookup table (~80 entries), ambiguous-mapping judgment calls, and the "changing a mapping" workflow live there. Architectural rationale stays in HEALTHKIT.md § 6.

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
| `infoSheetPermanentSubline` | "Apple Health summary data will be deleted, and future Apple Health edits won't sync." |
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
| `unlinkConfirmTitle` | "Unlink workout from Apple Health?" |
| `unlinkConfirmMessage` | "This will delete all Apple Health–sourced summary data for this workout, and you won't be able to link it back. This can't be undone." |
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

## Activity Rings (Apple Health)

Constants for the `appleActivity` Home widget — see SCREENS.md § Home Screen → Activity Rings widget, SERVICES.md § AppleActivityService, and HEALTHKIT.md § 20.

### Ring Colors

| Ring | Color | Constant |
|---|---|---|
| Move (outermost) | `#ef4444` | `FortiFitColors.activityMoveRing` |
| Exercise (middle) | `#10b981` | `FortiFitColors.activityExerciseRing` |
| Stand (innermost) | `#0845AD` | `FortiFitColors.activityStandRing` |

When a ring closes (progress ≥ 100%), the ring continues drawing past 100% as a second arc on top of the filled ring — same Apple Watch behavior. Implementation: render two `Circle().trim(...).stroke(...)` layers per ring, where the second layer's `from` value increments past 1.0 visually rotates the over-fill.

### Ring Chevron SF Symbols

Icons rendered inline next to each label in the left column (10pt bold, ring color, 4pt spacing before label text).

| Ring | SF Symbol | Notes |
|---|---|---|
| Move | `chevron.right` | Single rightward chevron |
| Exercise | `chevron.right.2` | Double rightward chevrons |
| Stand | `chevron.up` | Single upward chevron |

Chevron color matches its ring color at full opacity. The ring center displays today's date (abbreviated month + day number) in Muted Text instead of chevron icons.

### Slider Ranges and Increments (Configure Settings Modal)

| Metric | Range | Increment | FitNavi Default (when HK has no value) |
|---|---|---|---|
| Move | 1–2000 cal | 10 cal | 500 cal |
| Exercise | 1–240 min | 5 min | 30 min |
| Stand | 1–24 hrs | 1 hr | 12 hrs |

### Widget Strings

Lives under `AppConstants.ActivityRings.*`.

#### Card States

| Constant | Value |
|---|---|
| `cardHeader` | "Activity Rings" |
| `moveLabel` | "Move" |
| `exerciseLabel` | "Exercise" |
| `standLabel` | "Stand" |
| `moveUnit` | "cal" |
| `exerciseUnit` | "min" |
| `standUnit` | "hours" |

Headline value format on the widget left column: `{numerator}/{denominator} {unit}` — e.g., `500/1000 cal`, `30/60 min`, `14/16 hours`. Both numerator and denominator render in the ring's accent color at 20pt heavy weight.

#### Three Dynamic Card States (see SCREENS.md § Home Screen → Activity Rings widget)

| Constant | Value |
|---|---|
| `stateConnectAppleHealthMessage` | "Connect Apple Health to track your activity rings." |
| `stateConnectAppleHealthCTA` | "Connect" |
| `statePairAppleWatchMessage` | "Pair an Apple Watch to see your Move, Exercise, and Stand activity here." |

#### Workout Contribution Caption

Renders below each fraction on the widget when the corresponding metric has at least one HK-linked workout contribution today.

| Constant | Value (template) |
|---|---|
| `captionFromSingleWorkout` | "+{value} from today's {workoutName}" |
| `captionFromMultipleWorkouts` | "+{value} from today's workouts" |

Threshold for "single" vs. "multiple": one HK-linked `Workout` logged today → single (use the workout's name); two or more → multiple (suppress names, sum values).

#### Weekly Closure Rate Chip

| Constant | Value (template) |
|---|---|
| `weeklyClosureChip` | "Closed all rings {n} day(s) this week" |

Renders below the rings (or as an overline above, depending on layout — see SCREENS.md). Computed from `AppleActivityService.closedAllRingsDayCount`.

### Settings Modal Strings

| Constant | Value |
|---|---|
| `settingsModalHeading` | "Configure Activity Rings" |
| `settingsModalMoveSliderLabel` | "Move (calories)" |
| `settingsModalExerciseSliderLabel` | "Exercise (minutes)" |
| `settingsModalStandSliderLabel` | "Stand (hours)" |
| `settingsModalResetButton` | "Reset to defaults" |
| `settingsModalImportButton` | "Import from Apple Health" |
| `settingsModalImportDisabledCaption` | "Connect Apple Health to import your goals." |

### Activity Detail Sheet Strings

| Constant | Value |
|---|---|
| `detailSheetHeading` | "Activity" |
| `detailSheetRangeToggle7d` | "7 days" |
| `detailSheetRangeToggle30d` | "30 days" |
| `detailSheetMoveSparklineLabel` | "Move" |
| `detailSheetExerciseSparklineLabel` | "Exercise" |
| `detailSheetStandSparklineLabel` | "Stand" |
| `detailSheetClosureHeatmapHeading` | "Ring closure heatmap" |

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
- **Core:** "Planks", "Side Planks", "Hollow Hold", "L-Sit", "Bear Hold", "Hanging Leg Raises", "Cable Crunches", "Ab Wheel Rollouts", "Russian Twists", "Woodchoppers"
- **Back (Hangs):** "Dead Hang"
- **Legs (Holds):** "Wall Sit", "Glute Bridge Hold"
- **Functional:** "Bear Crawl"
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
"KB Swings": "Kettlebell Swings",
"Plank": "Planks",
"Side Plank": "Side Planks",
"Hollow Body Hold": "Hollow Hold",
"L Sit": "L-Sit",
"Wall Sits": "Wall Sit",
"Dead Hangs": "Dead Hang",
"Glute Bridge": "Glute Bridge Hold"
```

All alias targets must exist in the Exercise Dictionary.

---

## Isometric Exercise Names (Phase 8.7)

Set of exercise names whose `reps` field is interpreted as **seconds** rather than rep count by default. Used by:
- Template editor / Log Workout / Edit Planned Workout: drives initial REPS/TIME segmented control state and column-header label (SCREENS.md § Log Workout → Exercise Card Additions).
- `WatchScheduleService` plan composition: drives `IntervalStep` goal type (`.time(reps, .seconds)` vs `.open`) and step display name format (WORKOUTKIT.md § 6).
- Resolved at lookup time via `ExerciseSuggestionService.isIsometric(_:)` (SERVICES.md § ExerciseSuggestionService → isIsometric Lookup).

Stored as a `Set<String>`. Lookup is case-insensitive after alias resolution (the alias map normalizes "Plank" → "Planks" before this set is queried).

```swift
let isometricExerciseNames: Set<String> = [
    "Planks",
    "Side Planks",
    "Hollow Hold",
    "L-Sit",
    "Bear Hold",
    "Dead Hang",
    "Wall Sit",
    "Glute Bridge Hold"
]
```

The user can override on a per-exercise-card basis via the REPS/TIME segmented control (writes to `TemplateExerciseSet.displayAsTime` / `ExerciseSet.displayAsTime`). Resolution: `displayAsTime ?? isometricExerciseNames.contains(resolvedName)`.

---

## Ambiguous Exercise Default Modes (Phase 8.7)

For exercises in the dictionary that are commonly performed both as reps **and** for time (e.g., Burpees, Battle Ropes), this map provides a default display mode. Resolved by `ExerciseSuggestionService.isIsometric(_:)` after the isometric set check.

```swift
let ambiguousExerciseDefaultModes: [String: Bool] = [
    // true = default to TIME, false = default to REPS
    "Burpees":         false,
    "Box Jumps":       false,
    "Battle Ropes":    true,
    "Farmers Walks":   true,
    "Sled Push":       true,
    "Sled Pull":       true,
    "Rowing Machine":  true,
    "Assault Bike":    true
]
```

Defaults reflect the most common form of each exercise. Users who want the alternate form override per-card via the REPS/TIME toggle.

Exercises NOT in the isometric set AND NOT in the ambiguous map default to REPS (safe default for unknown / custom exercises).

---

## Watch Sync Glyph (Phase 8.7)

Used by the `FortiFitWatchSyncGlyph` component (SCREENS.md § Standard Patterns → Watch Sync Card Glyph) on Plan cards and the Edit Planned Workout screen.

| Constant | Value | Notes |
|---|---|---|
| `glyphActiveSymbol` | `applewatch.watchface` | SF Symbol when sync is on AND plan is registered with Watch |
| `glyphInactiveSymbol` | `applewatch.slash` | SF Symbol when sync is off (or disabled) |
| `glyphActiveColor` | `#22c55e` | "Watch Sync Green" — distinct from the existing positive-feedback green; matches Apple Watch's accent green |
| `glyphInactiveColor` | `FortiFitColors.mutedText` | Standard muted text color |
| `glyphActiveOpacity` | `1.0` | Full opacity when active or inactive-but-tappable |
| `glyphDisabledOpacity` | `0.4` | Reduced opacity when gates fail (master off, auth denied, scheduledTime missing, ≥1 exercise gate fails) |
| `glyphSize` | `24pt` | Glyph render size |
| `glyphTapTarget` | `44×44pt` | Hit area (Apple HIG) |

Tap behavior driven by effective state — see SCREENS.md § Standard Patterns → Watch Sync Card Glyph.

---

## Apple Watch Strings (Phase 8.7)

Lives under `AppConstants.AppleWatch.*`. Strings must be read from `AppConstants` — do not hardcode in views. Cross-referenced from SCREENS.md § Settings → Apple Health & Devices, SCREENS.md § Edit Planned Workout, SCREENS.md § Standard Patterns → Master Sync Off Popover, and INFO_COPY.md § Inline Popover Copy.

### Settings Section

User-facing copy uses "Push" everywhere per the Phase 8.7.1 rename. Internal Swift identifiers (`syncToAppleWatch`, `syncPlanToAppleWatchEnabled`) are unchanged for code-level continuity.

| Constant | Value |
|---|---|
| `settingsSectionHeader` | *(removed — Apple Watch card now lives under the "Apple Health & Devices" heading with no separate header)* |
| `settingsToggleLabel` | "Push planned workouts to Apple Watch" |
| `settingsDescription` | "Push planned workouts from your Plan tab to your Apple Watch. Pushed workouts appear in the Workout app's Scheduled section and complete automatically when finished. Requires watchOS 11 or later." |
| `settingsStatusConnected` | *(removed — no status line shown on Apple Watch card)* |
| `settingsStatusDenied` | "PERMISSION DENIED IN IOS SETTINGS" |
| `settingsOpenIOSSettingsButton` | "Open iOS Settings" |
| `settingsTurnOffConfirmTitle` | "Turn off Push to Apple Watch?" |
| `settingsTurnOffConfirmMessage` | "All scheduled workouts currently pushed to your Apple Watch will be removed. You can turn it back on anytime — your push preferences will be remembered." |
| `settingsTurnOffConfirmDestructive` | "Turn Off" |
| `settingsTurnOffConfirmCancel` | "Cancel" |

### Plan Workout Sheet (Phase 8.7.1)

Strings for the new Push to Apple Watch toggle on the Plan Workout sheet (SCREENS.md § Plan → Push to Apple Watch Toggle).

| Constant | Value |
|---|---|
| `scheduleWorkout_toggleLabel` | "Push to Apple Watch" |
| `scheduleWorkout_masterOffCaption` | "Push to Apple Watch is off in Settings" |
| `scheduleWorkout_authDeniedCaption` | "Apple Health permission required — open iOS Settings" |
| `scheduleWorkout_validationFailedToast` | "Couldn't push to Apple Watch — check Settings." |

### Edit Planned Workout Toggle (Phase 8.7.1)

| Constant | Value |
|---|---|
| `editScheduledWorkout_toggleLabel` | "Push to Apple Watch" |

### Master Sync Off Popover

| Constant | Value |
|---|---|
| `masterOffPopoverTitle` | "Push to Apple Watch is off" |
| `masterOffPopoverBody` | "Turn it on in Settings to push this workout to your Apple Watch." |
| `masterOffPopoverButton` | "Open Settings" |

In-app navigation (NavigationPath push), not iOS Settings. (Component / API names retain "Sync" / "MasterSyncOff" for code-level continuity; user-visible strings use "Push.")

### Field-Specific Gate Popovers

When the card glyph is disabled because a specific field is missing:

| Failure mode | Popover copy |
|---|---|
| Zero exercises in snapshot | "Add at least one exercise to push to Apple Watch." |
| Auth denied | (uses Master Sync Off Popover variant with body: "Permission denied. Open iOS Settings to grant access." and button: "Open iOS Settings" → `UIApplication.openSettingsURLString`.) |
| `scheduledDate < today` | (no popover — past-dated cards are read-only by design.) |

Constant: `AppConstants.AppleWatch.gatePopoverCopy(for: SyncGate) -> String`.

### Error Toast

| Constant | Value |
|---|---|
| `errorToastMessage` | "Couldn't push to Apple Watch. Try again later." |
| `errorToastRetryButton` | "Retry" |

Uses the existing capsule style — see § Toast Style. Auto-dismisses after 4 seconds (with-action standard).

### Rest / Time Picker Range

| Constant | Value | Notes |
|---|---|---|
| `durationPickerMinSeconds` | `5` | Minimum value for both REST PER SET and the TIME column |
| `durationPickerMaxSeconds` | `600` | Maximum value (10 minutes) |
| `durationPickerIncrementSeconds` | `5` | Increment between picker values |
| `durationDisplayFormatSubMinute` | `"\(seconds)s"` | E.g., `"30s"` |
| `durationDisplayFormatOverMinute` | `"\(minutes):\(secondsRemainder, .padded2)"` | E.g., `"1:30"` |

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

Maps the integer 1–10 effort score to a descriptive label. Used on the Workout Detail stat-card grid (label-only display, no number), the Metric Detail Sheet hero block (label + integer in parens), the Log Workout dropdown (`Label (Number)` format per option), the Share Image Card stat-card grid (label-only), and the Match Prompt Sheet FitNavi-side card metadata (`Effort: Label (Number)`).

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
["trainingLoad", "weekStreak", "powerLevel", "todaysPlan", "appleActivity"]
```

| Identifier | Display Name | Description |
|------------|-------------|-------------|
| `trainingLoad` | Training Load | Shows your accumulated training stress score and recovery readiness based on recent workout intensity, volume, and frequency. |
| `weekStreak` | Week Streak | Tracks how many consecutive weeks you've met your weekly workout target. |
| `powerLevel` | Power Level | Measures your average strength volume trend over the last 30 days across Strength Training and HIIT workouts. |
| `todaysPlan` | Today's Plan | Shows your scheduled workout for today so you can jump straight into logging. Long-press → "Complete Workout" opens the same compact confirmation sheet as the Plan tab. |
| `appleActivity` | Activity Rings | Tracks your daily Move, Exercise, and Stand rings. Requires an Apple Watch and Apple Health connected in Settings. |

> **Removed widgets:** `workoutInfo` (Workout Info) was retired in this revision. It duplicated the Recent Workouts list directly below the widget stack and offered no decision-relevant signal beyond a vanity Total Workouts count. See SERVICES.md § HomeWidgetService → One-time migration for the cleanup of existing `workoutInfo` records on the upgrade build.

### Default Home Widgets (first launch)
```swift
["todaysPlan", "trainingLoad", "powerLevel"]
```
Week Streak and Activity Rings are add-only — available via the Add Widgets menu but not seeded on first launch.

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

## Trends Chart Visual Tokens

Visual styling values for the Trends screen's chart cards. Consumed by `FortiFitChartCard` (see SCREENS.md § Standard Patterns → Trends Chart Card Visual Treatment) and the individual chart views in `Features/Progress/`. All hex values reference tokens already defined in § Colors and § Workout Type Chart Colors — no new color tokens.

### Gradient Anchor by Chart Type

Each Trends chart card paints a subtle background gradient behind its plot area, color-matched to the chart's data marks. Single-color anchors render a vertical fade; the Personal Records anchor uses a horizontal split mirroring its two-bar layout, layered with the same vertical fade-to-transparent.

| Chart (id) | Anchor Color(s) | Treatment |
|---|---|---|
| `strengthTracker` | `#BB2BC0` (Chart Pink) | Single-color, vertical fade |
| `trainingFrequency` | `#10b981` (Positive Green) | Single-color, vertical fade |
| `personalRecords` | `#8FE6F6` leading → `#0845AD` trailing | Horizontal split + vertical fade-to-transparent |
| `trainingLoadTrend` | `#3b82f6` (Primary Accent Blue) | Single-color, vertical fade |
| `workoutVolume` | `#4B2893` (Chart Purple) | Single-color, vertical fade |
| `rpeTrend` | `#FFBF51` (Chart Orange) | Single-color, vertical fade |
| `workoutTypeBreakdown` | `#3b82f6` (Primary Accent Blue) | Single-color, vertical fade |
| `sessionDuration` | `#289193` (Chart Teal) | Single-color, vertical fade |

**Helper function** in `AppConstants` — `static func chartGradientAnchor(for: ChartType) -> ChartGradientAnchor` returns either `.single(Color)` or `.horizontalSplit(leading: Color, trailing: Color)`. Views must never hardcode the mapping; pull from `AppConstants` everywhere.

### Gradient Treatment

| Property | Value |
|---|---|
| Type | `LinearGradient` |
| Vertical fade | Anchor color at 20% opacity (top) → 0% (bottom) |
| Horizontal split (Personal Records only) | Leading color (left) → trailing color (right) at full anchor saturation, composed beneath the vertical fade-to-transparent |
| Layer order (back → front) | Card surface → gradient → inner hairline → plot marks |
| Inset | Gradient fills the plot area only (inside the inner hairline) — never the chart title, header summary, controls row, or footer |

### Inner Plot Hairline

| Property | Value |
|---|---|
| Stroke | 1px Border `#404040` |
| Corner radius | 8pt |
| Inset | Bounds the plot area; does not enclose the chart title, header summary, toggles, or footer/legend |
| Empty state | Hairline hidden (along with gradient and header summary) |

### Header Summary Block

Hero value + caption rendered above the plot area on every chart card when its data threshold (§ Chart Data Thresholds) is met. Hidden on empty states.

| Property | Value |
|---|---|
| Hero value typography | 28px, 900 weight |
| Hero value color | Anchor color (single-color charts); Primary Text `#e5e5e5` for `personalRecords` (which uses a two-color anchor) |
| Caption typography | 12px, 700 weight, Muted Text `#737373`, uppercase, 2px letter-spacing |
| Spacing | 4pt between hero and caption; 12pt below caption before plot area |

#### Per-Chart Hero / Caption Formula

| Chart (id) | Hero Value | Caption |
|---|---|---|
| `strengthTracker` | `{latest weight} {unit}` (e.g., `225 lbs`) | `LATEST` |
| `trainingFrequency` | `{avg sessions/week, 1 dp}` | `AVG / LAST 8 WEEKS` |
| `personalRecords` | `+{delta} {unit}` (current − previous) | `LATEST PR` |
| `trainingLoadTrend` | `{today's score, integer}` | `TODAY` |
| `workoutVolume` | `{avg session volume, formatted with K/M suffix}` | `AVG / SESSION` |
| `rpeTrend` | `{avg rpe, 1 dp}` | `AVG / LAST 8 WEEKS` |
| `workoutTypeBreakdown` | *(rendered inside donut center — see § Donut Center Label below; header summary slot suppressed)* | — |
| `sessionDuration` | `{avg duration} min` | `AVG / SESSION` |

**Helper function** in `TrendsChartService` — `func headerSummary(for: ChartType, exerciseName: String?) -> ChartSummary?` returns `nil` when below the chart's data threshold; the view renders the empty state instead. `exerciseName` is required only for `strengthTracker` and `personalRecords`. `ChartSummary` is a value type with `hero: String` and `caption: String`. Strings live in `AppConstants` — captions never hardcoded in views.

### Latest Data-Point Highlight

Applies to line charts only (`strengthTracker`, `workoutVolume`, and the rolling-average line on `trainingLoadTrend`). Mirrors the existing Metric Detail Sheet sparkline convention (§ Stat Card Colors → "current workout's data point" treatment).

| Property | Value |
|---|---|
| Shape | Filled circle |
| Diameter | 6pt |
| Fill | Anchor color |
| Glow | 4pt outer blur at 60% anchor opacity |
| Position | Last data point on the line (most recent x value) |

Non-latest points retain their existing 3pt circle treatment (or no point marker, where the chart had none before).

### Bar Top Corner Radius

Applies to all `BarMark` charts (`trainingFrequency`, `personalRecords`, `rpeTrend`, `sessionDuration`).

| Property | Value |
|---|---|
| Top corners | 5pt radius |
| Bottom corners | 0pt — bars sit flush on the x-axis baseline |
| Implementation | `UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5)` |

### Line Interpolation

All `LineMark`s on Trends charts use `.interpolationMethod(.catmullRom)`. Softens jagged data without distorting trend direction. No exception charts.

### Donut Center Label (Workout Type Breakdown only)

Renders inside the donut hole when the chart's data threshold is met. Replaces the chart's header summary block on this card.

| Property | Value |
|---|---|
| Hero value | Total workout count across the active range (30D / 60D / 90D / All Time), Primary Text `#e5e5e5`, 24px, 900 weight |
| Caption | `WORKOUTS`, Muted Text `#737373`, 11px, 700 weight, 2px letter-spacing |
| Layout | Centered horizontally and vertically inside the donut hole; both lines stack with 2pt vertical spacing |
| Empty state | Center label hidden alongside the chart's other empty-state behavior |

---

## Trends Chart Detail View

Visual + behavioral tokens for the per-chart expanded view (Phase 6.2). See SCREENS.md § Trends Chart Detail and § Standard Patterns → Back Navigation Chevron. The detail view inherits every visual token from § Trends Chart Visual Tokens — this section only adds what's specific to the larger surface.

### Expand Button (on compact chart card)

| Property | Value |
|---|---|
| SF Symbol | `chevron.right` |
| Color | Muted Text `#737373` (matches Workout Detail stat-card chevrons) |
| Size | 14pt |
| Tap target | 44×44pt hit area, top-trailing of the card |
| Identifier | `trendsChart_{chartId}_expandButton` |
| VoiceOver label | `"Expand {chart title}, button"` |

### Range Toggle by Chart Type

Each chart's detail view exposes a wider set of time ranges than the compact card. Toggles render as a `FortiFitSegmentedToggle` row below the header summary. The eligible set is bounded by what the chart's underlying data supports — the table is per-chart canonical.

| Chart (id) | Eligible Ranges | Default |
|---|---|---|
| `strengthTracker` | 30D · 90D · 6M · 1Y · All | 90D |
| `trainingFrequency` | 8W · 6M · 1Y · All | 8W |
| `personalRecords` | All (timeline is event-driven, not range-based) | All |
| `trainingLoadTrend` | 14D · 30D · 90D · 6M | 30D |
| `workoutVolume` | 30D · 90D · 6M · 1Y · All | 90D |
| `rpeTrend` | 8W · 6M · 1Y · All | 8W |
| `workoutTypeBreakdown` | 30D · 60D · 90D · 1Y · All | 90D |
| `sessionDuration` | 8W · 6M · 1Y · All | 8W |

`TimeRange` raw values (used for accessibility identifiers via `trendsChartDetail_{chartId}_rangeToggle_{rawValue}`): `14d`, `30d`, `60d`, `90d`, `8w`, `6m`, `1y`, `all`.

### Header Summary (Detail Variant)

Extends § Trends Chart Visual Tokens → Header Summary Block with a comparison-delta band. Suppressed on `workoutTypeBreakdown` (its hero stays in the donut center).

| Property | Value |
|---|---|
| Hero value typography | 32px, 900 weight, anchor color (Primary Text `#e5e5e5` for `personalRecords`) |
| Caption typography | 12px, 700 weight, Muted Text `#737373`, uppercase, 2px letter-spacing |
| Delta band typography | 13px, 700 weight; color is Positive Green `#10b981` (up), Alert Red `#ef4444` (down), Muted Text `#737373` (flat or no prior period) |
| Delta arrow icon | `arrow.up` (up), `arrow.down` (down), `minus` (flat) — 11pt, color matches delta band |
| Delta string format | `{arrow} {magnitude} vs. prior {range}` — e.g., `↑ +15 lbs vs. prior 90D`, `↓ −0.4 vs. prior 8W`, `— same as prior 30D` |
| No-prior-data fallback | Delta band hidden entirely; `direction == .flat` returns `nil` delta string |
| Spacing | 6pt between hero and caption; 4pt between caption and delta band; 16pt below delta band before range toggles |

**Helper function** in `TrendsChartService` — `func comparisonDelta(for: ChartType, exerciseName: String?, range: TimeRange) -> ChartDelta?`. Returns `nil` when below the chart's data threshold (CONSTANTS.md § Chart Data Thresholds).

### Selection State

Tap-to-select on bars + line dots; drag-to-scrub on line charts. Selection lives only on the detail view — the compact card stays read-only.

| Property | Value |
|---|---|
| Selected mark | Full opacity, retains anchor color |
| Non-selected marks | 35% opacity |
| Floating annotation | Primary Text `#e5e5e5`, 13px, 700 weight; rendered above the selected mark with 6pt vertical offset; auto-flips below when within 24pt of the chart's top edge |
| Annotation content (line 1) | Per-chart formatted value — e.g., `225 lbs`, `36 min`, `5.4 RPE` |
| Annotation content (line 2) | Date or week label — e.g., `Apr 23, 2026`, `Week of Apr 19` |
| Annotation content (line 3, optional) | Per-chart context where useful — e.g., on `strengthTracker`: exercise + top set (`Bench Press, 5 × 5`); on `trainingLoadTrend`: zone label (`Moderate`) |
| Haptic | `UIImpactFeedbackGenerator(.light)` on initial selection AND on each scrub-snapped data point change. Not on deselection. |
| Multi-select | Not supported — a new selection replaces the prior |
| Persistence | View-state only — never written to SwiftData, never crosses navigation |
| Deselection triggers | Range toggle change, swipe-paging to a different chart, back navigation |

**Selection availability per chart type:**

| Chart (id) | Tap | Scrub | Notes |
|---|---|---|---|
| `strengthTracker` | Yes | Yes | Line chart with discrete points |
| `trainingFrequency` | Yes | Yes (snaps to weekly bars) | Bar chart |
| `personalRecords` | Yes | No | Tap any timeline point; timeline is event-driven, not continuous |
| `trainingLoadTrend` | Yes (per-day dots) | Yes (rolling-avg line scrubs continuously) | Both layers selectable |
| `workoutVolume` | Yes | Yes | Line chart |
| `rpeTrend` | Yes | Yes (snaps to weekly bars) | Bar chart |
| `workoutTypeBreakdown` | No | No | Donut segments don't surface a useful per-segment timestamp; the legend table already discloses values |
| `sessionDuration` | Yes | Yes (snaps to weekly bars) | Bar chart |

### Scrubber Treatment

Applies only on charts with scrub support per the table above.

| Property | Value |
|---|---|
| Vertical line | `RuleMark`, 1px, anchor color at 60% opacity |
| Touch follow | Real-time follow during drag; lifts the line on drag-release but keeps the last-snapped data point selected |
| Snap behavior | On bar charts, snaps to the bar whose x-bucket contains the touch x. On line charts, snaps to the nearest data point's x within ±half-bucket-width. |
| Out-of-bounds drag | Touch outside plot area → no scrubber line; selection retains the last in-bounds value |

### Swipe Paging

| Property | Value |
|---|---|
| Gesture | Horizontal swipe (≥ 50pt threshold), implemented via `TabView(.page)` page style |
| Order | `TrendsChart.sortOrder` ascending; wraps at both ends |
| Persistence | Detail view's active chart resets to the user's tap origin every time they return to the Trends screen and re-enter |
| Disabled when | A chart is in a scrub-active state (drag in progress) — page gesture defers to the scrub gesture |

### Y-Axis Label Formatting

Compact card abbreviates large numbers (`5K`, `1.2M`). Detail view renders full numerics with grouping separators (`5,000`, `1,200,000`) since vertical space is no longer constrained. Unit suffix per chart unchanged.

### Empty State

Same suppression rules as the compact card (gradient + hairline + header summary + plot marks all hide; centered muted message renders). Range toggles, See Info, and back chevron remain available.

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

> **Moved to `INFO_COPY.md` § Chart Info Modal Copy.** All chart-type entries (Strength Tracker, Training Frequency, Personal Records, Training Load Trend, Workout Volume, Effort Trend, Workout Type Breakdown, Session Duration) live there. Stored in `AppConstants` as a static dictionary keyed by `chartType`.

---

## Widget Info Modal Copy

> **Moved to `INFO_COPY.md` § Widget Info Modal Copy.** Entries for Training Load, Power Level, and Activity Rings live there. Stored in `AppConstants` as a static dictionary keyed by `widgetType`.

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
