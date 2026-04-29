# HEALTHKIT.md: FortiFit HealthKit Integration

> Authoritative spec for HealthKit integration. Cross-references PRD.md, SERVICES.md, SCREENS.md, CONSTANTS.md, and TESTING.md for domain-specific details rather than duplicating them.
> For data models, see `PRD.md` § Data Model. For service implementations, see `SERVICES.md`. For UI layouts, see `SCREENS.md`. For static tables, see `CONSTANTS.md`.

---

## 1. Overview

HealthKit integration lets FortiFit import workouts recorded on Apple Watch (or any Health-connected source — Peloton, Strava, Garmin, etc.) and reconcile them against FortiFit's own records. It is **read-only in MVP**. FortiFit does not write to HealthKit under any circumstance.

The product intent: a user records a workout on Apple Watch, opens FortiFit, and sees the workout already logged — ready for them to add exercise sets, RPE, and notes.

---

## 2. Scope

### In Scope (MVP — Phases 1+2 ship together)
- Workout import (auto-create new records when no FortiFit match exists)
- Dedup and linking (match incoming HK workouts against existing FortiFit records; bidirectional matcher)
- Background sync (observer queries + background refresh)
- Catch-up sync on launch (anchored queries)
- Upstream delete handling (promote to manual)
- Upstream update handling (HK wins on HK-owned fields)
- UI surfaces: Workout Detail source indicator + info sheet, peripheral glyphs, Log Workout read-only fields, Workout Detail Summary two-column grid (HK-linked), Settings "Apple Health" section
- iOS 18+ `workoutEffortScore` import into `rpe` (nil-fill only)

### Explicitly Out of Scope (MVP)
- **Write-back** (FortiFit → HealthKit). Deferred indefinitely. See § 20.
- **Biometrics** (resting HR, HRV, body weight, VO₂ max, etc.). Deferred to Phase 3. See § 20.
- **Sleep data**. Deferred to Phase 4. See § 20.
- **GPS / route data**. Not loaded, not stored.
- **User-configurable HK-to-FortiFit type mapping**. Static table only.
- **`estimatedWorkoutEffortScore`**. Ignored entirely; only user-entered `workoutEffortScore` imports.
- **Sync diagnostics UI** (sample counts, per-type breakdowns, etc.)

---

## 3. Phases

HealthKit integration is **Phase 8** in the FortiFit development roadmap (see CLAUDE.md § Development Phases). Launch Prep shifts from Phase 8 to Phase 9.

Phases 1 and 2 below ship together as a single Claude Code implementation pass. They are separated conceptually so the test matrix and integration-test cascade are easier to reason about, but there is no user-facing release between them.

### Phase 1: Foundation + Workout Import

**Goal:** Authorization flow works. Workouts recorded on Apple Watch (or any Health-connected source) are auto-created in FortiFit on app launch or foreground. Linking works bidirectionally. UI surfaces the HealthKit relationship. Settings section is functional.

| Feature | Where to find spec |
|---|---|
| `HealthKitClient` protocol + `DefaultHealthKitClient` concrete | § 4 Architecture Decisions, § 19 Testing Strategy |
| New `Workout` fields (10 optional) | § 5 Data Model; PRD.md § Data Model |
| `WorkoutMatchRejection` entity | § 5 Data Model; PRD.md § Data Model |
| HK-to-FortiFit type mapping table | § 6 Workout Type Taxonomy; CONSTANTS.md § HealthKit Mapping |
| Sprints → Cardio one-time migration | § 18 Platform and Migration |
| Field ownership rules (HK-owned vs user-owned) | § 7 Field Ownership |
| Log Workout read-only fields + helper text | § 7 Field Ownership; § 15 UI Surfaces; SCREENS.md § Log Workout |
| `workoutEffortScore` import (iOS 18+ gated) | § 8 Effort Score |
| `HealthKitSyncService` with `HKAnchoredObjectQuery` catch-up on launch/foreground | § 9 Sync Lifecycle |
| Persisted `HKQueryAnchor` (UserDefaults-serialized Data) | § 9 Sync Lifecycle |
| Auto-create flow + 2-minute minimum-duration floor | § 10 Auto-Create Flow |
| Upstream delete handling (promote to manual, null out pointer) | § 11 Upstream Updates and Deletes |
| Upstream update handling (HK wins on HK-owned fields) | § 11 Upstream Updates and Deletes |
| `WorkoutMatcher` service (bidirectional, tiered confidence) | § 12 Deduplication |
| Match Prompt Sheet (sheet-on-foreground) | § 13 Prompt UX; SCREENS.md § Match Prompt Sheet |
| Unlink action (three entry points) | § 14 Unlink |
| Workout Detail source indicator + info sheet | § 15 UI Surfaces; SCREENS.md § Workout Detail |
| Workout Detail Summary two-column grid (HK-linked) | § 15 UI Surfaces; SCREENS.md § Workout Detail |
| Peripheral HK glyph on Home / Workouts / Plan | § 15 UI Surfaces; SCREENS.md § Home, § Workouts, § Plan |
| Settings "Apple Health" section (toggle, status line, Sync Now, deep link) | § 16 Settings; SCREENS.md § Settings |
| Authorization flow + Info.plist `NSHealthShareUsageDescription` | § 17 Authorization |
| Accessibility identifiers for all new interactive elements | § 19 Testing Strategy; TESTING.md |
| Unit tests (`FortiFitTests`): HK-to-category mapping, matcher rules, field ownership, auto-create defaults | § 19 Testing Strategy |
| Integration tests (`FortiFitIntegrationTests`): auto-create cascade, link flow (both directions), upstream delete, rejection persistence, effort score nil-fill, Sprints migration | § 19 Testing Strategy |
| UI smoke tests (`FortiFitUITests`): Settings section states, Workout Detail source indicator + info sheet, unlink flow, Match Prompt Sheet actions, Log Workout read-only helper text | § 19 Testing Strategy |

### Phase 2: Ongoing Sync (Background Delivery)

**Goal:** Workouts recorded on Apple Watch appear in FortiFit without the user having to open the app. Phase 1's catch-up-on-launch is augmented with live background sync.

| Feature | Where to find spec |
|---|---|
| `HKObserverQuery` with `enableBackgroundDelivery` | § 9 Sync Lifecycle |
| `BGAppRefreshTask` registration + handler | § 9 Sync Lifecycle |
| Deleted-object handler wired into anchored query | § 9 Sync Lifecycle; § 11 Upstream Updates and Deletes |
| Threading: `@MainActor` marshaling in sync service | § 4 Architecture Decisions; § 9 Sync Lifecycle |
| Manual QA: background wake, anchor persistence, force-quit recovery | § 19 Testing Strategy |

### What's Explicitly Out of Both Phases

See § 2 Scope → Explicitly Out of Scope. Biometrics (future Phase 10), sleep (future Phase 11), and write-back (future Phase 12+) are separate implementation passes with their own future specs. See § 20 Future Phases for shape-level descriptions.

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
FortiFit never writes to HealthKit. `typesToShare` is an empty set in the authorization request. `NSHealthUpdateUsageDescription` is not included in Info.plist.

**Consequence:** manually logged FortiFit workouts do not contribute to the Apple Move/Exercise rings. Accepted tradeoff.

---

## 5. Data Model

### New `Workout` Fields (all optional)

| Field | Type | Notes |
|---|---|---|
| `healthKitUUID` | UUID? | Pointer to source HK workout. Nil = manual. |
| `healthKitSourceBundleID` | String? | Bundle ID of the writing app (e.g., `com.apple.health.WatchApp`). Used only for display via `HKSource.name`. |
| `healthKitActivityType` | String? | Friendly display string (e.g., "Traditional Strength Training"). |
| `avgHeartRate` | Int? | bpm |
| `maxHeartRate` | Int? | bpm |
| `activeEnergyKcal` | Double? | Active calories only (Move ring metric) |
| `totalEnergyBurnedKcal` | Double? | Active + basal combined |
| `elevationAscendedMeters` | Double? | Outdoor workouts only |
| `exerciseMinutes` | Int? | Apple Exercise ring credit. Differs from `durationMinutes`. |
| `indoor` | Bool? | Metadata flag |

See PRD.md § Data Model for the full `Workout` schema. Add these 10 fields to the existing table.

### New Entity: `WorkoutMatchRejection`

| Property | Type | Required | Notes |
|---|---|---|---|
| `id` | UUID | Yes | Auto-generated |
| `healthKitUUID` | UUID | Yes | The HK workout rejected |
| `workoutId` | UUID | Yes | The FortiFit workout it was rejected against |
| `rejectedDate` | Date | Yes | Set to `.now` on creation |

Standalone. No `@Relationship` to `Workout`. Lookup by UUID pair. Orphan records (when a linked `Workout` is deleted) are harmless and remain. No cleanup logic in MVP.

---

## 6. Workout Type Taxonomy

### Six FortiFit Types (Sprints removed)
Strength Training, HIIT, Cardio, Yoga, Pilates, **Other**.

"Other" is the catch-all for HK types without a clean category match (e.g., Kickboxing, Tai Chi, Dance, Rock Climbing) and serves as forward-compatibility for new HK types introduced by future iOS versions.

### Two-Level Categorization
- **FortiFit `workoutType`** (high-level): drives all algorithms, Workouts-screen organization, goal matching. One of the six types.
- **`healthKitActivityType`** (low-level, display-only): UI specificity. Never consumed by any algorithm.

### HK-to-Category Mapping
Static table in CONSTANTS.md § HealthKit Mapping. Not user-configurable. Claude Code consults this table at import time in `HealthKitSyncService`.

**Rule:** every `HKWorkoutActivityType` currently defined by Apple must have an explicit entry. New types introduced by future iOS versions fall through to "Other" via a default-case fallback in the mapping function.

---

## 7. Field Ownership

### HK-Owned Fields (HK wins on upstream update)
`date` (start time), `durationMinutes`, `distanceKm`, `avgHeartRate`, `maxHeartRate`, `activeEnergyKcal`, `totalEnergyBurnedKcal`, `elevationAscendedMeters`, `exerciseMinutes`, `indoor`, `healthKitActivityType`.

### User-Owned Fields (user always wins; HK never overwrites)
`name`, `note`, `time`, `ExerciseSets`, `rpe`.

### Read-Only Behavior in Log Workout Edit
When `healthKitUUID != nil`, the following fields are disabled (non-editable) in the Log Workout edit view: `durationMinutes`, `distanceKm`, `date` (start time).

Each disabled field renders helper text below it: **"Linked to Apple Health · tap to unlink."** Tap target opens the same info sheet as the Workout Detail source indicator (see § 15), with an "Unlink from Apple Health" button.

To edit these fields, the user must first unlink.

---

## 8. Effort Score (iOS 18+ only)

All effort-score reads are gated `if #available(iOS 18, *)`. iOS 17 users don't receive this sub-feature.

### Rules (Option 2 — nil-fill only)
- **On import:** if `rpe == nil` and HK has a `workoutEffortScore` for this workout, set `rpe = workoutEffortScore`. Otherwise leave `rpe` unchanged.
- **Never overwrite:** if `rpe != nil` (user has set a value in FortiFit), HK `workoutEffortScore` is ignored regardless of whether it changes later.
- **Estimated scores ignored:** `estimatedWorkoutEffortScore` is never imported. Only user-entered `workoutEffortScore` contributes.

### API Mechanics
`workoutEffortScore` is NOT a property on `HKWorkout`. It is a separate `HKQuantitySample` queried via `HKSampleQuery` and related to the workout via `relateWorkoutEffortSample(_:with:activity:)`. Permission is requested separately as `HKQuantityType(.workoutEffortScore)`.

---

## 9. Sync Lifecycle

### Three Layers

| Layer | Purpose | When It Runs |
|---|---|---|
| `HKObserverQuery` w/ `enableBackgroundDelivery` | Live sync | HK writes a new workout; iOS wakes FortiFit |
| `BGAppRefreshTask` | Belt-and-suspenders | Periodically, when iOS permits |
| `HKAnchoredObjectQuery` catch-up | Mandatory backstop | Every cold launch and foreground |

All three converge on the same entry point: `HealthKitSyncService.importPendingWorkouts()`.

### Anchor Persistence
`HKQueryAnchor` is persisted to UserDefaults (serialized `Data`). Every successful anchored query updates the anchor. Catch-up on launch uses the persisted anchor as the "since" marker.

### Deleted-Object Handler
Anchored queries MUST wire the `deletedObjectHandler`. Without it, HK-side deletions never reach FortiFit. See § 11 for behavior.

### Known Failure Modes (documented, no UI)
- User force-quit FortiFit → background delivery does not fire. Catch-up on next launch recovers.
- User disabled Background App Refresh at OS level → imports only during foreground. Catch-up on launch still runs.

---

## 10. Auto-Create Flow

Happy path: HK workout arrives, no matching FortiFit record exists (after `WorkoutMatcher` runs), create a new first-class `Workout`.

### Minimum-Duration Floor
HK workouts under **2 minutes** are skipped entirely. No FortiFit record created. Not added to the matching pool.

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
1. Find the FortiFit `Workout` with matching `healthKitUUID`.
2. Clear `healthKitUUID`, `healthKitSourceBundleID`, `healthKitActivityType` (set to nil).
3. Retain all HK-sourced measurement values as-is. The record is now a manual workout.
4. Bump `lastModifiedDate` to `.now`. This re-scopes the workout against any goal `resetDate` (see SERVICES.md § Goal Auto-Update → Reset Scoping).
5. **Do NOT fire the deletion cascade.** This is not a deletion.

**Rationale:** conservative, non-destructive. User retains their training history even if they clean up the Health app. Accepts that FortiFit data may diverge from HealthKit after this point.

---

## 12. Deduplication (`WorkoutMatcher`)

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
1. Populate `healthKitUUID`, `healthKitSourceBundleID`, `healthKitActivityType` on the FortiFit `Workout`.
2. Apply HK-owned field values from the HK record (overwrites prior FortiFit values for HK-owned fields only).
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
  - Right column (FortiFit workout): name, `workoutType`, RPE, ExerciseSets count, notes preview
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

### Three Entry Points
1. Workout Detail ellipsis menu → "Unlink from Apple Health" (visible only when `healthKitUUID != nil`)
2. Source indicator info sheet → "Unlink from Apple Health" button
3. Log Workout edit view → disabled field helper text "tap to unlink" → opens info sheet → unlink button

### On Unlink
1. Clear `healthKitUUID`, `healthKitSourceBundleID`, `healthKitActivityType` (set to nil).
2. Retain all HK-sourced numeric values (duration, distance, HR, calories, elevation, etc.) as-is — they become regular editable fields on a now-manual workout.
3. Bump `lastModifiedDate` to `.now`.
4. Re-add the HK workout UUID to the matching pool. (On next sync or next manual log, matcher may re-propose the pairing. If user rejected it, they would need a rejection record — but unlink does not create one automatically. If they want to prevent re-proposal, they resolve the next prompt with "Keep separate.")
5. Do NOT fire the deletion cascade.

---

## 15. UI Surfaces

### Workout Detail Source Indicator
Below the Workout Type row, when `workout.healthKitUUID != nil`. Format: `{healthKitActivityType} · {sourceName} [glyph]` — the word "from" is implied by the format and is not rendered. Glyph trails the source name **only when source is Apple Watch**.

- Source name resolved via `HealthKitClient.sourceName(for:)` per SERVICES.md § HealthKitClient. Apple Watch → `Apple Workout`; other recognized sources keep their `HKSource.name`; unresolvable bundle IDs fall back to `another app`. Never displays a raw bundle ID.
- Trailing glyph: `FortiFitHealthGlyph` (Apple Workout running figure on green) — renders only when source is Apple Watch. Other sources show no trailing glyph.
- Styled as secondary/muted text using the app's Label treatment (11px, 700 weight, 2px letter-spacing, Muted Text color).
- Tappable → opens info sheet.

Full layout spec lives in SCREENS.md § Workout Detail → Source Indicator.

### Source Indicator Info Sheet
- Body explainer: `This workout was imported from Apple Health via {sourceName}.` `{sourceName}` resolves via `HealthKitClient.sourceName(for:)` — Apple Watch becomes `Apple Workout`, other known sources show their `HKSource.name`, unresolvable bundle IDs fall back to `another app`. Never renders a raw bundle ID.
- Full `healthKitActivityType` displayed prominently.
- Source row also uses `{sourceName}` (same resolver).
- "Unlink from Apple Health" button.
- Dismiss.

Full layout spec lives in SCREENS.md § Workout Detail → Source Indicator Info Sheet.

### Workout Detail Summary — Stat Card Grid (Phase 8.5)

Workout Detail Summary renders as a **2-column grid of bordered, tappable stat cards**, regardless of whether the workout is HK-linked. HK-imported measurement fields (Avg HR, Max HR, Active kcal, Total kcal, Elevation Ascended, Exercise Minutes) render as additional stat cards alongside user-entered fields (Effort, Duration, Distance) — same field structure, same visual treatment. Manual workouts collapse to 2–3 cards naturally; HK-linked workouts can show up to 9.

**Indoor/Outdoor: removed** from Summary entirely.

Each card is independently tappable and opens the **Metric Detail Sheet** (per-metric comparative average + 30-day sparkline + optional Personal Best chip). The detail sheet's data layer is `WorkoutMetricService` (see SERVICES.md § WorkoutMetricService).

**Units** respect user preferences: `elevationAscendedMeters` displays as meters or feet per the distance unit setting. HR is always bpm. Calories are always kcal.

Full layout spec (including stat-card structure, field order, per-field display values, and Metric Detail Sheet behavior) is in SCREENS.md § Workout Detail → Summary and § Workout Detail → Metric Detail Sheet.

### Peripheral Glyph (Apple Workout)
The Apple Workout glyph (`FortiFitHealthGlyph` — running figure on green circular background) renders trailing the metadata row on these surfaces, **only when source is Apple Watch**:
- Recent Workouts list rows (Home)
- Workout Type card preview rows (Workouts tab)
- Scheduled Workout cards / logged-only cards (Plan tab)

Non-Apple-Watch HK sources (Strava, Peloton, etc.) do not render this glyph on peripheral surfaces — they are visually indistinguishable from manual workouts on those compact surfaces. Future updates may add per-source glyphs.

Visible only when `healthKitUUID != nil`. Full "from {source}" label stays on Workout Detail only.

### Log Workout Read-Only Fields
When `healthKitUUID != nil`:
- `durationMinutes`, `distanceKm`, `date` inputs are disabled (visually greyed, non-interactive).
- Helper text below each: "Linked to Apple Health · tap to unlink."
- Helper text is tappable → opens source indicator info sheet.
- All other fields (`name`, `note`, `time`, `rpe`, `ExerciseSets`) behave normally.

---

## 16. Settings — "Apple Health" Section

Separated from other Settings groups by FortiFitDivider. Section header: **Apple Health**.

### Contents

| Element | Behavior |
|---|---|
| Toggle: "Connect to Apple Health" | Controls app-level enable/disable. Flipping on triggers iOS authorization prompt (first time only). Flipping off stops all sync but retains existing linked workouts. |
| Description (below toggle) | "Import workouts from Apple Watch and other Health-connected apps. Linked workouts appear automatically and can't be fully unlinked in bulk." |
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
- `NSHealthShareUsageDescription` — required. Copy: TBD in SCREENS.md. Must be specific enough for App Store review (e.g., "FortiFit uses your Apple Health workout data to automatically log sessions recorded on Apple Watch or other connected apps.")
- `NSHealthUpdateUsageDescription` — NOT included. Not needed; write-back is out of scope.

### Entitlement
HealthKit capability added to the target.

### Read Permission List (requested at first enable)

| Type | iOS |
|---|---|
| `HKWorkoutType` | 17+ |
| `HKQuantityTypeIdentifierHeartRate` | 17+ |
| `HKQuantityTypeIdentifierActiveEnergyBurned` | 17+ |
| `HKQuantityTypeIdentifierBasalEnergyBurned` | 17+ |
| `HKQuantityTypeIdentifierDistanceWalkingRunning` | 17+ |
| `HKQuantityTypeIdentifierDistanceCycling` | 17+ |
| `HKQuantityTypeIdentifierDistanceSwimming` | 17+ |
| `HKQuantityTypeIdentifierFlightsClimbed` | 17+ |
| `HKQuantityTypeIdentifierAppleExerciseTime` | 17+ |
| `HKQuantityTypeIdentifierWorkoutEffortScore` | 18+ (gated) |

`typesToShare` is an empty set. Only `typesToRead` is populated.

### Denial Handling
HealthKit authorization is one-shot and opaque. FortiFit cannot re-prompt programmatically. Denial path surfaces via the Settings "Open iOS Settings" deep link.

**Read denial is indistinguishable from empty data.** FortiFit treats "no HK workouts found" uniformly regardless of cause. The Settings status line is the only place denial status is surfaced.

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
| `FortiFitUITests` | Settings section toggle + status states. Workout Detail source indicator + info sheet. Unlink via all three entry points. Match Prompt Sheet Link / Keep Separate / Decide Later. Log Workout read-only fields + helper text. |

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

## 20. Future Phases (Scope-Only)

### Phase 3: Biometrics
**Net-new entity:** `DailyBiometricSnapshot` (one record per calendar day). Fields include derived values: resting HR, HRV avg, body weight, VO₂ max, etc.

**Pattern:** mirror daily summaries into SwiftData; query HK live for intra-day detail if UI needs it. One snapshot per day, generated via background delivery or foreground catch-up.

**No Phase 1 constraints.** Schema is net-new. Permission additions are additive (user sees a second iOS prompt when Phase 3 enables new types).

### Phase 4: Sleep
**Net-new entity:** `DailySleepSnapshot`. Fields: `totalSleepMinutes`, stage breakdowns (deep/REM/core/awake), `sleepStartTime`, `sleepEndTime`, `sleepEfficiencyPercent`.

**Attribution convention:** sleep is attributed to the **wake-up date**, not the bedtime date. Sleep ending Wednesday morning lives on Wednesday's snapshot.

**New UI surfaces required.** Sleep has no current home in FortiFit. Phase 4 requires a dedicated PRD pass for UX (home widget, dedicated screen, or both). Currently listed as "out of scope" in PRD.md § Out of Scope — gets revisited at Phase 4.

**No Phase 1 constraints.**

### Phase 5 (Possible): Write-Back
Deferred indefinitely. Revisit requires: `NSHealthUpdateUsageDescription`, extended authorization request with `typesToShare`, active energy estimation for manual workouts, delete/edit propagation added to Workout Cascade, retroactive-write decision.

---

## 21. Companion Documents Updated for This Feature

| Document | Sections Added or Modified |
|---|---|
| PRD.md | § Data Model (Workout: 10 new fields, new entity WorkoutMatchRejection). § Technical Foundation (HealthKit added, moved out of Out of Scope). § Screen Summaries (Workout Detail Summary becomes a two-column grid for HK-linked workouts; Settings adds Apple Health section). |
| SERVICES.md | New sections: HealthKitClient (protocol), HealthKitSyncService, WorkoutMatcher. Extensions to Workout Cascade (fires on HK import). Field ownership rules. Effort score rules. |
| SCREENS.md | Workout Detail (source indicator + info sheet + Summary two-column grid for HK-linked workouts). Log Workout (read-only fields + helper text). Settings (Apple Health section). New section: Match Prompt Sheet. |
| CONSTANTS.md | New section: HealthKit Mapping (full HK-to-FortiFit type table). New SF Symbol entries. |
| CLAUDE.md | Out of Scope updated (HealthKit read removed, write-back explicitly retained). Development Phases: new "Phase 9: HealthKit Integration" entry (or similar numbering). |
| TESTING.md | New section: HealthKit Test Strategy (protocol stubbing, fixture pattern). New accessibility identifier entries. |

---

## 22. Open Items Deferred to Drafting Time

- Exact Info.plist copy for `NSHealthShareUsageDescription` (SCREENS.md).
- Exact SF Symbol names for each Health Data row (CONSTANTS.md).
- Full `HKWorkoutActivityType` → FortiFit mapping table (CONSTANTS.md — all ~80 entries).
- Final row grouping and ordering for Summary two-column grid right column (SCREENS.md).
- Source indicator info sheet exact copy (SCREENS.md).
- Match Prompt Sheet exact layout and copy (SCREENS.md).
