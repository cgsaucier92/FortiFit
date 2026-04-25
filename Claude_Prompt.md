# Phase 8: HealthKit Integration — Implementation Prompt

You are implementing Phase 8 of FortiFit. This phase covers HealthKit read integration: importing workouts from Apple Watch and other Health-connected sources, deduplicating against existing FortiFit records, and surfacing imported data in the UI. Read-only — FortiFit never writes to HealthKit.

## Required reading (do this before writing any code)

Read these in order. Read each in full.

1. **HEALTHKIT.md** — the authoritative spec for this phase. This is your primary reference. Every other doc you need is cross-referenced from inside it.
2. **CLAUDE.md** — coding conventions, project structure, naming rules, the "do not do" guardrails. If anything in HEALTHKIT.md conflicts with CLAUDE.md, CLAUDE.md wins.

You do **not** need to read PRD.md, SCREENS.md, SERVICES.md, CONSTANTS.md, or TESTING.md upfront. HEALTHKIT.md cross-references the specific sections of each that matter, and you should pull those sections just-in-time when implementing the relevant piece.

## Scope: Phase 1 + Phase 2 together

HEALTHKIT.md § 3 splits this work into two conceptual phases. Implement both in this session — they ship together.

- **Phase 1:** Foundation, workout import, dedup, UI surfaces, Settings, catch-up sync on launch.
- **Phase 2:** Live background delivery (`HKObserverQuery`, `BGAppRefreshTask`).

The Phase 1 / Phase 2 split exists for test-matrix clarity, not as a release boundary. Build everything from both phase tables in HEALTHKIT.md § 3.

## Implementation sequence

Implement in this order. Each step depends on the prior steps. Commit after each step (suggested commit messages below) so the history is reviewable and revertable.

1. **Data model additions.** New `Workout` fields (10 optional), new `WorkoutMatchRejection` entity, new `UserSettings` fields (`healthKitEnabled`, `healthKitAnchor`, `healthKitLastSyncDate`, `hasMigratedSprintsToCardio`). See HEALTHKIT.md § 5 and PRD.md § Data Model. Add to SwiftData schema. Verify the existing app still builds and runs.
   *Commit:* `Phase 8: data model — Workout HK fields, WorkoutMatchRejection, UserSettings additions`

2. **Sprints → Cardio one-time migration.** See HEALTHKIT.md § 18. Runs on first launch post-update; gated by `UserSettings.hasMigratedSprintsToCardio`. Update `AppConstants` workout types: remove "Sprints", add "Other". Update CONSTANTS.md mapping table consumers (Training Load modifier table, SF Symbols, chart colors).
   *Commit:* `Phase 8: Sprints → Cardio migration + Other workout type`

3. **HK-to-FortiFit mapping table.** See CONSTANTS.md § HealthKit Mapping (full 80-row table) and HEALTHKIT.md § 6. Implement as a static lookup function in CONSTANTS or a dedicated `HealthKitTypeMapping.swift`. Default case → "Other" with raw enum name as display string.
   *Commit:* `Phase 8: HK-to-FortiFit workout type mapping`

4. **`HealthKitClient` protocol + `DefaultHealthKitClient` concrete.** See HEALTHKIT.md § 4 and SERVICES.md § HealthKitClient. Define the protocol surface (operations table). Implement `DefaultHealthKitClient` using Apple's HealthKit framework — this is the *only* file allowed to `import HealthKit`. Define `HealthKitWorkoutSnapshot` struct here.
   *Commit:* `Phase 8: HealthKitClient protocol + concrete implementation`

5. **`WorkoutMatcher` service.** See HEALTHKIT.md § 12 and SERVICES.md § WorkoutMatcher. Bidirectional, tiered-confidence matching, rejection-aware. Implement `findMatch(forIncomingHKWorkout:)`, `findMatch(forNewManualWorkout:)`, `applyLink(workout:snapshot:)`, and the prompt queue API.
   *Commit:* `Phase 8: WorkoutMatcher service with bidirectional dedup`

6. **`HealthKitSyncService`.** See HEALTHKIT.md § 9 and SERVICES.md § HealthKitSyncService. Implement the full Import Pipeline (4-step algorithm in SERVICES.md § HealthKitSyncService → Import Pipeline). All ModelContext writes marshal to `@MainActor`. Include both Phase 1 (catch-up on launch + foreground + manual "Sync Now") and Phase 2 (`HKObserverQuery` + `BGAppRefreshTask`) trigger paths.
   *Commit:* `Phase 8: HealthKitSyncService — catch-up, observer queries, background refresh`

7. **WorkoutService extensions.** See SERVICES.md § WorkoutService (updated bullets). Wire the manual-side `WorkoutMatcher.findMatch(forNewManualWorkout:)` call into `log()`. Add `unlink()` method per SERVICES.md § HealthKit Unlink. Existing cascade behavior unchanged.
   *Commit:* `Phase 8: WorkoutService — matcher hook + unlink action`

8. **Effort score handling.** See HEALTHKIT.md § 8. Gate `if #available(iOS 18, *)`. Nil-fill only; never overwrite user-entered RPE; ignore `estimatedWorkoutEffortScore`. Wire into `HealthKitSyncService` post-create/post-link.
   *Commit:* `Phase 8: workoutEffortScore nil-fill (iOS 18+)`

9. **Authorization + Info.plist.** See HEALTHKIT.md § 17. Add HealthKit capability to the app target. Add `NSHealthShareUsageDescription` to Info.plist (do NOT add `NSHealthUpdateUsageDescription` — write-back is out of scope). Implement `requestAuthorization()` in `DefaultHealthKitClient` with the read permission list from § 17.
   *Commit:* `Phase 8: HealthKit authorization + Info.plist`

10. **Settings "Apple Health" section.** See SCREENS.md § Settings → Apple Health Section. Toggle, description, status line, conditional buttons (Sync Now / Open iOS Settings). Four-state state table. Confirmation alert on toggle-off. Use `FortiFitSegmentedToggle` styling consistent with existing General section.
    *Commit:* `Phase 8: Settings — Apple Health section`

11. **Workout Detail surfaces.** See SCREENS.md § Workout Detail (updated). Source indicator row below Workout Type. Source Indicator Info Sheet. Summary two-column grid for HK-linked workouts (left = user-entered, right = HK-imported, conditional rendering). "Unlink from Apple Health" ellipsis menu item. SF Symbols per CONSTANTS.md § Workout Detail Health Data Icons.
    *Commit:* `Phase 8: Workout Detail — source indicator, info sheet, two-column Summary`

12. **Log Workout read-only fields.** See SCREENS.md § Log Workout → Edit Mode — HealthKit-Linked Workouts. Disabled DatePicker, Duration, Distance when `healthKitUUID != nil`. Helper text "Linked to Apple Health · tap to unlink" tappable to open Source Indicator Info Sheet.
    *Commit:* `Phase 8: Log Workout — read-only fields when HK-linked`

13. **Peripheral HK glyph component.** See SCREENS.md § Standard Patterns → Peripheral HealthKit Glyph. Implement `FortiFitHealthGlyph.swift` once. Apply to Home Recent Workouts rows, Workouts tab Expanded Workout Preview Rows, Plan tab logged-only and completed scheduled workout cards (when linked).
    *Commit:* `Phase 8: Peripheral HK glyph on Home, Workouts, Plan`

14. **Match Prompt Sheet.** See SCREENS.md § Match Prompt Sheet (new section) and HEALTHKIT.md § 13. Sheet-on-foreground, side-by-side summary, three actions (Link / Keep Separate / Decide Later). Sequential multi-match handling. Wire to `WorkoutMatcher.pendingMatches()` queue.
    *Commit:* `Phase 8: Match Prompt Sheet`

15. **Accessibility identifiers.** See HEALTHKIT.md § 19 → Accessibility Identifiers and TESTING.md § Accessibility Identifiers. Add all Phase 8 identifiers to `AccessibilityIdentifiers.swift` first, then reference from views and tests. Never hardcode identifier strings.
    *Commit:* `Phase 8: accessibility identifiers`

16. **Unit tests.** See TESTING.md § HealthKit Test Strategy → Test Distribution by Target → `FortiFitTests`. Cover: HK-to-category mapping (every enum case), `WorkoutMatcher` time-window rules in isolation, field ownership rule application, auto-create default field values, 2-minute minimum-duration floor.
    *Commit:* `Phase 8: unit tests`

17. **Integration tests.** See TESTING.md § HealthKit Test Strategy → `FortiFitIntegrationTests`. Cover: auto-create cascade, link flow both directions, upstream delete behavior, `WorkoutMatchRejection` blocks re-proposal, iOS 18 effort score nil-fill, Sprints migration idempotency, unlink behavior. Use `StubHealthKitClient` from `TestFixtures.swift` (which you'll add — see TESTING.md § Shared Test Fixtures for the helpers list including `StubHealthKitClient`, `makeHKWorkoutFixture`, `makeLinkedWorkout`).
    *Commit:* `Phase 8: integration tests + StubHealthKitClient fixture`

18. **UI smoke tests.** See TESTING.md § HealthKit Test Strategy → `FortiFitUITests`. Cover: Settings section state transitions, Workout Detail source indicator + info sheet, unlink via all three entry points, Match Prompt Sheet actions, Log Workout disabled-field helper text. Add to `SmokeTests.swift`.
    *Commit:* `Phase 8: UI smoke tests`

## Done criteria

Before reporting Phase 8 complete, all of the following must be true:

- All three test targets pass: `FortiFitTests`, `FortiFitIntegrationTests`, `FortiFitUITests`. No skipped or disabled tests without a corresponding BUGS.md entry.
- The app compiles cleanly with no warnings introduced by Phase 8 work.
- No `// TODO` or `// FIXME` placeholders remain in shipped code. If something is genuinely unfinished, file it in BUGS.md and note the limitation in code with a reference to the bug ID.
- All accessibility identifiers from HEALTHKIT.md § 19 exist in `AccessibilityIdentifiers.swift` and are referenced by both views and tests.
- The 17 commit-after-each-step messages above are all in `git log` (or equivalent — combining 1-2 small steps into a single commit is fine if they're tightly coupled).

Manual on-device QA is NOT part of the done criteria — that's the user's job after this session ends. The TESTING.md § HealthKit Test Strategy → Requires Manual QA list documents what the user will verify.

## Things to flag back to the user

If you encounter any of these during implementation, stop and ask before proceeding:

- A spec ambiguity in HEALTHKIT.md or any companion doc that has more than one defensible interpretation.
- A circular dependency between two new services that the spec doesn't resolve.
- An existing FortiFit pattern that conflicts with what HEALTHKIT.md asks for (the spec is recent — it's possible something didn't get reconciled).
- A test that you cannot write without importing `HealthKit` directly (TESTING.md § HealthKit Test Strategy → Protocol Stubbing forbids this; if a scenario genuinely requires it, it belongs in manual QA, not automated tests).
- A SwiftData migration concern beyond the simple optional-field additions covered by automatic lightweight migration.

Do not proceed with a guess. Stop and ask.

## You are working on a Git feature branch

The user has created `feature/phase-8-healthkit` off the pre-Phase-8 baseline. Every commit you make lands on this branch. `main` stays frozen at the baseline so the user can do a clean diff at the end. Do not switch branches. Do not modify `main`.

If at any point you believe a destructive Git operation is needed (force-push, reset --hard, branch deletion), stop and ask.

## Begin

Start by reading HEALTHKIT.md and CLAUDE.md. Then proceed with step 1.
