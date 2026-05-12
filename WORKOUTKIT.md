# WORKOUTKIT.md: FitNavi Apple Watch Workout Scheduling

> Authoritative spec for outbound workout scheduling via WorkoutKit. Cross-references PRD.md, SERVICES.md, SCREENS.md, CONSTANTS.md, HEALTHKIT.md, and TESTING.md for domain-specific details rather than duplicating them.
> For data models, see `PRD.md` § Data Model. For service implementations, see `SERVICES.md`. For UI layouts, see `SCREENS.md`. For static tables, see `CONSTANTS.md`. For inbound HealthKit integration, see `HEALTHKIT.md`.

---

## 1. Overview

WorkoutKit integration lets FitNavi push `ScheduledWorkout`s onto the user's paired Apple Watch as native workouts in the Watch's Workout app Scheduled section. When the user starts and completes a session on Watch, WorkoutKit preserves the `WorkoutPlan.id` UUID on the resulting `HKWorkout` via the `HKWorkout.workoutPlan` extension property (async). FitNavi uses this UUID to deterministically match the completion back to the originating `ScheduledWorkout`. No native watchOS companion app is built.

The product intent: a user schedules a workout in FitNavi, walks to the gym, raises their wrist, taps the workout in Apple's Workout app, completes it set-by-set with rest timers between sets, and sees it logged automatically in FitNavi when they next open the app.

---

## 2. Scope

### In Scope (MVP — Phase 8.7)

- Outbound scheduling via `WorkoutScheduler.shared.schedule(_:at:)`
- `CustomWorkout` plan composition with one block per exercise, exercise prescriptions as step display names, and rest intervals between sets
- Plan-ID round-trip via `HKWorkout.workoutPlan?.id` for deterministic completion matching
- Per-`ScheduledWorkout` sync intent (card glyph, Edit Planned Workout toggle)
- Master Settings kill switch with reconciliation behavior
- Edit Planned Workout flow (long-press on Plan screen) with "this only / this and future" recurrence prompt
- WorkoutKit authorization (just-in-time on master toggle on)
- Time-based work intervals for isometric exercises (Planks, etc.) via dictionary lookup
- Per-exercise REPS/TIME override toggle
- Per-exercise REST PER SET field
- Cleanup lifecycle: skipped, completed, removed-from-plan, day-passed, sync-off, master-off, auth-revoked
- Reconciliation triggers: master toggle, foreground, auth state change, recurrence regen
- watchOS 11+ static caveat (no dynamic version detection)
- UI surfaces: card glyph, Edit Planned Workout, Settings Apple Watch section, master-off popover, error toast

### Explicitly Out of Scope (MVP)

- **Native watchOS companion app.** Indefinitely deferred. WorkoutKit accomplishes the integration goal without one.
- **Watch-side editing of scheduled workouts.** All edits happen on iPhone.
- **Sync diagnostics UI.** Debug logs to console only.
- **Dynamic watchOS version detection.** Static caveat copy in Settings; no probing of paired Watch OS.
- **Per-template Functional-vs-Traditional Strength Training override.** Defaults only (see § 6 Outbound HK Mapping).
- **Cardio / Yoga / Pilates / Other workout type scheduling.** Templates only support Strength Training and HIIT today; non-supported types can't be scheduled in the first place.
- **Time-based work intervals as a first-class HIIT concept.** Isometric exercises (Planks, Wall Sits) display as time via the dictionary flag, and the per-exercise REPS/TIME toggle handles ambiguous cases. No additional "HIIT timed work" mode.
- **Plan ID stamping for non-Watch-synced workouts.** `appleWorkoutPlanId` is only set when sync is enabled.

---

## 3. Phase

WorkoutKit integration is **Phase 8.7** in the FitNavi roadmap. The full feature index is in CLAUDE.md § Phase 8.7. This section only adds WK-internal phasing detail.

Phase 8.7 ships as a single Claude Code implementation pass — no internal sub-phases. Depends on:
- Phase 7 (Plan / Workout Scheduler) for the `ScheduledWorkout` foundation.
- Phase 8 (HealthKit Integration read-only) for the round-trip via `HKWorkout.workoutPlan` and the existing import pipeline.

---

## 4. Architecture Decisions

### `ScheduledWorkout` as Source of Truth

After scheduling, the `ScheduledWorkout` (specifically its `scheduledWorkoutSnapshot`) is the source of truth for what gets pushed to the Watch. Templates are the foundation but the relationship ends at scheduling time. This means:

- Editing a template does not propagate to existing scheduled workouts.
- Editing a `ScheduledWorkout` (via the Edit Planned Workout flow) deviates the snapshot from the original template freely; on save, the Watch is re-synced from the new snapshot.

**Rationale:** preserves the existing PlanService snapshot semantics ("editing a template after scheduling does not silently alter planned workouts"), while giving users a clean per-instance edit path.

### Always `CustomWorkout`, Never `SingleGoalWorkout`

All Watch-synced plans are `CustomWorkout` with one block per exercise. No simple/detailed mode toggle. The simple `SingleGoalWorkout` (single time goal, no exercise structure) was considered but rejected as too thin to justify the dual code path.

**Consequence:** every synced `ScheduledWorkout` must have ≥1 exercise. This becomes an explicit gate on the sync toggle.

### Plan-ID Fast-Path Before `WorkoutMatcher`

Workouts arriving from HealthKit whose `HKWorkout.workoutPlan?.id` matches a known `appleWorkoutPlanId` bypass the existing fuzzy `WorkoutMatcher` entirely and route through `PlanService.completeFromWatch(...)`. The matcher only runs for HK workouts without a plan-ID match.

**Rationale:** plan-ID match is deterministic; running the fuzzy matcher on top would risk lower-confidence prompts surfacing for workouts the user already explicitly scheduled.

### Stable Plan UUIDs

Each `ScheduledWorkout` gets a `appleWorkoutPlanId: UUID?` field, stamped on first sync and reused for the entire lifetime of the record. Off/on cycles, edits, master-toggle bounces — none of them change the UUID. Cleared only on `ScheduledWorkout` deletion.

**Rationale:** simpler mental model, easier debugging, and the matcher fast-path can rely on a single stable identity per scheduled workout.

### `WatchScheduleService` Separate from `PlanService`

All `WorkoutScheduler` interactions go through a dedicated service. `PlanService` doesn't import `WorkoutKit`; it delegates Watch-relevant operations to `WatchScheduleService`.

**Rationale:** distinct concern (Watch sync vs Plan CRUD), distinct testing surface (`StubWorkoutScheduler` vs in-memory SwiftData), distinct dependency. Mirrors the `HealthKitClient` / `HealthKitSyncService` separation.

### Intent vs Reconciliation Model

Per-card `syncToAppleWatch` flag is *user intent*. Whether the plan is actually registered with the Watch is *reconciliation state*, derived at runtime from intent ∩ master-toggle ∩ auth-state ∩ gating-conditions. The card glyph reflects effective state, not intent alone — an "intended sync" with master off renders as disabled.

**Rationale:** preserves the user's selections across master-toggle and auth-state cycles, while honestly reflecting what's actually on Watch.

### No Write-Back to HealthKit

FitNavi still does not write to HealthKit. WorkoutKit registers plans on the Watch; the Watch records the resulting `HKWorkout` itself when the user completes the session. FitNavi never touches `HKHealthStore.save(_:)`.

**Consequence:** the existing `typesToShare = []` in HealthKit authorization (HEALTHKIT.md § 4) is unaffected. WorkoutKit auth is requested separately and independently.

---

## 5. Data Model

The new fields are defined canonically in PRD.md § Data Model — that's the schema source of truth. Notes specific to WorkoutKit behavior:

- `ScheduledWorkout.syncToAppleWatch: Bool` — user intent flag. Defaults `false`. Toggled via the card glyph or Edit Planned Workout.
- `ScheduledWorkout.appleWorkoutPlanId: UUID?` — stamped on first sync, reused thereafter. Cleared only on record deletion.
- `ScheduledWorkout.scheduledWorkoutSnapshot` (renamed from `templateSnapshot`) — JSON blob containing exercises plus the new per-exercise fields below.
- `TemplateExerciseSet.restSeconds: Int?` and `ExerciseSet.restSeconds: Int?` — single value per exercise (UI keeps all rows of the same `exerciseName` in lockstep).
- `TemplateExerciseSet.displayAsTime: Bool?` and `ExerciseSet.displayAsTime: Bool?` — three-state override of the dictionary default.
- `UserSettings.syncPlanToAppleWatchEnabled: Bool` — master kill switch.

Encoding format for `scheduledWorkoutSnapshot` extends the existing JSON to add the two per-exercise fields:

```json
[
  {
    "exerciseName": "Bench Press",
    "sets": 3,
    "reps": 5,
    "weightKg": 74.84,
    "sortOrder": 0,
    "restSeconds": 90,
    "displayAsTime": null
  }
]
```

Backwards compatibility: `restSeconds` and `displayAsTime` are nullable. Snapshots created before Phase 8.7 will be missing both keys — decoders must default them to nil.

---

## 6. Plan Composition

When `WatchScheduleService.schedule(_:)` is called, it builds a `WorkoutPlan` wrapping a `WorkoutComposition` of type `.custom`, then calls `WorkoutScheduler.shared.schedule(_:at:)`.

### Activity Type (Outbound HK Mapping)

The `WorkoutComposition` is stamped with a single `HKWorkoutActivityType` derived from the `ScheduledWorkout.workoutType` via the lookup in HK_MAPPING.md § Outbound Mapping:

| FortiFit `workoutType` | `HKWorkoutActivityType` |
|---|---|
| Strength Training | `.traditionalStrengthTraining` |
| HIIT | `.highIntensityIntervalTraining` |

No per-template override in MVP. See HK_MAPPING.md § Outbound Mapping for rationale.

### Block Structure (one block per exercise)

For each exercise in the decoded `scheduledWorkoutSnapshot` (in `sortOrder`):

1. Resolve display mode: `displayAsTime ?? ExerciseSuggestionService.isIsometric(exerciseName)`. The dictionary's value for the exercise is the default; the per-row override (when non-nil) wins.
2. Build an `IntervalBlock`. For each of the `sets` count:
   - Append an `IntervalStep(.work, goal: <goal>)` with the resolved goal value.
   - If `restSeconds != nil` AND this is not the last set in the block, append an `IntervalStep(.recovery, goal: .time(TimeInterval(restSeconds), .seconds))`.
3. Set the work step's `displayName` per the formatting rules in § 6.4 below.
4. After the final set's work step, do **not** append a recovery step — the user transitions directly to the next exercise.

### Goal Mapping

| Resolution | Goal |
|---|---|
| Display as reps | `IntervalStep(.work, goal: .open)` — user taps Done to advance |
| Display as time | `IntervalStep(.work, goal: .time(TimeInterval(reps), .seconds))` — Watch auto-counts down |

When display-as-time, the integer in the `reps` field is interpreted as seconds. The field name is unchanged in the data model — interpretation is purely at composition time.

### Step Display Name Formatting

| `displayAsTime` resolved | `weightKg` | Step display name |
|---|---|---|
| false (reps) | nil | `"{exerciseName} · {reps} reps"` (e.g., `"Push-Ups · 10 reps"`) |
| false (reps) | set | `"{exerciseName} · {reps} reps @ {weight}{unit}"` (e.g., `"Bench Press · 5 reps @ 165 lb"`) |
| true (time) | nil | `"{exerciseName} · {reps}s"` (e.g., `"Plank · 60s"`) |
| true (time) | set | `"{exerciseName} · {reps}s @ {weight}{unit}"` (e.g., `"Weighted Dead Hang · 30s @ 25 lb"`) |

Weight respects user units (`UserSettings.useLbs`). No "BW" suffix on bodyweight rows — the absence of weight is sufficient signal on a small Watch face.

### Plan Wrapping

The `WorkoutComposition` is wrapped in a `WorkoutPlan(id: appleWorkoutPlanId, ...)`. The `id` parameter is the `ScheduledWorkout.appleWorkoutPlanId` UUID. WorkoutKit uses this UUID for plan identity; after the user completes the session on Watch, the same UUID is recoverable via `HKWorkout.workoutPlan?.id` (a WorkoutKit async extension property on `HKWorkout`).

### Schedule Time

`WorkoutScheduler.shared.schedule(plan, at:)` requires a real `Date`. Computed as `combined(scheduledDate, scheduledTime)` when `scheduledTime` is set, or noon (12:00 PM) on `scheduledDate` when `scheduledTime` is nil. See § 7 Sync Lifecycle Gates.

---

## 7. Sync Lifecycle

### Sync Toggle Gates

The per-card `syncToAppleWatch` toggle is interactive (and `WatchScheduleService.schedule(_:)` is allowed to register the plan) only when **all** of these conditions hold:

1. `UserSettings.syncPlanToAppleWatchEnabled == true` (master on)
2. WorkoutKit authorization granted
3. `scheduledWorkout.scheduledDate >= today`
4. `scheduledWorkoutSnapshot` decodes to ≥1 exercise

When any gate fails, the glyph renders disabled (muted, 0.4 opacity) and tap shows a contextual popover explaining what's missing. Specific popover messages by failure mode are in CONSTANTS.md § Apple Watch Strings.

**Scheduled time is not a gate.** `scheduledTime` is optional. When nil, `WatchScheduleService` falls back to noon (12:00 PM) on the scheduled date for the WorkoutKit `schedule(_:at:)` call. Apple Watch does not surface the scheduled time to users, and the writeback uses the actual start time from iOS/watchOS — the value is purely an API formality.

**Phase 8.7.1 entry-point refinement:** The primary configuration moment for `syncToAppleWatch` moves upstream to the Plan Workout sheet. A new "Push to Apple Watch" toggle there captures the user's intent at scheduling time, defaulting to `true` when master is on and auth granted. The Plan card glyph and Edit Planned Workout toggle remain (status indicator + quick-toggle on Plan; modification on Edit), but are no longer the discovery surface. User-facing copy renamed from "Sync" → "Push" everywhere; internal field names (`syncToAppleWatch`, `syncPlanToAppleWatchEnabled`) unchanged.

### On Per-Card Toggle On

Optimistic UI flow:

1. Glyph flips to active state immediately.
2. `syncToAppleWatch` flag set to `true` in SwiftData.
3. If `appleWorkoutPlanId == nil`, generate and persist a new UUID.
4. `WatchScheduleService.schedule(scheduledWorkout)` is called (async).
5. On success: glyph stays active.
6. On error: glyph reverts to inactive; error toast appears; `syncToAppleWatch` flag retained as `true` (intent preserved).

### On Per-Card Toggle Off

1. Glyph flips to inactive immediately.
2. `syncToAppleWatch` flag set to `false`.
3. `WatchScheduleService.removePlan(appleWorkoutPlanId)` is called (async).
4. `appleWorkoutPlanId` is **retained** on the model — not cleared.
5. On error: error toast appears, glyph stays inactive (the intent matches the visible state regardless of Watch-side success).

### On Edit (Edit Planned Workout Save)

1. SwiftData write completes for the new snapshot / fields.
2. If `syncToAppleWatch == true` and gates still pass:
   - `WatchScheduleService.removePlan(appleWorkoutPlanId)`
   - `WatchScheduleService.schedule(scheduledWorkout)` — same UUID, new plan content
3. If `syncToAppleWatch == true` but gates now fail (e.g., user removed all exercises): `removePlan` only, glyph renders disabled with appropriate popover.
4. If `syncToAppleWatch == false`: no Watch operation needed.

### On Master Toggle Off

1. Settings flag flipped to `false`.
2. For every `ScheduledWorkout` with `syncToAppleWatch == true`: `WatchScheduleService.removePlan(appleWorkoutPlanId)`.
3. Per-card flags **retained** (intent preserved).
4. All card glyphs render disabled. Tap shows master-off popover.

### On Master Toggle On

1. Settings flag flipped to `true`.
2. If WorkoutKit auth not yet granted, request authorization. On grant, proceed; on deny, status line updates and no further action.
3. Reconciliation runs: every `ScheduledWorkout` with `syncToAppleWatch == true` AND gates passing gets `WatchScheduleService.schedule(_:)` called with its existing `appleWorkoutPlanId`.

### Reconciliation

`WatchScheduleService.reconcile()` runs:

- After master toggle on (post-auth-grant)
- App foreground transition (defensive sweep, in case Watch state drifted)
- Auth state change (granted ↔ denied)
- After "this and future" recurrence edits
- After 12-week recurrence regenerator creates new instances
- After WorkoutKit auth restored

Reconcile loop:

1. Query `WorkoutScheduler.shared.scheduledPlans` to get current Watch state.
2. Build expected set: `ScheduledWorkout`s with `syncToAppleWatch == true` AND master on AND auth granted AND gates passing.
3. For each expected: if its UUID is not on Watch, schedule it. If on Watch but content changed since last schedule, re-schedule (removePlan + schedule).
4. For each plan on Watch whose UUID isn't in the expected set: removePlan.

Content-change detection: hash of the snapshot + scheduledTime + scheduledDate. Stored on the `ScheduledWorkout` as a transient hash field (or recomputed on demand).

---

## 8. Plan-ID Round-Trip

When the user completes a Watch-synced workout, WorkoutKit preserves the plan identity on the resulting `HKWorkout` via the `HKWorkout.workoutPlan` extension property (async). `DefaultHealthKitClient.makeSnapshot()` reads this to populate `snapshot.workoutPlanId`. FitNavi's existing HealthKit observer pipeline picks it up and routes through a dedicated completion path.

### Completion Flow

1. User starts the synced workout from Watch's Scheduled section.
2. Watch records the session as an `HKWorkout`. The `WorkoutPlan.id` is preserved and accessible via `HKWorkout.workoutPlan?.id` (WorkoutKit extension).
3. HealthKit observer query fires (on next foreground or background delivery).
4. `DefaultHealthKitClient.makeSnapshot()` reads `try? await workout.workoutPlan` and sets `snapshot.workoutPlanId = plan.id`.
5. `HealthKitSyncService.importPendingWorkouts()` processes the snapshot. Step 0 (plan-ID fast-path):

   ```
   if let planId = snapshot.workoutPlanId {
       if let scheduledWorkout = PlanService.findByPlanId(planId) {
           PlanService.completeFromWatch(scheduledWorkout: scheduledWorkout, hkSnapshot: snapshot)
           return  // skip matcher entirely
       }
   }
   // fall through to existing Steps 1–4 (matcher path)
   ```

5. `PlanService.completeFromWatch(...)`:
   - Decodes `scheduledWorkoutSnapshot`.
   - Creates a `Workout` with: name from `ScheduledWorkout.workoutName`, type from `ScheduledWorkout.workoutType`, date from snapshot's start date, `healthKitUUID` from snapshot, `healthKitSourceBundleID` (Apple Watch), `healthKitActivityType` ("Traditional Strength Training" or "HIIT" friendly string per HK_MAPPING.md), and all HK-owned fields populated from the snapshot.
   - Creates `ExerciseSet` records from the snapshot exercises (preserves `restSeconds` and `displayAsTime`).
   - Sets `ScheduledWorkout.status = "completed"` and `completedWorkoutId = newWorkout.id`.
   - Calls `WatchScheduleService.removePlan(appleWorkoutPlanId)` to clear the Watch-side registration (since it's now completed).
   - Fires the standard Workout Cascade.

### Why Bypass `WorkoutMatcher`

The matcher's job is fuzzy disambiguation when there's no explicit identity link. Plan-ID is an explicit identity link — running the matcher on top would risk surfacing prompts for workouts the user already explicitly scheduled.

### Edge Cases

- **Plan-ID present but `ScheduledWorkout` not found.** The `ScheduledWorkout` was deleted between scheduling and completion. Treat as if no plan ID: fall through to the matcher. Auto-create proceeds normally if no match.
- **Plan-ID present and `ScheduledWorkout.status` is already "completed" or "skipped".** Edge case: user deleted the schedule via "Remove from Plan" while the Watch session was in flight, then completed it on Watch. Treat as if no plan ID: fall through to the matcher. Better to create a duplicate manual workout than to silently overwrite a completed slot.
- **Plan-ID present but the FitNavi workout was already created via plan-ID match earlier.** Idempotency: if a `Workout` with the resulting `healthKitUUID` already exists, treat as an Upstream Update (HEALTHKIT.md § 11) instead of creating a duplicate.

---

## 9. Authorization

### Just-in-Time Pattern

WorkoutKit authorization is requested only when the user flips the Settings master toggle on for the first time. Per-card toggles never trigger authorization directly — they're gated by master, which is gated by auth.

Flow:

1. User flips Settings master toggle on.
2. FitNavi checks `WorkoutScheduler.shared.authorizationState`.
3. If `notDetermined`: call `WorkoutScheduler.shared.requestAuthorization()`. iOS shows the native dialog.
4. On grant: master stays on, status line shows "Connected", reconciliation runs.
5. On deny: master stays visually on, status line shows "Permission denied in iOS Settings", "Open iOS Settings" button appears. No reconciliation.
6. If already determined (granted or denied from a previous session): skip the prompt, just transition state.

### Info.plist

WorkoutKit does not require a separate Info.plist usage description in iOS 17+. The existing HealthKit usage description (`NSHealthShareUsageDescription`) covers the round-trip's read-side; outbound writes (the Watch recording the session) don't need iOS-side write authorization because FitNavi isn't writing to HealthKit — the Watch is.

### Auth Revoked Mid-Session

If the user revokes WorkoutKit auth via iOS Settings → Privacy → Workout while FitNavi is running:

1. Next `WatchScheduleService` operation fails with an auth error.
2. `WatchScheduleService` catches the error, updates internal auth state to denied, triggers UI refresh.
3. Settings master toggle stays visually on, but status line shows "Permission denied in iOS Settings". "Open iOS Settings" button appears.
4. All Plan card glyphs render disabled (muted, 0.4 opacity).
5. Tapping any card glyph shows the master-off popover (which now directs to iOS Settings via the auth-denied path).
6. Per-card flags retained.

Plans already on Watch from before the revocation remain there until the user clears them via iOS Settings or restores auth and FitNavi reconciles.

When auth is restored:

1. FitNavi detects on next foreground (auth state query).
2. Reconciliation runs against the current Watch state.
3. Glyphs return to their effective state per per-card flags.

---

## 10. UI Surfaces

### Card Glyph (Plan screen)

Component: `FortiFitWatchSyncGlyph` in `Design/Components/`. Position: upper-right of every `FortiFitScheduledWorkoutCard`.

| State | SF Symbol | Color | Opacity | Tap behavior |
|---|---|---|---|---|
| Active (synced) | `applewatch.watchface` | Watch Sync Green | 1.0 | Toggle off (with optimistic UI + revert-on-error) |
| Inactive (not synced, gates pass) | `applewatch.slash` | Muted Text | 1.0 | Toggle on (with optimistic UI + revert-on-error) |
| Disabled (gates fail or master off or auth denied) | `applewatch.slash` | Muted Text | 0.4 | Show contextual popover explaining the gate failure |

The disabled treatment is the same SF Symbol as inactive but with reduced opacity. This signals "off and unavailable" vs "off but available," consistent with iOS disabled-control conventions.

### Edit Planned Workout Toggle

Inside the Edit Planned Workout screen, a SwiftUI `Toggle` labeled **"Push to Apple Watch"** (Phase 8.7.1 rename) with a trailing `info.circle` popover. Mirrors the per-card flag. Disabled when master is off (popover redirects to Settings). Time is independent of the Push toggle — users can optionally set a scheduled time regardless of Push state.

### Plan Workout Toggle (Phase 8.7.1)

Inside the Plan Workout sheet (the primary entry point for Watch push), a SwiftUI `Toggle` labeled **"Push to Apple Watch"** positioned directly under the Recurrence segmented control. Default value at sheet open is driven by `UserSettings.syncPlanToAppleWatchEnabled` AND WorkoutKit auth state: `true` when both pass; `false` (greyed, 0.4 opacity, non-interactive) otherwise. Time is independent — the Scheduled Time toggle is a normal optional control regardless of Push state. Full layout in SCREENS.md § Plan → Push to Apple Watch Toggle.

### Settings → Apple Watch Section

Sibling card to Apple Health (no FortiFitDivider between). See SCREENS.md § Settings → Apple Watch Section for layout. Master toggle, description (with watchOS 11+ caveat baked in), status line, "Open iOS Settings" button. Four-state table mirrors Apple Health's pattern.

### Master Sync Off Popover

Triggered when user taps a card glyph or Edit Planned Workout toggle while master is off. Copy:

> **Push to Apple Watch is off**
> Turn it on in Settings to push this workout to your Apple Watch.
> [Open Settings]

"Open Settings" navigates in-app to Settings → Apple Watch section (NavigationPath push).

### Field-Specific Gate Popovers

When a card glyph is disabled due to a specific field missing, the popover surfaces what's needed:

| Failure mode | Popover copy |
|---|---|
| `scheduledDate < today` | (no popover — past-dated cards are simply read-only) |
| Zero exercises in snapshot | "Add at least one exercise to sync to Apple Watch." |
| Master off | (master-off popover, see above) |
| Auth denied | (master-off popover, which redirects to Settings → Apple Watch → Open iOS Settings) |

### Error Toast

When a `WatchScheduleService` operation fails for transient reasons:

> Couldn't sync to Apple Watch. Try again later. [Retry]

Capsule style per CONSTANTS.md § Toast Style. [Retry] action re-fires the failed operation. Auto-dismisses after 4 seconds (consistent with other action-link toasts).

---

## 11. Error Handling

### Optimistic UI with Revert

Per-card glyph flips on tap immediately. Service call fires in the background. On failure, glyph reverts and toast appears.

### Failure Modes

| Failure | Response |
|---|---|
| Auth not granted (defensive — gates should prevent) | Auto-flip master to off-with-denied-state; surface in Settings. |
| Auth revoked mid-session | Detect on next operation, treat as auth-denied (see § 9). |
| WorkoutKit internal error | Error toast with [Retry]. Per-card flag retained. |
| Plan ID collision (theoretical with deterministic UUIDs) | Log internally. No user-visible action. |
| Watch not paired / not reachable | API typically succeeds; plan delivers when Watch reconnects. No user-visible error. |
| Snapshot decode failure | Log to BUGS.md; treat as if the `ScheduledWorkout` had no exercises (gate fails). |

### No Silent Retries

Failed operations are not retried automatically. The user has [Retry] in the toast for immediate retry, and reconciliation on next foreground handles passive recovery.

### Per-Card Intent Preservation

Per-card `syncToAppleWatch` is retained as user intent regardless of what happens to the Watch-side state. If a `schedule()` call fails after the user tapped the glyph, the flag stays `true`. Reconciliation will retry on next foreground. The glyph's effective state reflects "is the plan currently registered with Watch," not "did the user want it to be."

---

## 12. Cleanup Lifecycle

`WorkoutScheduler.shared.removePlan(uuid)` is called on:

| Trigger | Handler | Notes |
|---|---|---|
| `ScheduledWorkout` skipped | PlanService → WatchScheduleService | Status set to "skipped"; if synced, removePlan. |
| `ScheduledWorkout` completed (Watch path) | PlanService.completeFromWatch | removePlan after creating Workout. |
| `ScheduledWorkout` completed (in-app path) | PlanService.complete | removePlan if `syncToAppleWatch == true`. |
| "Remove from Plan" action | PlanService → WatchScheduleService | removePlan if synced before deletion. |
| Day passed without completion | WatchScheduleService.reconcile (foreground sweep) | removePlan for any past-dated synced plans. |
| Per-card sync toggle off | WatchScheduleService directly | removePlan. |
| Master toggle off | WatchScheduleService loop | removePlan for every synced ScheduledWorkout. |
| WorkoutKit auth revoked | (no action — Watch retains plans until restored) | Plans remain on Watch but FitNavi can't manage them. Reconciliation cleans up when auth restored. |

### Past-Dated Sweep

On every app foreground, `WatchScheduleService.reconcile()` checks for `ScheduledWorkout`s where `syncToAppleWatch == true` AND `scheduledDate < today` AND status is still "planned". For each, call `removePlan` to clear the stale Watch entry. The `ScheduledWorkout` itself remains as overdue per the existing Plan logic.

---

## 13. Recurrence Handling

### Schedule Recurring (initial create)

When a recurring `ScheduledWorkout` is created, the 12-week regenerator creates one instance per week (or biweek). Each instance has its own `id` and `appleWorkoutPlanId` (when synced).

**Default `syncToAppleWatch` on new instances:** `false`. User must opt in per instance. (Future enhancement: a "sync entire series" toggle on the recurrence creation flow — out of scope for MVP.)

### Regenerate Recurrence (auto-extend)

When the regenerator creates new instances to maintain the 12-week lookahead (PlanService § Regenerate recurrence), each new instance inherits `syncToAppleWatch` from the **most recent existing instance in the same `recurrenceGroupId`**. Falls back to `false` if no existing instance found (shouldn't happen — by definition the group has at least one).

If the inherited value is `true`, the regenerator immediately calls `WatchScheduleService.schedule(_:)` for the new instance. Each new instance gets a freshly-generated `appleWorkoutPlanId`.

### Edit Recurring Instance

Edit Planned Workout on a recurring instance prompts on Save: "This workout only" / "This and future workouts." See SCREENS.md § Edit Planned Workout for the prompt UI.

- **This only:** snapshot saved to this instance only. Re-sync (removePlan + schedule, same UUID) if `syncToAppleWatch == true`.
- **This and future:** snapshot applied to this instance plus all future instances in the same `recurrenceGroupId` (`scheduledDate >= this instance's date`). Each affected synced instance gets re-sync (removePlan + schedule, each with its own existing UUID).

**Date changes always force "this only"** — applying a date change to a series doesn't have a coherent meaning. The recurrence prompt explicitly states this when a date change is detected.

### Remove from Plan (recurring)

Per existing PlanService § Remove from Plan: prompt "this only / this and future." Watch-side cleanup follows the deletion:

- Single instance deleted: removePlan (if synced), then SwiftData delete.
- "This and future" range deleted: removePlan for each synced instance in the range, then bulk delete.

---

## 14. watchOS 11+ Caveat

Apple Watch's Workout app Scheduled section requires watchOS 11 or later. On watchOS 10, scheduled plans are registered via WorkoutKit (the iOS API succeeds) but never appear in the Watch UI — the Scheduled section doesn't exist on watchOS 10.

### Approach: Static Caveat Copy

The Settings → Apple Watch section description includes the static caveat: "Requires watchOS 11 or later." No dynamic version detection from FitNavi.

**Rationale:**

- iOS-side detection of paired Watch's OS version is brittle. WCSession requires a paired companion app (which we don't have). HealthKit metadata can sometimes leak Watch OS, but it's undocumented and unreliable.
- The iOS WorkoutKit API doesn't error on watchOS 10 — it succeeds and silently no-ops on the Watch side.
- The user knows their own Watch version better than we can detect.

**Consequence:** users on watchOS 10 see all toggles work normally but never see the workout appear on their Watch. The static caveat informs them upfront. Future enhancement (heuristic detection of "no plans completed via Watch despite many synced") is out of scope.

---

## 15. Reconciliation Triggers (Consolidated)

`WatchScheduleService.reconcile()` runs on:

- App foreground (defensive sweep)
- Master Settings toggle on (after auth grant)
- WorkoutKit auth state change (granted ↔ denied)
- After "this and future" recurrence edits (PlanService.editScheduledWorkout)
- After 12-week recurrence regeneration creates new instances (PlanService → WatchScheduleService hook)
- After auth restored from a previously-denied state

Each trigger runs the same loop described in § 7 Reconciliation.

---

## 16. Testing Strategy

See TESTING.md for target structure and conventions, and TESTING.md § WorkoutKit Test Strategy for the protocol-stub pattern parallel to HealthKit's.

### Protocol Stubbing

`WatchScheduleService` is backed by `WorkoutSchedulerProtocol`. Tests inject `StubWorkoutScheduler` from `TestFixtures.swift`. The stub records `schedule` and `removePlan` calls and exposes assertion helpers. No test file outside the stub itself imports `WorkoutKit`.

### Test Distribution

| Target | Scenarios |
|---|---|
| `FortiFitTests` (unit) | Outbound HK type mapping correctness. Plan composition rules: block-per-exercise, recovery-step-between-sets, no-recovery-after-final-set. Step display name formatting (4 cases: reps/time × weight/no-weight). REST PER SET range validation (5–600s, 5s increments). REPS/TIME `displayAsTime` resolution against dictionary defaults. Sync gate logic (4 conditions; noon fallback when `scheduledTime` is nil). |
| `FortiFitIntegrationTests` | Plan-ID fast-path: HK arrives with `workoutPlanId` → `PlanService.completeFromWatch` fires, cascade runs, ScheduledWorkout marked completed, Watch plan removed. Edit flow: edit a synced ScheduledWorkout → re-sync called with same UUID. Master toggle off → all plans removed; per-card flags retained. Master toggle on (with prior intent) → reconciliation re-schedules. Recurrence regen creates new instances; if siblings synced, new ones are scheduled too. Auth revoked mid-session → graceful degradation. Past-dated sweep on foreground. Plan-ID match against deleted ScheduledWorkout falls through to matcher. |
| `FortiFitUITests` | Settings master toggle states (off, on-granted, on-denied). Plan card glyph states (active, inactive, disabled) and tap behavior. Master-off popover deep-link to Settings. Edit Planned Workout screen flow (open via long-press, edit fields, save, prompt for recurrence). REST PER SET picker interactions. REPS/TIME toggle interactions including column-header swap. |

### Untestable (Requires Manual QA)

- Real-Watch round-trip end-to-end (schedule → start on Watch → complete → appears in FitNavi).
- WorkoutKit's actual behavior with deterministic UUIDs (upsert vs error).
- Authorization prompt UX on first toggle-on.
- watchOS 10 paired Watch behavior (silent no-op confirmation).
- Background reconciliation when Watch session completes while FitNavi is closed.

---

## 17. Accessibility Identifiers

Add to `AccessibilityIdentifiers.swift`:

- `settings_appleWatchToggle`
- `settings_appleWatchOpenSettingsButton`
- `scheduledWorkoutCard_{index}_watchSyncGlyph`
- `editScheduledWorkout_watchSyncToggle`
- `editScheduledWorkout_watchSyncInfoPopover`
- `editScheduledWorkout_recurrencePrompt_thisOnly`
- `editScheduledWorkout_recurrencePrompt_thisAndFuture`
- `editScheduledWorkout_saveButton`
- `editScheduledWorkout_backButton`
- `editScheduledWorkout_dateField`
- `editScheduledWorkout_timeField`
- `exerciseCard_{index}_restPerSetField`
- `exerciseCard_{index}_restPerSetInfoPopover`
- `exerciseCard_{index}_repsTimeToggle`
- `masterSyncOff_popover`
- `masterSyncOff_openSettingsButton`
- `watchSyncErrorToast`
- `watchSyncErrorToast_retryButton`

---

## 18. Future Phases (Scope-Only)

### Sync Entire Series Toggle

When creating a recurring `ScheduledWorkout`, offer a "Sync all instances to Apple Watch" toggle that flips all 12 instances at once. Currently, users opt in per instance. Out of scope for MVP — flagged as a polish enhancement.

### Per-Template Functional vs Traditional Strength Training Override

Add a `WorkoutTemplate.appleHealthSubtype: HKWorkoutActivityType?` field letting users specify Functional vs Traditional. Currently, Strength Training defaults to Traditional. Out of scope for MVP — flagged as a power-user enhancement.

### Watch-Side Editing

Allow users to modify a scheduled workout from the Watch's Workout app. Currently read/start only. Likely requires a watchOS companion app and deeper WorkoutKit integration. Indefinitely deferred.

### Heuristic watchOS Version Detection

Detect "no plans completed via Watch in the last 30 days even though several have been scheduled" → surface a heuristic warning. Out of scope; static caveat is sufficient.

### Sync Diagnostics UI

Settings sub-page showing currently scheduled plans on Watch, plan-ID round-trip success rate, last reconciliation timestamp. Out of scope; debug-log only for MVP.
