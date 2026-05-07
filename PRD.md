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
- **Navigation:** Bottom tab bar (HOME, WORKOUTS, PLAN, TRENDS, GOALS). Settings via gear icon on Home. Drill-down screens use a blue left-pointing chevron button (`chevron.left` SF Symbol, Primary Accent Blue, 24×24pt circular tap target) at the top-leading edge — see SCREENS.md § Standard Patterns → Back Navigation Chevron.
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
- **Not in MVP:** CloudKit, authentication, user accounts, HealthKit write-back, biometrics (Phase 10), sleep data (Phase 11).

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
│   │   └── WorkoutMetricService.swift
│   └── Utilities/
│       ├── Extensions/                # Date+, Double+, Color+
│       ├── ShareSheet.swift           # UIActivityViewController wrapper
│       └── UnitConversion.swift
├── Features/
│   ├── Home/                          # HomeView, HomeViewModel
│   ├── Workout/                       # WorkoutListView, WorkoutDetailView, LogWorkoutView, CreateTemplateView, SavedTemplatesListView, TemplateImportView, WorkoutViewModel
│   ├── Plan/                          # PlanView, PlanViewModel, ScheduleWorkoutView, CompletePlanView
│   ├── Progress/                      # ProgressView, ProgressViewModel
│   ├── Goals/                         # GoalsView, AddGoalView, GoalsViewModel
│   └── Settings/                      # SettingsView, SettingsViewModel
├── Design/
│   ├── Components/                    # FortiFit-prefixed reusable components — see CLAUDE.md Phases 1, 4, 6, 7, 8 for full inventory
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
Home → Activity Detail Sheet (tap Activity Rings widget → 7/30-day breakdown)
Home → Activity Rings Settings Modal (long-press Activity Rings widget → "Configure Settings")
Home → Activity Rings See Info Modal (long-press Activity Rings widget → "See Info")
Home → Settings (tap "Connect" CTA on Activity Rings widget when Apple Health disconnected)

Workouts → Log Workout ("+ LOG")
Workouts → Expand/Collapse Workout Type card (tap)
Workouts → Sort, Filter, Reorder & Delete Type (long-press card header → context menu)
Workouts → Delete Workout Type (context menu → "Delete Workout Type" → confirm → bulk delete)
Workouts → Workout Detail (tap preview row in expanded card)
Workouts → Delete Workout (swipe left on preview row)
Workouts → Ellipsis → Create Template / View Saved Templates

Saved Templates → Create Template ("+" button → new template mode)
Saved Templates → Edit Template (tap row)
Saved Templates → Share Template (long-press → context menu → QR modal)
Saved Templates → Delete Template (long-press → context menu → confirm)
Saved Templates → Schedule Template (long-press → context menu → Plan scheduling flow)

Edit Template → Share Template (ellipsis → QR modal)
Edit Template → Delete Template (trash icon → confirm)

Template Import → Save Template (deep link → import prompt → confirm)

Workout Detail → Edit Workout (edit icon → pre-populated Log Workout)
Workout Detail → Delete Workout (trash icon → confirm)
Workout Detail → Save as Template (ellipsis, Strength/HIIT only)
Workout Detail → Metric Detail Sheet (tap any stat card in Summary grid)

Log Workout → Ellipsis → Use Template / Save as Template (new-workout mode only)

Plan → Schedule Workout ("+")
Plan → Ellipsis → Saved Templates (→ SavedTemplatesListView)
Plan → Complete Planned Workout (tap planned day → "Complete Planned Workout" → compact confirmation sheet)
Plan → Modify Exercises (compact confirmation sheet → "Modify Exercises" → Log Workout pre-populated)
Plan → Skip Workout (long-press planned card → context menu)
Plan → Remove from Plan (long-press any non-planned card → context menu → confirm; dual-action on completed scheduled cards; recurrence prompt on recurring instances)
Plan → Show on Plan (Workout Detail ellipsis menu when `hiddenFromPlan == true`)
Plan → Workout Detail (tap any completed scheduled or logged-only card on Plan)
Plan → Toggle Week/Month View (segmented toggle)

Trends → Add Chart Menu (ellipsis → "Add Charts" → overlay)
Trends → Chart Info Modal (long-press chart → context menu → "See Info" → modal)
Trends → Delete Chart (long-press chart → context menu → "Delete Chart" → confirm)
Trends → Reorder Charts (long-press chart → context menu → "Reorder Charts" → edit mode with drag handles)

Goals → Add Goal ("+ ADD")
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
| reps | Int | Yes | Reps per set |
| weightKg | Double? | No | Nil = bodyweight ("BW") |
| sortOrder | Int | Yes | Display order within workout |
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
| reps | Int | Yes | |
| weightKg | Double? | No | Nil = bodyweight |
| sortOrder | Int | Yes | |
| template | WorkoutTemplate | Yes | @Relationship back-reference (cascade delete) |

#### ScheduledWorkout
| Property | Type | Required | Notes |
|----------|------|----------|-------|
| id | UUID | Yes | Auto-generated |
| templateId | UUID? | No | Reference to WorkoutTemplate. Nil if freeform. |
| templateSnapshot | Data? | No | JSON blob capturing the template's exercises at scheduling time |
| scheduledDate | Date | Yes | Target calendar day (time component zeroed for day-level matching) |
| scheduledTime | Date? | No | Optional specific time of day |
| workoutType | String | Yes | Copied from template at scheduling time |
| workoutName | String | Yes | Copied from template name at scheduling time |
| durationMinutes | Int? | No | Copied from template at scheduling time |
| status | String | Yes | "planned" / "completed" / "skipped". Default: "planned" |
| completedWorkoutId | UUID? | No | Links to the actual Workout record once logged |
| recurrenceRule | String? | No | "weekly" / "biweekly" / nil |
| recurrenceGroupId | UUID? | No | Shared UUID linking all instances of a recurring schedule |
| dateCreated | Date | Yes | Auto-set on creation |

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

#### WorkoutMatchRejection
| Property | Type | Required | Notes |
|----------|------|----------|-------|
| id | UUID | Yes | Auto-generated |
| healthKitUUID | UUID | Yes | The HealthKit workout the user declined to link |
| workoutId | UUID | Yes | The FitNavi Workout ID it was rejected against |
| rejectedDate | Date | Yes | Set to `.now` on creation |
| reason | String | Yes | Provenance: `"keepSeparate"` (user tapped Keep Separate on the Match Prompt Sheet) or `"unlinked"` (user unlinked a previously HK-linked workout — see HEALTHKIT.md § 14). Backed by a `RejectionReason` enum. Used for telemetry / debugging only — the matcher's behavior is identical for both reasons. |

Standalone entity used by `WorkoutMatcher` (see HEALTHKIT.md § 12, SERVICES.md § WorkoutMatcher). Before proposing any pairing, the matcher checks for an existing rejection with matching `(healthKitUUID, workoutId)` — regardless of `reason`. No `@Relationship` to `Workout` — lookups are by UUID pair. Orphan rejections (when a linked `Workout` is deleted) are harmless and retained.

### Relationships
- Workout → many ExerciseSets (cascade delete, ordered by sortOrder)
- WorkoutTemplate → many TemplateExerciseSets (cascade delete, ordered by sortOrder)
- Templates are standalone — applying a template copies data, no reference created
- Goals are standalone, ordered by sortOrder
- GoalSnapshot: standalone. Links to Goal by UUID reference (goalId), not @Relationship. Deleting a Goal cascade-deletes all associated GoalSnapshot records. One snapshot per goal per day, deduplicating by date.
- WorkoutTypeOrder: one per workout type with ≥ 1 workout. Link to Workout is implicit via matching workoutType strings.
- ScheduledWorkout: standalone. Links to WorkoutTemplate and Workout by UUID reference, not @Relationship. Deleting a template does not delete associated scheduled workouts (templateSnapshot preserves exercise data). Deleting a Workout sets completedWorkoutId to nil and reverts status to "planned".
- HomeWidget: one per active widget. No relationship to other entities.
- TrendsChart: one per active chart. No relationship to other entities. Mirrors HomeWidget pattern.
- WorkoutMatchRejection: standalone. Links to Workout and HK records by UUID reference, not @Relationship. See HEALTHKIT.md § 12 for matcher lookup semantics. Orphan rejections after Workout deletion are harmless and retained; no cascade.
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
| Create Template | Build reusable Strength/HIIT template |
| Saved Templates | Manage and share templates (QR sharing) |
| Template Import | Save a template from a QR deep link |
| Trends | Customizable trend chart grid (Strength Tracker, Training Frequency, PRs, Load Trend, plus add-only charts) |
| Goals | Track targets with progress rings + 30-day sparklines |
| Add Goal | Create or edit a goal (4 types) |
| Settings | Unit preferences + Apple Health section |
| Match Prompt Sheet | Resolve ambiguous HK-to-FitNavi workout matches (HEALTHKIT § 13) |

---

## 7. Out of Scope (v1)

Do NOT build, scaffold UI for, or write service logic for:
- Social features, multi-user (single-workout image export and template QR sharing are in scope — see SCREENS.md § Workout Detail, SCREENS.md § Saved Templates List)
- Subscriptions or IAP
- Apple Watch app (a native watchOS companion app). HealthKit read integration (Phase 8) covers consuming workouts recorded in Apple's Fitness app on Apple Watch — see HEALTHKIT.md.
- Third-party device direct integration (Garmin, Whoop, Fitbit native SDKs). Workouts from these sources reach FitNavi indirectly via HealthKit when those apps write to Apple Health.
- Cloud sync or user accounts
- HealthKit write-back (FitNavi → HealthKit). Read integration is in scope as of Phase 8 — see HEALTHKIT.md § 2 and § 20.
- Nutrition tracking
- Mental health or mindfulness
- Sleep tracking (deferred to future Phase 11 — see HEALTHKIT.md § 20)
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
| `INFO_COPY.md` | User-facing strings for Chart Info Modals and Widget Info Modals (the "See Info" modal) | Implementing or editing those modals |
| `HK_MAPPING.md` | Static `HKWorkoutActivityType` → FortiFit `workoutType` lookup table | Implementing or editing the HK type mapping |
| `TESTING.md` | Test target structure, framework rules, naming, accessibility identifiers, fixtures | Writing or modifying tests |
| `BUGS.md` | Bugs, build failures, and unexpected behavior log | Logging any bug |
