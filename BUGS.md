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
