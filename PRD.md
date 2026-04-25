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
- **Typography:** Heavy and commanding. Headings: 800–900 weight, wide letter-spacing (1–6px). Widget headers: 13px, 900 weight, blue, uppercase, 2px spacing. Labels: exclusively uppercase, 11px, 700 weight, 2px spacing, muted. Body: 13–15px, 600–700 weight. No thin/light weights.
- **Spacing & Density:** Moderately dense. Screen padding: 20px horizontal, 24px top. Cards: 16px internal padding, 10–14px vertical gaps.
- **Decorative Motif:** Thin border line interrupted by a centered blue ✦ diamond. Acts as section separator app-wide.
- **Contextual Hints:** 16x16 circular "?" tooltip buttons next to complex widgets (Training Load, RPE, Power Level), positioned close to the widget title (left-aligned with small padding). 16x16 blue gear icons in the upper-right corner of configurable widgets (Training Load, Weekly Streak) open settings modals.
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
- **Not in MVP:** CloudKit, HealthKit, authentication, user accounts.

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
│   │   └── ExerciseSuggestionService.swift  # Autocomplete (see SERVICES.md)
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
│   │   └── CompletePlanView.swift     # Compact confirmation sheet (RPE, duration)
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
│   │   └── TemplateQRModalView.swift  # QR code modal for template sharing
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
Home → Training Load Settings Modal (gear icon on Training Load widget)
Home → Weekly Streak Settings Modal (gear icon on Weekly Streak widget)
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
| durationMinutes | Int? | No | Available for all types. Nil if not entered. |
| distanceKm | Double? | No | Cardio/Sprints only. Always nil for other types. |
| time | Date? | No | Time of day. Purely informational — not used by any algorithm. |
| lastModifiedDate | Date? | No | Set to `.now` on create AND on every update. Used by goal reset scoping (see SERVICES.md § Goal Auto-Update → Reset Scoping). Nil on records created before this field was introduced — treated as in-scope for all goals. |
| hiddenFromPlan | Bool | Yes | Default: `false`. Pure display flag controlling whether the workout surfaces as a logged-only card on the Plan calendar (see SCREENS.md § Plan and SERVICES.md § PlanService → Retrieval). Set to `true` via "Remove from Plan" long-press action; reverted to `false` via the conditional "Show on Plan" item in Workout Detail's ellipsis menu. Does not affect any algorithm, cascade, or other screen — purely controls Plan surfacing. |

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
- UserSettings: singleton (UserDefaults)

---

## 6. Screen Summaries

> Full layouts, state tables, and interaction specs are in `SCREENS.md`.

| Screen | Purpose | Key Elements |
|--------|---------|-------------|
| Home | Central hub with customizable widgets | Training Load widget (gear icon → settings modal), Workout Info widget, Week Streak widget (gear icon → settings modal), Power Level widget (optional), "+ Log Workout" CTA, Recent Workouts list (5 most recent), ellipsis menu for Add Widget, long-press edit mode for widget management |
| Workouts | Training log organized by type | Expandable Workout Type cards, preview rows (newest-first), swipe-to-delete on preview rows, bulk delete workout type via context menu, pagination (30 per page), search (>20 workouts), sort/filter via context menu, template management via ellipsis |
| Plan | Schedule workouts in advance using templates | Day-by-day scrollable week strip with month indicator, month grid toggle, blue filled circle selected day, scheduled workout cards per day, "Complete Planned Workout" flow with compact confirmation sheet, recurrence (weekly/biweekly), skip/restore, date resolution logic, Today's Plan HomeWidget, ellipsis → Saved Templates |
| Log Workout | Form for new/edit workout | Name, DatePicker (.dateAndTime), type dropdown, RPE, duration. Adapts by type: Strength/HIIT → exercise cards with autocomplete; Cardio/Sprints → distance; Yoga/Pilates → duration only. Edit mode: pre-populated, type locked, trash icon for delete. Ellipsis for templates (new mode only). |
| Workout Detail | Exercise breakdown for a session | Name, date, time, type, RPE, duration, exercises/distance, session notes. Share icon (renders workout as PNG image card → iOS share sheet), edit icon, trash icon, ellipsis (Strength/HIIT: save as template). |
| Create Template | Build reusable workout structure | Name, type (Strength/HIIT only), duration, exercise cards. No date/RPE/distance. Edit mode: trash icon + ellipsis (Share Template via QR). |
| Saved Templates | Manage and share templates | "+" button for new template, list (newest-first), tap to edit, long-press context menu (Share Template via QR, Schedule This Template, Delete Template). |
| Template Import | Save a template from QR code | Deep link import prompt with template preview, duplicate auto-rename, Cancel/Save. |
| Trends | Training trend charts with customizable layout | Customizable chart cards (TrendsChart-backed), long-press context menu to delete or reorder, ellipsis menu for Add Charts overlay. Strength Tracker (line chart, exercise selector, 30/60/90D), Training Frequency (bar chart, 8 weeks), Personal Records (exercise dropdown, bar chart comparing current vs. previous PR), Training Load Trend (daily dots, zone-colored, 7-day avg). Additional charts available via Add Charts: Workout Volume, RPE Trend, Workout Type Breakdown, Session Duration. Each chart has independent data thresholds. |
| Goals | Track targets | Three-section left column (Goal / Target / Progress with sentence-case Primary Accent labels), large right-justified circular progress rings with goal-type SF Symbol silhouettes and centered overall % readout, dual-arc rings for Speed and Distance with tap-to-toggle legend overlay, expandable sparkline cards (30-day history, always visible on expand), long-press context menu (delete, reset progress, reorder), ellipsis menu (Filter Goals, Expand/Collapse All), completion pulse animation on screen visit. Completed state uses blue border + 3% blue wash + "COMPLETED [date]" micro-label. |
| Add Goal | Create a goal | Type selector (Strength PR / Repetitions PR / Speed and Distance / Number of Weekly Workouts), conditional fields per type, validation. Weekly Workouts target read from UserSettings (read-only, configured via Weekly Streak widget gear icon). |
| Settings | Configure preferences | General: weight unit, distance unit. Training Load and Streak settings accessed via gear icons on their respective Home screen widgets. |

---

## 7. Out of Scope (v1)

Do NOT build, scaffold UI for, or write service logic for:
- Social features, multi-user (single-workout image export and template QR sharing are in scope — see SCREENS.md § Workout Detail, SCREENS.md § Saved Templates List)
- Subscriptions or IAP
- Apple Watch app
- Third-party device integration (Garmin, Whoop, Fitbit)
- Cloud sync or user accounts
- HealthKit integration
- Nutrition tracking
- Mental health or mindfulness
- Sleep tracking
- Onboarding flow

---

## Companion Documents

| Document | Contents | When to reference |
|----------|---------|------------------|
| `SCREENS.md` | Full screen layouts, state tables, interaction details | Building or modifying any View |
| `SERVICES.md` | All algorithms (Training Load, Streak, Power Level), service specs, deletion/edit cascading, goal auto-update | Building or modifying any Service or ViewModel |
| `CONSTANTS.md` | AppConstants values, color hex codes, exercise dictionary, motivational messages, advisory text | Defining constants, theming, or referencing specific values |
| `CLAUDE.md` | Coding conventions, constraints, bug logging, development phases | Every coding session |
| `TESTS.md` | Acceptance test checklist | Verifying features |
| `BUGS.md` | All bugs, build failures, and unexpected behavior | Logging any bugs, build failures, or unexpected behavior |
