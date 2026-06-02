# HEALTHKIT.md: FitNavi HealthKit Integration

> Authoritative spec for HealthKit integration. Cross-references PRD.md, SERVICES.md, SCREENS.md, CONSTANTS.md, and TESTING.md for domain-specific details rather than duplicating them.
> For data models, see `PRD.md` § Data Model. For service implementations, see `SERVICES.md`. For UI layouts, see `SCREENS.md`. For static tables, see `CONSTANTS.md`.

---

## 1. Overview

HealthKit integration lets FitNavi import workouts recorded on Apple Watch (or any Health-connected source — Peloton, Strava, Garmin, etc.) and reconcile them against FitNavi's own records. It is **read-only in MVP**. FitNavi does not write to HealthKit under any circumstance.

The product intent: a user records a workout on Apple Watch, opens FitNavi, and sees the workout already logged — ready for them to add exercise sets, RPE, and notes.

---

## 2. Scope

### In Scope (MVP — Phases 1+2 ship together)
- Workout import (auto-create new records when no FitNavi match exists)
- Dedup and linking (match incoming HK workouts against existing FitNavi records; bidirectional matcher)
- Background sync (observer queries + background refresh)
- Catch-up sync on launch (anchored queries)
- Upstream delete handling (promote to manual)
- Upstream update handling (HK wins on HK-owned fields)
- UI surfaces: Workout Detail source indicator + info sheet, peripheral glyphs, Log Workout read-only fields, Workout Detail Summary two-column grid (HK-linked), Settings "Apple Health" section
- iOS 18+ `workoutEffortScore` import into `rpe` (nil-fill only)

### In Scope (Phase 11)
- **Sleep data import** — `.asleep*` and `.inBed` category samples from any HK source (Apple Watch, Oura, Whoop, AutoSleep, etc.), aggregated into `DailySleepSnapshot` records on a 6pm-to-6pm wake-up-date attribution window. See § 21 (Sleep Data).
- Sleep observer query + `BGAppRefreshTask` registration for overnight refresh.
- `UserSettings.targetSleepHours` (Double, default 7.0). Optional import from Apple Health's sleep duration goal characteristic via "Import from Apple Health" in the Recovery Status Settings Modal.
- Sleep-adjusted Training Load decay path (only when the Recovery Status widget is linked to Training Load) — see SERVICES.md § Training Load Algorithm → Sleep-Adjusted Decay.
- New UI surfaces: Recovery Status widget (four gating states), Recovery Status Settings Modal, Recovery Status Detail Sheet, Linked Recovery & Load composite + combined Settings / See Info / Detail Sheet, Settings → Apple Health "Sleep" status row.

### Explicitly Out of Scope (MVP)
- **Write-back** (FitNavi → HealthKit). Deferred indefinitely. See § 22.
- **Biometrics** (resting HR, HRV, body weight, VO₂ max, etc.). Deferred to Phase 10. See § 22.
- **GPS / route data**. Not loaded, not stored.
- **User-configurable HK-to-FortiFit type mapping**. Static table only.
- **`estimatedWorkoutEffortScore`**. Ignored entirely; only user-entered `workoutEffortScore` imports.
- **Sync diagnostics UI** (sample counts, per-type breakdowns, etc.)

---

## 3. Phases

HealthKit integration is **Phase 8** in the FitNavi roadmap. The full feature index is in CLAUDE.md § Phase 8 — this section only adds HK-internal phasing detail.

**Phase 1 (Foundation + Import)** and **Phase 2 (Background Delivery)** ship together as a single Claude Code implementation pass. The split is conceptual — separated so the test matrix is easier to reason about, but no user-facing release between them.

- **Phase 1 — Foundation + Workout Import.** Authorization, anchored catch-up queries on launch/foreground, auto-create flow, bidirectional matcher, all UI surfaces, Settings section, manual "Sync Now". After Phase 1 alone, workouts arrive on next foreground.
- **Phase 2 — Background Delivery.** Adds `HKObserverQuery` with `enableBackgroundDelivery`, `BGAppRefreshTask` registration + handler, and `@MainActor` marshaling. Workouts arrive without user opening the app.

Out of both phases: biometrics (future Phase 10), write-back (deferred indefinitely). See § 22.

**Phase 11 (Sleep Data + Recovery Status Widget)** ships on top of Phases 1+2. Phase 11 extends `HealthKitClient` with sleep sample reads, registers a sleep observer query, expands `BGAppRefreshTask` scope, and adds new authorization types (see § 17, § 21). The matcher and Workout Cascade are unchanged — sleep data flows through a separate service (`RecoveryStatusService` in SERVICES.md) and a separate cascade (Sleep Cascade). The CLAUDE.md § Phase 11 row indexes the full feature set.

---

## 4. Architecture Decisions

### Dual-Source with Pointer
SwiftData is the source of truth for all cascade logic, algorithms, and UI. HealthKit is a reconciliation source. Every `Workout` carries an optional `healthKitUUID` pointing back to its HK record. Manual workouts have nil.

**Rationale:** preserves the existing Workout Cascade unchanged. All algorithms (Training Load, Streak, Power Level, Goal auto-update, GoalSnapshot) continue to query SwiftData only. HK reconciliation runs asynchronously and writes into the same SwiftData surface.

### `HealthKitClient` Protocol
All HealthKit access goes through `HealthKitClient` (protocol). Integration tests stub it with fixture data. Only the concrete implementation `DefaultHealthKitClient` imports `HealthKit`. No service outside the client directly imports `HealthKit`.

### Threading
Observer query callbacks fire on background threads. The sync service marshals to `@MainActor` before touching `ModelContext`. All SwiftData writes happen on main.

### No Write-Back (MVP)
FitNavi never writes to HealthKit. `typesToShare` is an empty set in the authorization request. `NSHealthUpdateUsageDescription` is not included in Info.plist.

**Consequence:** manually logged FitNavi workouts do not contribute to the Apple Move/Exercise rings. Accepted tradeoff.

---

## 5. Data Model

The 10 new `Workout` fields and the `WorkoutMatchRejection` entity are defined in PRD.md § Data Model — that's the canonical schema. Notes specific to HK behavior:

- All 10 new `Workout` fields are optional. `healthKitUUID == nil` means manual; non-nil means HK-imported or HK-linked.
- `WorkoutMatchRejection` is standalone (UUID-pair lookup, no `@Relationship`). Orphan rejections after a `Workout` is deleted are retained — harmless, no cleanup in MVP.
- **Phase 11 adds** `DailySleepSnapshot` (one record per wake-up date) and `DailyTrainingLoadSnapshot` (one record per day). Both standalone, no `@Relationship`. The sleep snapshot is the persistence layer for `RecoveryStatusService`'s 30-day cache (see § 21); the TL snapshot is captured at midnight rollover and on cascade events so the Trends `trainingLoadTrend` chart can render historical days without recomputing from raw HK inputs each open. Full field tables live in PRD.md § Data Model.

Field ownership (HK-owned vs user-owned) is in § 7 below.

---

## 6. Workout Type Taxonomy

Six FitNavi types: **Strength Training, HIIT, Cardio, Yoga, Pilates, Other**. "Other" is the catch-all for HK types without a clean category match (Kickboxing, Tai Chi, Dance, Rock Climbing, etc.) and the forward-compatibility bucket for new HK types in future iOS versions.

Two-level categorization:
- **FortiFit `workoutType`** (high-level): drives all algorithms, Workouts-screen organization, goal matching. One of the six types.
- **`healthKitActivityType`** (low-level, display-only): UI specificity. Never consumed by any algorithm.

The static `HKWorkoutActivityType` → FortiFit `workoutType` mapping lives in **HK_MAPPING.md**. Not user-configurable. Every Apple-defined `HKWorkoutActivityType` has an explicit entry; future-iOS unknowns fall through to "Other" via a `default` case.

---

## 7. Field Ownership

### HK-Owned Fields (HK wins on upstream update)
`date` (start time), `durationMinutes`, `distanceKm`, `avgHeartRate`, `maxHeartRate`, `activeEnergyKcal`, `totalEnergyBurnedKcal`, `elevationAscendedMeters`, `exerciseMinutes`, `indoor`, `healthKitActivityType`.

### User-Owned Fields (user always wins; HK never overwrites)
`name`, `note`, `time`, `ExerciseSets`, `rpe`.

### Read-Only Behavior in Log Workout Edit
When `healthKitUUID != nil`, the following fields are disabled (non-editable) in the Log Workout edit view: `durationMinutes`, `distanceKm`, `date` (start time).

Each disabled field's label shows a trailing `info.circle` icon (14pt, Muted Text). Tapping it opens a `.popover` with field-specific copy explaining why the field is read-only and how to recover edit access (see CONSTANTS.md § HealthKit Strings → Log Workout — HealthKit-Linked Field Popovers).

To edit these fields, the user must first unlink via Workout Detail (ellipsis menu or source indicator info sheet).

### Template Application on HK-Linked Workouts (Edit Mode)
The Edit Workout screen exposes a "Use Template" item in the top-right ellipsis menu for Strength Training and HIIT workouts (regardless of whether the workout is HK-linked — see SCREENS.md § Log Workout → Edit Mode Ellipsis Menu). Templates apply to user-owned fields only:

- **Exercises** (`ExerciseSets`, user-owned): the template's exercises are appended to the workout's existing exercise list as new rows. No dedupe by name. This is the primary value of applying a template to an imported workout — Apple Watch typically imports a workout with empty exercise data, so the template fills it in.
- **Name** (user-owned): fills only if `workout.name` is empty. Never overwrites a name the user has already entered.
- **Duration** (HK-owned): the template's `durationMinutes` is **silently dropped**. The HK-linked workout's `durationMinutes` continues to come from the HK record. The disabled-field treatment and `info.circle` popover are unaffected.
- **Workout type** (HK-owned via mapping): the template selector filters to templates matching the workout's current type, so a type mismatch can't arise. The template's type is not applied.

Field-ownership invariant: applying a template never changes a HK-owned field's value, even transiently. The matcher and upstream-update flow are unaffected because no HK-relevant fields move.

---

## 8. Effort Score (iOS 18+ only)

All effort-score reads are gated `if #available(iOS 18, *)`. iOS 17 users don't receive this sub-feature.

### Rules (Option 2 — nil-fill only)
- **On import:** if `rpe == nil` and HK has a `workoutEffortScore` for this workout, set `rpe = workoutEffortScore` AND set `rpeFromHK = true` (provenance flag — see PRD.md § Data Model → Workout). Otherwise leave both `rpe` and `rpeFromHK` unchanged.
- **Never overwrite:** if `rpe != nil` (user has set a value in FitNavi), HK `workoutEffortScore` is ignored regardless of whether it changes later. `rpeFromHK` stays `false`.
- **User edits clear provenance:** any subsequent user mutation of `rpe` via Log Workout (Edit Mode) sets `rpeFromHK = false`. The flag is exclusively about whether the *current* `rpe` value originated from HK.
- **Estimated scores ignored:** `estimatedWorkoutEffortScore` is never imported. Only user-entered `workoutEffortScore` contributes.

`rpeFromHK` is consumed by the unlink flow (§ 14) to decide whether to clear `rpe` alongside the six HK-only summary fields. No other algorithm reads it.

### API Mechanics
`workoutEffortScore` is NOT a property on `HKWorkout`. It is a separate `HKQuantitySample` queried via `HKSampleQuery` and related to the workout via `relateWorkoutEffortSample(_:with:activity:)`. Permission is requested separately as `HKQuantityType(.workoutEffortScore)`.

---

## 9. Sync Lifecycle

### Three Layers

| Layer | Purpose | When It Runs |
|---|---|---|
| `HKObserverQuery` w/ `enableBackgroundDelivery` | Live sync | HK writes a new workout; iOS wakes FitNavi |
| `BGAppRefreshTask` | Belt-and-suspenders | Periodically, when iOS permits |
| `HKAnchoredObjectQuery` catch-up | Mandatory backstop | Every cold launch and foreground |

All three converge on the same entry point: `HealthKitSyncService.importPendingWorkouts()`.

### Anchor Persistence
`HKQueryAnchor` is persisted to UserDefaults (serialized `Data`). Every successful anchored query updates the anchor. Catch-up on launch uses the persisted anchor as the "since" marker.

### Deleted-Object Handler
Anchored queries MUST wire the `deletedObjectHandler`. Without it, HK-side deletions never reach FitNavi. See § 11 for behavior.

### Known Failure Modes (documented, no UI)
- User force-quit FitNavi → background delivery does not fire. Catch-up on next launch recovers.
- User disabled Background App Refresh at OS level → imports only during foreground. Catch-up on launch still runs.

---

## 10. Auto-Create Flow

Happy path: HK workout arrives, no matching FitNavi record exists (after `WorkoutMatcher` runs), create a new first-class `Workout`.

### Minimum-Duration Floor
HK workouts under **2 minutes** are skipped entirely. No FitNavi record created. Not added to the matching pool.

**Scope:** applies only to auto-create. If a user manually logs a 90-second sprint and an HK record under 2 minutes matches, linking still works (via manual-side matcher entry point).

### Default Field Values on Auto-Create

| Field | Value |
|---|---|
| `healthKitUUID` | HK workout UUID |
| `healthKitSourceBundleID` | Source's bundle ID |
| `healthKitActivityType` | Friendly display string |
| `workoutType` | Mapped from HK type via CONSTANTS.md table |
| `name` | `"{healthKitActivityType} — {date} {time}"` (e.g., "Outdoor Run — Apr 23, 7:02 PM") |
| `date` | HK workout start date |
| `time` | HK workout start date (time component) |
| `durationMinutes` | HK workout duration in minutes (rounded to nearest integer) |
| `distanceKm` | HK distance if available, else nil |
| `rpe` | Nil (unless iOS 18+ `workoutEffortScore` present — see § 8) |
| `note` | Empty string |
| `ExerciseSets` | Empty |
| `lastModifiedDate` | `.now` |
| All HK-owned measurement fields | Populated from HK |

### Cascade
Auto-create routes through `WorkoutService.log()`. Full Workout Cascade fires (see SERVICES.md § Deletion Cascading Behavior → Workout Cascade). Training Load, Streak, Power Level, goal auto-update, GoalSnapshot all recalculate.

---

## 11. Upstream Updates and Deletes

### Upstream Update
HK wins on HK-owned fields (see § 7). `lastModifiedDate` bumps to `.now`. Workout Cascade fires to pick up any changed measured fields.

User-owned fields (`name`, `note`, `time`, `ExerciseSets`, `rpe`) are never touched by upstream updates.

### Upstream Delete
When `deletedObjectHandler` reports a HK workout deletion:
1. Find the FitNavi `Workout` with matching `healthKitUUID`.
2. Clear `healthKitUUID`, `healthKitSourceBundleID`, `healthKitActivityType` (set to nil).
3. Retain all HK-sourced measurement values as-is. The record is now a manual workout.
4. Bump `lastModifiedDate` to `.now`. This re-scopes the workout against any goal `resetDate` (see SERVICES.md § Goal Auto-Update → Reset Scoping).
5. **Do NOT fire the deletion cascade.** This is not a deletion.

**Rationale:** conservative, non-destructive. User retains their training history even if they clean up the Health app. Accepts that FitNavi data may diverge from HealthKit after this point.

---

## 12. Deduplication (`WorkoutMatcher`)

### 12.0 Plan-ID Fast-Path (Phase 8.7+)

Before the matcher runs, `HealthKitSyncService.importPendingWorkouts()` checks each incoming snapshot for `workoutPlanId` (populated via `HKWorkout.workoutPlan?.id`, a WorkoutKit async extension). If present and resolves to a `ScheduledWorkout` with matching `appleWorkoutPlanId`, the workout is routed through `PlanService.completeFromWatch(...)` and the matcher is skipped entirely.

This handles the deterministic case where FitNavi itself scheduled the workout via WorkoutKit (Phase 8.7 — see WORKOUTKIT.md § 8). The matcher's fuzzy logic only runs for HK workouts without a plan-ID match (the great majority — anything not scheduled by FitNavi).

Edge cases:

- **Plan-ID present but `ScheduledWorkout` not found** (e.g., schedule was deleted between scheduling and Watch completion): treat as if no metadata, fall through to the matcher path.
- **Plan-ID present but `ScheduledWorkout.status` is already "completed" or "skipped"**: edge case where user removed the schedule while a Watch session was in flight. Fall through to the matcher to avoid silently overwriting.
- **Plan-ID present but a FitNavi `Workout` already exists with `healthKitUUID == snapshot.uuid`**: idempotency case (e.g., re-import). Treat as Upstream Update (§ 11) instead of creating a duplicate.

See WORKOUTKIT.md § 8 for full mechanics. The matcher's bidirectional rules below apply only to non-plan-ID workouts.

### 12.1 Matcher Rules (existing)

Single service. Bidirectional. Called from two entry points:

| Entry Point | Caller | When |
|---|---|---|
| `matcher.findMatch(forIncomingHKWorkout:)` | `HealthKitSyncService` | Before auto-creating from an HK import |
| `matcher.findMatch(forNewManualWorkout:)` | `WorkoutService.log()` | Immediately after saving a manual workout |

Both use the same time-window rules and both respect `WorkoutMatchRejection` records.

### Tiered Confidence

| Tier | Rule | Action |
|---|---|---|
| **High** | Same `workoutType` AND `\|startA − startB\| ≤ 5 min` AND `\|endA − endB\| ≤ 5 min` | Auto-link silently. Apply field-ownership rules. Inline badge on workout card. |
| **Lower** | Same `workoutType`, same calendar day, **non-overlapping**, `\|startA − startB\| ≤ 4 hours` | Queue for user prompt (see § 13). |
| **None** | Outside both windows, different type, or different day | No match. Auto-create proceeds. |

### Rejection Check
Before proposing any pairing (high or lower), matcher queries for a `WorkoutMatchRejection` with matching `(healthKitUUID, workoutId)`. If found, skip — treat as no match.

### Same-Day Sessions Are Expected to Be Separate
AM+PM sessions of the same type on the same day, if non-overlapping AND >4 hours apart, are separate records by design. No prompt. No merge.

### Field Application on Link
Regardless of direction:
1. Populate `healthKitUUID`, `healthKitSourceBundleID`, `healthKitActivityType` on the FitNavi `Workout`.
2. Apply HK-owned field values from the HK record (overwrites prior FitNavi values for HK-owned fields only).
3. User-owned fields unchanged.
4. Bump `lastModifiedDate` to `.now`.
5. Fire Workout Cascade (any changed measured fields affect Training Load, goals, snapshots).

---

## 13. Prompt UX (Sheet-on-Foreground)

When `WorkoutMatcher` queues a lower-confidence match, present a modal sheet the next time the app foregrounds.

### Sheet Contents

- **Title:** "Possible Match"
- **Side-by-side summary:**
  - Left column (HK workout): date/time, `healthKitActivityType`, duration, key HK metrics (distance if present, avg HR, active kcal)
  - Right column (FitNavi workout): name, `workoutType`, RPE, ExerciseSets count, notes preview
- **Primary actions** (three buttons):
  - **"Link these workouts"** — applies high-confidence link logic
  - **"Keep separate"** — creates a `WorkoutMatchRejection` and dismisses
  - **"Decide later"** — dismisses without resolution; re-prompts next foreground
- **Secondary:** none in MVP. "Don't suggest for these again" is equivalent to "Keep separate" which persists the rejection.

### Behavior
- One sheet per pending match. Sequential, not batched.
- Multiple pending matches → sequential sheets on foreground.
- Sheet is dismissible (swipe-down = "Decide later").

### SCREENS.md
Add `SCREENS.md § Match Prompt Sheet` section with layout spec.

---

## 14. Unlink

### Two Entry Points
1. Workout Detail ellipsis menu → "Unlink from Apple Health" (visible only when `healthKitUUID != nil`)
2. Source indicator info sheet → "Unlink from Apple Health" link (gated by confirmation dialog)

### Confirmation
Unlink is **always** gated behind a SwiftUI `.confirmationDialog` regardless of entry point. Title "Unlink workout from Apple Health?" Message "This will delete all Apple Health–sourced summary data for this workout, and you won't be able to link it back. This can't be undone." Actions: destructive "Unlink" + cancel "Cancel". Copy is owned by `AppConstants.HealthKit.unlinkConfirm*` (see CONSTANTS.md § HealthKit Strings).

### On Unlink (one-way, destructive on summary data)
1. Capture `healthKitUUID` into a local before clearing — needed for step 7.
2. Clear `healthKitUUID`, `healthKitSourceBundleID`, `healthKitActivityType` (set to nil).
3. **Clear the six HK-only summary fields** (set each to nil): `avgHeartRate`, `maxHeartRate`, `activeEnergyKcal`, `totalEnergyBurnedKcal`, `elevationAscendedMeters`, `exerciseMinutes`. These have no manual-entry path in FitNavi, so retaining them on a now-manual workout would surface data the user can't trace, edit, or reproduce.
4. **Conditionally clear `rpe`:** if `workout.rpeFromHK == true`, set `rpe = nil`. Set `rpeFromHK = false` regardless. This isolates the destructive clear to RPE values that originated from `workoutEffortScore` (see § 8) without erasing user-entered effort ratings.
5. **Retain** `durationMinutes`, `distanceKm`, `date`, `time`, `name`, `note`, `ExerciseSets`, and `indoor` — these either have a manual-entry path or are user-owned per § 7. They become regular editable fields on a now-manual workout.
6. Bump `lastModifiedDate` to `.now`.
7. **Fire the full Workout Cascade** (SERVICES.md § Workout Cascade). Training Load, Effort Trend chart points, Power Level inputs, header summary recompute, and GoalSnapshot recompute against the cleared values. This is a behavior change from the prior spec — see § Why cascade now.
8. **Write a `WorkoutMatchRejection`** with `(healthKitUUID: capturedUUID, workoutId: workout.id, reason: .unlinked)`. This guarantees:
   - The matcher (`WorkoutMatcher.findCandidates(for:)`) skips the (UUID, workoutId) pair forever.
   - If the same HK UUID re-imports (e.g., the user removes and re-installs the Health source), auto-create proceeds normally as a new workout, but auto-link to this specific FitNavi workout is short-circuited. Other FitNavi workouts can still match it via the normal flow.
   - Re-linking via the Match Prompt Sheet for this same pairing is impossible — the matcher never queues it.

### Why one-way
Reversible unlink caused confused re-prompts and weaker warning copy. One-way unlink → "Unlinking is permanent" reads crisply and the matcher never re-proposes a rejected pair. Same-outcome workaround: delete the FitNavi workout and let auto-create rebuild from HK.

### Why cascade now
Earlier spec did NOT fire the cascade because unlink retained all measurement values — no aggregate input changed. Now that step 3 clears six HK-only fields and step 4 may clear `rpe`, downstream aggregates (Effort Trend chart points, Training Load when `rpe` is cleared, header summaries) need to recompute against the new values. Cascade after the field mutations and `lastModifiedDate` bump (so cascade reads the freshest state) and before the rejection write (so the rejection is purely a side effect with no cascade dependency).

### Contrast with HK Upstream Delete
HK upstream delete (§ 11) is non-destructive on measurements — it retains all HK-sourced values and does not fire the cascade. Rationale: upstream delete may be incidental (the user cleaning up Health), and FitNavi protects training history. User-initiated unlink is the destructive path because the user explicitly opted in via the confirmation dialog.

---

## 15. UI Surfaces

### Workout Detail Source Indicator
Below the Workout Type row, when `workout.healthKitUUID != nil`. Format: `[glyph] {sourceName}` — glyph leads the source name, no activity type prefix. Glyph renders **only when source is Apple Watch**.

- Source name resolved via `HealthKitClient.sourceName(for:)` per SERVICES.md § HealthKitClient. Apple Watch → `Apple Workout`; other recognized sources keep their `HKSource.name`; unresolvable bundle IDs fall back to `another app`. Never displays a raw bundle ID.
- Leading glyph: `FortiFitHealthGlyph` (Apple Workout running figure on green) — renders only when source is Apple Watch, positioned left of the source name. Other sources show no glyph.
- Styled as secondary/muted text using the app's Label treatment (11px, 700 weight, 2px letter-spacing, Muted Text color).
- Tappable → opens info sheet.

Full layout spec lives in SCREENS.md § Workout Detail → Source Indicator.

### Source Indicator Info Sheet (post-Phase-8.5 redesign)
- **Lead sentence:** "This workout was imported from Apple Health." (no inline source-name interpolation — moved to the footer).
- **Two-row callout** explaining (a) which fields are read-only here and (b) that unlinking is permanent and deletes Apple Health–sourced summary data — see SCREENS.md § Workout Detail → Source Indicator Info Sheet for exact copy and SF symbols.
- **Primary safe action:** full-width "Done" button (Primary Accent blue outline). This is the visually largest action, matching the iOS convention of giving the safe path the prominence.
- **Demoted destructive link:** "Unlink from Apple Health" rendered as a small Alert Red text-style link below Done. Tap → confirmation dialog (see § 14 Confirmation) → on confirm runs `HealthKitSyncService.unlink(workout:)` per § 14.
- **Footer metadata** (muted, below destructive link): Activity Type, Source (uses `sourceName` resolver), Imported date, Last synced (relative time from `HealthKitSyncService.lastSyncDate(for:)`). Source name resolution: Apple Watch → `Apple Workout`, recognized sources → `HKSource.name`, unresolvable → `another app`. Never renders a raw bundle ID.

Full layout spec lives in SCREENS.md § Workout Detail → Source Indicator Info Sheet.

### Workout Detail Summary — Stat Card Grid (Phase 8.5)

Workout Detail Summary renders as a **2-column grid of bordered, tappable stat cards**, regardless of whether the workout is HK-linked. HK-imported measurement fields (Avg HR, Max HR, Active kcal, Total kcal, Elevation Ascended, Exercise Minutes) render as additional stat cards alongside user-entered fields (Effort, Duration, Distance) — same field structure, same visual treatment. Manual workouts collapse to 2–3 cards naturally; HK-linked workouts can show up to 9.

**Indoor/Outdoor: removed** from Summary entirely.

Each card is independently tappable and opens the **Metric Detail Sheet** (per-metric comparative average + 30-day sparkline + optional Personal Best chip). The detail sheet's data layer is `WorkoutMetricService` (see SERVICES.md § WorkoutMetricService).

**Units** respect user preferences: `elevationAscendedMeters` displays as meters or feet per the distance unit setting. HR is always bpm. Calories are always kcal.

Full layout spec (including stat-card structure, field order, per-field display values, and Metric Detail Sheet behavior) is in SCREENS.md § Workout Detail → Summary and § Workout Detail → Metric Detail Sheet.

### Peripheral Apple Workout Label
On compact surfaces (Home, Workouts, Plan), Apple-Watch-sourced workouts display the text "Apple Workout" (styled `bodySmall` / muted) instead of the glyph icon. Renders trailing on the metadata row, separated by ` · `, **only when source is Apple Watch**:
- Recent Workouts list rows (Home)
- Workout Type card preview rows (Workouts tab)
- Scheduled Workout cards / logged-only cards (Plan tab)

Non-Apple-Watch HK sources (Strava, Peloton, etc.) do not render this label on peripheral surfaces — they are visually indistinguishable from manual workouts on those compact surfaces.

Visible only when `healthKitUUID != nil`. Full glyph + source name indicator stays on Workout Detail only.

### Log Workout Read-Only Fields
When `healthKitUUID != nil`:
- `durationMinutes`, `distanceKm`, `date` inputs are disabled (visually greyed, non-interactive).
- Each disabled field's label shows a trailing `info.circle` icon → popover with field-specific copy.
- All other fields (`name`, `note`, `time`, `rpe`, `ExerciseSets`) behave normally.

---

## 16. Settings — "Apple Health" Section

Separated from other Settings groups by FortiFitDivider. Section header: **Apple Health**.

### Contents

| Element | Behavior |
|---|---|
| Toggle: "Connect to Apple Health" | Controls app-level enable/disable. Flipping on triggers iOS authorization prompt (first time only). Flipping off stops all sync but retains existing linked workouts. |
| Description (below toggle) | "Import Apple Fitness workouts and sleep data from Apple Health." |
| Status line | Muted text below description. See states table below. |
| "Sync Now" button | Visible only when toggle is on AND authorization is granted. Triggers immediate `importPendingWorkouts()`. |
| "Open iOS Settings" button | Visible only when toggle is on AND authorization is denied. Deep-links via `UIApplication.openSettingsURLString`. |

### Four Possible States

| Toggle | iOS Auth | Status Line | Buttons |
|---|---|---|---|
| Off | (any) | — (no status) | — |
| On | Granted | "Connected · last sync {relative time}" or "Connected · never synced yet" | Sync Now |
| On | Denied | "Permission denied in iOS Settings" | Open iOS Settings |
| On | Not yet requested | (transient — prompt fires immediately on toggle-on) | — |

### Toggle-Off Behavior
Existing HK-linked workouts **remain linked**. `healthKitUUID` and related fields are retained. No cleanup, no cascade. Catch-up anchor is preserved.

**Rationale:** toggling off may be temporary. Auto-unlinking a month of workouts on toggle-off would be destructive.

### SCREENS.md
Update `SCREENS.md § Settings` to include the Apple Health section layout.

---

## 17. Authorization

### Info.plist Requirements
- `NSHealthShareUsageDescription` — required. Copy must be specific enough for App Store review and must mention activity rings (Stand-hour and daily-summary access) **and sleep** (Phase 11). Current copy: *"FitNavi reads your workouts, sleep, and activity data from Apple Health to give you context-aware recovery insights, training load scores, and activity rings visualization."* Update before release if scope expands.
- `NSHealthUpdateUsageDescription` — NOT included. Not needed; write-back is out of scope.

### Entitlement
HealthKit capability added to the target.

### Read Permission List (requested at first enable)

| Type | iOS | Notes |
|---|---|---|
| `HKWorkoutType` | 17+ | Per-workout reads. |
| `HKQuantityTypeIdentifierHeartRate` | 17+ | Per-workout. |
| `HKQuantityTypeIdentifierActiveEnergyBurned` | 17+ | Used both per-workout (existing) and as a daily-summary source for the Activity Rings widget's Move ring (see § 20 Activity Rings Daily Summary). |
| `HKQuantityTypeIdentifierBasalEnergyBurned` | 17+ | Per-workout. |
| `HKQuantityTypeIdentifierDistanceWalkingRunning` | 17+ | Per-workout. |
| `HKQuantityTypeIdentifierDistanceCycling` | 17+ | Per-workout. |
| `HKQuantityTypeIdentifierDistanceSwimming` | 17+ | Per-workout. |
| `HKQuantityTypeIdentifierFlightsClimbed` | 17+ | Per-workout. |
| `HKQuantityTypeIdentifierAppleExerciseTime` | 17+ | Used both per-workout (existing) and as a daily-summary source for the Activity Rings widget's Exercise ring. |
| `HKCategoryTypeIdentifierAppleStandHour` | 17+ | Daily-summary source for the Activity Rings widget's Stand ring (see § 20). Stored as a category type, not a quantity type — count distinct hours where `value == .stood` for the day. |
| `HKCategoryTypeIdentifierSleepAnalysis` | 17+ | **Phase 11.** Sleep stage samples (`.asleepDeep`, `.asleepREM`, `.asleepCore`, `.asleepUnspecified`, `.awake`, `.inBed`). Read for any HK source (Apple Watch, Oura, Whoop, AutoSleep, etc.). Aggregated by `RecoveryStatusService` into `DailySleepSnapshot` records on the 6pm-to-6pm wake-up-date window (see § 21). |
| `HKQuantityTypeIdentifierWorkoutEffortScore` | 18+ (gated) | Per-workout. |

> **Removed (BUG-048):** earlier revisions of this section listed `HKCharacteristicTypeIdentifierSleepDurationGoal` as a Phase 11 read type. That characteristic does not exist in HealthKit's public API — the only characteristic identifiers Apple exposes are `activityMoveMode`, `biologicalSex`, `bloodType`, `dateOfBirth`, `fitzpatrickSkinType`, and `wheelchairUse`. Apple's "Sleep Schedule" feature stores sleep goals internally but is not reachable through HealthKit reads. The Import from Apple Health button in the Recovery Status Settings Modal therefore always emits the "No sleep goal set in Apple Health." toast in this build; see § 21 → Apple Health sleep goal import.

`typesToShare` is an empty set. Only `typesToRead` is populated.

**Auth scope expansion note (Phase 8.6 Activity Rings):** Adding `HKCategoryTypeIdentifierAppleStandHour` plus broadening the read intent for `ActiveEnergyBurned` and `AppleExerciseTime` to daily-summary use means users who previously granted permission for the workout-only scope will be re-prompted on first launch of the build that ships the Activity Rings widget. Acceptable in a pre-launch product. Once the app ships, any future scope expansion will need a more careful migration plan (HK does not allow programmatic re-prompts; users must visit iOS Settings → Privacy → Health → FitNavi to grant new types).

**Auth scope expansion note (Phase 11 Sleep):** Adding `HKCategoryTypeIdentifierSleepAnalysis` triggers a fresh iOS authorization prompt on the first launch of the build that ships the Recovery Status widget. Sleep is treated as an opt-in scope: if the user denies, the Recovery Status widget renders its Sleep Access Denied gating state (see SCREENS.md § Home Screen → Recovery Status → States) with an in-card CTA that deep-links to iOS Settings via `UIApplication.openSettingsURLString`. Same iOS constraint applies: any post-launch scope expansion requires a manual user visit to iOS Settings → Privacy → Health → FitNavi.

### Denial Handling
HealthKit authorization is one-shot and opaque. FitNavi cannot re-prompt programmatically. Denial path surfaces via the Settings "Open iOS Settings" deep link.

**Read denial is indistinguishable from empty data.** FitNavi treats "no HK workouts found" uniformly regardless of cause. The Settings status line is the only place denial status is surfaced.

---

## 18. Platform and Migration

### Platform
- iOS 17+ minimum (unchanged).
- `workoutEffortScore` gated `if #available(iOS 18, *)`. iOS 17 users get everything else.

### Sprints → Cardio Migration
Runs once on first launch post-update:
1. Fetch all `Workout` records with `workoutType == "Sprints"`.
2. Rewrite each to `workoutType = "Cardio"`. Bump `lastModifiedDate = .now`.
3. Fetch the `WorkoutTypeOrder` record for "Sprints". If Cardio already has a record, delete the Sprints record. If Cardio does not, repoint the Sprints record to `workoutType = "Cardio"`.
4. Set a UserDefaults flag `hasMigratedSprintsToCardio = true`. Do not re-run.

Idempotent. Safe to run on a database with no Sprints records.

---

## 19. Testing Strategy

See TESTING.md for target structure and conventions.

### Protocol Stubbing
`HealthKitClient` is a protocol. Tests inject a `StubHealthKitClient` that returns fixture `HKWorkout`-equivalent data structures. No real HealthKit calls in tests.

### Test Distribution

| Target | Scenarios |
|---|---|
| `FortiFitTests` (unit) | HK-to-category mapping table correctness. `WorkoutMatcher` time-window rules in isolation. Field ownership rule application. Default field value construction on auto-create. |
| `FortiFitIntegrationTests` | Full auto-create → Workout Cascade (Training Load, goals, streak update). Link flow via both entry points (HK-side and manual-side). Upstream delete → null-out behavior. Rejection persistence. `workoutEffortScore` nil-fill under iOS 18+. Sprints migration. |
| `FortiFitUITests` | Settings section toggle + status states. Workout Detail source indicator + info sheet. Unlink via both entry points (ellipsis menu, info sheet). Match Prompt Sheet Link / Keep Separate / Decide Later. Log Workout read-only fields + inline `info.circle` popovers. |

### Untestable (Requires Manual QA)
- Real HK observer query wake-up from background
- Background refresh task execution
- iOS authorization prompt UX
- `workoutEffortScore` API on real iOS 18 device

### Accessibility Identifiers
Add to `AccessibilityIdentifiers.swift`:
- `settings_appleHealthToggle`
- `settings_appleHealthSyncNowButton`
- `settings_appleHealthOpenSettingsButton`
- `workoutDetail_healthSourceIndicator`
- `workoutDetail_healthUnlinkButton`
- `logWorkout_durationReadOnlyHelper`
- `logWorkout_distanceReadOnlyHelper`
- `logWorkout_dateReadOnlyHelper`
- `matchPromptSheet_linkButton`
- `matchPromptSheet_keepSeparateButton`
- `matchPromptSheet_decideLaterButton`

---

## 20. Activity Rings Daily Summary

The Activity Rings widget (see SCREENS.md § Home Screen → Activity Rings widget, SERVICES.md § AppleActivityService) requires daily totals for Move, Exercise, and Stand on top of the per-workout HK reads Phase 8 already does. This section documents the read patterns and the Apple Watch source-detection helper that gates the widget's empty states.

### Daily Totals — Three Read Patterns

`HealthKitClient` exposes the following methods (concrete signatures finalized by Claude Code):

**`fetchActivitySummary(for date: Date) -> HKActivitySummary?`** — preferred path. Wraps `HKActivitySummaryQuery` for a single calendar day (00:00:00–23:59:59 in the user's local time zone). Returns the summary record Apple maintains for the day; this single object exposes Move (`activeEnergyBurned`), Exercise (`appleExerciseTime`), Stand hours (`appleStandHours`), plus the user's **current Apple Health goals** for each ring (`activeEnergyBurnedGoal`, `appleExerciseTimeGoal`, `appleStandHoursGoal`). Used both for live ring values and for first-config goal import.

**`fetchActivitySummaries(from start: Date, to end: Date) -> [HKActivitySummary]`** — range version. Used by the Activity Detail Sheet's 7-day and 30-day breakdowns and by the weekly closure rate chip on the widget. Returns one summary per day in the inclusive range; days with no summary are returned as nil (caller treats as 0).

**`observeActivitySummaryChanges(handler: @escaping () -> Void)`** — register an observer for activity-summary changes. Fires when HK's daily summary updates (e.g., the Watch pushes a new minute of Exercise time). Handler hops to `@MainActor` before any SwiftData work. Same pattern as the existing `observeWorkoutChanges` (see § 9 Sync Lifecycle).

### Apple Watch Source-Detection Helper

`HealthKitClient.hasAppleWatchData(within days: Int = 7) -> Bool` — returns true if any HK sample sourced from an Apple Watch (i.e., `HKSource.bundleIdentifier` matches Apple's Watch source pattern) exists within the lookback window. Used by the Activity Rings widget to decide between its three dynamic states (see SCREENS.md § Home Screen → Activity Rings widget, States table). Implementation queries a cheap aggregate over `HKQuantityTypeIdentifierActiveEnergyBurned` filtered by source predicate and returns true on the first match.

This helper does **not** gate the Add Widgets menu — the widget is always offered. It only drives the in-card empty-state messaging post-add.

### First-Config Goal Import

When the user adds the Activity Rings widget for the first time, `AppleActivityService.importGoalsFromAppleHealth()` runs (see SERVICES.md). The flow:
1. Call `fetchActivitySummary(for: .now)`.
2. If the returned summary's `*Goal` fields are non-zero, write them into `UserSettings.targetMoveCalories`, `targetExerciseMinutes`, `targetStandHours` respectively (rounded to the slider's increment — 10 cal / 5 min / 1 hr).
3. If HK returns no summary or the goals are zero (user has not configured Apple Health goals), fall back to FitNavi defaults: 500 cal / 30 min / 12 hours.

The "Import from Apple Health" button in the Activity Rings Settings Modal re-runs this flow on demand (overwriting whatever the user has set in FitNavi).

### Refresh Triggers

The Activity Rings widget refreshes on:
- App foreground (existing HK catch-up sync — § 9).
- The new activity-summary observer query firing.
- The Workout Cascade — but **only** when the saved/edited/imported workout has `healthKitUUID != nil`. A purely manual log without HK linkage cannot have changed any HK-side daily total, so the cascade skips the activity-rings refresh hook for those. See SERVICES.md § Workout Cascade for the gate.

Local midnight is the day boundary. At rollover, the widget refetches and renders 0/goal across all three rings until movement registers.

---

## 21. Sleep Data (Phase 11)

The Recovery Status widget (see SCREENS.md § Home Screen → Recovery Status widget, SERVICES.md § RecoveryStatusService) requires sleep stage samples and an aggregated daily snapshot on top of the workout and activity-summary reads that Phases 8 and 8.6 already do. This section documents the read patterns, the wake-up-date attribution window, the persistence shape, and the refresh triggers. Algorithm formulas (sleep factor, per-workout contribution, deep-sleep percent, efficiency, correlation) live in SERVICES.md § Training Load Algorithm → Sleep-Adjusted Decay and § RecoveryStatusService.

### Sleep Session Definition

Sum durations of `.asleep*` samples only: `.asleepDeep`, `.asleepREM`, `.asleepCore`, `.asleepUnspecified`. Exclude `.inBed` (time in bed ≠ time asleep) and `.awake` (not sleep). `.inBed` samples are still consumed separately for the sleep efficiency calculation. `.awake` samples within the window are tracked for the stages bar in the Recovery Status Detail Sheet.

### Wake-Up Date Attribution — 6pm-to-6pm Window

Sleep is attributed to the **wake-up date**, not the bedtime date. The window for "today's sleep" is 6pm yesterday through 6pm today (local time). Matches the Apple Health app's convention and handles night-shift cases sensibly (a session ending 4pm belongs to today, since it ends before the 6pm boundary).

All `.asleep*` samples ending within the wake-up window are summed, including daytime naps. A 30-minute afternoon nap + an 8-hour overnight session = 8.5 hours total sleep for the wake-up day. The widget hero label is `SLEEP` (not `LAST NIGHT`) — accurate even with naps in the total.

### Sleep Source Filtering

Accept any HK source. No source filtering. Apple Watch, Oura Ring, Whoop, AutoSleep, etc., all contribute.

The original Apple Watch-only `appleWatchDetected` gating used by the Activity Rings widget is **not** reused for sleep. The Recovery Status widget's gating uses `hasRecentSleepData` instead:

```
hasRecentSleepData = HK has any .asleep* sample in the last 14 days
```

14-day window: long enough to handle short device breaks, short enough to detect "user stopped tracking" and degrade to the No Sleep Tracker state (see SCREENS.md § Home Screen → Recovery Status → States).

### `DefaultHealthKitClient` Sleep Methods

`HealthKitClient` exposes the following methods (concrete signatures finalized by Claude Code; see SERVICES.md § HealthKitClient):

**`fetchSleepSamples(from start: Date, to end: Date) async -> [HKCategorySample]`** — anchored query for `HKCategoryTypeIdentifierSleepAnalysis` samples in the range. Used by `RecoveryStatusService` for catch-up on launch and to populate the 30-day cache. Returns all stage values (`.asleep*`, `.awake`, `.inBed`) so the consumer can compute durations, efficiency, and the stages bar.

**`observeSleepChanges(handler: @escaping () -> Void)`** — registers an `HKObserverQuery` for `HKCategoryTypeIdentifierSleepAnalysis` with `enableBackgroundDelivery`. Fires when HK writes new sleep samples (typically Apple Watch syncs in the morning, or a third-party sleep tracker pushes overnight). Handler hops to `@MainActor` before any SwiftData work. Same pattern as the existing `observeWorkoutChanges` (see § 9 Sync Lifecycle).

**`fetchSleepDurationGoal() async -> TimeInterval?`** — protocol method retained for forward compatibility, but the underlying HealthKit characteristic does not exist (BUG-048). Always returns `nil` in the current build. Called only from the "Import from Apple Health" action in the Recovery Status Settings Modal; the consumer (`RecoveryStatusService.importSleepGoalFromAppleHealth()`) surfaces the documented "No sleep goal set in Apple Health." toast on every call.

### `HealthKitSyncService` — Sleep Observer + Background Refresh

`HealthKitSyncService` (see SERVICES.md § HealthKitSyncService) gains:

- A sleep observer subscription registered alongside the existing workout observer at app launch (when `healthKitEnabled == true` AND sleep scope granted).
- An expanded `BGAppRefreshTask` scope so background fires also refresh sleep data. The single task identifier is preserved — the handler now imports both pending workouts AND pending sleep samples. Allows Apple Watch sleep to sync overnight so morning app opens have fresh data without a spinner.
- A 6pm-cutoff catch-up trigger: the first `scenePhase == .active` after local 6pm refreshes sleep regardless of observer activity, to bridge any missed background fires.

The Workout Cascade is unchanged. Sleep refresh runs through a separate **Sleep Cascade** documented in SERVICES.md § Sleep Cascade.

### `DailySleepSnapshot` Persistence

Schema in PRD.md § Data Model. One record per wake-up date, deduplicated by date. Written by `RecoveryStatusService` after each anchored query or observer fire:

1. Aggregate the day's `.asleep*` durations, deep/REM/core/awake breakdowns, optional `.inBed` durations.
2. Compute `sleepEfficiencyPercent` from `inBedMinutes`. When the source writes explicit `.inBed` samples, `inBedMinutes` is the Σ of those samples. When the source omits them (Apple Watch's native sleep tracker on watchOS 9+ — see BUG-059), `inBedMinutes` falls back to `totalSleepMinutes + awakeMinutes` so efficiency surfaces for Apple-Watch-only users instead of staying silently nil. Efficiency is nil only when neither path yields data.
3. Upsert by `wakeUpDate` — overwrite existing snapshot if HK returned new samples for that day (e.g., a delayed Watch sync).
4. Bump `capturedDate = .now`.
5. Fire the Sleep Cascade (see SERVICES.md § Sleep Cascade) — refreshes the Recovery Status widget; if linked to Training Load, recomputes today's TL score on the sleep-adjusted path and rewrites today's `DailyTrainingLoadSnapshot`.

The service also maintains a rolling **30-day in-memory cache** of these snapshots so the Recovery Status Detail Sheet's sparkline + last-7-nights stat row render without on-demand HK queries.

### Refresh Triggers

The Recovery Status widget and detail sheet refresh on:

| Trigger | Behavior |
|---|---|
| App launch | Anchored sleep query for new samples since `UserSettings.healthKitAnchor`; rebuild 30-day cache from `DailySleepSnapshot` store. |
| Sleep observer query fires | Refresh today's snapshot, append to cache, fire Sleep Cascade. |
| 6pm-cutoff first foreground | Catch-up sleep refresh regardless of observer activity. |
| `BGAppRefreshTask` handler | Same as observer fire — refresh today's snapshot if new samples present. |
| Workout Cascade (HK-linked workout only) | No sleep refetch; only the time-since-last-workout timer line is bumped. |
| Local midnight rollover | Roll the wake-up day forward; the previous day's snapshot becomes historical. |

### Sleep Cascade

A separate cascade from the Workout Cascade because the inputs and consumers differ. Documented in SERVICES.md § Sleep Cascade. Summary:

1. Refresh the Recovery Status widget's view-model (hero value, deep caption, no-sleep-last-night sub-state detection).
2. If the widget is linked to Training Load (`HomeWidgetService.isLinkedActive(widgets:settings:) == true`), recompute today's TL score on the sleep-adjusted path (SERVICES.md § Training Load Algorithm → Sleep-Adjusted Decay) and overwrite today's `DailyTrainingLoadSnapshot`.
3. If a detail sheet (unlinked OR linked) is currently presented, the sheet's service publisher emits — sleep sparkline, stages bar, comparison band, correlation callout, and personal insights all update live.
4. Debounce across all triggers: 500ms.

### Known Failure Modes (documented, no UI)

- Apple Watch user keeps the Watch off the wrist overnight → no `.asleep*` samples → Live state degrades to the **no-sleep-last-night sub-state** (hero shows `— h —m`, deep caption reads `NO DATA`, timer line and watermark render normally). See SCREENS.md § Home Screen → Recovery Status widget → no-sleep-last-night sub-state.
- Source emits stage samples but no `.inBed` (the Apple Watch native sleep tracker case, plus some third-party apps) → `inBedMinutes` falls back to `totalSleepMinutes + awakeMinutes` so `sleepEfficiencyPercent` is computed and the detail-sheet caption renders. Per BUG-059.
- User force-quit FitNavi → background delivery does not fire. 6pm-cutoff catch-up on next foreground recovers.
- User disabled Background App Refresh at OS level → sleep imports only during foreground (anchored query on launch + 6pm-cutoff trigger).

---

## 22. Future Phases (Scope-Only)

### Phase 10: Biometrics
**Net-new entity:** `DailyBiometricSnapshot` (one record per calendar day). Fields include derived values: resting HR, HRV avg, body weight, VO₂ max, etc.

**Pattern:** mirror daily summaries into SwiftData; query HK live for intra-day detail if UI needs it. One snapshot per day, generated via background delivery or foreground catch-up.

**No Phase 1 constraints.** Schema is net-new. Permission additions are additive (user sees a second iOS prompt when Phase 10 enables new types).

### Phase 12+ (Possible): Write-Back
Deferred indefinitely. Revisit requires: `NSHealthUpdateUsageDescription`, extended authorization request with `typesToShare`, active energy estimation for manual workouts, delete/edit propagation added to Workout Cascade, retroactive-write decision.
