# IMPLEMENTATION_PLAN_PHASE_6_2.md: Phase 6.2 — Trends Chart Detail View

> Hand-off plan for executing Phase 6.2. Specs will be written into the canonical docs (CONSTANTS.md, SCREENS.md, SERVICES.md, CLAUDE.md, TESTING.md, PRD.md) before code begins. This document is the execution playbook. Read the spec sections first; this file only sequences and translates them into code + test work.
>
> Phase 6.1 (`IMPLEMENTATION_PLAN.md`) ships first. This phase assumes `FortiFitChartCard`, `TrendsChartService.headerSummary(for:exerciseName:)`, the gradient + hairline + summary tokens, and the Phase 6.1 accessibility identifiers are all in place.

---

## Goal

Give every Trends-screen chart a per-chart expanded view that pushes onto the navigation stack from the compact card. The detail view uses the same `FortiFitChartCard` visual language (gradient, hairline, header summary, latest-point highlight, smoothed line, rounded bars, donut center label) at a larger size, plus:

- Wider time-range toggles (D / W / M / 6M / 1Y / All Time as appropriate per chart).
- Comparison delta in the header summary (current period vs. prior period).
- Tap-to-select on every data point, plus drag-to-scrub on line charts. Selection state lives only on this surface — the compact card stays read-only.
- A `See Info` entry point inline on the detail view (so users can read the chart's explainer without going back to the long-press menu).
- Swipe left/right to page between the user's other Trends charts in `sortOrder`.
- Personal Records detail view structurally upgrades to a full PR timeline (line chart of every PR event over time for the selected exercise).
- Workout Type Breakdown detail view adds segment percentages and a sortable legend table.
- Y-axis labels show full numerics on the detail view (`5,000 lbs`) instead of compact-card abbreviations (`5K`).
- Empty state mirrors the compact card.

This phase also formalizes a small cross-app convention: the back-navigation control on every drill-down screen is a **left-pointing chevron button** (`chevron.left` SF Symbol), not the old "← BACK" text button referenced in PRD.md § Interaction Style. PRD.md gets updated as part of this phase to reflect what's actually shipping.

## Required Reading (in order)

1. `CLAUDE.md` — workflow rules, the new Phase 6.2 row, Session Hygiene checklist.
2. `PRD.md` § 2 (Design Language), § 3 (Technical Foundation), § Interaction Style (updated by this phase — back chevron is now the convention).
3. `CONSTANTS.md` § Colors, § Chart Types, § Workout Type Chart Colors, § Trends Chart Visual Tokens (Phase 6.1), **§ Trends Chart Detail View** (the new section — primary reference for this phase).
4. `SCREENS.md` § Standard Patterns (esp. **Back Navigation Chevron** and **Trends Chart Card Visual Treatment**), § Trends, **§ Trends Chart Detail** (new).
5. `SERVICES.md` § Workout Cascade, § TrendsChartService → Header Summary Computation, **§ TrendsChartService → Comparison Delta Computation**, **§ TrendsChartService → PR Timeline Fetch**, **§ TrendsChartService → Type Breakdown Percentages**.
6. `TESTING.md` — full doc; particularly § Test Types, § Naming Conventions, § Accessibility Identifiers.

Specs win over this plan. If anything below contradicts a spec, follow the spec and update this file.

---

## Execution Order

### Step 1 — Cross-app convention update (PRD.md + Standard Patterns)

1. **`PRD.md` § Interaction Style → Navigation:** replace the `← BACK` text-button reference with a left-pointing chevron button (`chevron.left` SF Symbol, Primary Accent Blue, 24×24pt circular tap target). The chevron is the new convention for every drill-down screen, not just the chart detail.
2. **`SCREENS.md` § Standard Patterns:** add a new pattern named `Back Navigation Chevron` describing the placement (top-leading, inset under Scroll Fade Header), tap behavior (pop one level on the navigation stack), accessibility identifier convention (`{screenId}_backButton`), and VoiceOver label ("Back, button"). Reference this pattern from any existing screen sections that previously cited "← BACK" — search SCREENS.md for `← BACK` and update each reference to the new pattern.

These edits are cheap but non-trivial — they touch every drill-down surface (Workout Detail, Add Goal, Schedule Workout, Saved Templates, etc.). Confirm via Grep that no `← BACK` text-button literal remains anywhere in the doc set.

### Step 2 — Theme & Constants

1. **`App/AppConstants.swift`** — extend the existing `Trends` enum (added in Phase 6.1) with new caption strings for the comparison delta block, expanded range toggles, and selection-callout templates. New types:
   - `enum TimeRange { case d, w, m, sixM, oneY, all }` plus per-chart eligibility helpers.
   - `struct ChartDelta { let hero: String; let caption: String; let delta: String?; let direction: DeltaDirection }` — extends `ChartSummary` with a comparison band.
   - `enum DeltaDirection { case up, down, flat }` — drives the arrow icon and color (Positive Green / Alert Red / Muted Text).
2. **`Design/Theme/`** — no new color tokens. The detail view inherits every visual token from the compact card.

### Step 3 — Service work

**`Core/Services/TrendsChartService.swift`** — add the following per SERVICES.md § TrendsChartService:

- `func comparisonDelta(for chartType: ChartType, exerciseName: String?, range: TimeRange) -> ChartDelta?` — returns the same `hero` + `caption` produced by `headerSummary(for:)` for the *current* range, plus a `delta` string and direction comparing it to the immediately prior period of the same length. `nil` when below the chart's data threshold (no change from existing thresholds in CONSTANTS.md § Chart Data Thresholds).
- `func dataPoints(for chartType: ChartType, exerciseName: String?, range: TimeRange) -> [ChartDataPoint]` — generic data backing for the expanded chart at any supported range. Each point carries `(x: Date, y: Double, label: String)`. Identical to the existing chart view fetches but parameterized over `TimeRange` instead of fixed 30D/60D/90D.
- `func fullPRTimeline(for exerciseName: String) -> [PRTimelineEvent]` — every PR event for the named exercise, chronologically. `PRTimelineEvent` has `(date, weightKg, deltaKg)`. Empty array → empty state. Used only by Personal Records detail view.
- `func breakdownPercentages(range: TimeRange) -> [WorkoutTypeBreakdownRow]` — same data feeding the donut, plus per-row percentages and avg duration. Used only by Workout Type Breakdown detail view.

No persistent cache. The detail view recomputes on observation just like the compact card.

### Step 4 — Components

1. **`Design/Components/FortiFitChartCard.swift`** (existing, from Phase 6.1) — extend the public API with `onExpand: (() -> Void)?`. When non-nil, render a left-chevron expand button at the top-trailing of the card. Tap → invoke `onExpand`. The button uses the same chevron treatment as Workout Detail's `FortiFitStatCard` (see Phase 8.5). Identifier `trendsChart_{chartId}_expandButton`.
2. **`Design/Components/FortiFitChartDetailView.swift`** — new file. Generic over chart content. Pushed onto the navigation stack from the Trends screen. Wraps a vertically expanded variant of `FortiFitChartCard` (~60% of viewport height instead of compact card's ~280pt) plus the comparison delta block, range toggles, See Info button (top-trailing), and a horizontal `TabView` (page style) that swipes between every active chart for the user. Passes the user's `TrendsChart.sortOrder` as the page index source.
3. **`Design/Components/FortiFitChartScrubber.swift`** — new file. Encapsulates the scrub-gesture overlay used by line-chart detail views. Wraps a `chartOverlay` + `DragGesture` and exposes a binding for the current scrub x-value. Snaps to discrete data points on the bar variant.
4. **`Design/Components/FortiFitBackChevron.swift`** — new file (or reuse if already factored). Implements the cross-app back chevron per Step 1. Used by every drill-down screen, not just chart detail.

### Step 5 — Per-chart detail views

Build one detail view per `ChartType` under `Features/Progress/Detail/` (or matching the existing folder layout — confirm via Grep). Each detail view:

1. Wraps in `FortiFitChartCard` with the larger sizing variant.
2. Sources data from `TrendsChartService.dataPoints(...)` at the active `TimeRange`.
3. Renders the expanded range toggles per CONSTANTS.md § Trends Chart Detail View (Range Toggle by Chart Type table).
4. Composes `FortiFitChartScrubber` for line charts; for bar charts uses `chartXSelection` for tap-to-select with snap.
5. Renders the floating selection annotation per CONSTANTS.md § Trends Chart Detail View (Selection Callout).
6. Renders the comparison delta header summary block per § Header Summary (Detail Variant).
7. Renders Y-axis labels with full numerics (no `K`/`M` abbreviations).
8. Suppresses chart-specific affordances that don't apply at scale (e.g., the compact card's exercise dropdown is hoisted into the title row of the detail view).

**Per-chart structural deltas:**

- **Strength Tracker, Workout Volume, Training Frequency, Training Load Trend, Effort Trend, Session Duration:** straightforward larger version of the compact card with selection + scrubbing. No structural change.
- **Personal Records:** structural change. Replaces the 2-bar comparison with a line chart over `fullPRTimeline(for:)`. Each PR event is a labeled point (date + weight + delta). The compact card stays unchanged — the structural change lives only on detail.
- **Workout Type Breakdown:** structural change. Donut stays in the upper half; lower half adds a sortable legend table (column headers: Type, Count, %, Avg Duration). Sort taps cycle through count desc → count asc → alphabetical.

### Step 6 — Trends screen wiring

1. Each chart card on the Trends screen gets the expand-button affordance (via the new `onExpand` prop on `FortiFitChartCard`).
2. Tapping the expand button pushes the corresponding `*ChartDetailView` onto the navigation stack.
3. The push uses the standard right-to-left iOS navigation transition. Free with `NavigationStack`; do not use `fullScreenCover` (would lose the back-swipe gesture, accessibility cues, and standard transition).
4. While in detail, swipe left/right between charts in the user's `TrendsChart.sortOrder`. Wrap-around at the ends. The active chart's index is preserved when the user backs out and re-enters.

### Step 7 — Accessibility identifiers

**`Core/Utilities/AccessibilityIdentifiers.swift`** — add:

- `trendsChart_{chartId}_expandButton` — compact card's chevron.
- `trendsChartDetail_{chartId}_card` — detail view container.
- `trendsChartDetail_{chartId}_backButton` — left-chevron back control.
- `trendsChartDetail_{chartId}_headerSummary` — hero + delta block.
- `trendsChartDetail_{chartId}_seeInfoButton` — inline `info.circle` icon.
- `trendsChartDetail_{chartId}_rangeToggle_{value}` — e.g., `..._rangeToggle_30d`, `..._rangeToggle_1y`. Use the `TimeRange` raw value.
- `trendsChartDetail_{chartId}_dataPoint_{index}` — selection target.
- `trendsChartDetail_{chartId}_selectionAnnotation` — floating callout.
- `trendsChartDetail_personalRecords_timelinePoint_{index}` — PR-timeline-specific.
- `trendsChartDetail_workoutTypeBreakdown_legendRow_{index}` — donut legend rows.
- `trendsChartDetail_workoutTypeBreakdown_legendSortHeader_{column}` — `count`, `percent`, `type`, `avgDuration`.

Generate `chartId` strings from the existing `ChartType` raw values — never hand-typed.

---

## Tests

Pick targets per `TESTING.md` § Test Types. Use the `test_situation_expectedOutcome` naming pattern. Reuse `TestFixtures.swift` helpers; extend with new fixtures only where necessary.

### Unit tests — `FortiFitTests` / `TrendsChartDetailUnitTests.swift`

| Test name | Asserts |
|---|---|
| `test_comparisonDelta_belowThreshold_returnsNil` | Iterate every `ChartType`; seed below threshold → `nil`. |
| `test_comparisonDelta_strengthTracker_currentExceedsPrior_returnsUpDirection` | Seed prior period 200 lbs, current period 220 lbs; assert `delta == "+20 lbs"`, `direction == .up`. |
| `test_comparisonDelta_currentBelowPrior_returnsDownDirection` | Seed inverse; assert `direction == .down` and delta string is negative. |
| `test_comparisonDelta_noPriorPeriodData_returnsFlatDirectionAndNilDelta` | Seed only current-period data; assert `direction == .flat`, `delta == nil`. |
| `test_dataPoints_strengthTracker_30d_returnsPointsInRange` | Seed across a 90-day window; request 30D; assert returned points all fall inside the trailing 30 days, sorted by `date` ascending. |
| `test_dataPoints_oneYearRange_includesOlderPoints` | Same seed; request 1Y; assert older points reappear. |
| `test_dataPoints_excludesNilWeightForStrengthTracker` | Seed with nil-weight bodyweight workouts; assert excluded. |
| `test_fullPRTimeline_returnsEveryPREventChronologically` | Seed Bench Press at 135 / 155 / 185 / 205 (all PRs) plus a 175 (no PR — below 185); assert timeline `[135, 155, 185, 205]` with correct deltas. |
| `test_fullPRTimeline_excludesBaseline` | Seed only one workout; assert empty array (baseline alone is not a PR). |
| `test_fullPRTimeline_emptyExercise_returnsEmptyArray` | Unseeded exercise name; assert empty. |
| `test_breakdownPercentages_30dRange_returnsCountAndPercentPerType` | Seed 10 workouts (5 Strength, 3 HIIT, 2 Cardio); assert rows sum to 10 and percentages sum to 100. |
| `test_breakdownPercentages_avgDurationExcludesNilDuration` | Seed mixed durations; assert avg ignores nil-duration workouts. |
| `test_timeRangeEligibility_perChartType` | Iterate `ChartType`; assert eligible `TimeRange` set matches CONSTANTS.md § Trends Chart Detail View → Range Toggle by Chart Type. |

### Integration tests — `FortiFitIntegrationTests` / `TrendsChartDetailIntegrationTests.swift`

| Test name | Asserts |
|---|---|
| `test_loggingWorkout_updatesComparisonDelta` | Existing 200 lbs current period; log a 220 lbs workout; assert `comparisonDelta(for: .strengthTracker, ...)` reflects updated delta. |
| `test_deletingPRWorkout_removesEventFromFullPRTimeline` | Seed 4-event PR timeline; delete the most recent; assert timeline shrinks to 3, deltas recompute. |
| `test_editingWorkoutDate_movesPointAcrossRangeBoundary` | Edit a Strength Tracker workout's date so it crosses the 30D / 60D boundary; assert `dataPoints(for:range:)` reflects the move at both ranges. |
| `test_workoutCascade_refreshesBreakdownPercentages` | Log a new workout; assert the breakdown row counts and percentages update. |
| `test_cosmeticEditOnly_doesNotChangeComparisonDelta` | Cosmetic edit only; assert deltas unchanged pre/post-edit. |

### UI smoke tests — `FortiFitUITests` / `SmokeTests.swift`

XCUI cannot reliably assert color or scrub-gesture motion — those belong to manual QA per `TESTING.md` § Color Treatment Tests. Smoke tests verify navigation, identifier presence, and discrete tap behavior only.

| Test name | Asserts |
|---|---|
| `test_trendsChart_expandButtonTap_pushesDetailView` | Launch with `--uitesting --reset-state`, seed minimum-threshold data, tap `trendsChart_strengthTracker_expandButton`, assert `trendsChartDetail_strengthTracker_card` exists. |
| `test_trendsChartDetail_backButtonTap_popsToTrendsScreen` | From within the detail view, tap `trendsChartDetail_strengthTracker_backButton`, assert tab content is the Trends list (the detail card identifier no longer hits). |
| `test_trendsChartDetail_dataPointTap_revealsSelectionAnnotation` | Tap `trendsChartDetail_trainingFrequency_dataPoint_3`, assert `trendsChartDetail_trainingFrequency_selectionAnnotation` becomes hittable. |
| `test_trendsChartDetail_rangeToggleChange_clearsSelection` | Select a data point; tap a different range toggle; assert the selection annotation no longer hits. |
| `test_trendsChartDetail_seeInfoButtonTap_opensSeeInfoModal` | Tap `trendsChartDetail_strengthTracker_seeInfoButton`; assert the standard See Info Modal close button (`seeInfoModal_closeButton`) is hittable. |
| `test_trendsChartDetail_swipeLeft_pagesToNextChart` | From `strengthTracker` detail, perform horizontal left-swipe; assert next chart's detail card identifier (per the user's `TrendsChart.sortOrder`) is hittable. |
| `test_trendsChartDetail_personalRecordsTimeline_rendersTimelinePoints` | After seeding a PR timeline, navigate to Personal Records detail; assert `trendsChartDetail_personalRecords_timelinePoint_0` exists. |
| `test_trendsChartDetail_workoutTypeBreakdown_legendRowsExist` | Navigate to Workout Type Breakdown detail; assert `trendsChartDetail_workoutTypeBreakdown_legendRow_0` exists for every type with non-zero count. |

Tab navigation uses the existing `Tab` enum string match (`TRENDS`) per `TESTING.md` § Tab bar gotcha — not an identifier.

### Manual QA (not automatable)

- Right-to-left push transition on expand button tap.
- Back chevron pops back to Trends; iOS swipe-back gesture also works.
- Detail view chart visually matches the compact card's gradient + hairline + bar/line styling, just larger.
- Y-axis renders full numerics (no `K`/`M` abbreviation).
- Tap a bar/dot → selection annotation appears above the mark, auto-flips below when within 24pt of the chart top edge.
- Drag along a line chart → vertical scrubber line follows the finger; annotation updates continuously; light haptic fires on each new snapped point.
- Drag-release on a line chart leaves the last-touched value selected (don't auto-deselect on lift).
- Range toggle change deselects.
- Swipe left/right pages between charts in the user's `sortOrder`; wraps at both ends.
- See Info button opens the standard See Info Modal.
- Personal Records detail timeline renders one labeled point per PR event with date + weight + delta.
- Workout Type Breakdown detail legend table sort cycles correctly.
- Empty state matches compact card (gradient/hairline/header-summary all hidden, centered muted message).
- Dynamic Type scales the header summary and selection callout reasonably without truncating.
- VoiceOver focus on push lands on the chart title; selection callout announces as a separate label.

---

## Session Hygiene Checklist (per CLAUDE.md)

Before declaring Phase 6.2 complete:

- [ ] All three test targets pass. Any intentionally failing tests are logged in `BUGS.md` as `Open — pending implementation`.
- [ ] Every new interactive element has an `.accessibilityIdentifier(...)` whose constant lives in `AccessibilityIdentifiers.swift`.
- [ ] Every spec edit lands in the canonical doc (CONSTANTS.md / SCREENS.md / SERVICES.md / CLAUDE.md / TESTING.md / PRD.md). Already done — do not re-edit unless implementation reveals a contradiction.
- [ ] Every `← BACK` literal in code (and screenshots, sample data, etc.) has been migrated to the left-chevron back button. Log results in `BUGS.md` if any non-trivial migrations surfaced.
- [ ] Any bug surfaced during implementation is logged to `BUGS.md` (resolved or open) with the standard fields.
- [ ] Manual QA items above are walked through on a real device, not just simulator.

---

## Out of Scope for This Phase

- Pinch-to-zoom on the detail chart (deferred — scrubbing covers the core "examine a specific point" need).
- Tap-through from a data point to the underlying workouts (deferred — useful but adds a navigation layer; revisit later).
- Animated entry on the detail view (push transition is enough; no custom fade/slide).
- Compact-card selection state — explicitly stays read-only on the Trends list. Selection only exists on the detail view.
- Apple-Watch-style force-touch / 3D-touch peek-and-pop on the compact card (out of scope for iOS 17+ baseline).
- Trends-screen integration of Activity Rings data (still parked per Phase 8.6 post-MVP note).
