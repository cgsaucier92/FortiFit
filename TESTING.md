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
- Cards: `workoutTypeCard_StrengthTraining`, `goalCard_benchPress`, `scheduledWorkoutCard_0`, `workoutDetail_summaryCard_effort`, `workoutDetail_summaryCard_duration`, `workoutDetail_summaryCard_distance`, `workoutDetail_summaryCard_avgHR`, `workoutDetail_summaryCard_maxHR`, `workoutDetail_summaryCard_activeKcal`, `workoutDetail_summaryCard_totalKcal`, `workoutDetail_summaryCard_elevation`, `workoutDetail_summaryCard_exerciseMinutes`, `metricDetailSheet_closeButton`
- HealthKit: `settings_appleHealthToggle`, `settings_appleHealthSyncNowButton`, `settings_appleHealthOpenSettingsButton`, `workoutDetail_healthSourceIndicator`, `workoutDetail_healthUnlinkButton`, `matchPromptSheet_linkButton`, `matchPromptSheet_keepSeparateButton`, `matchPromptSheet_decideLaterButton`
- HealthKit (Phase 8.5+ Source Info Sheet redesign): `sourceInfoSheet_readOnlyCallout`, `sourceInfoSheet_permanentUnlinkCallout`, `sourceInfoSheet_doneButton`, `sourceInfoSheet_unlinkConfirmButton`, `sourceInfoSheet_unlinkCancelButton`, `sourceInfoSheet_lastSyncedRow`, `logWorkout_hkFieldInfoIcon_date`, `logWorkout_hkFieldInfoIcon_startTime`, `logWorkout_hkFieldInfoIcon_duration`, `logWorkout_hkFieldInfoIcon_distance`
- Activity Rings widget (`appleActivity`): `homeWidget_appleActivity_card`, `homeWidget_appleActivity_state_connectAppleHealth`, `homeWidget_appleActivity_state_pairAppleWatch`, `homeWidget_appleActivity_connectButton`, `homeWidget_appleActivity_moveRing`, `homeWidget_appleActivity_exerciseRing`, `homeWidget_appleActivity_standRing`, `homeWidget_appleActivity_weeklyClosureChip`
- Activity Rings Settings Modal: `activityRingsSettings_moveSlider`, `activityRingsSettings_exerciseSlider`, `activityRingsSettings_standSlider`, `activityRingsSettings_resetButton`, `activityRingsSettings_importButton`
- Activity Detail Sheet: `activityDetailSheet_closeButton`, `activityDetailSheet_range7d`, `activityDetailSheet_range30d`, `activityDetailSheet_moveSparkline`, `activityDetailSheet_exerciseSparkline`, `activityDetailSheet_standSparkline`, `activityDetailSheet_closureHeatmap`
- Trends chart cards (Phase 6.1 — see SCREENS.md § Standard Patterns → Trends Chart Card Visual Treatment): `trendsChart_{chartId}_card`, `trendsChart_{chartId}_headerSummary`, `trendsChart_workoutTypeBreakdown_centerLabel`
- Trends chart detail view (Phase 6.2 — see SCREENS.md § Trends Chart Detail and CONSTANTS.md § Trends Chart Detail View): `trendsChart_{chartId}_expandButton`, `trendsChartDetail_{chartId}_card`, `trendsChartDetail_{chartId}_backButton`, `trendsChartDetail_{chartId}_headerSummary`, `trendsChartDetail_{chartId}_seeInfoButton`, `trendsChartDetail_{chartId}_rangeToggle_{rangeRawValue}` (e.g. `..._rangeToggle_30d`, `..._rangeToggle_1y`), `trendsChartDetail_{chartId}_dataPoint_{index}` (selection target — only on charts where selection is enabled per CONSTANTS.md § Trends Chart Detail View → Selection State), `trendsChartDetail_{chartId}_selectionAnnotation`, `trendsChartDetail_personalRecords_timelinePoint_{index}` (PR timeline only), `trendsChartDetail_workoutTypeBreakdown_legendRow_{index}` (donut legend only), `trendsChartDetail_workoutTypeBreakdown_legendSortHeader_{column}` (column ∈ `count`, `percent`, `type`, `avgDuration`)
- Cross-app back navigation chevron (Phase 6.2 — see SCREENS.md § Standard Patterns → Back Navigation Chevron): `{screenId}_backButton` — e.g., `workoutDetail_backButton`, `addGoal_backButton`, `settings_backButton`, `trendsChartDetail_strengthTracker_backButton`

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
| `FortiFitTests` (unit) | HK-to-FortiFit category mapping (every entry in HK_MAPPING.md resolves correctly, including the "Other" fallback). `WorkoutMatcher` time-window rules in isolation (5-minute overlap buffer; 4-hour prompt threshold; same-day non-overlapping rejection). Field ownership rule application (HK-owned vs user-owned). Auto-create default field value construction (name formatting, `lastModifiedDate = .now`, empty sets/notes). 2-minute minimum-duration floor. |
| `FortiFitIntegrationTests` | Auto-create from HK import fires full Workout Cascade (Training Load, Streak, Speed/Distance goals, GoalSnapshot). Link flow from both directions (HK-arrives-first and manual-log-first). Upstream delete nulls pointer + bumps `lastModifiedDate` without firing deletion cascade. `WorkoutMatchRejection` persistence blocks re-proposal. iOS 18 `workoutEffortScore` imports into `rpe` only when nil; never overwrites user-entered RPE. Sprints → Cardio one-time migration is idempotent. Unlink clears pointer fields but retains HK-sourced numeric values. |
| `FortiFitUITests` | Settings "Apple Health" section toggle states (off, on-granted, on-denied). Workout Detail source indicator renders with correct `HKSource.name` and opens info sheet on tap. Unlink flow via both entry points (ellipsis menu, info sheet button). Match Prompt Sheet actions (Link / Keep Separate / Decide Later) produce correct state changes. Log Workout disabled fields (`durationMinutes`, `distanceKm`, `date`) show inline `info.circle` popovers and are non-editable when `healthKitUUID != nil`. |

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

## Color Treatment Tests (Phase 8.5 polish)

The Workout Detail stat-card and Metric Detail Sheet color rules are visual — no new accessibility identifiers, no behavior changes, but two narrow unit-test surfaces:

- **`AppConstants.effortColor(for:)`** — `FortiFitTests` should iterate every integer from 1 through 10 and assert the returned color matches the band defined in CONSTANTS.md § Effort Color Mapping (1–4 green, 5–6 yellow, 7–10 red). Same shape as the existing `effortLabel(for:)` test.
- **Stat card and detail sheet color application** — UI smoke tests can't reliably assert on colors via XCUI (color queries are flaky and brittle), so color correctness is verified via manual QA on first-build review rather than automated tests. Document any visual regressions in BUGS.md per the standard workflow.

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
