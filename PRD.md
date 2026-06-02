# PRD: FitNavi

> **Purpose:** Single source of truth for the app's overall architecture. For detailed specs, see the companion docs referenced throughout.

---

## 1. Product Overview

### Problem Statement
Most fitness apps don't offer a holistic, all-in-one approach to tracking workouts, nutrition, and mental health.

### Target Users

| Persona | Primary Need |
|---------|-------------|
| Chad (Serious Lifter) | Robust workout tracking for strength milestones |
| Martha (Fitness Mom) | Minimalist logging for workouts, nutrition, and sleep habits |
| Nick (Night Shifter) | Single view connecting recovery, sleep, and training intensity |

### Product Vision
A holistic health app that helps users track and understand the interaction between physical fitness, nutrition, and mental health.

---

## 2. Design Language & Aesthetic

> Visual mockups are in `Design/Mockups/` — see `MOCKUPS.md` for usage guidance. Mockups inform styling only. This section is the source of truth for all design decisions.

### Visual Identity
- **Mood:** Dark, modern, clean. Bold and empowering, not playful. Data-driven with cool, technical precision.
- **Color Strategy:** See `CONSTANTS.md` for all hex values. Pure dark neutral foundation with modern blue accent for primary actions. Supporting palette: light blue (secondary), green (positive), red (caution). Text is cool light gray — never pure white.
- **Typography:** Heavy and commanding. Headings (screen, modal, and section): 800–900 weight, sentence case, normal letter-spacing. Widget headers: 13px, 900 weight, blue, uppercase, 2px spacing. Labels (status badges, micro-labels, pills, metadata tags): exclusively uppercase, 11px, 700 weight, 2px spacing, muted. Body: 13–15px, 600–700 weight. No thin/light weights.
- **Spacing & Density:** Moderately dense. Screen padding: 20px horizontal, 24px top. Cards: 16px internal padding, 10–14px vertical gaps.
- **Decorative Motif:** Thin border line interrupted by a centered blue ✦ diamond. Acts as section separator app-wide.
- **Contextual Hints:** 16x16 circular "?" tooltip button next to the Effort input on Log Workout, positioned close to the label (left-aligned with small padding). Configurable widgets (Training Load, Weekly Streak) expose their settings modal via long-press → "Configure Settings" — see SCREENS.md § Home Screen → Widget Context Menu. Training Load and Power Level widgets, plus every Trends chart, expose their in-depth explanation via long-press → "See Info" — see SCREENS.md § Standard Patterns → See Info Modal.
- **Inspiration:** Data density of Strong, premium dark aesthetic of Oura Ring, earned-achievement tone of Strava.

### Interaction Style
- **Animations:** Subtle and functional. Progress bars: 0.4s width transitions. Toggles: 0.2s ease. Save buttons: 0.2s disabled↔enabled. Delete "x": 0.15s opacity fade-in. No playful bounces.
- **Navigation:** Bottom tab bar (HOME, WORKOUTS, PLAN, TRENDS, GOALS). Settings via gear icon on Home. Drill-down screens use a blue left-pointing chevron button (`chevron.left` SF Symbol, Primary Accent Blue, 24×24pt circular tap target) at the top-leading edge, and also accept a left-to-right edge-swipe-back gesture as an equivalent way to pop — see SCREENS.md § Standard Patterns → Back Navigation Chevron.
- **Home widget tap-to-open (Phase 8.8):** Every Home widget card opens a per-widget detail sheet on tap — Today's Plan Detail Sheet, Training Load Detail Sheet, Weekly Streak Insights Sheet, Power Level Breakdown Sheet, and the existing Activity Detail Sheet. Tap-to-open is suppressed while the home is in Widget Edit Mode. Long-press context menus remain the entry point for `See Info`, `Configure Settings`, `Complete Workout`, `Reorder Widgets`, and `Delete Widget` on every widget, in every mode. See SCREENS.md § Standard Patterns → Home Widget Tap-to-Open.
- **Feedback:** Color state changes. Completed goals: blue border, faint 3% blue card-surface wash, and "COMPLETED [date]" micro-label (Secondary Text, uppercase) at top center of goal card. Save buttons visually disabled until valid. Light haptic feedback (UIImpactFeedbackGenerator, .light) on primary action buttons: "+ Log Workout" (Home), "+" (Plan). Completion pulse: when user navigates to Goals with a goal whose `lastCelebratedDate` is today, the ring briefly glows/pulses once per visit.

### Accessibility
- Minimum touch target: 44x44pt (Apple HIG)
- Dynamic Type: Yes
- VoiceOver: Yes
- WCAG AA contrast — verify Muted Text (#737373) on Dark (#0a0a0a)
- Dark-only by design; light mode not planned

---

## 3. Technical Foundation

### Platform & Stack
- **Platform:** iOS 17+ (required for SwiftData, covers ~95% active iPhones)
- **UI:** SwiftUI — no UIKit unless SwiftUI has no native equivalent; isolate behind UIViewControllerRepresentable in Core/Utilities/
- **Architecture:** MVVM — ViewModels are @Observable classes (iOS 17 Observation). Do NOT use ObservableObject + @Published. Zero business logic in Views.
- **Persistence:** SwiftData for structured data. UserDefaults ONLY for lightweight preferences.
- **Charts:** Swift Charts (Apple native)
- **Dependencies:** Zero third-party. Native frameworks only. Swift Package Manager.
- **HealthKit:** Read-only integration in Phase 8 (see HEALTHKIT.md). Imports workouts from Apple Watch and other Health-connected sources. No write-back in MVP.
- **WorkoutKit:** Outbound integration in Phase 8.7 (see WORKOUTKIT.md). Schedules `ScheduledWorkout`s onto the user's paired Apple Watch as native workouts in the Watch's Workout app. Requires watchOS 11+ for the Scheduled section to render. Native iOS framework, no third-party dependency. Plan-ID round-trip via `HKWorkout.workoutPlan?.id` (WorkoutKit extension) lets HealthKit's read pipeline match completed sessions back to the originating `ScheduledWorkout`.
- **Not in MVP:** CloudKit, authentication, user accounts, HealthKit write-back, native watchOS companion app, biometrics (Phase 10).

### Project Structure

> Scaffold ALL folders/files as stubs. Do NOT create folders for out-of-scope features.

```
FortiFit/
├── App/
│   ├── FortiFitApp.swift              # @main, SwiftData container
│   ├── ContentView.swift              # Tab navigation root
│   └── AppConstants.swift
├── Core/
│   ├── Models/
│   │   ├── Workout.swift
│   │   ├── ExerciseSet.swift
│   │   ├── Goal.swift
│   │   ├── GoalSnapshot.swift
│   │   ├── WorkoutTypeOrder.swift
│   │   ├── WorkoutTemplate.swift
│   │   ├── TemplateExerciseSet.swift
│   │   ├── ScheduledWorkout.swift
│   │   ├── HomeWidget.swift
│   │   ├── TrendsChart.swift
│   │   ├── WorkoutMatchRejection.swift
│   │   ├── DailySleepSnapshot.swift
│   │   ├── DailyTrainingLoadSnapshot.swift
│   │   └── UserSettings.swift
│   ├── Services/
│   │   ├── WorkoutService.swift
│   │   ├── GoalService.swift
│   │   ├── GoalSnapshotService.swift
│   │   ├── ExerciseLoadService.swift
│   │   ├── StreakService.swift
│   │   ├── WorkoutTypeOrderService.swift
│   │   ├── WorkoutTemplateService.swift
│   │   ├── PlanService.swift
│   │   ├── HomeWidgetService.swift
│   │   ├── TrendsChartService.swift
│   │   ├── PowerLevelService.swift
│   │   ├── WorkoutShareService.swift
│   │   ├── TemplateShareService.swift
│   │   ├── ExerciseSuggestionService.swift
│   │   ├── HealthKitClient.swift
│   │   ├── DefaultHealthKitClient.swift
│   │   ├── HealthKitSyncService.swift
│   │   ├── WorkoutMatcher.swift
│   │   ├── AppleActivityService.swift
│   │   ├── WorkoutMetricService.swift
│   │   ├── WorkoutSchedulerProtocol.swift
│   │   ├── DefaultWorkoutScheduler.swift
│   │   ├── WatchScheduleService.swift
│   │   └── RecoveryStatusService.swift
│   └── Utilities/
│       ├── Extensions/                # Date+, Double+, Color+
│       ├── ShareSheet.swift           # UIActivityViewController wrapper
│       └── UnitConversion.swift
├── Features/
│   ├── Home/                          # HomeView, HomeViewModel
│   ├── Workout/                       # WorkoutListView, WorkoutDetailView, LogWorkoutView, CreateTemplateView, SavedTemplatesListView, TemplateImportView, WorkoutViewModel
│   ├── Plan/                          # PlanView, PlanViewModel, ScheduleWorkoutView, CompletePlanView, EditScheduledWorkoutView
│   ├── Progress/                      # ProgressView, ProgressViewModel
│   ├── Goals/                         # GoalsView, AddGoalView, GoalsViewModel
│   └── Settings/                      # SettingsView, SettingsViewModel
├── Design/
│   ├── Components/                    # FortiFit-prefixed reusable components — see CLAUDE.md Phases 1, 4, 6, 7, 8 for full inventory
│   │                                  # Phase 8.8 adds: FortiFitTodaysPlanDetailSheet.swift,
│   │                                  #                FortiFitTrainingLoadDetailSheet.swift,
│   │                                  #                FortiFitWeeklyStreakDetailSheet.swift,
│   │                                  #                FortiFitPowerLevelDetailSheet.swift
│   │                                  # Phase 11 adds: FortiFitRecoveryStatusWidget.swift,
│   │                                  #               FortiFitRecoveryStatusSettingsModal.swift,
│   │                                  #               FortiFitRecoveryStatusDetailSheet.swift,
│   │                                  #               FortiFitLinkedRecoveryLoadComposite.swift,
│   │                                  #               FortiFitLinkedRecoveryLoadSettingsModal.swift,
│   │                                  #               FortiFitLinkedRecoveryLoadDetailSheet.swift
│   ├── Theme/                         # Colors.swift, Typography.swift, Spacing.swift
│   └── Assets.xcassets
└── Tests/
    ├── ModelTests/
    ├── ServiceTests/
    └── ViewModelTests/
```

> **Components folder** — every reusable view component is `FortiFit`-prefixed (`FortiFitCard`, `FortiFitButton`, etc.). Plus several non-prefixed views (`WorkoutShareCardView`, `TemplateQRModalView`, `MatchPromptSheetView`). The full set is implied by the SCREENS.md sections that reference them; CLAUDE.md's phase tables call out the new components introduced per phase.

---

## 4. Navigation Flow

```
Launch → Tab Bar [Home | Workouts | Plan | Trends | Goals]

Home → Settings (gear icon, top-right of screen)
Home → Log Workout (CTA button)
Home → Workout Detail (tap recent workout)
Home → Add Widget Menu (ellipsis → "Add Widget" → overlay)
Home → Widget Edit Mode (long-press widget → "x" delete, drag reorder)
Home → Training Load Settings Modal (long-press Training Load widget → "Configure Settings")
Home → Weekly Streak Settings Modal (long-press Weekly Streak widget → "Configure Settings")
Home → Widget Info Modal (long-press Training Load or Power Level widget → "See Info")
Home → Complete Planned Workout (Today's Plan widget → compact confirmation sheet)
Home → Today's Plan Detail Sheet (tap Today's Plan widget — Phase 8.8)
Home → Training Load Detail Sheet (tap Training Load widget — Phase 8.8)
Home → Weekly Streak Insights Sheet (tap Weekly Streak widget — Phase 8.8)
Home → Power Level Breakdown Sheet (tap Power Level widget — Phase 8.8)
Home → Activity Detail Sheet (tap Activity Rings widget → 7/30-day breakdown)
Home → Activity Rings Settings Modal (long-press Activity Rings widget → "Configure Settings")
Home → Activity Rings See Info Modal (long-press Activity Rings widget → "See Info")
Home → Settings (tap "Connect" CTA on Activity Rings widget when Apple Health disconnected)
Home → Recovery Status Detail Sheet (tap Recovery Status widget — Phase 11)
Home → Recovery Status Settings Modal (long-press Recovery Status widget → "Configure Settings")
Home → Recovery Status See Info Modal (long-press Recovery Status widget → "See Info")
Home → Settings (tap Recovery Status widget in Connect Apple Health state)
Home → iOS Settings (tap Recovery Status widget in Sleep Access Denied state — deep-links via UIApplication.openSettingsURLString)
Home → Linked Recovery & Load Detail Sheet (tap either card of the linked composite)
Home → Linked Recovery & Load Settings Modal (long-press linked composite → "Configure Settings")
Home → Linked Recovery & Load See Info Modal (long-press linked composite → "See Info")
Recovery Status Detail Sheet → Workout Detail (tap headline row of Time Since Last Workout block)
Recovery Status Detail Sheet → Workouts (tap per-type row of Time Since Last Workout block — auto-expands that type's card)
Recovery Status Detail Sheet → Log Workout (tap "Log a Workout" CTA in cold-start empty state)

Workouts → Log Workout ("+ LOG")
Workouts → Expand/Collapse Workout Type card (tap)
Workouts → Sort, Filter, Reorder & Delete Type (long-press card header → context menu)
Workouts → Delete Workout Type (context menu → "Delete Workout Type" → confirm → bulk delete)
Workouts → Workout Detail (tap preview row in expanded card)
Workouts → Delete Workout (swipe left on preview row)
Workouts → Ellipsis → Create Workout Template / View Workout Templates

Workout Templates → Create Workout Template ("+" button → new template mode)
Workout Templates → Edit Template (tap row)
Workout Templates → Share Template (long-press → context menu → QR modal)
Workout Templates → Delete Template (long-press → context menu → confirm)
Workout Templates → Schedule Template (long-press → context menu → Plan scheduling flow)

Edit Template → Share Template (ellipsis → QR modal)
Edit Template → Delete Template (trash icon → confirm)

Template Import → Save Template (deep link → import prompt → confirm)

Workout Detail → Edit Workout (edit icon → pre-populated Log Workout)
Workout Detail → Delete Workout (trash icon → confirm)
Workout Detail → Save as Template (ellipsis, Strength/HIIT only)
Workout Detail → Metric Detail Sheet (tap any stat card in Summary grid)

Log Workout → Ellipsis → Use Template / Save as Template (new-workout mode only)

Plan → Plan Workout ("+")
Plan → Ellipsis → Workout Templates (→ SavedTemplatesListView)
Plan → Complete Planned Workout (tap planned day → "Complete Planned Workout" → compact confirmation sheet)
Plan → Modify Exercises (compact confirmation sheet → "Modify Exercises" → Log Workout pre-populated)
Plan → Skip Workout (long-press planned card → context menu)
Plan → Remove from Plan (long-press any non-planned card → context menu → confirm; dual-action on completed scheduled cards; recurrence prompt on recurring instances)
Plan → Show on Plan (Workout Detail ellipsis menu when `hiddenFromPlan == true`)
Plan → Workout Detail (tap any completed scheduled or logged-only card on Plan)
Plan → Toggle Week/Month View (segmented toggle)
Plan → Edit Planned Workout (long-press planned/skipped scheduled card → "Edit Workout")
Plan → Toggle Apple Watch Sync (tap FortiFitWatchSyncGlyph on scheduled card)
Plan → Master Sync Off Popover (tap card glyph or Edit Planned Workout toggle when master is off → "Open Settings" → Settings → Apple Watch section)

Trends → Add Chart Menu (ellipsis → "Add Charts" → overlay)
Trends → Chart Info Modal (long-press chart → context menu → "See Info" → modal)
Trends → Delete Chart (long-press chart → context menu → "Delete Chart" → confirm)
Trends → Reorder Charts (long-press chart → context menu → "Reorder Charts" → edit mode with drag handles)

Goals → Create Goal ("+ ADD")
Goals → Ellipsis → Filter Goals (Active / Completed / All)
Goals → Ellipsis → Expand All / Collapse All
Goals → Expand/Collapse Card (tap chevron on goal card)
Goals → Delete Goal (long-press → context menu → "Delete Goal" → confirm)
Goals → Reset Goal Progress (long-press → context menu → "Reset Goal Progress" → confirm; hidden for Weekly Workouts)
Goals → Reorder Goals (long-press → context menu → "Reorder Goals" → edit mode with drag handles)
```

> Full screen layouts, state tables, and interaction details are in `SCREENS.md`.

---

## 5. Data Model

### Core Entities

#### Workout
| Property | Type | Required | Notes |
|----------|------|----------|-------|
| id | UUID | Yes | Auto-generated |
| name | String | Yes | e.g., "Push Day I" |
| date | Date | Yes | Defaults to today. User can backdate. No future dates. |
| workoutType | String | Yes | One of the 6 types in AppConstants |
| rpe | Int? | No | 1–10. Nil if not rated. |
| rpeFromHK | Bool | Yes | Default: `false`. Provenance flag for `rpe` — `true` only when `rpe` was populated by the iOS 18+ `workoutEffortScore` nil-fill path (HEALTHKIT.md § 8). Set to `false` whenever the user mutates `rpe` via Log Workout, on HK upstream delete, and on unlink. Used exclusively by `HealthKitSyncService.unlink(workout:)` to decide whether to clear `rpe` (HEALTHKIT.md § 14). Never persisted as `true` for manual workouts. |
| note | String | No | Free-text session notes |
| durationMinutes | Int? | No | Available for all types. Nil if not entered. Read-only in Log Workout edit view when `healthKitUUID != nil` (HK-owned field — see HEALTHKIT.md § 7). |
| distanceKm | Double? | No | Cardio only. Always nil for other types. Read-only in Log Workout edit view when `healthKitUUID != nil` (HK-owned field). |
| time | Date? | No | Time of day. Purely informational — not used by any algorithm. |
| lastModifiedDate | Date? | No | Set to `.now` on create AND on every update. Used by goal reset scoping (see SERVICES.md § Goal Auto-Update → Reset Scoping). Nil on records created before this field was introduced — treated as in-scope for all goals. |
| hiddenFromPlan | Bool | Yes | Default: `false`. Pure display flag controlling whether the workout surfaces as a logged-only card on the Plan calendar (see SCREENS.md § Plan and SERVICES.md § PlanService → Retrieval). Set to `true` via "Remove from Plan" long-press action; reverted to `false` via the conditional "Show on Plan" item in Workout Detail's ellipsis menu. Does not affect any algorithm, cascade, or other screen — purely controls Plan surfacing. |
| healthKitUUID | UUID? | No | Pointer to source HealthKit workout record. Nil = manual FitNavi workout. Non-nil = imported or linked to an HK record. See HEALTHKIT.md § 5. |
| healthKitSourceBundleID | String? | No | Bundle ID of the app that wrote the workout to HealthKit (e.g., `com.apple.health.WatchApp`, `com.onepeloton.peloton`). Used for the source indicator label via `HKSource.name`. Nil when `healthKitUUID` is nil. |
| healthKitActivityType | String? | No | Friendly display string for the HK activity type (e.g., "Traditional Strength Training", "Outdoor Run"). Used on Workout Detail's source indicator. Never consumed by any algorithm. Nil when `healthKitUUID` is nil. |
| avgHeartRate | Int? | No | Average heart rate in bpm. Imported from HK; nil if not available. HK-owned (see HEALTHKIT.md § 7). |
| maxHeartRate | Int? | No | Maximum heart rate in bpm. Imported from HK; nil if not available. HK-owned. |
| activeEnergyKcal | Double? | No | Active calories burned (Move ring metric). Imported from HK; nil if not available. HK-owned. |
| totalEnergyBurnedKcal | Double? | No | Active + basal calories combined. Imported from HK; nil if not available. HK-owned. |
| elevationAscendedMeters | Double? | No | Elevation gain. Outdoor workouts only. Imported from HK; nil if not available. HK-owned. Display respects `useMiles` (meters vs feet). |
| exerciseMinutes | Int? | No | Apple Exercise ring credit. Differs from `durationMinutes` (strength sessions with low HR may log less Exercise time than total duration). Imported from HK; nil if not available. HK-owned. |
| indoor | Bool? | No | Metadata flag distinguishing indoor vs outdoor workout variants. Imported from HK; nil for manual workouts. HK-owned. |

#### ExerciseSet
| Property | Type | Required | Notes |
|----------|------|----------|-------|
| id | UUID | Yes | Auto-generated |
| exerciseName | String | Yes | e.g., "Bench Press" |
| sets | Int | Yes | Number of sets |
| reps | Int | Yes | Reps per set. When `displayAsTime` resolves to true (see below), the integer is interpreted as **seconds** at display and Watch-composition time. Field name unchanged for storage continuity. |
| weightKg | Double? | No | Nil = bodyweight ("BW") |
| sortOrder | Int | Yes | Display order within workout |
| restSeconds | Int? | No | Default nil. Single rest value per exercise — UI keeps all rows of the same `exerciseName` in lockstep within a workout. Applied between each set; no rest after the final set. Drives the Apple Watch's recovery-step countdown when synced (see WORKOUTKIT.md § 6). Range 5–600 seconds in 5-second increments. |
| displayAsTime | Bool? | No | Three-state override of the dictionary's isometric flag. `nil` = use the exercise dictionary's default (e.g., "Plank" → true; "Bench Press" → false). `true` = force time display regardless of dictionary. `false` = force reps display regardless of dictionary. Per-exercise-card override (UI keeps all rows of the same `exerciseName` in lockstep). See WORKOUTKIT.md § 6 and CONSTANTS.md § Isometric Exercise Names. |
| workout | Workout | Yes | @Relationship back-reference (cascade delete) |

#### Goal
| Property | Type | Required | Notes |
|----------|------|----------|-------|
| id | UUID | Yes | Auto-generated |
| goalType | String | Yes | "exercisePR", "repsPR", "speedDistance", or "weeklyWorkouts" |
| title | String | Yes | Exercise name or custom goal name |
| unit | String | Yes | "weight", "reps", or "speedDistance" |
| targetValueKg | Double? | No | exercisePR only |
| currentValueKg | Double? | No | exercisePR only. Auto-updated. |
| targetReps | Int? | No | repsPR only |
| currentReps | Int? | No | repsPR only. Auto-updated. |
| targetDistanceKm | Double? | No | speedDistance only |
| currentDistanceKm | Double? | No | speedDistance only |
| targetDurationMinutes | Int? | No | speedDistance only. Both distance+duration = speed target. Duration alone = endurance target. |
| currentDurationMinutes | Int? | No | speedDistance only |
| colorIndex | Int | Yes | Cycles through [Blue, Light Blue, Green, Red] |
| sortOrder | Int | Yes | Drag-and-drop order |
| lastCelebratedDate | Date? | No | Set when goal crosses 100%. Drives the Completion Pulse Animation on Goals screen visit and supplies the date shown in the "COMPLETED [date]" micro-label on completed goal cards. Cleared on goal progress reset. |
| resetDate | Date? | No | Set to `.now` when user invokes "Reset Goal Progress". Cleared to nil when the goal definition is edited via the Add/Edit Goal flow. Used to scope which workouts count toward this goal — see SERVICES.md § Goal Auto-Update → Reset Scoping. |

#### GoalSnapshot
| Property | Type | Required | Notes |
|----------|------|----------|-------|
| id | UUID | Yes | Auto-generated |
| goalId | UUID | Yes | Reference to parent Goal |
| date | Date | Yes | Calendar day (time component zeroed) |
| value | Double | Yes | Goal's current value at end of day |

#### WorkoutTypeOrder
| Property | Type | Required | Notes |
|----------|------|----------|-------|
| id | UUID | Yes | Auto-generated |
| workoutType | String | Yes | Unique per type |
| sortOrder | Int | Yes | User-defined display order |
| isExpanded | Bool | Yes | Default: false |
| activeSortOption | String | Yes | Default: "newestFirst" |
| activeFiltersJSON | String? | No | JSON-serialized filter state |

#### WorkoutTemplate
| Property | Type | Required | Notes |
|----------|------|----------|-------|
| id | UUID | Yes | Auto-generated |
| name | String | Yes | User-entered name |
| workoutType | String | Yes | "Strength Training" or "HIIT" only |
| durationMinutes | Int? | No | Nil if not entered |
| dateCreated | Date | Yes | Auto-set on creation |

#### TemplateExerciseSet
| Property | Type | Required | Notes |
|----------|------|----------|-------|
| id | UUID | Yes | Auto-generated |
| exerciseName | String | Yes | |
| sets | Int | Yes | |
| reps | Int | Yes | When `displayAsTime` resolves to true (see below), the integer is interpreted as **seconds** at display and Watch-composition time. Field name unchanged for storage continuity. |
| weightKg | Double? | No | Nil = bodyweight |
| sortOrder | Int | Yes | |
| restSeconds | Int? | No | Default nil. Single rest value per exercise — UI keeps all rows of the same `exerciseName` in lockstep. Carried through into `ScheduledWorkout.scheduledWorkoutSnapshot` at scheduling time. Mirrors `ExerciseSet.restSeconds`. See WORKOUTKIT.md § 6. |
| displayAsTime | Bool? | No | Three-state override of the dictionary's isometric flag. Same semantics as `ExerciseSet.displayAsTime`. Carried through into the snapshot at scheduling time. |
| template | WorkoutTemplate | Yes | @Relationship back-reference (cascade delete) |

#### ScheduledWorkout
| Property | Type | Required | Notes |
|----------|------|----------|-------|
| id | UUID | Yes | Auto-generated |
| templateId | UUID? | No | Reference to WorkoutTemplate. Nil if freeform. |
| scheduledWorkoutSnapshot | Data? | No | JSON blob capturing the workout's exercises (names, sets, reps, weights, restSeconds, displayAsTime, sortOrder). Initialized from the template at scheduling time, then mutable via the Edit Planned Workout flow (see SCREENS.md § Edit Planned Workout). The `ScheduledWorkout` is the source of truth for this data — template edits do not propagate to existing scheduled workouts. Renamed from `templateSnapshot` in Phase 8.7. |
| scheduledDate | Date | Yes | Target calendar day (time component zeroed for day-level matching) |
| scheduledTime | Date? | No | Optional specific time of day. Not required for Apple Watch push — when nil, `WatchScheduleService` falls back to noon (12:00 PM) on the scheduled date for the WorkoutKit API call. Apple Watch does not surface the scheduled time to users. UI label: "Scheduled Time" (toggle). |
| workoutType | String | Yes | Copied from template at scheduling time |
| workoutName | String | Yes | Copied from template name at scheduling time |
| durationMinutes | Int? | No | Copied from template at scheduling time. Mutable via Edit Planned Workout. |
| status | String | Yes | "planned" / "completed" / "skipped". Default: "planned" |
| completedWorkoutId | UUID? | No | Links to the actual Workout record once logged |
| recurrenceRule | String? | No | "weekly" / "biweekly" / nil |
| recurrenceGroupId | UUID? | No | Shared UUID linking all instances of a recurring schedule |
| dateCreated | Date | Yes | Auto-set on creation |
| syncToAppleWatch | Bool | Yes | Default: `false`. Per-instance user intent flag for Apple Watch push. Captured at scheduling time by the Schedule Workout sheet's "Push to Apple Watch" toggle (Phase 8.7.1+, primary entry point); also toggleable post-creation via the `FortiFitWatchSyncGlyph` on the Plan card or the "Push to Apple Watch" toggle on the Edit Planned Workout screen. Gated by master `UserSettings.syncPlanToAppleWatchEnabled`, WorkoutKit auth, `scheduledDate >= today`, and ≥1 exercise in the snapshot. Internal field name retains "sync" for code-level continuity; user-facing copy uses "Push." See WORKOUTKIT.md § 7. |
| appleWorkoutPlanId | UUID? | No | Stable plan UUID stamped on first sync, retained for the lifetime of the record across off/on cycles, edits, and master-toggle bounces. Used as the `WorkoutPlan.id` and round-trips through HealthKit via `HKWorkout.workoutPlan?.id` (WorkoutKit extension) for deterministic completion matching (see WORKOUTKIT.md § 8). Cleared only on `ScheduledWorkout` deletion. |

#### HomeWidget
| Property | Type | Required | Notes |
|----------|------|----------|-------|
| id | UUID | Yes | Auto-generated |
| widgetType | String | Yes | Unique per widget type |
| sortOrder | Int | Yes | Display order on Home |

#### TrendsChart
| Property | Type | Required | Notes |
|----------|------|----------|-------|
| id | UUID | Yes | Auto-generated |
| chartType | String | Yes | Unique per chart type |
| sortOrder | Int | Yes | Display order on Trends |

#### UserSettings (UserDefaults-backed)
| Property | Type | Default | Notes |
|----------|------|---------|-------|
| useLbs | Bool | false | |
| useMiles | Bool | false | |
| targetWorkoutsPerWeek | Int | 5 | Range 0–99. Used by Streak only. |
| targetMinutesPerWorkout | Int | 52 | Range 0–300. Fallback for nil duration in Training Load. |
| targetMoveCalories | Int? | nil | Daily Move ring goal (active calories). Range 1–2000, snap to nearest 10. Used by the Activity Rings widget. Nil until first config — on first add of the widget, populated from Apple Health's current Move goal via `AppleActivityService.importGoalsFromAppleHealth()`; falls back to 500 if HK has no value. See SERVICES.md § AppleActivityService and SCREENS.md § Home Screen → Activity Rings widget. |
| targetExerciseMinutes | Int? | nil | Daily Exercise ring goal (minutes). Range 1–240, snap to nearest 5. Same population semantics as `targetMoveCalories`; falls back to 30 if HK has no value. |
| targetStandHours | Int? | nil | Daily Stand ring goal (hours). Range 1–24, snap to nearest 1. Same population semantics; falls back to 12 if HK has no value. |
| experienceLevel | Int | 0 | 0=Beginner, 1=Intermediate, 2=Advanced |
| currentStreak | Int | 0 | Consecutive completed weeks |
| longestStreak | Int | 0 | Highest streak ever reached |
| hasSeededDefaultWidgets | Bool | false | Prevents re-seeding after user removes all widgets |
| hasSeededDefaultTrendsCharts | Bool | false | Prevents re-seeding after user removes all charts |
| hasMigratedWorkoutInfoRemoval | Bool | false | One-shot flag for the Workout Info widget removal migration. On launch, if false, delete any `HomeWidget` records with `widgetType == "workoutInfo"`, re-index remaining sortOrder, set this flag to true. See SERVICES.md § HomeWidgetService → One-time migration. |
| hasMigratedSprintsToCardio | Bool | false | Gates the one-time Sprints → Cardio migration (see HEALTHKIT.md § 18). Set to `true` after migration runs. |
| healthKitEnabled | Bool | false | User-facing toggle for "Apple Health" section in Settings (see HEALTHKIT.md § 16). When `false`, all HK sync activity is suspended; existing linked workouts retain their `healthKitUUID`. |
| healthKitAnchor | Data? | nil | Serialized `HKQueryAnchor` for catch-up sync (see HEALTHKIT.md § 9). Updated after every successful anchored query. |
| healthKitLastSyncDate | Date? | nil | Timestamp of last successful sync. Drives the "Last sync X min ago" status line in Settings. |
| syncPlanToAppleWatchEnabled | Bool | false | Master kill switch for Apple Watch workout scheduling (see WORKOUTKIT.md § 7, § 9, § 10 and SCREENS.md § Settings → Apple Watch Section). When `false`, all per-card `syncToAppleWatch` flags are visually disabled and any plans previously registered with the Watch are removed. Per-card flags are retained for restoration when master is flipped back on. First flip-on triggers `WorkoutScheduler.shared.requestAuthorization()` (just-in-time pattern). |
| targetSleepHours | Double | 7.0 | Daily sleep duration target in hours. Range 4.0–12.0, snap to nearest 0.5. Drives the Recovery Status widget's deep-sleep-target context, the Sleep Target slider in the Recovery Status Settings Modal, and the sleep-adjusted decay path of the Training Load algorithm when the Recovery Status widget is linked to Training Load (see SERVICES.md § Training Load Algorithm → Sleep-Adjusted Decay). Optionally populated from Apple Health's sleep duration goal characteristic via "Import from Apple Health" in the settings modal. See HEALTHKIT.md § 21. |
| recoveryLoadManuallyUnlinked | Bool | false | Sticky flag set when the user explicitly chooses "Unlink Widgets" from the combined long-press context menu on the Linked Recovery & Load composite. Prevents auto-relink even when Recovery Status and Training Load become adjacent again. Cleared only when the user manually re-establishes linking (e.g., by removing and re-adding one of the widgets, or via the Add Widgets Menu Order seed). See SCREENS.md § Standard Patterns → Widget Linking and SERVICES.md § HomeWidgetService → `isLinkedActive`. |

#### WorkoutMatchRejection
| Property | Type | Required | Notes |
|----------|------|----------|-------|
| id | UUID | Yes | Auto-generated |
| healthKitUUID | UUID | Yes | The HealthKit workout the user declined to link |
| workoutId | UUID | Yes | The FitNavi Workout ID it was rejected against |
| rejectedDate | Date | Yes | Set to `.now` on creation |
| reason | String | Yes | Provenance: `"keepSeparate"` (user tapped Keep Separate on the Match Prompt Sheet) or `"unlinked"` (user unlinked a previously HK-linked workout — see HEALTHKIT.md § 14). Backed by a `RejectionReason` enum. Used for telemetry / debugging only — the matcher's behavior is identical for both reasons. |

Standalone entity used by `WorkoutMatcher` (see HEALTHKIT.md § 12, SERVICES.md § WorkoutMatcher). Before proposing any pairing, the matcher checks for an existing rejection with matching `(healthKitUUID, workoutId)` — regardless of `reason`. No `@Relationship` to `Workout` — lookups are by UUID pair. Orphan rejections (when a linked `Workout` is deleted) are harmless and retained.

#### DailySleepSnapshot
| Property | Type | Required | Notes |
|----------|------|----------|-------|
| id | UUID | Yes | Auto-generated |
| wakeUpDate | Date | Yes | Calendar day the user woke up (time component zeroed). Lookup key — unique per day. |
| totalSleepMinutes | Int | Yes | Σ duration of all `.asleep*` HK samples for the sleep window (per HEALTHKIT.md § 21) |
| deepSleepMinutes | Int | Yes | Σ duration of `.asleepDeep` samples |
| remSleepMinutes | Int | Yes | Σ duration of `.asleepREM` samples |
| coreSleepMinutes | Int | Yes | Σ duration of `.asleepCore` + `.asleepUnspecified` samples |
| awakeMinutes | Int | Yes | Σ duration of `.awake` samples within the sleep window |
| inBedMinutes | Int? | No | Σ duration of `.inBed` samples. Nil if no `.inBed` samples were written by the source. Drives sleep-efficiency calculation. |
| sleepEfficiencyPercent | Int? | No | `round((totalSleepMinutes / inBedMinutes) × 100)`. Nil if `inBedMinutes` is nil. |
| sourceBundleID | String? | No | Bundle ID of the writing app (Apple Health, Oura, Whoop, etc.). Used for diagnostic surfacing only. |
| capturedDate | Date | Yes | Wall-clock timestamp when the snapshot was written. |

Standalone entity (no `@Relationship`). Lookups by `wakeUpDate`. Written by `RecoveryStatusService` on observer-triggered sleep refresh; one snapshot per wake-up day, deduplicated by date. Drives the unlinked Recovery Status detail sheet's 14-day sparkline (sliced from the 30-day cache) and the linked Recovery & Load detail sheet's 14-day sleep chart. See HEALTHKIT.md § 21 and SERVICES.md § RecoveryStatusService.

#### DailyTrainingLoadSnapshot
| Property | Type | Required | Notes |
|----------|------|----------|-------|
| id | UUID | Yes | Auto-generated |
| date | Date | Yes | Calendar day the snapshot represents (time component zeroed). Lookup key — unique per day. |
| score | Int | Yes | Training Load score (0–100) captured at midnight rollover for this day. |
| wasSleepAdjusted | Bool | Yes | `true` if the score was computed using the sleep-adjusted decay path (Recovery Status linked to Training Load at capture time); `false` if computed using the baseline algorithm. |
| capturedDate | Date | Yes | Wall-clock timestamp when the snapshot was written. |

Standalone entity (no `@Relationship`). Lookups by `date`. Written by the Training Load algorithm's Daily Snapshot Capture path (see SERVICES.md § Training Load Algorithm → Daily Snapshot Capture). Powers the Trends `trainingLoadTrend` chart's snapshot-aware rendering — historical days render from snapshot values, today's value is recomputed live. Also drives the linked detail sheet's 14-day Training Load chart and window comparison.

### Relationships
- Workout → many ExerciseSets (cascade delete, ordered by sortOrder)
- WorkoutTemplate → many TemplateExerciseSets (cascade delete, ordered by sortOrder)
- Templates are standalone — applying a template copies data, no reference created
- Goals are standalone, ordered by sortOrder
- GoalSnapshot: standalone. Links to Goal by UUID reference (goalId), not @Relationship. Deleting a Goal cascade-deletes all associated GoalSnapshot records. One snapshot per goal per day, deduplicating by date.
- WorkoutTypeOrder: one per workout type with ≥ 1 workout. Link to Workout is implicit via matching workoutType strings.
- ScheduledWorkout: standalone. Links to WorkoutTemplate and Workout by UUID reference, not @Relationship. Deleting a template does not delete associated scheduled workouts (`scheduledWorkoutSnapshot` preserves exercise data). Deleting a Workout sets completedWorkoutId to nil and reverts status to "planned". Deleting a `ScheduledWorkout` with `appleWorkoutPlanId != nil` triggers `WatchScheduleService.removePlan(_:)` to clear the plan from any paired Apple Watch (see WORKOUTKIT.md § 12).
- HomeWidget: one per active widget. No relationship to other entities.
- TrendsChart: one per active chart. No relationship to other entities. Mirrors HomeWidget pattern.
- WorkoutMatchRejection: standalone. Links to Workout and HK records by UUID reference, not @Relationship. See HEALTHKIT.md § 12 for matcher lookup semantics. Orphan rejections after Workout deletion are harmless and retained; no cascade.
- DailySleepSnapshot: standalone. No `@Relationship`. One record per `wakeUpDate`. Written and deduplicated by `RecoveryStatusService` on sleep observer fire. Not affected by Workout deletion. See HEALTHKIT.md § 21.
- DailyTrainingLoadSnapshot: standalone. No `@Relationship`. One record per `date`. Written at midnight rollover and on any cascade event that mutates today's TL inputs (workout create/edit/delete, sleep refresh while linked). Workout deletion triggers a recompute-and-overwrite of today's snapshot; historical snapshots are immutable. See SERVICES.md § Training Load Algorithm → Daily Snapshot Capture.
- UserSettings: singleton (UserDefaults)

---

## 6. Screen Index

> One-line index of every screen. Full layouts, state tables, and interaction details live in `SCREENS.md`.

| Screen | Purpose |
|---|---|
| Home | Customizable widget grid + "+ Log Workout" CTA + Recent Workouts list |
| Workouts | Training log organized by type (expandable cards, search, sort/filter) |
| Plan | Schedule workouts using templates (week strip / month grid, recurrence) |
| Log Workout | Form for new or edit workout (type-adaptive; HK-aware in edit mode) |
| Workout Detail | Per-session breakdown (stat-card Summary grid + Metric Detail Sheets, share image, edit, delete) |
| Create Workout Template | Build reusable Strength/HIIT template |
| Workout Templates | Manage and share templates (QR sharing) |
| Template Import | Save a template from a QR deep link |
| Trends | Customizable trend chart grid (Strength Tracker, Training Frequency, PRs, Load Trend, plus add-only charts) |
| Goals | Track targets with progress rings + 30-day sparklines |
| Create Goal | Create or edit a goal (4 types) |
| Settings | Unit preferences + Apple Health section |
| Match Prompt Sheet | Resolve ambiguous HK-to-FitNavi workout matches (HEALTHKIT § 13) |
| Edit Planned Workout | Edit a scheduled workout's exercises, name, date, time, duration, and Apple Watch push intent (WORKOUTKIT § 13; SCREENS § Edit Planned Workout) |
| Today's Plan Detail Sheet (Phase 8.8) | Tap-to-open detail of today's planned workouts with per-row Complete action (SCREENS § Today's Plan Detail Sheet) |
| Training Load Detail Sheet (Phase 8.8) | Tap-to-open breakdown of training load with 14-day chart, contributing workouts, week comparison, recovery callout (SCREENS § Training Load Detail Sheet) |
| Weekly Streak Insights Sheet (Phase 8.8) | Tap-to-open streak insights with typographic hero, stat row, this-week ring, 26-week heatmap, milestone shelf — no flame (SCREENS § Weekly Streak Insights Sheet) |
| Power Level Breakdown Sheet (Phase 8.8) | Tap-to-open breakdown with 30-day volume chart, top exercises driving trend, window comparison, calculated nudge (SCREENS § Power Level Breakdown Sheet) |
| Recovery Status Settings Modal (Phase 11) | Configure unlinked Recovery Status widget: Sleep Target slider (4–12h, 0.5 step), Import from Apple Health, Done (SCREENS § Recovery Status Settings Modal) |
| Recovery Status Detail Sheet (Phase 11) | Tap-to-open detail for the unlinked Recovery Status widget: stages bar, sleep efficiency, 14-day sparkline, last-7-nights stat row, time-since-workout breakdown, See Info / Configure Settings footer (SCREENS § Recovery Status Detail Sheet) |
| Linked Recovery & Load Settings Modal (Phase 11) | Combined Configure Settings modal for the linked composite: Training Experience, Target Workout Duration, Sleep Target sliders + Import from Apple Health (SCREENS § Linked Recovery & Load Settings Modal) |
| Linked Recovery & Load Detail Sheet (Phase 11) | Combined detail sheet for the linked composite: dual hero, stacked 14-day sleep + sleep-adjusted TL charts, synchronized scrubbing, window comparison, correlation callout, personal pattern insights, contributing workouts, last-3-nights row, time-since-workout, recovery readiness callout (SCREENS § Linked Recovery & Load Detail Sheet) |
| Recovery Status / Linked Recovery & Load See Info Modal (Phase 11) | Reuses the existing `FortiFitSeeInfoModal` component; copy keyed by `recoveryStatus` and `linkedRecoveryLoad` in INFO_COPY § Widget Info Modal Copy |

---

## 7. Out of Scope (v1)

Do NOT build, scaffold UI for, or write service logic for:
- Social features, multi-user (single-workout image export and template QR sharing are in scope — see SCREENS.md § Workout Detail, SCREENS.md § Workout Templates List)
- Subscriptions or IAP
- Native watchOS companion app. HealthKit read integration (Phase 8) covers consuming workouts recorded in Apple's Fitness app on Apple Watch — see HEALTHKIT.md. WorkoutKit-based outbound scheduling of `ScheduledWorkout`s onto the user's paired Watch is in scope as of Phase 8.7 — see WORKOUTKIT.md.
- Third-party device direct integration (Garmin, Whoop, Fitbit native SDKs). Workouts from these sources reach FitNavi indirectly via HealthKit when those apps write to Apple Health.
- Cloud sync or user accounts
- HealthKit write-back (FitNavi → HealthKit). Read integration is in scope as of Phase 8 — see HEALTHKIT.md § 2 and § 20.
- Nutrition tracking
- Mental health or mindfulness
- Biometrics: resting HR, HRV, body weight, VO₂ max, etc. (deferred to future Phase 10 — see HEALTHKIT.md § 20)
- Onboarding flow

---

## Companion Documents

| Document | Contents | When to load |
|---|---|---|
| `CLAUDE.md` | Constraints, workflow rules, phase index | Every session (always loaded) |
| `PRD.md` | This doc — overview, design language, project structure, data model, screen index | Most sessions |
| `SCREENS.md` | Full screen layouts, state tables, interaction details | Building or modifying any View |
| `SERVICES.md` | Algorithms (Training Load, Streak, Power Level), service specs, cascade behavior, goal auto-update | Building or modifying any Service or ViewModel |
| `CONSTANTS.md` | Colors, typography, exercise dictionary, SF Symbols, advisory text, reference tables | Defining constants, theming |
| `HEALTHKIT.md` | HealthKit integration spec — architecture, sync lifecycle, matcher, field ownership, UI surfaces, authorization | Any Phase 8 work |
| `WORKOUTKIT.md` | WorkoutKit integration spec — outbound Apple Watch scheduling, plan composition, plan-ID round-trip, sync lifecycle, reconciliation, authorization, UI surfaces | Any Phase 8.7 work |
| `INFO_COPY.md` | User-facing strings for Chart Info Modals and Widget Info Modals (the "See Info" modal), plus inline popover copy | Implementing or editing those modals/popovers |
| `HK_MAPPING.md` | Static `HKWorkoutActivityType` → FortiFit `workoutType` lookup table (inbound) and FortiFit `workoutType` → `HKWorkoutActivityType` table (outbound, Phase 8.7+) | Implementing or editing the HK type mapping |
| `TESTING.md` | Test target structure, framework rules, naming, accessibility identifiers, fixtures | Writing or modifying tests |
| `BUGS.md` | Bugs, build failures, and unexpected behavior log | Logging any bug |
