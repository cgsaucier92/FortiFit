# Implementation Prompt — Workout Detail Stat Card Color Treatment

> Hand this file to Claude Code as the prompt for the change. Read the referenced spec sections before writing any code; the spec is authoritative. This is a polish iteration on top of Phase 8.5 (the Workout Detail Summary redesign) — assumes that work has already shipped or is in progress.

---

## Goal

Color-code each stat card on the Workout Detail Summary grid (and its corresponding Metric Detail Sheet) so each metric has its own visual identity. Five concrete changes:

1. **Stat card label color** changes from muted gray to Primary Text white. Applies to every card.
2. **Stat card icon color** changes from muted gray to a metric-specific color. The Effort icon (`chart.bar.fill`) uses three colors via SF Symbols palette rendering — green/yellow/red across its three bars. Every other icon uses one color.
3. **Stat card value color** changes from white to match the icon color. For Effort, the value color is dynamic — it maps from `workout.rpe` per CONSTANTS.md § Effort Color Mapping (1–4 green, 5–6 yellow, 7–10 red).
4. **Metric Detail Sheet** loses the redundant centered `[Metric] details` title (the hero block is the de facto title). Hero block adopts the same icon/label/value color treatment as the card. The 30-day sparkline is colored per metric (Effort uniquely uses per-segment color based on each data point's own effort band).
5. **Share Image Card** mirrors the on-screen stat-card color treatment 1:1 (static, no tap behavior, but identical icon/label/value colors).

The Match Prompt Sheet's `Effort: Hard (7)` metadata line stays plain muted text — color treatment does **not** apply there.

---

## Spec Sections to Read First

Read these in order. Each one has been updated to reflect this change; treat them as the source of truth.

1. **CONSTANTS.md § Stat Card Colors** (new section) — full per-metric icon/value/sparkline color table. The single source of truth for every color used by this feature.
2. **CONSTANTS.md § Effort Color Mapping** (new section) — 1–10 → green/yellow/red mapping for the dynamic Effort coloring. Includes a helper-function callout (`AppConstants.effortColor(for:)`).
3. **CONSTANTS.md § Workout Detail Summary Icons** — table cleaned up; cross-references the new Stat Card Colors section for color details.
4. **CONSTANTS.md § Workout Detail Health Data Icons** — same cleanup; references Stat Card Colors. Indoor/Outdoor explicitly removed (per Phase 8.5).
5. **SCREENS.md § Workout Detail → Summary** — stat card structure now specifies icon/label/value colors; chevron stays muted; unit text stays muted; Effort value color is dynamic.
6. **SCREENS.md § Workout Detail → Metric Detail Sheet** — header (`[Metric] details` title) removed; hero block adopts color treatment; sparkline colors per metric (Effort per-segment).
7. **SCREENS.md § Workout Detail → Share Image Card** — propagation rule explicit: same color treatment as on-screen card.
8. **TESTING.md § Color Treatment Tests** (new sub-section) — unit test scope for `effortColor(for:)`; manual-QA path for color application correctness.
9. **CLAUDE.md § Phase 8.5** — new line covering the color polish; cross-references the spec sections above.

---

## What Changes in Code

### Constants

- Add `effortColor(for: Int) → Color` helper to `AppConstants` per CONSTANTS.md § Effort Color Mapping. Mirrors the structure of the existing `effortLabel(for: Int)` helper.
- Add per-metric color constants (or a single `statCardColor(for: WorkoutMetric) → Color` helper) per CONSTANTS.md § Stat Card Colors. Reuse the existing color tokens defined in § Colors (Positive Green, Caution Yellow, Alert Red, Chart Purple, Chart Orange, Chart Teal) — no new tokens introduced.

### `FortiFitStatCard.swift`

Update the existing component (see PRD.md § Project Structure) to support the new color rules:

- **Label** is now `Primary Text` color (was Muted Text). Same size and weight.
- **Icon** takes a `Color` (or for Effort, a tuple of three colors via palette rendering). Single-color icons render normally; the Effort icon uses `.symbolRenderingMode(.palette).foregroundStyle(green, yellow, red)` — verify the bar order on first build (short → medium → tall expected).
- **Value** takes a `Color`. For non-Effort cards, this is the same color as the icon. For Effort, this is the band color from `AppConstants.effortColor(for: rpe)`.
- **Unit text** (the inline `bpm`, `kcal`, `min` after numeric values) stays Muted Secondary Text regardless of value color.
- **Chevron** stays Muted Text.
- **Card border** stays `#404040` (subtle, lets the colors pop).

The Workout Detail view's `WorkoutSummaryGrid` (or wherever the cards are constructed) provides the right colors per card by calling `AppConstants.statCardColor(for:)` (or equivalent) and, for Effort, `AppConstants.effortColor(for: workout.rpe ?? 0)`.

### `FortiFitMetricDetailSheet.swift`

- **Remove the centered `[Metric] details` title.** The sheet's top chrome is now: drag indicator + close X (top-right) + body (starting with the hero block). No centered title.
- **Hero block:**
  - Icon: same color treatment as on the card (single-color or palette).
  - Label: Primary Text white (was muted).
  - Value: matches the icon color (single-color metrics) or the Effort band color (Effort).
  - For Effort: the smaller `(7)` integer below the hero label stays Secondary Text muted regardless of the value color above it.
- **Sparkline:**
  - Single-color metrics: line uses the metric's color per CONSTANTS.md § Stat Card Colors (e.g., Duration purple, HR red, calories orange, distance teal).
  - Effort sparkline: per-segment color. Each line segment's color is determined by its endpoint's effort value via `AppConstants.effortColor(for:)`. Implementation options:
    - Render the sparkline as multiple `LineMark` series, one per band, segmented by the data points' effort values.
    - OR use Swift Charts' `foregroundStyle(by:)` modifier with a categorical scale derived from each point's band.
    - Either approach is acceptable; verify visually that segment colors transition cleanly when adjacent points fall into different bands.
  - **Highlighted current-workout dot** stays Primary Accent Blue across all metrics — visual signal locating the current session in the chart, distinct from the line color.
- **PR chip and comparative-context delta line colors are unchanged.** Both stay Primary Accent Blue (the chip's tint and the positive-delta text). No metric-color treatment here.

### `WorkoutShareCardView.swift`

The share image card mirrors the new stat-card color treatment 1:1:

- Same icon/label/value color rules as the on-screen card.
- Effort icon palette and Effort value dynamic coloring both apply.
- No chevron, no tap behavior (already part of the share-card structure).
- Other share-card chrome (header `✦ FitNavi`, workout name, exercises list, footer) unchanged.

### Match Prompt Sheet

**No change.** The right-hand FortiFit-side card's `Effort: Hard (7)` metadata line stays plain muted text. Color treatment does not propagate here.

### Models / Services / cascades / algorithms

**Nothing changes.** This is a pure UI/visual polish layer. `WorkoutMetricService`, `WorkoutService`, all algorithms, all cascades — untouched.

### Accessibility identifiers

**No new identifiers.** Color is visual-only; existing identifiers (`workoutDetail_summaryCard_*`, `metricDetailSheet_closeButton`) are sufficient. Do **not** add identifier-per-color or anything similar — accessibility tests don't reliably introspect color in XCUI.

---

## Tests

Use the per-target framework rules in TESTING.md.

### `FortiFitTests` (unit, Swift Testing)

- `test_effortColor_returnsCorrectBandForEveryInteger` — iterate 1 through 10, assert each returned color matches the band per CONSTANTS.md § Effort Color Mapping (1–4 green, 5–6 yellow, 7–10 red). Same shape as the existing `effortLabel(for:)` test.

### `FortiFitIntegrationTests`

- None required. No service-layer changes, no cascade changes.

### `FortiFitUITests`

- None required for color verification — XCUI cannot reliably introspect colors. UI tests for the underlying behavior (stat cards exist, tap opens sheet, sheet closes) already cover functionality and were spec'd in PROMPT_workout_detail_summary_redesign. Color correctness is verified via manual QA on first build.
- **Existing test that needs adjusting:** the smoke test `test_workoutDetail_eachStatCard_opensCorrectMetricSheet` currently asserts the sheet title `[Metric] details`. With the centered title removed, that assertion needs to change — assert the **hero block label** is present (e.g., `Effort` for the Effort card) instead of the now-deleted `Effort details` centered title. Update the test to look for the hero label as the sheet's identifying content.

### Manual QA checklist for first build

- Effort icon renders with three distinct colors (green/yellow/red) on the stat card and the detail sheet hero block.
- Effort value color changes between green/yellow/red based on `workout.rpe` for that workout.
- Effort sparkline shows per-segment color transitions when test fixture data spans multiple bands.
- All other metrics show single-color icon and value matching CONSTANTS.md § Stat Card Colors.
- Detail sheet has no centered title — hero block is the topmost content.
- Share image card export produces colored stat cards visually identical to the on-screen card.
- Match Prompt Sheet `Effort: Hard (7)` metadata line stays plain muted text — no color treatment.

---

## Out of Scope

- Algorithms, cascades, services — none touched.
- New components — none. `FortiFitStatCard` and `FortiFitMetricDetailSheet` are existing components from Phase 8.5; this change updates their color logic only.
- New accessibility identifiers — none.
- New SwiftData fields — none.
- Card structure (icon top + label + chevron, value below) — unchanged.
- Card border color, padding, sizing, tap behavior, sheet presentation, sheet dismissal — unchanged.
- Comparative context block, PR chip, delta line color — unchanged.
- Match Prompt Sheet — unchanged.
- Any surface that uses these icons outside the stat-card and detail-sheet contexts — there are none today, but for forward-compatibility, color rules are scoped to stat cards and detail sheets only.

---

## Acceptance Criteria

- Every stat card on Workout Detail renders with: icon in metric color, label in Primary Text white, value in matching metric color (or Effort band color for the Effort card), chevron in Muted Text.
- Effort icon shows three distinct colors across its three bars (green/yellow/red, short → medium → tall).
- Effort value color changes based on `workout.rpe` — verified across at least three workouts spanning the three bands.
- Tapping any stat card opens the Metric Detail Sheet with **no centered title**, just the hero block at the top.
- Hero block icon, label, and value follow the same color treatment as the card.
- Single-color metric sparklines use the metric's color from CONSTANTS.md § Stat Card Colors.
- Effort sparkline uses per-segment color matching each data point's effort band.
- Current-workout dot on every sparkline is Primary Accent Blue.
- PR chip stays Primary Accent Blue.
- Comparative-context delta line stays muted by default, Primary Accent Blue for positive deltas.
- Share Image Card export shows colored stat cards visually identical to the on-screen Workout Detail.
- Match Prompt Sheet `Effort: Hard (7)` line is plain muted text — color treatment **not** applied.
- All test targets pass green; the existing UI smoke test assertion on the deleted detail-sheet title is updated to check the hero label instead.

---

## Session Hygiene Reminder

Per CLAUDE.md § Session Hygiene: log any unexpected color rendering or build failure to BUGS.md as you encounter it. The Effort palette icon is the most likely surprise (Apple may change layer order in a future SF Symbols release) — flag any visual-order discrepancy in BUGS.md immediately rather than fudging the foreground style tuple.
