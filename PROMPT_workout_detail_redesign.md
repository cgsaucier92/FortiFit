# Implementation Prompt — Workout Detail Summary Redesign + Source Indicator Polish

> Hand this file to Claude Code as the prompt for the change. Read the referenced spec sections before writing any code; the spec is authoritative. This is a multi-pronged change — read the full prompt before opening any file.

---

## Goal

Five coordinated changes centered on Workout Detail and the Apple Watch source treatment:

1. **Workout Detail Summary becomes a 2-column grid of bordered tappable stat cards.** Each card shows an SF symbol + sentence-case label on top with the value rendered larger below. Tapping a card opens a Metric Detail Sheet with comparative average, 30-day sparkline, and an optional Personal Best chip.
2. **Effort transforms from a number into a descriptive label** (Easy / Light / Moderate / Hard / All Out) on display surfaces. The integer is preserved for algorithms. Effort SF symbol swaps from `heart.gauge.open` to `chart.bar.fill`.
3. **Apple Watch source rename + indicator format change.** The source name "Apple Watch" becomes "Apple Workout" (other sources keep their names). The Workout Detail source indicator drops the word "from" and moves the glyph to the trailing position. Source name resolution gains a clean fallback (`another app`) so raw bundle IDs never reach the UI.
4. **The Apple Workout glyph is now Apple-Watch-source-only on peripheral surfaces.** It no longer appears for Strava/Peloton/etc. workouts on Home Recent, Workouts preview rows, or Plan cards. The glyph is also repositioned from "leading the workout name" to "trailing metadata on the date row."
5. **The Exercises header on Workout Detail is hidden** when `workout.exerciseSets.isEmpty`.

The Share Image Card is also updated to use the same 2-column stat-card grid (static, no tap behavior) so the export image mirrors the new Workout Detail layout.

---

## Spec Sections to Read First

Read these in order. Each one has been updated to reflect this change; treat them as the source of truth.

1. **SCREENS.md § Standard Patterns → Peripheral Apple Workout Glyph** — full rendering and scope rules (Apple-Watch-source-only).
2. **SCREENS.md § Workout Detail → Source Indicator** — new format (`{activityType} · {sourceName} [glyph]`), Apple Workout rename, sourceName resolution rules, glyph trailing position.
3. **SCREENS.md § Workout Detail → Source Indicator Info Sheet** — body copy fix (`This workout was imported from Apple Health via {sourceName}.`).
4. **SCREENS.md § Workout Detail → Summary** — full rewrite to 2-column stat-card grid. Field order, per-field display values, conditional rendering rules, conditional Exercises header.
5. **SCREENS.md § Workout Detail → Metric Detail Sheet** (new sub-section) — full spec for the tap-detail sheet (presentation, header, close button, hero / comparative / sparkline / PR chip blocks, empty states, accessibility).
6. **SCREENS.md § Workout Detail → Share Image Card** — now describes the stat-card grid layout instead of pills.
7. **SCREENS.md § Log Workout** — Effort dropdown format updated to `Label (Number)` per option.
8. **SCREENS.md § Home Screen / § Workouts / § Plan** — peripheral surfaces updated for glyph repositioning and Apple-Watch-only scope.
9. **SERVICES.md § WorkoutMetricService** (new section) — the read-only aggregate service powering the Metric Detail Sheet.
10. **SERVICES.md § HealthKitClient** — `sourceName(for:)` rule updated (Apple Watch → Apple Workout, never returns a raw bundle ID, fallback `another app`).
11. **CONSTANTS.md § Workout Detail Summary Icons** — Effort symbol swap (`heart.gauge.open` → `chart.bar.fill`).
12. **CONSTANTS.md § Effort Label Mapping** (new section) — full 1–10 to label table.
13. **CONSTANTS.md § Share Image Card Styling** — token table rewritten for stat-card grid.
14. **TESTING.md § Accessibility Identifiers** — new identifiers per stat card + shared `metricDetailSheet_closeButton`.
15. **PRD.md § Project Structure** — three new files listed.
16. **PRD.md § Navigation Flow / § Screen Summaries** — Workout Detail row updated; new Metric Detail Sheet entry.
17. **CLAUDE.md § Phase 8.5** (new) — phase-level summary with cross-references.

---

## What Changes in Code

### New components

- **`FortiFitStatCard.swift`** in `Design/Components/` — generic bordered stat card. Takes: SF symbol name, label string, value string (already formatted by the caller — view layer doesn't compute units), optional unit string for inline display, accessibility identifier, and a `onTap` closure. Renders per SCREENS.md § Workout Detail → Summary (top row icon+label+chevron; below row big value+optional inline unit). Tap state subtle 0.15s opacity dim.

- **`FortiFitMetricDetailSheet.swift`** in `Design/Components/` — the modal sheet opened by tapping any stat card. Takes: `Workout` and `WorkoutMetric` enum case (see SERVICES.md § WorkoutMetricService). Calls `WorkoutMetricService` for all aggregate data — never queries SwiftData directly. Renders the four blocks per SCREENS.md § Metric Detail Sheet: hero, comparative context, 30-day sparkline (Swift Charts `LineMark`), optional PR chip. Empty/insufficient-data states per the spec.

### New service

- **`WorkoutMetricService.swift`** in `Core/Services/` — three methods (`comparativeAverage`, `sparklineData`, `isPersonalBest`) plus the `WorkoutMetric` enum. Read-only. No mutations, no cascades. Implementation per SERVICES.md § WorkoutMetricService — including the PR-eligible-metrics restriction (only Distance, Active kcal, Total kcal, Elevation are eligible).

### Workout Detail screen rewrite

- Replace the existing Summary block (today: single-column or two-column rows of icon+label+value) with a `LazyVGrid` of `FortiFitStatCard` instances per SCREENS.md § Workout Detail → Summary. Field order is fixed per the spec. Each card renders only when its underlying value is non-nil.
- Wire each card's `onTap` to present `FortiFitMetricDetailSheet` via `.sheet(isPresented:)` with `.presentationDetents([.medium])` and `.presentationDragIndicator(.visible)`.
- Hide the Exercises section header **and** the empty list area entirely when `workout.exerciseSets.isEmpty` for Strength/HIIT workouts. (Other types already don't render this section — no change needed there.)
- Update the Source Indicator row to use the new format `{healthKitActivityType} · {sourceName} [glyph]` per SCREENS.md § Source Indicator. The glyph (`FortiFitHealthGlyph`) renders trailing **only when** source is Apple Watch.

### Effort label rendering

- Add a helper to `AppConstants` (e.g., `static func effortLabel(for: Int) → String`) using the table in CONSTANTS.md § Effort Label Mapping. Map 1–10 to Easy / Light / Moderate / Hard / All Out via the five-band scheme.
- **Workout Detail stat card:** value renders the descriptive label only (no integer shown).
- **Metric Detail Sheet hero block (Effort case):** label at hero size + `(N)` integer in smaller muted text below.
- **Log Workout dropdown:** each option label is `[Label] ([Number])` (e.g., `Easy (1)`, `Hard (7)`). Underlying integer stored on `workout.rpe`.
- **Match Prompt Sheet — FortiFit-side card metadata:** if currently `Effort 7`, change to `Effort: Hard (7)`.
- **Share Image Card:** label only on the stat card (no integer).
- **Effort Trend chart (Trends):** unchanged. Y-axis stays numeric 1–10 per the spec — chart precision matters, weekly averages can be decimals.
- **Workouts tab Filter By → Effort range:** unchanged. Stays a 1–10 min/max stepper.

### Apple Watch → Apple Workout source name

- Update `DefaultHealthKitClient.sourceName(for:)` per SERVICES.md § HealthKitClient. Apple Watch bundle → `Apple Workout`. Other recognized sources → their `HKSource.name`. Unrecognized → `another app` (graceful fallback). **Never returns a raw bundle ID under any circumstance.**
- Update the function signature: was `(for bundleID: String) → String?`. Now: `(for bundleID: String) → String` (non-optional). Caller code that previously handled nil can drop that branch.
- Source Indicator Info Sheet body paragraph template: `This workout was imported from Apple Health via {sourceName}.` Apply the same resolver.

### Glyph repositioning + scoping

- `FortiFitHealthGlyph` already renders the running-figure-on-green visual — no visual change. **Add a render-time gate**: glyph only renders when `workout.healthKitUUID != nil` AND the resolved source name is `Apple Workout`. If the consumer of the glyph doesn't already have access to the source name, plumb it through (or add a helper on `Workout` like `var isAppleWatchSourced: Bool` that does the bundle-ID check).
- **Position change** on these three surfaces (per SCREENS.md):
  - Home → Recent Workouts list rows
  - Workouts tab → Expanded Workout Preview Rows
  - Plan tab → Logged-only and completed scheduled cards
  
  Move the glyph from its current "before workout name" position to **trailing metadata** on the date row, separated by ` · ` from the date. Format becomes `Apr 23, 2026 · [glyph]`. Duration and distance render on a separate third row below the date row. The glyph is always the last token on the date row.

### Share Image Card

- Replace the current pills layout in `WorkoutShareCardView.swift` with a 2-column grid mirroring `FortiFitStatCard` styling (same field order, same per-field display values), but without chevron, without tap behavior, sized appropriately for the 390pt-wide image. Token table per CONSTANTS.md § Share Image Card Styling.
- Effort renders as the descriptive label only (no integer).
- All other share-card content (header, workout name, exercises list, footer, `+X more exercises` truncation) unchanged.

### Constants

- Add `effortLabel(for:)` helper to `AppConstants` per CONSTANTS.md § Effort Label Mapping.
- Update Effort SF symbol entry: `chart.bar.fill` (was `heart.gauge.open`).

### Accessibility identifiers

Add to `AccessibilityIdentifiers.swift`:

```swift
static let workoutDetail_summaryCard_effort = "workoutDetail_summaryCard_effort"
static let workoutDetail_summaryCard_duration = "workoutDetail_summaryCard_duration"
static let workoutDetail_summaryCard_distance = "workoutDetail_summaryCard_distance"
static let workoutDetail_summaryCard_avgHR = "workoutDetail_summaryCard_avgHR"
static let workoutDetail_summaryCard_maxHR = "workoutDetail_summaryCard_maxHR"
static let workoutDetail_summaryCard_activeKcal = "workoutDetail_summaryCard_activeKcal"
static let workoutDetail_summaryCard_totalKcal = "workoutDetail_summaryCard_totalKcal"
static let workoutDetail_summaryCard_elevation = "workoutDetail_summaryCard_elevation"
static let workoutDetail_summaryCard_exerciseMinutes = "workoutDetail_summaryCard_exerciseMinutes"
static let metricDetailSheet_closeButton = "metricDetailSheet_closeButton"
```

The metric detail sheet's close button identifier is shared across all metric variants (the sheet itself is one component; the metric is configured via parameters, not a different identifier per case).

---

## Tests

Use the per-target framework rules in TESTING.md.

### `FortiFitTests` (unit, Swift Testing)

- `test_effortLabelMapping_returnsCorrectBandForEveryInteger` — assert all 10 mappings (1→Easy through 10→All Out).
- `test_workoutMetricService_comparativeAverage_excludesCurrentWorkout` — fixture: 5 logged Strength workouts with varying durations, plus the workout under test. Assert the returned average is the mean of the 5 others, not 6.
- `test_workoutMetricService_comparativeAverage_returnsNilWhenInsufficientData` — fewer than 3 same-type workouts with the metric set → nil.
- `test_workoutMetricService_isPersonalBest_falseForIneligibleMetrics` — assert `isPersonalBest(for: .effort, ...)` always returns false regardless of value. Same for `.avgHR`, `.maxHR`, `.duration`, `.exerciseMinutes`.
- `test_workoutMetricService_isPersonalBest_trueWhenWorkoutHoldsMaxValue` — fixture seeded with this workout having the max distance for Cardio → returns true.
- `test_sourceName_appleWatchBundle_returnsAppleWorkout` — mock the Apple Watch bundle ID input; assert `Apple Workout` returned.
- `test_sourceName_unrecognizedBundle_returnsAnotherApp` — random bundle ID → `another app`.

### `FortiFitIntegrationTests` (XCTest)

- Editing or deleting a workout flows through to the Metric Detail Sheet's queries on next open (the service queries SwiftData live, no invalidation needed). Sanity guard test only — pass an in-memory container, log a workout, open the sheet's hypothetical query, assert correct values.

### `FortiFitUITests` (smoke, XCTest)

- `test_workoutDetail_eachStatCard_opensCorrectMetricSheet` — log a workout with all metric values populated (HK fixture); navigate to Workout Detail; tap each stat card via its identifier; assert the sheet title matches the expected metric name (e.g., `Effort details` after tapping `workoutDetail_summaryCard_effort`); dismiss via `metricDetailSheet_closeButton`; repeat for each metric.
- `test_workoutDetail_effortRendersDescriptiveLabel_notInteger` — assert `Hard` (or whichever band the fixture's 7 maps to) appears on the Effort card; assert `7` does NOT appear on the card itself.
- `test_workoutDetail_exercisesHeaderHidden_whenNoExerciseSets` — log a Strength workout with no exercises; assert the "Exercises" header is not present.
- `test_workoutDetail_appleWatchSource_rendersAppleWorkoutLabel_withTrailingGlyph` — fixture: workout with Apple Watch bundle ID; assert source row contains `Apple Workout` and the glyph is present trailing.
- `test_workoutDetail_stravaSource_rendersStravaLabel_withoutGlyph` — fixture: Strava bundle ID; assert source row contains `Strava` and the glyph is **not** present.
- `test_workoutsTab_appleWatchWorkout_showsGlyphTrailing_inDateRow` — assert the glyph appears as the last token on the date row, not before the name.
- `test_workoutsTab_stravaWorkout_showsNoGlyph` — assert no glyph anywhere on the row.
- `test_logWorkout_effortDropdown_rendersLabelAndNumberFormat` — assert at least one option label matches `Hard (7)` exactly (or use `Easy (1)` as a stable lowest-band check).
- `test_sourceIndicatorInfoSheet_neverShowsRawBundleID` — fixture: a workout whose bundle ID would normally be unresolvable; assert the body prose shows `another app`, never the raw bundle string.

### Existing tests that may need adjusting

- Any UI test that previously asserted on the "Summary" rows being a single column or two-column row layout needs to be updated for the stat-card grid.
- Any test asserting on Effort being rendered as an integer (`Effort 7`) on Workout Detail or the Match Prompt Sheet must be updated to expect the label format.
- Tests for the share image card layout pills need to be updated for the stat-card grid.
- Tests that asserted on the Source Indicator row format (`from {source}`) need to be updated for the new format (no "from").
- Tests asserting the glyph's leading position before workout names should be deleted; the glyph no longer renders there.

---

## Out of Scope

- Algorithms unchanged. Training Load still consumes `workout.rpe` as integer 1–10.
- Cascades unchanged. No model modifications.
- HealthKit sync, matcher, link/unlink behavior — unchanged structurally; only the source name resolver gets the rename + clean-fallback rules.
- Settings § Apple Health section — unchanged. The system-level "Apple Health" brand stays intact; only the per-workout "Apple Watch" source name renames.
- Match Prompt Sheet's `FROM APPLE HEALTH` label — unchanged. System brand callout.
- Effort Trend chart on Trends — y-axis stays numeric.
- Workouts tab Filter By → Effort range — stepper stays numeric.
- Resting HR — out of scope; no field added in Summary.
- Indoor/Outdoor field — explicitly removed from Summary in this change.
- Goals, Plan day-to-day operations, Trends, all other screens — no changes beyond the glyph repositioning where applicable.

---

## Acceptance Criteria

- Workout Detail Summary renders as a 2-column grid of bordered stat cards. Each card has SF symbol + sentence-case label + chevron in top row; big value below.
- Tapping any stat card opens the Metric Detail Sheet at `.medium` detent. Sheet title is `[Metric] details`. Close (X in top-right) dismisses the sheet.
- Effort card displays only the descriptive label (no integer). Mapping per CONSTANTS.md § Effort Label Mapping.
- The Metric Detail Sheet's hero for Effort shows label + `(N)` integer below in muted small text.
- Comparative context line shows `Your typical [Workout Type] session — [value]` plus a delta line. When fewer than 3 same-type workouts have the metric set, both lines are replaced with `Not enough data yet — log a few more sessions.`
- 30-day sparkline renders with the current workout's data point highlighted. < 3 data points → `Not enough data yet` muted line.
- Personal Best chip appears only on PR-eligible metrics (Distance, Active kcal, Total kcal, Elevation) when this workout's value is the all-time max for the type.
- Apple Watch source workouts show source row as `{activityType} · Apple Workout [glyph]` on Workout Detail. No `from` word.
- Strava / Peloton / other sources show `{activityType} · {sourceName}` (no glyph). Source name is always a clean string — never a raw bundle ID.
- Source Indicator Info Sheet body reads `This workout was imported from Apple Health via {sourceName}.` `{sourceName}` resolves cleanly per the rules; `another app` shows for unresolvable cases.
- Apple Workout glyph appears trailing on the date row on Home Recent Workouts, Workouts preview rows, and Plan logged-only / completed-scheduled cards — **only** when the workout's source is Apple Watch.
- Strava / Peloton / other HK-sourced workouts on those peripheral surfaces look identical to manual workouts (no glyph).
- The "Exercises" header and list are hidden on Workout Detail when `workout.exerciseSets.isEmpty` — both for manual and HK-imported Strength/HIIT workouts. Header reappears once the user adds an exercise.
- Log Workout Effort dropdown shows `Label (Number)` per option.
- Share Image Card export uses the 2-column stat-card grid mirroring Workout Detail (no chevrons, no tap, otherwise the same layout). Effort renders as label only.
- All three test targets (`FortiFitTests`, `FortiFitIntegrationTests`, `FortiFitUITests`) pass green.

---

## Session Hygiene Reminder

Per CLAUDE.md § Session Hygiene: log any unexpected behavior or build failure to BUGS.md as you encounter it, and confirm before closing the session that every interactive element added in this change has an `.accessibilityIdentifier(...)` from `AccessibilityIdentifiers.swift` (no hardcoded strings, no hardcoded copy).
