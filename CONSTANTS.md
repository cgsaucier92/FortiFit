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
| Sleep Awake | `#FF6B5B` | Awake segment of the sleep stages bar on the Recovery Status Detail Sheet and the Linked Recovery & Load Detail Sheet (Phase 11). Verify against the Apple Health app's sleep stages chart before committing the hex. Other stage colors are reused: Deep → Chart Purple (`#4B2893`), REM → Primary Accent Blue (`#3b82f6`), Core → Light Blue token from `Secondary` palette (`#93c5fd` — define inline if not already in the token set). |
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

| Field | Icon | Visible On |
|-------|-----------|-----------|
| Effort (Workout Detail Summary, Metric Detail Sheet hero, Share Image Card) | Custom `FortiFitEffortBars` 5-bar glyph — see § Effort Bars Glyph | All workout types (when rated) |
| Effort (Log Workout dropdown) | `chart.bar.fill` SF Symbol | All workout types (when rated) |
| Duration | `clock` SF Symbol | All workout types (when recorded) |
| Distance | `ruler` SF Symbol | Cardio only (when recorded) |

**Rendering:** Icon size matches the label text size on the stat card. SF Symbol icons render in a single color per § Stat Card Colors. The Effort bars glyph derives lit-bar count from the rpe tier and lit-bar color from § Effort Color Mapping — see § Effort Bars Glyph for full specification.

---

## Effort Bars Glyph

Custom 5-bar ascending-bars indicator used in place of an SF Symbol for the Effort icon on the Workout Detail Summary stat card, the Metric Detail Sheet Effort hero, and the Share Image Card stat-card grid. Inspired by Apple Fitness's Effort row glyph. The Log Workout dropdown continues to use the `chart.bar.fill` SF Symbol (text-list context, not a stat card).

**Component:** `FortiFitEffortBars(rpe: Int, size: CGFloat = 16)` in `Design/Components/`. Default `size: 16` matches the in-app stat-card label text; the Share Image Card invokes the glyph with `size: 12` to match its smaller 12pt label text.

**Tier-to-lit-bar mapping** (1:1 with § Effort Label Mapping):

| RPE | Label | Lit Bars |
|-----|-------|----------|
| 1, 2 | Easy | 1 |
| 3, 4 | Light | 2 |
| 5, 6 | Moderate | 3 |
| 7, 8 | Hard | 4 |
| 9, 10 | All Out | 5 |

**Bar geometry:**

- 5 vertical capsule bars, bottom-aligned, ascending height left-to-right
- Height fractions of `size`: 0.40 / 0.55 / 0.70 / 0.85 / 1.00
- Bar width: `max(2, size × 0.18)`
- Horizontal spacing: `max(1.5, size × 0.10)`
- Container height = `size` (matches surrounding label text)

**Color rules:**

- Lit bars: `AppConstants.effortColor(for: rpe)` — collapses to 3-band per § Effort Color Mapping (green / yellow / red).
- Unlit bars: `FortiFitColors.mutedText × 0.25`.

**Nil handling:** Not applicable. The Workout Detail Summary Effort card and the Metric Detail Sheet Effort hero are both conditionally rendered only when `workout.rpe != nil`, so the bars always have a tier to render.

**Accessibility:** The glyph is `.accessibilityHidden(true)` by default; the surrounding label/value text conveys the meaning. Call sites override with `.accessibilityIdentifier(...)` for UI test reachability (`workoutDetail_summaryCard_effortBars`, `metricDetailSheet_hero_effortBars`).

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
| Effort (Workout Detail Summary, Metric Detail Sheet hero, Share Image Card) | Custom `FortiFitEffortBars` glyph — lit bars use the dynamic band color from § Effort Color Mapping; unlit bars use `FortiFitColors.mutedText × 0.25`. See § Effort Bars Glyph. | Dynamic — maps from `workout.rpe` per § Effort Color Mapping | Per-segment color — each segment endpoint maps via § Effort Color Mapping |
| Effort (Log Workout dropdown) | Multi-color palette on `chart.bar.fill`: short bar `#10b981`, middle bar `#C4F648`, tall bar `#ef4444` | Dynamic — maps from `workout.rpe` per § Effort Color Mapping | n/a |
| Duration | `#289193` (teal) | `#289193` | `#289193` |
| Distance | `#6E8CCD` (periwinkle) | `#6E8CCD` | `#6E8CCD` |
| Avg HR | `#BA3535` (darker red) | `#BA3535` | `#BA3535` |
| Max HR | `#ef4444` (red) | `#ef4444` | `#ef4444` |
| Active kcal | `#CC7A00` (darker orange) | `#CC7A00` | `#CC7A00` |
| Total kcal | `#FFA600` (orange) | `#FFA600` | `#FFA600` |
| Elevation Ascended | `#934F28` (orange) | `#934F28` | `#934F28` |
| Exercise Minutes | `#289193` (teal) | `#289193` | `#289193` |

**Notes on the table above:**
- Most hex values reference tokens already defined in § Colors (Positive Green, Caution Yellow, Alert Red, Chart Orange, Chart Teal). Distance uses periwinkle `#6E8CCD` (defined inline as `AppConstants.statCardDistance`); Avg HR uses darker red `#BA3535` (defined inline as `AppConstants.statCardHeartRateDark`).
- Elevation and Exercise Minutes are not in the user's explicit color spec but inherit sensible defaults — Elevation tracks the calorie family (orange) since it represents "work performed against gravity," and Exercise Minutes tracks the Duration family (teal) since it's a time-based metric. Adjust if a different mapping is preferred.
- The Effort palette-rendered SF Symbol applies only on the Log Workout dropdown: `Image(systemName: "chart.bar.fill").symbolRenderingMode(.palette).foregroundStyle(.green, .yellow, .red)` (using the actual hex tokens). Layer order in `chart.bar.fill` is short → medium → tall, so the foreground style tuple maps to that order naturally; verify visually on first build in case Apple changes the layer order in a future SF Symbols release. On the Workout Detail Summary, the Metric Detail Sheet hero, and the Share Image Card, the SF Symbol is replaced by `FortiFitEffortBars` per § Effort Bars Glyph.

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
| `statePairAppleWatchMessage` | "No recent Apple Watch activity detected. Wear your Apple Watch to track your Move, Exercise, and Stand activity here." |

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
| `settingsModalImportButton` | "Import from Apple Health" |
| `settingsModalImportDisabledCaption` | "Connect Apple Health to import your goals." |
| `settingsModalDoneButton` | See § Settings Modal Done Button below — shared constant `AppConstants.SettingsModal.doneButtonLabel = "Done"`. |

> **Phase 8.8 changes:** The previous `settingsModalResetButton` constant ("Reset to defaults") has been removed entirely. The previous accessibility identifier `activityRingsSettings_resetButton` is retired and must not be reused. Button order in the modal is now Import (first) → Done (second), top-to-bottom, both full-width. See SCREENS.md § Activity Rings Settings Modal for the full layout.

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
["trainingLoad", "weekStreak", "powerLevel", "todaysPlan", "appleActivity", "recoveryStatus"]
```

| Identifier | Display Name | Description |
|------------|-------------|-------------|
| `trainingLoad` | Training Load | Shows your accumulated training stress score and recovery readiness based on recent workout intensity, volume, and frequency. |
| `weekStreak` | Week Streak | Tracks how many consecutive weeks you've met your weekly workout target. |
| `powerLevel` | Power Level | Measures your average strength volume trend across Strength Training and HIIT workouts so you can see if you're getting stronger. |
| `todaysPlan` | Today's Plan | Shows your scheduled workout for today so you can jump straight into logging. Long-press → "Complete Workout" opens the same compact confirmation sheet as the Plan tab. |
| `appleActivity` | Activity Rings | Tracks your daily Move, Exercise, and Stand rings. Requires an Apple Watch and Apple Health connected in Settings. |
| `recoveryStatus` | Recovery Status | Tracks your sleep, recovery, and time since your last workout. Requires a sleep-tracking device (Apple Watch, Oura, Whoop, etc.) and Apple Health connected in Settings. When placed adjacent to Training Load, the two widgets link into a single composite with shared border, sleep-adjusted decay, and Sleep Impact Chip. |

> **Removed widgets:** `workoutInfo` (Workout Info) was retired in this revision. It duplicated the Recent Workouts list directly below the widget stack and offered no decision-relevant signal beyond a vanity Total Workouts count. See SERVICES.md § HomeWidgetService → One-time migration for the cleanup of existing `workoutInfo` records on the upgrade build.

### Default Home Widgets (first launch)
```swift
["todaysPlan", "trainingLoad", "powerLevel"]
```
Week Streak, Activity Rings, and Recovery Status are add-only — available via the Add Widgets menu but not seeded on first launch.

### Add Widgets Menu Order

The Add Widgets menu lists every non-active widget type in this canonical order. Recovery Status sits directly below Training Load so users discover the linking behavior when they add the second of the pair. Weekly Streak anchors the bottom of the list.

```swift
["trainingLoad", "recoveryStatus", "powerLevel", "todaysPlan", "appleActivity", "weekStreak"]
```

| Position | Identifier | Notes |
|---|---|---|
| 1 | `trainingLoad` | Anchors the recovery cluster at the top of the list. |
| 2 | `recoveryStatus` | **Phase 11.** Directly below Training Load so the linking affordance is discoverable: dragging Recovery Status to the slot directly above or below Training Load auto-links the pair (unless `recoveryLoadManuallyUnlinked == true`). See SCREENS.md § Standard Patterns → Widget Linking. |
| 3 | `powerLevel` | Strength-trend complement to the recovery cluster. |
| 4 | `todaysPlan` | Schedule-driven companion to the performance/recovery cluster above. |
| 5 | `appleActivity` | Apple Health–gated; clusters with other HK-aware widgets. |
| 6 | `weekStreak` | Motivational anchor at the bottom of the list. |

Rows render with: SF Symbol (widget glyph), Display Name, description string from the table above. Add button is always enabled regardless of HK/Watch state — gating happens via the in-card states once the widget is on the Home grid (mirrors Activity Rings precedent — see HEALTHKIT.md § 21 and SCREENS.md § Home Screen → Add Widgets Menu).

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
| `personalRecords` | `+{delta} {unit}` (current − previous) | `LATEST PR CHANGE` |
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

### Advisory Text (Context-Aware) — Standalone Training Load Widget

Used by the standalone Training Load widget body and the Training Load Detail Sheet's Recovery Readiness callout. The linked Recovery & Load composite uses a different copy table — see § Linked Advisory Copy below.

If user has NOT logged a workout today → readiness variant. If user HAS → post-training variant.

| Zone | Readiness (no workout today) | Post-Training (trained today) |
|---|---|---|
| Resting | "No recent training stress. Ready for a full session." | *(cannot occur — floor > 0 if trained today)* |
| Low | "Well recovered. Ready to train." | "Session logged. You have more capacity to train again if you choose." |
| Moderate | "Some muscle fatigue. A moderate session would be ideal." | "Good work today. Rest up." |
| High | "Significant muscle fatigue. Consider a lighter session or active recovery." | "Recovery is the priority." |
| Peak | "High physical stress. Rest or very light activity recommended." | "You've been pushing hard. Time to rest." |

### Linked Advisory Copy (linked Recovery & Load composite only)

Used by the linked Recovery & Load composite — the Training Load widget body inside the linked pair, and the Linked Recovery & Load Detail Sheet's Recovery Readiness callout. The standalone Training Load widget and its detail sheet keep using the table above; this copy never bleeds into the unlinked surface.

Computed by `RecoveryStatusService.computeLinkedAdvisory(baseAdvisory:zone:trainedToday:sleepHours:targetSleepHours:)`. Met-target and missing-data nights pass `baseAdvisory` through unchanged — the joint sentence only replaces the base when sleep is strong, moderately below, or significantly below target. Resolves BUG-061 (concatenating an independent sleep qualifier could produce contradictory pairings like *"Well recovered. Ready to train. You're significantly under-slept."*).

Sleep buckets:

| Sleep ratio (sleepHours / targetSleepHours) | Bucket | Behavior |
|---|---|---|
| `≥ 1.0` | `strong` | Base advisory replaced with a joint sentence that appends a positive sleep note. |
| `0.85 – 0.99` | `metTarget` | `baseAdvisory` returned unchanged. |
| `0.70 – 0.84` | `moderatelyBelow` | Base advisory replaced with a joint sentence that downgrades intensity one notch. |
| `< 0.70` | `significantlyBelow` | Base advisory replaced with a joint sentence that clamps the recommendation at light / rest. |
| `nil` (no sleep data) | n/a | `baseAdvisory` returned unchanged. |

Stored in `AppConstants.TrainingLoad.linkedAdvisoryText` as a dictionary keyed by `"<zone>|<trainedToday>|<sleepBucket>"`. 27 unique strings — five zones × two `trainedToday` values × three non-empty sleep buckets, minus three Resting × trained combinations (the same-day floor in `ExerciseLoadService.calculateLoad` prevents that pairing). See INFO_COPY.md § Training Load Zones → Linked Advisory Copy for the canonical copy entries.

---

## Streak Flame Tiers

| Streak | Tier | Flame Style | Card Border |
|--------|------|------------|-------------|
| 0 | Dormant | Gray silhouette (#404040), 35% opacity, small scale | Default (#404040) |
| 1–3 | Building | Small, #1e40af → #3b82f6 → #93c5fd gradient, subtle glow | Default (#404040) |
| 4–7 | Committed | Medium, #1e3a8a → #3b82f6 → #bfdbfe gradient, stronger glow | Blue (#3b82f6) |
| 8+ | Elite | Large, #1e3a8a → #60a5fa → #eff6ff gradient, strongest glow | Light Blue (#60a5fa) |

### Streak Motivational Messages

| Streak | Message |
|--------|---------|
| 0 | "Hit your weekly target to start a streak!" |
| 1 | "One week down. It's all you, brah." |
| 2 | "Two weeks. Respect." |
| 3 | "Three weeks. Officially not a resolutioner." |
| 4 | "Four weeks. Do you even lift? Yes. Yes you do." |
| 5 | "Five weeks. Solid. Tight. Locked in." |
| 6 | "Six weeks. Consistency yields results." |
| 7 | "Seven weeks. Yeah buddy." |
| 8 | "Eight weeks. Absolute unit behavior." |
| 9 | "Nine weeks. Flexing on 'em respectfully." |
| 10 | "Ten weeks. Double digits. Built different." |
| 11 | "Eleven weeks. Mirin." |
| 12+ | "Unstoppable. We're all gonna make it, brah." |

---

## Power Level Statuses

| Status | Directional Indicator | Color | Contextual Message |
|--------|----------------------|-------|-------------------|
| Deloading | ↓ | Red (#ef4444) | "Your volume has decreased over the last 30 days." |
| Steady | — | Muted Text gray (#737373) | "Your volume has been consistent over the last 30 days." |
| Rising | ↑ | Green (#10b981) | "Your volume has been increasing over the last 30 days." |
| No data | — | — | "Log Strength Training or HIIT workouts to track your power level." |

Thresholds: < −10% = Deloading, −10% to +10% = Steady, > +10% = Rising.

> **Phase 12 note:** the **Contextual Message** column is no longer rendered as a visible line on the Power Level widget card or the Breakdown Sheet hero (the gauge + directional indicator + delta caption carry the meaning). It is retained as the VoiceOver announcement string for the gauge (see § Power Level Gauge → Accessibility) and as the source for the See Info modal's plain-language summary. The **No data** row's message remains the card's empty-state copy when fewer than 3 qualifying workouts exist.

---

## Power Level Gauge (Phase 12)

Shared visual tokens for the continuous Power Level gauge. The **same** gauge renders on the Power Level widget card (compact) and the Breakdown Sheet hero (larger). Surfaces the underlying continuous `pct_change` that the categorical status (Deloading/Steady/Rising) is derived from. See SCREENS.md § Home Screen → Power Level widget, § Power Level Breakdown Sheet → block 1, and SERVICES.md § Power Level Algorithm → Widget & Hero Gauge Position.

### Track

| Property | Value |
|---|---|
| Visible range | Fixed **−30% … +30%** of `pct_change`. Values beyond clamp to the track ends and trigger the **Overflow Indicator** treatment on the thumb (the delta caption still shows the true figure). See § Overflow Indicator below. |
| Height | 8pt (widget and sheet) |
| Corner radius | 4pt (capsule ends) |
| Zone fills | Deloading `#ef4444` (Alert Red) from −30% to −10% · Steady `#404040` (Border gray) from −10% to +10% · Rising `#10b981` (Positive Green) from +10% to +30%. Zones meet at the threshold ticks. |
| Threshold ticks | Two 1pt dividers at −10% and +10%, filled with the **card background** (`#1a1a1a` on the widget / sheet card surface) so the zones read as separated segments. |
| Lateral inset | The gauge body (track + axis labels together) is inset **16pt** on each side from the parent card's content area. This leaves breathing room for the thumb at clamped positions (8pt overhang past the track end) and, when off-scale, the indicator halo (14pt outer radius). Position math is unchanged — `pct ∈ [−30, +30]` still maps across the (now narrower) track width. |

### Thumb

| Property | Value |
|---|---|
| Shape | Circle, 16pt diameter |
| Fill | Current **status color** (red / gray-`#737373` for Steady / green) |
| Border | 2pt, card-background color (`#1a1a1a`) for contrast against the track |
| Position | Center mapped from clamped `pct_change`: `x = (clamp(pct, −30, 30) + 30) / 60` across the track width. At exactly the −10% / +10% boundary, the thumb sits on the tick. |

### Overflow Indicator

Renders an "off-scale" treatment on the thumb when `pct_change` lies outside the gauge's visible range, so the clamped thumb position cannot be misread as the exact value. The delta caption remains the source of truth for the precise figure; the indicator is a redundant visual signal that the bar has saturated. Visual reference: `Design Mockups/PowerLevelWidgetGauge_Overflow.svg` (Option A).

| Property | Value |
|---|---|
| Trigger | `|pct_change| > 30` (strict greater-than). At exactly ±30% the thumb sits on the axis label without an overflow indicator. Hidden in the No-Data state. |
| Halo | Two concentric `Circle`s rendered **behind** the thumb. Radii proportional to `thumbDiameter` — outer ≈ `thumbDiameter × 0.875`, inner ≈ `thumbDiameter × 0.6875` (so the halo scales 1:1 between the compact widget and the Breakdown Sheet hero). Fill = the same status color as the thumb; opacity = **28%** (inner) / **18%** (outer). |
| Chevron | SF Symbol `chevron.right.2` (double chevron) for positive overflow (`pct_change > +30`) · `chevron.left.2` for negative overflow (`pct_change < −30`). Centered inside the thumb. ~9pt, `.bold` weight, tinted **Card Surface** (`#1a1a1a`) for contrast against the colored thumb fill. |
| Animation | Static — no pulse, fade, or rotation. The thumb's existing position animation (`.easeOut 0.4s`) carries it to the clamped edge; the indicator simply appears/disappears with the position update. Respects `accessibilityReduceMotion` by inheriting the parent's no-animation branch. |
| Caption / Ticks / Position math | **Unchanged.** Tick labels remain `−30% / −10% / +10% / +30%`; position formula is identical; delta caption continues to show the true `pct_change`. |
| Symmetry | Same rules mirror on the negative side — chevron points left, halo and opacity values are identical, glow color follows the Deloading status. |
| Accessibility identifier | `homeWidget_powerLevel_gaugeOverflowIndicator` (compact) · `powerLevelDetailSheet_heroGaugeOverflowIndicator` (hero) — attached to the halo+chevron composite. |

### Thumb Pulse

A subtle breathing halo behind the thumb that surfaces "live, still changing" on the active states. Renders on **both** the compact widget and the Breakdown Sheet hero. Color tracks the thumb's status color, so the visual cue inherits the state mapping automatically.

| Property | Value |
|---|---|
| Trigger | Status is `.rising` or `.deloading`, the gauge is **not** in the No-Data state, and `accessibilityReduceMotion` is **off**. The off-scale state does **not** suppress the pulse — the animated halo stacks behind the static off-scale halo so the "live" cue rides on top of the "saturated" cue. |
| Suppressed when | `.steady` (intentionally calm — nothing is changing) · No-Data state (no thumb to anchor the pulse) · Reduce Motion is on. |
| Shape | `Circle`, same 16pt diameter as the thumb, fill = thumb's status color (no border). |
| Animation | `scaleEffect` 1.0 → 2.1× combined with `opacity` 0.35 → 0 over **1.6s**, `.easeOut`, `repeatForever(autoreverses: false)`. Begins on `onAppear`. |
| Z-order | Rendered **behind** the thumb and, when off-scale, behind the overflow halo + chevron as well. |
| Accessibility identifier | `homeWidget_powerLevel_gaugeThumbPulse` (compact) · `powerLevelDetailSheet_heroGaugeThumbPulse` (hero) — attached to the breathing halo circle. Present in the view hierarchy only when the pulse is rendering. |

### Directional Indicator

Renders **only** on the Breakdown Sheet hero. The widget card omits the glyph entirely — the gauge thumb + color zones carry the state, and the delta caption carries the magnitude. `FortiFitPowerLevelGauge.glyph(for:)` remains the shared mapping used by the hero.

| Property | Value |
|---|---|
| Glyph | `↓` Deloading · `—` Steady · `↑` Rising (status-colored). Sole status glyph on the hero — no status word. |
| Size | Widget: **not rendered.** Sheet hero: ~40pt. |

### Delta Caption

| Property | Value |
|---|---|
| Format | `{sign}{pct}% vs prior 30d` (widget) · `{sign}{pct}% vs prior 30 days` (sheet hero) |
| Color | Muted Text `#737373` |
| Source | `PowerLevelService.windowComparison().deltaPct`, rounded to a whole percent. Carries the true value even when the thumb is clamped. |

### Axis Labels

`−30%` / `−10%` / `+10%` / `+30%` beneath the track, `FortiFitTypography.labelSmall` (13/semibold) with 1pt kerning, Muted Text, aligned to the track ends and the two ticks. Rendered on **both** the widget card and the Breakdown Sheet hero (the two outer labels sit at the track ends; the −10% / +10% labels center under their threshold ticks).

### Empty / No-Data State

When fewer than 3 qualifying Strength/HIIT workouts exist in the current 30d window: render the track in Steady gray only (no zones, no thumb), `—` indicator, and the **No data** copy from § Power Level Statuses in place of the delta caption. Matches the Breakdown Sheet hero per-block empty state (SCREENS.md § Power Level Breakdown Sheet → Per-block empty states).

### Accessibility

The gauge exposes a single combined VoiceOver label: `"Power level: {status}. {pct}% versus the prior 30 days."` — the status **word** is spoken here even though it is not drawn, so the state is never conveyed by color alone (WCAG AA, PRD § Accessibility). When `|pct_change| > 30`, the label appends `" Off-scale — past +30%."` (or `−30%`), so the off-scale state is announced rather than left only as a visual cue. Reduce Motion: the thumb snaps to position rather than animating on recompute, and the Thumb Pulse is suppressed entirely.

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
| Stat card icons | SF Symbols per § Workout Detail Summary Icons and § Workout Detail Health Data Icons, rendered at same size and color as the label text. **Effort** uses the custom `FortiFitEffortBars` 5-bar glyph (size 12) per § Effort Bars Glyph — not an SF Symbol. |
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

---

## Settings Modal Done Button (Phase 8.8)

Shared style + copy for the `Done` button added to the Weekly Streak, Training Load, and Activity Rings Settings Modals (SCREENS.md § Home Screen → Widget Definitions and § Activity Rings Settings Modal).

| Property | Value |
|----------|-------|
| Style | Outlined Primary Accent Blue (`#3b82f6` border + label, transparent fill) — distinct from blue-filled CTAs used for primary commits |
| Copy | `Done` (`AppConstants.SettingsModal.doneButtonLabel`) |
| Width | Full-width within the modal's inner padding |
| Height | 44pt minimum (Apple HIG tap target) |
| Corner radius | 12pt |
| Border width | 1.5pt |
| Font | `FortiFitTypography.bodySmall`, 700 weight |
| Position | Last action in the modal (bottom-most), beneath any other action buttons |
| Action | Dismisses the modal — identical behavior to the top-right close X. No commit step (sliders already apply changes immediately). |
| Accessibility | VoiceOver label: `Done, button` |
| Identifier convention | `{modalId}_doneButton` — current modals: `weeklyStreakSettings_doneButton`, `trainingLoadSettings_doneButton`, `activityRingsSettings_doneButton` |

> **Rationale for outlined (not filled):** Sliders auto-apply on change, so Done is a dismiss, not a submit. Outlined styling distinguishes it from the filled "primary commit" CTAs used elsewhere (Save Workout, Save Goal, Import from Apple Health). It also visually defers to other actions in modals that have a filled CTA above it (Activity Rings → Import from Apple Health).

---

## Widget Tap Behavior (Phase 8.8)

Reference table for the new tap routing introduced in Phase 8.8 (see SCREENS.md § Standard Patterns → Home Widget Tap-to-Open and SERVICES.md § HomeWidgetService → Widget Tap Routing).

| Widget | Tap result | Suppressed in Edit Mode? | Long-press still available? |
|---|---|---|---|
| `todaysPlan` | Opens Today's Plan Detail Sheet | Yes | Yes |
| `trainingLoad` | Opens Training Load Detail Sheet | Yes | Yes (See Info / Configure Settings) |
| `weekStreak` | Opens Weekly Streak Insights Sheet | Yes | Yes (Configure Settings) |
| `powerLevel` | Opens Power Level Breakdown Sheet | Yes | Yes (See Info) |
| `appleActivity` (live state) | Opens Activity Detail Sheet (existing) | Yes | Yes (See Info / Configure Settings) |
| `appleActivity` (connect HK state) | Navigates to Settings → Apple Health (existing) | Yes | Yes |
| `appleActivity` (pair Watch state) | No-op (existing) | Yes | Yes |

---

## Widget Detail Sheet Visual Tokens (Phase 8.8)

Shared visual treatment for the four new detail sheets (Today's Plan, Training Load, Weekly Streak Insights, Power Level Breakdown) and the Activity Detail Sheet retrofit.

### Sheet Presentation

| Property | Value |
|---|---|
| Presentation | iOS modal sheet, `.large` detent |
| Dismissal | Swipe-down + tap close X (top-right) |
| Drag indicator | Visible (Apple default) |
| Background | Card Surface (`#1a1a1a`) |
| Top inset | Standard sheet header area (~24pt) |

### Header

| Element | Treatment |
|---|---|
| Title | Centered, Primary Text, 20px / 800 weight |
| Close button | Top-right 24×24pt circular, Elevated Surface bg + Border, muted `xmark`. Identifier `{sheetId}_closeButton` |

### Hero Block

Per-sheet hero hero treatment:

| Sheet | Hero |
|---|---|
| Today's Plan Detail Sheet | No standalone hero — the mini-card list is the body |
| Training Load Detail Sheet | Larger gradient bar (~280pt wide) + zone label (Primary Text, 22px / 800) + `{score} / 100` value beneath (zone-colored, 28px / 900) |
| Weekly Streak Insights Sheet | Massive streak count typography per § Weekly Streak Insights → Hero |
| Power Level Breakdown Sheet | Status label + directional indicator (48pt) + numeric average volume line |
| Activity Detail Sheet | No standalone hero — three sparkline blocks (existing) |

### Body Block Spacing

| Property | Value |
|---|---|
| Inter-block vertical gap | `FortiFitSpacing.cardPadding` (16pt) |
| Block internal padding | `FortiFitSpacing.cardPadding` (16pt) |
| Block container | `FortiFitCard` (consistent with home widget cards) |

### Footer Button Block

| Property | Value |
|---|---|
| Layout | Side-by-side text buttons, separated by `·` (Muted Text 13px). When a single entry applies, centered alone. |
| Color | Primary Accent Blue `#3b82f6` |
| Font | 13px / 600 weight |
| Tap target | 44pt vertical minimum per button |
| Spacing from last body block | 24pt |
| Identifier convention | `{sheetId}_seeInfoButton`, `{sheetId}_configureSettingsButton` |

### Per-Sheet Footer Variants

| Sheet | See Info? | Configure Settings? |
|---|---|---|
| Today's Plan Detail Sheet | — | — |
| Training Load Detail Sheet | ✓ | ✓ |
| Weekly Streak Insights Sheet | — | ✓ |
| Power Level Breakdown Sheet | ✓ | — |
| Activity Detail Sheet | ✓ | ✓ |

---

## Weekly Streak Insights (Phase 8.8)

Visual + content constants specific to the Weekly Streak Insights Sheet (SCREENS.md § Weekly Streak Insights Sheet).

### Hero

| Property | Value |
|---|---|
| Number font | System, ~96–120pt, 900 weight |
| Number color | Optional linear gradient `#3b82f6` → `#93c5fd`, vertical top-to-bottom; falls back to Primary Accent Blue solid when gradient mode is disabled |
| Number animation | Count-up from 0 → `currentStreak` over 0.6s, ease-out, on sheet appear. Skip animation when `UIAccessibility.isReduceMotionEnabled == true` (render final value directly). |
| Sub-label | `WEEK STREAK`, Primary Accent Blue, uppercase, 13px / 800, 2px letter spacing |
| Identifier | `weeklyStreakDetailSheet_hero` |

### Heatmap Color Ramp

| State | Fill | Border |
|---|---|---|
| Untracked / pre-app | Card Surface (`#1a1a1a`) | 1px `#404040` |
| Below target (1 ≤ workouts < target) | Primary Accent Blue at 25% opacity | None |
| Target met (workouts ≥ target) | Primary Accent Blue at 100% opacity | None |
| Current in-progress week (index 0) | Fill per its current count band | 1px Primary Accent Blue ring |

### Heatmap Geometry

| Property | Value |
|---|---|
| Total weeks rendered | 26 (fixed — no toggle in v1) |
| Grid | 4 columns × ~7 rows; oldest week top-left, dates ascend left-to-right then top-to-bottom; current in-progress week is bottom-right |
| Cell size | ~32×32pt |
| Cell gap | 4pt |
| Day-of-Monday label | Primary Text 10/600, centered within cell |
| Tooltip on tap | `FortiFitTooltip`, copy `{n} of {target} workouts · week of {Mon date}`, anchored above the cell |

### Milestone Marks

```swift
[1, 4, 12, 26, 52]   // weeks
```

| Badge style | SF Symbol | Size |
|---|---|---|
| Unlocked | `trophy.fill`, Primary Accent Blue | 36pt |
| Locked | `trophy`, Muted Text | 36pt |
| Next-unlocked highlight | 1px Primary Accent Blue ring + 6% blue card-surface wash behind the locked badge | — |
| Below-badge label | Uppercase `1 WK` / `4 WKS` / `12 WKS` / `26 WKS` / `52 WKS`, Muted Text 10/700 | — |

### Stat Row Labels

| Position | Label (uppercase) | Source |
|---|---|---|
| Left | `CURRENT STREAK` | `StreakService.currentStreak` |
| Middle | `ALL-TIME BEST` | `StreakService.longestStreak` |
| Right | `TOTAL WEEKS LOGGED` | `StreakService.historySummary().totalWeeksLogged` |

---

## Training Load Detail Sheet (Phase 8.8)

Visual + content constants specific to the Training Load Detail Sheet (SCREENS.md § Training Load Detail Sheet).

### Hero

| Property | Value |
|---|---|
| Gradient bar | Reuses § Training Load Zones color stops, ~280pt wide, ~14pt tall |
| Zone label font | Primary Text 22/800 |
| Score value font | Zone color, 28px / 900 |
| Score format | `{score} / 100` |

### 14-Day Chart

| Property | Value |
|---|---|
| Range | Fixed 14 days (today inclusive) — no toggle |
| Mark type | Smoothed line + per-day filled circle (~3pt); today's point ~6pt Primary Accent Blue (matches `trainingLoadTrend` Trends chart) |
| Line interpolation | `.catmullRom` (matches CONSTANTS § Trends Chart Visual Tokens → Line Interpolation) |
| Per-point color | Zone color for that day |
| Y-axis | 0–100, gridlines at 30 / 55 / 80 (zone thresholds) |
| Gradient anchor | `#3b82f6` Primary Accent Blue (single-color vertical fade) |
| Selection — interaction | Tap to select; drag to scrub. Matches `FortiFitChartDetailView` (Trends chart detail) behavior |
| Selection — visual | Selected point upsized to ~96pt; non-selected points dim to 35% opacity; line dims to 55% opacity; vertical `RuleMark` at selected x in Primary Accent Blue 60% opacity |
| Selection — haptic | Light impact on selection change (iOS only) |
| Selection — annotation | `{score} / 100 · {zone}` (left, zone-colored) and `{date.shortFormatted}` (right, Muted Text) rendered as a row below the chart |
| Identifiers | Per-point: `trainingLoadDetailSheet_chartDataPoint_{index}`. Annotation: `trainingLoadDetailSheet_chartSelectionAnnotation` |

### Contributing Workouts Block

| Property | Value |
|---|---|
| Max rows | 5 |
| Lookback | 7 days |
| Row format | `{name}` (Primary Text 15/700) · `{date}` (Muted 13px) · `{pct}%` (Muted 13px, monospaced digit) · inline horizontal share bar (~56×4pt capsule, Primary Accent Blue fill on Elevated Surface track, filled to `pct/100`). Absolute training-load value is intentionally not displayed — created additivity confusion vs the hero score and read as "0 training load · 5%" after integer rounding. |
| Footer link | `See all in Trends →` (Primary Accent Blue 13/600) — navigates to Trends → Training Load Trend chart detail |

### Week Comparison Band

Row + trailing italic caption inside a single `FortiFitCard`. Matches the linked Recovery & Load Detail Sheet's Window Comparison treatment (CONSTANTS § Linked Recovery & Load Detail Sheet → Window Comparison Band).

| Property | Value |
|---|---|
| Row copy template | `Training load · {arrow} {abs(deltaPct)}%` (no "vs last week" suffix — the caption beneath establishes the comparison) |
| Arrow rule | `↑` when `deltaPct >= 0`, `↓` when `deltaPct < 0` |
| Delta color when current ≤ previous | Positive Green `#10b981` |
| Delta color when current > previous | Alert Red `#ef4444` |
| Caption copy template | `This week so far ({Mon, MMM d} – today) vs same period last week ({Mon, MMM d} – {matched weekday, MMM d})` — 11pt italic Muted Text |
| Caption identifier | `trainingLoadDetailSheet_weekComparisonCaption` |
| Comparison windows | Day-of-week matched (BUG-066): Mon-through-current-weekday this ISO week vs Mon-through-the-same-weekday last ISO week. On Sunday the windows collapse to a full Mon–Sun comparison. Driven by `ExerciseLoadService.weekOverWeekComparison(context:now:)` |
| Insufficient-data treatment | When `matchedDayCount < 2` (early Monday), the row renders `Not enough data` in Muted Text in place of a delta. Caption still renders so the user can see what window would have been used |
| Hidden when | `matchedDayCount >= 2` AND `currentWeekTss == 0` AND `previousWeekTss == 0` (truly no data on either side) — preserves the existing "never-trained users don't see an empty card" behavior |
| Absolute total | Intentionally not displayed — consistency with contributing-workouts rows (no per-row absolute either) and avoids the additivity-vs-hero confusion |

---

## Power Level Detail Sheet (Phase 8.8)

Visual + content constants specific to the Power Level Breakdown Sheet (SCREENS.md § Power Level Breakdown Sheet).

### Hero (Phase 12 — icon-only gauge)

Mirrors the widget gauge at sheet scale. Full token set in § Power Level Gauge.

| Property | Value |
|---|---|
| Status word | **Not rendered** (Phase 12). The directional indicator is the sole status glyph. |
| Directional indicator size | ~40pt, status-colored |
| Numeric line | `{currentAvgVolume} avg volume` (Primary Text 20/700 + Muted unit) |
| Delta caption | `{sign}{pct}% vs prior 30 days` (Muted Text) |
| Gauge | Continuous track per § Power Level Gauge (−30%…+30%, threshold ticks, status-zoned, status-colored thumb, axis labels). |

### 30-Day Volume Chart

| Property | Value |
|---|---|
| Range | Fixed 30 days (today inclusive) — no toggle |
| Mark type | Smoothed line, today's point highlighted |
| Line interpolation | `.catmullRom` |
| Gradient anchor | `#4B2893` Chart Purple (matches `workoutVolume` Trends chart) |
| Empty-day handling | No point (gap in line) — do not interpolate across missing days |

### Top Exercises Block

| Property | Value |
|---|---|
| Card header | `Driving Your Trend` (Primary Text, `FortiFitTypography.detailSheetItemTitle`) |
| Subtitle | `% change in volume vs previous 30 days` (Muted Text, `FortiFitTypography.labelSmall`). Sits directly below the header, above the rows. Disambiguates the per-row `%` values as each exercise's own 30-day volume delta — *not* a share of the overall window-comparison delta. |
| Max rows | 3 |
| Filter | `sessionCountInWindow >= 3` (≥ 3-session filter per Phase 8.8) |
| Row layout | Exercise name (`FortiFitTypography.bodySmall`, Muted Text, single-line) · `{sign}{deltaPct}%` (sign-colored against the *rounded display value*: Positive green `#10b981` when `> 0`, Alert red `#ef4444` when `< 0`, Muted gray `#737373` when the value rounds to `0%` — so near-zero values like `+0.3%` that display as `0%` share the muted treatment; `FortiFitTypography.labelSmall`, right-aligned). The qualifying "volume vs previous 30 days" copy is rendered once at the card level (see Subtitle above) rather than repeated per row. |
| Sort | Descending current-window volume; ties broken by descending session count, then exercise name ascending |

### Window Comparison Bars (Phase 12)

Block 2 visual — two stacked bars (positioned directly below the hero gauge, above the Top Exercises card). Source: `PowerLevelService.windowComparison()` (no new service logic).

| Property | Value |
|---|---|
| Header | `Window comparison` (Primary Text, `FortiFitTypography.detailSheetItemTitle` — 18pt regular, matches the Top Exercises card header) |
| Delta chip | `{sign}{deltaPct}%`, status-colored text on a faint same-hue tint (~12% opacity of the status color), ~3×8pt padding, 6pt radius, right-aligned in the header row |
| Bar track | Elevated Surface `#2d2d2d`, 10pt height, 5pt corner radius |
| Previous bar | Fill Muted gray `#737373`; micro-label `PREVIOUS 30D` (uppercase `FortiFitTypography.labelSmall` — 13/semibold — with 1pt kerning); right-aligned value `{previous30dAvg}` (`FortiFitTypography.labelSmall`, Secondary Text) |
| Current bar | Fill **status color**; micro-label `CURRENT 30D` (uppercase `FortiFitTypography.labelSmall` — 13/semibold — with 1pt kerning, status-colored); right-aligned value `{current30dAvg}` (`FortiFitTypography.labelSmall`, Primary Text) |
| Scaling | Both bars scaled to the **larger** of the two averages — larger bar fills the track, smaller fills `min/max` proportionally |
| Values | Displayed via `UnitConversion.displayWeight(kg:)` |
| Empty rule | Hide the entire block when `current30dAvg == 0` OR `previous30dAvg == 0` (unchanged) |

### Nudge Archetypes

```swift
["deloading", "steady", "rising", "coldStart"]
```

| Archetype | Inputs surfaced in copy | Trigger |
|---|---|---|
| `deloading` | `currentSessionCount30d`, `previousSessionCount30d` | `status == .deloading` AND ≥ 3 in-window workouts |
| `steady` | `topExerciseName` (gracefully degrades when nil) | `status == .steady` AND ≥ 3 in-window workouts |
| `rising` | `avgSessionsPerWeek30d`, optional `topExerciseName` | `status == .rising` AND ≥ 3 in-window workouts |
| `coldStart` | (none) | Fewer than 3 Strength/HIIT workouts in the current 30d window |

Copy templates live in INFO_COPY § Power Level Nudge Copy. Stored in `AppConstants.PowerLevel.nudgeCopy` as a dictionary keyed by archetype rawValue.

---

## Today's Plan Detail Sheet (Phase 8.8)

Visual + content constants specific to the Today's Plan Detail Sheet (SCREENS.md § Today's Plan Detail Sheet).

### Mini-Card Layout

| Slot | Value |
|---|---|
| Top row | Workout-type SF Symbol (18pt) + template name (Primary Text 17/700) + status pill (right-aligned) |
| Meta row | `{time} · {duration} · {watchSyncGlyph}` (Muted 13px, `·`-separated) |
| Exercise list | Per-exercise grouped list. Exercise name header (`FortiFitTypography.labelSmall` = 13px/600, Primary Text). One line per `SnapshotExercise` set group below (`FortiFitTypography.labelSmall`, Muted Text), format: `{sets} × {reps} reps[ · {weight} kg/lbs][ · rest {restSeconds}s]`. Time-based exercises render `{sets} × {reps}s`. `displayAsTime` resolution: explicit snapshot value wins → else `ExerciseSuggestionService.isIsometric(exerciseName)` (alias map → isometric set → ambiguous defaults → reps fallback). Weight suppressed for bodyweight. Unit follows `UserSettings.useLbs`. Replaces the previous "`{n} exercises · {m} sets`" summary row. |
| Action row | Full-width `Complete Workout` button (blue-filled, primary CTA) on Planned rows. **Hidden on Completed and Skipped rows** — the status pill is the sole signal (Phase 8.8 update). |

### Status Pills

| Status | Background | Border | Label color |
|---|---|---|---|
| Planned | Transparent | 1px Primary Accent Blue | Primary Accent Blue |
| Completed | Positive Green `#10b981` (filled) | None | White |
| Skipped | Transparent | 1px Muted Text | Muted Text |

### `+ Schedule another workout for today` Chip — RETIRED (Phase 8.8 follow-up)

The chip was removed from the Today's Plan Detail Sheet entirely. Users schedule additional workouts via the Plan tab. Identifier `todaysPlanDetailSheet_scheduleMoreButton` is retired and must not be reused.

### Empty State

| Property | Value |
|---|---|
| Copy | `No workouts planned for today.` (Muted Text, centered) |
| Identifier | `todaysPlanDetailSheet_emptyState` |

---

## Recovery Status Widget (Phase 11)

Visual + content constants for the standalone (unlinked) Recovery Status widget on the Home screen. See SCREENS.md § Home Screen → Recovery Status widget.

### Hero Typography

The hero region is two side-by-side columns: `SLEEP` (left) + `SINCE LAST WORKOUT` (right). Both columns share the same label/value styling. The SINCE LAST WORKOUT column renders in all 4 gating states (workout history is independent of HK sleep gating).

| Slot | Style |
|---|---|
| Widget header | `RECOVERY STATUS` — Primary Accent Blue 13/900, uppercase, 2px letter-spacing (standard widget header treatment) |
| Hero sub-labels | `SLEEP` / `SINCE LAST WORKOUT` — Primary Accent Blue 11/700, uppercase, 2px letter-spacing |
| Hero values | `{h}h {mm}m` (sleep) / `{value}` (workout — no trailing descriptor, sub-label supplies it) — Primary Text, **32px / 900 weight** (matches Weekly Streak count treatment). Muted Text when no data. |
| Deep caption (SLEEP column only) | `{pct}% DEEP · {h}h {mm}m` (e.g., `34% DEEP · 1h 24m`) — Muted Text 11/700, uppercase, 2px letter-spacing, dot-separated |
| Workout-name caption (SINCE LAST WORKOUT column only) | `{Workout.name}` rendered as-stored (sentence/title case as the user entered it — *not* forced uppercase) — Muted Text 11/700, 2px letter-spacing, single-line tail truncation. Falls back to `{Workout.workoutType}` when `name` is empty/whitespace. Suppressed entirely when no workout has been logged. |

### Since Last Workout Hero Value

Bare value rendered under the `SINCE LAST WORKOUT` sub-label in the right hero column. Same graceful precision degradation as the legacy timer meta line but without the trailing descriptor (the sub-label supplies that context). Any workout type counts (manual or HK-imported, all 6 types). Primary Text 32/900 (or Muted Text when `NO DATA`).

| Time since last workout | Format |
|---|---|
| `< 1 hour` | `{n} min` |
| `1–23 hours` | `{h}h {mm}m` |
| `24–72 hours` | `{d}d {h}h` |
| `> 72 hours` | `{d} days` |
| Never logged | `NO DATA` |

### Decorative Watermark

| Property | Value |
|---|---|
| SF Symbol | `moon.zzz` |
| Size | ~140pt |
| Color | Muted Text fill |
| Opacity (Live, incl. no-sleep-last-night sub-state) | 20% |
| Opacity (Connect Apple Health) | 10% (reduced — quieter empty state) |
| Opacity (No Sleep Tracker) | 10% |
| Opacity (Sleep Access Denied) | 10% |
| Placement | Centered in the card via `ZStack` (sits behind both hero columns), clipped by card edges |
| Identifier | `homeWidget_recoveryStatus_watermark` |

Identical treatment to Today's Plan's silhouette pattern. **No `info.circle` on the card body** — See Info accessed via long-press context menu only.

### No-Sleep-Last-Night Sub-State

When `hasRecentSleepData == true` but no `.asleep*` samples ended within last night's wake-up window:

| Element | Rendering |
|---|---|
| Hero value | `— h —m` (Muted Text 32/900) |
| Deep caption | `NO DATA` (Muted Text 11/700, uppercase) |
| Timer line | Renders normally per format breakpoints above |
| Watermark | Full 20% opacity |

### SF Symbols

| Symbol | Usage |
|---|---|
| `moon.zzz` | Card watermark and the `Sleep` row icon in Settings → Apple Health (see HEALTHKIT.md § 16). |

---

## Recovery Status Settings Modal (Phase 11)

Visual + content constants for the unlinked Configure Settings modal (SCREENS.md § Recovery Status Settings Modal).

### Heading

`Configure Recovery Status` — modal heading treatment per existing Configure modals.

### Sleep Target Slider

| Property | Value |
|---|---|
| Label | `Sleep Target — {value} hrs` (value bolded inline) |
| Range | `4.0` – `12.0` hours |
| Increment | `0.5` hours |
| Default | `7.0` hours |
| UserSettings field | `targetSleepHours: Double` |
| Identifier | `recoveryStatusSettings_targetSleepHoursSlider` |

### Import from Apple Health Button

| Property | Value |
|---|---|
| Label | `Import from Apple Health` |
| Style | `FortiFitButton(..., style: .primary)` — full-width filled Primary Accent Blue button. Matches Activity Rings Settings Modal Import button treatment for visual consistency. |
| Position | Below the slider |
| Action | `RecoveryStatusService.importSleepGoalFromAppleHealth()` — calls `HealthKitClient.fetchSleepDurationGoal()`. HealthKit does not expose a sleep duration goal characteristic in its public API (BUG-048), so the call always returns `nil` in the current build and the toast fires. The snap-to-0.5-hr-increment + 4.0–12.0 clamp logic is exercised in unit tests and ready for the day Apple ships a real API. |
| Disabled state | When HK not connected: `.opacity(0.4)` + `.disabled(true)` |
| Disabled caption (HK not connected) | `"Connect Apple Health to import your goal."` (Muted Text, `FortiFitTypography.note`, below button) |
| HK-no-goal toast | `"No sleep goal set in Apple Health."` (Toast Style — see § Toast Style) |
| Identifier | `recoveryStatusSettings_importButton` |

### Done Button

Reuses the **Settings Modal Done Button** treatment defined in § Settings Modal Done Button (Phase 8.8) — outlined Primary Accent Blue, full width, dismisses the modal. Identifier: `recoveryStatusSettings_doneButton`.

### Close Button

Standard modal `xmark` close button in the top-trailing corner. Identifier: `recoveryStatusSettings_closeButton`.

---

## Recovery Status Detail Sheet (Phase 11)

Visual + content constants for the unlinked Detail Sheet (SCREENS.md § Recovery Status Detail Sheet). Reuses the Widget Detail Sheet Visual Tokens (Phase 8.8) for sheet presentation, header, hero, body spacing, and footer button block.

### Hero Block

| Element | Rendering |
|---|---|
| Hero label | `SLEEP` (Primary Accent Blue 11/700, uppercase) |
| Hero value | `{h}h {mm}m` (Primary Text, sheet-hero scale — typically 48/900 per § Widget Detail Sheet Visual Tokens → Hero Block) |
| Deep caption | `{pct}% DEEP · {h}h {mm}m` (Muted Text 11/700, uppercase) |
| Identifier | `recoveryStatusDetailSheet_hero` |

### Sleep Stages Bar

Horizontal stacked bar showing the proportion of each stage within the wake-up window.

| Stage | Color |
|---|---|
| Deep | Chart Purple `#4B2893` |
| REM | Primary Accent Blue `#3b82f6` |
| Core | Light Blue `#93c5fd` (inline; not in token table) |
| Awake | Sleep Awake `#FF6B5B` (Phase 11) |

| Property | Value |
|---|---|
| Bar height | 12pt |
| Corner radius | 6pt (continuous) |
| Inter-stage divider | None — stages render edge-to-edge |
| Legend position | Below the bar, dot-separated, Muted Text 11/700 |
| Identifier (bar) | `recoveryStatusDetailSheet_stagesBar` |
| Identifier (legend) | `recoveryStatusDetailSheet_stagesLegend` |

### Sleep Efficiency Caption

| Property | Value |
|---|---|
| Format | `Sleep efficiency: {pct}% ({h}h {mm}m asleep of {h}h {mm}m in bed)` (italic, Muted Text 13px) |
| Visibility | Hidden when `DailySleepSnapshot.inBedMinutes == nil` |
| Position | Beneath the stages legend |
| Identifier | `recoveryStatusDetailSheet_sleepEfficiencyCaption` |

### 14-Day Sleep Sparkline

| Property | Value |
|---|---|
| Window | Last 14 days (rolling, anchored to today's wake-up date). Sourced from `RecoveryStatusService.recent30DaySleep.suffix(14)` so the underlying 30-day cache is unchanged. Matches the linked Recovery & Load Detail Sheet's sleep sparkline window. |
| Y-axis | Domain `4…10` hours; leading axis marks at `5`, `7`, `9` with 0.5pt dashed gridlines (Border) and Muted Text value labels. Matches the linked Recovery & Load Detail Sheet's sleep sparkline. |
| Line color | Chart Purple `#4B2893` |
| Line interpolation | `.catmullRom` (matches Trends chart visual tokens — § Trends Chart Visual Tokens → Line Interpolation) |
| Latest-point highlight | 6pt Primary Accent Blue filled dot (matches § Trends Chart Visual Tokens → Latest Data-Point Highlight) |
| Caption | `Last 14 days · Sleep duration` |
| Selection annotation | `{hours}h · {date}` on tap; `{hours}h · {weekday}` while scrubbing |
| Empty-state copy | `Not enough sleep data yet to chart trends.` (rendered when fewer than 7 days of snapshots exist) |
| Identifier (chart) | `recoveryStatusDetailSheet_sleepSparkline` |
| Identifier (data point) | `recoveryStatusDetailSheet_sleepSparkline_dataPoint_{index}` |
| Identifier (annotation) | `recoveryStatusDetailSheet_sleepSparkline_selectionAnnotation` |

### Last-7-Nights Stat Row

Three-cell stat row beneath the sparkline.

| Cell | Label | Value source |
|---|---|---|
| 1 | `AVG SLEEP` | Mean of `totalSleepMinutes` across last 7 `DailySleepSnapshot` records → formatted `{h}h {mm}m` |
| 2 | `AVG DEEP` | Mean of `deepSleepMinutes` across last 7 records → `{h}h {mm}m` |
| 3 | `NIGHTS ON TARGET` | Count of last 7 nights where `sleepHours >= targetSleepHours × 0.85` → `{n}/7` |

| Property | Value |
|---|---|
| Label style | Muted 11/700, uppercase, 2px letter-spacing |
| Value style | Primary Text 17/800 |
| Identifier | `recoveryStatusDetailSheet_last7NightsStatRow` |

### Time Since Last Workout Block

Below the sparkline + stat row. Shows the same headline timer line that's on the widget, plus a per-type breakdown.

| Element | Rendering |
|---|---|
| Headline row | Same format as widget timer line (§ Recovery Status Widget → Timer Meta Line). Tappable → Workout Detail of the most recent workout. |
| Per-type rows | One row per of the 6 workout types that has ≥ 1 record. Format: `{Workout Type Glyph} {Type Name} · {time since last}` (Muted 13px). Tap → Workouts tab with that type's card auto-expanded. |
| Per-type sort | Most-recent first (across types). |
| Identifier (block) | `recoveryStatusDetailSheet_timeSinceWorkout` |
| Identifier (headline) | `recoveryStatusDetailSheet_timeSinceWorkout_headline` |
| Identifier (type row) | `recoveryStatusDetailSheet_timeSinceWorkout_typeRow_{type}` |

### Cold-Start Empty State

When `Workout` count is zero (user has never logged a workout):

| Property | Value |
|---|---|
| Copy | `No workouts logged yet.` (Muted Text 15px, centered) |
| CTA | Full-width `Log a Workout` button (filled Primary Accent Blue) → navigates to Log Workout |
| Identifier | `recoveryStatusDetailSheet_emptyState_coldStart` |

### Footer Buttons (See Info / Configure Settings)

Reuses the Phase 8.8 detail-sheet footer pattern: two side-by-side outlined buttons.

| Button | Action | Identifier |
|---|---|---|
| `See Info` | Opens Recovery Status See Info Modal | `recoveryStatusDetailSheet_seeInfoButton` |
| `Configure Settings` | Opens Recovery Status Settings Modal | `recoveryStatusDetailSheet_configureSettingsButton` |

---

## Linked Recovery & Load (Phase 11)

Visual + content constants for the linked composite (`FortiFitLinkedRecoveryLoadComposite`) — the container that renders Recovery Status + Training Load as a single visual unit when adjacent and not manually unlinked.

### Shared Border Treatment

| Property | Value |
|---|---|
| Border color | Primary Accent Blue `#3b82f6` (replaces each card's default Border `#404040`) |
| Border width | 1px |
| Corner radius | Standard card corner radius |
| Per-card padding between RS and TL | **Zero** (cards render edge-to-edge inside the composite) |
| Internal divider | None — the absence of inter-card padding IS the divider |
| Tap target | Single composite tap target for long-press / tease; individual cards still route their own taps to their own detail sheet behavior (both open the **same** combined detail sheet). |

When unlinked (including manually unlinked), each widget renders independently with its own card border + standard padding. The composite container is conditional on `HomeWidgetService.isLinkedActive(widgets:settings:)`.

### Gradient Backdrop

Subtle blue gradient that spans the full composite, used to give the linked pair its own visual identity vs. the surrounding flat-surface widgets. Mirrors the `FortiFitChartCard` single-color gradient pattern (CONSTANTS § Trends Chart Visual Tokens → Gradient Treatment) at a lower opacity so it reads as a hint, not a treatment.

| Property | Value |
|---|---|
| Type | `LinearGradient`, top → bottom |
| Color | Primary Accent Blue `#3b82f6` |
| Top stop opacity | **0.12** (vs. 0.2 used by Trends Chart Cards — intentionally lower for subtlety) |
| Bottom stop opacity | 0.0 |
| Base fill | `FortiFitColors.cardSurface` (`#1a1a1a`) — the gradient renders in a `ZStack` over this surface, both clipped to the composite corner radius |
| Child card fill | Both child cards (Recovery Status + Training Load) pass `fillColor: .clear` to `FortiFitCard` so the composite's gradient shows through both halves. The default `FortiFitCard.fillColor` remains `cardSurface` — only the embedded path opts out. |
| Owner | `FortiFitLinkedRecoveryLoadComposite` — the gradient is part of the composite container, never the child widgets. |
| Unlinked state | When `isLinkedActive == false`, each child reverts to `fillColor: cardSurface` so individual cards regain their opaque surfaces. |

### `FortiFitCard.fillColor` parameter

Added alongside Phase 11's Linked composite to let embedded cards opt out of their own surface fill so a parent container (e.g. the linked composite) can paint a single shared background.

| Property | Value |
|---|---|
| Type | `Color` |
| Default | `FortiFitColors.cardSurface` |
| Embedded usage | `.clear` — used by both child widgets when rendered inside `FortiFitLinkedRecoveryLoadComposite` (`isEmbedded: true` path) |
| Non-embedded usage | Default (`cardSurface`) — preserves the original look for every other caller |

### Animation Timing

| Transition | Duration | Curve |
|---|---|---|
| Border swap on link/unlink | 0.2s | Ease |
| Padding collapse/expand between cards | 0.2s | Ease |
| Score number tween on linking state change | 0.4s | Ease (matches PRD § 2 progress-bar standard) |
| Gradient bar fill on score recompute | 0.4s | Parallel to score tween |
| Drag preview opacity in Widget Edit Mode (composite as one unit) | 30% | (matches existing widget drag preview) |

Reduce Motion: snap (no tweens).

### No Bridge / No LINKED Chip

Confirmed against the locked spec: there is **no** bridge bar between the cards, **no** LINKED micro-chip, **no** inner-edge glow pulse, **no** shared header strip. Border swap + zero padding are the only visual signals of linking.

### Dual Hero Spec (composite layout reference)

Both cards retain their existing hero blocks.

- The `moon.zzz` watermark on the RS card is **suppressed in the linked variant** — the composite leans on the shared blue border + Sleep Impact Chip as the linking signals, and removing the watermark keeps the dual-hero block visually cleaner. The watermark returns the moment the pair auto-unlinks or is manually unlinked (`isEmbedded == false`).

### Sleep Impact Chip (on Training Load widget when linked)

| Property | Value |
|---|---|
| Position | Beneath the existing zone advisory copy on the TL widget body |
| Format | `{arrow} {signed integer} from sleep` (e.g., `↑ +3 from sleep`) |
| Computation | `currentLinkedScore − whatBaselineWouldBe` (rounded integer); algorithm in SERVICES.md § Training Load Algorithm → Sleep-Adjusted Decay |
| Up-arrow `↑` | Positive delta (more retained stress — sleep-adjusted decay slowed) |
| Down-arrow `↓` | Negative delta (less stress) — rare since linked algorithm only slows decay |
| Em-dash `—` | Zero delta (sleep met target) |
| Color | Alert Red `#ef4444` when positive (more stress = warning), Positive Green `#10b981` when negative, Muted Text `#737373` when zero |
| Visibility | Only when linked AND sleep data available for last night |
| Hidden | When linked but missing last-night sleep data (silent baseline fallback) |
| Identifier | `homeWidget_trainingLoad_sleepImpactChip` |

### SF Symbols

| Symbol | Usage |
|---|---|
| `rectangle.on.rectangle.slash` | "Unlink Widgets" item in the combined long-press context menu (see SCREENS.md § Home Screen → Widget Context Menu). |

### Composite Identifier

| Identifier | Element |
|---|---|
| `homeWidget_linkedRecoveryLoad_composite` | The composite container itself |

---

## Linked Recovery & Load Settings Modal (Phase 11)

Visual + content constants for the combined Configure Settings modal (SCREENS.md § Linked Recovery & Load Settings Modal). Reuses Settings Modal Done Button (Phase 8.8) treatment.

### Heading

`Configure Recovery & Load`

### Slider Order

Three slider cards, top-to-bottom. Preserves existing TL settings modal order (Experience → Duration), appends Sleep Target as the new addition.

| # | Card | Range | Increment | Default | UserSettings field | Identifier |
|---|---|---|---|---|---|---|
| 1 | Training Experience | Beginner / Intermediate / Advanced (3-position) | — | Beginner (0) | `experienceLevel` | `linkedRecoveryLoadSettings_experienceLevelSlider` |
| 2 | Target Workout Duration | 0–300 min | (existing TL spec) | 52 min | `targetMinutesPerWorkout` | `linkedRecoveryLoadSettings_targetWorkoutDurationSlider` |
| 3 | Sleep Target | 4–12 hrs | 0.5 hrs | 7.0 hrs | `targetSleepHours` | `linkedRecoveryLoadSettings_targetSleepHoursSlider` |

### Import from Apple Health Button

Single import button — **scope limited to Sleep Target only** (the other two sliders have no Apple Health equivalent). Same behavior as the unlinked Recovery Status Settings Modal's Import button.

| Property | Value |
|---|---|
| Label | `Import from Apple Health` |
| Style | `FortiFitButton(..., style: .primary)` — full-width filled Primary Accent Blue button. Matches Activity Rings Settings Modal Import button + unlinked Recovery Status Settings Modal Import button. |
| Position | Beneath the Sleep Target slider card (matches unlinked modal placement convention) |
| Action | `RecoveryStatusService.importSleepGoalFromAppleHealth()` |
| Disabled state | When HK not connected: `.opacity(0.4)` + `.disabled(true)`, with the same `"Connect Apple Health to import your goal."` caption below |
| Identifier | `linkedRecoveryLoadSettings_importButton` |

### Done Button + Close Button

| Button | Identifier |
|---|---|
| Done (outlined, full width) | `linkedRecoveryLoadSettings_doneButton` |
| Close (`xmark`, top-trailing) | `linkedRecoveryLoadSettings_closeButton` |

### Modal Identifier

`linkedRecoveryLoadSettings_modal`

---

## Linked Recovery & Load Detail Sheet (Phase 11)

Visual + content constants for the combined Detail Sheet (SCREENS.md § Linked Recovery & Load Detail Sheet). Reuses Widget Detail Sheet Visual Tokens (Phase 8.8) for sheet presentation, header, body block spacing, footer button block.

### Sheet Title

`Recovery & Load Insights`

### Dual Hero Block

Two hero columns side-by-side at the top.

| Column | Label | Value | Subtext |
|---|---|---|---|
| Left | `SLEEP` (Primary Accent Blue 11/700) | `{h}h {mm}m` (Primary Text 48/900) | `{pct}% DEEP · {h}h {mm}m` (Muted 11/700) |
| Right | `TRAINING LOAD` (Primary Accent Blue 11/700) | `{score}/100` (Primary Text 48/900) | `Adjusted for sleep` (Muted 11/700) |

| Identifier (block) | Element |
|---|---|
| `linkedRecoveryLoadDetailSheet_dualHero` | Container |
| `linkedRecoveryLoadDetailSheet_recoveryHero` | Left column |
| `linkedRecoveryLoadDetailSheet_loadHero` | Right column |

### Combined Sleep & Load Chart (Dual Axis, 14-Day)

Single Swift Charts view overlaying sleep duration and sleep-adjusted Training Load on a shared 14-day x-axis. Both lines share the chart's 0–100 y-domain; sleep hours are normalized into that space for plotting and the trailing axis labels render the un-normalized hour values so the right-axis reads naturally in hours.

| Property | Value |
|---|---|
| Window | Last 14 days |
| Title | `Last 14 Days · Sleep & Load` |
| Inline legend (beneath title) | `● SLEEP` (Chart Purple dot) + `● LOAD` (latest zone color dot) — 11/700 Muted Text uppercase, 1.5 kerning |
| Sleep line | Chart Purple `#4B2893`, `.catmullRom`, 2pt stroke. Points: latest = Primary Accent Blue, others = Chart Purple. Data source: `DailySleepSnapshot`. |
| Load line | Latest-score zone color (per § Training Load Zones), `.catmullRom`, 2pt stroke. Points: per-day zone color. Data source: `DailyTrainingLoadSnapshot` with live fallback for days lacking a persisted snapshot (see SERVICES.md § Training Load Algorithm → `fourteenDayDailyScores`). |
| Left axis (Load) | Position `.leading`, domain `0...100`, ticks `[30, 55, 80]`, label color = latest zone color, dashed grid lines (`StrokeStyle(lineWidth: 0.5, dash: [3, 3])`, Border color). |
| Right axis (Sleep) | Position `.trailing`, label color Chart Purple, **no** grid lines. Tick values from `DailySleepSnapshot.sparklineAxisValues(for:)` rendered as `{h}h` (denormalized from the shared 0–100 domain). |
| Scrubbing | Single tap or drag selects the nearest calendar day across either dataset (set-union of load + sleep dates, snapped to start-of-day). One neutral `RuleMark` (Muted Text @ 0.6) renders at the selected day. Selected points scale to 96 symbol size; un-selected points dim to 0.35 opacity; both lines dim to 0.55 opacity when any day is selected. Light haptic on cross-day transition. |
| Combined annotation | Single row beneath the chart: `{sleepDuration}` (Chart Purple) · `{score} / 100` (zone color) · `{zone}` (Primary Text) · trailing `{date}` (Muted Text). Renders `— h —m` or `— / 100` for whichever side is missing on the selected day so a missed sleep night doesn't hide the load read (and vice versa). |
| Chart height | 140 pt |
| Identifier (chart) | `linkedRecoveryLoadDetailSheet_combinedChart` |
| Identifier (load points) | `linkedRecoveryLoadDetailSheet_loadChartDataPoint_{index}` |
| Identifier (sleep points) | `linkedRecoveryLoadDetailSheet_sleepChartDataPoint_{index}` |
| Identifier (annotation) | `linkedRecoveryLoadDetailSheet_combinedSelectionAnnotation` |

### Window Comparison Band

Two-line band + trailing caption, all inside a single `FortiFitCard` below the combined chart. No card title — the two rows (`Training Load` and `Sleep`) act as the card's visible identity at all collapse states; only the caption hides behind the chevron (see SCREENS.md § Linked Recovery & Load Detail Sheet → Collapsible insight cards).

| Line | Format |
|---|---|
| Training Load | `TRAINING LOAD · {↑/↓} {pct}%` (uppercase Muted label + Primary Text value). The trailing "vs last week" is intentionally omitted — the grey caption beneath the rows already names the matched windows. When the matched window is fewer than 2 days (i.e. early Monday before any data has accrued), the value renders as `Not enough data` in Muted Text. |
| Sleep | `SLEEP · {↑/↓} {pct}%`. Same `Not enough data` treatment as Training Load when the matched window is fewer than 2 days. |
| Caption (below both rows) | `This week so far ({Mon, MMM d} – today) vs same period last week ({Mon, MMM d} – {matched weekday, MMM d})` — 11pt italic Muted Text, ID `linkedRecoveryLoadDetailSheet_windowComparisonCaption`. Names the day-of-week-matched windows (BUG-065, BUG-066). |

Arrow colors: Alert Red for higher training load / lower sleep, Positive Green for the inverse. Computation: **day-of-week matched windows** — both rows compare Mon-through-current-weekday of this ISO week vs Mon-through-the-same-weekday of the prior ISO week. On Monday the window is a single day (and the row collapses to `Not enough data`); on Sunday it is the full Mon–Sun week. Training Load is a sum of raw `sessionStress` over the matched window (no time decay; see SERVICES.md § Training Load Algorithm → `weekOverWeekComparison`). Sleep is the mean of `totalSleepMinutes` over nights *present* in each matched window (missing nights are skipped, not zero-filled; see SERVICES.md § RecoveryStatusService → `sleepWeekOverWeekComparison`). Both windows are aligned so a single caption describes both rows.

Identifier: `linkedRecoveryLoadDetailSheet_windowComparison`

### Last 3 Nights Row

Three-cell row below the window comparison band. Each cell: `{Day}, {Month} {Date} · {h}h {mm}m · {pct}% deep`.

Identifier: `linkedRecoveryLoadDetailSheet_last3Nights`

### Time Since Workout Block

Same structure as unlinked detail sheet (see Recovery Status Detail Sheet § Time Since Last Workout Block). Identifier: `linkedRecoveryLoadDetailSheet_timeSinceWorkout`

### Contributing Workouts Block

Reuses the Phase 8.8 Training Load Detail Sheet contributing-workouts pattern. Lists the workouts inside the 10-day decay window. Identifier: `linkedRecoveryLoadDetailSheet_contributingWorkouts`

### Recovery Readiness Callout

The joint Recovery & Load advisory string returned by `RecoveryStatusService.computeLinkedAdvisory(...)` — see § Training Load Zones → Linked Advisory Copy. When sleep data for last night is missing or sleep met target, the base TL zone advisory (per § Training Load Zones → Advisory Text — Standalone Training Load Widget) renders unchanged.

Identifier: `linkedRecoveryLoadDetailSheet_recoveryCallout`

### Footer Buttons

Reuses the Phase 8.8 detail-sheet footer pattern.

| Button | Action | Identifier |
|---|---|---|
| `See Info` | Opens Linked Recovery & Load See Info Modal | `linkedRecoveryLoadDetailSheet_seeInfoButton` |
| `Configure Settings` | Opens Linked Recovery & Load Settings Modal | `linkedRecoveryLoadDetailSheet_configureSettingsButton` |

### Collapsible Insight Cards

Four secondary body blocks on the Linked Recovery & Load Detail Sheet expose a bottom-aligned chevron toggle that hides their content. Matches the Goals card chevron pattern: `Image(systemName: isExpanded ? "chevron.up" : "chevron.down")`, `.font(.system(size: 12, weight: .semibold))`, `FortiFitColors.mutedText`, full-width plain `Button` with `.frame(height: 24)` and `.contentShape(Rectangle())`, animated with `withAnimation(.easeInOut(duration: 0.1))`. The card title row stays visible when collapsed; everything below it hides. The Window Comparison card uses the static title `Training Load & Sleep` (added so the collapsed state has a label).

State persists per-card via `UserSettings` UserDefaults flags (registered defaults all `false` → collapsed on first launch and after install).

| Card | UserDefaults key | Default | Chevron accessibility identifier |
|---|---|---|---|
| Window comparison (Training Load & Sleep) | `recoverySheetStressLoadExpanded` | `false` | `linkedRecoveryLoadDetailSheet_windowComparison_chevron` |
| Last 3 Nights | `recoverySheetLast3NightsExpanded` | `false` | `linkedRecoveryLoadDetailSheet_last3Nights_chevron` |
| Contributing This Week | `recoverySheetContributingExpanded` | `false` | `linkedRecoveryLoadDetailSheet_contributingWorkouts_chevron` |
| Time Since Last Workout | `recoverySheetTimeSinceWorkoutExpanded` | `false` | `linkedRecoveryLoadDetailSheet_timeSinceWorkout_chevron` |

### Sheet Identifier

`linkedRecoveryLoadDetailSheet_sheet`
