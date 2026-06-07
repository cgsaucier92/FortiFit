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

---

### BUG-047

| Field | Value |
|-------|-------|
| Date | 2026-05-21 |
| Phase | Phase 11 spec review — Home Screen Widget Edit Mode "x" delete button documented but not implemented |
| Description | SCREENS.md § Home Screen → Widget Edit Mode previously described an "x" delete button in the top-right of each widget card during edit mode (24×24pt circular, `#2d2d2d` bg, `#404040` border, muted "×") that tapped to delete the `HomeWidget` record. The same affordance was referenced in the Home Screen States table's Edit Mode row ("All widgets show 'x' buttons") and indirectly in the Phase 8.8 Test Strategy ("'x' delete buttons remain visible"). No such button exists in the implementation. Deletion has always happened via the long-press context menu's `Delete Widget` item (SCREENS.md § Home Screen → Widget Context Menu → "Delete Widget"). The documentation drifted from the implementation at some point before Phase 11. Surfaced during the Phase 11 cross-doc review because the new SCREENS.md § Standard Patterns → Widget Linking and § Home Screen → Widget Edit Mode (Phase 11 sub-block) explicitly call out the absence of "x" delete buttons on the linked composite, prompting a parity check against the standard Widget Edit Mode behavior. |
| Root Cause | Documentation drift — likely a spec'd-but-not-implemented feature from an earlier Phase 4 / Phase 8.8 iteration. The implementation chose long-press → context menu as the single deletion path; the spec text was never updated to match. The Phase 8.8 Test Strategy in TESTING.md inherited the assumption without verification. |
| Resolution | Doc fix across three files: (1) SCREENS.md § Home Screen → Widget Edit Mode rewritten as drag-only edit mode with deletion routed exclusively through long-press → context menu (no inline "x"); SCREENS.md § Home Screen → States table updated to remove the "x button" reference; the same section gained a Phase 11 sub-block covering linked-pair composite drag behavior. (2) TESTING.md § Widget Detail Sheet Test Strategy (Phase 8.8) — edit-mode-tap-suppression scenario reworded to drop the "x buttons remain visible" expectation. (3) TESTING.md § Recovery Status & Widget Linking Test Strategy (Phase 11) — added a UI smoke regression assertion that no `widget_*_deleteButton`-style element exists in edit mode, scoped to all widget types. SERVICES.md § HomeWidgetService → Widget Linking documentation likewise removed a stale "x delete" reference in the manual-flag-clearing rules. No implementation changes — the implementation was already correct. |
| Status | Resolved (doc fix only) |

---

### BUG-048

| Field | Value |
|-------|-------|
| Date | 2026-05-21 |
| Phase | Phase 11 Step 2 — Recovery Status / Sleep Goal Import |
| Description | `HEALTHKIT.md § 17` Read Permission List, `HEALTHKIT.md § 21` Sleep Data section, and `SERVICES.md § HealthKitClient → fetchSleepDurationGoal()` all reference `HKCharacteristicTypeIdentifierSleepDurationGoal` as a real HealthKit read type used to populate `UserSettings.targetSleepHours` from Apple Health's user-set sleep goal. Verified against Apple Developer Documentation: HealthKit's public characteristic identifiers are `activityMoveMode`, `biologicalSex`, `bloodType`, `dateOfBirth`, `fitzpatrickSkinType`, `wheelchairUse` — there is **no** `sleepDurationGoal` characteristic in HealthKit. Discovered during Step 2 implementation when `HKCharacteristicType(.sleepDurationGoal)` failed to compile. |
| Root Cause | Spec drift — the Phase 11 design assumed an API surface that Apple does not expose. Apple's "Sleep Schedule" feature in the Health app stores sleep goals internally but does not surface them through HealthKit characteristics for third-party app reads. The mistake likely originated when designing the "Import from Apple Health" affordance for the Recovery Status Settings Modal by analogy to Activity Rings (where `HKActivitySummary` exposes ring goals). Sleep has no equivalent. |
| Resolution | (Step 2 implementation, code-only — spec fixes landed in Step 8.) **Step 2 code changes:** (1) Removed `HKCharacteristicType(.sleepDurationGoal)` from `DefaultHealthKitClient.readTypes`. (2) `DefaultHealthKitClient.fetchSleepDurationGoal()` now always returns `nil` with an in-source comment documenting the unavailability. (3) `RecoveryStatusService.importSleepGoalFromAppleHealth()` surfaces the documented "No sleep goal set in Apple Health." toast on every call. (4) The protocol method signature is retained so the Settings Modal "Import from Apple Health" button can still call it; the snap-to-0.5-hr + clamp logic is exercised in unit tests and ready for the day Apple ships a real API. **Step 8 spec edits:** HEALTHKIT.md § 17 Read Permission List — removed the `HKCharacteristicTypeIdentifierSleepDurationGoal` row + added a "Removed (BUG-048)" callout explaining the missing API; HEALTHKIT.md § 21 — updated `fetchSleepDurationGoal()` description to note the unavailability; SERVICES.md § HealthKitClient — updated the `fetchSleepDurationGoal()` row to mark the method as protocol-retained-but-non-functional; SCREENS.md § Recovery Status Settings Modal + § Linked Recovery & Load Settings Modal — Import button copy now notes BUG-048 and the always-emitted toast; CONSTANTS.md § Recovery Status Settings Modal → Import from Apple Health Button → Action row — same. The user-visible "No sleep goal set in Apple Health." copy is unchanged. Decision on whether to drop the Import button entirely is deferred — keeping it preserves the spec'd modal layout and gives us a clean upgrade path when/if Apple exposes the characteristic. |
| Status | Resolved (Step 2 code + Step 8 spec edits) |

---

### BUG-049

| Field | Value |
|-------|-------|
| Date | 2026-05-21 |
| Phase | Phase 11 Step 7 — Sleep-Load Correlation copy variants |
| Description | CONSTANTS.md § Linked Recovery & Load Detail Sheet → Correlation Callout defines two variants — `highSleepBetter` (triggered when `correlationDelta <= -5`) and `lowSleepWorse` (triggered when `correlationDelta >= +5`). Both variants describe the SAME directional correlation (good sleep → better recovery / less retained stress) from opposite perspectives. But the trigger conditions are OPPOSITE signs. The formula `delta = mean(highSleepScores) - mean(lowSleepScores)` yields a negative delta when high sleep correlates with lower next-day scores (the normal healthy correlation) — that hits `highSleepBetter`. To hit `lowSleepWorse` (delta ≥ +5), high sleep would have to correlate with HIGHER next-day scores than low sleep does — an inverted correlation that the copy text "Short nights leave your score ~N points higher" does NOT describe. Discovered while writing the `RealisticUserScenarioBuilder` integration test for Step 7 — a fixture explicitly modeling "short nights raise next-day score" produced `highSleepBetter`, not `lowSleepWorse`. |
| Root Cause | Spec ambiguity: the two variant names describe the same correlation direction from different angles ("strong nights help" vs "short nights hurt"), but the trigger conditions assume they're symmetric/opposite. In practice the formula's delta is the same sign for both phrasings, so one of the two variants is unreachable from realistic user data. |
| Resolution | (Step 7 — code unchanged; test expectation corrected. Step 8 — CONSTANTS spec clarified.) Implementation in `RecoveryStatusService.computeSleepLoadCorrelation()` and `AppConstants.RecoveryStatus.correlationCopy` matches the spec as written. The integration test (`RealisticUserScenarioBuilderTests.test_threeWeeksLowSleepScenarioYieldsEnoughPairedDaysForCorrelation`) was updated to expect `highSleepBetter` since the fixture's correlation direction triggers that variant. **Step 8 spec edit:** CONSTANTS.md § Linked Recovery & Load Detail Sheet → Correlation Callout — added the formula `correlationDelta = mean(highSleepScores) − mean(lowSleepScores)` directly above the variant table, renamed the second variant from "Low-sleep → much-higher-score" to "High-sleep → much-higher-score (inverted — rebound training pattern)" to reflect what positive delta actually means, and added a "Variant naming caveat (BUG-049)" callout explaining the two variants capture opposite underlying user behaviors (healthy correlation vs. rebound training). The copy strings themselves are unchanged — the user sees different phrasings that match the data direction. |
| Status | Resolved (Step 7 test correction + Step 8 spec clarification) |

---

### BUG-050

| Field | Value |
|-------|-------|
| Date | 2026-05-21 |
| Phase | Phase 11 Step 7 — UI smoke test coverage gap |
| Description | TESTING.md § Recovery Status & Widget Linking Test Strategy lists ~20 UI smoke scenarios for the Phase 11 Recovery Status widget and the Linked Recovery & Load composite (gating-state CTA dispatch, drag-to-link, manual unlink via long-press, combined detail sheet routing, See Info / Settings handoffs, the "no x button" regression assertion from BUG-047). The unit + integration test layers cover the same surface non-visually (gating-state resolution, tap-route resolution, isLinkedActive math, sleep cascade observer fires, manual-unlink flag stickyness, snapshot reads, sleep qualifier composition, archetype copy keys). The XCUI layer is not yet wired for Phase 11. The Phase 8.8 Detail Sheets that shipped before this phase also do not have full XCUI coverage — the existing `FortiFitUITests` target hosts only legacy smoke tests. |
| Root Cause | Scope. The Step 7 plan list explicitly says "Fill in remaining UI smoke tests per the same section's UI smoke row" but the existing UI test infrastructure (launch arguments, simulator setup for HK / sleep-scope manipulation, Settings deep-link verification) needs broader build-out than the Step 7 budget allows. The XCUI-specific contracts (verifying `UIApplication.openSettingsURLString` actually fires, Apple Health permission flows, `Reduce Motion` snap behavior on the 0.2s border-swap / 0.4s score tween) are also listed as "Untestable" in TESTING.md § Untestable, meaning even with full XCUI coverage some scenarios remain manual-QA-only. |
| Resolution | (No code changes — coverage deferral logged.) Unit + integration layers cover the functional surface comprehensively (155+ green Phase 11 tests across Steps 1–7). UI smoke implementation deferred to a Phase 11.x follow-up that can bring up the XCUI harness (HK manipulation, gating-state seeding via launch arguments, Settings deep-link capture). The scenarios listed in TESTING.md § Recovery Status & Widget Linking Test Strategy → UI smoke row are the canonical scope; the regression assertion from BUG-047 (no `widget_*_deleteButton` element in Widget Edit Mode) is the highest-priority addition when that harness lands. |
| Status | Open — pending Phase 11.x follow-up |

---

### BUG-051

| Field | Value |
|-------|-------|
| Date | 2026-05-21 |
| Phase | Phase 11 — Recovery Status widget (last-night sleep lookup) |
| Description | Between 6pm local time and midnight, the Recovery Status widget hero and detail-sheet hero render the no-sleep-last-night sub-state ("— h —m / NO DATA") and the stages bar / efficiency caption disappear, even when last night's sleep was correctly ingested into `DailySleepSnapshot`. The 7-day stat row continues to render because it reads `recent30DaySleep.suffix(7)` directly. Reproduces deterministically by launching the app after 6pm with at least one ingested snapshot. |
| Root Cause | `RecoveryStatusService.recomputeDerivedFromCache()` used `wakeUpDate(for: Date())` to compute "today's wake-up day" for the `todaysSnapshot` lookup. `wakeUpDate(for:)` is the sample-attribution helper — it rolls end-dates after 6pm forward to the *next* calendar day so an evening nap sample groups with tomorrow's wake-up window (HEALTHKIT.md § 21). Applied to `Date()` after 6pm, it returns tomorrow's start-of-day, but cached snapshots for last night are keyed to today's start-of-day, so the `first(where: isDate(_:inSameDayAs:))` lookup never matched and `todaysSnapshot` was nil. Existing tests bypassed the bug by assigning `svc.todaysSnapshot` directly rather than driving it through `recomputeDerivedFromCache`. |
| Resolution | Replaced `wakeUpDate(for: Date())` with `Calendar.current.startOfDay(for: Date())` in `recomputeDerivedFromCache()`. The two helpers are intentionally distinct: `wakeUpDate(for:)` is for *sample* attribution (where past-6pm samples should roll forward to tomorrow); `startOfDay(for: Date())` is for *lookup* (the user already woke up today regardless of the current hour). Added a regression test that pre-seeds a snapshot keyed to today's start-of-day and asserts `todaysSnapshot` is non-nil after `reloadCacheFromStore` — passes at any time of day. |
| Status | Resolved |

---

### BUG-052

| Field | Value |
|-------|-------|
| Date | 2026-05-27 |
| Phase | Phase 11 — Recovery Status widget (sleep aggregation accuracy) |
| Description | The Recovery Status widget's nightly sleep total ran several minutes short of Apple Health's `TIME ASLEEP` value for the same night (e.g., FitNavi reported `7h 50m` while Apple Health reported `7h 57m` — a 7-minute gap on ~470 minutes). The deep / REM / core per-stage minutes also drifted relative to the underlying sample durations. The widget hero, the detail-sheet stages bar, and the `DailySleepSnapshot` row used downstream by the linked Training Load sleep-adjusted decay were all affected by the same off-by-a-few-minutes error. |
| Root Cause | `HKSleepSampleSnapshot.durationMinutes` rounded each sample to whole minutes at construction time (`Int((endDate.timeIntervalSince(startDate) / 60.0).rounded())`), and `RecoveryStatusService.aggregate(samples:)` summed those already-rounded ints. Apple Watch writes a fresh `HKCategorySample` on every stage transition (~30–60 samples per night), and each sample carries up to ±30 seconds of rounding error. Apple Health computes `TIME ASLEEP` by summing raw sample seconds and rounding once at the end, so the sum-of-rounded-pieces strategy drifts by a few minutes per night with std-dev growing as √N. The stage definition (`totalSleepMinutes = deep + REM + core`, excluding awake / inBed) was correct; only the rounding strategy was off. |
| Resolution | Two-part fix. **Part 1** — Replaced `HKSleepSampleSnapshot.durationMinutes: Int` with `durationSeconds: TimeInterval` (raw, un-rounded). Rewrote `RecoveryStatusService.aggregate(samples:)` to accumulate per-stage seconds and round once at the end. This cut the discrepancy from ~7 min to ~1 min. **Part 2** — Added an in-session transition-gap credit to `totalSleepMinutes`. Apple Watch writes each stage as its own sample with 1–2 second gaps in between; Apple Health computes asleep as session-span minus awake, so those gaps end up counted. Our pure sum-of-durations was running ~30–60 seconds short across a 30–60-transition night. New helper `inSessionTransitionGapSeconds(samples:)` sorts non-`.inBed` samples by `startDate` and sums positive gaps shorter than 5 minutes between consecutive pairs (the 5-min threshold rejects between-session gaps like nap-to-overnight). Per-stage minutes still use round-to-nearest; the gap credit lands only in `totalSleepMinutes`. Test coverage: `SleepAggregationRoundingTests` (sum-then-round signature, large-gap rejection, small-gap credit) and integration test `fractionalSecondSamplesProduceSumThenRoundTotal` drives the full sample → ingest → `DailySleepSnapshot` pipeline. |
| Status | Resolved |

---

### BUG-053

| Field | Value |
|-------|-------|
| Date | 2026-05-27 |
| Phase | Phase 11 — Linked Recovery & Load combined context menu (Unlink Widgets icon not rendering) |
| Description | In the combined long-press context menu on the linked Recovery Status + Training Load composite, the "Unlink Widgets" row showed its label text but no leading SF Symbol icon. The other three rows (See Info `info.circle`, Configure Settings `gear`, Reorder Widgets `arrow.up.arrow.down`) rendered their icons correctly. |
| Root Cause | The spec'd SF Symbol `link.slash` does not exist in the SF Symbols catalog (no `.slash` variant of the `link` family is provided by the system). `Label(_:systemImage:)` silently swallows unknown symbol names — the row still renders with the text, but the icon slot is blank. The CLAUDE.md / CONSTANTS.md / SCREENS.md Phase 11 spec referenced `link.slash` as if it existed; the code faithfully implemented the spec, so the bug surfaced at runtime only. |
| Resolution | Replaced `link.slash` with `rectangle.on.rectangle.slash` (a valid SF Symbol that visually communicates "two stacked things, broken apart" — the right metaphor for unlinking two widgets). Updated `HomeView.swift` Linked composite `contextMenu` Label, CONSTANTS.md § Linked Recovery & Load → SF Symbols, SCREENS.md § Home Screen → Widget Context Menu, and CLAUDE.md Phase 11 SF Symbols row to match. |
| Status | Resolved |

---

### BUG-054

| Field | Value |
|-------|-------|
| Date | 2026-05-27 |
| Phase | Phase 11 — Linked Recovery & Load Detail Sheet (14-day Training Load chart empty) |
| Description | In the "Recovery & Load Insights" detail sheet, the "Last 14 days · Training Load (sleep-adjusted)" sparkline rendered blank even when the user had more than 14 days of workout history. The companion "Last 14 days · Sleep duration" sparkline directly above it populated correctly. The standalone Training Load Detail Sheet (opened from the unlinked Training Load widget) rendered its 14-day chart normally. |
| Root Cause | `FortiFitLinkedRecoveryLoadDetailSheet.loadSparkline` called `ExerciseLoadService.snapshots(for:context:)` directly. That function returns only persisted `DailyTrainingLoadSnapshot` records — days without a snapshot are simply absent from the result. Snapshots are only captured by `captureTodaySnapshot` during cascade events (workout log/edit/delete, sleep ingest, link/unlink), so users who upgraded into Phase 11 mid-history, or who didn't trigger a cascade for several days, have no snapshots for the 14-day window and the chart renders empty. The standalone Training Load Detail Sheet uses `ExerciseLoadService.fourteenDayDailyScores(context:)` which gracefully falls back to a live baseline recompute for days without a persisted snapshot — this is the correct contract for any 14-day chart. |
| Resolution | Replaced the direct `snapshots(for:context:)` call in `FortiFitLinkedRecoveryLoadDetailSheet.loadSparkline` with `ExerciseLoadService.fourteenDayDailyScores(context:)`, mirroring the standalone Training Load Detail Sheet. The chart now renders all 14 days regardless of snapshot capture history — today is always live (matching the hero), historical days prefer the persisted snapshot when present (capturing the sleep-adjusted score the user saw on that day), and pre-snapshot days fall back to the baseline computation. |
| Status | Resolved |

---

### BUG-055

| Field | Value |
|-------|-------|
| Date | 2026-05-27 |
| Phase | Phase 11 — Home Widget Edit Mode (linked composite cannot be dragged or tapped to exit) |
| Description | While the Home tab was in edit/reorder mode, after the Recovery Status and Training Load widgets had been combined into the linked composite, the user could neither (a) drag the combined card to reorder it, nor (b) tap it to exit edit mode. Tapping any other widget (or empty space) still exited edit mode as expected, and the un-linked Recovery Status / Training Load widgets could be dragged normally. The composite also rendered without the trailing `line.3.horizontal` drag-handle overlay shown on every other card in edit mode. |
| Root Cause | Two independent gaps in `HomeView.linkedCompositeView`. **(1) No drag affordance.** Regular widgets get `.reorderableCard(payload:in:identifiedBy:)` applied in edit mode via `widgetCard(for:)`. The composite code path skipped that entirely and rendered the bare `FortiFitLinkedRecoveryLoadComposite` regardless of edit-mode state, so the composite was not a `.draggable` source nor a `.dropDestination` target. **(2) Tap swallowed.** `FortiFitLinkedRecoveryLoadComposite` registers `.onTapGesture { onTap() }` at the composite root. That gesture consumes the tap before it can bubble up to the parent `ScrollView`'s `.onTapGesture` (which is the mechanism that exits edit mode for non-linked widgets). The composite's `onTap` callback was gated on `!viewModel.isEditMode`, so in edit mode it became a no-op — the tap was absorbed and edit mode persisted. |
| Resolution | Restructured `linkedCompositeView` to (a) apply `.reorderableCard` to the composite when `viewModel.isEditMode == true`, with a new `reorderLinkedComposite(fromIndex:toIndex:)` helper that moves *both* `recoveryStatus` and `trainingLoad` as a single unit to the drop target's position while preserving their relative order (per SCREENS § Linked Recovery & Load Composite → Edit Mode: "The composite drags as one unit — dragging either card moves both"). The helper also calls `HomeWidgetService.clearManualUnlinkIfReorderAffectedPair` to maintain parity with the standard widget reorder path. (b) Added the trailing `line.3.horizontal` drag-handle overlay in edit mode, matching `widgetCard(for:)`. (c) Updated the composite's `onTap` so when edit mode is active it explicitly exits edit mode (`viewModel.isEditMode = false` with the same 0.2s easeInOut animation the ScrollView's tap-to-exit uses), rather than no-op'ing. |
| Status | Resolved |

---

### BUG-056

| Field | Value |
|-------|-------|
| Date | 2026-05-27 |
| Phase | Phase 11 — Linked Recovery & Load Settings Modal (Training Experience change does not refresh Training Load score) |
| Description | When the user opens "Configure Recovery & Load" on the linked composite and adjusts the Training Experience slider (Beginner / Intermediate / Advanced), the Training Load score displayed on the Training Load widget does not recompute after the modal closes. The standalone "Configure Training Load" modal (unlinked widget) updates the score correctly using the same slider. Target Workout Duration on the linked modal is also affected by the same gap, since both inputs feed `ExerciseLoadService.calculateLoad` and neither triggers a recompute on dismiss. |
| Root Cause | `HomeView.dismissTrainingLoadSettings()` (the dismiss handler for the standalone Training Load modal at `HomeView.swift:1085-1088`) calls `viewModel.loadData(context: modelContext)`, which re-runs `ExerciseLoadService.calculateLoad` against the just-mutated `UserSettings` and re-renders the widget. The linked modal's `onDismiss` closure (`HomeView.swift:222-229`) only sets `showLinkedRecoveryLoadSettings = false` and does not call `viewModel.loadData(...)`. Slider value changes mutate `UserSettings` immediately, but because `ExerciseLoadService.calculateLoad` is invoked from `HomeViewModel.loadData` (not via a UserSettings observer), the widget continues to show the pre-change score. The standalone-modal path masked the bug because its dismiss handler does the refresh; the linked-modal path was missing the equivalent line. Sleep Target changes happen to recompute because `RecoveryStatusService` observes `targetSleepHours` and runs its own cascade that includes `captureTodaySnapshot` — but that path doesn't fire for `experienceLevel` or `targetMinutesPerWorkout`. |
| Resolution | Mirrored the standalone path in `HomeView.linkedCompositeView`'s settings modal block (`HomeView.swift:222-231`): the `onDismiss` closure now calls `viewModel.loadData(context: modelContext)` immediately after setting `showLinkedRecoveryLoadSettings = false`. `HomeViewModel.loadData` invokes `ExerciseLoadService.calculateLoad` against the just-mutated `UserSettings`, so any change to `experienceLevel` or `targetMinutesPerWorkout` now recomputes the Training Load score on close — matching the behavior of `dismissTrainingLoadSettings()` at `HomeView.swift:1085-1088`. Snapshot capture continues to flow through the sleep cascade for `targetSleepHours` changes (unchanged). |
| Status | Resolved |

---

### BUG-057

| Field | Value |
|-------|-------|
| Date | 2026-05-27 |
| Phase | Phase 11 — Linked Recovery & Load Detail Sheet (Training Load week-over-week comparison; row was labeled "Stress Load" at the time of this bug, renamed later in Phase 11 for consistency with the widget name) |
| Description | The Training Load row (labeled "Stress Load" at the time) in the window-comparison block of the Recovery & Load Insights sheet showed extreme/nonsensical deltas (e.g. "↑ 51843% vs last week") even when current-week and prior-week workloads were roughly similar. |
| Root Cause | `ExerciseLoadService.weekOverWeekComparison` summed time-decayed contributions for both weeks using `now` as the single decay reference. With `τ = 2.0` (intermediate default), a workout 13 days ago contributes `exp(-13/2) ≈ 0.0015×` its raw stress while one 0 days ago contributes `1.0×`. Identical workloads in adjacent weeks therefore appear up to ~666× different purely because of the age offset, yielding the absurd delta. Time decay is the correct model for live readiness/fatigue (the Training Load score and the Contributing Workouts breakdown), but it is not what the "Training Load vs last week" band is describing — that band describes *workload performed* per week. |
| Resolution | Replaced the `decayedSum(in:)` helper in `weekOverWeekComparison` with a `rawSum(in:)` that sums un-decayed `sessionStress` per week. Identical workouts in current/prior week now yield `deltaPct == 0`; doubled workload yields `~+100%`; halved yields `~-50%`. Updated `SERVICES.md § Detail Sheet Helpers → TrainingLoadWeekComparison` to spec raw `session_stress` sums (the prior wording said `tssContribution`, which was the buggy intent). Added regression tests `test_weekOverWeekComparison_identicalWorkouts_returnsZeroDelta`, `test_weekOverWeekComparison_doubledThisWeek_returnsRoughly100PctIncrease`, and `test_weekOverWeekComparison_halvedThisWeek_returnsRoughly50PctDecrease` in `TrainingLoadDetailHelpersUnitTests.swift`. |
| Status | Resolved |

---

### BUG-058

| Field | Value |
|-------|-------|
| Date | 2026-05-27 |
| Phase | Phase 11 — Linked Recovery & Load Detail Sheet (Sleep week-over-week comparison) |
| Description | The Sleep row in the window-comparison block of the Recovery & Load Insights sheet used a different "week" definition than the Training Load row (then labeled "Stress Load") sitting directly above it, even though both rows shared the same "vs last week" label. Training Load uses ISO Mon–Sun calendar weeks; Sleep was computing means over a rolling 7-record window (`recent30.suffix(7)` vs `recent30.dropLast(7).suffix(7)`). Two consequences: (1) on any day except Sunday the two rows compared incomparable windows ("Training Load Mon–Wed vs Mon–Sun" alongside "Sleep last 7 records vs prior 7 records"); (2) any missing nights shifted the "last 7" record window past the calendar week into prior days, so a single untracked night could quietly slide the comparison off-week. |
| Root Cause | `sleepWeekComparisonDelta` was inlined in `FortiFitLinkedRecoveryLoadDetailSheet` and operated on `recent30.suffix(7)` / `recent30.dropLast(7).suffix(7)`. The slicing was by record-count, not by calendar window, so the helper had no notion of "this Mon–Sun" — it just took the latest 7 snapshots regardless of which calendar week they belonged to. The row label "vs last week" implied a calendar-week semantic that the math did not honor. |
| Resolution | Added `RecoveryStatusService.sleepWeekOverWeekComparison(now:)` returning a `SleepWeekComparison` struct (mean minutes for each week, rounded `deltaPct`, snapshot counts per window). Uses `Date.startOfWeek` / `endOfWeek` (ISO Mon–Sun, same boundaries as `ExerciseLoadService.weekOverWeekComparison`). Averages snapshots **present in each window only** — missing nights are skipped rather than zero-filled, so a single untracked night doesn't drag the mean down. Returns `deltaPct == 0` when the prior week has no snapshots (parallels the Training Load `previousWeekTss == 0` branch). `FortiFitLinkedRecoveryLoadDetailSheet.sleepWeekComparison{Delta,Text}` now delegates to the new helper. Added regression tests `test_sleepWeekOverWeekComparison_identicalSleep_returnsZeroDelta`, `test_sleepWeekOverWeekComparison_halvedThisWeek_returnsRoughly50PctDecrease`, `test_sleepWeekOverWeekComparison_missingNightInCurrentWeek_averagesPresentDaysOnly`, and `test_sleepWeekOverWeekComparison_noPriorWeekSnapshots_returnsZeroDelta` in a new `SleepWeekComparisonUnitTests.swift`. Updated `SCREENS.md § Linked Recovery & Load Detail Sheet → item 4` to call out the ISO Mon–Sun boundary and present-day averaging. |
| Status | Resolved |

---

### BUG-059

| Field | Value |
|-------|-------|
| Date | 2026-05-27 |
| Phase | Phase 11 — Recovery Status Detail Sheet (Sleep Efficiency caption) |
| Description | The "Sleep efficiency: XX% (Yh ZZm asleep of Nh MMm in bed)" caption was silently hidden in the Recovery Status Detail Sheet for users whose sleep is tracked solely by Apple Watch (the most common case). The detail sheet rendered the hero, stages bar, sparkline, and last-7-nights row normally but skipped the efficiency line, even though sleep stage data and awake periods were captured. |
| Root Cause | `RecoveryStatusService.aggregate(samples:)` populated `inBedMinutes` only by summing explicit `HKCategoryValueSleepAnalysis.inBed` samples (`agg.inBedMinutes = sawInBed ? Int((inBedSec / 60.0).rounded()) : nil`). Apple Watch's native sleep tracking (watchOS 9+) emits only stage samples — `.asleepDeep`, `.asleepREM`, `.asleepCore`, `.awake` — and does **not** write `.inBed` category samples. Apple Health derives "TIME IN BED" for these users from the bounds of the sleep session itself, but our aggregator did not. With no `.inBed` samples, `inBedMinutes` stayed nil, `sleepEfficiencyPercent` came back nil from `computeSleepEfficiency`, and the detail-sheet's `if let inBed = todaysSnapshot?.inBedMinutes` guard at `FortiFitRecoveryStatusDetailSheet.swift:39` evaluated false → caption hidden. |
| Resolution | In `RecoveryStatusService.aggregate(samples:)`, when no `.inBed` samples are present but stage samples are (`!sawInBed && agg.totalSleepMinutes > 0`), fall back to `inBedMinutes = totalSleepMinutes + awakeMinutes`. This approximates Apple Health's session-span TIB within rounding (the only difference is small in-session transition gaps already credited toward `totalSleepMinutes`) and yields a sensible `sleepEfficiencyPercent = round(asleep / (asleep + awake) × 100)` — the conventional "% of session spent asleep" definition. Existing `.inBed`-bearing sources (Oura, Whoop, AutoSleep, manual logging) continue to use their explicit samples unchanged. Also added a one-time **backfill in `reloadCacheFromStore`** so legacy snapshots written before this fix (still carrying `inBedMinutes == nil` despite having stage + awake data) are repaired on next launch — the previous fix alone only manifested for *new* aggregations and left existing users staring at a still-hidden caption until their next HK ingest. Backfill is idempotent and source-respecting (skips snapshots that already have non-nil `inBedMinutes`). Finally, added the matching `sleepEfficiencyCaptionBlock` to `FortiFitLinkedRecoveryLoadDetailSheet` between the stages bar and combined chart, since the linked "Recovery & Load Insights" sheet had no efficiency display at all even though it covers the same data. Updated `DailySleepSnapshot.inBedMinutes` doc comment to describe the fallback, repurposed the `aggregateWithNoInBedSamplesReturnsNilEfficiency` test to assert the new behavior under its new name `aggregateWithoutInBedFallsBackToAsleepPlusAwake`, added `SleepEfficiencyBackfillTests` covering legacy / explicit / zero-asleep paths, and updated `SERVICES.md § RecoveryStatusService → Sleep efficiency`, `SCREENS.md § Linked Recovery & Load Detail Sheet`, and `HEALTHKIT.md § 21` to reflect the spec change. |
| Status | Resolved |

---

### BUG-060

| Field | Value |
|-------|-------|
| Date | 2026-05-27 |
| Phase | Phase 11 — Home Widget Edit Mode (linked composite splits into two widgets when reordered) |
| Description | In Home edit/reorder mode, dragging the Linked Recovery & Load composite onto any other widget does not reposition the composite as a unit. Instead, the pair *splits*: Recovery Status jumps to the drop target's position while Training Load stays behind, breaking the Recovery Status ↔ Training Load adjacency. Because the auto-link rule requires adjacency, the composite then dissolves into the two standalone widgets. The reverse direction — dragging a non-pair widget onto the composite — moves both pair widgets together correctly (this path was added in BUG-055). Only the composite-as-source path is broken. |
| Root Cause | Asymmetric drop-destination handling between the composite and the regular widgets. The composite at `HomeView.swift:840-845` is the drop *source* with `payload: "recoveryStatus"` and registers `reorderLinkedComposite` as its own drop *destination* handler (which correctly moves both pair widgets, `HomeView.swift:882-907`). But `FortiFitReorderable.reorderableCard` invokes the `onReorder` of the **destination** card, not the source's. So when the composite is dragged onto e.g. `todaysPlan`, it is `todaysPlan`'s `reorderableCard` (`HomeView.swift:509-526`) that processes the drop — and that handler is the generic single-widget mover: it computes `fromIndex = activeWidgets.firstIndex(where: { $0.widgetType == "recoveryStatus" })` and runs a plain `types.move(fromOffsets:toOffset:)` on just that one entry, leaving `trainingLoad` untouched. The pair becomes non-adjacent and `HomeWidgetService.isLinkedActive` flips false → composite unlinks. `reorderLinkedComposite` only fires when the composite is the *destination*, which is why the inverse direction works. The bug only surfaces post-BUG-055 — before that fix the composite wasn't draggable at all. |
| Resolution | Extracted the pair-move array logic into a new static helper `HomeWidgetService.movePairOrderedTypes(previousOrderedTypes:targetType:)` — pure input → output, no view dependency, returns nil for invalid targets (pair member, missing target, missing pair widget). Updated `HomeView.movePairToTarget` to delegate to the helper, and updated `reorderLinkedComposite` (composite-as-destination path) to forward through `movePairToTarget`. Added a new branch at the top of `widgetCard`'s `onReorder` closure (`HomeView.swift:513-528`) that detects when the dragged payload is part of the active linked pair (`isLinkedActive && (draggedType == "recoveryStatus" || draggedType == "trainingLoad")`) and routes through `movePairToTarget(targetType: widget.widgetType)` instead of the generic single-widget `types.move`. This is the path SwiftUI invokes when the composite is the drop *source* (it runs the destination card's `onReorder`), so the pair now travels together regardless of drag direction. Added three regression tests to `LinkingLifecycleIntegrationTests` referencing BUG-060: `test_movePairOrderedTypes_compositeDraggedOntoLaterWidget_pairStaysAdjacentAndLinked` (pair after target → pair lands immediately after target), `test_movePairOrderedTypes_compositeDraggedOntoEarlierWidget_pairStaysAdjacentAndLinked` (pair before target → pair lands immediately before target), and `test_movePairOrderedTypes_returnsNilForInvalidTargets` (guard rails). All three pass; the four existing linking-lifecycle tests continue to pass. |
| Status | Resolved |

---

### BUG-061

| Field | Value |
|-------|-------|
| Date | 2026-05-27 |
| Phase | Phase 11 — Linked Recovery & Load (Training Load advisory + Sleep Qualifier contradiction) |
| Description | When the Recovery Status and Training Load widgets are linked, the composite advisory line concatenates the Training Load zone advisory with the Sleep Qualifier copy as `"\(base) \(qualifier)"` (`HomeView.linkedAwareAdvisory`, `HomeView.swift:919-929`). The two halves are computed from independent inputs (training-load score vs. last-night sleep ratio), and in the Resting/Low/Moderate readiness zones the base advisory prescribes training ("Ready for a full session." / "Ready to train." / "A moderate session would be ideal.") while the qualifier can simultaneously report "You're under-slept." or "You're significantly under-slept." The user-visible string then reads, e.g., *"Well recovered. Ready to train. You're significantly under-slept."* or *"Some muscle fatigue. A moderate session would be ideal. You're significantly under-slept."* — internally contradictory in both cases. High/Peak readiness ("Consider a lighter session or active recovery." / "Rest or very light activity recommended.") already counsel caution, so the qualifier reinforces rather than contradicts; Post-Training variants describe what was just done, not what to do next, so they're not affected. The Sleep-Adjusted Decay path does not save us: the sleep factor ∈ [0.60, 1.0] only slows decay of existing training stress, so a user with little/no recent workouts stays in Resting/Low/Moderate regardless of last night's sleep. |
| Root Cause | Spec-level coupling, not an algorithm bug. The Readiness-variant advisories for Resting, Low, and Moderate were written as complete prescriptions ("Ready for a full session" / "Ready to train" / "A moderate session would be ideal"), framing the user's go/no-go decision purely on muscular freshness. When the Sleep Qualifier is appended in the linked composite, it injects a second axis (sleep debt) that the base advisory did not reason about, producing the contradiction. Letting the qualifier override the base would lose the freshness signal; rewording all readiness copy to describe muscular state only (no prescription) makes Resting/Low/Moderate read sensibly with any qualifier — but flattens the advisory's usefulness for the *unlinked* case, where the prescription is the value. Better: replace the entire combined advisory with a single sleep-aware composite string when the qualifier would create a contradiction, and leave the unlinked base advisory unchanged. |
| Resolution | Replaced the entire concat-with-qualifier pattern in the linked path with a single joint-advisory lookup. Retired `RecoveryStatusService.computeSleepQualifier(...)` and `AppConstants.TrainingLoad.sleepQualifierCopy`. Added `AppConstants.TrainingLoad.linkedAdvisoryText` — a 27-string table keyed on `"<zone>\|<trainedToday>\|<sleepBucket>"` (5 zones × 2 `trainedToday` × 3 non-empty sleep buckets, minus 3 Resting × trained pairings prevented by the same-day floor). Added `RecoveryStatusService.computeLinkedAdvisory(baseAdvisory:zone:trainedToday:sleepHours:targetSleepHours:)` which buckets the sleep ratio, returns `baseAdvisory` unchanged for `metTarget` (0.85–0.99) and missing-data nights, and looks up a joint sentence in the new table for `strong`, `moderatelyBelow`, and `significantlyBelow`. Strong sleep no longer appends a separate sentence — it produces its own coherent joint line (e.g. *"Well recovered and sleep was strong — a great day to train hard."*) so the linked composite never reads as two contradictory voices. Encoded the override semantics directly in the copy: `moderatelyBelow` downgrades the recommendation one notch, `significantlyBelow` clamps it at light/rest, both name sleep as the reason. Added `trainedToday: Bool` to `ExerciseLoadService.LoadResult` so call sites pass the right key without re-deriving from the advisory string. Updated `HomeView.linkedAwareAdvisory` (`HomeView.swift:959-973`) and `FortiFitLinkedRecoveryLoadDetailSheet.recoveryReadinessCalloutBlock` (`FortiFitLinkedRecoveryLoadDetailSheet.swift:516-532`) to call the new function instead of concatenating. Scoping confirmed: the standalone Training Load widget body and `FortiFitTrainingLoadDetailSheet.recoveryCalloutBlock` continue to render `LoadResult.advisory` directly — the joint advisory never bleeds into the unlinked surface. Retired the obsolete `RecoveryStatusService.currentSleepQualifier` cached property + Sleep Cascade Step 6 (joint advisory depends on live zone + trainedToday inputs the service doesn't hold, so call sites compute on demand). Updated `CONSTANTS.md § Training Load Zones` (split into "Standalone" and "Linked Advisory Copy" subsections), `INFO_COPY.md § Training Load Zones → Linked Advisory Copy` (renamed from Sleep Qualifier Copy, full 27-string table inline), `SERVICES.md § RecoveryStatusService` (replaced Sleep Qualifier bullet + `currentSleepQualifier` row), `SCREENS.md § Home Screen → Training Load Linked variant` and § Linked Recovery & Load Detail Sheet → block 10, and `CLAUDE.md` Phase 11 row. Deleted the qualifier-only tests in `RecoveryStatusAlgorithmTests` (5 cases) and `SnapshotRenderingTests` (3 cases) per the joint-advisory replacement; added `LinkedAdvisoryTests` covering the contradiction cells and the new pass-through behavior. Regression tests referencing BUG-061: `test_lowZone_untrained_significantlyBelow_overridesWithLightRest`, `test_lowZone_untrained_moderatelyBelow_overridesWithModerate`, `test_moderateZone_untrained_significantlyBelow_overridesWithLightRest`, `test_moderateZone_untrained_moderatelyBelow_overridesWithLightSession`, `test_restingZone_untrained_significantlyBelow_overridesWithLightRest`, `test_highZone_trained_strong_returnsJointSentence`, `test_lowZone_untrained_strong_returnsJointSentence`, `test_metTarget_returnsBaseAdvisoryUnchanged`, `test_missingSleepData_returnsBaseAdvisoryUnchanged`. |
| Status | Resolved |

---

### BUG-062

| Field | Value |
|-------|-------|
| Date | 2026-05-27 |
| Phase | Phase 11 — Recovery Status widget (SINCE LAST WORKOUT hero value freezes after a manual log) |
| Description | After logging a workout, the Recovery Status widget's `SINCE LAST WORKOUT` hero value renders `0 min` and never advances. Reproduced by logging a workout and waiting on the Home tab — 30+ minutes later the value still reads `0 min`. The detail-sheet headline (which calls `lastWorkoutHero(context:)` directly on each render) updates correctly when the sheet is opened, confirming the formatter is fine; the bug is purely in how the cached value backing the widget is refreshed. |
| Root Cause | `RecoveryStatusService.lastWorkoutHeroFormatted` is only mutated from `refreshTimerLine(context:)`, which is only called from `WorkoutService` cascade points (`WorkoutService.swift:35`). At log time the cascade computes `0 min` (≪ 60s elapsed) and stores it. The widget read site (`HomeView.swift:676-678` and `:829-831`) prefers the cached value and only falls back to a live recompute when the cache string is empty — `"0 min"` is non-empty, so the fallback never engages and the value stays frozen until the next workout mutation. Spec at `SERVICES.md:1641` lists three refresh triggers for `timeSinceLastWorkoutFormatted` / `lastWorkoutHeroFormatted`: `Foreground entry, 60s timer while Home tab visible, Workout Cascade`. Only the Workout Cascade trigger was implemented — the foreground-entry and 60s-timer paths were never wired up. Pure spec-vs-code drift. |
| Resolution | Wired up the two missing triggers in `HomeView`: (1) `.task { while !Task.isCancelled { Task.sleep(60s); refreshTimerLine } }` — the modifier's lifecycle is tied to view appearance, so the loop runs only while Home is in the hierarchy and is cancelled automatically on disappear (matches the "60s timer while Home tab visible" spec). (2) `.onChange(of: scenePhase)` calling `refreshTimerLine` on `.active` (matches "Foreground entry"). (3) Bonus: added a `refreshTimerLine` call inside the existing `.onAppear`, so the value is correct on the very first paint after a cold launch (the cascade only fires on workout mutation, so first-launch reads would otherwise have shown an empty cache string and fallen through to the live path — correct, but the explicit prime keeps the cache and the live path in agreement). Used Swift Concurrency rather than `Timer.publish` to honor the no-Combine guidance in CLAUDE.md. Regression test added to `RecoveryStatusAlgorithmTests` referencing BUG-062: `test_refreshTimerLine_updatesLastWorkoutHeroFormatted_afterWorkoutInserted` — inserts a workout dated 20 minutes ago, calls `refreshTimerLine(context:)`, asserts `lastWorkoutHeroFormatted == "20 min"`. Documents the contract HomeView's new triggers depend on; if anyone later removes the cache write inside `refreshTimerLine`, this fails before the widget regression resurfaces. |
| Status | Resolved |

---

### BUG-063

| Field | Value |
|-------|-------|
| Date | 2026-05-28 |
| Phase | Phase 11 — Linked Recovery & Load (Sleep Impact Chip mis-attributes a discretization artifact to sleep) |
| Description | The `sleepImpactChip` in `HomeView.swift:950-1005` was producing non-zero "from sleep" deltas — including impossible *negative* deltas (e.g. `↓ −12 from sleep`) — even when the user's last-night sleep was essentially at the configured target (sleep ratio ≈ 0.995 → `sleepFactor` ≈ 0.998). Repro: sleep 6h 58m, `targetSleepHours = 7.0`, `experienceLevel = 2` (Advanced, τ=1.5), two strength workouts logged on Wed → chip reads `↓ −12 from sleep` colored green (the "sleep saved you 12 points" branch). Debug print confirmed both algorithms ran with the same workouts, sleep snapshots, and settings; the divergence was purely in the *shape* of the two decay functions being compared. |
| Root Cause | The chip computed `delta = linked.score − baseline.score` where `linked = ExerciseLoadService.computeCurrentScore(...)` (discrete per-day-step decay, sleep-aware) and `baseline = ExerciseLoadService.calculateLoad(...)` (continuous-time decay, sleep-blind). These two functions don't agree even when sleep is exactly at target — `calculateLoad` integrates `exp(−daysAgo/τ)` over the real-valued elapsed time, while `computeCurrentScore` multiplies by `(1 − λ·factor)` once per midnight crossed. With `factor = 1.0`, the two match at integer-day boundaries but diverge at every fractional offset. Per-workout sign rule: workouts logged *earlier in the day than current viewing time* → discrete under-decays → `linked > baseline`; workouts logged *later in the day than current viewing time* → discrete over-decays → `linked < baseline`. The artifact compounds across multiple workouts in the 10-day lookback. With τ=1.5 (Advanced), λ ≈ 0.487 is large enough that the per-day gap reaches 1–2 score points per contributing workout, easily summing to ±12. The artifact has nothing to do with sleep — it would persist even if the user slept exactly 7.0 hours every night. Compounding issue: `sleepFactor` is clamped to `[0.60, 1.0]`, so sleep alone can only *slow* decay (raise the score) — meaning the legitimate sleep delta is mathematically `≥ 0` always. Negative deltas were only ever reachable via the artifact, yet the chip's color logic included branches for `−4...−1` and `≤ −5` deltas (rendered amber and green respectively), implying the designer expected a "sleep helped recovery" semantic that the algorithm can't actually produce. |
| Resolution | Fixed the chip's baseline so both sides of the delta use the same decay *shape*. The new `baseline` calls `computeCurrentScore(...)` with `sleepSnapshotsByDay: [:]` (empty map) — per `perDayFactor`, every day falls through to the missing-data fallback `factor = 1.0`, producing the discrete-day-step decay with neutral sleep. `linked` keeps the real snapshot map. The only difference between the two is now the per-day `sleepFactor` variation, which is exactly what "from sleep" should mean. With at-target sleep on every relevant day, the two products are identical → `delta = 0` (correct). With sub-target sleep on intervening days, `linked > baseline` by exactly the slowed-decay contribution → `delta > 0` (correct). With above-target sleep, `sleepFactor` saturates at 1.0 → `delta = 0`. Negative deltas are now mathematically impossible, so the dead `−4...−1` and `default` (≤−5) color branches were removed — the switch now collapses to `5...`/`1...4`/`0` with `0` colored as the positive/neutral state (was muted gray, now green since "sleep matched target" is a good outcome). Regression tests added to `RecoveryStatusAlgorithmTests` (new `SleepImpactChipBaselineTests` struct) referencing BUG-063: `test_sleepImpactChip_atTargetSleep_returnsZeroDelta` (asserts `computeCurrentScore` with at-target snapshots produces the same score as with an empty map → delta = 0); `test_sleepImpactChip_belowTargetSleep_returnsPositiveDelta` (asserts the snapshot-aware variant produces a strictly higher score when an intervening day's sleep is below target); `test_sleepImpactChip_aboveTargetSleep_returnsZeroDelta` (asserts the `sleepFactor` ceiling clamp holds — over-sleeping doesn't lower the score). |
| Status | Resolved |

---

### BUG-064

| Field | Value |
|-------|-------|
| Date | 2026-05-28 |
| Phase | Phase 11 — Linked Recovery & Load (Training Load widget bar renders sleep-blind score even when linked) |
| Description | In the linked composite, the Training Load widget displays three different score representations: (1) the **bar/zone/advisory** on the widget body, (2) the **chip** showing "from sleep," and (3) the **`DailyTrainingLoadSnapshot`** that gets persisted to disk for the Trends chart. The bar is the user's primary signal — it's what they look at to gauge readiness — but it was being rendered from the sleep-*blind* baseline calculation, while the linked detail sheet, the snapshot capture path, and the chip's "linked" side all use the sleep-*aware* calculation. So in the linked state the user saw a bar that didn't reflect what their sleep actually did to recovery, with a chip below it gesturing at a delta the bar never showed. On a day with strong same-day workout stress this was masked by the Same-Day Floor (both algorithms collapse to floor → bar coincidentally matches), but on any non-floor-pinned day the bar would diverge from the persisted snapshot and from the detail-sheet score. |
| Root Cause | `HomeViewModel.loadData(context:)` at `HomeViewModel.swift:96-103` unconditionally calls `ExerciseLoadService.calculateLoad(...)` — the continuous-time, sleep-blind path — regardless of `HomeWidgetService.isLinkedActive(...)`. `viewModel.loadResult` is then read by `HomeView` in three spots (`HomeView.swift:56` for `loadColor`, `HomeView.swift:793` for the zone label, `HomeView.swift:806` for the bar progress) plus `linkedAwareAdvisory` at `HomeView.swift:940`. None of those consult the linking state when deciding which load shape to display. The Sleep Cascade's Step 4 captures a sleep-adjusted `DailyTrainingLoadSnapshot` and the linked detail sheet's `loadResult` computed property already uses `computeCurrentScore`, so the rest of the linked surface was correct — the widget bar was the lone holdout, by omission rather than design. |
| Resolution | Added `linkedAwareLoadResult: ExerciseLoadService.LoadResult` as a computed property on `HomeView`. When `isLinkedActive`, it computes a fresh `LoadResult` via `computeCurrentScore` with the real sleep snapshots (matching the detail sheet's behavior and the snapshot capture path). When not linked, it returns `viewModel.loadResult` unchanged (the existing sleep-blind path is the correct unlinked behavior). All three reads were updated to consult `linkedAwareLoadResult` instead of `viewModel.loadResult`: `loadColor` at `HomeView.swift:56-58`, the bar/zone block at `HomeView.swift:793-808`, and `linkedAwareAdvisory` at `HomeView.swift:940`. Reactive: since the computed property reads from `recoveryService` (`@Observable`) and `settings` (`@Observable`), it re-evaluates automatically when sleep snapshots update via the Sleep Cascade, when `targetSleepHours` changes, when linking state flips, and on each Home tab render. Regression test added to `RecoveryStatusAlgorithmTests` (new `LinkedAwareLoadResultContractTests` struct) referencing BUG-064: `test_linkedAwareLoadResult_whenLinked_usesComputeCurrentScore` — sets up workouts and sub-target sleep on intervening days, asserts that the score that drives the bar equals `computeCurrentScore(...)` and NOT `calculateLoad(...)`. Documents the contract that the linked-state widget must show the sleep-adjusted score. |
| Status | Resolved |

---

### BUG-065

| Field | Value |
|-------|-------|
| Date | 2026-05-28 |
| Phase | Phase 11 — Linked Recovery & Load Detail Sheet (Training Load / Sleep "vs last week" timeframe ambiguous to users; row was labeled "Stress Load" at the time, renamed later in Phase 11) |
| Description | The Window Comparison block on the linked detail sheet (`FortiFitLinkedRecoveryLoadDetailSheet.swift:293`) renders two rows — `Training Load ↑/↓ {pct}% vs last week` (then labeled "Stress Load") and `Sleep ↑/↓ {pct}% vs last week` — without telling the user *which week*. Users could not tell whether "this week" meant a trailing 7-day window, the ISO Mon–Sun week (potentially partial mid-week), or a same-point-in-time-last-week comparison. Mid-week the ambiguity is especially loud because a small early-week amount of training is being divided by a full prior week's stress sum, surfacing legitimate-but-shocking deltas like "↑ 420% vs last week" that the user reads as a bug rather than a partial-week effect. Compounded by stale CONSTANTS.md copy that described the computation as "mean of last 7 vs mean of preceding 7 (snapshot-driven)" — neither row actually does that. |
| Root Cause | (1) No visual disclosure of the comparison windows on the detail sheet; the "vs last week" label is honest about *what* is being compared (the spec is correct — both rows are ISO Mon–Sun current vs prior, see `ExerciseLoadService.weekOverWeekComparison` and `RecoveryStatusService.sleepWeekOverWeekComparison`) but leaves the *which dates* question to the user's intuition. (2) Doc drift in CONSTANTS.md § Window Comparison Band described a rolling-7-day algorithm that was never the implementation. |
| Resolution | Added a single italic Muted-Text caption above the two rows, dynamically computed against ISO Mon–Sun week boundaries: `This week so far ({Mon, MMM d} – today) vs last week ({Mon, MMM d} – {Sun, MMM d})`. New accessibility identifier `linkedRecoveryLoadDetailSheet_windowComparisonCaption`. Since Training Load and Sleep already use the same windows (BUG-058 alignment), one caption covers both rows. CONSTANTS.md Window Comparison Band entry rewritten to describe the caption and to correct the computation note (sum of raw `sessionStress` for Training Load, mean of nights-present `totalSleepMinutes` for Sleep, both bounded to ISO Mon–Sun). SCREENS.md § Linked Recovery & Load Detail Sheet step 4 updated to mention the caption. Regression test added to `LinkedDetailSheetWindowComparisonCaptionTests` referencing BUG-065. **Follow-up: BUG-066** — surfacing the windows revealed that the comparison itself was partial-week-vs-full-week, so the caption was rewritten and the algorithms changed to use day-of-week matched windows. |
| Status | Resolved |

---

### BUG-066

| Field | Value |
|-------|-------|
| Date | 2026-05-28 |
| Phase | Phase 11 — Linked Recovery & Load Detail Sheet (Training Load / Sleep windowed comparison was partial-week vs full-week, not apples-to-apples; row was labeled "Stress Load" at the time, renamed later in Phase 11) |
| Description | Surfaced by BUG-065's caption work. The Window Comparison band on the linked detail sheet was comparing Mon-through-today of the current ISO week against the **full** Mon–Sun of the prior ISO week. For Training Load (a sum, then labeled "Stress Load") this was structurally biased — on Thursday the numerator covered 4 days and the denominator covered 7, producing dramatic but spurious deltas (e.g. "↑ 420% vs last week" on a normal-volume mid-week morning). For Sleep (a mean) the bias was smaller but still real because weekend nights typically differ from weekday nights, so a user who sleeps in on weekends would consistently look "↓ vs last week" Mon–Fri. The original BUG-058 alignment fix between the two rows was correct as far as it went, but both algorithms inherited the partial-vs-full asymmetry. |
| Root Cause | `ExerciseLoadService.weekOverWeekComparison(context:now:)` and `RecoveryStatusService.sleepWeekOverWeekComparison(now:)` both bounded the current window with `now.startOfWeek...now.endOfWeek` (the full Mon–Sun, even mid-week) and the prior window the same way one ISO week earlier. The intent was a stable "last week" benchmark but the cost was a partial-week numerator divided into a full-week denominator. The current-window filter still excluded future-dated workouts/snapshots in practice, but the prior window was always seven full days. |
| Resolution | Both algorithms now clip the prior window to the same Mon-through-current-weekday offset as `now`: on Thursday both windows run Mon–Thu, on Sunday both collapse to the full Mon–Sun. `TrainingLoadWeekComparison` and `SleepWeekComparison` each gained a `matchedDayCount` field (1 Mon … 7 Sun) so callers can render a "Not enough data" treatment when there's only one day of comparison (early Monday). `FortiFitLinkedRecoveryLoadDetailSheet.windowComparisonBlock` now: (a) renders `Not enough data` in Muted Text for each row when `matchedDayCount < 2`, instead of showing a single-day delta colored as a confident trend, and (b) updates the caption to name the matched window explicitly — `This week so far (Mon, MMM d – today) vs same period last week (Mon, MMM d – matched-weekday, MMM d)`. SERVICES.md, CONSTANTS.md, and SCREENS.md updated to describe day-of-week matched windows. Regression tests added to `LinkedDetailSheetWindowComparisonCaptionTests` (caption text on Mon/Thu/Sun), `SleepWeekComparisonUnitTests` (prior-window clipping ignores weekend nights), and `TrainingLoadDetailHelpersUnitTests` (Training Load sum honors clipped prior window) — all referencing BUG-066. Existing BUG-057 / BUG-058 regression tests continue to pass because their fixtures already used weekday-only workouts/nights, which happen to be in the matched window on every day-of-`now`. |
| Status | Resolved |

---

### BUG-067

| Field | Value |
|-------|-------|
| Date | 2026-05-30 |
| Phase | Phase 11 — Linked Recovery & Load (sleep-adjusted Training Load score didn't propagate to historical chart surfaces, and chip delta disagreed with visible score change) |
| Description | Three related symptoms with a shared root cause, observed in the linked composite: (1) On the Recovery & Load Insights detail sheet, the "Last 14 Days · Training Load (Sleep-Adjusted)" chart's latest data point didn't match the hero score at the top of the sheet — e.g. header read `8/100 ADJUSTED FOR SLEEP` while the chart's rightmost dot was labeled `5/100 Low` (a visible 3-point delta inside a single screen). (2) The Trends `trainingLoadTrend` chart on the Progress screen always rendered the sleep-blind baseline score for today, even when Recovery Status was linked with Training Load on Home — so the same workout history produced two different "today's TL" numbers depending on which screen the user was looking at. (3) The home widget's "+N from sleep" chip claimed a smaller delta than the user could see when toggling linking on the widget bar — chip would say `↑ +1 from sleep` while the bar moved from 7 to 9 (visible +2). |
| Root Cause | Three different "today's TL score" code paths had drifted apart. `ExerciseLoadService.fourteenDayDailyScores` called the sleep-blind `calculateLoad` for today regardless of linking state (the doc comment claimed it would "match the hero" but the function it picked didn't accept sleep inputs at all). `TrendsChartService.trainingLoadPoints` and `trainingLoadTrendSummary` likewise hardcoded `calculateLoad` for today's branch with no awareness of `HomeWidgetService.isLinkedActive`. `HomeViewModel.loadData` populated `loadResult` via `calculateLoad` (continuous-time decay `exp(-daysAgo/τ)`) while the chip's baseline computed `computeCurrentScore` with an empty sleep map (discrete per-day product `(1 - λ·1.0)^days`); these two algorithms agree at integer-day boundaries but diverge by 1–2 points for workouts logged within the past ~24h, so `linked - baseline` (chip) ≠ `linked_displayed - baseline_displayed` (what the user perceives on toggling). Compounding micro-issue: the chip computed `Int((linked.score - baseline.score).rounded())` on the unrounded floats, but the bar and the linked detail sheet header each rounded their own score independently for display, so `round(linked - baseline) ≠ round(linked) - round(baseline)` on boundary cases. |
| Resolution | Unified every "current Training Load score" surface on the discrete per-day-step algorithm so the chip baseline, the home widget bar, the unlinked Training Load detail sheet hero, the linked detail sheet hero, the linked detail sheet 14-day chart's today point, and the Trends `trainingLoadTrend` chart's today point all share one decay shape. Four changes: (1) **`ExerciseLoadService.fourteenDayDailyScores`** gained optional `sleepSnapshotsByDay` / `targetSleepHours` parameters; today's branch now always routes through `computeCurrentScore` (empty map when omitted → `sleepFactor = 1.0` on every day, matching baseline; live map when supplied → matches the linked hero). `FortiFitLinkedRecoveryLoadDetailSheet.dailyLoadScores` passes the live map + target so the chart's latest dot equals the header hero. (2) **`TrendsChartService.trainingLoadPoints` and `trainingLoadTrendSummary`** added `computeTrainingLoadForToday(...)` helper that, on the main thread, reads `HomeWidgetService.isLinkedActive` + `RecoveryStatusService.current.cachedSnapshotsByDay()` and dispatches to `computeCurrentScore` when linked. The helper uses `MainActor.assumeIsolated` so the actor-isolated SwiftData snapshots never escape the main actor — only the final value-type `LoadResult` crosses. Off-main-thread callers (unit tests on Swift Testing's default background actor) get the baseline `calculateLoad` path, so existing tests don't need to register a singleton. (3) **`HomeViewModel.loadData`** now sets `loadResult` via `computeCurrentScore` with an empty sleep map, putting the unlinked bar on the same discrete-day-step shape as the chip baseline and the rest of the unlinked surface. `FortiFitTrainingLoadDetailSheet.reload` was updated to match. (4) **`HomeView.sleepImpactChip`** rounds each operand to `Int` before subtracting (`baselineInt = Int(baseline.score.rounded())`, `linkedInt = Int(linked.score.rounded())`, `delta = max(linkedInt - baselineInt, 0)`), so the chip's integer delta exactly equals the displayed bar change. Regression tests added: `FourteenDayDailyScoresSnapshotTests.test_fourteenDayDailyScores_withSleepMap_todayMatchesComputeCurrentScore` and `..._withoutSleepMap_todayMatchesUnifiedBaseline` in `SnapshotRenderingTests`; `UnlinkedTrainingLoadBarShapeTests.test_loadData_loadResultEqualsComputeCurrentScoreEmptyMap` and `SleepImpactChipRoundingContractTests` (three cases) in `RecoveryStatusAlgorithmTests`; and the end-to-end `LinkedSleepAdjustedChartIntegrationTests` (three integration tests covering linked chart-matches-hero, Trends chart sleep-adjusted-when-linked, and Trends chart baseline-when-unlinked). Updated the BUG-045 regression test to assert against `computeCurrentScore` (the new unified algorithm) instead of `calculateLoad`. |
| Status | Resolved |

---

### BUG-068

| Field | Value |
|-------|-------|
| Date | 2026-05-30 |
| Phase | Phase 11 — Recovery Status (yesterday's sleep duration overwritten with partial data by observer fire) |
| Description | On both the Recovery Status Detail Sheet and the linked Recovery & Load Detail Sheet, yesterday's sleep value (the middle "Last 3 Nights" column) was rendering as a heavily under-counted total — user repro showed `Fri, May 29 — 1h 37m, 31% deep` while Apple Health's `Sleep` view for the same May 29 wake-up date reported `5 hr 23 min` time asleep. Today's snapshot and snapshots from days prior were correct; only yesterday's was corrupted. The corrupted value persisted across app foreground/background cycles. |
| Root Cause | `RecoveryStatusService.handleSleepObserverFire` and `refreshFromBackground` both hardcoded a 36-hour fetch window (`now - 36h`). For any observer fire after early morning local time, that window starts AFTER yesterday's 6pm-to-6pm wake-up window starts (6 PM two days ago) — so a chunk of yesterday's overnight samples falls outside the fetch entirely. `ingestSamples` then groups by wake-up day and calls `upsertSnapshot`, which UNCONDITIONALLY overwrites the existing snapshot with the aggregate of whatever samples it did fetch. Concretely: the launch-time `refresh(forceCatchUp: false)` did a 30-day fetch and correctly wrote yesterday's snapshot at 5h 23m. The user's Apple Watch then synced new sleep data later, the observer fired, `handleSleepObserverFire` re-fetched only the last 36 hours (missing yesterday's early-evening samples), computed a partial aggregate of 1h 37m, and overwrote the previously-correct 5h 23m with the partial value. The bug is double-edged: the fetch window was too narrow, AND the upsert lacked any guard against partial-coverage overwrites. |
| Resolution | Two complementary changes in `RecoveryStatusService`. (1) Replaced the hardcoded `-36h` literal in `handleSleepObserverFire` and `refreshFromBackground` with a new `observerFetchWindowStart(now:)` helper that anchors to *yesterday's* `wakeUpWindow.start` (6 PM two days ago) with a 2-hour buffer for late-arriving Apple Watch writes. The resulting window is ~48–49 hours wide regardless of the current hour of day, guaranteeing full coverage of both today's and yesterday's wake-up windows. (2) Added a defensive partial-coverage guard to `upsertSnapshot(for:samples:fetchWindowStart:context:)`: when `fetchWindowStart` is provided and the wake-up day's window starts before it, skip the upsert entirely. `ingestSamples` now threads `start` into `upsertSnapshot` as `fetchWindowStart` so any future caller using a narrow window can't accidentally overwrite a previously-complete snapshot. The 30-day `refresh()` path was unchanged — its window starts 30 days back, far before any wake-up window the user will see, so the guard is a no-op there. Regression tests added: `test_observerFetchWindowStart_coversYesterdayWakeUpWindow` (pins the windowStart formula at 4:57 PM — the exact time-of-day from the user's screenshot) and `test_partialFetchWindowDoesNotOverwritePreviouslyCorrectSnapshot` (full end-to-end repro: seeds a 5h 23m snapshot via `refresh()`, then a narrower observer fire with 1h 37m of samples — asserts the snapshot stays at 5h 23m). Both in `RecoveryStatusSleepIntegrationTests`. |
| Status | Resolved |

---

### BUG-069

| Field | Value |
|-------|-------|
| Date | 2026-05-30 |
| Phase | Phase 11 — Recovery Status / Linked Recovery & Load Detail Sheets (sleep sparkline Y-axis clips values below 4h or above 10h) |
| Description | The 14-day sleep sparkline on both the Recovery Status Detail Sheet (`FortiFitRecoveryStatusDetailSheet.interactiveSparklineChart`) and the linked Recovery & Load Detail Sheet (`FortiFitLinkedRecoveryLoadDetailSheet.sleepSparkline`) hardcoded the Y-axis to `chartYScale(domain: 4...10)`. Any sleep value below 4h (e.g., the 1h 37m the user observed from BUG-068, or a short partial-night reading) rendered at its true coordinate *outside the visible plot area* — the data line "swooped" below the bottom edge of the chart with the latest dot floating somewhere off-screen. Symmetric problem on the upper end for catch-up sleep ≥ 11h. The data was correct; only the rendering was broken. |
| Root Cause | Hardcoded `chartYScale(domain: 4...10)` + hardcoded `AxisMarks(... values: [5, 7, 9])` in both sheets. The 4–10h band was chosen for the typical healthy sleep range but never adapted when actual data fell outside it. |
| Resolution | Added two static helpers on `DailySleepSnapshot`: `sparklineDomain(for:)` returns an adaptive `ClosedRange<Double>` (anchors to 4...10 in the typical case; expands the lower bound down to as low as 0 and the upper bound up to as high as 14 when actual data exceeds 4...10; zero-sleep snapshots are excluded from the min/max calc so a missing night doesn't drag the floor to 0), and `sparklineAxisValues(for:)` returns three evenly spaced tick values `[lower + 1, midpoint, upper - 1]` so labels stay one tick inside the plot frame. Both detail sheets now call these helpers — when the data is typical (5–9h on every day) the chart looks identical to pre-fix; when data is extreme the chart expands to keep every point inside the plot area. Unit tests in `SparklineDomainAdaptationTests` (new `RecoveryStatusFoundationTests` struct) cover: empty input → default `4...10`; zero-sleep excluded; typical-range preservation; below/above-anchor expansion; lower-floor at 0 and upper-cap at 14; axis-value labels match the historical `[5, 7, 9]` for the default domain. |
| Status | Resolved |

---

### BUG-070

| Field | Value |
|-------|-------|
| Date | 2026-06-01 |
| Phase | Phase 11 — Recovery Status / Linked Recovery & Load Detail Sheet (Sleep-Load Correlation Callout and Personal Pattern Insights Pattern 1 partly tautological when training load snapshots were captured sleep-adjusted) |
| Description | `RecoveryStatusService.computeSleepLoadCorrelation` (powering the correlation callout and Personal Insights Pattern 1 — "Score-by-sleep-bucket") read training load scores directly from persisted `DailyTrainingLoadSnapshot` rows without checking `wasSleepAdjusted`. Whenever a user has the Recovery & Load composite linked, today's snapshot is written with `wasSleepAdjusted = true`, meaning the score is computed via the sleep-adjusted decay path — where sleep duration is one of the inputs that shapes the score. Pairing those scores against the same sleep values being correlated makes the relationship partly self-fulfilling: `sleep[D]` is itself a factor inside `load[D+1]` whenever D+1 was captured as sleep-adjusted, so "training load runs lower after 7+ hour nights" surfaces a property of the formula rather than a discovered behavioral pattern. Symmetric issue for users who linked the widgets recently: the historical window is a mix of baseline and sleep-adjusted snapshots, making the correlation an apples-to-oranges sum across two different signals. |
| Root Cause | `computeSleepLoadCorrelation` consumed `DailyTrainingLoadSnapshot.score` as opaque numeric input without distinguishing the capture-time linking state. The snapshot store is a cache for chart rendering; using it as the source of truth for a correlation against sleep ignored that one of the cache's two computation paths takes sleep as an input. |
| Resolution | `RecoveryStatusService.computeSleepLoadCorrelation` now recomputes the baseline (non-sleep-adjusted) score for each paired `nextDay` on the fly via `ExerciseLoadService.calculateLoad(workouts:..., now: endOfNextDay)`, pulling raw workouts from the 55-day window that covers the full pairing range plus the 10-day decay tail. The `DailyTrainingLoadSnapshot` lookup was removed from this function entirely — persisted snapshots no longer influence correlation results regardless of whether they were captured sleep-adjusted or baseline. `nextDay` is normalized to start-of-day and the workout filter spans `(nextDay - 10 days, endOfNextDay)` so a workout done any time during `nextDay` counts (matches the original snapshot capture's end-of-day semantics). Existing `CorrelationVariantTests` were updated to seed `Workout` objects rather than `DailyTrainingLoadSnapshot` rows, and a new regression test `snapshotScoresDoNotInfluenceCorrelation` pre-populates strongly correlated sleep-adjusted snapshots with no underlying workouts and asserts the result is `noPattern` — proving the snapshot path is dead. Integration test `test_threeWeeksLowSleepScenarioYieldsEnoughPairedDaysForCorrelation` was likewise switched from snapshot seeding to workout seeding. |
| Status | Resolved |

---

### BUG-071

| Field | Value |
|-------|-------|
| Date | 2026-06-01 |
| Phase | Phase 11 — Recovery Status / Linked Recovery & Load Detail Sheet (Personal Pattern Insights Pattern 3 "Multi-week aggregate" was a hardcoded caption, not a computed insight) |
| Description | The Personal Insights row "Your most consistent recovery weeks line up with sleep targets met 5+ nights." (Pattern 3 in `RecoveryStatusService.computePersonalInsights`) was emitted whenever the user had ≥ 4 weeks of sleep snapshots (`weekCount >= 4`). No comparison was performed against the user's actual data — the string ran regardless of whether the user's recovery weeks did or did not line up with sleep-target-met nights. Confirmed by the prior test `returnsAtLeastOneInsightWith21PairedDays`, which seeded 30 uniform 7h sleep snapshots with zero workouts and zero load snapshots and still returned ≥ 1 insight — only Pattern 3 could have produced it, and it did so without any real signal. Symptomatically harmless on the surface (the copy stayed visually consistent with the other Personal Insights rows) but undermined the trust contract of the "Personal Insights" surface: a row that reads as a discovered pattern was actually a tautology that fired on every user with enough days of any sleep data. |
| Root Cause | `computePersonalInsights` Pattern 3 logic was a placeholder — `weekCount >= 4` gate plus a static `insights.append(...)` of the templated copy. No week bucketing, no comparison of well-rested vs under-rested weeks, no load-delta computation. The spec (CONSTANTS.md § Linked Recovery & Load Detail Sheet → Personal Pattern Insights → Multi-week aggregate) defined the row but deferred the algorithm to the implementation, and the implementation never materialized — the unconditional emission was a temporary marker that shipped. |
| Resolution | Replaced the unconditional emission with `computePattern3MultiWeekAggregate`. The new logic buckets sleep snapshots into ISO weeks (Mon–Sun via `Date.startOfWeek`), counts nights meeting `UserSettings.targetSleepHours` per week, and computes a per-week mean baseline TL score using the same `calculateLoad(..., now: endOfDay)` path BUG-070 introduced (snapshot-independent, sleep-adjustment-independent). Weeks are split into `wellRested` (≥ 5 target-met nights) vs `underRested` (< 5). The current in-progress week is skipped to avoid partial-data bucket assignment. Emission is gated by two conditions: both buckets must hold ≥ 2 weeks (a real comparison, not a sample of one), AND `delta = mean(underRestedLoads) - mean(wellRestedLoads)` must be ≥ 5 points (matches Pattern 1's correlation-band magnitude for consistency). Copy was templated with `{n}` so the actual delta is surfaced — CONSTANTS.md § Linked Recovery & Load Detail Sheet → Personal Pattern Insights updated to `"Your most consistent recovery weeks (~{n} points lower load) line up with sleep targets met 5+ nights."`. Tests: `returnsAtLeastOneInsightWith21PairedDays` was rebuilt around a real well-rested-vs-under-rested fixture (it previously only passed because of the unconditional emission); three new regression tests cover the emission path (`pattern3EmitsWhenWellRestedWeeksHaveLowerLoad`), single-bucket suppression (`pattern3SuppressedWhenAllWeeksWellRested`), and below-threshold suppression (`pattern3SuppressedWhenDeltaBelowThreshold`). |
| Status | Resolved |

---

### BUG-072

| Field | Value |
|-------|-------|
| Date | 2026-06-02 |
| Phase | Phase 8.5 — Workout Detail Summary Redesign (`FortiFitMetricDetailSheet` / `WorkoutMetricService.sparklineData`) |
| Description | On the per-metric detail sheet opened from a Summary stat card on Workout Detail, the 30-day sparkline frequently renders the "Not enough data yet — log a few more sessions." empty state even when the user has many historical sessions of that workout type. Reproducible repro: open a HIIT workout dated May 6, 2026 (the user has **70 HIIT workouts** total). Tap the Active kcal stat card. The same sheet correctly shows the hero `330 kcal`, the comparative line `Your typical HIIT session — 199 kcal`, and the delta `+132 kcal vs typical` — proving aggregate HIIT data exists — yet immediately below those lines the sparkline block reads `Not enough data yet — log a few more sessions.` The two messages contradict each other on the same screen, and the empty-state copy ("log a few more sessions") is actively misleading because the user has far more than enough sessions; the issue is purely a windowing bug. |
| Root Cause | `WorkoutMetricService.sparklineData` (`FortiFit/Core/Services/WorkoutMetricService.swift:76–91`) anchors the 30-day cutoff to **`Date()` (today)** rather than to `workout.date`: `let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())`. The fetch predicate then filters `w.workoutType == workoutType && w.date >= cutoff`. For the repro workout (May 6, 2026) with today = June 2, 2026, the cutoff resolves to **May 3, 2026** — a window that sits 27 days *after* the workout being viewed. From the user's HIIT history (May 6 → Apr 29 → Apr 20 → Apr 8 → Mar 26 → Mar 17 → Mar 9 …), only the May 6 workout itself falls inside the window; the next HIIT (Apr 29) is 4 days outside. The `points.count >= 3` threshold then trips the empty state. The comparative-average path (line 62) has no date filter at all (it uses every workout of that type except the current one), which is why the SAME sheet successfully renders `199 kcal typical` while the sparkline shows "not enough data" — the two helpers in the same service file use inconsistent windowing semantics. The bug has two compounding effects: (a) for any workout viewed more than ~30 days after it was logged, the sparkline window slides entirely past the neighborhood of that workout, so historical context is cropped; (b) for users whose cadence for a given workout type is sparser than 30 days, the sparkline never has enough data regardless of how old the workout is. The empty-state copy ("log a few more sessions") additionally misattributes the problem to data scarcity instead of windowing — actionable in the wrong direction. |
| Resolution | Two changes in `WorkoutMetricService.sparklineData` plus a caption refresh in `FortiFitMetricDetailSheet`. (1) **Anchor swap**: the trailing 30-day cutoff is now computed as `workout.date - 30 days … workout.date` instead of `Date() - 30 days … (open)`. This guarantees the current workout always sits at the rightmost edge of the chart (where `isCurrentWorkoutDate(...)` already expected to find it) and makes the window stable regardless of how long after the workout the user opens the sheet. (2) **Sparse-cadence fallback**: when the trailing window yields fewer than 3 points (e.g., a monthly long run), the service falls back to a `fetchLimit = 5` descriptor pulling the most recent same-type sessions at-or-before `workout.date`. Return type changed from `[(Date, Double)]` to a `SparklineResult?` containing `points` plus a `SparklineMode` (`.trailingWindow(days:anchorDate:)` vs `.recentFallback(sessionCount:)`). The sheet branches its caption on the mode — `"30 days through <Month Day> · <Type>"` for the trailing window, `"Last N <Type> sessions"` for the fallback — so users always see a caption that matches what the chart is showing. The empty-state path now only fires when there are genuinely < 3 sessions of that type at-or-before the workout's date, which is also exactly when `comparativeAverage` returns nil — eliminating the contradictory "199 kcal typical / log a few more sessions" state from the screenshot. `comparativeAverage` and `isPersonalBest` keep their all-history semantics (typicality and PRs are meaningful at lifetime scope). SERVICES.md § WorkoutMetricService → Operations updated to document the new signature and modes. Four regression tests added to `FortiFitTests/WorkoutMetricTests.swift` referencing BUG-072: `sparklineData_olderWorkoutInDenseHistory_returnsTrailingWindowAroundWorkoutDate` (70 weekly HIIT workouts, target picked from 8 weeks ago — pre-fix returned nil), `sparklineData_sparseCadenceType_returnsRecentFallback` (12 monthly long runs → fallback returns exactly 5 points), `sparklineData_fewerThanThreeSessionsOfType_returnsNil` (genuine no-data case), and `sparklineData_neverEmptyWhenComparativeAverageExists` (the contradiction itself — asserts sparkline is non-nil whenever comparative average is non-nil). All 4 pass; all 7 pre-existing `WorkoutMetricServiceTests` + `WorkoutMetricIntegrationTests` still pass (11/11). |
| Status | Resolved |

---

### BUG-074

| Field | Value |
|-------|-------|
| Date | 2026-06-03 |
| Phase | Phase 12 — Power Level Widget gauge (off-scale `pct_change` rendering) |
| Description | When the user's Power Level `pct_change` exceeds the gauge's visible range (`pct > +30%` or `pct < −30%`), the thumb is clamped to the bar's edge with no visual signal that the value is off-scale. Reproducible repro: a user with `pct_change = +141%` sees the thumb sitting exactly on top of the `+30%` axis label, even though the caption reads `+141% vs prior 30d`. The bar reads as "exactly +30%" while the caption disagrees — same screen, contradictory signals. Affects both the compact widget on Home and the hero gauge on the Power Level Breakdown Sheet, since both surfaces share `FortiFitPowerLevelGauge`. |
| Root Cause | `FortiFitPowerLevelGauge.swift` correctly clamps the thumb position via `powerLevelGaugePosition(pctChange:)` (`position = (clamp(pct, −30, +30) + 30) / 60`), but the rendered thumb has no off-scale treatment. The gauge was specced (CONSTANTS § Power Level Gauge, Phase 12) with axis labels at `−30 / −10 / +10 / +30` and the caption as the source of truth for the exact value — but the spec did not call out what the thumb should look like when the value sits outside the visible range, so the implementation rendered the in-range thumb identically at the clamped edge. The caption disagrees with the bar in any case where `pct_change` lies outside `[−30, +30]`. |
| Resolution | Added an off-scale "Overflow Indicator" treatment to `FortiFitPowerLevelGauge` (Option A in the design exploration; see `Design Mockups/PowerLevelWidgetGauge_Overflow.svg`). When `|pct_change| > 30` (strict), the thumb gains (a) two concentric halo circles behind it, radii proportional to `Self.thumbDiameter` (×0.875 outer, ×0.6875 inner) filled with `thumbColor` at 28% / 18% opacity, and (b) an inset SF Symbol `chevron.right.2` (positive overflow) or `chevron.left.2` (negative overflow) — a **double** chevron, matching the design mockup intent — 9pt `.bold`, tinted `FortiFitColors.cardSurface` for contrast against the colored thumb. Bar geometry, tick labels, position math, and the delta caption are all unchanged — the caption remains the source of truth for the exact value. `voiceOverLabel` appends `" Off-scale — past ±30%."` when overflowing. Two new accessibility identifiers (`homeWidget_powerLevel_gaugeOverflowIndicator`, `powerLevelDetailSheet_heroGaugeOverflowIndicator`) wire onto the halo+chevron composite. CONSTANTS § Power Level Gauge gained an "Overflow Indicator" subsection; SCREENS § Power Level widget + § Power Level Breakdown Sheet → Block 1 Hero each gained a one-line callout. Five regression tests added to `FortiFitTests/PowerLevelGaugeTests.swift` referencing BUG-074: `test_overflow_pctAbovePositiveThreshold_returnsPositive`, `test_overflow_pctBelowNegativeThreshold_returnsNegative`, `test_overflow_atBoundaryThirty_returnsNil` (strict greater-than at the boundary), `test_overflow_withinVisibleRange_returnsNil`, `test_overflow_inNoDataState_returnsNil`. A cascade integration test (`PowerLevelGaugeCascadeIntegrationTests.test_loggingWorkoutPushingPastPositiveThreshold_revealsOverflowIndicator`) seeds a +10% baseline then logs a 4000-volume workout that pushes deltaPct past +30%; asserts `overflowDirection(for:)` flips from nil → `.positive` after the cascade while the thumb position stays clamped at 1.0. All 13 unit + 6 integration tests in the Power Level Gauge suite pass; broader Power Level surface (`PowerLevelServiceTests`, `PowerLevelDetailHelpersUnitTests`) also still green (22/22). |
| Status | Resolved |

---

### BUG-073

| Field | Value |
|-------|-------|
| Date | 2026-06-02 |
| Phase | Phase 6 / 6.2 — Trends Chart Card vs. Chart Detail View (empty-state threshold divergence) |
| Description | The compact Trends chart card and the expanded chart detail view (`FortiFitChartDetailView`, pushed via the card's chevron) use different "do I have enough data?" thresholds, so the card and the detail screen disagree about whether a chart is empty. Reproducible repro from the attached screenshots: the user has logged **Arnold Press exactly once** with a weight. The Strength Tracker card on Trends correctly shows the empty-state caption `"Log more exercises to display strength trends."` (no hero, no chart, the time-range pills are present but no plot). Tapping the card's chevron pushes the detail view, which renders a chart with a single pink dot at the top of an otherwise empty plot — no hero, no comparison delta, no surrounding context. The two surfaces give the user contradictory signals on the same data: the card says "not enough yet" while the detail draws a (meaningless) chart from the same single point. Confirmed by inspection to affect at least: `strengthTracker`, `workoutVolume`, `trainingFrequency`, `trainingLoadTrend`, `rpeTrend`, `sessionDuration`, and `workoutTypeBreakdown` — i.e. nearly every chart type except `personalRecords` (which happens to share an `exercisesWithPRs(...)` call on both surfaces and is therefore consistent). The detail-view side also has its own empty-state path that *would* show `AppConstants.chartEmptyMessages[chartId]` if it ever fired — but for most chart types, the detail's threshold (`points.isEmpty`) is strictly weaker than the card's, so the detail's empty state is effectively unreachable in the configurations where the card shows it. |
| Root Cause | The "enough data" predicate is computed in two unrelated places with deliberately different semantics, with no shared rule. **Card side** (`FortiFit/Features/Progress/ProgressViewModel.swift:139–186`) exposes per-chart booleans that encode the spec's CONSTANTS § Chart Data Thresholds — `hasStrengthData = strengthDataPoints.count >= 2`, `hasVolumeData = volumeDataPoints.count >= 2`, `hasTypeBreakdownData = total >= 2`, `hasFrequencyData / hasRPEData / hasDurationData = ≥ 1 *completed* prior week with data`, `hasLoadTrendData = 3+ days with workouts in last 14 days`, `hasPRData = !exercisesWithPRs().isEmpty`. `FortiFitProgressView` passes these into `FortiFitChartCard(isEmpty: ...)` (e.g. `strengthTrackerCard` at line 238: `isEmpty = viewModel.availableExercises.isEmpty || !viewModel.hasStrengthData`). **Detail side** (`FortiFit/Design/Components/FortiFitChartDetailView.swift`) calls `TrendsChartService.dataPoints(for:exerciseName:range:context:)` and gates the empty state on `if points.isEmpty` (line 251 line chart, 339 bar chart, 410 training load, 535 PR timeline via `prExercises.isEmpty`, 661 breakdown via `rows.isEmpty`). `TrendsChartService.dataPoints(...)` (lines 412–442) has no minimum threshold — it returns whatever the per-chart helper produces: `strengthTrackerPoints` returns one point per qualifying workout (so 1 workout → 1 point, not empty), `workoutVolumePoints` likewise, `trainingFrequencyPoints` returns one bucket per ISO week in the range *including zero-count weeks*, `trainingLoadPoints` returns 30 daily points unconditionally (including zero scores), `rpeTrendPoints` / `sessionDurationPoints` include weeks with data (no "completed week" exclusion of the current in-progress week), `breakdownPercentages` returns rows whenever `!filtered.isEmpty`. So `isEmpty` on the card and `points.isEmpty` in the detail are not the same check, and only `personalRecords` ends up consistent because both surfaces happen to call `exercisesWithPRs(...)` (the detail at line 531, the card via `viewModel.hasPRData`). There is no single source of truth — `CONSTANTS § Chart Data Thresholds` describes the card semantics; the detail view was implemented in Phase 6.2 without back-referencing them, and the divergence has compounded as new charts were added. Symptom-wise this also explains why the screenshot's detail view shows no header summary or comparison delta despite the single dot: `TrendsChartService.headerSummary` for `strengthTracker` *does* enforce `workoutsWithExercise >= 2` (line 138), so it returns nil, `comparisonDelta` falls through, and the detail correctly suppresses the hero block — but the *chart* itself ignores that same threshold, leaving a context-free dot. |
| Resolution | Added `TrendsChartService.hasEnoughData(for:exerciseName:range:context:) -> Bool` as the single source of truth for the "does this chart have enough data to render?" question, encoding CONSTANTS § Chart Data Thresholds per chart type: `strengthTracker` / `workoutVolume` → `dataPoints.count >= 2`; `personalRecords` → `!exercisesWithPRs(...).isEmpty` (range-independent, lifetime); `trainingLoadTrend` → ≥ 3 distinct days with workouts in last 14 days (range-independent, matches `ProgressViewModel.hasLoadTrendData`); `workoutTypeBreakdown` → total workouts in range ≥ 2; `trainingFrequency` → ≥ 1 *completed* prior week with count > 0 in range (via new private helper `hasAtLeastOneCompletedWeek(points:requiringValue:)`); `rpeTrend` / `sessionDuration` → ≥ 1 completed prior week with data in range (the `*Points` helpers already drop empty weeks, so any completed-week point qualifies). Updated all five chart sub-renderers in `FortiFitChartDetailView` (`lineChartDetail`, `barChartDetail`, `trainingLoadDetail`, `breakdownDetail`, `prTimelineDetail`) to replace `points.isEmpty` / `rows.isEmpty` / `prExercises.isEmpty` gates with `!TrendsChartService.hasEnoughData(...)` so the detail's empty-state path now fires at the same threshold as the card. `ProgressViewModel.has*Data` predicates were left as-is — they already implement the matching semantics on cached arrays, and a doc cross-reference in `hasEnoughData(...)` makes the two surfaces' shared dependency on CONSTANTS § Chart Data Thresholds explicit. Eleven regression tests added to `FortiFitTests/TrendsChartTests.swift` in a new `HasEnoughDataThresholdTests` suite — for each chart type, one fixture just below threshold (must be empty) and one at-threshold (must have data); plus a parity test `cardAndDetailAgreeWhenStrengthHasOnlyOnePoint` that reproduces the screenshot fixture (Arnold Press logged once) and asserts the detail view is empty at *every* eligible range. SERVICES.md § TrendsChartService gained an "Enough-Data Predicate (BUG-073)" section documenting the new entry point and the card-vs-detail contract. |
| Status | Resolved |

---

### BUG-075

| Field | Value |
|-------|-------|
| Date | 2026-06-03 |
| Phase | Phase 4 / Phase 6 — Power Level Insights vs. Workout Volume Trend chart (qualifying-workout filter divergence) |
| Description | The "Current 30D Avg" surfaced in the Power Level Breakdown Sheet's hero / window-comparison bars frequently disagrees by a large margin with the "avg volume per session" hero on the Trends → Workout Volume chart for the same 30-day window. Both surfaces are described to the user as a 30-day Strength Training + HIIT volume average, but a side-by-side check on a real account showed the Power Level value sitting well below the Trends chart hero. The two numbers also drive different downstream decisions: Power Level's status classification (Rising / Steady / Deloading) and nudge copy use that average, while the Trends chart hero is the user's primary "what is my volume?" check. Disagreement here also propagates to `topContributingExercises.sessionCountInWindow` and `nudge.inputs.currentSessionCount30d` so the breakdown sheet can credit "N sessions" that the user wouldn't recognise as logged. |
| Root Cause | `PowerLevelService.fetchQualifyingWorkouts` (`FortiFit/Core/Services/PowerLevelService.swift:92–102`) filters by date + workout type only — it does **not** require `!exerciseSets.isEmpty`. `TrendsChartService.workoutVolumeSummary` (`FortiFit/Core/Services/TrendsChartService.swift:285–289`) and `workoutVolumePoints` (`TrendsChartService.swift:956`) both add an explicit `!$0.exerciseSets.isEmpty` filter. The two services agree on the per-workout volume formula — both call `PowerLevelService.workoutVolume(for:)` — but their eligibility filters drift. For users with HealthKit integration enabled, the Phase-8 sync auto-creates empty `Workout` rows for any Apple Watch Strength Training / HIIT session that hasn't been linked to a logged workout, and `workout.exerciseSets` stays empty until the user logs sets against it. Those rows have `workoutType ∈ {Strength Training, HIIT}` and a recent `date`, so they fall straight into `fetchQualifyingWorkouts`'s 30-day window with `workout_volume = 0`. The averaging path (`averageVolume(for:)`, `PowerLevelService.swift:105–109`) sums those zeros into the numerator and increments the denominator — pulling `current30dAvg` down and pulling the percentage delta toward Deloading. The Trends chart never sees those rows, hence the divergence. The same drift affects `topContributingExercises` (no exercise rows to aggregate so the zero-volume sessions contribute nothing on the per-exercise side, but their existence in `currentWorkouts` still bumps the count handed to `windowComparison`/`computeNudge` via the denominator) and the cold-start guard (`currentWorkouts.count < 3`), which can think the user is past cold-start on the strength of empty HK shells alone. |
| Resolution | Added a post-fetch `!$0.exerciseSets.isEmpty` filter inside `PowerLevelService.fetchQualifyingWorkouts` so every downstream caller (`calculatePowerLevel`, `windowComparison`, `topContributingExercises`, `computeNudge`) inherits the same "logged sets exist" eligibility rule the Trends → Workout Volume chart already enforces. Volume formula, time windows, type filter, and bodyweight handling are unchanged. The filter is applied in-memory after the predicate fetch rather than inside `#Predicate` (matches the post-fetch pattern in `TrendsChartService.workoutVolumeSummary` and keeps the SwiftData fetch predicate identical to its current shape). SERVICES.md § Power Level Algorithm → Scope updated to call out the empty-set exclusion (now reads "Only Strength Training and HIIT workouts that have at least one logged ExerciseSet — HealthKit-imported sessions without sets are excluded"). Regression coverage: `PowerLevelServiceTests.emptyExerciseSetWorkoutsDoNotSkewAverage` (a baseline-window logged workout plus a current-window HK-shell at the same date must still classify Steady — pre-fix the shell drags `currentAvg` to zero and classifies Deloading) and `PowerLevelGaugeCascadeIntegrationTests.test_hkShellWorkoutInCurrentWindow_doesNotDragWindowComparisonDown` (logs an empty-set Strength workout into a previously-Rising state and asserts `windowComparison.current30dAvg` and `deltaPct` are unchanged). |
| Status | Resolved |

---

### BUG-076

| Field | Value |
|-------|-------|
| Date | 2026-06-04 |
| Phase | Phase 6 / 6.1 / 6.2 — Trends line & bar charts (Strength Tracker, Workout Volume, PR Timeline, Training Frequency, Session Duration) — compact card + detail view |
| Description | When a chart's data contains a sharp jump (e.g. Strength Tracker going from ~20 lbs to ~80 lbs across a few sessions), the rendered line and/or the latest-point highlight dot sits flush against — or visibly crosses above — the chart's top border. Reproduced on the Strength Tracker detail view (90D, Arnold Press): the magenta line rises through the upper third of the plot area and the glow dot is clipped by the rounded plot-area stroke at the top edge. Same risk applies to the Strength Tracker compact card, Workout Volume (line, compact + detail), Personal Records PR timeline (detail), Training Frequency (bar, compact + detail), and Session Duration (bar, compact + detail) — every chart that relies on Swift Charts' automatic Y-axis domain. Visually unprofessional and, on smoothed lines, makes it look like the data exceeds the highest gridline label even when it does not. |
| Root Cause | Two compounding factors. (1) **Auto Y-axis domain with no headroom**: `FortiFitChartDetailView.lineChartDetail` (`FortiFit/Design/Components/FortiFitChartDetailView.swift:248–333`), `barChartDetail` (`:338–407` — except the explicit `rpeTrend` 0...10 case), `prTimelineDetail` (`:538–651`), and the compact-card chart bodies for `strengthTracker` / `workoutVolume` / `trainingFrequency` / `sessionDuration` in `FortiFitProgressView.swift` (`:236–329`, `:614–~700`, plus the bar variants) declare no `.chartYScale(domain:)`. Swift Charts then picks an upper bound by snapping to the nearest "round" gridline at or above the max value, which frequently equals the max value itself (e.g. data peak = 80 → top gridline = 80). The latest data point and its glow dot land exactly on the inner plot frame, and the dot's `shadow(radius: 4)` extends past it. (2) **`.catmullRom` overshoot**: `LineMark.interpolationMethod(.catmullRom)` (applied on Strength Tracker, Workout Volume, PR Timeline, and the Training Load dashed rolling average) produces a smoothed cubic curve that can exceed the maximum of its control points at a sharp concave-down transition. When values jump 20 → 80 in one or two steps, the interpolated path arcs above 80 by several percent and clips through the plot border. Training Load is shielded only because it pins the domain to `0...100` (`FortiFitChartDetailView.swift:489`, `FortiFitProgressView.swift:574`), which gives ~20pt of cosmetic headroom past the realistic upper end. The compact-card `FortiFitChartCard.plotArea` (`FortiFit/Design/Components/FortiFitChartCard.swift:97–106`) and the detail-view `detailPlotArea` (`FortiFitChartDetailView.swift:826–840`) both apply a 1pt stroked rounded rectangle as the visual frame, so any overshoot becomes immediately visible against the border. |
| Resolution | Added `TrendsChartService.paddedYDomain(for:headroomFraction:floorAtZero:)` returning `0...niceCeiling(maxY * 1.10)` with a safe `0...1` fallback for empty / all-zero series. `niceCeiling` rounds the upper bound to a chart-friendly 1/2/5 × 10ⁿ step so the top gridline label stays readable. Applied `.chartYScale(domain: paddedYDomain)` to: `FortiFitChartDetailView.lineChartDetail` (Strength Tracker, Workout Volume), `barChartDetail` (used by Training Frequency + Session Duration; RPE keeps its explicit `0...10`), `prTimelineDetail`, and the four compact-card chart bodies in `FortiFitProgressView.swift` (Strength Tracker, Training Frequency, Workout Volume, Session Duration). Swapped `.interpolationMethod(.catmullRom)` → `.interpolationMethod(.monotone)` on the three data-bearing line series — Strength Tracker (compact + detail), Workout Volume (compact + detail), and the Personal Records timeline. The Training Load rolling-average dashed line keeps `.catmullRom` (its `0...100` domain already absorbs any overshoot, and the smoothed curve is the intended visual). Personal Records compact card untouched — it already pinned its own `0...(max * 1.2)` domain. Removed the now-unused `barChartDetail` `yDomain` conditional plumbing (`.modify { ... }`) in favour of a direct `yDomain ?? paddedYDomain(...)` fallback. Regression coverage: `PaddedYDomainTests` (six cases — empty fallback, all-zero fallback, single value, mixed values ≥10% above max, small-int series, custom headroom). 6/6 passing. No spec changes — visual polish only; behaviour, thresholds, gradient anchors, and threshold gates are identical. |
| Status | Resolved |

---

### BUG-077

| Field | Value |
|-------|-------|
| Date | 2026-06-05 |
| Phase | Phase 8.5 — Workout Detail Summary stat-card grid |
| Description | After logging or editing a workout with several exercises, the Workout Detail screen's Summary section renders the first four stat cards (Effort, Duration, Avg HR, Max HR) as completely blank cells — no icon, label, value, or card background — while their layout space is preserved. Active kcal and Total kcal (the last two cards) render correctly at the bottom row. Scrolling the ScrollView even slightly causes the missing cards to "pop in" with full content. Reproduced on a HealthKit-linked Strength Training workout with 5+ exercises and all summary fields populated (rpe, duration, avg/max HR, active/total kcal). |
| Root Cause | `WorkoutDetailView.summarySection` (`FortiFit/Features/Workout/WorkoutDetailView.swift:293`) used `LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8)` for the stat-card grid. The view's outer body is a `ScrollView` whose content is offset by `.padding(.top, headerHeight)` (`:60`) where `headerHeight` is written from a `GeometryReader` inside `FortiFitFixedHeader` (`FortiFit/Design/Components/FortiFitFixedHeader.swift:23–29`). This produces a multi-pass layout sequence: pass 1 lays out the VStack with `headerHeight = 0`, the geometry reader fires `.onAppear` / `.onChange` and writes the real header height (~150pt), pass 2 re-lays the VStack with the new top padding. When the Exercises subsection beneath the grid is tall (several `FortiFitCard` rows), the total scroll content size on pass 2 differs enough that `LazyVGrid` re-evaluates its visible cell window during the re-layout. Cells whose centroids straddle the recomputed window boundary commit their *layout slot* (preserving the row spacing — which is why Active kcal sits at the correct row-3 y-position) but skip rendering their cell *content* until a subsequent layout invalidation (e.g. scroll gesture) forces re-evaluation. The bug only manifests when the cell count × row height × surrounding content height crosses LazyVGrid's internal visible-bounds threshold, which is why pure-HK workouts without exercises don't reproduce it. Not specific to the new effort-bars icon — happens identically for the symbol-icon cards. The number of cells is fixed and small (max 8), so lazy rendering offers no performance benefit here; it is purely a layout footgun. |
| Resolution | Replaced the `LazyVGrid` in `summarySection` with an eagerly-laid-out `VStack(spacing: 8)` of paired `HStack(spacing: 8)` rows (cards walked two-at-a-time via `stride(from:to:by:)`). Each cell wraps its `FortiFitStatCard` in `.frame(maxWidth: .infinity)` to preserve the equal-width 50/50 column behavior `GridItem(.flexible())` previously provided; an odd trailing card pairs with a `Color.clear.frame(maxWidth: .infinity)` placeholder. Extracted a private `@ViewBuilder statCardView(for:)` helper so the effort-bars branch (custom `FortiFitEffortBars` icon) and the symbol-icon branch (`SymbolStatCardIcon`) aren't duplicated inline. Added a `// BUG-077:` guard comment above the new container so future refactors don't reintroduce `LazyVGrid` here. No change to `summaryCards` data, card ordering, accessibility identifiers, `FortiFitStatCard` component, or `WorkoutMetric` sheet behavior — purely a layout-container swap. |
| Status | Resolved |

---

### BUG-078

| Field | Value |
|-------|-------|
| Date | 2026-06-05 |
| Phase | Phase 8 — HealthKit Integration (foreground refresh) |
| Description | When a workout completed on Apple Watch lands in HealthKit while the FitNavi app is foregrounded on the Home tab, the Home screen does not update to show the new workout (Recent Workouts row, Training Load bar, Power Level gauge, Today's Plan green dot). The data *is* being imported — navigating to any other tab and returning to Home immediately reveals the newly-imported workout. Same staleness applies to upstream HK deletes and rpe nil-fills via `workoutEffortScore` while Home is foregrounded. |
| Root Cause | `HKObserverQuery` fires the workout-changes callback in `DefaultHealthKitClient.observeWorkoutChanges` immediately while foregrounded; `HealthKitSyncService.importPendingWorkouts(...)` then writes the new `Workout` to SwiftData and calls `context.save()`. But `HomeViewModel` consumes that data via *snapshots* into `@Observable` properties (`recentWorkouts`, `loadResult`, `powerLevelResult`, `todaysScheduledWorkouts`) that are populated by `loadData(context:)` and only re-run on `.onAppear` (HomeView.swift:262) plus a handful of `.onDisappear` callbacks from child screens. There was no signal connecting "HK sync committed" → "Home reload" — the observer fired, the data landed, but the snapshot in the VM was never refreshed. Navigating away/back worked because the second `.onAppear` re-ran `loadData`. Same gap would apply to any other VM that snapshots HK-derived state (Plan, Workouts list) — only Home was confirmed by the user. |
| Resolution | Added `Notification.Name.fortiFitHealthKitDidImport` defined at the bottom of `FortiFit/Core/Services/HealthKitSyncService.swift`. Posted from a new private `notifyHealthKitDidImport()` helper called (a) at the end of `importPendingWorkouts` after `context.save()` succeeds (unconditional — empty cycles are cheap on listeners and delete-only syncs must still refresh) and (b) inside the `changed { ... }` block of `backfillMissingEffortScores` so the negative-case "nothing changed" path stays silent. `HomeView` listens via `.onReceive(NotificationCenter.default.publisher(for: .fortiFitHealthKitDidImport))` immediately after the existing `.onChange(of: scenePhase)` block, running the same trio of refreshes `.onAppear` already runs (`viewModel.loadData`, `activityService.refreshWorkoutContributions`, `recoveryService.refreshTimerLine`). Posting from `MainActor` (the service is `@MainActor`) means listeners receive on main without queue hops. Regression coverage in `FortiFitIntegrationTests/HealthKitIntegrationTests.swift`: `test_importPendingWorkouts_postsImportNotification_whenWorkoutLanded`, `test_importPendingWorkouts_postsImportNotification_onDeleteOnlySync`, `test_backfillMissingEffortScores_postsImportNotification_whenScoresChanged`, and an inverted `test_backfillMissingEffortScores_doesNotPost_whenNothingChanged` so a future refactor that always-posts is caught. Plan/Workouts list don't subscribe yet (out of scope — additive design lets them opt in without further sync-service changes). |
| Status | Resolved |

---

### BUG-079

| Field | Value |
|-------|-------|
| Date | 2026-06-05 |
| Phase | Phase 6 / 6.2 — Effort Trend chart card empty-state divergence (regression on BUG-073's card↔detail parity contract) |
| Description | The compact Effort Trend chart card on the Trends list renders an empty plot (Y-axis with `0`–`10` labels and X-axis with week-start dates, no bars) instead of showing the empty-state caption `"Log workouts with effort ratings to display effort trends."` when no logged workouts have `rpe` recorded. Reproducible by logging one or more workouts without an Effort value (or having only HK-imported Apple Workout sessions with no `workoutEffortScore`). Tapping the same card's chevron pushes the Detail View, which correctly displays the empty-state caption. So the card and detail surfaces give the user contradictory signals on the same data — the exact failure mode BUG-073 was supposed to have closed for every chart type. Confirmed visually against the attached screenshots: list view shows the broken empty plot; detail view shows the correct caption. |
| Root Cause | `ProgressViewModel.computeRPETrend()` (`FortiFit/Features/Progress/ProgressViewModel.swift:504–512`) appended a placeholder `RPEWeekEntry(weekStart:, averageRPE: 0)` for *every* week iterated by `forEachRecentWeek` — including weeks where `weekWorkouts.filter { $0.rpe != nil }` was empty. Because every past completed week landed in `rpeWeeklyData` with a zero value, `hasRPEData` (`ProgressViewModel.swift:160–166`) — which checks "any completed past week exists in cached array" — returned `true` whenever any past complete week existed, regardless of whether any workouts actually had RPE. `FortiFitProgressView.rpeTrendCard` passes `isEmpty: !viewModel.hasRPEData` to `FortiFitChartCard`, so `isEmpty` was `false`, the empty-state caption never fired, and the chart rendered with zero-height bars (axes only). The Detail View went through `TrendsChartService.hasEnoughData(for: "rpeTrend", ...)` → `hasAtLeastOneCompletedWeek(points: rpeTrendPoints(...), requiringValue: false)`; `rpeTrendPoints` (`TrendsChartService.swift:937–958`) already drops empty weeks (`if !rpes.isEmpty { weekData.append(...) }`), so the detail's emptiness check correctly fired the empty state. BUG-073's resolution claimed "`ProgressViewModel.has*Data` predicates were left as-is — they already implement the matching semantics on cached arrays" — true for `hasDurationData` (whose `computeDurationTrend` correctly `guard !weekWorkouts.isEmpty else { return }`s) but the same guard was missing from `computeRPETrend`, so `hasRPEData`'s semantics silently drifted from `hasEnoughData("rpeTrend", ...)`. |
| Resolution | Added `guard !weekWorkouts.isEmpty else { return }` inside `computeRPETrend`'s `forEachRecentWeek` block, immediately after the `rpe != nil` filter. This mirrors the identical guard in `computeDurationTrend` (`FortiFit/Features/Progress/ProgressViewModel.swift:541–542`) and restores parity between the cached `rpeWeeklyData` and `TrendsChartService.rpeTrendPoints(...)`. Empty weeks are no longer appended as zero-RPE placeholders, so `hasRPEData` now returns `false` when no completed prior week has RPE data, the card's `isEmpty` flips to `true`, and `FortiFitChartCard` renders the empty-state caption from `AppConstants.chartEmptyMessages["rpeTrend"]`. The Effort Trend chart itself also benefits — when populated, the chart only renders bars for weeks with actual RPE data (matching the detail view's bar set) rather than a mix of real bars and zero-height phantom bars from RPE-less weeks. Added a `// BUG-079` comment above the guard so future refactors can't quietly reintroduce the zero-fill. Regression coverage in `FortiFitTests/TrendsChartTests.swift` in a new `EffortTrendCardEmptyStateTests` suite: `test_workoutsWithoutRPE_hasRPEDataReturnsFalse` (asserts `vm.hasRPEData == false` and `rpeWeeklyData.isEmpty` when workouts exist with no RPE), `test_oneCompletedWeekWithRPE_hasRPEDataReturnsTrue` (asserts a single prior-week RPE-rated workout flips the flag and lands in the cached array), and `test_cardAndDetailAgreeWhenNoRPEData` (card-vs-detail parity check on the BUG-073 contract). |
| Status | Resolved |

---

### BUG-080

| Field | Value |
|-------|-------|
| Date | 2026-06-05 |
| Phase | Phase 3 — Workouts list / `FortiFitWorkoutTypeCard` (sort+filter active layout regression) |
| Description | On the Workouts screen, when a non-default sort is active *and* one or more filters are active, the "Strength Training" workout type card wraps its title mid-word across three lines: `Strengt` / `h` / `Training`. Reproducible by tapping the ellipsis menu, selecting any sort other than Newest First, applying any filter, then returning to the Workouts list. Other type cards (Cardio, HIIT, Other, Yoga) are unaffected because their titles are short enough to fit. |
| Root Cause | `FortiFitWorkoutTypeCard.cardContent` (`FortiFit/Design/Components/FortiFitWorkoutTypeCard.swift:55-58`) renders the type-name `Text` with no `.lineLimit` or `.minimumScaleFactor` modifier. The trailing HStack cluster (`Text(countLabel)` with `.fixedSize()` at `:67`, sort `Image` at `:71`, filter `HStack` at `:78`, chevron `Image` at `:95`) refuses to compress horizontally. When both sort + filter indicators are present the trailing cluster widens by ~30–40pt, and "Strength Training" is the only flexible element left — SwiftUI compresses it to the residual width. Because the residual width sits in the unlucky zone between "Strength" fitting on one line and the whole word breaking at the space, SwiftUI's last-resort text layout falls back to a mid-word break, producing the `Strengt`/`h` split. |
| Resolution | Restructured the trailing slot of `FortiFitWorkoutTypeCard.cardContent` so the count badge + sort/filter indicators stack vertically (count on top, indicators row beneath) instead of all crowding into the outer HStack. The fix was preceded by three failed text-modifier attempts on the title (documented here so future-me doesn't repeat the loop): (1) `.lineLimit(1) + .minimumScaleFactor(0.85)` — still truncated to `Strengt…`; (2) `.minimumScaleFactor(0.7)` — same truncation; (3) `.lineLimit(2)` — SwiftUI still broke mid-character as `Strengt` / `h Train…` because even *just* "Strength" alone couldn't fit the residual ~135pt left after the trailing chrome on a 393pt iPhone. Width analysis showed the trailing cluster (`"86 WORKOUTS"` ~85pt + sort icon ~19pt + filter icon+badge ~33pt + chevron ~16pt + 4× HStack spacing ~32pt = ~185pt) was the actual root cause; no text-shrinking modifier could close a ~50pt deficit. Wrapped `Text(countLabel)` + sort/filter indicators into a `VStack(alignment: .trailing, spacing: 2)` so the indicator row drops *underneath* the count instead of competing horizontally with it. The indicator row is conditionally rendered (only when `isNonDefaultSort || activeFilterCount > 0`) so the inactive state collapses to a single-child VStack — visually identical to the original single-row layout. Chevron and drag-handle stay outside the VStack, vertically centered relative to the whole card. Reclaimed ~50pt of horizontal width, enough for "Strength Training" to render single-line at native font size with no `.lineLimit`, no `.minimumScaleFactor`, and no `.kerning` change. Accepted tradeoff: when sort or filter is active, *all five* cards grow vertically by ~10pt (one consistent rhythm change across the list), and the card height jumps on toggle — consistent across cards, only on deliberate user action. Added `// BUG-080:` guard comment above the new VStack so future refactors can't quietly flatten it back into the HStack. Confirmed clean compile via `XcodeRefreshCodeIssuesInFile`. Visual mockup at `Design Mockups/WorkoutTypeCard_StackedTrailing_Option2.svg`. No regression unit test added: pure layout-modifier fix on a stateless SwiftUI view body with no observable behavior to assert against in Swift Testing — the `// BUG-080:` guard comment + mockup serve as the regression markers (same pattern used for BUG-077's `LazyVGrid` swap). |
| Status | Resolved |

---

### BUG-081

| Field | Value |
|-------|-------|
| Date | 2026-06-06 |
| Phase | Phase 8.8 / Phase 11 — Training Load Settings Modal & Linked Recovery & Load Settings Modal (Training Experience slider tick labels) |
| Description | On iPhone 17 (393pt wide), the middle slider tick label "INTERMEDIATE" wraps mid-word as `INTERMEDI` / `ATE` underneath the Training Experience slider. Reproducible by opening the Training Load Configure Settings modal (or the linked Recovery & Load Configure Settings modal) on any 393pt-class device. "BEGINNER" and "ADVANCED" tick labels render fine on a single line. |
| Root Cause | The three tick labels (`BEGINNER` / `INTERMEDIATE` / `ADVANCED`) are laid out as `Text`s separated by `Spacer()`s inside an `HStack` (`FortiFit/Features/Home/HomeView.swift:1126-1132` and `FortiFit/Design/Components/FortiFitLinkedRecoveryLoadSettingsModal.swift:112-118`). SwiftUI's `HStack` proposes roughly equal width to each flexible `Text` child — about a third of the available width minus the two `Spacer()`s. With `FortiFitTypography.labelSmall` (13pt semibold) + `.kerning(2)`, "INTERMEDIATE" measures wider than that one-third allocation on a 393pt screen (modal width minus 2×(screenHorizontal+8) outer padding minus 2×cardPadding ≈ 305pt available, so each Text gets ≤ ~100pt; "INTERMEDIATE" at kerning 2 measures ~106pt). The middle `Text` is the only one that overflows its proposed width, so it word-wraps. Total horizontal room is in fact sufficient for all three labels at intrinsic width — the wrap is caused by the equal-thirds proposal, not by genuine overflow. |
| Resolution | Added `.lineLimit(1)` + `.fixedSize(horizontal: true, vertical: false)` to each of the three tick `Text`s in both modals. `.fixedSize` overrides the proposed width and lets each `Text` render at its intrinsic width; the two `Spacer()`s then absorb the slack symmetrically. No font, kerning, or string change — visually identical on devices where the original layout already fit (iPhone Pro Max, iPad), now correct on 393pt-class devices. Avoided `.minimumScaleFactor` per the saved feedback note about it misbehaving with explicit `.kerning` (truncates with `…` instead of shrinking). Added `// BUG-081:` guard comment above each fixed row so a future refactor doesn't quietly drop the modifiers. |
| Status | Resolved |
