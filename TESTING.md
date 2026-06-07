# TESTING.md: FitNavi Test Organization

> How the test suite is organized, how to run each type, and how to add new tests without losing track.

---

## Test Types

FitNavi has three distinct kinds of tests. They live in separate Xcode targets so you can run each independently and tell at a glance which kind a test is.

| Target | Type | What it tests | Typical run time |
|--------|------|---------------|-----------------|
| `FortiFitTests` | **Unit tests** | Pure functions and single-service logic in isolation (algorithms, formatters, unit conversions, validation) | Milliseconds per test |
| `FortiFitIntegrationTests` | **Integration tests** | Realistic cross-service scenarios — "when the user does X, does the full cascade run correctly?" Uses in-memory SwiftData. | ~50–200ms per test |
| `FortiFitUITests` | **XCUI smoke tests** | End-to-end user journeys driven through the real UI on a simulator | 2–10 seconds per test |

**Rule of thumb for picking a type:**
- Testing a formula, a conversion, a validator, a single-service rule → Unit test.
- Testing a workflow that crosses services (e.g., logging a workout updates a goal AND a snapshot AND the streak) → Integration test.
- Testing that a screen renders, buttons exist, and a user flow doesn't crash → XCUI smoke test.

---

## Xcode Target Setup

If you don't already have three test targets, add the two missing ones:

1. **File → New → Target → iOS → Unit Testing Bundle**
   - Name: `FortiFitIntegrationTests`
   - Target to Test: `FortiFit`
2. **File → New → Target → iOS → UI Testing Bundle**
   - Name: `FortiFitUITests`
   - Target to Test: `FortiFit`

You should end up with this structure:

```
FortiFit/
├── FortiFit/                          # App target
├── FortiFitTests/                     # Unit tests (already exists)
│   └── *UnitTests.swift
├── FortiFitIntegrationTests/          # NEW
│   ├── TestFixtures.swift             # Shared helpers
│   └── *IntegrationTests.swift
└── FortiFitUITests/                   # NEW
    └── SmokeTests.swift
```

### Scheme Configuration

In your `FortiFit` scheme (Product → Scheme → Edit Scheme → Test), make sure all three test targets are listed. You can toggle any of them off for fast iteration (e.g., skip UI tests while developing a service).

---

## Naming Conventions

Use these suffixes consistently — they keep the test navigator readable:

| Suffix | Target | Example |
|--------|--------|---------|
| `*UnitTests.swift` | `FortiFitTests` | `UnitConversionUnitTests.swift`, `StreakAlgorithmUnitTests.swift` |
| `*IntegrationTests.swift` | `FortiFitIntegrationTests` | `WorkoutCascadeIntegrationTests.swift`, `PlanServiceIntegrationTests.swift` |
| `SmokeTests.swift` (just one file) | `FortiFitUITests` | `SmokeTests.swift` |

**Test method names** follow the `test_situation_expectedOutcome` pattern. This format reads as a readable sentence in Xcode's test navigator and doubles as spec documentation.

Good examples:
- `test_loggingWorkoutWithMatchingExercise_updatesStrengthPRGoal`
- `test_deletingLastWorkoutOfType_removesWorkoutTypeOrder`
- `test_cosmeticEditOnly_bumpsLastModifiedDateAndRescopesGoal`

Bad examples:
- `testGoals()` — what about goals?
- `testWorkoutDelete()` — delete what outcome?

---

## Running Tests

**Run all tests:** `⌘U`

**Run only unit tests:** In Test Navigator, right-click `FortiFitTests` → Run. Fast.

**Run only integration tests:** Right-click `FortiFitIntegrationTests` → Run. Use this before committing.

**Run only UI smoke tests:** Right-click `FortiFitUITests` → Run. Slow; run before every TestFlight build.

**Command line:**
```bash
# Integration tests only
xcodebuild test -scheme FortiFit -only-testing:FortiFitIntegrationTests

# UI smoke tests only
xcodebuild test -scheme FortiFit -only-testing:FortiFitUITests
```

---

## Accessibility Identifiers (required for UI tests)

XCUI tests find UI elements by accessibility identifier, not by the text label shown to users. This keeps tests from breaking when copy changes.

Add identifiers to every custom SwiftUI element a test interacts with:

```swift
Button("+ Log Workout") { /* ... */ }
    .accessibilityIdentifier("logWorkoutCTA")

TextField("Workout name", text: $name)
    .accessibilityIdentifier("workoutNameInput")
```

**Naming convention for identifiers:** camelCase, descriptive, scoped by screen where ambiguous. Representative examples from the current codebase:

- Actions: `logWorkoutCTA`, `saveWorkoutButton`, `addExerciseButton`, `saveGoalButton`, `planAddButton`
- Inputs: `workoutNameInput`, `durationInput`, `distanceInput`, `goalTargetWeightInput`
- Dropdowns: `workoutTypeDropdown`, `goalExerciseDropdown`
- Menus: `homeEllipsisMenu`, `workoutsEllipsisMenu`, `workoutDetailEllipsis`, `addWidgetsMenuItem`, `saveAsTemplateMenuItem`, `viewSavedTemplatesMenuItem`, `homeWidget_trainingLoad_configureSettings`, `homeWidget_weeklyStreak_configureSettings`, `homeWidget_trainingLoad_seeInfo`, `homeWidget_powerLevel_seeInfo`, `homeWidget_todaysPlan_completeWorkoutMenuItem`, `trendsChart_seeInfoMenuItem`, `seeInfoModal_closeButton`, `editWorkout_ellipsisMenu`, `editWorkout_useTemplateMenuItem`, `editWorkout_templateSelectorOverlay`
- Today's Plan widget: `homeWidget_todaysPlan_silhouette` (renders only when an uncompleted scheduled workout exists today — tests assert presence/absence by state)
- Cards: `workoutTypeCard_StrengthTraining`, `goalCard_benchPress`, `scheduledWorkoutCard_0`, `workoutDetail_summaryCard_effort`, `workoutDetail_summaryCard_duration`, `workoutDetail_summaryCard_distance`, `workoutDetail_summaryCard_avgHR`, `workoutDetail_summaryCard_maxHR`, `workoutDetail_summaryCard_activeKcal`, `workoutDetail_summaryCard_totalKcal`, `workoutDetail_summaryCard_elevation`, `workoutDetail_summaryCard_exerciseMinutes`, `workoutDetail_summaryCard_effortBars`, `metricDetailSheet_closeButton`, `metricDetailSheet_hero_effortBars`
- HealthKit: `settings_appleHealthToggle`, `settings_appleHealthSyncNowButton`, `settings_appleHealthOpenSettingsButton`, `workoutDetail_healthSourceIndicator`, `workoutDetail_healthUnlinkButton`, `matchPromptSheet_linkButton`, `matchPromptSheet_keepSeparateButton`, `matchPromptSheet_decideLaterButton`
- HealthKit (Phase 8.5+ Source Info Sheet redesign): `sourceInfoSheet_readOnlyCallout`, `sourceInfoSheet_permanentUnlinkCallout`, `sourceInfoSheet_doneButton`, `sourceInfoSheet_unlinkConfirmButton`, `sourceInfoSheet_unlinkCancelButton`, `sourceInfoSheet_lastSyncedRow`, `logWorkout_hkFieldInfoIcon_date`, `logWorkout_hkFieldInfoIcon_startTime`, `logWorkout_hkFieldInfoIcon_duration`, `logWorkout_hkFieldInfoIcon_distance`
- Activity Rings widget (`appleActivity`): `homeWidget_appleActivity_card`, `homeWidget_appleActivity_state_connectAppleHealth`, `homeWidget_appleActivity_state_pairAppleWatch`, `homeWidget_appleActivity_connectButton`, `homeWidget_appleActivity_moveRing`, `homeWidget_appleActivity_exerciseRing`, `homeWidget_appleActivity_standRing`, `homeWidget_appleActivity_weeklyClosureChip`
- Activity Rings Settings Modal: `activityRingsSettings_moveSlider`, `activityRingsSettings_exerciseSlider`, `activityRingsSettings_standSlider`, `activityRingsSettings_importButton`, `activityRingsSettings_doneButton` (Phase 8.8). **Retired:** `activityRingsSettings_resetButton` — see Phase 8.8 row below.
- Activity Detail Sheet: `activityDetailSheet_closeButton`, `activityDetailSheet_range7d`, `activityDetailSheet_range30d`, `activityDetailSheet_moveSparkline`, `activityDetailSheet_exerciseSparkline`, `activityDetailSheet_standSparkline`, `activityDetailSheet_closureHeatmap`
- Trends chart cards (Phase 6.1 — see SCREENS.md § Standard Patterns → Trends Chart Card Visual Treatment): `trendsChart_{chartId}_card`, `trendsChart_{chartId}_headerSummary`, `trendsChart_workoutTypeBreakdown_centerLabel`
- Trends chart detail view (Phase 6.2 — see SCREENS.md § Trends Chart Detail and CONSTANTS.md § Trends Chart Detail View): `trendsChart_{chartId}_expandButton`, `trendsChartDetail_{chartId}_card`, `trendsChartDetail_{chartId}_backButton`, `trendsChartDetail_{chartId}_headerSummary`, `trendsChartDetail_{chartId}_seeInfoButton`, `trendsChartDetail_{chartId}_rangeToggle_{rangeRawValue}` (e.g. `..._rangeToggle_30d`, `..._rangeToggle_1y`), `trendsChartDetail_{chartId}_dataPoint_{index}` (selection target — only on charts where selection is enabled per CONSTANTS.md § Trends Chart Detail View → Selection State), `trendsChartDetail_{chartId}_selectionAnnotation`, `trendsChartDetail_personalRecords_timelinePoint_{index}` (PR timeline only), `trendsChartDetail_workoutTypeBreakdown_legendRow_{index}` (donut legend only), `trendsChartDetail_workoutTypeBreakdown_legendSortHeader_{column}` (column ∈ `count`, `percent`, `type`, `avgDuration`)
- Cross-app back navigation chevron (Phase 6.2 — see SCREENS.md § Standard Patterns → Back Navigation Chevron): `{screenId}_backButton` — e.g., `workoutDetail_backButton`, `addGoal_backButton`, `settings_backButton`, `trendsChartDetail_strengthTracker_backButton`
- Apple Watch push (Phase 8.7 + 8.7.1 — see SCREENS.md § Standard Patterns → Watch Sync Card Glyph, § Plan → Push to Apple Watch Toggle, § Settings → Apple Watch Section, § Edit Planned Workout, and WORKOUTKIT.md § 17): `settings_appleWatchToggle`, `settings_appleWatchOpenSettingsButton`, `scheduledWorkoutCard_{index}_watchSyncGlyph`, `scheduleWorkout_pushToAppleWatchToggle`, `scheduleWorkout_pushToAppleWatchInfoPopover`, `editScheduledWorkout_backButton`, `editScheduledWorkout_dateField`, `editScheduledWorkout_timeField`, `editScheduledWorkout_watchSyncToggle`, `editScheduledWorkout_watchSyncInfoPopover`, `editScheduledWorkout_recurrencePrompt_thisOnly`, `editScheduledWorkout_recurrencePrompt_thisAndFuture`, `editScheduledWorkout_saveButton`, `exerciseCard_{index}_restPerSetField`, `exerciseCard_{index}_restPerSetInfoPopover`, `exerciseCard_{index}_repsTimeToggle`, `masterSyncOff_popover`, `masterSyncOff_openSettingsButton`, `watchSyncErrorToast`, `watchSyncErrorToast_retryButton`. (Identifier names retain "Sync"/"watchSync" tokens for code-level continuity; user-facing copy uses "Push" per CONSTANTS.md § Apple Watch Strings.)
- Widget Detail Sheets (Phase 8.8 — see SCREENS.md § Today's Plan Detail Sheet, § Training Load Detail Sheet, § Weekly Streak Insights Sheet, § Power Level Breakdown Sheet, and the Activity Detail Sheet retrofit): `todaysPlanDetailSheet_closeButton`, `todaysPlanDetailSheet_emptyState`, `todaysPlanDetailSheet_row_{scheduledWorkoutId}_completeButton`; `trainingLoadDetailSheet_closeButton`, `trainingLoadDetailSheet_hero`, `trainingLoadDetailSheet_dailyChart`, `trainingLoadDetailSheet_chartDataPoint_{index}`, `trainingLoadDetailSheet_chartSelectionAnnotation`, `trainingLoadDetailSheet_contributingWorkouts`, `trainingLoadDetailSheet_weekComparison`, `trainingLoadDetailSheet_recoveryCallout`, `trainingLoadDetailSheet_seeInfoButton`, `trainingLoadDetailSheet_configureSettingsButton`, `trainingLoadDetailSheet_emptyState_coldStart`; `weeklyStreakDetailSheet_closeButton`, `weeklyStreakDetailSheet_hero`, `weeklyStreakDetailSheet_statRow`, `weeklyStreakDetailSheet_thisWeekRing`, `weeklyStreakDetailSheet_heatmap`, `weeklyStreakDetailSheet_heatmap_cell_{0..25}`, `weeklyStreakDetailSheet_milestoneShelf`, `weeklyStreakDetailSheet_milestone_{1|4|12|26|52}`, `weeklyStreakDetailSheet_configureSettingsButton`; `powerLevelDetailSheet_closeButton`, `powerLevelDetailSheet_hero`, `powerLevelDetailSheet_topExercises`, `powerLevelDetailSheet_topExerciseRow_{0..2}`, `powerLevelDetailSheet_windowComparison`, `powerLevelDetailSheet_nudge`, `powerLevelDetailSheet_seeInfoButton`; `activityDetailSheet_seeInfoButton`, `activityDetailSheet_configureSettingsButton` (retrofit on existing sheet). Settings Modal Done buttons (Phase 8.8): `weeklyStreakSettings_doneButton`, `trainingLoadSettings_doneButton`, `activityRingsSettings_doneButton`. **Retired:** `activityRingsSettings_resetButton` (Reset to defaults removed entirely in Phase 8.8 — see CONSTANTS.md § Activity Rings → Settings Modal Strings) and `todaysPlanDetailSheet_scheduleMoreButton` (the "+ Schedule another workout for today" chip was removed from the Today's Plan Detail Sheet in the Phase 8.8 follow-up). Tests must not reference retired identifiers.
- Recovery Status widget (Phase 11 — see SCREENS.md § Home Screen → Recovery Status widget, § Recovery Status Settings Modal, § Recovery Status Detail Sheet, § Recovery Status See Info Modal). **Widget:** `homeWidget_recoveryStatus_card`, `homeWidget_recoveryStatus_sleepHero`, `homeWidget_recoveryStatus_sleepValue`, `homeWidget_recoveryStatus_deepSleepCaption`, `homeWidget_recoveryStatus_timerLine`, `homeWidget_recoveryStatus_watermark`, `homeWidget_recoveryStatus_state_connectAppleHealth`, `homeWidget_recoveryStatus_state_sleepAccessDenied`, `homeWidget_recoveryStatus_state_noSleepTracker`, `homeWidget_recoveryStatus_state_live`, `homeWidget_recoveryStatus_connectButton`, `homeWidget_recoveryStatus_openIOSSettingsButton`. **Settings modal:** `recoveryStatusSettings_modal`, `recoveryStatusSettings_targetSleepHoursSlider`, `recoveryStatusSettings_importButton`, `recoveryStatusSettings_doneButton`, `recoveryStatusSettings_closeButton`. **Detail sheet:** `recoveryStatusDetailSheet_sheet`, `recoveryStatusDetailSheet_closeButton`, `recoveryStatusDetailSheet_hero`, `recoveryStatusDetailSheet_stagesBar`, `recoveryStatusDetailSheet_stagesLegend`, `recoveryStatusDetailSheet_sleepEfficiencyCaption`, `recoveryStatusDetailSheet_sleepSparkline`, `recoveryStatusDetailSheet_sleepSparkline_dataPoint_{index}`, `recoveryStatusDetailSheet_sleepSparkline_selectionAnnotation`, `recoveryStatusDetailSheet_last7NightsStatRow`, `recoveryStatusDetailSheet_timeSinceWorkout`, `recoveryStatusDetailSheet_timeSinceWorkout_headline`, `recoveryStatusDetailSheet_timeSinceWorkout_typeRow_{type}` (type ∈ `strengthTraining`, `hiit`, `cardio`, `yoga`, `pilates`, `other`), `recoveryStatusDetailSheet_emptyState_coldStart`, `recoveryStatusDetailSheet_seeInfoButton`, `recoveryStatusDetailSheet_configureSettingsButton`. **See Info modal:** `recoveryStatusSeeInfoModal`, `recoveryStatusSeeInfoModal_closeButton`, `recoveryStatusSeeInfoModal_section_{a..f}`.
- Linked Recovery & Load composite (Phase 11 — see SCREENS.md § Linked Recovery & Load Composite, § Linked Recovery & Load Settings Modal, § Linked Recovery & Load See Info Modal, § Linked Recovery & Load Detail Sheet). **Composite + Training Load linked additions:** `homeWidget_linkedRecoveryLoad_composite`, `homeWidget_trainingLoad_sleepImpactChip`. **Combined long-press menu items:** `linkedMenuItem_seeInfo`, `linkedMenuItem_configureSettings`, `linkedMenuItem_unlinkWidgets`, `linkedMenuItem_reorderWidgets`. **Combined settings modal:** `linkedRecoveryLoadSettings_modal`, `linkedRecoveryLoadSettings_experienceLevelSlider`, `linkedRecoveryLoadSettings_targetWorkoutDurationSlider`, `linkedRecoveryLoadSettings_targetSleepHoursSlider`, `linkedRecoveryLoadSettings_importButton`, `linkedRecoveryLoadSettings_doneButton`, `linkedRecoveryLoadSettings_closeButton`. **Combined detail sheet:** `linkedRecoveryLoadDetailSheet_sheet`, `linkedRecoveryLoadDetailSheet_closeButton`, `linkedRecoveryLoadDetailSheet_dualHero`, `linkedRecoveryLoadDetailSheet_recoveryHero`, `linkedRecoveryLoadDetailSheet_loadHero`, `linkedRecoveryLoadDetailSheet_stagesBar`, `linkedRecoveryLoadDetailSheet_combinedChart`, `linkedRecoveryLoadDetailSheet_combinedSelectionAnnotation`, `linkedRecoveryLoadDetailSheet_windowComparison`, `linkedRecoveryLoadDetailSheet_contributingWorkouts`, `linkedRecoveryLoadDetailSheet_last3Nights`, `linkedRecoveryLoadDetailSheet_timeSinceWorkout`, `linkedRecoveryLoadDetailSheet_timeSinceWorkout_headline`, `linkedRecoveryLoadDetailSheet_timeSinceWorkout_typeRow_{type}` (type ∈ `strengthTraining`, `hiit`, `cardio`, `yoga`, `pilates`, `other`), `linkedRecoveryLoadDetailSheet_recoveryCallout`, `linkedRecoveryLoadDetailSheet_seeInfoButton`, `linkedRecoveryLoadDetailSheet_configureSettingsButton`. **Collapsible insight card chevrons** (per SCREENS.md § Linked Recovery & Load Detail Sheet → Collapsible insight cards, CONSTANTS.md § Linked Recovery & Load Detail Sheet → Collapsible Insight Cards): `linkedRecoveryLoadDetailSheet_windowComparison_chevron`, `linkedRecoveryLoadDetailSheet_last3Nights_chevron`, `linkedRecoveryLoadDetailSheet_contributingWorkouts_chevron`, `linkedRecoveryLoadDetailSheet_timeSinceWorkout_chevron`. **Combined See Info modal:** `linkedRecoveryLoadSeeInfoModal`, `linkedRecoveryLoadSeeInfoModal_closeButton`, `linkedRecoveryLoadSeeInfoModal_section_{a..f}`. **Retired in Phase 11:** the old `pairAppleWatch` Recovery-Status-tier identifier (if drafted) was renamed to `state_noSleepTracker` (source-agnostic) before any code shipped — no test should reference `pairAppleWatch` for Recovery Status (only the Activity Rings widget still uses that token). The stacked two-chart layout on the Linked Recovery & Load Detail Sheet was replaced by a single dual-axis chart (see SCREENS.md § Linked Recovery & Load Detail Sheet → body block 3 and CONSTANTS.md § Linked Recovery & Load Detail Sheet → Combined Sleep & Load Chart), so `linkedRecoveryLoadDetailSheet_sleepSparkline`, `linkedRecoveryLoadDetailSheet_loadSparkline`, `linkedRecoveryLoadDetailSheet_sleepChartSelectionAnnotation`, and `linkedRecoveryLoadDetailSheet_loadChartSelectionAnnotation` are retired — tests must not reference them.

- Power Level Gauge (Phase 12 — see SCREENS.md § Home Screen → Power Level widget, § Power Level Breakdown Sheet → block 1 & block 2; CONSTANTS.md § Power Level Gauge, § Power Level Detail Sheet → Window Comparison Bars). **Widget:** `homeWidget_powerLevel_card`, `homeWidget_powerLevel_deltaCaption`, `homeWidget_powerLevel_gauge`, `homeWidget_powerLevel_gaugeThumb`, `homeWidget_powerLevel_gaugeOverflowIndicator` (BUG-074 — present only when `|pct_change| > 30`) (existing `homeWidget_powerLevel_seeInfo` unchanged). **Retired:** `homeWidget_powerLevel_directionalIndicator` — the indicator glyph was removed from the widget card; tests must not reference it. The glyph still renders on the Breakdown Sheet hero (`powerLevelDetailSheet_hero` covers it). **Breakdown Sheet hero:** `powerLevelDetailSheet_hero`, `powerLevelDetailSheet_heroGauge`, `powerLevelDetailSheet_heroGaugeThumb`, `powerLevelDetailSheet_heroGaugeOverflowIndicator` (BUG-074 — present only when off-scale). **Thumb Pulse:** `homeWidget_powerLevel_gaugeThumbPulse`, `powerLevelDetailSheet_heroGaugeThumbPulse` (present in the view hierarchy when the breathing halo is rendering — i.e., Rising/Deloading, not No-Data, and Reduce Motion off; off-scale states still pulse with the static off-scale halo layered on top — per CONSTANTS.md § Power Level Gauge → Thumb Pulse). **Window comparison bars:** `powerLevelDetailSheet_windowComparison` (unchanged container ID), `powerLevelDetailSheet_windowComparison_deltaChip`, `powerLevelDetailSheet_windowComparison_previousBar`, `powerLevelDetailSheet_windowComparison_currentBar`. Color correctness of the gauge zones/thumb and bar fills is verified via manual QA (XCUI color queries are flaky — same precedent as § Color Treatment Tests).

**Indexed-row pattern for dynamic rows.** When a screen has a list of rows a test needs to target individually (exercises in a workout form, templates in a selection sheet, etc.), suffix the identifier with the row index — and set/column index if the row itself contains multiple inputs:

```swift
// Row 0's name field
.accessibilityIdentifier("exerciseNameInput_0")

// Row 0, Set 0's reps field (exercise 0, set 0)
.accessibilityIdentifier("repsInput_0_0")

// First template row in the selection sheet
.accessibilityIdentifier("templateSelectionRow_0")
```

Use zero-indexing. Apply this pattern any time Claude Code generates a new `ForEach` over data that a UI test will interact with.

**When NOT to use identifiers — match by label text instead.** Some UI elements are matched in tests by their visible label, not by identifier. Don't add identifiers to these, and don't replace the existing label-based matching with identifiers:

- **System alerts** — buttons like "Delete", "Cancel", "Save" in `.alert(...)` modals are matched via `app.alerts.buttons["Delete"]`.
- **Segmented control options** — the individual options inside a segmented toggle (e.g., the "KG" and "LBS" buttons inside `settings_weightUnitToggle`) are matched by label. Apply the identifier to the container only.
- **Swipe-to-delete action buttons** — the revealed action button (e.g., "Trash") is matched by label.
- **Tab bar buttons** (see below).

**Tab bar gotcha.** In SwiftUI, `.accessibilityIdentifier()` applied inside a `TabView`'s tab content attaches to the *content view*, not the tab-bar button. XCUI can only find tab-bar buttons by their visible label text. For this reason, smoke tests use a `Tab` enum with the on-screen labels (`"HOME"`, `"WORKOUTS"`, `"PLAN"`, `"TRENDS"`, `"GOALS"`) instead of identifiers. Do not add `.accessibilityIdentifier("tabBar_home")` etc. to TabView items — it won't do what you expect.

**Central source of truth.** Keep identifier string constants in `AccessibilityIdentifiers.swift` so tests and views reference the same values. Never hardcode identifier strings in tests or views — always use the constants. When adding a new identifier, add it to `AccessibilityIdentifiers.swift` first, then reference it from both the view and the test.

---

## Launch Arguments for UI Tests

UI tests launch the real app, so they need a way to start from a clean state. In `FortiFitApp.swift`, check for launch arguments:

```swift
@main
struct FortiFitApp: App {
    init() {
        if CommandLine.arguments.contains("--uitesting") {
            // Skip onboarding animations, reduce animation durations, etc.
        }
        if CommandLine.arguments.contains("--reset-state") {
            // Wipe SwiftData store and UserDefaults for a clean test run
        }
    }
    // ...
}
```

Each UI test then launches with those arguments (see `SmokeTests.swift`).

---

## The Bug Fix → Regression Test Rule

Every entry in `BUGS.md` that gets resolved should have a corresponding regression test. This is the single most valuable testing habit for a long-lived codebase.

**Workflow:**

1. You log a bug in `BUGS.md` with repro steps.
2. You (or Claude Code) fix the bug.
3. Before marking the bug **Resolved**, write a test that would have failed before the fix and passes after.
4. Place the test in the appropriate target based on what it exercises:
   - A formula bug → `FortiFitTests`
   - A cascade bug → `FortiFitIntegrationTests`
   - A UI/navigation bug → `FortiFitUITests`
5. Reference the bug ID in the test's doc comment.

Example:

```swift
/// Regression test for BUGS.md #23:
/// Editing a workout's date did not recompute the GoalSnapshot on
/// the NEW date — only the old date got updated.
func test_editingWorkoutDate_recomputesSnapshotsOnBothDates() throws {
    // ...
}
```

Over time this builds a test suite that reflects exactly the categories of bugs your codebase is prone to. Same bug category never bites twice.

---

## Shared Test Fixtures

Integration tests share helpers via `TestFixtures.swift` in the `FortiFitIntegrationTests` target:

- `inMemoryContainer()` — returns a `ModelContainer` backed by an isolated in-memory store.
- `makeWorkout(...)` — factory for creating a `Workout` + `ExerciseSet`s.
- `makeStrengthPRGoal(...)`, `makeRepsPRGoal(...)`, `makeSpeedDistanceGoal(...)` — factories for each goal type.
- `makeTemplate(...)` — factory for a `WorkoutTemplate`.
- `daysAgo(_:)` — computes a `Date` N days before now (for testing date-scoped logic).
- `StubHealthKitClient` — in-memory stub conforming to the `HealthKitClient` protocol. Seed with fixture `HKWorkout`-equivalent structs; supports controlled "incoming workout," "upstream delete," and "upstream update" simulations. See HEALTHKIT.md § 19 Testing Strategy.
- `makeHKWorkoutFixture(...)` — factory for `HKWorkout`-equivalent fixture data (HK activity type, start/end dates, duration, distance, HR stats, energy, elevation, effort score, source bundle ID). Used to seed `StubHealthKitClient`.
- `makeLinkedWorkout(...)` — factory for a FitNavi `Workout` with `healthKitUUID`, `healthKitSourceBundleID`, and `healthKitActivityType` pre-populated; for testing link-aware logic without going through the full import path.

If you find yourself repeating setup code across tests, add it to `TestFixtures.swift`.

---

## HealthKit Test Strategy

HealthKit integration (Phase 8 — see HEALTHKIT.md) is tested via protocol stubbing. Real HealthKit calls never happen in automated tests; the simulator's HealthKit support is limited and background delivery does not fire in simulator.

### Protocol Stubbing

All HealthKit access goes through the `HealthKitClient` protocol (see SERVICES.md § HealthKitClient). Tests inject `StubHealthKitClient` from `TestFixtures.swift` instead of the concrete `DefaultHealthKitClient`. The stub exposes methods to seed fixture HK workouts, simulate upstream deletes, and simulate upstream updates without going through any Apple framework.

**Rule:** no test file outside `StubHealthKitClient` itself imports `HealthKit`. If you find yourself needing to, stop — the coverage belongs in manual QA, not an automated test.

### Test Distribution by Target

| Target | Scenarios |
|--------|-----------|
| `FortiFitTests` (unit) | HK-to-FortiFit category mapping (every entry in HK_MAPPING.md resolves correctly, including the "Other" fallback). `WorkoutMatcher` time-window rules in isolation (5-minute overlap buffer; 4-hour prompt threshold; same-day non-overlapping rejection). Field ownership rule application (HK-owned vs user-owned). Auto-create default field value construction (name formatting, `lastModifiedDate = .now`, empty sets/notes). 2-minute minimum-duration floor. `rpeFromHK` provenance flag — defaults `false` on manual log, set `true` only when iOS 18+ nil-fill populates `rpe`, cleared to `false` when the user mutates `rpe`. |
| `FortiFitIntegrationTests` | Auto-create from HK import fires full Workout Cascade (Training Load, Streak, Speed/Distance goals, GoalSnapshot). Link flow from both directions (HK-arrives-first and manual-log-first). Upstream delete nulls pointer + bumps `lastModifiedDate` without firing deletion cascade. `WorkoutMatchRejection` persistence blocks re-proposal. iOS 18 `workoutEffortScore` imports into `rpe` only when nil; never overwrites user-entered RPE. Sprints → Cardio one-time migration is idempotent. **Unlink** (HEALTHKIT § 14): clears the three HK pointer fields AND the six HK-only summary fields (`avgHeartRate`, `maxHeartRate`, `activeEnergyKcal`, `totalEnergyBurnedKcal`, `elevationAscendedMeters`, `exerciseMinutes`); clears `rpe` only when `rpeFromHK == true` and clears the flag in either case; retains `durationMinutes` / `distanceKm` / `date` / user-owned fields; bumps `lastModifiedDate`; fires the full Workout Cascade (Effort Trend chart points + Training Load recompute when `rpe` was cleared); writes a `WorkoutMatchRejection` blocking re-link of the same `(uuid, workoutId)` pair. |
| `FortiFitUITests` | Settings "Apple Health" section toggle states (off, on-granted, on-denied). Workout Detail source indicator renders with correct `HKSource.name` and opens info sheet on tap. Unlink flow via both entry points (ellipsis menu, info sheet button) — confirmation dialog displays the updated title "Unlink workout from Apple Health?" and the deletion-warning message; on confirm, Summary stat cards for cleared HK-only fields disappear from the grid. Source Indicator Info Sheet Row 2 callout displays the updated subline mentioning data deletion. Match Prompt Sheet actions (Link / Keep Separate / Decide Later) produce correct state changes. Log Workout disabled fields (`durationMinutes`, `distanceKm`, `date`) show inline `info.circle` popovers and are non-editable when `healthKitUUID != nil`. |

### Requires Manual QA (Not Automatable)

These scenarios require a real device and cannot be covered by automated tests. Log them in a manual QA checklist before every TestFlight build:

- Real HK observer query wake-up from background after a Watch workout ends.
- `BGAppRefreshTask` execution under iOS throttling.
- Force-quit recovery: kill the app, record a Watch workout, relaunch → workout appears via catch-up sync.
- Persisted `HKQueryAnchor` survives app termination and simulator resets.
- iOS authorization prompt UX on first toggle-on (copy, ordering of permission rows).
- Denial path: deny permission in iOS Settings → FitNavi Settings status line shows "Permission denied" with working deep link.
- `workoutEffortScore` round-trip on a real iOS 18 device (set score in Fitness app → appears in FitNavi `rpe` after next sync, when `rpe` was nil).

### Identifier Constants

All HealthKit-related accessibility identifiers are listed in the "HealthKit:" row of the § Accessibility Identifiers representative examples above. As with all identifiers, they live as string constants in `AccessibilityIdentifiers.swift` and are referenced from both views and tests — never hardcoded.

---

## WorkoutKit Test Strategy (Phase 8.7)

WorkoutKit integration (Phase 8.7 — see WORKOUTKIT.md) is tested via protocol stubbing, mirroring the HealthKit pattern. Real WorkoutKit calls never happen in automated tests; the simulator's WorkoutKit support is limited and the Watch's Scheduled section can't be observed from iOS tests.

### Protocol Stubbing

All WorkoutKit access goes through the `WorkoutSchedulerProtocol` protocol (see SERVICES.md § WorkoutSchedulerProtocol). Tests inject `StubWorkoutScheduler` from `TestFixtures.swift` instead of the concrete `DefaultWorkoutScheduler`. The stub records every `schedule` and `removePlan` call and exposes assertion helpers (e.g., `assertScheduled(uuid:atDate:)`, `assertRemoved(uuid:)`, `enumerateScheduled()`).

**Rule:** no test file outside `StubWorkoutScheduler` itself imports `WorkoutKit`. If you find yourself needing to, stop — the coverage belongs in manual QA, not an automated test.

### Test Distribution by Target

| Target | Scenarios |
|--------|-----------|
| `FortiFitTests` (unit) | **Outbound HK type mapping** correctness (Strength Training → `.traditionalStrengthTraining`; HIIT → `.highIntensityIntervalTraining`; per HK_MAPPING.md § Outbound Mapping). **Plan composition rules** (per WORKOUTKIT.md § 6): one block per exercise; one `IntervalStep(.work)` per set; recovery step inserted between sets when `restSeconds != nil`; no recovery after final set in each block; correct goal-type resolution (`.time` for time, `.open` for reps); step display name format across all four `(displayAsTime, weightKg)` permutations. **REST PER SET range validation** (5–600 in 5s increments). **`displayAsTime` resolution** against `isometricExerciseNames` Set and `ambiguousExerciseDefaultModes` map (CONSTANTS.md). **`ExerciseSuggestionService.isIsometric(_:)`** alias resolution + dictionary fallback + ambiguous-default fallback. **Sync gate logic** (5 conditions per WORKOUTKIT.md § 7). **`ScheduledWorkout.appleWorkoutPlanId` lifecycle** — stamped on first sync, retained across off/on cycles, cleared on record deletion. |
| `FortiFitIntegrationTests` | **Plan-ID fast-path:** synthetic HK snapshot with `workoutPlanId` matching an existing `ScheduledWorkout` → `PlanService.completeFromWatch(...)` fires, `Workout` created with HK-owned fields, `ExerciseSet`s preserve `restSeconds` and `displayAsTime`, `ScheduledWorkout.status = "completed"`, `WatchScheduleService.removePlan(_:)` called, full Workout Cascade fires. **Plan-ID with deleted ScheduledWorkout** → falls through to matcher path. **Plan-ID with already-completed ScheduledWorkout** → falls through to matcher path. **Edit Planned Workout flow:** edit a synced `ScheduledWorkout` → `WatchScheduleService.resync(_:)` is called with same UUID. **Recurrence edit "this and future":** each affected synced instance gets re-sync individually. **Master toggle off:** all plans removed via `removePlan` loop; per-card flags retained. **Master toggle on:** reconciliation re-schedules previously-synced cards. **Auth revoked mid-session:** next operation gracefully degrades; status line updates; per-card flags retained. **Past-dated sweep on foreground:** stale plans removed. **12-week recurrence regen:** new instances inherit `syncToAppleWatch` from most recent sibling; if true, `schedule(_:)` is called. **`ScheduledWorkout` deletion:** `removePlan` is called before SwiftData delete if `appleWorkoutPlanId != nil`. |
| `FortiFitUITests` | **Settings master toggle states** (off; on-granted; on-denied via Stub denial) — toggle visibility, status line copy, "Open iOS Settings" button visibility. **Plan card glyph states** (active/green, inactive/muted, disabled/0.4-opacity) and tap behavior (active → off, inactive → on, disabled → popover). **Master Sync Off popover** — taps card glyph or Edit Planned Workout toggle while master off, popover appears, "Open Settings" navigates in-app. **Edit Planned Workout flow** — long-press planned card → Edit Workout context menu item → screen opens → fields pre-populated → edit → save → recurrence prompt for recurring instance. **REST PER SET picker** opens duration picker, range/increments correct, info.circle popover visible. **REPS/TIME segmented control** flips column header and input type; flip preserves integer values. **Date-change forces "this only"** in recurrence prompt. **Past-dated card glyph** is muted and non-tappable (or tap is no-op). |

### Requires Manual QA (Not Automatable)

These scenarios require a real device and cannot be covered by automated tests. Log them in a manual QA checklist before every TestFlight build:

- Real-Watch round-trip: schedule on phone → workout appears in Watch's Scheduled section → user starts → completes → resulting `HKWorkout.workoutPlan?.id` carries the plan UUID → FitNavi marks the slot completed via plan-ID fast-path on next foreground.
- WorkoutKit's actual upsert behavior (`schedule` with existing UUID): does it replace or error?
- Authorization prompt UX on first toggle-on (copy, dialog flow).
- Denial path: deny in iOS Settings → FitNavi Settings status line shows "Permission denied" with working deep link.
- watchOS 10 paired Watch behavior — the iOS API succeeds, but plans don't appear on Watch (silently). Static caveat copy makes this honest.
- Background reconciliation when Watch session completes while FitNavi is closed — verify the workout shows up correctly when FitNavi is next foregrounded.

### Identifier Constants

All Apple Watch push–related accessibility identifiers are listed in the "Apple Watch push (Phase 8.7 + 8.7.1 …)" row of the § Accessibility Identifiers representative examples above.

---

## Color Treatment Tests (Phase 8.5 polish)

The Workout Detail stat-card and Metric Detail Sheet color rules are visual — no new accessibility identifiers, no behavior changes, but two narrow unit-test surfaces:

- **`AppConstants.effortColor(for:)`** — `FortiFitTests` should iterate every integer from 1 through 10 and assert the returned color matches the band defined in CONSTANTS.md § Effort Color Mapping (1–4 green, 5–6 yellow, 7–10 red). Same shape as the existing `effortLabel(for:)` test.
- **Stat card and detail sheet color application** — UI smoke tests can't reliably assert on colors via XCUI (color queries are flaky and brittle), so color correctness is verified via manual QA on first-build review rather than automated tests. Document any visual regressions in BUGS.md per the standard workflow.

---

## Effort Bars Test Strategy

The `FortiFitEffortBars` component (CONSTANTS.md § Effort Bars Glyph) replaces the Effort SF Symbol on the Workout Detail Summary stat card and the Metric Detail Sheet Effort hero. Tests live in `FortiFitTests/FortiFitEffortBarsTests.swift` (Swift Testing).

- **Tier mapping** — `FortiFitEffortBars.litBarCount(forRPE:)` returns the expected lit-bar count for every rpe 1–10 (Easy=1, Light=2, Moderate=3, Hard=4, All Out=5) and returns 0 for out-of-range inputs (`< 1` or `> 10`).
- **Tier-to-label alignment** — for each rpe 1–10, the lit-bar tier matches the bucket boundary in `AppConstants.effortLabel(for:)` so the glyph and label tell the same story (single source of truth for the 5-band mapping).
- **Lit color provenance** — lit bars use `AppConstants.effortColor(for:)` directly (verified by the existing color-band test); no separate per-bar color helper exists, so no extra assertion is needed.
- **UI smoke** — `FortiFitUITests` asserts the two new identifiers are reachable: `workoutDetail_summaryCard_effortBars` on the Workout Detail Summary Effort card and `metricDetailSheet_hero_effortBars` after tapping into the Effort detail sheet. Colors are not asserted (per § Color Treatment Tests above) — verify visually.

---

## Widget Detail Sheet Test Strategy (Phase 8.8)

The four new widget detail sheets and three settings-modal Done buttons (Today's Plan, Training Load, Weekly Streak, Power Level + Activity Detail Sheet retrofit) are tested via the same three-target split as the rest of the app. Calculated logic in services lives in unit tests; cascade-aware behavior lives in integration; presentation and tap routing lives in UI smoke.

### Test Distribution by Target

| Target | Scenarios |
|--------|-----------|
| `FortiFitTests` (unit) | **`StreakService.fetchHeatmap(weeks:)`** — returns exactly N cells, index 0 = most recent week, current-week cell has `.inProgress` status, untracked cells precede the user's first workout. **`StreakService.thisWeekProgress()`** — `currentCount` matches in-week workout count; `daysRemainingThisWeek` is 0 on Sunday EOD and 6 on Monday 00:00. **`StreakService.historySummary()`** — `unlockedMilestones` matches `[1, 4, 12, 26, 52]` filter against `currentStreak`; `nextUnlockedMilestone` is nil when all unlocked; `totalWeeksLogged` count is target-current-aware (matches retroactive recalc semantics). **`ExerciseLoadService.fourteenDayDailyScores()`** — returns 14 entries today-inclusive, scores match the per-day algorithm replay. **`ExerciseLoadService.contributingWorkouts(daysBack:limit:)`** — max 5 rows, sorted by descending training-load contribution (`tssContribution` field, surfaced as "training load" in user-facing copy), `percentOfWeeklyLoad` sums to ≤ 100. **`ExerciseLoadService.weekOverWeekComparison()`** — uses same Mon–Sun week definition as Streak; deltaPct is 0 when previous week training-load total is 0. **`PowerLevelService.topContributingExercises(limit:)`** — ≥ 3-session filter excludes one-off exercises; sort tie-break order matches spec; returns 0–3 entries. **`PowerLevelService.windowComparison()`** — surfaces existing intermediates without recompute. **`PowerLevelService.computeNudge()`** — archetype resolution: `coldStart` when < 3 in-window workouts (overrides status); `.deloading` / `.steady` / `.rising` map to their archetypes; steady-with-no-top-exercise gracefully degrades to cold-start. **`PlanService.fetchTodaysScheduledWorkouts()`** — returns all statuses (planned, completed, skipped) when `scheduledDate == today`; ordering by `scheduledTime` then `sortOrder`; nil times sort last; completed rows from yesterday do NOT appear after midnight rolls over (date-filter test, not time-based). |
| `FortiFitIntegrationTests` | **Widget tap routing edit-mode suppression** — drive `HomeViewModel` into edit mode → assert tap on every widget type returns `WidgetDetailRoute.suppressed`. **Workout Cascade re-fetches helpers when detail sheet is presented** — present each detail sheet, fire a workout-save cascade, assert each helper was called once and the sheet's published state updated. **Today's Plan Detail Sheet — Complete button cascade** — tap Complete on a `Planned` row → confirms in the compact confirmation sheet → assert `PlanService.completeScheduled` fires, full Workout Cascade runs (Training Load, Streak, Power Level recompute), row's status pill updates to `Completed`, action button updates to the disabled-checkmark state, and the row stays in place (no reorder). **Completed-row visibility windowing** — complete a scheduled workout today → assert row visible in today's sheet → advance system clock past midnight → assert row no longer appears in tomorrow's sheet. **Power Level nudge cold-start fallback** — seed 2 Strength workouts in the last 30 days → assert archetype is `coldStart` even when status is `.rising`. **Steady-with-no-top-exercise fallback** — seed 5 Strength workouts each on a different exercise (no exercise has ≥ 3 sessions) → assert nudge archetype resolves to coldStart copy. **Settings modal Done button parity** — open each of the three modals → assert Done button dismisses identical to close X → assert slider values persisted to `UserSettings` regardless of dismissal path. **Activity Rings Settings Modal — Reset to defaults removed** — assert there is no `activityRingsSettings_resetButton` element in the modal. |
| `FortiFitUITests` | **Tap-to-open per widget** — from Home, tap each of the five widgets, assert the corresponding sheet ID is present (`todaysPlanDetailSheet_closeButton`, etc.). **Edit mode tap suppression** — enter edit mode via long-press → tap each widget → assert no sheet opens (per Phase 11 doc-drift fix, no "x" delete buttons render — deletion is via long-press context menu after exiting edit mode). **Today's Plan Detail Sheet — Complete flow** — tap Complete on a Planned row → confirm in compact confirmation sheet → assert row status pill updated to Completed and stays visible. **Today's Plan Detail Sheet — Schedule More chip** — tap chip from populated state → assert sheet dismisses and Plan tab Scheduling Flow opens. **Training Load Detail Sheet — footer navigation** — tap See Info → assert Widget Info Modal opens after sheet dismiss; tap Configure Settings → assert Training Load Settings Modal opens. **Activity Detail Sheet retrofit — footer navigation** — same pattern for the existing Activity Detail Sheet (`activityDetailSheet_seeInfoButton`, `activityDetailSheet_configureSettingsButton`). **Settings modal Done buttons** — open each modal, tap Done, assert modal dismisses. **Weekly Streak heatmap tap** — tap a heatmap cell, assert tooltip appears with correct copy. **Power Level Breakdown Sheet top-exercise tap** — tap a row → assert sheet dismisses and Trends → Strength Tracker chart detail opens pre-filtered to that exercise. **Cold-start states** — wipe SwiftData → open each detail sheet → assert per-block empty-state copies render where applicable. |

### Required Reading for Widget Detail Sheet Tests

When writing tests for this phase, the prompts to Claude Code should reference:
- **SCREENS.md** § Standard Patterns → Home Widget Tap-to-Open, § Today's Plan Detail Sheet, § Training Load Detail Sheet, § Weekly Streak Insights Sheet, § Power Level Breakdown Sheet, § Activity Detail Sheet (footer retrofit)
- **SERVICES.md** § Streak Algorithm → Weekly Streak Insights Helpers, § Power Level Algorithm → Top Contributing Exercises / Window Comparison / Nudge Computation, § Training Load Algorithm → Detail Sheet Helpers, § HomeWidgetService → Widget Tap Routing, § PlanService → Retrieval (`fetchTodaysScheduledWorkouts`)
- **CONSTANTS.md** § Widget Detail Sheet Visual Tokens, § Weekly Streak Insights, § Training Load Detail Sheet, § Power Level Detail Sheet, § Today's Plan Detail Sheet, § Settings Modal Done Button, § Widget Tap Behavior
- **INFO_COPY.md** § Power Level Nudge Copy, § Widget Detail Sheet Empty States

### Identifier Constants

All Phase 8.8 accessibility identifiers are listed in the "Widget Detail Sheets (Phase 8.8 …)" row of the § Accessibility Identifiers representative examples above. As with all identifiers, they live as string constants in `AccessibilityIdentifiers.swift` and are referenced from both views and tests — never hardcoded. The retired `activityRingsSettings_resetButton` constant must be deleted from `AccessibilityIdentifiers.swift` as part of this phase.

---

## Recovery Status & Widget Linking Test Strategy (Phase 11)

The Recovery Status widget, Linked Recovery & Load composite, sleep-adjusted Training Load decay path, and the new `DailySleepSnapshot` / `DailyTrainingLoadSnapshot` entities are tested via the same three-target split as the rest of the app. Algorithm math lives in unit tests; cross-service cascades and gating-state transitions live in integration; presentation, tap routing, and link/unlink behavior live in UI smoke.

### Test Distribution by Target

| Target | Scenarios |
|--------|-----------|
| `FortiFitTests` (unit) | **`RecoveryStatusService.sleepFactor(sleepHours:targetSleepHours:)`** — match SERVICES.md § Training Load Algorithm → Sleep-Adjusted Decay: ratio `≥ 1.0` → `1.0`, ratio `0.5` → `0.80`, ratio `≤ 0.0` → floor `0.60`, nil → `1.0` (missing-data fallback). **Wake-up-date attribution** — given a fixture batch of `.asleep*` samples spanning 6pm yesterday through 6pm today, assert all samples ending within the window aggregate into the correct `DailySleepSnapshot.wakeUpDate`; samples ending at exactly 6pm boundary go to the *prior* day. **Daytime nap inclusion** — 30-min nap + 8-h overnight on same wake-up day → `totalSleepMinutes` = 510. **Sleep efficiency** — `inBedMinutes == nil` → `sleepEfficiencyPercent == nil`; computed values round per HEALTHKIT.md § 21 → DailySleepSnapshot Persistence. **Deep-sleep percentage** — rounding rules per HEALTHKIT.md § 21; `totalAsleep == 0` → returns nil. **`hasRecentSleepData(within: 14)`** — true on first `.asleep*` match in 14-day window; false when only `.inBed` samples present in window. **`RecoveryStatusGatingState` derivation** — exercise all 4 input combinations of `healthKitEnabled` × `sleepScopeGranted` × `hasRecentSleepData` and assert the correct enum case. **`computeLinkedAdvisory()`** — joint advisory keyed on (zone, trainedToday, sleepBucket). BUG-061 regression coverage: each contradiction cell (Low/Moderate/Resting × untrained × moderatelyBelow/significantlyBelow) returns a single sentence that clamps intensity — never a contradictory concat. `metTarget` (0.85–0.99) and missing-data (nil) inputs return the base advisory unchanged. `strong` (≥ 1.0) produces a joint sentence (positive sleep note woven in, not appended). Matches CONSTANTS § Training Load Zones → Linked Advisory Copy. **`computeSleepLoadCorrelation()`** — fixture with N=14 paired days, median-split at 7h, assert `correlationDelta` sign and the copy-variant selection (`delta <= -5` → `highSleepBetter`; `delta >= +5` → `lowSleepWorse`; else `noPattern`). **`HomeWidgetService.isLinkedActive(widgets:settings:)`** — all 5 gate rules in order: manual-unlink flag, presence of both widgets, adjacency, RS gating state == `.live`. Each rule has a positive and negative case. **`ExerciseLoadService.computeCurrentScore(workouts:sleepData:targetSleepHours:)`** — sleep-adjusted decay produces a higher score than baseline when sleep was below target across the 10-day window; equal score when all days met target; missing-data days silently fall back to baseline `sleepFactor = 1.0`. **`captureDailySnapshot()`** — idempotency (same inputs → no SwiftData write); upsert by date (today's record gets rewritten, historical immutable); `wasSleepAdjusted` reflects `isLinkedActive` at capture time. **`recoveryLoadManuallyUnlinked` flag clearing** — set the flag → reorder operation that changes either widget's `sortOrder` → assert flag cleared; reorder operation that does NOT change `sortOrder` → assert flag retained. |
| `FortiFitIntegrationTests` | **Sleep Cascade — observer fire** — given a `StubHealthKitClient` that delivers a new sleep sample, fire `RecoveryStatusService.handleSleepObserverFire()` → assert `DailySleepSnapshot` upserted, 30-day cache appended, widget view-model `todaysSnapshot` republished. **Sleep Cascade — linked TL score recompute** — set up linked composite, fire sleep observer with below-target sleep → assert today's `DailyTrainingLoadSnapshot` rewritten with `wasSleepAdjusted == true` AND new score higher than the prior baseline. **Sleep Cascade — unlinked is a no-op for TL** — set up unlinked Recovery Status + Training Load, fire sleep observer → assert today's `DailyTrainingLoadSnapshot` NOT rewritten and TL widget score unchanged. **6pm-cutoff catch-up** — advance system clock past local 6pm without observer fire → `scenePhase` returns to `.active` → assert `refresh(forceCatchUp: true)` ran exactly once. Subsequent foregrounds within the same 6pm window do not re-run (guarded by `lastSleepCatchUpDate`). **Auto-link on adjacency** — start with Recovery Status + Training Load non-adjacent → reorder so they become adjacent (and RS in `.live`, flag false) → assert `isLinkedActive == true` and composite container renders with shared border. **Auto-unlink on gating degradation** — start with linked composite → revoke sleep scope via stub → assert `currentGatingState` transitions to `.sleepAccessDenied`, `isLinkedActive == false`, composite container collapses to two independent cards with the 0.2s animation. **Manual unlink + sticky flag** — from linked state, invoke "Unlink Widgets" from long-press menu → assert `recoveryLoadManuallyUnlinked == true` and composite collapses; widget reorder that does NOT change `sortOrder` → flag retained; reorder that DOES change `sortOrder` → flag clears and composite re-establishes if all gates pass. **Workout Cascade — Recovery Status timer-line bump** — log a workout → assert `RecoveryStatusService.timeSinceLastWorkoutFormatted` republishes; sleep portion of widget unaffected. **Workout Cascade — `DailyTrainingLoadSnapshot` today rewrite** — log a workout → assert today's `DailyTrainingLoadSnapshot` upserted with the new score + current `wasSleepAdjusted` value; historical snapshots untouched. **Sleep observer — debounce** — fire 5 sleep observer events in 200ms → assert Sleep Cascade body ran exactly once (500ms debounce trailing edge). **`importSleepGoalFromAppleHealth()` happy path** — stub returns 8.0 hr goal → assert `UserSettings.targetSleepHours == 8.0`; stub returns nil → assert toast emitted, settings unchanged. **Sleep scope first grant → backfill** — start with sleep scope ungranted, no sleep observer registered → user grants → assert observer registered AND immediate 30-day backfill query ran. **Trends `trainingLoadTrend` snapshot-aware rendering** — seed 14 days of `DailyTrainingLoadSnapshot` records with mixed `wasSleepAdjusted` values → assert chart renders snapshot values for historical days and computes today's value live; toggling linking only affects future captures. |
| `FortiFitUITests` | **Add Recovery Status from Add Widgets menu** — assert row is enabled regardless of HK state; tap → widget renders in the appropriate gating state. **Four gating states** — drive `UserSettings` + sleep auth to each of the 4 states, assert correct `homeWidget_recoveryStatus_state_*` identifier present and correct CTA visible. **Connect Apple Health CTA** — tap → assert in-app navigation to Settings → Apple Health section. **Sleep Access Denied CTA** — tap the `homeWidget_recoveryStatus_openIOSSettingsButton` → assert `UIApplication.openSettingsURLString` deep-link fires (verify via launch-argument capture). **No Sleep Tracker tap** — assert no-op (no navigation, no sheet). **Tap Recovery Status widget in Live state** — assert `recoveryStatusDetailSheet_sheet` presented. **Detail sheet — Time Since Last Workout headline tap** — assert sheet dismisses and Workout Detail of most recent workout opens. **Detail sheet — per-type row tap** — assert sheet dismisses and Workouts tab opens with that type's card expanded. **Cold-start empty CTA** — wipe SwiftData → open detail sheet → tap `Log a Workout` CTA → assert sheet dismisses and Log Workout screen opens. **Settings Modal — Sleep Target slider** — drag slider, tap Done, reopen → assert persisted value. **Settings Modal — Import button disabled state** — toggle Apple Health off → reopen modal → assert Import button disabled with caption visible. **Auto-link on drag** — start with widgets non-adjacent → enter Widget Edit Mode → drag Recovery Status into a slot adjacent to Training Load → drop → assert `homeWidget_linkedRecoveryLoad_composite` present (with the 0.2s border-swap animation visible). **Manual unlink** — long-press composite → tap `linkedMenuItem_unlinkWidgets` → assert composite collapses to two independent cards. **Linked composite — both cards open combined detail sheet** — tap RS card → assert `linkedRecoveryLoadDetailSheet_sheet` opens; dismiss; tap TL card → assert same combined sheet opens (not standalone Training Load Detail Sheet). **Linked composite — combined long-press menu** — assert exactly 4 items render (See Info → Configure Settings → Unlink Widgets → Reorder Widgets) with no `Delete Widget` item. **Sleep Impact Chip rendering** — set up linked composite with below-target sleep → assert `homeWidget_trainingLoad_sleepImpactChip` present, copy matches `↑ +{N} from sleep`, color Alert Red. **See Info modal — Recovery Status** — long-press widget → See Info → assert `recoveryStatusSeeInfoModal` present with all 6 sections (`_section_a` through `_section_f`). **See Info modal — Linked** — long-press composite → See Info → assert `linkedRecoveryLoadSeeInfoModal` with all 6 sections. **Widget Edit Mode no-x-button assertion** — enter edit mode on any widget → assert no `widget_*_deleteButton` or similar "x" element exists on screen (regression test for the BUGS.md doc-drift fix). |

### Required Reading for Recovery Status Tests

When writing tests for this phase, the prompts to Claude Code should reference:

- **SCREENS.md** § Standard Patterns → Widget Linking, § Home Screen → Widget Definitions → Recovery Status, § Recovery Status Settings Modal, § Recovery Status Detail Sheet, § Recovery Status See Info Modal, § Linked Recovery & Load Composite, § Linked Recovery & Load Settings Modal, § Linked Recovery & Load See Info Modal, § Linked Recovery & Load Detail Sheet
- **SERVICES.md** § RecoveryStatusService, § Training Load Algorithm → Sleep-Adjusted Decay / Daily Snapshot Capture, § Sleep Cascade, § HomeWidgetService → Widget Linking + Widget Tap Routing, § HealthKitClient (sleep methods), § HealthKitSyncService (sleep observer + BG refresh)
- **HEALTHKIT.md** § 17 (sleep authorization types + scope expansion note), § 21 (Sleep Data — full spec)
- **CONSTANTS.md** § Recovery Status Widget, § Recovery Status Settings Modal, § Recovery Status Detail Sheet, § Linked Recovery & Load, § Linked Recovery & Load Settings Modal, § Linked Recovery & Load Detail Sheet, § Training Load Zones → Linked Advisory Copy, § Add Widgets Menu Order, § Widget Types
- **INFO_COPY.md** § Widget Info Modal Copy → recoveryStatus / linkedRecoveryLoad / Training Load (Linking with Recovery Status section), § Chart Info Modal Copy → Training Load Trend (About this chart's calculation), § Widget Detail Sheet Empty States (Phase 11), § Training Load Zones → Linked Advisory Copy

### Identifier Constants

All Phase 11 accessibility identifiers are listed in the two new "Recovery Status widget …" and "Linked Recovery & Load composite …" rows of the § Accessibility Identifiers representative examples above. They live as string constants in `AccessibilityIdentifiers.swift` per CLAUDE.md.

### Untestable (Requires Manual QA)

- Real HK sleep observer query wake-up from background (Apple Watch sync overnight)
- `BGAppRefreshTask` execution timing
- iOS sleep-scope authorization prompt UX
- Reduce Motion behavior on the 0.2s border-swap and 0.4s score tween animations (XCUI cannot reliably introspect Core Animation timing)
- Real `UIApplication.openSettingsURLString` deep-link landing on the Apple Health → FitNavi privacy screen (only the fire is testable via launch-argument capture)

---

## Power Level Gauge Test Strategy (Phase 12)

The Power Level gauge redesign adds **no new service logic** — it re-renders existing `PowerLevelService` outputs (`status`, `windowComparison()`). Coverage is therefore weighted toward a small unit surface (position math) plus UI smoke (render + routing). Color correctness is manual QA per § Color Treatment Tests precedent.

### Test Distribution by Target

| Target | Scenarios |
|--------|-----------|
| `FortiFitTests` (unit) | **Gauge position mapping** — a pure helper `powerLevelGaugePosition(pctChange:)` (or the view-model equivalent) returns `0.0` at `pct ≤ −30`, `1.0` at `pct ≥ +30`, `0.5` at `pct == 0`, and `(clamp(pct,−30,30)+30)/60` for interior values; boundary values −10 / +10 map to `0.333…` / `0.666…`. **Clamp honesty** — for `pct = +212`, position is `1.0` but the delta caption string still reads `+212% vs prior 30d` (caption is not clamped). **No-data state** — when `baseline_avg == 0` or `< 3` qualifying workouts, the view-model exposes the no-data gauge state (Steady track, `—` indicator, "No data" copy) and a nil thumb position. **Status→color/glyph mapping** — Deloading→`↓`/red, Steady→`—`/gray, Rising→`↑`/green (extend the existing status mapping test). **Overflow indicator (BUG-074)** — `FortiFitPowerLevelGauge.overflowDirection(for:)` returns `.positive` for `pct > +30` (strict), `.negative` for `pct < −30` (strict), and `nil` at the boundary (±30 exactly), in-range, and no-data (`nil`). |
| `FortiFitIntegrationTests` | **Gauge recompute on Workout Cascade** — present the Home (or the Breakdown Sheet), log/edit/delete a Strength workout that flips `pct_change` across a threshold (e.g. Steady→Rising) → assert the widget/sheet view-model republishes the new `status`, thumb position, and delta caption in one cascade pass. **Overflow indicator on cascade (BUG-074)** — seed a workout history where current `pct_change` sits within ±30%, then log a high-volume workout that pushes `deltaPct` past +30%; assert the gauge's `overflowDirection(for:)` flips from `nil` to `.positive` after a single cascade pass while the thumb position stays clamped at `1.0`. **Window comparison bars empty-hide** — seed a state where `previous30dAvg == 0` → assert the block-2 bars model reports hidden; seed both windows populated → assert visible with `previousBar`/`currentBar` scaled to the larger average. **Bars reuse existing intermediates** — assert `windowComparison()` is read, not recomputed, by the bars view-model (no extra fetch). |
| `FortiFitUITests` | **Widget render** — Home shows `homeWidget_powerLevel_gauge` + `homeWidget_powerLevel_gaugeThumb` + `homeWidget_powerLevel_deltaCaption`; assert the status **word** is absent from the card and the directional indicator glyph is absent (the glyph now renders only on the Breakdown Sheet hero). **Tap-to-open** — tap the card → `powerLevelDetailSheet_hero` present; assert `powerLevelDetailSheet_heroGauge` renders and no status word is shown in the hero. **Window comparison bars** — assert `powerLevelDetailSheet_windowComparison_previousBar`, `..._currentBar`, `..._deltaChip` present in a populated state; wipe to a single-window state → assert the block is absent. **Cold-start** — wipe SwiftData → open the sheet → assert the hero no-data copy renders and the bars block is hidden. **VoiceOver label** — assert the gauge's accessibility label contains the status word + percent (color-independent state); when `|pct_change| > 30`, assert it additionally contains `"Off-scale — past +30%."` (or `−30%`). |

### Required Reading for Power Level Gauge Tests

When writing tests for this phase, the prompts to Claude Code should reference:
- **SCREENS.md** § Home Screen → Power Level widget, § Power Level Breakdown Sheet (block 1 hero, block 2 window comparison bars)
- **SERVICES.md** § Power Level Algorithm → Widget & Hero Gauge Position, → Window Comparison Computation
- **CONSTANTS.md** § Power Level Gauge, § Power Level Statuses, § Power Level Detail Sheet → Hero / Window Comparison Bars
- **IMPLEMENTATION_PLAN_PHASE_12.md** (build steps + identifier inventory)

### Identifier Constants

All Phase 12 identifiers are listed in the "Power Level Gauge (Phase 12 …)" row of the § Accessibility Identifiers representative examples above. They live as string constants in `AccessibilityIdentifiers.swift` and are referenced from both views and tests — never hardcoded.

---

## Prompting Claude Code

Generic template that adapts to any test type:

> "Read [SPEC.md] § [section]. Write [unit / integration / UI smoke] tests in the style of `[ExistingTestFile].swift` that verify each rule in that section. Use `TestFixtures.swift` helpers (and `StubHealthKitClient` for HK work — never import `HealthKit` in tests). Add the file to the `[FortiFitTests / FortiFitIntegrationTests / FortiFitUITests]` target."

For regression tests, append: "Reference BUGS.md #[N] in the test's doc comment. The test should fail against the pre-fix code and pass after."

---

## Companion Documents

| Document | Contents |
|----------|---------|
| `SERVICES.md` | Service specs and cascade definitions — primary reference when writing integration tests |
| `SCREENS.md` | Screen layouts and flows — primary reference when writing smoke tests |
| `HEALTHKIT.md` | HealthKit integration spec — primary reference when writing HealthKit-related unit, integration, or UI tests. Protocol stubbing pattern and test distribution in § 19 |
| `BUGS.md` | Bug log — source for regression test cases |
