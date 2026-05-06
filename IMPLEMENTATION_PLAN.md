# IMPLEMENTATION_PLAN.md: Phase 6.1 — Trends Chart Visual Polish

> Hand-off plan for executing Phase 6.1. Specs have already been written into the canonical docs (CONSTANTS.md, SCREENS.md, SERVICES.md, CLAUDE.md, TESTING.md). This document is the execution playbook. Read the spec sections first; this file only sequences and translates them into code + test work.

---

## Goal

Bring every Trends-screen chart card up to an Apple-Fitness-style level of polish: subtle background gradient color-matched to each chart's data, hero summary value above each plot, smoothed line interpolation, latest-point highlight on line charts, rounded bar tops, and donut center label on Workout Type Breakdown. No new chart types; no changes to existing chart definitions or data thresholds.

## Required Reading (in order)

1. `CLAUDE.md` — workflow rules, Phase 6.1 row, Session Hygiene checklist.
2. `PRD.md` § 2 (Design Language), § 3 (Technical Foundation), § Project Structure.
3. `CONSTANTS.md` § Colors, § Chart Types, § Workout Type Chart Colors, **§ Trends Chart Visual Tokens** (the new section — primary reference).
4. `SCREENS.md` § Standard Patterns (esp. **Trends Chart Card Visual Treatment**), § Trends.
5. `SERVICES.md` § Workout Cascade, **§ TrendsChartService → Header Summary Computation**.
6. `TESTING.md` — full doc; particularly § Test Types, § Naming Conventions, § Accessibility Identifiers, § Color Treatment Tests.

Specs win over this plan. If anything below contradicts a spec, follow the spec and update this file.

---

## Execution Order

### Step 1 — Theme & Constants

1. **`Design/Theme/Colors.swift`** — confirm `chartOrange` resolves to `#FFBF51` (the CONSTANTS.md update is already in). Search the codebase for any literal `#FFA600` or `0xFFA600` and migrate every reference to the `chartOrange` token. If none exists, log a one-line BUGS.md note: `chartOrange token added with value FFBF51, no prior literals to migrate`.
2. **`App/AppConstants.swift`** — add:
   - `enum ChartGradientAnchor { case single(Color); case horizontalSplit(leading: Color, trailing: Color) }`
   - `struct ChartSummary { let hero: String; let caption: String }`
   - `static func chartGradientAnchor(for: ChartType) -> ChartGradientAnchor` — table-driven from CONSTANTS.md § Trends Chart Visual Tokens → Gradient Anchor by Chart Type.
   - `enum Trends { static let captionLatest = "LATEST"; static let captionAvgPerSession = "AVG / SESSION"; ... }` — every caption string from the per-chart hero/caption table. Views read from these; never hardcode.

### Step 2 — Service work

**`Core/Services/TrendsChartService.swift`** — implement `headerSummary(for:exerciseName:)` per SERVICES.md § TrendsChartService → Header Summary Computation. One private method per chart id, all returning `ChartSummary?`. Each must short-circuit and return `nil` when below the threshold in CONSTANTS.md § Chart Data Thresholds — there is one canonical threshold spec; do not duplicate the rules here.

Unit conversion: respect `useLbs` for Strength Tracker, Personal Records, Workout Volume. Format helpers belong in `Core/Utilities/Extensions/` if not already present.

No persistent cache. The view recomputes via `headerSummary(for:)` on each render — SwiftData observation handles cascade-driven refreshes implicitly.

### Step 3 — Component work

**`Design/Components/FortiFitChartCard.swift`** — new file. Wraps `FortiFitCard`. Public API:

```swift
FortiFitChartCard(
    chartId: ChartType,
    title: String,
    summary: ChartSummary?,
    gradientAnchor: ChartGradientAnchor,
    @ViewBuilder controls: () -> ControlsView,
    @ViewBuilder chart: () -> ChartView,
    @ViewBuilder footer: () -> FooterView
)
```

Composes:
- Title row (existing chart title; preserves chart-specific affordances).
- Header summary block (hidden when `summary == nil` or when `chartId == .workoutTypeBreakdown` — that chart suppresses the header slot in favor of the donut center label).
- Controls slot.
- Plot area: gradient backdrop (`LinearGradient` per `gradientAnchor`) → inner hairline (1px Border `#404040`, 8pt corner radius) → injected chart content.
- Footer slot.
- Empty state: when `summary == nil`, hide gradient + hairline + injected chart content; render the chart's existing centered muted empty message.

### Step 4 — Per-chart view updates

Locate the eight chart views under `Features/Progress/` (or wherever they currently live — the codebase folder may be `Features/Trends/`; confirm with Grep). For each:

1. Wrap the existing chart body in `FortiFitChartCard`, plumbing the gradient anchor and header summary from `AppConstants.chartGradientAnchor(for:)` and `TrendsChartService.headerSummary(for:exerciseName:)`.
2. Apply `.interpolationMethod(.catmullRom)` to all `LineMark`s.
3. Replace `BarMark` body with `UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5)` for the bar shape.
4. Add the latest-point highlight overlay on line charts (Strength Tracker, Workout Volume, Training Load Trend rolling-average line).
5. For `WorkoutTypeBreakdownView`: render the donut center label (count + `WORKOUTS` caption) per CONSTANTS.md § Donut Center Label. Suppress the header summary slot.
6. Add accessibility identifiers per Step 5.

### Step 5 — Accessibility identifiers

**`Core/Utilities/AccessibilityIdentifiers.swift`** — add the new constants. Naming follows the patterns added to `TESTING.md`:

- `trendsChart_{chartId}_card` — the outer card (one per chart type).
- `trendsChart_{chartId}_headerSummary` — hero+caption block (skip on `workoutTypeBreakdown`).
- `trendsChart_workoutTypeBreakdown_centerLabel` — donut center text.

Generate `chartId` strings from the existing `ChartType` raw values — never hand-typed.

---

## Tests

Pick targets per `TESTING.md` § Test Types. Use the `test_situation_expectedOutcome` naming pattern. Reuse `TestFixtures.swift` helpers where they exist; extend with new fixtures only if necessary.

### Unit tests — `FortiFitTests` / `TrendsChartVisualUnitTests.swift`

Pure-function coverage. Swift Testing framework (the convention for this target). One file.

| Test name | Asserts |
|---|---|
| `test_chartOrangeToken_equalsFFBF51` | `FortiFitColors.chartOrange` resolves to `#FFBF51` (regression guard against accidental revert). |
| `test_chartGradientAnchor_singleColorCharts_returnDocumentedAnchor` | Iterate every `ChartType` whose anchor is single-color (Strength Tracker, Training Frequency, Training Load Trend, Workout Volume, Effort Trend, Workout Type Breakdown, Session Duration). Assert `.single(expectedColor)` for each. |
| `test_chartGradientAnchor_personalRecords_returnsHorizontalSplit` | `chartGradientAnchor(for: .personalRecords) == .horizontalSplit(leading: lightCyan, trailing: deepBlue)`. |
| `test_headerSummary_belowThreshold_returnsNil` | For each chart id, seed in-memory `ModelContainer` with data below the threshold in CONSTANTS.md § Chart Data Thresholds; assert `nil`. |
| `test_headerSummary_strengthTracker_returnsLatestWeightWithUnit_lbs` | Seed three logged sets (100, 150, 200 kg) for "Bench Press"; `useLbs = true`; assert hero `441 lbs` (200 × 2.205 rounded) and caption `LATEST`. |
| `test_headerSummary_strengthTracker_returnsLatestWeightWithUnit_kg` | Same seed; `useLbs = false`; assert hero `200 kg`. |
| `test_headerSummary_trainingFrequency_returnsAvgPerWeekOneDecimal` | Seed 8 weeks (3, 2, 4, 3, 3, 2, 5, 2 sessions); assert hero `3.0` (24 / 8) caption `AVG / LAST 8 WEEKS`. |
| `test_headerSummary_personalRecords_returnsDeltaWithUnit` | Seed Bench Press baseline 135 lbs, first PR 155 lbs; assert hero `+20 lbs` caption `LATEST PR`. |
| `test_headerSummary_personalRecords_multipleEvents_usesLatestTwo` | Seed three PRs at 135 / 155 / 185; assert hero `+30 lbs`. |
| `test_headerSummary_trainingLoadTrend_returnsTodaysScoreInteger` | Seed via stub returning 47.6; assert hero `48` caption `TODAY`. |
| `test_headerSummary_workoutVolume_formatsKSuffix` | Seed two Strength workouts each with sets totaling 4,500 lbs volume; assert hero `4.5K lbs` caption `AVG / SESSION`. |
| `test_headerSummary_rpeTrend_returnsAvgOneDecimal` | Seed 8 weeks of workouts with RPE values yielding mean 6.4; assert hero `6.4` caption `AVG / LAST 8 WEEKS`. |
| `test_headerSummary_rpeTrend_excludesNilRpe` | Seed mixed workouts (some with `rpe = nil`); assert nil-RPE workouts are excluded from the average. |
| `test_headerSummary_workoutTypeBreakdown_returnsTotalCount_30D` | Seed 12 workouts in last 30 days, 5 outside; with toggle = 30D, assert hero `12` caption `WORKOUTS`. (Even though the view places this in the donut center, the service produces the same `ChartSummary` value.) |
| `test_headerSummary_sessionDuration_excludesNilDuration` | Seed mixed workouts (some with `durationMinutes = nil`); assert nil-duration workouts are excluded. |
| `test_headerSummary_sessionDuration_returnsAvgMinutes` | Seed 8 weeks of durations averaging 36.4 min; assert hero `36 min` caption `AVG / SESSION`. |

### Integration tests — `FortiFitIntegrationTests` / `TrendsChartHeaderSummaryIntegrationTests.swift`

Cross-service cascade coverage. XCTest framework. Use `inMemoryContainer()` and existing fixtures; mirror the structure of `WorkoutCascadeIntegrationTests.swift` (find via Grep).

| Test name | Asserts |
|---|---|
| `test_loggingHeavierWorkout_updatesStrengthTrackerHeaderSummary` | Existing 200 kg log → log a 220 kg set → call `headerSummary(for: .strengthTracker, exerciseName: "Bench Press")` → hero updates to reflect 220 kg. |
| `test_deletingMostRecentPR_recomputesPersonalRecordsHeaderSummary` | Seed PR timeline 135/155/185; delete the 185 workout; assert hero falls back to `+20 lbs` (155 − 135). |
| `test_deletingAllPRs_returnsNilForPersonalRecordsHeaderSummary` | Delete every PR-bearing workout; assert `headerSummary(for: .personalRecords)` returns `nil`. |
| `test_workoutVolume_thresholdBoundary_appearsAtSecondQualifyingWorkout` | Log one Strength workout → assert `nil`; log a second → assert non-`nil` summary with formatted hero. |
| `test_workoutTypeBreakdown_thresholdBoundary_appearsAtSecondWorkout` | Log one workout → assert `nil`; log a second → assert summary returns total count `2`. |
| `test_editingWorkoutDate_acrossEightWeekBoundary_recomputesAffectedSummaries` | Edit a workout's date so it moves out of the 8-week window for `trainingFrequency` and `rpeTrend`; assert both summaries recompute (mean drops accordingly). |
| `test_cosmeticEditOnly_doesNotChangeNumericSummaries` | Edit a workout's name only; assert all chart header summaries return identical values pre/post-edit (cosmetic edits bump `lastModifiedDate` but don't alter computation inputs). |

### UI smoke tests — `FortiFitUITests` / `SmokeTests.swift`

XCUI cannot reliably assert color/gradient correctness — those belong to manual QA per `TESTING.md` § Color Treatment Tests. Smoke tests verify identifier presence only.

| Test name | Asserts |
|---|---|
| `test_trendsScreen_seededChartsRenderHeaderSummaryIdentifier` | Launch with `--uitesting --reset-state`, seed via UI a minimum-threshold dataset, navigate to TRENDS tab, assert each `trendsChart_{chartId}_headerSummary` exists for every default-seeded chart whose threshold is met. |
| `test_trendsScreen_workoutTypeBreakdown_centerLabelIdentifier` | After seeding ≥ 2 workouts, add the Workout Type Breakdown chart, assert `trendsChart_workoutTypeBreakdown_centerLabel` exists. |

Tab navigation uses the existing `Tab` enum string match (`TRENDS`) per `TESTING.md` § Tab bar gotcha — not an identifier.

### Manual QA (not automatable)

Add to the manual QA checklist for the next TestFlight build:

- Each chart's gradient renders at the documented opacity (~20% top → 0% bottom) and uses the correct anchor color.
- Personal Records gradient is a horizontal split (cyan left → dark blue right) layered with the vertical fade-to-transparent.
- Inner plot hairline is visible but subtle; corner radius is 8pt.
- Latest-point glow on line charts is visible but doesn't dominate the line.
- Bar top corners are clearly rounded; bar bottoms remain square.
- Donut center label is centered both axes inside the donut hole.
- Empty states: gradient/hairline/header summary all hidden; existing empty message is centered and readable.
- Dynamic Type: header summary scales reasonably without truncating the hero value.
- VoiceOver: header summary announces as `"{hero}, {caption}"` first, then the chart marks follow.

---

## Session Hygiene Checklist (per CLAUDE.md)

Before declaring Phase 6.1 complete:

- [ ] All three test targets pass. Any intentionally failing tests are logged in `BUGS.md` as `Open — pending implementation`.
- [ ] Every new interactive element has an `.accessibilityIdentifier(...)` whose constant lives in `AccessibilityIdentifiers.swift`.
- [ ] Every spec edit lands in the canonical doc (CONSTANTS.md / SCREENS.md / SERVICES.md / CLAUDE.md / TESTING.md). Already done — do not re-edit unless implementation reveals a contradiction.
- [ ] Any `#FFA600` literal still in code is migrated to the `chartOrange` token (or it's confirmed there were none — log result in `BUGS.md`).
- [ ] Any bug surfaced during implementation is logged to `BUGS.md` (resolved or open) with the standard fields (date, phase, description, root cause, resolution, status).
- [ ] Manual QA items above are walked through on a real device, not just simulator.

---

## Out of Scope for This Phase

- New chart types (any addition to the eight in `CONSTANTS.md` § Chart Types).
- Changes to chart data thresholds, default seed, add/delete/reorder behavior.
- Changes to See Info Modal copy (lives in `INFO_COPY.md`; unchanged).
- Trends-screen integration of Activity Rings data (parked per Phase 8.6 post-MVP note).
- Any HealthKit-related changes — none of these are HK-specific.
- Animated entry / staggered draw-in (deferred — could ship later if desired).
- Skeleton empty-state visualization (deferred — current centered muted message is retained).
- Muted gridline / axis-label restyling (deferred).
