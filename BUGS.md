# BUGS.md — FortiFit Bug Log

> Claude Code: Log all bugs, build failures, and unexpected behavior
> here before attempting a fix. Do not delete resolved entries.

## Template

| Field | Value |
|-------|-------|
| Date | YYYY-MM-DD |
| Phase | Phase N — Feature Name |
| Description | What went wrong |
| Root Cause | Why it happened |
| Resolution | What fixed it |
| Status | Open / Resolved |

---

## Entries

### BUG-001

| Field | Value |
|-------|-------|
| Date | 2026-03-30 |
| Phase | Phase 3 — Log Workout / Add Goal (any screen with a Menu-style picker inside a ScrollView) |
| Description | After tapping a selection in a `.pickerStyle(.menu)` dropdown and then scrolling, the picker/menu briefly follows the scroll direction for 1–2 seconds before snapping back to its original position. |
| Root Cause | Platform-level interaction quirk: iOS renders `.menu` pickers using a native UIKit overlay under SwiftUI's abstraction. On selection dismissal, the menu's animation briefly conflicts with the scroll view's momentum or layout recalculation, causing a transient drift. |
| Resolution | Replaced `Menu`-based `FortiFitSelect` with a pure SwiftUI inline dropdown that expands/collapses within the scroll view. No UIKit overlay is involved, eliminating the scroll drift. Also replaced the standalone `Menu` in `AddGoalView.goalTypeSelector` with the updated `FortiFitSelect`. |
| Status | Resolved |

---

### BUG-002

| Field | Value |
|-------|-------|
| Date | 2026-04-06 |
| Phase | Phase 4 — Home Screen Widgets |
| Description | Upon each build and run in the Simulator, duplicate copies of every default widget appeared on the Home screen, accumulating with each launch. |
| Root Cause | `HomeWidgetService.seedDefaultWidgets` guarded against re-seeding using a `UserDefaults` boolean (`hasSeededDefaultWidgets`), while widget records lived in SwiftData. These two storage systems fell out of sync during development — particularly when schema changes triggered store deletion in `FortiFitApp` (which only removed the main SQLite file, not WAL/SHM companions) while UserDefaults retained or lost the flag independently. When the flag was `false` but widgets already existed, seeding inserted duplicates without per-type checks. |
| Resolution | Replaced the UserDefaults boolean guard in `seedDefaultWidgets` with per-widget-type database checks (the same pattern `addWidget` already used). Removed `hasSeededDefaultWidgets` from `UserSettings`. Also fixed `FortiFitApp` store recovery to delete WAL and SHM files alongside the main store file. Updated related tests. |
| Status | Resolved |

---

### BUG-003

| Field | Value |
|-------|-------|
| Date | 2026-04-07 |
| Phase | Phase 3 — Add Goal (FortiFitExerciseAutocomplete dropdown) |
| Description | On the Add Goal screen, the exercise autocomplete dropdown's bottom edge showed a thin sliver of text bleeding through from the form fields beneath it (e.g. "Current (lbs)" label or "Save Goal" button text). |
| Root Cause | SwiftUI's `if condition { ... }` blocks in a ViewBuilder create opaque conditional containers that swallow inner `.zIndex()` modifiers. The autocomplete's `.zIndex(100)` only applied within the conditional, not relative to sibling views in the parent VStack. This occurred at two levels: (1) the `if !viewModel.selectedGoalType.isEmpty { ... }` block in the body, causing the Save Goal button to render on top, and (2) the `if viewModel.isCustomExercise { ... }` block inside the form, causing the Current/Target HStack to render on top. Additionally, the dropdown ScrollView lacked `.clipped()`, the suggestion row buttons used default button style (adding extra height beyond the calculated `dropdownHeight`), and the chevron section's conditional removal caused layout shifts exposing content behind. |
| Resolution | Applied multiple fixes to `AddGoalView.swift` and `FortiFitExerciseAutocomplete.swift`: (1) Wrapped conditional blocks in concrete `VStack` containers with `.zIndex(1)` at both the body level and form level so the dropdown renders above all sibling content. (2) Added `.clipped()` to the dropdown ScrollView. (3) Added `.buttonStyle(.plain)` and changed `.frame(minHeight:)` to `.frame(height:)` on suggestion rows for exact height matching. (4) Changed the chevron section from conditional rendering to opacity-based hiding to maintain consistent dropdown height. |
| Status | Resolved |

---

### BUG-004

| Field | Value |
|-------|-------|
| Date | 2026-04-08 |
| Phase | Phase 6 — FortiFitAddChartMenu / FortiFitAddWidgetMenu (UIKit API build failure) |
| Description | The project failed to build for tests because `FortiFitAddWidgetMenu.swift` and `FortiFitAddChartMenu.swift` used `UIImpactFeedbackGenerator` and `UIScreen.main` without UIKit being available in the build configuration. |
| Root Cause | The build scheme targets a platform (likely Mac Catalyst or Designed for iPad) where `UIImpactFeedbackGenerator` and `UIScreen` are unavailable. These UIKit APIs were used directly without platform guards. |
| Resolution | Wrapped `UIImpactFeedbackGenerator` calls in `#if canImport(UIKit)` guards in both `FortiFitAddWidgetMenu.swift` and `FortiFitAddChartMenu.swift`. Replaced `UIScreen.main.bounds.height * 0.7` with a fixed `maxHeight: 500` in `FortiFitAddChartMenu.swift`. |
| Status | Resolved |

---

### BUG-005

| Field | Value |
|-------|-------|
| Date | 2026-04-08 |
| Phase | Phase 6 — FortiFitAddChartMenu (overlay does not dismiss after adding chart) |
| Description | After tapping "Add" in the Add Charts overlay, the chart is added but the overlay remains open. The user must manually close it. The equivalent `FortiFitAddWidgetMenu` correctly dismisses after adding a widget. |
| Root Cause | `FortiFitAddChartMenu`'s Add button calls `onAdd(chartType)` but does not set `isPresented = false` afterward. Compare with `FortiFitAddWidgetMenu` which includes `isPresented = false` after `onAdd(widgetType)`. |
| Resolution | Pending — add `isPresented = false` after the `onAdd(chartType)` call in `FortiFitAddChartMenu.swift`. |
| Status | Open |

---

### BUG-006

| Field | Value |
|-------|-------|
| Date | 2026-04-08 |
| Phase | Phase 6 — Personal Records chart (PR detection not case-insensitive) |
| Description | The `exercisesWithPRs()` method in `ProgressViewModel` groups exercise sets by exact `exerciseName` string, not by case-insensitive comparison. "bench press" and "Bench Press" are treated as different exercises for PR tracking. |
| Root Cause | The `exerciseHistory` dictionary key uses `exerciseSet.exerciseName` directly without `.lowercased()`. The existing goal auto-update system already uses case-insensitive matching, but the PR detection logic does not. |
| Resolution | Pending — normalize exercise names to lowercase when building the `exerciseHistory` dictionary in `exercisesWithPRs()` and `prComparison(for:)`. |
| Status | Open |

---

### BUG-007

| Field | Value |
|-------|-------|
| Date | 2026-04-08 |
| Phase | Phase 6 — Personal Records chart (PR Summary Row styling) |
| Description | The PR Summary Row labels ("Previous Record" / "Current Record") use Title Case with `primaryText` color. The spec requires uppercase ("PREVIOUS RECORD" / "CURRENT RECORD") with `mutedText` color. Additionally, the previous record value uses `primaryAccent` color instead of muted text. |
| Root Cause | Styling mismatch between implementation and spec. |
| Resolution | Pending — update label text to `.textCase(.uppercase)`, change label `foregroundStyle` to `mutedText`, and change previous record value `foregroundStyle` to `mutedText`. |
| Status | Open |

---

### BUG-008

| Field | Value |
|-------|-------|
| Date | 2026-04-08 |
| Phase | Phase 6 — RPE Trend / Session Duration charts (reference line color) |
| Description | The reference lines on both the RPE Trend chart ("Hard" at RPE 7) and Session Duration chart ("Target" at targetMinutes) use `primaryText` color instead of muted color as specified. |
| Root Cause | Both reference lines use `.foregroundStyle(FortiFitColors.primaryText)` for the `RuleMark` and annotation, but the spec requires muted color. |
| Resolution | Pending — change `.foregroundStyle(FortiFitColors.primaryText)` to `.foregroundStyle(FortiFitColors.mutedText)` on both `RuleMark` instances and their annotations. |
| Status | Open |

---

### BUG-009

| Field | Value |
|-------|-------|
| Date | 2026-04-08 |
| Phase | Phase 6 — Workout Type Breakdown chart (segment labels) |
| Description | The donut chart segments only show the count number in the overlay annotation. The spec requires both the workout type name and count. |
| Root Cause | The `SectorMark` annotation at line 631 only renders `"\(entry.count)"`, not `"\(entry.workoutType) (\(entry.count))"`. |
| Resolution | Pending — update the annotation text to include the workout type name. |
| Status | Open |

---

### BUG-010

| Field | Value |
|-------|-------|
| Date | 2026-04-16 |
| Phase | Phase 3 — Log Workout / Workout Detail (exercise set ordering) |
| Description | After logging a workout with multiple exercises (each with multiple rows), returning to the workout detail or edit screen shows exercises/rows in a scrambled order instead of the order they were entered. |
| Root Cause | `sortOrder` was assigned per-exercise (using the exercise index), not per-row. All rows within the same exercise received the same `sortOrder` value. Since SwiftData `@Relationship` arrays don't preserve insertion order, rows with identical `sortOrder` values appeared in non-deterministic order after reload. |
| Resolution | Changed `saveWorkout()`, `saveEditedWorkout()`, and `saveCurrentFormAsTemplate()` in `WorkoutViewModel` to use a global sequential counter for `sortOrder` across all rows, so every `ExerciseSet` gets a unique, ordered value. |
| Status | Resolved |

---

### BUG-011

| Field | Value |
|-------|-------|
| Date | 2026-04-17 |
| Phase | Phase 3 — Goals (sparkline not updating after workout log) |
| Description | The 30-day sparkline on goal cards does not update after logging, editing, or deleting workouts. The chart shows stale data until the app is relaunched. |
| Root Cause | `GoalsViewModel.snapshotCache` is a dictionary that caches fetched snapshots per goal ID. The `loadSnapshots(for:context:)` method has an early return (`if snapshotCache[goal.id] != nil { return }`) that prevents re-fetching once data is cached. When the Goals screen reappears after a workout change, `loadGoals` refreshes the goal list but never invalidates the snapshot cache, so any previously-expanded sparkline continues to display stale data. |
| Resolution | Clear the entire `snapshotCache` dictionary inside `loadGoals(context:)` so that the next sparkline expand always fetches fresh snapshot data from SwiftData. |
| Status | Resolved |

---

### BUG-012

| Field | Value |
|-------|-------|
| Date | 2026-04-17 |
| Phase | Phase 3 — Goals (editing goal current value ignored) |
| Description | When editing a goal via the context menu "Edit Goal" flow, changing the "Current" value (weight for Strength PR, reps for Repetitions PR) has no effect. The saved goal shows a different value — either the previous auto-calculated value or 0. |
| Root Cause | `GoalsViewModel.saveEditedGoal(context:)` only saves `title` and target values (`targetValueKg`, `targetReps`) but does not write `currentValueKg` or `currentReps` from the form fields. Then `GoalService.handleGoalDefinitionEdit` calls `recalculateGoals`, which scans all in-scope workouts and overwrites the current value with the max found (or 0 if no matches). The current value from the form is doubly lost: never saved, then overwritten by recalculation. |
| Resolution | Made the "Current" fields read-only (disabled with muted text) in edit mode, since current values are auto-derived from workout data per the spec. This aligns the UI with the actual data flow and prevents user confusion. |
| Status | Resolved |

---

### BUG-013

| Field | Value |
|-------|-------|
| Date | 2026-04-17 |
| Phase | Phase 3 — Goals (sparkline disappears on screen re-entry) |
| Description | After expanding a goal card's sparkline and navigating away from the Goals screen, returning causes the sparkline to show the empty skeleton (dashed line) instead of the chart — even though snapshot data exists in SwiftData. |
| Root Cause | Regression introduced by BUG-011 fix. `loadGoals(context:)` now clears `snapshotCache` on every call (to fix stale data), but does not re-populate snapshots for goals whose cards are still expanded (`expandedGoalIds` persists across navigation). The sparkline section renders because `isExpanded` is still true, but `snapshotCache[goal.id]` is nil, so `isSparklineEmpty` returns true and the skeleton displays. `loadSnapshots` is only called from the chevron tap handler when transitioning collapsed → expanded, so already-expanded cards never refetch. |
| Resolution | After clearing the cache in `loadGoals`, iterate over `expandedGoalIds` and call `loadSnapshots` for each expanded goal to re-populate the cache immediately. |
| Status | Resolved |

---

### BUG-014

| Field | Value |
|-------|-------|
| Date | 2026-04-17 |
| Phase | Phase 3 — Goals (dual-arc ring shows single ring at zero progress) |
| Description | Speed and Distance goals with both distance and duration targets display a single grey ring instead of two concentric grey rings when progress is zero on both metrics. |
| Root Cause | `FortiFitGoalProgressRing.isDualArc` checks `distanceProgress > 0 && durationProgress > 0` to decide whether to render dual arcs. At zero progress both values are 0, so the condition is false and the component falls through to single-ring rendering. The dual-arc decision should be based on whether both targets exist, not on whether progress is non-zero. |
| Resolution | Added a `hasDualTargets: Bool` parameter to `FortiFitGoalProgressRing` and changed `isDualArc` to use it instead of inferring from progress values. Updated `GoalsView` call site to pass `hasDualTargets: isDualArc` (which is already correctly computed from target presence). Updated RING-013 test to verify dual-arc at zero progress. |
| Status | Resolved |

---

### BUG-015

| Field | Value |
|-------|-------|
| Date | 2026-04-17 |
| Phase | Phase 3 — Goals (zero-duration bug in GoalService causes false completion and phantom pulse) |
| Description | A dual-target Speed and Distance goal (5k run: 5 miles in 5 minutes) with zero progress triggers the completion pulse animation on the Goals screen. The ring shows the blue pulse circle despite 0.00/5.00 mi and 0/5 min. |
| Root Cause | `GoalService.completionPercentage` has the same zero-duration bug that was fixed in `GoalsViewModel.durationProgress` (BUG-014 session): in the dual-target speed path, `goal.currentDurationMinutes <= target` returns `true` when `currentDurationMinutes = 0`, causing `durationPct = 100`. While the overall `completionPercentage` is saved by `min(distancePct=0, durationPct=100) = 0`, the bug creates a pathway for false completion: if a matching workout ever provides sufficient distance with duration of 0 (empty field stored as 0 instead of nil), both `completionPercentage` and `isComplete` report 100%/true, and `checkAndFireCompletion` sets `lastCelebratedDate = today`. Once set, `lastCelebratedDate` is never cleared by normal recalculation — even if the triggering workout is deleted and values revert to 0. The pulse persists because `identifyGoalsToPulse` checks `lastCelebratedDate`, not current progress. `GoalService.isComplete` has the same bug: `currentDurationMinutes <= targetDur` is `true` at 0. |
| Resolution | Applied `currentDurationMinutes == 0` early-return guard to both `GoalService.completionPercentage` (dual-target duration path, returns 0) and `GoalService.isComplete` (dual-target Speed and Distance check, returns false), matching the fix already in `GoalsViewModel.durationProgress`. |
| Status | Resolved |

---

### BUG-016

| Field | Value |
|-------|-------|
| Date | 2026-04-18 |
| Phase | Phase 3 — Goals (pulse animation fires on incomplete goals) |
| Description | The completion pulse animation on the Goals screen fires for goals that are not at 100%. For example, a Bench Press goal at 225/250 lbs (90%) shows the blue pulse ring. |
| Root Cause | `GoalsViewModel.identifyGoalsToPulse()` only checked whether `lastCelebratedDate` was set to today — it did not verify the goal was still actually complete. If a goal hit 100% earlier (setting `lastCelebratedDate`), and the user then raised the target (making it incomplete), the pulse still fired because `lastCelebratedDate` remained set to today. |
| Resolution | Added an `isGoalComplete` check in `identifyGoalsToPulse()` so the pulse only fires when the goal's `lastCelebratedDate` is today **and** the goal is currently at 100% completion. |
| Status | Resolved |

---

### BUG-017

| Field | Value |
|-------|-------|
| Date | 2026-04-22 |
| Phase | Phase 7 — Plan (Remove from Plan undo toast dismissal) |
| Description | When the "Removed from Plan" undo toast auto-dismisses after 4 seconds (user does not tap Undo), it vanishes instantly instead of animating out. The entrance animation (slide down + fade in) works correctly, but the exit has no animation. |
| Root Cause | The toast used `if viewModel.showRemovedFromPlanToast { VStack { ... }.transition(...) }` — a conditional insertion/removal with `.transition()`. SwiftUI's transition-based removal animations are unreliable when the state change originates from a `DispatchQueue.main.asyncAfter` callback on an `@Observable` object; the removal transition silently fails to fire even with an `.animation(value:)` modifier on the parent ZStack. |
| Resolution | Replaced the conditional `if`/`.transition` pattern with an always-present view that animates `opacity` and `offset` based on the flag value. `.animation(.easeInOut(duration: 0.2), value:)` is applied directly to the toast view, ensuring both entrance and exit reliably animate via property interpolation rather than view insertion/removal. |
| Status | Resolved |

---

### BUG-018

| Field | Value |
|-------|-------|
| Date | 2026-04-23 |
| Phase | Phase 4 — Home Screen (ellipsis button scroll drift) |
| Description | On the Home screen, tapping the ellipsis menu button and then scrolling causes the button to temporarily drift with the scroll before snapping back to its original position. The Workouts screen does not have this issue. |
| Root Cause | The ellipsis button (and gear icon) are placed inside the `ScrollView` in `HomeView.swift`. When the native menu overlay dismisses mid-scroll, the button's position briefly follows scroll momentum before SwiftUI re-settles the layout. The Workouts screen avoids this by placing its header outside the `ScrollView` in a fixed `VStack(spacing: 0)`. |
| Resolution | Extracted the header (`HStack` with ellipsis + gear icon and `FortiFitDivider`) out of the `ScrollView` into a fixed `VStack(spacing: 0)` above it, mirroring the `WorkoutListView` pattern. The scroll content now begins below the divider with `.padding(.top, FortiFitSpacing.gapMedium)` instead of `screenTop`. |
| Status | Resolved |

---

### BUG-019

| Field | Value |
|-------|-------|
| Date | 2026-04-23 |
| Phase | Phase 7 — Plan Screen (ellipsis button scroll drift) |
| Description | On the Plan screen, tapping the ellipsis menu button and then scrolling causes the button to temporarily drift with the scroll before snapping back to its original position. Same root cause as BUG-018. |
| Root Cause | The ellipsis button (and plus button) are placed inside the `ScrollView` in `PlanView.swift`. When the native menu overlay dismisses mid-scroll, the button's position briefly follows scroll momentum before SwiftUI re-settles the layout. |
| Resolution | Extracted the header (`HStack` with ellipsis + plus button and `FortiFitDivider`) out of the `ScrollView` into a fixed `VStack(spacing: 0)` above it, mirroring the `WorkoutListView` and `HomeView` pattern. |
| Status | Resolved |

---

### BUG-020

| Field | Value |
|-------|-------|
| Date | 2026-04-23 |
| Phase | Phase 6 — Trends Screen (ellipsis button scroll drift) |
| Description | On the Trends screen, tapping the ellipsis menu button and then scrolling causes the button to temporarily drift with the scroll before snapping back to its original position. Same root cause as BUG-018 and BUG-019. |
| Root Cause | The ellipsis button is placed inside the `ScrollView` in `FortiFitProgressView.swift`. When the native menu overlay dismisses mid-scroll, the button's position briefly follows scroll momentum before SwiftUI re-settles the layout. |
| Resolution | Extracted the header (`HStack` with ellipsis and `FortiFitDivider`) out of the `ScrollView` into a fixed `VStack(spacing: 0)` above it, mirroring the pattern used by `WorkoutListView`, `HomeView`, and `PlanView`. |
| Status | Resolved |

---

### BUG-021

| Field | Value |
|-------|-------|
| Date | 2026-04-24 |
| Phase | Phase 8 — Settings (HealthKit authorization status always shows "Permission denied") |
| Description | After enabling "Connect to Apple Health" in Settings, the status line reads "Permission denied in iOS Settings" and shows an "Open iOS Settings" button. The user never denied permissions, and Apple Health does not appear in the iOS Settings page for FitNavi. |
| Root Cause | `DefaultHealthKitClient.authorizationStatus()` used `HKHealthStore.authorizationStatus(for:)`, which returns **sharing/write** authorization status (`.sharingAuthorized` / `.sharingDenied`). Since FortiFit is read-only (`toShare: []` in the authorization request), HealthKit always returns `.sharingDenied` for the workout type — the code then incorrectly mapped this to the app's `.denied` enum case. For read-only HealthKit apps, iOS intentionally hides whether read access was granted or denied; `authorizationStatus(for:)` is meaningless for read types. |
| Resolution | Added a `healthKitAuthorizationRequested` boolean flag to `UserSettings`. `DefaultHealthKitClient.requestAuthorization()` sets this flag to `true` after the authorization prompt completes. `authorizationStatus()` now returns `.granted` when the flag is set, `.notDetermined` otherwise — bypassing the unusable `HKHealthStore.authorizationStatus(for:)` API entirely. |
| Status | Resolved |

---

### BUG-022

| Field | Value |
|-------|-------|
| Date | 2026-04-24 |
| Phase | Phase 8 — HealthKit Sync (imported workouts not visible on Workouts screen) |
| Description | Workouts auto-imported from Apple Watch via HealthKit do not appear on the Workouts screen. The workouts exist in SwiftData but the Workouts screen shows no type card for them. |
| Root Cause | `HealthKitSyncService.autoCreate(from:context:)` called `WorkoutService.logWorkout()` but did not call `WorkoutTypeOrderService.ensureOrderExists(for:context:)`. The Workouts screen groups workouts by `WorkoutTypeOrder` records — without a type order entry for the imported workout's type, no type card is rendered and the workout is invisible. Additionally, `GoalService.recalculateGoals()` was not called, so goals were not updated by HK imports. |
| Resolution | Added `WorkoutTypeOrderService.ensureOrderExists(for: mapping.workoutType, context: context)` and `GoalService.recalculateGoals(...)` after the `logWorkout` call in `autoCreate`, matching the cascade used by `WorkoutViewModel.saveWorkout` and `PlanService.completePlannedWorkout`. |
| Status | Resolved |

---

### BUG-023

| Field | Value |
|-------|-------|
| Date | 2026-04-25 |
| Phase | Phase 8 — HealthKit Sync (effort score / RPE never populates on imported workouts) |
| Description | Workouts imported from Apple Watch via HealthKit do not receive the `workoutEffortScore` value in the `rpe` field, even when the user rated effort on the Watch. The effort score is nil on all HK-imported workouts. |
| Root Cause | Race condition with no retry mechanism. `workoutEffortScore` is a separate `HKQuantitySample` in HealthKit — not a property of `HKWorkout`. When the anchored query delivers a new workout, `HealthKitSyncService.processSnapshot` calls `applyEffortScoreIfNeeded`, which calls `DefaultHealthKitClient.fetchEffortScore`. However, the effort score sample typically syncs from Apple Watch *after* the workout sample, so the query returns nil. Three factors make this failure permanent: (1) `fetchEffortScore` errors are silently swallowed by `try?` at the call sites in `processSnapshot` (lines 121 and 129 of `HealthKitSyncService.swift`), providing no signal that a retry is needed; (2) `handleUpstreamUpdate` (line 170) does not attempt effort score nil-fill — correct per HEALTHKIT.md § 11 which says `rpe` is user-owned and never touched by upstream updates, but this creates a gap when the initial import misses the score; (3) effort score samples are a different `HKQuantityType` than workouts, so their arrival in HealthKit does not trigger the `HKObserverQuery` on `HKObjectType.workoutType()`, meaning no re-import is attempted when the score becomes available. |
| Resolution | Three-layer fix: (1) `handleUpstreamUpdate` now calls `applyEffortScoreIfNeeded` when `rpe` is nil, so upstream workout updates backfill the score. (2) Added `backfillMissingEffortScores(context:)` which scans all HK-linked workouts with nil `rpe` and fetches effort scores — called at the end of every `importPendingWorkouts` cycle as a catch-all. (3) Added `observeEffortScoreChanges` to `HealthKitClient` protocol; `DefaultHealthKitClient` registers an `HKObserverQuery` on `HKQuantityType(.workoutEffortScore)` with background delivery, triggering backfill when effort score samples arrive independently of workout updates. Regression tests: `test_upstreamUpdate_nilFillsEffortScoreWhenRPEIsNil`, `test_upstreamUpdate_preservesExistingRPEDuringUpdate`, `test_backfillEffortScores_fillsMissingRPEOnLinkedWorkouts`. |
| Status | Resolved |

---

### BUG-024

| Field | Value |
|-------|-------|
| Date | 2026-04-30 |
| Phase | Phase 8 — HealthKit Match Prompt (grey empty sheet flash before content appears) |
| Description | When the workout matching service finds a potential Apple Workout match, a blank grey sheet appears briefly before the correct Match Prompt Sheet renders with its content. |
| Root Cause | `FortiFitApp.swift` uses `.sheet(isPresented: $showMatchPrompt)` with an `if let match = currentPendingMatch` conditional inside the content closure. When `showMatchPrompt` becomes `true`, SwiftUI may render the sheet content before the `currentPendingMatch` state update has propagated through the view update cycle. The `if let` fails on the first render pass, producing an empty view (grey sheet), then succeeds on the next pass once the state catches up. This is a known SwiftUI timing issue with `@State` and conditional sheet content. |
| Resolution | Replaced `.sheet(isPresented: $showMatchPrompt)` with `.sheet(item: $currentPendingMatch)`, which ties presentation directly to the data. The sheet only appears when the item is non-nil, and the item is passed directly to the content closure — no conditional unwrap, no race condition. Removed the now-unnecessary `showMatchPrompt` boolean. |
| Status | Resolved |

---

### BUG-025

| Field | Value |
|-------|-------|
| Date | 2026-05-01 |
| Phase | Phase 4 — Home Screen Widgets |
| Description | The Weekly Streak widget reappears on the Home screen after the user deletes it, every time the app reopens or the Home tab is re-entered. Additionally, the Weekly Streak widget was incorrectly included in the default seed list, causing it to appear on first launch without user action. |
| Root Cause | `HomeWidgetService.seedDefaultWidgets()` was called on every `HomeViewModel.loadData()` invocation (every Home screen appearance). The function relied on idempotency (skipping widget types that already exist in the store) rather than a one-time seeding flag. After the user hard-deletes a widget, the widget type no longer exists in SwiftData, so the next seeding pass re-creates it. The SERVICES.md spec documented a `hasSeededDefaultWidgets` UserSettings flag to gate seeding, but it was never implemented — an earlier version (BUG-002) was removed due to UserDefaults/SwiftData sync issues during schema migration, and the replacement idempotent approach introduced this inverse bug. |
| Resolution | Added `hasSeededDefaultHomeWidgets` boolean to `UserSettings` (defaults to `false`). `seedDefaultWidgets()` now checks this flag and returns early if `true`; after seeding it sets the flag to `true`. Legacy widget migrations still run independently (they have their own idempotency). Removed `"weekStreak"` from `AppConstants.defaultHomeWidgets` so it is no longer seeded on first launch. |
| Status | Resolved |

---

### BUG-026

| Field | Value |
|-------|-------|
| Date | 2026-05-03 |
| Phase | Phase 8.6 — Activity Rings Widget (app crash on launch) |
| Description | App crashes immediately on launch with `NSInvalidArgumentException: 'startDateComponents: Date components require a calendar.'` |
| Root Cause | `DefaultHealthKitClient.fetchActivitySummary(for:)` and `fetchActivitySummaries(from:to:)` create `DateComponents` via `calendar.dateComponents([.year, .month, .day], from:)`, which does not set the `.calendar` property on the result. `HKQuery.predicate(forActivitySummariesBetweenStart:end:)` requires `.calendar` to be set, and throws an unrecoverable `NSInvalidArgumentException` when it is nil. |
| Resolution | Added `components.calendar = calendar` after every `calendar.dateComponents(...)` call in both `fetchActivitySummary(for:)` and `fetchActivitySummaries(from:to:)` in `DefaultHealthKitClient.swift`. |
| Status | Resolved |

---

### BUG-027

| Field | Value |
|-------|-------|
| Date | 2026-05-03 |
| Phase | Phase 8.6 — Activity Rings Widget (observer query not delivering updates) |
| Description | Activity ring values never update in real-time while the app is open. Changes in Apple Health data are not reflected until the app is relaunched. |
| Root Cause | Two issues in `DefaultHealthKitClient.observeActivitySummaryChanges`: (1) The `HKObserverQuery` completion handler parameter was discarded with `_` — per Apple docs, not calling the completion handler prevents future update delivery. (2) Only `HKQuantityType(.activeEnergyBurned)` was observed; changes to exercise time or stand hours did not trigger a refresh. |
| Resolution | Rewrote `observeActivitySummaryChanges` to observe all three contributing types (`activeEnergyBurned`, `appleExerciseTime`, `appleStandHour`) and call the `completionHandler()` in both the success and error paths. |
| Status | Resolved |

---

### BUG-028

| Field | Value |
|-------|-------|
| Date | 2026-05-03 |
| Phase | Phase 8.6 — Activity Rings Widget (activity rings always show zeros) |
| Description | Activity ring values display 0/goal for all three rings despite Apple Fitness showing real progress (e.g., Move 250/690, Exercise 16/30, Stand 8/6). The widget reaches the Live Rings state (State 3) but never populates actual data. |
| Root Cause | `DefaultHealthKitClient.readTypes` did not include `HKObjectType.activitySummaryType()`. Apple documentation for `activitySummaryType()` states: "Use this type to request permission to read HKActivitySummary objects from the HealthKit store." Without this type in the authorization request, `HKActivitySummaryQuery` silently returns empty results (HealthKit never reveals read-access denial). The individual types (`activeEnergyBurned`, `appleExerciseTime`, `appleStandHour`) authorize reading individual samples, not aggregated activity summaries. |
| Resolution | Added `HKObjectType.activitySummaryType()` to the `readTypes` set in `DefaultHealthKitClient`. Users who previously authorized HealthKit will need to re-authorize (the system will automatically show the authorization dialog for the new type on the next `requestAuthorization()` call). |
| Status | Resolved |

---

### BUG-029

| Field | Value |
|-------|-------|
| Date | 2026-05-03 |
| Phase | Phase 8.6 — Activity Rings Widget (chevron icons overflow outside rings) |
| Description | The three chevron icons (Stand, Exercise, Move) centered inside the activity rings overflow beyond the innermost (Stand) ring. The icons should fit entirely within the inner area of the stand ring. |
| Root Cause | The chevron icons in `ActivityRingsCanvas` used a fixed `font(.system(size: 10))` and `VStack(spacing: 2)`, giving a total height of ~36pt. The inner diameter of the stand ring at the 100×100 widget size is only ~24pt (`standRadius - ringThickness/2` × 2 = 12 × 2). The fixed size did not account for the available inner space. |
| Resolution | Replaced fixed icon size and spacing with dynamic calculation based on the stand ring's inner radius: `iconSize = max(standInnerRadius * 2 / 3.8, 5)` and `spacing: 0`. Also extracted `standRadius` as a shared `let` to avoid duplicating the formula. Icons now scale proportionally to the canvas size and stay within the innermost ring. |
| Status | Resolved |

---

### BUG-030

| Field | Value |
|-------|-------|
| Date | 2026-05-04 |
| Phase | Phase 8.6 — Activity Rings Integration Tests |
| Description | `test_closedAllRingsDayCount_correctlyCountsClosedDays` failed with `XCTAssertEqual failed: ("7") is not equal to ("3")`. The service reported 7 closed-ring days instead of the expected 3 within the last week. |
| Root Cause | `StubHealthKitClient.fetchActivitySummaries(from:to:)` returned all stored summaries without filtering by the requested date range. The test populated 21 days of summaries (7 of which had all rings closed), but only 3 of those fell within the last 7 days. The service's `refreshWeeklyClosure()` correctly requested a 7-day window, but the stub ignored the date parameters and returned all 21 summaries, causing the service to count all 7 closed days. |
| Resolution | Updated `StubHealthKitClient.fetchActivitySummaries(from:to:)` in `TestFixtures.swift` to filter `activitySummariesToReturn` by the requested date range, matching real `HealthKitClient` behavior. |
| Status | Resolved |

---

### BUG-031

| Field | Value |
|-------|-------|
| Date | 2026-05-04 |
| Phase | Phase 3 — Tab Navigation (navigation stack pop flash on tab switch) |
| Description | When switching tabs, the previous tab's navigation stack visibly pops back to its root view for a split second before the new tab appears. For example, viewing a workout detail on the Workouts tab and tapping Goals briefly shows the Workouts tab's NavigationStack popping back to the workout list. |
| Root Cause | Each tab view has an `onChange(of: selectedTab)` handler that synchronously resets all navigation state (setting `isPresented` booleans to `false`, nilling out `item` bindings) when leaving the tab. These resets trigger `.navigationDestination` pops immediately. Because SwiftUI's `TabView` keeps the outgoing tab's view hierarchy alive in memory, the pop animation is briefly visible during the tab transition before the old tab moves offscreen. |
| Resolution | Wrapped the navigation state resets in each tab's `onChange(of: selectedTab)` handler inside `DispatchQueue.main.async`, deferring them by one run loop cycle. By the time the resets fire, the tab transition has moved the old tab offscreen, making the pops invisible. |
| Status | Resolved |

---

### BUG-032

| Field | Value |
|-------|-------|
| Date | 2026-05-06 |
| Phase | Phase 6.1 — Trends Chart Visual Polish (FFA600 migration audit) |
| Description | IMPLEMENTATION_PLAN.md required searching for any `#FFA600` / `0xFFA600` literals and migrating them to the `chartOrange` token (`#FFBF51`). A codebase search found one reference: `statCardCalorie` in `Colors.swift` uses `FFA600`. This is a semantically distinct color token for calorie stat cards (Phase 8.5), not the chart orange token. No migration needed. |
| Root Cause | N/A — not a bug. Documenting the audit result per the Session Hygiene Checklist. |
| Resolution | No code change required. `statCardCalorie` (`FFA600`) is intentionally different from `chartOrange` (`FFBF51`). |
| Status | Resolved |

---

### BUG-033

| Field | Value |
|-------|-------|
| Date | 2026-05-06 |
| Phase | Phase 6.1 — Trends Chart Visual Polish (PointMark series parameter) |
| Description | Build failed at FortiFitProgressView.swift line ~615 with `Incorrect argument label in call (have 'x:y:series:', expected 'x:y:z:')` on a PointMark used for the Training Load Trend rolling-average highlight. |
| Root Cause | `PointMark` does not accept a `series:` parameter. The code passed `series: .value("Series", "AvgHighlight")` by analogy with `LineMark`, but PointMark's API only supports `x:`, `y:`, and `z:`. |
| Resolution | Removed the `series: .value("Series", "AvgHighlight")` argument from the PointMark. |
| Status | Resolved |

---

### BUG-034

| Field | Value |
|-------|-------|
| Date | 2026-05-06 |
| Phase | Phase 6.1 — Trends Chart Visual Polish (XCUI chart selection smoke tests) |
| Description | Two smoke tests (`test_trendsChart_dataPointTap_revealsSelectionAnnotation`, `test_trendsChart_toggleChange_clearsSelection`) cannot verify the chart tap-to-select and toggle-clears-selection behaviors. The tests need to trigger SwiftUI Charts `.chartXSelection` gestures via XCUI, but XCUI tap, press, and drag gestures on chart coordinates do not activate the `.chartXSelection` binding. |
| Root Cause | SwiftUI Charts renders marks in its own compositing layer. `.chartXSelection` uses an internal gesture recognizer that XCUI coordinate-based gestures (`.tap()`, `.press(forDuration:)`, `.press(forDuration:thenDragTo:)`) do not trigger. Chart mark `.accessibilityIdentifier()` modifiers create accessibility tree entries but these are not hittable XCUI elements. This is a known platform limitation of XCUI + Swift Charts. |
| Resolution | Tests rewritten to verify achievable assertions: chart card renders with data (card + header summary identifiers exist), time range toggle responds without crashing. Full selection annotation verification deferred to manual QA (see IMPLEMENTATION_PLAN.md § Manual QA). |
| Status | Open — pending platform support |

### BUG-035

| Field | Value |
|-------|-------|
| Date | 2026-05-10 |
| Phase | Phase 8.7 — Apple Watch Workout Scheduling |
| Description | When a user completes a planned workout via the Custom Workout push-to-Watch flow, the app creates a new workout record on the Plan screen instead of completing the existing ScheduledWorkout. The plan-ID round-trip fast-path in `HealthKitSyncService.processSnapshot()` never fires, so the incoming HK workout falls through to `autoCreate()`. |
| Root Cause | `DefaultHealthKitClient.makeSnapshot()` looked up the plan UUID via a guessed metadata key string (`"HKWorkoutPlanId"`). No public `HKMetadataKeyWorkoutPlanId` constant exists in HealthKit. WorkoutKit provides the plan identity through `HKWorkout.workoutPlan` (an async extension property), not through raw metadata. Because the metadata lookup always missed, `snapshot.workoutPlanId` was always `nil`, the fast-path in `HealthKitSyncService.processSnapshot()` was skipped, and the workout was treated as a brand-new import. |
| Resolution | Replaced metadata key lookup with `try? await workout.workoutPlan` (WorkoutKit extension on `HKWorkout`). Reads `plan.id` directly. Required making `makeSnapshot` async and restructuring `fetchWorkouts` to process snapshots outside the synchronous `HKAnchoredObjectQuery` callback. |
| Status | Resolved |

### BUG-036

| Field | Value |
|-------|-------|
| Date | 2026-05-10 |
| Phase | Phase 8.7 — Apple Watch Workout Scheduling |
| Description | Fatal crash ("Index out of range" in `ContiguousArrayBuffer`) when deleting an exercise on the Edit Planned Workout screen. |
| Root Cause | `exerciseCard(index:)` used `$viewModel.exercises[index]` subscript bindings throughout (text fields, rest/time toggles, row bindings). When `removeExercise(at:)` mutated the array, SwiftUI re-evaluated existing bindings from the previous render cycle before tearing down old views. Those bindings still held the now-stale integer index, which was out of bounds on the shrunken array. The same pattern existed for the inner row-level `ForEach`. |
| Resolution | Replaced all index-based `$viewModel.exercises[index]` bindings with ID-based safe `Binding` wrappers (`exerciseBinding(for: UUID)` and `rowBinding(exerciseId:rowId:)`). Getters use `first(where:)` with a harmless default fallback; setters guard with `firstIndex(where:)`. All mutation call sites (`removeExercise`, `removeRow`, `addRow`) now resolve the index at call time via `firstIndex`. |
| Status | Resolved |

### BUG-037

| Field | Value |
|-------|-------|
| Date | 2026-05-11 |
| Phase | Phase 7 — Plan (Workout Scheduler) |
| Description | When drag-swiping the week strip on the Plan screen, the day-of-week labels (MON, TUE, etc.) stay fixed while the date numbers shift. Labels and numbers become misaligned after any non-week-multiple drag. |
| Root Cause | `dayAbbreviations` is a hardcoded array `["MON"..."SUN"]` indexed by ForEach enumeration position (0-6). The drag gesture shifts `effectiveOffset` by individual days, changing which date lands at each position, but the label at each position never changes — position 0 always reads "MON" even when its date is a Tuesday. Additionally, the `.animation` modifier cross-fades numbers in place rather than sliding the entire strip, creating a visual split between static labels and transitioning numbers. |
| Resolution | Replaced the hardcoded array with a `dayAbbreviation(for:)` helper that derives the label from each date's actual weekday. Added `.id(effectiveOffset)` with a `.push` transition and explicit `withAnimation` to make the entire strip (labels + numbers + dots) slide as a unit on drag. |
| Status | Resolved |

---

### BUG-038

| Field | Value |
|-------|-------|
| Date | 2026-05-11 |
| Phase | Phase 7 — Plan (Schedule Workout template preview) |
| Description | On the Plan Workout (Schedule Workout) screen, the exercise count shown in the template preview cards is incorrect. For example, a template with 5 distinct exercises (each having 2 set rows) displays "10 exercises" instead of "5 exercises". The count reflects the total number of `TemplateExerciseSet` rows rather than the number of unique exercises. |
| Root Cause | `ScheduleWorkoutView.swift:361` uses `template.exerciseSets.count`, which counts every `TemplateExerciseSet` row (one per set/rep variation). A single exercise with 3 sets produces 3 `TemplateExerciseSet` records, so the displayed count is inflated by the number of sets per exercise. The count should instead be the number of distinct exercise names across those sets. |
| Resolution | Replaced `template.exerciseSets.count` with `Set(template.exerciseSets.map(\.exerciseName)).count` in `ScheduleWorkoutView.swift:361` to count distinct exercises instead of individual set rows. |
| Status | Resolved |

---

### BUG-039

| Field | Value |
|-------|-------|
| Date | 2026-05-11 |
| Phase | Phase 3 / Phase 7 — Edit Workout Template + Edit Planned Workout (exercise set ordering) |
| Description | On the Edit Workout Template and Edit Planned Workout screens, exercise set rows within each exercise appear in a non-deterministic order instead of the order they were entered. For example, a user entering Overhead Press at 95, 115, 135 lbs (ascending) may see 115, 135, 95 after reopening the screen. Same class of bug as BUG-010, which was fixed for Log Workout / Edit Workout but not applied to these two surfaces. |
| Root Cause | **Edit Workout Template:** `WorkoutTemplateViewModel.buildExerciseData()` (line 158) assigns `sortOrder: index` where `index` is the exercise-level enumeration index, not a per-row counter. All rows within the same exercise receive the same `sortOrder` value. When `TemplateExerciseSet` records are later queried from SwiftData, rows with identical `sortOrder` appear in non-deterministic order. This bad data also propagates downstream to scheduled workout snapshots via `PlanService.encodeSnapshot(template:)`, which reads from `template.exerciseSets.sorted { $0.sortOrder < $1.sortOrder }`. **Edit Planned Workout:** The `performSave` path correctly uses a global counter (line 152), so re-saving fixes ordering. However, if the initial snapshot was created from a template with duplicate `sortOrder` values, the loaded rows inherit the ambiguous ordering. |
| Resolution | Changed `WorkoutTemplateViewModel.buildExerciseData()` to use a global sequential counter (`globalSortOrder`) incremented per row instead of using the exercise-level enumeration index. Each row now gets a unique, sequential `sortOrder` value. Regression test: `WorkoutTemplateServiceTests/test_multiRowExercise_producesUniqueSortOrders`. |
| Status | Resolved |

---

### BUG-040

| Field | Value |
|-------|-------|
| Date | 2026-05-11 |
| Phase | Phase 6.2 — Trends Chart Detail View (Strength Tracker exercise dropdown missing) |
| Description | The Strength Tracker chart on the compact Trends card correctly shows an inline `FortiFitSelect` dropdown to pick which exercise to display (e.g. Barbell Rows, Barbell Squats, Overhead Press). When the user taps into the detail view (`FortiFitChartDetailView`), the dropdown is absent — the chart renders with whatever exercise was last selected on the compact card, but there is no way to change it. The Personal Records detail view does not have this problem; it renders its own `FortiFitSelect` dropdown. |
| Root Cause | `FortiFitChartDetailView` reads `selectedStrengthExercise` from UserDefaults at init (key `"trendsSelectedExercise"`) and passes it to `lineChartDetail(...)` via `exerciseNameForChart(...)`, but never renders a `FortiFitSelect` control for the Strength Tracker chart type. The compact card's dropdown lives in `FortiFitProgressView.strengthTrackerCard` and uses `ProgressViewModel.selectedExercise` / `selectExercise(...)` — none of that wiring exists in the detail view. By contrast, the Personal Records detail view (`prTimelineDetail`) renders its own `FortiFitSelect` bound to `selectedPRExercise` with inline UserDefaults persistence, demonstrating the intended pattern. |
| Resolution | Added `TrendsChartService.exercisesWithStrengthData(context:)` to fetch sorted exercise names that have weight data. Added a `FortiFitSelect` dropdown to the `strengthTracker` case in `FortiFitChartDetailView.detailChartContent(...)`, bound to `selectedStrengthExercise` with inline UserDefaults persistence and `selectedIndex` reset on change — same pattern as `prTimelineDetail`. |
| Status | Resolved |

---

### BUG-041

| Field | Value |
|-------|-------|
| Date | 2026-05-12 |
| Phase | Phase 6 — Trends Screen (chart reorder drag state stuck) |
| Description | On the Trends screen, when reordering charts via drag-and-drop, one or more chart cards remain visually greyed out (opacity 0.5) after the drag ends. The greyed state persists even after exiting reorder/edit mode by tapping the screen or switching tabs. The chart still functions, but its appearance is incorrect until the view is recreated (e.g., relaunching the app). The same pattern likely affects the other reorderable screens (Home widgets, Goals, Workouts), though only Trends has been reported so far. |
| Root Cause | The dragged chart's greyed appearance is driven by `.opacity(draggingChartType == chart.chartType ? 0.5 : 1.0)` in `FortiFitProgressView.swift:172`. The `@State var draggingChartType: String?` is set inside `.onDrag { draggingChartType = chart.chartType ... }` (line 179) but is only reset to `nil` in `ChartDropDelegate.performDrop(...)` (line 1036). SwiftUI's `.onDrag` modifier does not provide a "drag ended" callback, and `performDrop` is only invoked when the drag terminates over a valid drop target. If the drag is cancelled (released outside any drop zone, or the gesture is interrupted), `draggingChartType` is never cleared and the source chart stays at 0.5 opacity indefinitely. Compounding factors after the BUG-041-adjacent change that kept reorder mode active across drops: the user now performs multiple successive drags before tapping to exit, increasing the surface area for a cancelled or mis-targeted drop to leave state stale. Neither the tap-to-exit handler, `onDisappear`, nor the tab-change handler reset `draggingChartType`, so leaving reorder mode does not recover. |
| Resolution | Two-layer fix on all four reorderable screens (`FortiFitProgressView`, `HomeView`, `GoalsView`, `WorkoutListView`): (1) **`onChange(of: isReorderMode/isEditMode)`** resets the dragging state variable when reorder/edit mode transitions to false, so any path out of edit mode (tap, tab switch, `onDisappear`) recovers stale state. (2) **Catch-all `.onDrop(of: [.text], isTargeted: nil)`** on the outer ScrollView/container fires when a drop lands outside any inner card/widget/goal, immediately clearing the stale drag state while the user is still in edit mode. SwiftUI's drop-target nesting routes successful inner drops to their inner delegates and only routes "missed" drops to the outer catch-all (which returns `false` to signal the drop wasn't actually consumed for reordering — just used for cleanup). The first fix alone left stuck-greyed cards visible during long edit sessions; the catch-all closes that gap. |
| Status | Resolved |

---

### BUG-042

| Field | Value |
|-------|-------|
| Date | 2026-05-16 |
| Phase | Phase 3 — Goals Screen (Weekly Workouts goal "COMPLETED" date) |
| Description | On the Goals screen, the "COMPLETED <date>" label on a satisfied Number of Weekly Workouts goal card always shows the current date instead of the date the goal was actually completed. Example: user hits the weekly workouts target on May 14, but on May 16 the card reads "COMPLETED MAY 16, 2026". Re-opening the Goals screen on any later day within the same week silently rewrites the celebrated date to that day. Non-weekly goals (Strength PR / Repetitions PR / Speed and Distance) are unaffected — their completion date sticks. |
| Root Cause | `GoalService.checkAndFireCompletion(goal:)` (`GoalService.swift:409–419`) sets `goal.lastCelebratedDate = today` whenever the existing celebrated day is strictly earlier than today (`guard today > lastCelebratedDay else { return }` allows the assignment through on a later day). For non-weekly goals this is fine because the function is only invoked on the 0→100% crossing edge (`GoalService.swift:336–340`: `if newProgress >= 100 && previousProgress < 100`), so the assignment happens exactly once on the day of completion. For the weekly workouts goal, however, `checkAndFireCompletion` is called unconditionally whenever `progress.isComplete` is true — both from `recalculateGoals` (line 355–363, fires on every workout save/delete cascade) and from `ensureWeeklyGoalCelebration` (line 400–407, fires on every `GoalsView.onAppear` via `GoalsViewModel.loadGoals`). The result: the first time the goal is hit (e.g. May 14) the date is correctly stored, but any subsequent invocation on a later day in the same week — opening the Goals tab, logging an additional workout, any workout edit — passes the `today > lastCelebratedDay` guard and overwrites `lastCelebratedDate` to today. The intended semantics for the weekly goal is "first date the target was hit within the current ISO week", not "most recent day the goal was still complete". |
| Resolution | Introduced a new week-aware helper `GoalService.checkAndFireWeeklyCompletion(goal:)` that early-returns when `lastCelebratedDate` already falls in the current ISO week (using `Date.isSameWeek(as:)`), and only updates the field on the first completion of a fresh week (or first-ever celebration). Re-pointed both weekly-specific call sites — `recalculateGoals` (workout cascade) and `ensureWeeklyGoalCelebration` (Goals screen `onAppear`) — to use the new helper. Left the existing `checkAndFireCompletion` untouched so non-weekly PR goals keep their edge-triggered "set once on 0→100% crossing" semantics. Added regression tests `WEEK-011 ensureCelebration_preservesFirstCompletionDateWithinSameWeek` and `WEEK-012 ensureCelebration_advancesAcrossWeekBoundary` in `FortiFitTests/GoalWeeklyWorkoutsTests.swift`. |
| Status | Resolved |


---

### BUG-043

| Field | Value |
|-------|-------|
| Date | 2026-05-18 |
| Phase | Phase 8.8 — Today's Plan Detail Sheet (isometric exercise rendered as reps) |
| Description | On the Today's Plan Detail Sheet, a planned workout containing Planks rendered the set group as `5 × 60 reps` instead of `5 × 60s`. The same bug would affect any isometric exercise (Dead Hang, Wall Sit, L-Sit, etc.) and any ambiguous-default-time exercise (Battle Ropes, Sled Push, Farmers Walks) whose template/snapshot did not have `displayAsTime` explicitly set. |
| Root Cause | `FortiFitTodaysPlanDetailSheet.setLine(group:)` read `group.displayAsTime ?? false` directly. The `displayAsTime` field on `SnapshotExercise` is optional and only carries a value when the template author toggled the REPS/TIME segmented control on the exercise card. Older templates and templates whose authors left the control alone serialize `displayAsTime` as `nil`. With `?? false`, the renderer treated every nil-flagged snapshot exercise as reps-based regardless of whether the exercise name was in `AppConstants.isometricExerciseNames` or `AppConstants.ambiguousExerciseDefaultModes`. The correct resolution (per WORKOUTKIT.md § 6 and the existing `ExerciseSuggestionService.isIsometric(_:)` helper) is: explicit `displayAsTime` wins → else look up the exercise name through alias map → isometric set → ambiguous defaults → reps-mode fallback. The sheet bypassed that helper. |
| Resolution | Updated `setLine(group:)` to compute `isTime = group.displayAsTime ?? ExerciseSuggestionService.isIsometric(group.exerciseName)`. Now Planks etc. render as `5 × 60s` even when the snapshot’s flag is nil, while explicit overrides on the snapshot still win. No changes to the snapshot data model or the editing flow. |
| Status | Resolved |

---

### BUG-044

| Field | Value |
|-------|-------|
| Date | 2026-05-18 |
| Phase | Phase 8.8 — Today's Plan Detail Sheet (Modify Exercises does nothing) |
| Description | On the Today's Plan Detail Sheet, tapping **Complete Workout** on a Planned row opens the `CompletePlanView` completion sub-sheet. From that sub-sheet, tapping **Modify Exercises** dismisses the sub-sheet but does nothing else — the user is left back on the detail sheet with no way to actually modify the workout's exercises. Expected behavior (matching the Plan tab and the Home tab's planned-workout completion flow) is for Modify Exercises to dismiss the completion sub-sheet *and* the parent detail sheet, then push the user to the Log Workout screen pre-populated from the `ScheduledWorkout` snapshot so they can edit exercises/sets/reps/weights before saving. |
| Root Cause | `FortiFitTodaysPlanDetailSheet.swift:65–67` wires the `onModifyExercises` closure of the embedded `CompletePlanView` as `{ completionTarget = nil }` — i.e. it only clears the `@State` that drives the completion sub-sheet's `.sheet(item:)` binding. Compare with the two other call sites of the same `CompletePlanView`: `PlanView.swift:189–194` and `HomeView.swift:235–240` both dismiss the completion sheet *and* call `prepareLogWorkoutFromScheduled(scheduled)` (PlanView/HomeView each define a local helper that resets the shared `WorkoutViewModel`, copies the workout name/type/duration/scheduled-id, and decodes the snapshot into `ExerciseFormEntry` rows). Their parent views also gate a `.navigationDestination(isPresented:)` to `LogWorkoutView` that fires when the view model's "ready" state flips, completing the push. The detail sheet has none of this: it neither has access to `prepareLogWorkoutFromScheduled` (the helper is private to HomeView/PlanView, not shared), nor does it dismiss itself, nor does it propagate a "go to Log Workout" intent to its host. So the Modify Exercises tap is a no-op beyond closing the sub-sheet. |
| Resolution | Added a new `onModifyExercises: ((ScheduledWorkout) -> Void)?` callback on `FortiFitTodaysPlanDetailSheet` (mirror of `onNavigateToCompletedWorkout`). Rewrote the `CompletePlanView.onModifyExercises` closure inside the detail sheet to capture the current `completionTarget`, clear it, call `dismiss()` on the detail sheet, then `DispatchQueue.main.asyncAfter(deadline: .now() + 0.2)` and fire the new callback with the captured `ScheduledWorkout` — same 0.2s post-dismiss delay already used by `onNavigateToCompletedWorkout` so the parent sheet finishes dismissing before the host triggers navigation. Wired `HomeView.widgetDetailSheet(for: .todaysPlan)` to pass `onModifyExercises: { scheduled in prepareLogWorkoutFromScheduled(scheduled) }`. No new helper or nav-state added — `prepareLogWorkoutFromScheduled` already sets `workoutVM.showLogWorkout = true`, which trips the existing `.navigationDestination(isPresented: $workoutVM.showLogWorkout)` at `HomeView.swift:209` to push `LogWorkoutView`. Same path Modify Exercises already followed from the Home tab's own completion sheet and from the Plan tab. |
| Status | Resolved |

---

### BUG-045

| Field | Value |
|-------|-------|
| Date | 2026-05-19 |
| Phase | Phase 8.8 — Training Load Detail Sheet (latest chart point disagrees with hero score) |
| Description | On the Training Load Insights sheet, the most recent data point on the "Last 14 days" line chart does not match the hero score at the top of the sheet. Example reported on May 19, 2026 at ~08:08 AM: hero shows 83/100 (Peak) while the chart's latest point reads 53/100 (Moderate). The gap is largest when the sheet is opened in the morning (when "end-of-day" is many hours away from "now") and shrinks toward zero late at night. Past 13 buckets are unaffected — only the last point disagrees with the hero. |
| Root Cause | `ExerciseLoadService.fourteenDayDailyScores` builds each daily bucket by advancing the reference clock to `dayEnd - 1 second` (i.e. 23:59:59 of that calendar day), then calls `calculateLoad(now: referenceTime)`. For historical buckets this is correct — it asks "what was the score at end of that day?". For the today bucket (`offset == 0`) this projects the decay forward to end-of-day, so workouts logged earlier today/yesterday have decayed by 16+ extra hours relative to the hero (which uses real `Date()`). The hero and chart's last point therefore diverge by `exp(-Δhours/24/τ)` worth of retained stress — substantial when `τ = 2.0` (Intermediate) and the user's most recent workout is within a couple of days. The `× 150` same-day floor doesn't paper over this because the floor caps at 80, and on a day with no workouts yet `todayStress = 0` so the floor is 0. |
| Resolution | Special-cased the latest bucket inside `fourteenDayDailyScores`: when `offset == 0` the reference time is the passed-in `now` directly, otherwise it remains end-of-day. This makes the chart's last point literally `calculateLoad(..., now: now)` — identical inputs to the hero — so they agree by construction. Past 13 buckets unchanged. Added regression test `test_fourteenDayDailyScores_latestEntryMatchesHeroScore` in `FortiFitTests/TrainingLoadDetailHelpersUnitTests.swift` referencing BUG-045 in the doc comment. |
| Status | Resolved |

---

### BUG-046

| Field | Value |
|-------|-------|
| Date | 2026-05-19 |
| Phase | Phase 8.8 — Power Level Breakdown Sheet ("Driving your trend" deltas and advisory message stuck at "+0% / flat" for fresh data) |
| Description | After seeding four Barbell Squats workouts (varying volume) on a fresh install, the Power Level Breakdown Sheet's "Driving your trend" rows all rendered as `+0%` and the advisory copy read *"Volume on Barbell Squats is flat over the last 30 days. Adding ~5% weight or 1–2 reps could push you into Rising."* The deltas and message did not respond to the volume variation, making the sheet look broken to a user who had clearly varied their training. |
| Root Cause | Working as spec'd but with a misleading presentation. `PowerLevelService.topContributingExercises` computes per-exercise `deltaPct = ((currentVolume - previousVolume) / previousVolume) × 100`, hard-defaulting to `0` when `previousVolume == 0` (PowerLevelService.swift:256-261). Since the user had no workouts in days -60 → -31, every exercise's `previousWindowVolume` was 0 → every `deltaPct = 0`. Likewise, `calculatePowerLevel` falls back to `.steady` when `baselineAvg == 0` (PowerLevelService.swift:58-60), so `computeNudge` entered the steady branch and emitted the "flat… push you into Rising" copy. The user had no signal that the trend math requires a 60-day comparison window. |
| Resolution | (1) Added a new nudge archetype `PowerLevelNudgeArchetype.noBaseline` and a new copy key `noBaseline` in `AppConstants.PowerLevel.nudgeCopy` that explicitly states *"Trend comparisons use the prior 30 days as a baseline. Keep logging — once you have 60 days of Strength or HIIT history…"*. (2) Inserted a no-baseline guard in `PowerLevelService.computeNudge` that fires after the cold-start guard: when `currentWorkouts.count >= 3 && previousWorkouts.isEmpty`, emit `.noBaseline` instead of `.steady`. (3) In `FortiFitPowerLevelDetailSheet.topExerciseRow`, render an em-dash (`—`, Muted Text) instead of "+0%" whenever `exercise.previousWindowVolume == 0`, so the row delta agrees with the advisory message. (4) Spec updates: SERVICES.md § Nudge Computation (resolution-order step 2), INFO_COPY.md § Power Level Nudge Copy (new `noBaseline` section + constant block), SCREENS.md § Power Level Breakdown Sheet block 3 (em-dash rendering) and block 5 (five archetypes). (5) Regression tests added in `FortiFitTests/PowerLevelDetailHelpersUnitTests.swift`: `test_computeNudge_currentWindowOnlyWithEmptyBaseline_returnsNoBaseline` and `test_topContributingExercises_emptyBaseline_reportsZeroPreviousVolume`, both referencing BUG-046 in their doc comments. **Follow-up (same day):** initial guard was too coarse — `previousWorkouts.isEmpty` is false when prior-window workouts exist but for DIFFERENT exercises than the cited top exercise (e.g., user has Bench Press history but the current window's top exercise is brand-new Barbell Squats). Per-exercise rows correctly showed em-dashes via `previousWindowVolume == 0`, but `computeNudge` fell into the steady branch and emitted *"Volume on Barbell Squats is flat…"*. Added per-exercise baseline check inside the `.steady` and `.rising` branches: in `.steady`, if `top.previousWindowVolume == 0` degrade to `noBaseline`; in `.rising`, if `top.previousWindowVolume == 0` suppress `topExerciseName` so the copy falls back to `risingNoTop`. Added regression test `test_computeNudge_steadyWithTopExerciseLackingBaseline_returnsNoBaseline`. Updated SERVICES.md § Nudge Computation resolution-order step 3 to document both per-exercise baseline checks. |
| Status | Resolved |
