# CLAUDE.md: FitNavi Development Guide

> Quick-reference for Claude Code. This document contains coding conventions, constraints, and the development roadmap.
> For full specs, reference the companion docs listed at the bottom.

---

## Key Constraints

- **SwiftUI only** — No UIKit unless absolutely necessary (then wrap in UIViewControllerRepresentable in Core/Utilities/)
- **@Observable** — Do NOT use ObservableObject + @Published
- **SwiftData @Model** — All persistent entities use SwiftData, not Core Data
- **No third-party dependencies** — Native frameworks only (Swift Charts, SwiftData)
- **iOS 17+ minimum** — Leverage modern Swift features
- **Zero business logic in Views** — All logic in ViewModels or Services
- **UserDefaults only for preferences** — No structured data in UserDefaults
- **Mockups are visual guides, not specs** — Before styling any screen, review the corresponding mockup in Design/Mockups/ and MOCKUPS.md. Match the visual feel, not the specific content. If a mockup conflicts with PRD.md, the PRD always wins.
- **Tests live in the right target** — Unit tests → `FortiFitTests` (Swift Testing). Integration tests → `FortiFitIntegrationTests` (XCTest). UI smoke tests → `FortiFitUITests` (XCTest). Do not mix frameworks within a target. See `TESTING.md` for the full rationale.

---

## Bug Logging

When you encounter a bug, build failure, or unexpected behavior during development, log it to BUGS.md before attempting a fix. Each entry should include:

- **Date** (YYYY-MM-DD)
- **Phase and feature** (e.g., "Phase 2 — WorkoutService")
- **Description** (what went wrong)
- **Root cause** (once identified)
- **Resolution** (what fixed it)
- **Status** (Open / Resolved)

Do not delete resolved entries — mark them as Resolved and leave them for reference. If a bug recurs, reference the original entry rather than creating a duplicate.

---

## Testing

FitNavi has three test types, each in its own Xcode target. See `TESTING.md` for full conventions, setup, and accessibility identifier rules.

**Framework per target (do not mix):**
- `FortiFitTests` — Unit tests, Swift Testing (`@Test`, `#expect`)
- `FortiFitIntegrationTests` — Integration tests, XCTest (`XCTestCase`, `XCTAssert...`)
- `FortiFitUITests` — UI smoke tests, XCTest (required — UI testing is XCTest-only)

**Choosing the right test type:**
- A formula, conversion, validator, or single-service rule → Unit test.
- A workflow that crosses services (e.g., logging a workout updates a goal AND a snapshot AND the streak) → Integration test in `FortiFitIntegrationTests`. Use `TestFixtures.swift` helpers.
- A screen rendering, button existing, or end-to-end user flow → UI smoke test in `FortiFitUITests`.

**Rules:**
- After adding or changing any SERVICES.md cascade, add 2–3 integration tests in `FortiFitIntegrationTests` before marking the feature complete.
- Before marking a BUGS.md entry as Resolved, add a regression test in the appropriate target and reference the bug number in the test's doc comment.
- Every interactive SwiftUI element touched by a UI test must have an `.accessibilityIdentifier(...)`. Identifier constants live in `AccessibilityIdentifiers.swift` — add new ones there, never hardcode strings in tests or views.
- Test method names use `test_situation_expectedOutcome` format (readable as a sentence in the test navigator, doubles as spec documentation).
- Never weaken or delete a failing test to make it pass. A failing test means either the code is wrong or the spec changed — fix the code, or update the test AND the spec document together in the same change.

---

## Session Hygiene

At the end of each development session, before closing or pausing work:

- All three test targets should be in a passing state (`FortiFitTests`, `FortiFitIntegrationTests`, `FortiFitUITests`). If a test was left failing intentionally (e.g., written before the code that satisfies it), log it in BUGS.md with status "Open — pending implementation" so it isn't forgotten.
- Any new bug or unexpected behavior noticed during the session is logged in BUGS.md before the session ends, even if unresolved.
- Any spec change made during the session is reflected in the appropriate doc (PRD.md / SCREENS.md / SERVICES.md / CONSTANTS.md) — code and spec must not drift across sessions.
- If the session added new interactive UI, verify each element has an `.accessibilityIdentifier(...)` before wrapping up.

---

## Out of Scope (Do Not Build)

- Social features, multi-user (single-workout image export and template QR sharing are in scope — see SCREENS.md § Workout Detail, SCREENS.md § Saved Templates List)
- Subscriptions or IAP
- Apple Watch app
- Third-party device integration (Garmin, Whoop, Fitbit)
- Cloud sync or user accounts
- HealthKit write-back (FortiFit → HealthKit). HealthKit **read** integration is in scope as of Phase 8 — see HEALTHKIT.md. Write-back remains deferred indefinitely; see HEALTHKIT.md § 2 Scope and § 20 Future Phases.
- Nutrition tracking
- Mental health or mindfulness features
- Sleep tracking
- Onboarding flow

---

## Development Phases

### Phase 1: Foundation
**Goal:** App launches, compiles, navigable skeleton with placeholder screens.

| Feature | Where to find spec |
|---------|-------------------|
| Project scaffold (all folders/stubs) | PRD.md § Project Structure |
| Tab navigation (5 tabs) | PRD.md § Navigation Flow |
| Theme system (colors, typography, spacing) | PRD.md § Design Language, CONSTANTS.md |
| Reusable FortiFit components | PRD.md § Project Structure (Design/Components/) |
| Settings shell | SCREENS.md § Settings |
| UserSettings (UserDefaults singleton) | PRD.md § Data Model (UserSettings) |

### Phase 2: Data Layer
**Goal:** Core persistence works independently of UI. All CRUD testable.

| Feature | Where to find spec |
|---------|-------------------|
| Workout, ExerciseSet, Goal, GoalSnapshot models | PRD.md § Data Model |
| WorkoutService (CRUD + cascade) | SERVICES.md § WorkoutService |
| GoalService (progress calc + auto-update) | SERVICES.md § Goal Auto-Update |
| GoalSnapshotService (sparkline data) | SERVICES.md § GoalSnapshotService |
| ExerciseLoadService (Training Load algorithm) | SERVICES.md § Training Load Algorithm |
| StreakService (streak algorithm) | SERVICES.md § Streak Algorithm |
| WorkoutTypeOrder model + service | PRD.md § Data Model, SERVICES.md § WorkoutTypeOrderService |
| WorkoutTemplate + TemplateExerciseSet models | PRD.md § Data Model |
| ScheduledWorkout model | PRD.md § Data Model |
| WorkoutTemplateService | SERVICES.md § WorkoutTemplateService |
| PlanService (scheduling, completion, recurrence, date resolution) | SERVICES.md § PlanService |
| Unit conversion (kg↔lbs, km↔miles) | kg × 2.205 = lbs; km × 0.621371 = miles |
| ExerciseSuggestionService | SERVICES.md § ExerciseSuggestionService |

### Phase 3: Core UI
**Goal:** All screens built and connected to SwiftData.

| Feature | Where to find spec |
|---------|-------------------|
| Accessibility identifiers on all interactive elements | Every button, text field, tab, and navigation control gets `.accessibilityIdentifier(...)` using constants from `AccessibilityIdentifiers.swift`. Required for UI smoke tests and VoiceOver. See TESTING.md § Accessibility Identifiers. |
| Home screen (widgets, CTA, recent workouts) | SCREENS.md § Home Screen |
| Settings screen (3 groups, 6 controls) | SCREENS.md § Settings |
| Workout list (type cards, expand/collapse, pagination, search, sort/filter) | SCREENS.md § Workouts |
| Log Workout (form, type-adaptive, templates, autocomplete) | SCREENS.md § Log Workout |
| Exercise name autocomplete (FortiFitExerciseAutocomplete) | SERVICES.md § ExerciseSuggestionService |
| Workout Detail (breakdown, edit, delete, save as template) | SCREENS.md § Workout Detail |
| Edit Workout (pre-populated, type locked, trash) | SCREENS.md § Log Workout (Edit Mode) |
| Goals screen (progress rings, SF Symbol silhouettes, expandable sparkline, ellipsis menu) | SCREENS.md § Goals |
| Add Goal (type selector, conditional fields) | SCREENS.md § Add Goal |
| Progress screen (4 charts, thresholds, auto-update) | SCREENS.md § Progress |
| Template screens (Create, Saved List, edit mode) | SCREENS.md § Create Template, Saved Templates |
| Workouts + Log Workout ellipsis menus | SCREENS.md § Workouts, Log Workout |

### Phase 4: Home Screen Customization & Power Level
**Goal:** Home fully user-customizable with Power Level widget.

| Feature | Where to find spec |
|---------|-------------------|
| HomeWidget model | PRD.md § Data Model (HomeWidget) |
| HomeWidgetService (CRUD, seeding, reorder) | SERVICES.md § HomeWidgetService |
| PowerLevelService (30-day volume comparison) | SERVICES.md § Power Level Algorithm |
| Dynamic widget rendering | SCREENS.md § Home Screen (Widget Card System) |
| Widget edit mode (long-press, delete, drag reorder) | SCREENS.md § Home Screen (Widget Edit Mode). Add identifiers for delete "x" buttons and drag handles in `AccessibilityIdentifiers.swift`. |
| Add Widget menu (ellipsis → overlay) | SCREENS.md § Home Screen (Add Widget Menu). Add identifiers for ellipsis, each widget row's Add button, and dismiss control. |
| Power Level widget | SCREENS.md § Home Screen (Widget Definitions), CONSTANTS.md § Power Level |

### Phase 5: Polish & Secondary Features
**Goal:** Animations, edge cases, auto-detection.

| Feature | Where to find spec |
|---------|-------------------|
| Progress bar animations (0.4s) | PRD.md § Interaction Style |
| Save button transitions (0.2s) | PRD.md § Interaction Style |
| Empty states (all screens, per-chart) | SCREENS.md (States tables per screen), CONSTANTS.md § Chart Thresholds |
| Hint tooltips ("?" on Training Load, Effort, Power Level) | PRD.md § Design Language (Contextual Hints) |
| Goal drag-and-drop | SCREENS.md § Goals |
| PR auto-detection | SERVICES.md § Goal Auto-Update |
| Edge cases (missing data, zero targets, BW, long names, backdated workouts, edit/delete cascading) | SERVICES.md § Deletion Cascading Behavior; add integration tests in `FortiFitIntegrationTests` |
| Workout share image export (share icon, image card, share sheet) | SCREENS.md § Workout Detail (Share Image Card), SERVICES.md § WorkoutShareService |
| Template QR sharing (QR generation, deep link import, context menus) | SCREENS.md § Saved Templates List (Share Template QR Modal), SCREENS.md § Template Import Prompt, SERVICES.md § TemplateShareService |

### Phase 6: Trends Screen v2
**Goal:** Trends screen fully customizable with new charts and redesigned Personal Records.

| Feature | Where to find spec |
|---------|-------------------|
| TrendsChart model | PRD.md § Data Model (TrendsChart) |
| TrendsChartService (CRUD, seeding, reorder) | SERVICES.md § TrendsChartService |
| Dynamic chart rendering by sortOrder | SCREENS.md § Trends (Chart Card System) |
| Chart context menu (long-press → Delete Chart, Reorder Charts) | SCREENS.md § Trends (Chart Card Context Menu). Add identifiers for each menu action. |
| Chart reorder edit mode (drag handles) | SCREENS.md § Trends (Reorder Edit Mode). Add identifiers for drag handles. |
| Trends ellipsis menu → Add Charts overlay | SCREENS.md § Trends (Add Charts Menu). Add identifiers for ellipsis, each chart row's Add button, and dismiss control. |
| FortiFitAddChartMenu component | Mirrors FortiFitAddWidgetMenu |
| Personal Records redesign (exercise dropdown, bar chart) | SCREENS.md § Trends (PR Definition, PR Layout, PR Edge Cases) |
| Workout Volume chart | SCREENS.md § Trends (Chart Definitions), CONSTANTS.md § Chart Types |
| Effort Trend chart | SCREENS.md § Trends (Chart Definitions), CONSTANTS.md § Chart Types |
| Workout Type Breakdown chart | SCREENS.md § Trends (Chart Definitions), CONSTANTS.md § Chart Types |
| Session Duration chart | SCREENS.md § Trends (Chart Definitions), CONSTANTS.md § Chart Types |
| Chart deletion cascading | SERVICES.md § Deletion Cascading Behavior (Chart Deletion) |
| Updated empty states (all charts removed, per-chart thresholds) | SCREENS.md § Trends (States), CONSTANTS.md § Chart Data Thresholds |

### Phase 7: Plan (Workout Scheduler)
**Goal:** Users can schedule workouts in advance and complete them with minimal friction.

| Feature | Where to find spec |
|---------|-------------------|
| Plan screen (week strip, month grid, day detail) | SCREENS.md § Plan |
| Schedule Workout flow (template selection, date, time, recurrence) | SCREENS.md § Plan (Scheduling Flow) |
| Complete Planned Workout (compact confirmation sheet) | SCREENS.md § Plan (Complete Planned Workout Flow) |
| Date resolution logic (today, past, future) | SCREENS.md § Plan (Date Resolution Logic), SERVICES.md § PlanService |
| Skip / Restore / Remove from Plan scheduled workouts | SCREENS.md § Plan (Long-Press Context Menu) |
| Recurring workout management (edit/delete this or future) | SCREENS.md § Plan (Editing Recurring Workouts) |
| Recurrence auto-regeneration (12-week lookahead) | SERVICES.md § PlanService |
| Today's Plan HomeWidget | SCREENS.md § Home Screen (Widget Definitions), CONSTANTS.md § Widget Types |
| "Schedule This Template" context menu on Saved Templates | SCREENS.md § Saved Templates List |
| FortiFitWeekStrip, FortiFitMonthGrid, FortiFitScheduledWorkoutCard components | PRD.md § Project Structure (Design/Components/) |
| Workout deletion → ScheduledWorkout revert | SERVICES.md § Deletion Cascading Behavior, SERVICES.md § PlanService |
| Logged-only workout surfacing on Plan (dots, cards, LOGGED badge, tap-to-detail) | SCREENS.md § Plan (Day Detail Area, Logged-Only Workout Surfacing); PRD.md § Data Model (Workout.hiddenFromPlan); SERVICES.md § PlanService (Retrieval → Fetch Plan surface) |
| "Remove from Plan" unified long-press action (all card types, with completed-card dual-action and recurrence handling) | SCREENS.md § Plan (Long-Press Context Menu); SERVICES.md § PlanService (Remove from Plan) |
| "Show on Plan" conditional ellipsis item in Workout Detail | SCREENS.md § Workout Detail (Ellipsis Menu); CONSTANTS.md § SF Symbols |
| Today's Plan widget green dot for logged-only workouts | SCREENS.md § Home Screen (Today's Plan widget, Right column) |

### Phase 8: HealthKit Integration
**Goal:** Workouts recorded on Apple Watch (or any Health-connected source) auto-import into FortiFit. Bidirectional matching, linking, and unlinking. UI surfaces the HealthKit relationship. Read-only — no write-back.

Phases 1 and 2 in HEALTHKIT.md ship together as a single implementation pass. Catch-up-on-launch (anchored queries) is Phase 1; live background delivery (observer queries + `BGAppRefreshTask`) is Phase 2.

| Feature | Where to find spec |
|---------|-------------------|
| `HealthKitClient` protocol + `DefaultHealthKitClient` concrete | HEALTHKIT.md § 4 Architecture Decisions; SERVICES.md § HealthKitClient |
| New `Workout` fields (`healthKitUUID`, `healthKitSourceBundleID`, `healthKitActivityType`, `avgHeartRate`, `maxHeartRate`, `activeEnergyKcal`, `totalEnergyBurnedKcal`, `elevationAscendedMeters`, `exerciseMinutes`, `indoor`) | HEALTHKIT.md § 5 Data Model; PRD.md § Data Model |
| `WorkoutMatchRejection` entity | HEALTHKIT.md § 5 Data Model; PRD.md § Data Model |
| HK-to-FortiFit workout type mapping table (static) | HEALTHKIT.md § 6 Workout Type Taxonomy; CONSTANTS.md § HealthKit Mapping |
| Sprints → Cardio one-time migration | HEALTHKIT.md § 18 Platform and Migration |
| Field ownership rules (HK-owned vs user-owned) | HEALTHKIT.md § 7 Field Ownership |
| `HealthKitSyncService` (catch-up on launch, observer queries, background refresh, deleted-object handler) | HEALTHKIT.md § 9 Sync Lifecycle; SERVICES.md § HealthKitSyncService |
| Auto-create flow + 2-minute minimum-duration floor | HEALTHKIT.md § 10 Auto-Create Flow |
| Upstream delete handling (null out pointer, bump `lastModifiedDate`, no cascade) | HEALTHKIT.md § 11 Upstream Updates and Deletes; SERVICES.md § HealthKitSyncService |
| Upstream update handling (HK wins on HK-owned fields) | HEALTHKIT.md § 11 Upstream Updates and Deletes |
| `WorkoutMatcher` service (bidirectional, tiered confidence, rejection-aware) | HEALTHKIT.md § 12 Deduplication; SERVICES.md § WorkoutMatcher |
| Workout Cascade fires on HK import (reuses existing cascade) | SERVICES.md § Deletion Cascading Behavior → Workout Cascade |
| `workoutEffortScore` import into `rpe` (nil-fill only, iOS 18+ gated) | HEALTHKIT.md § 8 Effort Score |
| Match Prompt Sheet (sheet-on-foreground, side-by-side summary, 3 actions) | HEALTHKIT.md § 13 Prompt UX; SCREENS.md § Match Prompt Sheet |
| Unlink action (three entry points: ellipsis, info sheet, Log Workout helper) | HEALTHKIT.md § 14 Unlink; SCREENS.md § Workout Detail (Ellipsis Menu) |
| Workout Detail source indicator + info sheet + Summary two-column grid (HK-linked) | HEALTHKIT.md § 15 UI Surfaces; SCREENS.md § Workout Detail |
| Log Workout read-only fields (`durationMinutes`, `distanceKm`, `date`) + helper text | HEALTHKIT.md § 15 UI Surfaces; SCREENS.md § Log Workout |
| Peripheral HK glyph on Home, Workouts, Plan | HEALTHKIT.md § 15 UI Surfaces; SCREENS.md § Home, § Workouts, § Plan |
| Settings "Apple Health" section (toggle, status line, Sync Now, iOS deep link) | HEALTHKIT.md § 16 Settings; SCREENS.md § Settings (Apple Health Section) |
| Authorization flow + Info.plist `NSHealthShareUsageDescription` | HEALTHKIT.md § 17 Authorization |
| New accessibility identifiers (see HEALTHKIT.md § 19 for list) | HEALTHKIT.md § 19 Testing Strategy; TESTING.md |
| Unit / integration / UI tests for the above | HEALTHKIT.md § 19 Testing Strategy |

### Phase 9: Launch Prep
**Goal:** Ready for TestFlight or App Store.

| Feature | Notes |
|---------|-------|
| All three test targets passing | `FortiFitTests`, `FortiFitIntegrationTests`, `FortiFitUITests` must all pass green before any TestFlight build. No skipped or disabled tests without a BUGS.md entry explaining why. |
| App icon + launch screen | Blue ✦ on dark background |
| App Store metadata | Screenshots, description, keywords |
| Privacy manifest | Nutrition labels for local data, passes Xcode validation |
| Performance testing | < 2s launch, 60fps scroll, no leaks |
| TestFlight beta | Builds, installs, all features work |

---

## Companion Documents

| Document | Contents | When to reference |
|----------|---------|------------------|
| `PRD.md` | App overview, design language, project structure, data models, navigation, screen summaries | Always — the core context doc |
| `SCREENS.md` | Full screen layouts, state tables, interaction details | Building or modifying any View |
| `SERVICES.md` | Algorithms, service specs, deletion/edit cascading, goal auto-update | Building or modifying any Service or ViewModel |
| `CONSTANTS.md` | AppConstants values, colors, exercise dictionary, messages, reference tables | Defining constants, theming, referencing values |
| `HEALTHKIT.md` | HealthKit integration spec: architecture, phases, data model additions, field ownership, sync lifecycle, matcher, UI surfaces, Settings | Building or modifying any HealthKit-related service, UI surface, or test; reference alongside SERVICES.md and SCREENS.md for Phase 8 work |
| `TESTING.md` | Test target structure, framework-per-target rules, naming conventions, accessibility identifier conventions, shared fixture usage, regression test workflow | Always — reference whenever writing or modifying tests |
| `BUGS.md` | All bugs, build failures, and unexpected behavior | Logging any bugs, build failures, or unexpected behavior |
