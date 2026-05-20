# IMPLEMENTATION_PLAN_PHASE_8_8.md: Home Widget Detail Sheets + Settings Modal Done Buttons

> **Phase 8.8 deliverables.** Build four new widget detail sheets (Today's Plan, Training Load, Weekly Streak Insights, Power Level Breakdown), wire tap-to-open on every Home widget (suppressed in edit mode), retrofit the existing Activity Detail Sheet with a See Info / Configure Settings footer, and add an outlined `Done` button to the Weekly Streak / Training Load / Activity Rings Settings Modals. Activity Rings Settings Modal also gets restructured — `Reset to defaults` removed entirely; `Import from Apple Health` moves to first position directly below the Stand slider.

> **Phase scope assumption:** Phases 1 through 8.7.1 are complete. This phase adds on top of the existing home widget system, training-load / streak / power-level / plan services, and the Activity Detail Sheet shipped in Phase 8.6.

---

## 1. Required Reading (read these BEFORE writing any code)

Read these sections, in order, before starting any subphase. Treat them as the authoritative source — if anything below this implementation plan disagrees with the specs, the specs win and the implementation plan is wrong.

### Phase index (start here)
- `CLAUDE.md` § Phase 8.8 row — quick feature-to-spec index for this phase

### Product surface
- `SCREENS.md` § Standard Patterns → Home Widget Tap-to-Open (new pattern + footer button block)
- `SCREENS.md` § Home Screen → Widget Definitions (tap behavior added to every widget)
- `SCREENS.md` § Today's Plan Detail Sheet (new)
- `SCREENS.md` § Training Load Detail Sheet (new)
- `SCREENS.md` § Weekly Streak Insights Sheet (new — **no flame**, typographic + data + badges)
- `SCREENS.md` § Power Level Breakdown Sheet (new)
- `SCREENS.md` § Activity Detail Sheet → "Footer (Phase 8.8 retrofit)" (footer add only)
- `SCREENS.md` § Home Screen → Activity Rings Settings Modal (new button order + Done replaces Reset)
- `SCREENS.md` § Home Screen → Widget Definitions → Weekly Streak Settings Modal + Training Load Settings Modal (Done button added)
- `SCREENS.md` § Home Screen → States (table now reflects tap-to-open and edit-mode suppression)

### Services / algorithms
- `SERVICES.md` § Streak Algorithm → Weekly Streak Insights Helpers (`fetchHeatmap`, `thisWeekProgress`, `historySummary`)
- `SERVICES.md` § Training Load Algorithm → Detail Sheet Helpers (`fourteenDayDailyScores`, `contributingWorkouts`, `weekOverWeekComparison`)
- `SERVICES.md` § Power Level Algorithm → Top Contributing Exercises / Window Comparison Computation / Nudge Computation
- `SERVICES.md` § PlanService → Retrieval (`fetchTodaysScheduledWorkouts` — new method returns all of today's `ScheduledWorkout` records regardless of status)
- `SERVICES.md` § HomeWidgetService → Widget Tap Routing (new — view-layer routing contract)
- `SERVICES.md` § Workout Cascade — last bullet ("Widget Detail Sheet derived data") is the hook for re-fetching helpers while a sheet is presented

### Foundations
- `PRD.md` § Interaction Style → "Home widget tap-to-open" bullet
- `PRD.md` § Project Structure → Design/Components/ (the four new `FortiFit*DetailSheet.swift` files)
- `PRD.md` § Navigation Flow → new Home → *Detail Sheet edges
- `PRD.md` § Screen Index → four new rows

### Constants and copy
- `CONSTANTS.md` § Widget Tap Behavior
- `CONSTANTS.md` § Widget Detail Sheet Visual Tokens (sheet presentation, hero, body block, footer button block, per-sheet variants)
- `CONSTANTS.md` § Weekly Streak Insights (hero, heatmap color ramp, heatmap geometry, milestone marks, stat row labels)
- `CONSTANTS.md` § Training Load Detail Sheet (hero, 14-day chart, contributing workouts block, week comparison band)
- `CONSTANTS.md` § Power Level Detail Sheet (hero, 30-day volume chart, top exercises block, nudge archetypes)
- `CONSTANTS.md` § Today's Plan Detail Sheet (mini-card layout, status pills, schedule more chip, empty state)
- `CONSTANTS.md` § Settings Modal Done Button (shared style + copy)
- `CONSTANTS.md` § Activity Rings → Settings Modal Strings (Reset removed, Done added)
- `INFO_COPY.md` § Power Level Nudge Copy (four archetypes — `deloading`, `steady`, `rising`, `coldStart`, plus `risingNoTop` fallback variant)
- `INFO_COPY.md` § Widget Detail Sheet Empty States

### Testing
- `TESTING.md` § Test Types (target-per-framework: `FortiFitTests` Swift Testing, `FortiFitIntegrationTests` XCTest, `FortiFitUITests` XCTest — do NOT mix)
- `TESTING.md` § Accessibility Identifiers → "Widget Detail Sheets (Phase 8.8 …)" row (complete identifier inventory + retired identifier list)
- `TESTING.md` § Widget Detail Sheet Test Strategy (test distribution by target)
- `TESTING.md` § The Bug Fix → Regression Test Rule (apply if any BUGS.md entries are resolved during this phase)

### Companion docs (referenced incidentally)
- `HEALTHKIT.md` — only § 7 (field ownership) is touched, no edits needed in this phase
- `WORKOUTKIT.md` — only the Watch Sync Glyph reference on Today's Plan mini-cards is relevant; no edits

---

## 2. Out of Scope (do not build in this phase)

These were considered and explicitly excluded — do not implement, do not add stubs:

- **Tomorrow's Plan preview** in Today's Plan Detail Sheet (deferred to keep scope tight to today)
- **Swipe-paging between widget detail sheets** (analogous to Trends Chart Detail's swipe-paging) — widgets are reorderable on the home, which would make paging direction unstable
- **Range toggles** on Training Load (fixed 14d), Weekly Streak heatmap (fixed 26w), Power Level (fixed 30d). Do not add toggles
- **Animated flame** inside the Weekly Streak Insights Sheet — the flame stays on the widget card only
- **Calculated nudges for any widget other than Power Level** (Training Load uses its existing zone advisory; Power Level is the only widget with the calculated-nudge surface)
- **Trends Chart Detail-style scrubbing or selection** on the new sheets
- **A net-new "Reset" path** for Activity Rings goals after the Reset button removal — manual slider adjustment + Import from Apple Health are the only paths in v1

---

## 3. Subphase Ordering

Work bottom-up: services first (no UI dependencies), then sheet components (depend on services), then widget tap wiring (depends on sheet components), then modal updates and retrofit (independent), then tests.

| Subphase | Title | Depends on | Output |
|---|---|---|---|
| 8.8.A | Service extensions | (nothing) | `StreakService` + 2 helpers, `ExerciseLoadService` + 3 helpers, `PowerLevelService` + 3 helpers, `PlanService.fetchTodaysScheduledWorkouts()`, `HomeWidgetService` tap-route contract |
| 8.8.B | Accessibility identifiers + retirement | 8.8.A | All Phase 8.8 identifiers added to `AccessibilityIdentifiers.swift`; `activityRingsSettings_resetButton` deleted |
| 8.8.C | Four new detail sheet components | 8.8.A, 8.8.B | `FortiFitTodaysPlanDetailSheet.swift`, `FortiFitTrainingLoadDetailSheet.swift`, `FortiFitWeeklyStreakDetailSheet.swift`, `FortiFitPowerLevelDetailSheet.swift` |
| 8.8.D | Widget tap wiring + edit-mode suppression | 8.8.C | `HomeViewModel` tap router; `.sheet(item:)` presentation on `HomeView`; sheet-dismiss-then-modal handoff for footer buttons |
| 8.8.E | Activity Detail Sheet footer retrofit | 8.8.B | Add `See Info` / `Configure Settings` footer to existing `FortiFitActivityDetailSheet` |
| 8.8.F | Settings Modal Done buttons + Activity Rings restructure | 8.8.B | Add Done to Weekly Streak / Training Load / Activity Rings Settings Modals; reorder Activity Rings buttons; delete Reset |
| 8.8.G | Tests (unit, integration, UI smoke) | 8.8.A–F | New tests in all three targets per `TESTING.md` § Widget Detail Sheet Test Strategy |
| 8.8.H | Session hygiene + verification | 8.8.G | All three test targets green; BUGS.md entries logged or resolved; specs and code aligned |

> **Key constraint:** Do not advance to the next subphase until the previous one compiles. Specifically, do not write a detail sheet component (8.8.C) until its service helpers (8.8.A) exist as compilable stubs — even if stubs throw `fatalError("TODO")` initially. This prevents long red-builds.

---

## 4. Subphase 8.8.A — Service Extensions

### 4.1 `StreakService` (`Core/Services/StreakService.swift`)

Add the three helpers per `SERVICES.md` § Streak Algorithm → Weekly Streak Insights Helpers:

- `func fetchHeatmap(weeks: Int = 26) -> [StreakHeatmapCell]`
- `func thisWeekProgress() -> ThisWeekProgress`
- `func historySummary() -> StreakHistorySummary`

Define the three associated `struct` types at file scope (or nested inside the service — pick consistent with the existing service style). All are pure reads against the existing in-memory workout set; no new persistence.

**Acceptance criteria:**
- `fetchHeatmap` returns exactly `weeks` cells, index 0 = most recent week.
- Untracked cells (predating first logged workout) carry `.untracked` status.
- Index-0 cell carries `.inProgress` status (current week).
- `thisWeekProgress.daysRemainingThisWeek` is 0 on Sunday 23:59:59 local and 6 on Monday 00:00:00.
- `historySummary.unlockedMilestones` = `[1, 4, 12, 26, 52].filter { $0 <= currentStreak }`.
- `historySummary.nextUnlockedMilestone` is nil when all unlocked.
- All three methods are synchronous, no caching.

### 4.2 `ExerciseLoadService` (`Core/Services/ExerciseLoadService.swift`)

Add the three helpers per `SERVICES.md` § Training Load Algorithm → Detail Sheet Helpers:

- `func fourteenDayDailyScores() -> [TrainingLoadDailyScore]`
- `func contributingWorkouts(daysBack: Int = 7, limit: Int = 5) -> [TrainingLoadContributor]`
- `func weekOverWeekComparison() -> TrainingLoadWeekComparison`

The 14-day daily scores function is a daily replay of the existing algorithm — refactor the score computation to accept a `referenceDate` parameter if it currently hardcodes `.now`. This is the only structural change to existing code in this subphase.

**Acceptance criteria:**
- `fourteenDayDailyScores()` returns 14 entries, oldest first.
- `contributingWorkouts` returns ≤ 5 rows, sorted by `tssContribution` descending (ties by `date` descending).
- `percentOfWeeklyLoad` sums to ≤ 100 (rounding may make it 99 or 100).
- `weekOverWeekComparison` uses the **same Mon–Sun week definition** as `StreakService` (do not invent a new one).

### 4.3 `PowerLevelService` (`Core/Services/PowerLevelService.swift`)

Add the three helpers per `SERVICES.md` § Power Level Algorithm → Top Contributing Exercises / Window Comparison / Nudge Computation:

- `func topContributingExercises(limit: Int = 3) -> [PowerLevelTopExercise]`
- `func windowComparison() -> PowerLevelWindowComparison`
- `func computeNudge() -> PowerLevelNudge`

**Acceptance criteria:**
- `topContributingExercises` applies the **≥ 3-session filter** (`sessionCountInWindow >= 3`) — this is non-negotiable; the entire "what's driving the trend" UX depends on it.
- Sort order: descending `currentWindowVolume`, ties by descending `sessionCountInWindow`, then by `exerciseName` ascending.
- `computeNudge` resolution order:
  1. **Cold-start guard first**: `qualifyingWorkoutsInCurrentWindow.count < 3` → archetype `.coldStart`, inputs all nil.
  2. Else branch on status (`.deloading` / `.steady` / `.rising`).
  3. `.steady` with no top exercise passing the ≥ 3-session filter → also degrades to cold-start copy (do not crash on nil, do not render a "Volume on  is flat" message).
- Copy templates live in `AppConstants.PowerLevel.nudgeCopy` per `INFO_COPY.md` § Power Level Nudge Copy. Service exposes the **archetype + inputs**, not the rendered string.

### 4.4 `PlanService` (`Core/Services/PlanService.swift`)

Add one method per `SERVICES.md` § PlanService → Retrieval:

- `func fetchTodaysScheduledWorkouts() -> [ScheduledWorkout]`

Returns all `ScheduledWorkout` records where `scheduledDate == today` (calendar-local), regardless of status. Sort by `scheduledTime` ascending (nil times sort last), then `sortOrder` ascending.

**Acceptance criteria:**
- Existing `fetchTodaysPlanned()` (returns first uncompleted) is untouched — both methods coexist.
- Completed-row visibility windowing is a side effect of the date filter — no separate completion-window logic needed.

### 4.5 `HomeWidgetService` view-layer contract

The widget-tap routing function `tapRoute(for:isEditMode:)` per `SERVICES.md` § HomeWidgetService → Widget Tap Routing is **owned by `HomeViewModel`**, not the service. Document it inside `HomeViewModel.swift`. Do not modify `HomeWidgetService.swift` itself in this subphase (it stays a SwiftData CRUD shop).

### 4.6 Cascade integration

In `WorkoutService.log()` / `WorkoutService.update()` / `WorkoutService.delete()` cascade fan-out, add a published-changes notification that the four new detail-sheet ViewModels subscribe to. Do NOT pre-emptively recompute the helpers — the sheet ViewModel re-fetches on each cascade fire while it is presented. Sheets that are not presented do nothing.

---

## 5. Subphase 8.8.B — Accessibility Identifiers

Add the following to `AccessibilityIdentifiers.swift` (per `TESTING.md` § Accessibility Identifiers convention — never hardcode strings in views or tests):

```swift
enum AccessibilityIdentifiers {
    // Today's Plan Detail Sheet
    static let todaysPlanDetailSheet_closeButton          = "todaysPlanDetailSheet_closeButton"
    static let todaysPlanDetailSheet_emptyState           = "todaysPlanDetailSheet_emptyState"
    static let todaysPlanDetailSheet_scheduleMoreButton   = "todaysPlanDetailSheet_scheduleMoreButton"
    static func todaysPlanDetailSheet_row_completeButton(scheduledWorkoutId: String) -> String {
        "todaysPlanDetailSheet_row_\(scheduledWorkoutId)_completeButton"
    }

    // Training Load Detail Sheet
    static let trainingLoadDetailSheet_closeButton              = "trainingLoadDetailSheet_closeButton"
    static let trainingLoadDetailSheet_hero                     = "trainingLoadDetailSheet_hero"
    static let trainingLoadDetailSheet_dailyChart               = "trainingLoadDetailSheet_dailyChart"
    static let trainingLoadDetailSheet_contributingWorkouts     = "trainingLoadDetailSheet_contributingWorkouts"
    static let trainingLoadDetailSheet_weekComparison           = "trainingLoadDetailSheet_weekComparison"
    static let trainingLoadDetailSheet_recoveryCallout          = "trainingLoadDetailSheet_recoveryCallout"
    static let trainingLoadDetailSheet_seeInfoButton            = "trainingLoadDetailSheet_seeInfoButton"
    static let trainingLoadDetailSheet_configureSettingsButton  = "trainingLoadDetailSheet_configureSettingsButton"
    static let trainingLoadDetailSheet_emptyState_coldStart     = "trainingLoadDetailSheet_emptyState_coldStart"

    // Weekly Streak Insights Sheet
    static let weeklyStreakDetailSheet_closeButton              = "weeklyStreakDetailSheet_closeButton"
    static let weeklyStreakDetailSheet_hero                     = "weeklyStreakDetailSheet_hero"
    static let weeklyStreakDetailSheet_statRow                  = "weeklyStreakDetailSheet_statRow"
    static let weeklyStreakDetailSheet_thisWeekRing             = "weeklyStreakDetailSheet_thisWeekRing"
    static let weeklyStreakDetailSheet_heatmap                  = "weeklyStreakDetailSheet_heatmap"
    static func weeklyStreakDetailSheet_heatmap_cell(_ index: Int) -> String {
        "weeklyStreakDetailSheet_heatmap_cell_\(index)"
    }
    static let weeklyStreakDetailSheet_milestoneShelf           = "weeklyStreakDetailSheet_milestoneShelf"
    static func weeklyStreakDetailSheet_milestone(_ mark: Int) -> String {
        "weeklyStreakDetailSheet_milestone_\(mark)"
    }
    static let weeklyStreakDetailSheet_configureSettingsButton  = "weeklyStreakDetailSheet_configureSettingsButton"

    // Power Level Breakdown Sheet
    static let powerLevelDetailSheet_closeButton              = "powerLevelDetailSheet_closeButton"
    static let powerLevelDetailSheet_hero                     = "powerLevelDetailSheet_hero"
    static let powerLevelDetailSheet_volumeChart              = "powerLevelDetailSheet_volumeChart"
    static let powerLevelDetailSheet_topExercises             = "powerLevelDetailSheet_topExercises"
    static func powerLevelDetailSheet_topExerciseRow(_ index: Int) -> String {
        "powerLevelDetailSheet_topExerciseRow_\(index)"
    }
    static let powerLevelDetailSheet_windowComparison         = "powerLevelDetailSheet_windowComparison"
    static let powerLevelDetailSheet_nudge                    = "powerLevelDetailSheet_nudge"
    static let powerLevelDetailSheet_seeInfoButton            = "powerLevelDetailSheet_seeInfoButton"

    // Activity Detail Sheet (retrofit)
    static let activityDetailSheet_seeInfoButton              = "activityDetailSheet_seeInfoButton"
    static let activityDetailSheet_configureSettingsButton    = "activityDetailSheet_configureSettingsButton"

    // Settings Modal Done buttons
    static let weeklyStreakSettings_doneButton                = "weeklyStreakSettings_doneButton"
    static let trainingLoadSettings_doneButton                = "trainingLoadSettings_doneButton"
    static let activityRingsSettings_doneButton               = "activityRingsSettings_doneButton"
}
```

**Retire `activityRingsSettings_resetButton`** — delete its constant from `AccessibilityIdentifiers.swift` and search-replace its usage across the codebase (should be zero references after the button is removed from the view). Any straggling reference is a compile error — a feature, not a bug.

---

## 6. Subphase 8.8.C — Detail Sheet Components

Build four new components in `Design/Components/`. Each component is a SwiftUI `View` taking minimal init args (the relevant `@Observable` ViewModel) and rendering the full sheet per its `SCREENS.md` section.

### 6.1 `FortiFitTodaysPlanDetailSheet.swift`

Render per `SCREENS.md` § Today's Plan Detail Sheet. ViewModel responsibilities:
- Call `PlanService.fetchTodaysScheduledWorkouts()` on appear and on each Workout Cascade publish.
- Compose a `Complete` button action that opens the **same compact confirmation sheet** used by the Plan tab's Complete Planned Workout Flow (do not re-implement — reuse the existing component / flow).
- Compose a `Schedule another workout for today` button action that dismisses the sheet and pushes the Plan tab's Scheduling Flow pre-set to today.
- Row tap action: dismiss sheet and navigate to either Workout Detail (Completed rows) or Schedule Workout sheet (Planned rows). No-op for Skipped rows.

**Reactivity rule:** When a workout is completed via the Complete button, the row's status pill updates to `Completed`, the action button updates to disabled-checkmark, and **the row stays in place** (do not reorder).

**Watch sync glyph:** Render `FortiFitWatchSyncGlyph` on every mini card — it is naturally scoped to Strength/HIIT because `ScheduledWorkout` records are template-backed and templates are restricted to those two types. Do not add type-check guarding code.

### 6.2 `FortiFitTrainingLoadDetailSheet.swift`

Render per `SCREENS.md` § Training Load Detail Sheet. ViewModel calls all three new `ExerciseLoadService` helpers on appear. Reuses the visual treatment from `FortiFitChartCard` (gradient backdrop, hairline, smoothed line) for the 14-day chart at sheet-block scale.

**Per-block empty states:** Implement the table in `SCREENS.md` § Training Load Detail Sheet → Per-block empty states. Each block independently renders its own empty copy (per Phase 8.8 product decision — partial data still feels rewarding).

**Footer:** Side-by-side `See Info` · `Configure Settings`. Both use the sheet-dismiss-then-modal handoff (see 8.8.D below).

### 6.3 `FortiFitWeeklyStreakDetailSheet.swift`

Render per `SCREENS.md` § Weekly Streak Insights Sheet. **The animated flame is intentionally not rendered** — do not import or instantiate the flame view in this file.

Five blocks, top-to-bottom: typographic hero (with count-up animation, respecting `UIAccessibility.isReduceMotionEnabled`) → stat row → this-week concentric arc → 26-week heatmap → milestone shelf.

**Heatmap tooltip:** Use `FortiFitTooltip` (existing component) anchored above the tapped cell. Tap-outside dismisses. Cell tooltips do **not** open any other sheet — they are passive disclosure only.

**Milestone shelf:** Render 5 SF Symbol badges at `[1, 4, 12, 26, 52]`. Tapping a badge is a no-op in v1.

### 6.4 `FortiFitPowerLevelDetailSheet.swift`

Render per `SCREENS.md` § Power Level Breakdown Sheet. ViewModel calls `topContributingExercises`, `windowComparison`, and `computeNudge` on appear.

**Nudge rendering:** ViewModel receives `PowerLevelNudge` from the service. It looks up the copy template in `AppConstants.PowerLevel.nudgeCopy` by `archetype.rawValue` (or `risingNoTop` when archetype is `.rising` and `topExerciseName` is nil). Interpolation happens in the view layer using `String(format:)` / `LocalizedStringResource`.

**Top exercise row tap:** Dismiss sheet, navigate to Trends → Strength Tracker chart detail pre-filtered to that exercise (reuse the existing chart-detail navigation API).

---

## 7. Subphase 8.8.D — Widget Tap Wiring + Edit-Mode Suppression

### 7.1 `HomeViewModel`

Add the `tapRoute(for:isEditMode:)` function per the `WidgetDetailRoute` enum in `SERVICES.md` § HomeWidgetService → Widget Tap Routing. Wire it as follows in `HomeView`:

```swift
// Pseudocode — match existing HomeView style
ForEach(widgets) { widget in
    WidgetCardView(widget: widget)
        .onTapGesture {
            switch viewModel.tapRoute(for: widget, isEditMode: viewModel.isEditMode) {
            case .suppressed: break
            case .todaysPlan: viewModel.presentedSheet = .todaysPlan
            case .trainingLoad: viewModel.presentedSheet = .trainingLoad
            case .weeklyStreak: viewModel.presentedSheet = .weeklyStreak
            case .powerLevel: viewModel.presentedSheet = .powerLevel
            case .appleActivityLive: viewModel.presentedSheet = .appleActivityDetail
            case .appleActivityConnectHK: navigate(to: .settingsAppleHealth)
            case .appleActivityPairWatch: break
            }
        }
}
.sheet(item: $viewModel.presentedSheet) { sheet in
    sheet.makeView()
}
```

### 7.2 Sheet-dismiss-then-modal handoff

When a sheet's footer button (`See Info` or `Configure Settings`) is tapped, the sheet must dismiss first via its `presentationMode` binding, then the parent (`HomeView`) opens the corresponding modal after a `0.2s` delay (matches the iOS sheet-dismiss animation). **Never stack sheet-on-sheet** — `.sheet` modifiers stacked vertically cause flicker.

Implementation: each sheet emits a `RequestFollowupModal` enum event upward via a closure (`onFollowupRequested:`). `HomeView` listens, dismisses the sheet, then schedules a `DispatchQueue.main.asyncAfter` of 0.2s to present the modal.

### 7.3 Edit mode visual

No new visual change. Tap-to-open is suppressed by the `tapRoute` returning `.suppressed`. The existing "x" delete buttons and drag physics remain unchanged.

---

## 8. Subphase 8.8.E — Activity Detail Sheet Footer Retrofit

In the existing `FortiFitActivityDetailSheet.swift`:
1. Add a footer block below the closure heatmap (the last existing body block).
2. Footer renders side-by-side `See Info` · `Configure Settings` text buttons per `CONSTANTS.md` § Widget Detail Sheet Visual Tokens → Footer Button Block.
3. Both buttons use the sheet-dismiss-then-modal handoff from 7.2.
4. `See Info` → Widget Info Modal (existing `seeInfoModal` populated from `INFO_COPY` § Activity Rings).
5. `Configure Settings` → Activity Rings Settings Modal (existing).
6. Add identifiers `activityDetailSheet_seeInfoButton` and `activityDetailSheet_configureSettingsButton`.

No other behavior changes to Activity Detail Sheet.

---

## 9. Subphase 8.8.F — Settings Modal Done Buttons + Activity Rings Restructure

### 9.1 Add `Done` button to three modals

For each of the three existing settings modals (`WeeklyStreakSettingsModalView`, `TrainingLoadSettingsModalView`, `ActivityRingsSettingsModalView`), add a full-width outlined `Done` button below the last existing slider / action button. Style per `CONSTANTS.md` § Settings Modal Done Button (outlined, 1.5pt border, full-width, 44pt min height, copy `Done`).

Tapping `Done` dismisses the modal — identical to the close X.

Add identifiers `weeklyStreakSettings_doneButton`, `trainingLoadSettings_doneButton`, `activityRingsSettings_doneButton`.

### 9.2 Restructure Activity Rings Settings Modal

Per `SCREENS.md` § Activity Rings Settings Modal (Phase 8.8 updates):

1. **Delete the `Reset to defaults` button** from the view. Delete its `activityRingsSettings_resetButton` accessibility identifier (already done in 8.8.B).
2. **Reorder the action buttons** so `Import from Apple Health` is the **first** action (directly below the Stand slider), and the new `Done` button is the **second** action (bottom of the modal).
3. Update the `settingsModalResetButton` constant in `AppConstants.ActivityRings.*` — delete it. Tests referencing the retired identifier should now fail to compile (a feature).

### 9.3 Constant cleanup

In `AppConstants.ActivityRings`, ensure:
- `settingsModalResetButton` is deleted
- `settingsModalImportButton` remains
- `settingsModalImportDisabledCaption` remains
- New shared constant `AppConstants.SettingsModal.doneButtonLabel = "Done"` is referenced by all three modals

---

## 10. Subphase 8.8.G — Tests

Test framework rules (per `TESTING.md` § Test Types) — **framework-per-target, do not mix**:

| Target | Framework | What goes here |
|---|---|---|
| `FortiFitTests` | Swift Testing | Pure service helpers, calculated nudge resolution, constants |
| `FortiFitIntegrationTests` | XCTest | Cross-service cascades, tap routing edit-mode suppression, completed-row windowing |
| `FortiFitUITests` | XCTest | Tap-to-open per widget, footer handoff, Done button parity, heatmap tooltip |

### 10.1 Unit tests (`FortiFitTests`)

Create new files (one per service extension, per the existing per-service `*UnitTests.swift` pattern):

- `StreakInsightsHelpersUnitTests.swift` — covers `fetchHeatmap`, `thisWeekProgress`, `historySummary`. ≥ 6 tests, including `test_fetchHeatmap_returnsExactly26CellsByDefault`, `test_thisWeekProgress_onSundayEOD_returnsZeroDaysRemaining`, `test_historySummary_unlockedMilestonesMatchFilterAgainstStreak`.
- `TrainingLoadDetailHelpersUnitTests.swift` — covers `fourteenDayDailyScores`, `contributingWorkouts`, `weekOverWeekComparison`. ≥ 5 tests.
- `PowerLevelDetailHelpersUnitTests.swift` — covers `topContributingExercises`, `windowComparison`, `computeNudge`. ≥ 7 tests, including the critical archetype resolution tests:
  - `test_computeNudge_lessThanThreeWorkoutsInWindow_returnsColdStartEvenWhenStatusIsRising`
  - `test_computeNudge_steadyStatusWithNoTopExercisePassingFilter_degradesToColdStart`
  - `test_topContributingExercises_excludesExercisesWithFewerThanThreeSessions`
- `PlanServiceTodaysScheduledUnitTests.swift` — covers `fetchTodaysScheduledWorkouts`. ≥ 3 tests including nil-time sort order.

Use `test_situation_expectedOutcome` naming throughout. Reuse `TestFixtures.makeWorkout`, `makeStrengthPRGoal`, `daysAgo` factories.

### 10.2 Integration tests (`FortiFitIntegrationTests`)

Create new files:

- `WidgetTapRoutingIntegrationTests.swift` — drives `HomeViewModel` through edit-mode toggles. Test `test_tapRoute_inEditMode_returnsSuppressedForEveryWidgetType` (parameterized over all 5 widget types).
- `WidgetDetailSheetCascadeIntegrationTests.swift` — presents each detail sheet, fires a workout-save, asserts each helper re-fetches and the ViewModel publishes new state. ≥ 4 tests (one per sheet).
- `TodaysPlanCompletionWindowingIntegrationTests.swift` — completes a scheduled workout today → assert visible in today's sheet → advance clock → assert no longer visible. Use a `Date` injection point (or `Clock` protocol if one exists; otherwise create a thin `CalendarDayProvider` protocol with a default `.now` impl + a test stub).
- `PowerLevelNudgeColdStartFallbackIntegrationTests.swift` — seeds 2 Strength workouts → assert archetype is `coldStart` regardless of computed status.
- `ActivityRingsSettingsResetRemovalIntegrationTests.swift` — boots the Activity Rings Settings Modal in a test host → assert no element with `activityRingsSettings_resetButton` exists.

### 10.3 UI smoke tests (`FortiFitUITests`)

Add to `SmokeTests.swift` (or split if the file exceeds ~600 lines):

- `test_homeWidget_todaysPlan_tap_opensDetailSheet`
- `test_homeWidget_trainingLoad_tap_opensDetailSheet`
- `test_homeWidget_weeklyStreak_tap_opensDetailSheet`
- `test_homeWidget_powerLevel_tap_opensDetailSheet`
- `test_homeWidget_editMode_tapDoesNotOpenSheet`
- `test_todaysPlanDetailSheet_completeButton_completesWorkoutAndKeepsRowVisible`
- `test_todaysPlanDetailSheet_scheduleMoreChip_dismissesAndOpensSchedulingFlow`
- `test_trainingLoadDetailSheet_seeInfoFooter_dismissesAndOpensWidgetInfoModal`
- `test_activityDetailSheet_retrofitFooter_navigatesViaDismissThenModalHandoff`
- `test_weeklyStreakSettingsModal_doneButton_dismissesModal`
- `test_trainingLoadSettingsModal_doneButton_dismissesModal`
- `test_activityRingsSettingsModal_doneButton_dismissesModal`
- `test_activityRingsSettingsModal_resetButton_isNotPresent`

Use `--uitesting --reset-state` launch args for clean state. Seed data via the app's existing test-seed hooks (or extend if needed for the cold-start path).

### 10.4 Regression test rule

If any new bugs are logged in `BUGS.md` during this phase and resolved, add a regression test per `TESTING.md` § The Bug Fix → Regression Test Rule. Reference the bug ID in the test's doc comment.

---

## 11. Subphase 8.8.H — Session Hygiene + Verification

Apply `CLAUDE.md` § Session Hygiene before considering this phase done:

- [ ] **All three test targets passing.** Any intentionally failing test logged in `BUGS.md` as "Open — pending implementation".
- [ ] **Every new interactive UI element has `.accessibilityIdentifier(...)`** sourced from `AccessibilityIdentifiers.swift` — no hardcoded strings.
- [ ] **Specs and code aligned.** Any deviation from the spec discovered during implementation is reflected back into the relevant `.md` file (do not let the spec rot).
- [ ] **`activityRingsSettings_resetButton` deleted** from `AccessibilityIdentifiers.swift` and from `AppConstants.ActivityRings`. Zero references in the codebase (grep should return zero hits).
- [ ] **Sheet-on-sheet behavior verified manually**: open Training Load Detail Sheet → tap `See Info` → confirm Widget Info Modal appears cleanly with no flicker. Repeat for Configure Settings. Repeat for Activity Detail Sheet retrofit.
- [ ] **Edit-mode tap suppression verified manually**: long-press a widget → enter edit mode → tap each widget → confirm no sheet opens.
- [ ] **Completed-row visibility windowing verified manually** (preferred over relying on the time-stub test): complete a scheduled workout today → open Today's Plan Detail Sheet → confirm row visible → advance system time to tomorrow → reopen → confirm row no longer appears.
- [ ] **BUGS.md** — any unexpected behavior or build failure during implementation logged per `CLAUDE.md` § Bug Logging.

---

## 12. Cross-cutting concerns

### 12.1 Reduce Motion

`UIAccessibility.isReduceMotionEnabled == true` → skip the Weekly Streak hero count-up animation (render final value directly). All other animations are subtle enough that they don't need a Reduce Motion gate.

### 12.2 Dynamic Type

All copy uses standard `FortiFitTypography.*` styles which scale with Dynamic Type. The 96pt hero on Weekly Streak should clamp to a maximum (`.fixedSize(horizontal: false, vertical: true)` plus a `.dynamicTypeSize(...DynamicTypeSize.accessibility1)` cap) to avoid overflowing on accessibility sizes — but **do not block the layout** at small sizes; users may have set tiny type.

### 12.3 VoiceOver

Per `TESTING.md` § Accessibility Identifiers and PRD § Accessibility:
- Sheet title announced first
- Hero number announced with sub-label (Weekly Streak: "12, week streak")
- Status pills announced as part of the row's accessibility label
- Action buttons announce with `.button` trait
- Heatmap cells announce as `Week of {Mon date}, {count} of {target} workouts` — do not require tooltip activation for VoiceOver

### 12.4 SwiftData threading

Sheet ViewModels query SwiftData on the main actor (existing convention per `SERVICES.md` § WorkoutMetricService → Computation Rules). Do not introduce background contexts for these reads.

### 12.5 Naming convention reminder

Per `CLAUDE.md` § Key Constraints: product name = **FitNavi** (user-facing copy), codebase = **FortiFit** (Swift identifiers). All component class names are `FortiFit*`. All user-facing copy in this phase reads "FitNavi" only where there's product-level prose (none in this phase, since detail sheets reference data, not the product name).

---

## 13. Verification Gates

This phase is **not done** until all of the following pass:

1. `xcodebuild test -scheme FortiFit` returns success across all three targets.
2. The retired `activityRingsSettings_resetButton` identifier returns zero grep hits across the entire codebase (including tests).
3. Manual QA pass on a simulator covering: tap-to-open per widget, edit-mode suppression, footer button handoff (no flicker), completed-row windowing, Done button parity, and the Power Level cold-start nudge fallback (seed < 3 Strength workouts).
4. `CLAUDE.md` § Phase 8.8 row references resolve — every linked spec section exists and matches the implementation.
5. No new `Open` entries in `BUGS.md` unless they are intentionally deferred and noted.

When all five pass, mark the phase complete in `CLAUDE.md` (no formal mark — just stop opening new BUGS entries against it and let the next phase begin).
