# CLAUDE.md: FitNavi Development Guide

> Always-loaded router. Constraints, workflow rules, and a phase-indexed table of contents pointing into the heavier specs (PRD, SCREENS, SERVICES, CONSTANTS, HEALTHKIT, TESTING, INFO_COPY, HK_MAPPING).

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
- **Naming convention** — The product is **FitNavi** (use in user-facing copy, prose, and product-level references). The codebase namespace is **FortiFit** (use for Swift identifiers, file names, Xcode targets/schemes, and component prefixes like `FortiFitCard`). Both are intentional — the app was renamed but the code wasn't refactored. When in doubt: would the compiler care? FortiFit. Would a user see it? FitNavi.

---

## Bug Logging

Log every bug, build failure, or unexpected behavior to BUGS.md *before* attempting a fix. Required fields: date (YYYY-MM-DD), phase/feature, description, root cause, resolution, status (Open / Resolved). Never delete resolved entries — mark them Resolved. If a bug recurs, reference the original entry, don't duplicate.

---

## Testing

Three targets, framework-per-target (don't mix): `FortiFitTests` (unit, Swift Testing), `FortiFitIntegrationTests` (cross-service workflows, XCTest), `FortiFitUITests` (smoke tests, XCTest). Pick by scope: single-service rule → unit; cross-service cascade → integration; screen render / user flow → UI smoke.

Non-negotiables — after any SERVICES.md cascade change, add 2–3 integration tests before marking complete; before marking a BUGS.md entry Resolved, add a regression test referencing the bug number in its doc comment; every interactive UI element gets an `.accessibilityIdentifier(...)` whose constant lives in `AccessibilityIdentifiers.swift` (never hardcode strings); test names use `test_situation_expectedOutcome`; never weaken a failing test to make it pass.

See `TESTING.md` for setup, naming details, and accessibility-identifier rules.

---

## Session Hygiene

Before closing a session: all three test targets passing (intentionally failing tests must be logged in BUGS.md as "Open — pending implementation"); any new bug logged to BUGS.md even if unresolved; any spec change reflected in the relevant doc (code and spec must not drift); any new interactive UI has `.accessibilityIdentifier(...)`.

---

## Out of Scope (Do Not Build)

- Social features, multi-user (single-workout image export and template QR sharing are in scope — see SCREENS.md § Workout Detail, SCREENS.md § Workout Templates List)
- Subscriptions or IAP
- Native watchOS companion app. WorkoutKit-based outbound scheduling is in scope as of Phase 8.7 — see WORKOUTKIT.md.
- Third-party device integration (Garmin, Whoop, Fitbit)
- Cloud sync or user accounts
- HealthKit write-back (FitNavi → HealthKit). HealthKit **read** integration is in scope as of Phase 8 (workouts/activity) and Phase 11 (sleep) — see HEALTHKIT.md. Write-back remains deferred indefinitely; see HEALTHKIT.md § 2 Scope and § 20 Future Phases.
- Nutrition tracking
- Mental health or mindfulness features
- Onboarding flow

---

## Development Phases

Each phase is a one-line goal plus a feature → spec-ref index. Drill into the referenced doc for detail. Specs win; this is the table of contents.

### Phase 1: Foundation
*App launches and compiles, navigable skeleton with placeholder screens.*

| Feature | Spec |
|---|---|
| Project scaffold (folders/stubs) | PRD § Project Structure |
| Tab navigation (5 tabs) | PRD § Navigation Flow |
| Theme system (colors, typography, spacing) | PRD § Design Language; CONSTANTS |
| Reusable FortiFit components | PRD § Project Structure (Design/Components/) |
| Settings shell | SCREENS § Settings |
| UserSettings (UserDefaults singleton) | PRD § Data Model |

### Phase 2: Data Layer
*Core persistence works independently of UI. All CRUD testable.*

| Feature | Spec |
|---|---|
| Workout, ExerciseSet, Goal, GoalSnapshot models | PRD § Data Model |
| WorkoutService (CRUD + cascade) | SERVICES § WorkoutService |
| GoalService + GoalSnapshotService | SERVICES § Goal Auto-Update, § GoalSnapshotService |
| ExerciseLoadService (Training Load) | SERVICES § Training Load Algorithm |
| StreakService | SERVICES § Streak Algorithm |
| WorkoutTypeOrder + service | PRD § Data Model; SERVICES § WorkoutTypeOrderService |
| WorkoutTemplate + TemplateExerciseSet models + service | PRD § Data Model; SERVICES § WorkoutTemplateService |
| ScheduledWorkout model + PlanService | PRD § Data Model; SERVICES § PlanService |
| Unit conversion | kg × 2.205 = lbs; km × 0.621371 = miles |
| ExerciseSuggestionService | SERVICES § ExerciseSuggestionService |

### Phase 3: Core UI
*All screens built and connected to SwiftData.*

| Feature | Spec |
|---|---|
| Accessibility identifiers everywhere | TESTING § Accessibility Identifiers |
| Home screen | SCREENS § Home Screen |
| Settings | SCREENS § Settings |
| Workouts list (cards, pagination, search, sort/filter) | SCREENS § Workouts |
| Log Workout (form, type-adaptive, templates, autocomplete) | SCREENS § Log Workout; SERVICES § ExerciseSuggestionService |
| Workout Detail | SCREENS § Workout Detail |
| Edit Workout (HK-aware) | SCREENS § Log Workout (Edit Mode); SERVICES § WorkoutTemplateService; HEALTHKIT § 7 |
| Goals + Create Goal | SCREENS § Goals, § Create Goal |
| Progress | SCREENS § Progress |
| Templates (Create, Saved List) | SCREENS § Create Workout Template, § Workout Templates |

### Phase 4: Home Customization & Power Level
*Home fully user-customizable with Power Level widget.*

| Feature | Spec |
|---|---|
| HomeWidget model + service | PRD § Data Model; SERVICES § HomeWidgetService |
| PowerLevelService | SERVICES § Power Level Algorithm |
| Dynamic widget rendering, edit mode, Add Widget menu | SCREENS § Home Screen |
| Power Level widget | SCREENS § Home Screen (Widget Definitions); CONSTANTS § Power Level |

### Phase 5: Polish & Secondary Features
*Animations, edge cases, sharing.*

| Feature | Spec |
|---|---|
| Progress bar + save button animations | PRD § Interaction Style |
| Empty states (per-screen, per-chart) | SCREENS (state tables); CONSTANTS § Chart Thresholds |
| Hint tooltip (Effort input only) | PRD § Design Language |
| Goal drag-and-drop, PR auto-detection | SCREENS § Goals; SERVICES § Goal Auto-Update |
| Edit/delete cascading edge cases | SERVICES § Deletion Cascading Behavior |
| Workout share image export | SCREENS § Workout Detail (Share Image Card); SERVICES § WorkoutShareService |
| Template QR sharing | SCREENS § Workout Templates List, § Template Import Prompt; SERVICES § TemplateShareService |

### Phase 6: Trends Screen v2
*Trends fully customizable; PR redesign.*

| Feature | Spec |
|---|---|
| TrendsChart model + service | PRD § Data Model; SERVICES § TrendsChartService |
| Dynamic chart rendering, context menu, reorder, Add Charts overlay | SCREENS § Trends |
| Personal Records redesign | SCREENS § Trends (PR sections) |
| New charts (Workout Volume, Effort Trend, Type Breakdown, Session Duration) | SCREENS § Trends (Chart Definitions); CONSTANTS § Chart Types |
| Chart deletion cascading | SERVICES § Deletion Cascading Behavior (Chart Deletion) |
| Per-chart empty-state thresholds | CONSTANTS § Chart Data Thresholds |

### Phase 6.1: Trends Chart Visual Polish
*Charts gain Apple-Fitness-style gradient backdrops, per-chart header summary values, smoothed lines, rounded bar tops, latest-point highlights, and donut center label. Add-only — no behavioral changes to existing chart definitions or thresholds.*

| Feature | Spec |
|---|---|
| `FortiFitChartCard` component | PRD § Project Structure (Design/Components/); SCREENS § Standard Patterns (Trends Chart Card Visual Treatment) |
| Per-chart gradient anchors + horizontal split for Personal Records | CONSTANTS § Trends Chart Visual Tokens (Gradient Anchor by Chart Type, Gradient Treatment) |
| Inner plot hairline | CONSTANTS § Trends Chart Visual Tokens (Inner Plot Hairline) |
| Header summary block (hero + caption per chart) | CONSTANTS § Trends Chart Visual Tokens (Header Summary Block); SERVICES § TrendsChartService → Header Summary Computation |
| Latest-point highlight on line charts | CONSTANTS § Trends Chart Visual Tokens (Latest Data-Point Highlight) |
| Smoothed line interpolation (`.catmullRom`) | CONSTANTS § Trends Chart Visual Tokens (Line Interpolation) |
| Rounded bar tops (5pt, top corners) | CONSTANTS § Trends Chart Visual Tokens (Bar Top Corner Radius) |
| Donut center label (Workout Type Breakdown) | SCREENS § Trends; CONSTANTS § Trends Chart Visual Tokens (Donut Center Label) |
| `Chart (Orange)` token migration `#FFA600` → `#FFBF51` | CONSTANTS § Colors |
| Workout Cascade reference to header summary recompute | SERVICES § Workout Cascade |
| Tests + new accessibility identifiers | TESTING |

### Phase 6.2: Trends Chart Detail View
*Per-chart expanded view pushed onto the navigation stack from the compact card. Larger chart with the same visual language; wider time-range toggles; comparison-delta header summary; tap-to-select + drag-to-scrub on data points; inline See Info; swipe-paging between charts; full PR timeline for Personal Records; sortable legend table for Workout Type Breakdown. Also formalizes a cross-app convention swap: `← BACK` text button → left-pointing chevron button on every drill-down screen.*

| Feature | Spec |
|---|---|
| `FortiFitChartDetailView` component | PRD § Project Structure (Design/Components/); SCREENS § Trends Chart Detail |
| Expand button on compact chart card | SCREENS § Trends (Expand Affordance); CONSTANTS § Trends Chart Detail View (Expand Button) |
| Cross-app `chevron.left` back convention | PRD § Interaction Style; SCREENS § Standard Patterns (Back Navigation Chevron) |
| Range toggles per chart (D / W / M / 6M / 1Y / All) | CONSTANTS § Trends Chart Detail View (Range Toggle by Chart Type); SERVICES § TrendsChartService → Data Point Fetch (Detail View) |
| Comparison delta band in header summary | CONSTANTS § Trends Chart Detail View (Header Summary — Detail Variant); SERVICES § TrendsChartService → Comparison Delta Computation |
| Tap-to-select on bars + dots | CONSTANTS § Trends Chart Detail View (Selection State); SCREENS § Trends Chart Detail |
| Drag-to-scrub on line charts | CONSTANTS § Trends Chart Detail View (Scrubber Treatment); SCREENS § Trends Chart Detail |
| Inline See Info entry on detail view | SCREENS § Trends Chart Detail (See Info) |
| Swipe-paging between charts in `sortOrder` | CONSTANTS § Trends Chart Detail View (Swipe Paging); SCREENS § Trends Chart Detail |
| Personal Records detail = full PR timeline | SCREENS § Trends Chart Detail (Per-Chart Detail Variants); SERVICES § TrendsChartService → PR Timeline Fetch |
| Workout Type Breakdown detail = sortable legend table | SCREENS § Trends Chart Detail (Per-Chart Detail Variants); SERVICES § TrendsChartService → Type Breakdown Percentages |
| Full-numeric Y-axis labels on detail | CONSTANTS § Trends Chart Detail View (Y-Axis Label Formatting) |
| Tests + new accessibility identifiers | TESTING |

### Phase 7: Plan (Workout Scheduler)
*Schedule workouts in advance and complete with minimal friction.*

| Feature | Spec |
|---|---|
| Plan screen (week strip, month grid, day detail) | SCREENS § Plan |
| Schedule + Complete + Date Resolution flows | SCREENS § Plan; SERVICES § PlanService |
| Skip / Restore / Remove from Plan | SCREENS § Plan (Long-Press Context Menu); SERVICES § PlanService |
| Recurring workout management + 12-week auto-regeneration | SCREENS § Plan; SERVICES § PlanService |
| Today's Plan HomeWidget (silhouette watermark, context-menu completion; Workout Info widget retired with one-time migration) | SCREENS § Home Screen; SERVICES § HomeWidgetService; CONSTANTS § Widget Types; PRD § Data Model |
| Plan-related components (FortiFitWeekStrip / MonthGrid / ScheduledWorkoutCard) | PRD § Project Structure |
| Workout deletion → ScheduledWorkout revert | SERVICES § Deletion Cascading Behavior, § PlanService |
| Logged-only workout surfacing on Plan; "Show on Plan" / "Remove from Plan" actions | SCREENS § Plan, § Workout Detail; SERVICES § PlanService; PRD § Data Model (Workout.hiddenFromPlan) |

### Phase 8: HealthKit Integration (read-only)
*Workouts from Apple Watch and other Health-connected sources auto-import. Bidirectional matching and linking. No write-back. Phases 1+2 in HEALTHKIT ship together — Phase 1 is catch-up-on-launch, Phase 2 is live observer queries + `BGAppRefreshTask`.*

| Feature | Spec |
|---|---|
| `HealthKitClient` protocol + `DefaultHealthKitClient` | HEALTHKIT § 4; SERVICES § HealthKitClient |
| New Workout fields (10 HK-sourced) + `WorkoutMatchRejection` | HEALTHKIT § 5; PRD § Data Model |
| HK-to-FortiFit type mapping (static) + Sprints → Cardio migration | HEALTHKIT § 6, § 18; HK_MAPPING |
| Field ownership (HK-owned vs user-owned) | HEALTHKIT § 7 |
| `HealthKitSyncService` (catch-up, observer, BG refresh, deletes) | HEALTHKIT § 9; SERVICES § HealthKitSyncService |
| Auto-create flow + 2-min minimum-duration floor | HEALTHKIT § 10 |
| Upstream update + delete handling | HEALTHKIT § 11; SERVICES § HealthKitSyncService |
| `WorkoutMatcher` (bidirectional, tiered confidence, rejection-aware) | HEALTHKIT § 12; SERVICES § WorkoutMatcher |
| `workoutEffortScore` import (iOS 18+, nil-fill only) | HEALTHKIT § 8 |
| Match Prompt Sheet + Unlink action | HEALTHKIT § 13, § 14; SCREENS § Match Prompt Sheet, § Workout Detail |
| Workout Detail source indicator + info sheet + Summary grid | HEALTHKIT § 15; SCREENS § Workout Detail |
| Log Workout read-only fields + info popovers | HEALTHKIT § 15; SCREENS § Log Workout |
| Peripheral HK glyph (Home, Workouts, Plan) | HEALTHKIT § 15; SCREENS § Home, § Workouts, § Plan |
| Settings "Apple Health" section + authorization + Info.plist | HEALTHKIT § 16, § 17; SCREENS § Settings |
| Tests + accessibility identifiers | HEALTHKIT § 19; TESTING |

### Phase 8.5: Workout Detail Summary Redesign + Source Indicator Polish
*Summary becomes a 2-column grid of bordered, tappable stat cards opening a per-metric detail sheet (comparative average + 30-day sparkline + optional PR chip). Effort renders as a label (Easy/Light/Moderate/Hard/All Out). Apple Watch source renames to "Apple Workout"; source indicator format and glyph scoping updated.*

| Feature | Spec |
|---|---|
| `FortiFitStatCard` + `FortiFitMetricDetailSheet` components | SCREENS § Workout Detail; PRD § Project Structure |
| `WorkoutMetricService` (comparativeAverage, sparkline, isPersonalBest) | SERVICES § WorkoutMetricService |
| Effort SF Symbol swap + 1–10 → label mapping + Log Workout dropdown format | CONSTANTS § Workout Detail Summary Icons, § Effort Label Mapping; SCREENS § Log Workout |
| Effort label propagation (Match Prompt Sheet, Share Image Card) | SCREENS § Match Prompt Sheet, § Share Image Card |
| Source indicator format change + Apple Watch → "Apple Workout" rename | SCREENS § Workout Detail (Source Indicator); SERVICES § HealthKitClient |
| Apple Workout glyph scoped to Apple Watch source only on peripheral surfaces | SCREENS § Standard Patterns; SCREENS § Home, § Workouts, § Plan |
| Conditional Exercises header (hidden when empty) | SCREENS § Workout Detail |
| Share Image Card 2-column stat-card grid | SCREENS § Workout Detail (Share Image Card); CONSTANTS § Share Image Card Styling |
| Per-metric color treatment (icon, value, sparkline; multi-color Effort palette) | SCREENS § Workout Detail; CONSTANTS § Stat Card Colors, § Effort Color Mapping |
| Tests + new accessibility identifiers | TESTING |

### Phase 8.6: Activity Rings Widget (Apple Watch users)
*New Home widget showing Move/Exercise/Stand rings live from Apple Health, with FitNavi-configured goals, tap-to-detail breakdown, per-workout contribution captions, and weekly closure-rate chip. Three dynamic states gated by HK + Watch availability. Add-only; default seed becomes `[todaysPlan, trainingLoad, powerLevel]`.*

| Feature | Spec |
|---|---|
| `appleActivity` widget type + default-seed update | CONSTANTS § Widget Types, § Default Home Widgets; SERVICES § HomeWidgetService; SCREENS § Home Screen |
| Three dynamic states (Connect HK / Pair Watch / Live) | SCREENS § Home Screen (Activity Rings → States); SERVICES § AppleActivityService |
| Three nested rings + over-100% second-arc | SCREENS § Activity Rings widget; CONSTANTS § Activity Rings |
| Left-column fractions, color flip, all-rings celebration pulse | SCREENS § Activity Rings widget |
| Workout contribution caption (HK-linked workouts only) | SCREENS § Activity Rings widget; SERVICES § AppleActivityService |
| Weekly closure rate chip | SCREENS § Activity Rings widget; CONSTANTS § Activity Rings |
| Activity Rings Settings Modal (sliders, Reset, Import from HK) | SCREENS § Activity Rings Settings Modal; CONSTANTS § Activity Rings |
| Activity Detail Sheet (3 sparklines + heatmap, 7/30-day toggle) | SCREENS § Activity Detail Sheet; CONSTANTS § Activity Rings |
| Activity Rings See Info Modal | SCREENS § Activity Rings See Info Modal; INFO_COPY § Activity Rings |
| `AppleActivityService` (daily totals, observer, Watch detection, weekly closure, goal import) | SERVICES § AppleActivityService |
| HK auth scope expansion + Info.plist update | HEALTHKIT § 17, § 20 |
| Workout Cascade refresh hook (HK-linked only) | SERVICES § Workout Cascade, § AppleActivityService |
| `UserSettings.targetMoveCalories` / `targetExerciseMinutes` / `targetStandHours` + first-config import | PRD § Data Model; SERVICES § AppleActivityService; HEALTHKIT § 20 |
| Tests + new accessibility identifiers | TESTING |

*Post-MVP (parked):* Trends-screen integration via three new chart types (`moveHistory`, `exerciseHistory`, `standHistory`) consuming `AppleActivityService.fetchActivitySummaries`. Out of scope for this phase.

### Phase 8.7: Apple Watch Workout Scheduling
*Sync `ScheduledWorkout`s from the Plan tab to the user's Apple Watch via WorkoutKit. Completed sessions auto-link back via `HKWorkout.workoutPlan?.id` round-trip. No native watchOS companion app.*

| Feature | Spec |
|---|---|
| `WatchScheduleService` (schedule, removePlan, reconcile, error handling) | SERVICES § WatchScheduleService; WORKOUTKIT § 7, § 11, § 15 |
| New ScheduledWorkout fields (`syncToAppleWatch`, `appleWorkoutPlanId`) + rename `templateSnapshot` → `scheduledWorkoutSnapshot` | PRD § Data Model; WORKOUTKIT § 5 |
| New TemplateExerciseSet + ExerciseSet fields (`restSeconds`, `displayAsTime`) | PRD § Data Model; WORKOUTKIT § 5 |
| `UserSettings.syncPlanToAppleWatchEnabled` master kill switch | PRD § Data Model; SCREENS § Settings → Apple Watch Section |
| Plan-ID fast-path in HealthKitSyncService (bypass WorkoutMatcher) | SERVICES § HealthKitSyncService; HEALTHKIT § 12.0; WORKOUTKIT § 8 |
| `PlanService.completeFromWatch(...)` + `editScheduledWorkout(...)` | SERVICES § PlanService; WORKOUTKIT § 8, § 13 |
| `CustomWorkout` plan composition (one block per exercise, exercise prescriptions, rest intervals between sets) | WORKOUTKIT § 6 |
| Outbound HK type mapping (FortiFit `workoutType` → `HKWorkoutActivityType`) | HK_MAPPING § Outbound Mapping; WORKOUTKIT § 6 |
| Isometric exercise dictionary additions + `displayAsTime` toggle | CONSTANTS § Exercise Dictionary, § Isometric Exercise Names; WORKOUTKIT § 6 |
| REST PER SET field + REPS/TIME segmented control on exercise cards (Create/Edit Template, Log Workout, Edit Planned Workout) | SCREENS § Create Workout Template, § Log Workout, § Edit Planned Workout |
| Card glyph (`FortiFitWatchSyncGlyph`: `applewatch.watchface` / `applewatch.slash`) | SCREENS § Plan, § Standard Patterns; CONSTANTS § Watch Sync Glyph |
| Edit Planned Workout screen + recurrence prompt | SCREENS § Edit Planned Workout; WORKOUTKIT § 13 |
| Settings → Apple Watch section + just-in-time auth | SCREENS § Settings; WORKOUTKIT § 9, § 10 |
| Master Sync Off popover + field-specific gate popovers | SCREENS § Standard Patterns; CONSTANTS § Apple Watch Strings |
| Cleanup lifecycle (skip, complete, remove, day-passed, sync-off, master-off, auth-revoked) | WORKOUTKIT § 12; SERVICES § PlanService |
| Recurrence sync intent inheritance + 12-week regen hook | WORKOUTKIT § 13; SERVICES § PlanService |
| Optimistic UI + error toast with retry | WORKOUTKIT § 11; CONSTANTS § Toast Style |
| watchOS 11+ static caveat (no dynamic detection) | WORKOUTKIT § 14; SCREENS § Settings |
| Tests + new accessibility identifiers | TESTING § WorkoutKit Test Strategy; WORKOUTKIT § 16, § 17 |

### Phase 8.7.1: Apple Watch Push — Entry-Point Refinement
*Refinement on top of Phase 8.7. Moves the primary configuration moment from the Plan card glyph to the Schedule Workout sheet, auto-defaults Push when master is on. Time is decoupled from Push — setting a scheduled time is optional regardless of push state; when no time is set, `WatchScheduleService` falls back to noon for the WorkoutKit API call. Full rename "Sync" → "Push" everywhere user-facing; "Set Specific Time" → "Scheduled Time", "Date" → "Scheduled Date" on Plan/Edit screens. Internal Swift identifiers unchanged.*

| Feature | Spec |
|---|---|
| Schedule Workout "Push to Apple Watch" toggle (new primary entry point) | SCREENS § Plan → Push to Apple Watch Toggle; CONSTANTS § Apple Watch Strings → Schedule Workout Sheet |
| Auto-default to true when master on / greyed off when master off | SERVICES § PlanService → Scheduling; WORKOUTKIT § 7 |
| Time decoupled from Push; noon fallback when `scheduledTime` is nil | WORKOUTKIT § 7; SERVICES § WatchScheduleService → Schedule Date Resolution |
| Rename "Sync" → "Push" across Settings master toggle, Edit Planned Workout toggle, Master Sync Off Popover | CONSTANTS § Apple Watch Strings; SCREENS § Settings, § Edit Planned Workout, § Standard Patterns |
| Plan card glyph behavior unchanged (status indicator + quick-toggle) | SCREENS § Standard Patterns → Watch Sync Card Glyph |
| Tests + new accessibility identifiers (`scheduleWorkout_*`) | TESTING § Accessibility Identifiers (Apple Watch push) |
| Implementation plan | IMPLEMENTATION_PLAN_PHASE_8_7_1.md |

### Phase 8.8: Home Widget Detail Sheets + Settings Modal Done Buttons
*Every Home widget opens a per-widget detail sheet on tap. Settings modals gain an outlined Done button. Activity Rings settings modal restructured (Done replaces Reset to defaults; Import from Apple Health moves to first position below the Stand slider). Activity Detail Sheet retrofitted with See Info / Configure Settings footer for parity with the four new sheets.*

| Feature | Spec |
|---|---|
| Home Widget Tap-to-Open pattern (routing + edit-mode suppression) | SCREENS § Standard Patterns → Home Widget Tap-to-Open; SERVICES § HomeWidgetService → Widget Tap Routing; CONSTANTS § Widget Tap Behavior |
| Today's Plan Detail Sheet (`FortiFitTodaysPlanDetailSheet`) + per-row Complete button + Schedule More chip + completed-row visibility windowing | SCREENS § Today's Plan Detail Sheet; SERVICES § PlanService → Retrieval (`fetchTodaysScheduledWorkouts`); CONSTANTS § Today's Plan Detail Sheet; INFO_COPY § Widget Detail Sheet Empty States |
| Training Load Detail Sheet (`FortiFitTrainingLoadDetailSheet`) + 14-day chart + contributing workouts + week comparison + recovery callout | SCREENS § Training Load Detail Sheet; SERVICES § Training Load Algorithm → Detail Sheet Helpers; CONSTANTS § Training Load Detail Sheet; INFO_COPY § Widget Detail Sheet Empty States |
| Weekly Streak Insights Sheet (`FortiFitWeeklyStreakDetailSheet`) — typographic hero, stat row, this-week ring, 26-week heatmap, milestone shelf — no flame | SCREENS § Weekly Streak Insights Sheet; SERVICES § Streak Algorithm → Weekly Streak Insights Helpers; CONSTANTS § Weekly Streak Insights; INFO_COPY § Widget Detail Sheet Empty States |
| Power Level Breakdown Sheet (`FortiFitPowerLevelDetailSheet`) + 30-day volume chart + top 3 exercises (≥ 3-session filter) + window comparison + **calculated** nudge | SCREENS § Power Level Breakdown Sheet; SERVICES § Power Level Algorithm → Top Contributing Exercises / Window Comparison / Nudge Computation; CONSTANTS § Power Level Detail Sheet; INFO_COPY § Power Level Nudge Copy |
| Activity Detail Sheet footer retrofit (See Info / Configure Settings) | SCREENS § Activity Detail Sheet (Phase 8.8 retrofit) |
| Settings Modal `Done` button (outlined) on Weekly Streak / Training Load / Activity Rings modals | SCREENS § Widget Definitions (Weekly Streak / Training Load Settings Modals), § Activity Rings Settings Modal; CONSTANTS § Settings Modal Done Button |
| Activity Rings Settings Modal — Reset removed; Import moved to first position | SCREENS § Activity Rings Settings Modal; CONSTANTS § Activity Rings → Settings Modal Strings |
| Workout Cascade hook for derived data refresh while a detail sheet is presented | SERVICES § Workout Cascade |
| Tests + new accessibility identifiers (and retirement of `activityRingsSettings_resetButton`) | TESTING § Widget Detail Sheet Test Strategy; TESTING § Accessibility Identifiers → Widget Detail Sheets |
| Implementation plan | IMPLEMENTATION_PLAN_PHASE_8_8.md |

### Phase 11: Recovery Status Widget + Training Load Linking
*New Home widget surfacing last-night sleep, deep-sleep breakdown, and time-since-last-workout, with a four-state gating system (Connect Apple Health / Sleep Access Denied / No Sleep Tracker / Live). When placed adjacent to Training Load, the two widgets visually link via a shared border + zero padding, expose a combined long-press menu, combined Settings / See Info / Detail Sheet, and the TL algorithm gains a sleep-adjusted decay path (driven by `targetSleepHours`). Adds two SwiftData snapshots (`DailySleepSnapshot`, `DailyTrainingLoadSnapshot`) so the Training Load Trend chart can render history without recomputing from raw HK each open.*

| Feature | Spec |
|---|---|
| `recoveryStatus` widget type + default-seed update + Add Widgets order (adjacent to Training Load) | CONSTANTS § Widget Types, § Add Widgets Menu Order; SERVICES § HomeWidgetService; SCREENS § Home Screen |
| Four gating states (Connect Apple Health / Sleep Access Denied / No Sleep Tracker / Live) + no-sleep-last-night sub-state | SCREENS § Home Screen (Recovery Status → States); SERVICES § RecoveryStatusService |
| Sleep hero (32/900 value, deep-sleep caption) + timer line + `moon.zzz` watermark | SCREENS § Home Screen (Recovery Status widget); CONSTANTS § Recovery Status Widget |
| `RecoveryStatusService` (sleep fetch + observer, 30-day cache, efficiency, correlation, gating, readiness copy, smart suggestion, personal insights) | SERVICES § RecoveryStatusService |
| `DefaultHealthKitClient` sleep methods (sample query, observer subscription, sleep duration goal characteristic read) | SERVICES § HealthKitClient; HEALTHKIT § 21 |
| `HealthKitSyncService` sleep observer + BG refresh registration | SERVICES § HealthKitSyncService; HEALTHKIT § 21 |
| HK auth scope expansion (sleep) + Info.plist `NSHealthShareUsageDescription` update | HEALTHKIT § 17, § 21 |
| Recovery Status Settings Modal (Sleep Target slider 4–12h step 0.5, Import from Apple Health) | SCREENS § Recovery Status Settings Modal; CONSTANTS § Recovery Status Settings Modal |
| Recovery Status Detail Sheet (stages bar, sleep efficiency, 14-day sparkline, last-7-nights row, time-since-workout breakdown) | SCREENS § Recovery Status Detail Sheet; CONSTANTS § Recovery Status Detail Sheet |
| Recovery Status See Info Modal | SCREENS § Recovery Status See Info Modal; INFO_COPY § Widget Info Modal Copy → recoveryStatus |
| Widget Linking — adjacency rule, auto-unlink, manual-unlink flag, shared border, zero padding, animations | SCREENS § Standard Patterns → Widget Linking; SERVICES § HomeWidgetService (`isLinkedActive`) |
| Linked Recovery & Load composite (container) | SCREENS § Linked Recovery & Load Composite |
| Combined long-press context menu (See Info / Configure Settings / Unlink Widgets / Reorder) | SCREENS § Home Screen (Widget Context Menu) |
| Combined Settings / See Info / Detail Sheet for the linked pair | SCREENS § Linked Recovery & Load Settings Modal, § Linked Recovery & Load See Info Modal, § Linked Recovery & Load Detail Sheet; INFO_COPY § Widget Info Modal Copy → linkedRecoveryLoad |
| Training Load widget — Sleep Impact Chip when linked | SCREENS § Home Screen (Widget Definitions → Training Load); CONSTANTS § Linked Recovery & Load |
| Training Load algorithm — Sleep-Adjusted Decay subsection + sleep cascade hooks | SERVICES § Training Load Algorithm (Sleep-Adjusted Decay, Daily Snapshot Capture), § Sleep Cascade |
| Trends `trainingLoadTrend` chart — snapshot-aware rendering + new "About this chart's calculation" info section | SCREENS § Trends; SERVICES § Training Load Algorithm (Daily Snapshot Capture); INFO_COPY § Chart Info Modal Copy → Training Load Trend |
| Linked Recovery & Load joint advisory copy (27 strings, zone × trainedToday × sleep bucket) | INFO_COPY § Training Load Zones → Linked Advisory Copy |
| `UserSettings.targetSleepHours` (Double, default 7.0) + `recoveryLoadManuallyUnlinked` (Bool, default false) | PRD § Data Model |
| `DailySleepSnapshot` + `DailyTrainingLoadSnapshot` SwiftData entities | PRD § Data Model; HEALTHKIT § 21 |
| `Sleep Awake` color token `#FF6B5B`; `moon.zzz` + `rectangle.on.rectangle.slash` SF Symbols | CONSTANTS § Colors, § SF Symbols |
| Widget Edit Mode — linked-pair-as-composite behavior + doc-drift fix on "x" delete button | SCREENS § Home Screen (Widget Edit Mode); BUGS (doc-drift entry) |
| Tests + new accessibility identifiers | TESTING § Accessibility Identifiers → Recovery Status |
| Collapsible insight cards on Linked Recovery & Load Detail Sheet (5 cards, persisted via UserSettings, default collapsed) | SCREENS § Linked Recovery & Load Detail Sheet → Collapsible insight cards; CONSTANTS § Linked Recovery & Load Detail Sheet → Collapsible Insight Cards |
| Implementation plan | IMPLEMENTATION_PLAN_PHASE_11.md |

### Phase 9: Launch Prep
*Ready for TestFlight or App Store.*

| Feature | Notes |
|---|---|
| All three test targets passing | No skipped tests without a BUGS.md entry |
| App icon + launch screen | Blue ✦ on dark background |
| App Store metadata | Screenshots, description, keywords |
| Privacy manifest | Local-data labels, passes Xcode validation |
| Performance | < 2s launch, 60fps scroll, no leaks |
| TestFlight beta | Builds, installs, all features work |
