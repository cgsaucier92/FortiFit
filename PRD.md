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
- **Navigation:** Bottom tab bar (HOME, WORKOUTS, PLAN, TRENDS, GOALS). Settings via gear icon on Home. Drill-down screens use blue "← BACK" text button (uppercase, letter-spaced).
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
│   ├── FortiFitApp.swift              # @main entry point, SwiftData container
│   ├── ContentView.swift              # Root view: tab navigation
│   └── AppConstants.swift             # All constants (see CONSTANTS.md)
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
│   │   ├── TrendsChart.swift             # Chart visibility + order on Trends
│   │   ├── WorkoutMatchRejection.swift   # HealthKit dedup rejection record (see HEALTHKIT.md § 5)
│   │   └── UserSettings.swift         # UserDefaults-backed preferences
│   ├── Services/
│   │   ├── WorkoutService.swift       # CRUD for workouts (see SERVICES.md)
│   │   ├── GoalService.swift          # Goal progress + auto-update (see SERVICES.md)
│   │   ├── GoalSnapshotService.swift  # Goal sparkline snapshots (see SERVICES.md)
│   │   ├── ExerciseLoadService.swift  # Training Load algorithm (see SERVICES.md)
│   │   ├── StreakService.swift         # Streak algorithm (see SERVICES.md)
│   │   ├── WorkoutTypeOrderService.swift
│   │   ├── WorkoutTemplateService.swift
│   │   ├── PlanService.swift          # Scheduled workout CRUD + recurrence (see SERVICES.md)
│   │   ├── HomeWidgetService.swift
│   │   ├── TrendsChartService.swift   # CRUD for TrendsChart records (see SERVICES.md)
│   │   ├── PowerLevelService.swift    # Power Level algorithm (see SERVICES.md)
│   │   ├── WorkoutShareService.swift  # Workout image export (see SERVICES.md)
│   │   ├── TemplateShareService.swift # Template QR sharing (see SERVICES.md)
│   │   ├── ExerciseSuggestionService.swift  # Autocomplete (see SERVICES.md)
│   │   ├── HealthKitClient.swift         # HealthKit protocol + DefaultHealthKitClient (see HEALTHKIT.md § 4, SERVICES.md § HealthKitClient)
│   │   ├── HealthKitSyncService.swift    # HK import, anchor persistence, cascade triggering (see HEALTHKIT.md § 9, SERVICES.md § HealthKitSyncService)
│   │   ├── WorkoutMatcher.swift          # Bidirectional HK dedup (see HEALTHKIT.md § 12, SERVICES.md § WorkoutMatcher)
│   │   └── WorkoutMetricService.swift    # Comparative averages, sparkline data, PR detection for Workout Detail Metric Detail Sheet (see SERVICES.md § WorkoutMetricService)
│   └── Utilities/
│       ├── Extensions/                # Date+, Double+, Color+
│       ├── ShareSheet.swift           # UIActivityViewController wrapper
│       └── UnitConversion.swift       # kg↔lbs, km↔miles
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── HomeViewModel.swift
│   ├── Workout/
│   │   ├── WorkoutListView.swift
│   │   ├── WorkoutDetailView.swift
│   │   ├── LogWorkoutView.swift
│   │   ├── CreateTemplateView.swift
│   │   ├── SavedTemplatesListView.swift
│   │   ├── TemplateImportView.swift   # QR code import prompt (see SCREENS.md § Template Import Prompt)
│   │   └── WorkoutViewModel.swift
│   ├── Plan/
│   │   ├── PlanView.swift             # Plan tab root view (calendar + day detail)
│   │   ├── PlanViewModel.swift
│   │   ├── ScheduleWorkoutView.swift  # Scheduling flow sheet
│   │   └── CompletePlanView.swift     # Compact confirmation sheet (Effort, duration)
│   ├── Progress/
│   │   ├── ProgressView.swift
│   │   └── ProgressViewModel.swift
│   ├── Goals/
│   │   ├── GoalsView.swift
│   │   ├── AddGoalView.swift
│   │   └── GoalsViewModel.swift
│   └── Settings/
│       ├── SettingsView.swift
│       └── SettingsViewModel.swift
├── Design/
│   ├── Components/
│   │   ├── FortiFitCard.swift
│   │   ├── FortiFitDivider.swift
│   │   ├── FortiFitLabel.swift
│   │   ├── FortiFitWidgetHeader.swift
│   │   ├── FortiFitProgressBar.swift
│   │   ├── FortiFitButton.swift
│   │   ├── FortiFitSegmentedToggle.swift
│   │   ├── FortiFitBackButton.swift
│   │   ├── FortiFitSelect.swift
│   │   ├── FortiFitInput.swift
│   │   ├── FortiFitHintTooltip.swift
│   │   ├── FortiFitStreakWidget.swift
│   │   ├── FortiFitWorkoutTypeCard.swift
│   │   ├── FortiFitPowerLevelWidget.swift
│   │   ├── FortiFitGoalProgressRing.swift  # Circular progress ring with SF Symbol silhouette
│   │   ├── FortiFitGoalLegendTooltip.swift # Overlay tooltip for dual-arc Distance/Duration legend
│   │   ├── FortiFitExerciseAutocomplete.swift
│   │   ├── FortiFitAddWidgetMenu.swift
│   │   ├── FortiFitAddChartMenu.swift # Add Charts overlay (mirrors FortiFitAddWidgetMenu)
│   │   ├── FortiFitWeekStrip.swift    # Reusable week strip calendar component
│   │   ├── FortiFitMonthGrid.swift    # Reusable month grid calendar component
│   │   ├── FortiFitScheduledWorkoutCard.swift # Card for a scheduled workout in Plan
│   │   ├── WorkoutShareCardView.swift # Share image card (see SERVICES.md § WorkoutShareService)
│   │   ├── TemplateQRModalView.swift  # QR code modal for template sharing
│   │   ├── FortiFitHealthSourceIndicator.swift  # HK-pink heart + activity type + source name on Workout Detail (see HEALTHKIT.md § 15)
│   │   ├── FortiFitHealthSourceInfoSheet.swift  # Tap sheet with explainer + Unlink button (see HEALTHKIT.md § 15)
│   │   ├── FortiFitHealthDataSubsection.swift   # Workout Detail Health Data rows (HR, calories, elevation, etc.) with conditional rendering (see HEALTHKIT.md § 15)
│   │   ├── FortiFitHealthGlyph.swift             # Apple Workout glyph (running figure on green) for peripheral surfaces — Apple-Watch-source-only (see SCREENS.md § Standard Patterns → Peripheral Apple Workout Glyph)
│   │   ├── FortiFitStatCard.swift                # Bordered stat card (icon + label + big value + chevron) used in Workout Detail Summary grid (see SCREENS.md § Workout Detail → Summary)
│   │   ├── FortiFitMetricDetailSheet.swift       # Per-metric detail sheet (hero, comparative context, 30-day sparkline, optional PR chip) opened by tapping a stat card (see SCREENS.md § Workout Detail → Metric Detail Sheet)
│   │   └── MatchPromptSheetView.swift           # Sheet-on-foreground dedup prompt (see HEALTHKIT.md § 13, SCREENS.md § Match Prompt Sheet)
│   ├── Theme/
│   │   ├── Colors.swift
│   │   ├── Typography.swift
│   │   └── Spacing.swift
│   └── Assets.xcassets
└── Tests/
    ├── ModelTests/
    ├── ServiceTests/
    └── ViewModelTests/
```

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
| healthKitUUID | UUID? | No | Pointer to source HealthKit workout record. Nil = manual FortiFit workout. Non-nil = imported or linked to an HK record. See HEALTHKIT.md § 5. |
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
| workoutId | UUID | Yes | The FortiFit Workout ID it was rejected against |
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

## 6. Screen Summaries

> Full layouts, state tables, and interaction specs are in `SCREENS.md`.

| Screen | Purpose | Key Elements |
|--------|---------|-------------|
| Home | Central hub with customizable widgets | Training Load widget (long-press → "See Info" → modal; long-press → "Configure Settings" → modal), Week Streak widget (long-press → "Configure Settings" → modal), Power Level widget (long-press → "See Info" → modal; optional), Today's Plan widget (workout-type silhouette watermark when a plan exists today; long-press → "Complete Workout" → compact confirmation sheet, conditional on an uncompleted plan today), "+ Log Workout" CTA, Recent Workouts list (5 most recent, Apple Workout glyph trailing on date row for Apple-Watch-sourced workouts only), ellipsis menu for Add Widget, long-press edit mode for widget management |
| Workouts | Training log organized by type | Expandable Workout Type cards, preview rows (newest-first, Apple Workout glyph trailing on date row for Apple-Watch-sourced workouts only), swipe-to-delete on preview rows, bulk delete workout type via context menu, pagination (30 per page), search (>20 workouts), sort/filter via context menu, template management via ellipsis |
| Plan | Schedule workouts in advance using templates | Day-by-day scrollable week strip with month indicator, month grid toggle, blue filled circle selected day, scheduled workout cards per day (Apple Workout glyph trailing on metadata row for Apple-Watch-sourced linked workouts only), "Complete Planned Workout" flow with compact confirmation sheet, recurrence (weekly/biweekly), skip/restore, date resolution logic, Today's Plan HomeWidget, ellipsis → Saved Templates |
| Log Workout | Form for new/edit workout | Name, DatePicker (.dateAndTime), type dropdown, Effort dropdown (renders `Label (Number)` per CONSTANTS.md § Effort Label Mapping), duration. Adapts by type: Strength/HIIT → exercise cards with autocomplete; Cardio → distance; Yoga/Pilates → duration only. Edit mode: pre-populated, type locked, trash icon for delete. Ellipsis for templates (new mode only). When `healthKitUUID != nil`: `durationMinutes`, `distanceKm`, and `date` are disabled with inline `info.circle` popovers explaining why each field is read-only (see HEALTHKIT.md § 15). |
| Workout Detail | Exercise breakdown for a session | Name, date, time, type, Summary block (2-column grid of bordered tappable stat cards — Effort/Duration/Distance plus HR/calories/elevation/exercise minutes when present; tap any card → Metric Detail Sheet with comparative average, 30-day sparkline, optional Personal Best chip), conditional Exercises section (hidden when no ExerciseSets), session notes. Share icon (renders workout as PNG image card with the same stat-card grid → iOS share sheet), edit icon, trash icon, ellipsis (Strength/HIIT: save as template; when linked: "Unlink from Apple Health"). When `healthKitUUID != nil`: source indicator (`{healthKitActivityType} · {sourceName} [glyph]` — glyph trailing only for Apple Watch source; sourceName resolves Apple Watch → Apple Workout) below Workout Type row, tappable to open info sheet (see HEALTHKIT.md § 15, SERVICES.md § HealthKitClient → sourceName resolution). |
| Create Template | Build reusable workout structure | Name, type (Strength/HIIT only), duration, exercise cards. No date/Effort/distance. Edit mode: trash icon + ellipsis (Share Template via QR). |
| Saved Templates | Manage and share templates | "+" button for new template, list (newest-first), tap to edit, long-press context menu (Share Template via QR, Schedule This Template, Delete Template). |
| Template Import | Save a template from QR code | Deep link import prompt with template preview, duplicate auto-rename, Cancel/Save. |
| Trends | Training trend charts with customizable layout | Customizable chart cards (TrendsChart-backed), long-press context menu (See Info → Chart Info Modal, Reorder Charts, Delete Chart), ellipsis menu for Add Charts overlay. Strength Tracker (line chart, exercise selector, 30/60/90D), Training Frequency (bar chart, 8 weeks), Personal Records (exercise dropdown, bar chart comparing current vs. previous PR), Training Load Trend (daily dots, zone-colored, 7-day avg). Additional charts available via Add Charts: Workout Volume, Effort Trend, Workout Type Breakdown, Session Duration. Each chart has independent data thresholds. |
| Goals | Track targets | Three-section left column (Goal / Target / Progress with sentence-case Primary Accent labels), large right-justified circular progress rings with goal-type SF Symbol silhouettes and centered overall % readout, dual-arc rings for Speed and Distance with tap-to-toggle legend overlay, expandable sparkline cards (30-day history, always visible on expand), long-press context menu (delete, reset progress, reorder), ellipsis menu (Filter Goals, Expand/Collapse All), completion pulse animation on screen visit. Completed state uses blue border + 3% blue wash + "COMPLETED [date]" micro-label. |
| Add Goal | Create a goal | Type selector (Strength PR / Repetitions PR / Speed and Distance / Number of Weekly Workouts), conditional fields per type, validation. Weekly Workouts target read from UserSettings (read-only, configured via long-press → "Configure Settings" on the Weekly Streak widget). |
| Settings | Configure preferences | General: weight unit, distance unit. Training Load and Streak settings accessed via long-press → "Configure Settings" on their respective Home screen widgets. Apple Health section: "Connect to Apple Health" toggle, status line, "Sync Now" button (when connected), "Open iOS Settings" button (when permission denied) — see HEALTHKIT.md § 16. |
| Match Prompt Sheet | Resolve ambiguous HK-to-FortiFit workout matches | Modal sheet on app foreground when `WorkoutMatcher` has queued a lower-confidence match. Side-by-side summary of the two workouts, three actions: "Link these workouts," "Keep separate," "Decide later." See HEALTHKIT.md § 13. |

---

## 7. Out of Scope (v1)

Do NOT build, scaffold UI for, or write service logic for:
- Social features, multi-user (single-workout image export and template QR sharing are in scope — see SCREENS.md § Workout Detail, SCREENS.md § Saved Templates List)
- Subscriptions or IAP
- Apple Watch app (a native watchOS companion app). HealthKit read integration (Phase 8) covers consuming workouts recorded in Apple's Fitness app on Apple Watch — see HEALTHKIT.md.
- Third-party device direct integration (Garmin, Whoop, Fitbit native SDKs). Workouts from these sources reach FortiFit indirectly via HealthKit when those apps write to Apple Health.
- Cloud sync or user accounts
- HealthKit write-back (FortiFit → HealthKit). Read integration is in scope as of Phase 8 — see HEALTHKIT.md § 2 and § 20.
- Nutrition tracking
- Mental health or mindfulness
- Sleep tracking (deferred to future Phase 11 — see HEALTHKIT.md § 20)
- Biometrics: resting HR, HRV, body weight, VO₂ max, etc. (deferred to future Phase 10 — see HEALTHKIT.md § 20)
- Onboarding flow

---

## Companion Documents

| Document | Contents | When to reference |
|----------|---------|------------------|
| `SCREENS.md` | Full screen layouts, state tables, interaction details | Building or modifying any View |
| `SERVICES.md` | All algorithms (Training Load, Streak, Power Level), service specs, deletion/edit cascading, goal auto-update | Building or modifying any Service or ViewModel |
| `CONSTANTS.md` | AppConstants values, color hex codes, exercise dictionary, motivational messages, advisory text | Defining constants, theming, or referencing specific values |
| `HEALTHKIT.md` | HealthKit integration spec: architecture, phases, data model additions, field ownership, sync lifecycle, matcher, UI surfaces, Settings | Any Phase 8 work — building or modifying HealthKit-related models, services, UI surfaces, or tests |
| `CLAUDE.md` | Coding conventions, constraints, bug logging, development phases | Every coding session |
| `TESTS.md` | Acceptance test checklist | Verifying features |
| `BUGS.md` | All bugs, build failures, and unexpected behavior | Logging any bugs, build failures, or unexpected behavior |
