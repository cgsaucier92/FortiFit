# IMPLEMENTATION_PLAN_PHASE_8_7_1.md: Apple Watch Sync — Entry-Point Refinement

> Refinement pass on top of Phase 8.7. Phase 8.7 is shipped and works. This phase fixes the discoverability gap: users can't tell what they need to enable to push a scheduled workout to Apple Watch. This plan moves the primary entry point upstream to Schedule Workout, makes "Push" the consistent verb, decouples time from push (noon fallback when no time is set), and renames "Set Specific Time" → "Scheduled Time" / "Date" → "Scheduled Date".

---

## 1. What's Changing

Five behaviors and one term:

1. **Primary entry point moves to Schedule Workout.** A new "Push to Apple Watch" toggle appears on the Schedule Workout sheet under the Recurrence option. This is where users now configure Watch sync for a workout. The Plan card glyph and the Edit Scheduled Workout toggle remain (status indicator + quick toggle, modification surface) but are no longer the discovery surface.

2. **Auto-default tied to master.** When master is on in Settings, Push defaults `true` for every newly scheduled workout. Users can opt out per workout. When master is off, the Push toggle on Schedule Workout is greyed out (off position) with caption *"Push to Apple Watch is off in Settings"* and a tap deep-links to Settings via the existing Master Sync Off Popover.

3. **Time is decoupled from Push.** Setting a scheduled time is optional regardless of push state. When Push is on and no `scheduledTime` is set, `WatchScheduleService` falls back to noon (12:00 PM) on the scheduled date for the WorkoutKit API call. Apple Watch does not surface the scheduled time to users, and the writeback uses the actual start time from iOS/watchOS. UI labels renamed: "Set Specific Time" → "Scheduled Time", "Date" → "Scheduled Date".

4. **Rename "Sync" → "Push" everywhere user-facing.** Settings master toggle becomes *"Push planned workouts to Apple Watch."* Edit Scheduled Workout toggle becomes *"Push to Apple Watch."* Plan card glyph tooltips and Master Sync Off Popover copy update accordingly. **Internal data fields are unchanged** — `UserSettings.syncPlanToAppleWatchEnabled` and `ScheduledWorkout.syncToAppleWatch` keep their Swift identifiers. This is purely a user-facing copy change.

5. **Plan card glyph behavior unchanged.** Same SF Symbols, same opacity rules, same one-tap behavior. Its role shifts from discovery to status + quick-toggle, but no implementation change.

The motivating user problem: pre-refinement, a user enabled the master setting, scheduled a workout without a time, and saw a greyed glyph on the Plan card with no explanation of why the workout wasn't pushing to their Watch. Post-refinement, the user makes the Push decision at the moment they're scheduling, and time is no longer a blocking requirement — the service handles the noon fallback transparently.

---

## 2. Required Reading

This refinement touches the same surfaces as Phase 8.7. Re-read these before starting if you've been away from the codebase.

| Doc | Section | Why |
|---|---|---|
| `WORKOUTKIT.md` | § 7 Sync Lifecycle, § 9 Authorization, § 10 UI Surfaces | Canonical spec — refined entry-point patterns land here. |
| `SCREENS.md` | § Plan → Scheduling Flow, § Edit Scheduled Workout, § Settings → Apple Watch Section, § Standard Patterns → Watch Sync Card Glyph + Master Sync Off Popover | Surfaces that change. |
| `SERVICES.md` | § PlanService → Scheduling, § WatchScheduleService → Triggers + Sync Gates | Default-on logic at scheduling time. |
| `CONSTANTS.md` | § Apple Watch Strings | All user-facing copy lives here. |
| `INFO_COPY.md` | § Inline Popover Copy → Watch Sync Toggle | Push toggle popover copy. |
| `PRD.md` | § Data Model → ScheduledWorkout (`syncToAppleWatch`), § UserSettings (`syncPlanToAppleWatchEnabled`) | Confirm the internal field names stay as-is — Swift identifiers are NOT being renamed. |
| `IMPLEMENTATION_PLAN_PHASE_8_7.md` | § 5 Phase A–G | The original implementation phases this builds on. |

---

## 3. Behavior Specifications

### 3.1 Schedule Workout — New "Push to Apple Watch" Toggle

Position: directly below the Recurrence segmented control, above the "Schedule Workout" CTA button. New row, full width.

Component: SwiftUI `Toggle` styled per the existing toggle treatment, with a trailing `info.circle` icon.

Identifier: `scheduleWorkout_pushToAppleWatchToggle`. Info-popover identifier: `scheduleWorkout_pushToAppleWatchInfoPopover`.

**Default value at sheet open:**

| Master state at sheet open | Push toggle default |
|---|---|
| `UserSettings.syncPlanToAppleWatchEnabled == true` AND WorkoutKit auth granted | `true` (on) |
| Master off OR auth denied | `false` (off, and toggle is disabled — see below) |

**When master is off (or auth denied):**

- Toggle rendered in off position, **greyed out (non-interactive)** at the same opacity used for the disabled card glyph (0.4).
- Caption directly beneath the toggle row, muted text: *"Push to Apple Watch is off in Settings"* (when master off) OR *"Apple Health permission required — open iOS Settings"* (when auth denied).
- Tap on the disabled toggle surfaces the existing Master Sync Off Popover with deep-link to in-app Settings (master-off case) or iOS Settings (auth-denied case). Same popover treatment as Phase 8.7 — no new popover needed.

**When the user toggles Push on or off:** No side effects on the Scheduled Time toggle. Time and Push are independent controls. When Push is on and no `scheduledTime` is set, `WatchScheduleService` falls back to noon (12:00 PM) for the WorkoutKit API call.

**Save behavior:**

When the user taps "Schedule Workout":

- `ScheduledWorkout.syncToAppleWatch` is set from the toggle's final value at save time.
- If `syncToAppleWatch == true`, gates are validated server-side as a defensive check (master on, auth granted, ≥1 exercise in snapshot, scheduledDate >= today). Validation failure should be impossible given the UI gates, but if it happens (race condition, form bypass), `syncToAppleWatch` is forced to `false` and a soft error toast appears: *"Couldn't push to Apple Watch — check Settings."*
- After SwiftData save, if `syncToAppleWatch == true`, `WatchScheduleService.schedule(_:)` is called per existing Phase 8.7 logic. New `appleWorkoutPlanId` UUID is stamped on first sync.
- For recurring schedules, the inheritance logic is unchanged — every instance in the new `recurrenceGroupId` gets the same `syncToAppleWatch` value (and the same `scheduledTime`, applied to each instance's date).

### 3.2 Edit Scheduled Workout — Toggle Rename

Existing "Sync to Apple Watch" toggle is renamed to **"Push to Apple Watch"**. Identifier `editScheduledWorkout_watchSyncToggle` stays for code consistency (or rename to `editScheduledWorkout_pushToggle` if you prefer; flag in `AccessibilityIdentifiers.swift` either way).

Time and Push are independent controls on the Edit screen as well — toggling Push on/off has no side effect on the Scheduled Time toggle.

`info.circle` popover copy updated to remove the time requirement reference.

### 3.3 Settings — Master Toggle Rename

The Settings → Apple Watch section's master toggle text changes from *"Sync planned workouts to Apple Watch"* to *"Push planned workouts to Apple Watch."* Description copy below the toggle stays the same. The section header stays *"Apple Watch."*

Confirmation alert title and message use the new term too: *"Turn off Push to Apple Watch?"* and *"All scheduled workouts currently pushed to your Apple Watch will be removed. You can turn it back on anytime — your push preferences will be remembered."*

Status line states stay as-is (`CONNECTED`, `PERMISSION DENIED IN IOS SETTINGS`).

### 3.4 Plan Card Glyph — No Behavior Change

Existing `FortiFitWatchSyncGlyph` component, existing four-state logic from Phase 8.7. Confirm the internal popover/tooltip strings reference "Push" in any user-visible copy (most are gate-failure messages keyed to specific failures and don't say "Sync" or "Push" — but audit `CONSTANTS.md § Apple Watch Strings` to be sure).

### 3.5 Master Sync Off Popover — Copy Update

Title changes from *"Apple Watch sync is off"* to *"Push to Apple Watch is off."*

Body and button text otherwise unchanged. Same in-app deep-link to Settings.

---

## 4. Copy Inventory (Updated)

All strings live in `CONSTANTS.md § Apple Watch Strings` under `AppConstants.AppleWatch.*`. New and renamed entries:

| Constant | Old Value (Phase 8.7) | New Value (Phase 8.7.1) |
|---|---|---|
| `settingsToggleLabel` | "Sync planned workouts to Apple Watch" | "Push planned workouts to Apple Watch" |
| `settingsTurnOffConfirmTitle` | "Turn off Apple Watch sync?" | "Turn off Push to Apple Watch?" |
| `settingsTurnOffConfirmMessage` | "All scheduled workouts currently synced to your Apple Watch will be removed…" | "All scheduled workouts currently pushed to your Apple Watch will be removed…" |
| `masterOffPopoverTitle` | "Apple Watch sync is off" | "Push to Apple Watch is off" |
| `editScheduledWorkout_toggleLabel` | "Sync to Apple Watch" | "Push to Apple Watch" |

New entries:

| Constant | Value |
|---|---|
| `scheduleWorkout_toggleLabel` | "Push to Apple Watch" |
| `scheduleWorkout_masterOffCaption` | "Push to Apple Watch is off in Settings" |
| `scheduleWorkout_authDeniedCaption` | "Apple Health permission required — open iOS Settings" |
| `scheduleWorkout_validationFailedToast` | "Couldn't push to Apple Watch — check Settings." |

Removed entries (time no longer gated):
- `setSpecificTime_pushRequiredCaption` — removed (time decoupled from push)
- `gateNoTime` — removed (no longer a gate failure)

Push toggle `info.circle` popover copy (lives in `INFO_COPY.md § Inline Popover Copy`):

> *"Pushes this workout to your Apple Watch's Workout app. Appears in the Scheduled section on the workout's day."*

This single popover string is reused by both Schedule Workout and Edit Scheduled Workout.

---

## 5. Code Implementation Sequence

Six discrete chunks. Order matters — strings come first so UI work can reference final copy.

**Chunk A — Copy & Constants:**
1. Update `AppConstants.AppleWatch.*` per § 4 above.
2. Update `INFO_COPY.md` reference string for the Push toggle popover.
3. Add new `AccessibilityIdentifiers.swift` entries: `scheduleWorkout_pushToAppleWatchToggle`, `scheduleWorkout_pushToAppleWatchInfoPopover`.

**Chunk B — Schedule Workout View:**
1. Add the Push toggle row beneath the Recurrence segmented control in `ScheduleWorkoutView.swift`.
2. Wire the toggle's default value to `UserSettings.syncPlanToAppleWatchEnabled` AND auth state at sheet open.
3. Rename "Set Specific Time" → "Scheduled Time", "Date" → "Scheduled Date".
4. Implement the disabled-toggle + caption treatment when master is off / auth denied. Tap routes to existing Master Sync Off Popover.

**Chunk C — Edit Scheduled Workout View:**
1. Rename toggle label to "Push to Apple Watch."
2. Rename labels to match Plan Workout screen ("Scheduled Date", "Scheduled Time" toggle).

**Chunk D — Settings View:**
1. Rename master toggle label.
2. Update confirmation alert copy.

**Chunk E — Standard Patterns:**
1. Update Master Sync Off Popover title.

**Chunk F — Tests:**
1. Unit tests:
   - Schedule Workout default Push value resolves correctly across master states (on/off, auth granted/denied).
   - Gate passes when `scheduledTime` is nil (noon fallback).
   - Recurring schedule with time propagates `scheduledTime` to all instances.
2. Integration tests:
   - Save flow: `ScheduledWorkout.syncToAppleWatch` reflects toggle state at save time.
   - Save with `syncToAppleWatch == true` calls `WatchScheduleService.schedule(_:)` once.
   - Recurring schedule with Push on → all 12 instances inherit Push value.
3. UI tests:
   - Schedule Workout opens with Push toggle in correct default position based on master state.
   - Tap on disabled Push toggle (master off) shows Master Sync Off Popover.
   - Push and Scheduled Time toggles are independent (no auto-enable/lock coupling).

---

## 6. Acceptance Criteria

- [ ] User opens Schedule Workout while master is on → Push toggle defaults to on; Scheduled Time toggle is independent and off by default.
- [ ] User opens Schedule Workout while master is off → Push toggle is greyed out in off position with "Turn it on in Settings" caption; tap shows Master Sync Off Popover with deep-link to Settings.
- [ ] Push and Scheduled Time toggles are fully independent — toggling one has no effect on the other.
- [ ] Saving a Push-enabled scheduled workout registers a plan with the Watch (via existing `WatchScheduleService.schedule(_:)` flow). `appleWorkoutPlanId` is stamped.
- [ ] Recurring schedules: every instance inherits the Push value and the time. Confirmed via integration test.
- [ ] All user-facing copy reads "Push" not "Sync" — verified across Settings, Edit Scheduled Workout, Schedule Workout, Master Sync Off Popover. Internal Swift identifiers (`syncToAppleWatch`, `syncPlanToAppleWatchEnabled`) unchanged.
- [ ] Plan card glyph behavior unchanged from Phase 8.7 — passes existing 8.7 UI tests without modification.
- [ ] Existing 8.7 integration tests continue to pass with the rename. Auto-default on master cycles, reconciliation, recurrence inheritance — all unchanged.

---

## 7. Risks and Edge Cases

- **Multiple same-day workouts:** When multiple workouts are scheduled for the same day without a time, they all get the same noon fallback timestamp. Unlikely to cause issues since Apple Watch doesn't surface the time, but could affect sort order. A per-workout minute offset could be added as a trivial fix if needed.
- **User scheduled workout while master was off, later turns master on:** card was created with `syncToAppleWatch = false`. Master coming on doesn't retroactively flip it. User must manually toggle Push on via card glyph or Edit Scheduled Workout. This is correct — defaults capture state at creation. Worth documenting in user-facing help if you ever add it.
- **Scheduled time picker increment:** `Date.now` may not align to the picker's increment (e.g., 5-min steps). Snap to the next valid increment when auto-defaulting.
- **Existing Phase 8.7 UI tests:** the rename will break any test that asserts on the old "Sync to Apple Watch" copy. Audit and update before merging.
- **Existing data:** all existing `ScheduledWorkout` records and `UserSettings` are unaffected — only user-facing copy changes. No migration needed.

---

## 8. Out of Scope (Explicit)

- Renaming Swift identifiers (`syncToAppleWatch`, `syncPlanToAppleWatchEnabled`) — internal-only, unchanged.
- Changing the Plan card glyph component, behavior, or visual treatment.
- Changing the Phase 8.7 reconciliation logic, plan-ID round-trip, or cleanup lifecycle.
- Changing the master-off / master-on intent-preservation behavior — Interpretation A from Phase 8.7 stays.
- Configurable fallback-time setting in Settings (noon is sufficient — Apple Watch doesn't surface the scheduled time).
- Retroactively flipping `syncToAppleWatch` on existing cards when the user changes the master setting.

---

## 9. Estimated Effort

- Chunk A: 0.25 session
- Chunk B: 0.5 session
- Chunk C: 0.25 session
- Chunk D: 0.25 session
- Chunk E: 0.1 session
- Chunk F: 1 session

Total: ~2.5 sessions including tests.
