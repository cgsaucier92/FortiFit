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
- Menus: `homeEllipsisMenu`, `workoutsEllipsisMenu`, `workoutDetailEllipsis`, `addWidgetsMenuItem`, `saveAsTemplateMenuItem`, `viewSavedTemplatesMenuItem`
- Cards: `workoutTypeCard_StrengthTraining`, `goalCard_benchPress`, `scheduledWorkoutCard_0`

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

If you find yourself repeating setup code across tests, add it to `TestFixtures.swift`.

---

## Prompting Claude Code

When adding new integration tests, this prompt pattern works well:

> "Read SERVICES.md § [specific section]. Write integration tests in the style of `WorkoutCascadeIntegrationTests.swift` that verify each bullet in that section fires correctly. Use `TestFixtures.swift` helpers. Add the file to the `FortiFitIntegrationTests` target."

For UI smoke tests:

> "Read SCREENS.md § [screen name]. Add an XCUI smoke test to `SmokeTests.swift` that exercises the primary user flow on that screen end-to-end. Use accessibility identifiers matching the convention in TESTING.md."

For regression tests:

> "Here's the bug from BUGS.md #[N]: [paste]. Write a test that would have failed before the fix and passes after. Place it in the appropriate target and reference the bug number in the doc comment."

---

## Companion Documents

| Document | Contents |
|----------|---------|
| `SERVICES.md` | Service specs and cascade definitions — primary reference when writing integration tests |
| `SCREENS.md` | Screen layouts and flows — primary reference when writing smoke tests |
| `BUGS.md` | Bug log — source for regression test cases |
