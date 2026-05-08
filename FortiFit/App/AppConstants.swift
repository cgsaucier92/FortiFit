import Foundation
import SwiftUI

// MARK: - Chart Visual Types

enum ChartGradientAnchor {
    case single(Color)
    case horizontalSplit(leading: Color, trailing: Color)
}

struct ChartSummary {
    let hero: String
    let caption: String
}

enum DeltaDirection {
    case up, down, flat
}

struct ChartDelta {
    let hero: String
    let caption: String
    let delta: String?
    let direction: DeltaDirection
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let x: Date
    let y: Double
    let label: String
}

struct PRTimelineEvent: Identifiable {
    let id = UUID()
    let date: Date
    let weightKg: Double
    let deltaKg: Double
}

struct WorkoutTypeBreakdownRow: Identifiable {
    let id = UUID()
    let type: String
    let count: Int
    let percent: Double
    let avgDurationMinutes: Int?
}

enum DetailTimeRange: String, CaseIterable {
    case fourteenDays = "14d"
    case thirtyDays = "30d"
    case sixtyDays = "60d"
    case ninetyDays = "90d"
    case eightWeeks = "8w"
    case sixMonths = "6m"
    case oneYear = "1y"
    case allTime = "all"

    var displayLabel: String {
        switch self {
        case .fourteenDays: return "14D"
        case .thirtyDays: return "30D"
        case .sixtyDays: return "60D"
        case .ninetyDays: return "90D"
        case .eightWeeks: return "8W"
        case .sixMonths: return "6M"
        case .oneYear: return "1Y"
        case .allTime: return "All"
        }
    }

    var days: Int? {
        switch self {
        case .fourteenDays: return 14
        case .thirtyDays: return 30
        case .sixtyDays: return 60
        case .ninetyDays: return 90
        case .eightWeeks: return 56
        case .sixMonths: return 182
        case .oneYear: return 365
        case .allTime: return nil
        }
    }

    static func eligibleRanges(for chartType: String) -> [DetailTimeRange] {
        switch chartType {
        case "strengthTracker":
            return [.thirtyDays, .ninetyDays, .sixMonths, .oneYear, .allTime]
        case "trainingFrequency":
            return [.eightWeeks, .sixMonths, .oneYear, .allTime]
        case "personalRecords":
            return [.allTime]
        case "trainingLoadTrend":
            return [.fourteenDays, .thirtyDays, .ninetyDays, .sixMonths]
        case "workoutVolume":
            return [.thirtyDays, .ninetyDays, .sixMonths, .oneYear, .allTime]
        case "rpeTrend":
            return [.eightWeeks, .sixMonths, .oneYear, .allTime]
        case "workoutTypeBreakdown":
            return [.thirtyDays, .sixtyDays, .ninetyDays, .oneYear, .allTime]
        case "sessionDuration":
            return [.eightWeeks, .sixMonths, .oneYear, .allTime]
        default:
            return [.allTime]
        }
    }

    static func defaultRange(for chartType: String) -> DetailTimeRange {
        switch chartType {
        case "strengthTracker": return .ninetyDays
        case "trainingFrequency": return .eightWeeks
        case "personalRecords": return .allTime
        case "trainingLoadTrend": return .thirtyDays
        case "workoutVolume": return .ninetyDays
        case "rpeTrend": return .eightWeeks
        case "workoutTypeBreakdown": return .ninetyDays
        case "sessionDuration": return .eightWeeks
        default: return .allTime
        }
    }
}

enum AppConstants {
    static let workoutTypes = [
        "Strength Training",
        "HIIT",
        "Cardio",
        "Yoga",
        "Pilates",
        "Other"
    ]

    static let exerciseOptions = [
        "Bench Press",
        "Barbell Squats",
        "Deadlifts",
        "Overhead Press",
        "Barbell Rows",
        "Incline Bench Press",
        "Custom"
    ]

    static let workoutTypeModifiers: [String: Double] = [
        "Strength Training": 1.0,
        "HIIT": 1.1,
        "Cardio": 0.7,
        "Pilates": 0.5,
        "Yoga": 0.3,
        "Other": 0.7
    ]

    static let experienceLevels = ["Beginner", "Intermediate", "Advanced"]
    static let experienceDescriptions = ["< 1 year", "1–3 years", "3+ years"]

    static let rpeScale = Array(1...10)

    static let goalTypes = ["Strength PR", "Repetitions PR", "Speed and Distance", "Number of Weekly Workouts"]

    // MARK: - Icons
    static let editIcon = "pencil"
    static let deleteIcon = "trash"

    // MARK: - Workout Type SF Symbols
    static let workoutTypeIconWidth: CGFloat = 30
    static let workoutTypeSymbols: [String: String] = [
        "Strength Training": "figure.strengthtraining.traditional",
        "HIIT": "figure.highintensity.intervaltraining",
        "Cardio": "figure.mixed.cardio",
        "Yoga": "figure.yoga",
        "Pilates": "figure.pilates",
        "Other": "figure"
    ]

    // MARK: - Workout Detail Summary Icons
    static let summaryFieldSymbols: [String: String] = [
        "RPE": "chart.bar.fill",
        "Duration": "clock",
        "Distance": "ruler",
        "AvgHR": "heart.fill",
        "MaxHR": "heart.fill",
        "ActiveKcal": "flame.fill",
        "TotalKcal": "flame",
        "Elevation": "arrow.up.right",
        "ExerciseMinutes": "figure.walk"
    ]

    // MARK: - Effort Color Mapping

    static func effortColor(for score: Int) -> Color {
        switch score {
        case 1...4: return FortiFitColors.positive
        case 5, 6: return FortiFitColors.caution
        case 7...10: return FortiFitColors.alert
        default: return FortiFitColors.mutedText
        }
    }

    // MARK: - Stat Card Colors

    static let statCardPurple = Color(hex: "4B2893")
    static let statCardTeal = Color(hex: "289193")
    static let statCardCalorie = Color(hex: "FFA600")
    static let statCardOrange = Color(hex: "934F28")

    static func statCardColor(for metric: WorkoutMetric) -> Color {
        switch metric {
        case .effort: return FortiFitColors.positive
        case .duration, .exerciseMinutes: return statCardPurple
        case .distance: return statCardTeal
        case .avgHR, .maxHR: return FortiFitColors.alert
        case .activeKcal, .totalKcal: return statCardCalorie
        case .elevation: return statCardOrange
        }
    }

    // MARK: - Effort Label Mapping

    static func effortLabel(for score: Int) -> String {
        switch score {
        case 1, 2: return "Easy"
        case 3, 4: return "Light"
        case 5, 6: return "Moderate"
        case 7, 8: return "Hard"
        case 9, 10: return "All Out"
        default: return "Unknown"
        }
    }

    // MARK: - Goal Card Header Labels

    enum GoalHeaderLabel {
        static let strength = "Strength Goal"
        static let reps = "Reps Goal"
        static let speed = "Speed Goal"
        static let endurance = "Endurance Goal"
        static let distance = "Distance Goal"
        static let frequency = "Frequency Goal"
    }

    // MARK: - Goal Tooltip
    static let goalTooltipPercentageFontSize: CGFloat = 18

    // MARK: - Goal Silhouette
    static let goalSilhouetteCompletedOpacity: Double = 0.90

    // MARK: - Goal Card SF Symbol Silhouettes
    static let goalSymbolStrengthPR = "figure.strengthtraining.traditional"
    static let goalSymbolRepsPR = "figure.strengthtraining.traditional"
    static let goalSymbolSpeedDistance = "figure.run"
    static let goalSymbolWeeklyWorkouts = "calendar"

    // Experience level int values
    static let experienceBeginner = 0
    static let experienceIntermediate = 1
    static let experienceAdvanced = 2

    // MARK: - Widget Context Menu SF Symbols

    static let configureSettingsIcon = "gear"
    static let completeWorkoutIcon = "checkmark.circle"

    // MARK: - Trends Chart Context Menu SF Symbols

    static let seeInfoIcon = "info.circle"

    // MARK: - Widgets

    static let widgetTypes = [
        "trainingLoad",
        "weekStreak",
        "powerLevel",
        "todaysPlan",
        "appleActivity"
    ]

    static let defaultHomeWidgets = [
        "todaysPlan",
        "trainingLoad",
        "powerLevel"
    ]

    static let widgetDisplayNames: [String: String] = [
        "trainingLoad": "Training Load",
        "weekStreak": "Weekly Streak",
        "powerLevel": "Power Level",
        "todaysPlan": "Today's Plan",
        "appleActivity": "Activity Rings"
    ]

    static let widgetDescriptions: [String: String] = [
        "trainingLoad": "Shows your accumulated training stress score and recovery readiness based on recent workout intensity, volume, and frequency.",
        "weekStreak": "Tracks how many consecutive weeks you've met your weekly workout target.",
        "powerLevel": "Measures your average strength volume trend over the last 30 days across Strength Training and HIIT workouts.",
        "todaysPlan": "Shows your scheduled workout for today so you can jump straight into logging.",
        "appleActivity": "Tracks your daily Move, Exercise, and Stand rings. Requires an Apple Watch and Apple Health connected in Settings."
    ]

    // MARK: - Power Level

    static let powerLevelStatuses = ["Deloading", "Steady", "Rising"]

    // MARK: - Chart Types (Trends Screen)

    static let trendsChartTypes = [
        "strengthTracker",
        "trainingFrequency",
        "personalRecords",
        "trainingLoadTrend",
        "workoutVolume",
        "rpeTrend",
        "workoutTypeBreakdown",
        "sessionDuration"
    ]

    static let defaultTrendsCharts = [
        "strengthTracker",
        "trainingFrequency",
        "personalRecords",
        "trainingLoadTrend"
    ]

    static let trendsChartDisplayNames: [String: String] = [
        "strengthTracker": "Strength Tracker",
        "trainingFrequency": "Training Frequency",
        "personalRecords": "Personal Records",
        "trainingLoadTrend": "Training Load Trend",
        "workoutVolume": "Workout Volume",
        "rpeTrend": "Effort Trend",
        "workoutTypeBreakdown": "Workout Type Breakdown",
        "sessionDuration": "Session Duration"
    ]

    static let trendsChartDescriptions: [String: String] = [
        "strengthTracker": "Tracks your max weight for a selected exercise over time so you can see strength progression at a glance.",
        "trainingFrequency": "Shows how many workouts you completed each week.",
        "personalRecords": "Compares your latest personal record against the previous record for each exercise.",
        "trainingLoadTrend": "Visualizes your daily training load score over the last two weeks so you can spot overtraining or recovery windows.",
        "workoutVolume": "Tracks your total training volume per session over time to reveal whether you're progressively overloading.",
        "rpeTrend": "Shows your average effort per week so you can monitor training intensity over time.",
        "workoutTypeBreakdown": "Shows the distribution of your workout types so you can see if your training is balanced.",
        "sessionDuration": "Tracks your average workout duration per week to help you manage your time in the gym."
    ]

    // MARK: - Trends Chart Visual Tokens

    enum Trends {
        static let captionLatest = "LATEST"
        static let captionAvgLast8Weeks = "AVG / LAST 8 WEEKS"
        static let captionLatestPR = "LATEST PR"
        static let captionToday = "TODAY'S LOAD"
        static let captionAvgPerSession = "AVG / SESSION"
        static let captionWorkouts = "WORKOUTS"

        static func deltaString(magnitude: String, rangeLabel: String) -> String {
            "\(magnitude) vs. prior \(rangeLabel)"
        }
        static let deltaSamePrefix = "same as prior"
    }

    static func chartGradientAnchor(for chartType: String) -> ChartGradientAnchor {
        switch chartType {
        case "strengthTracker":
            return .single(FortiFitColors.chartPink)
        case "trainingFrequency":
            return .single(FortiFitColors.positive)
        case "personalRecords":
            return .horizontalSplit(leading: FortiFitColors.chartLightCyan, trailing: FortiFitColors.chartDeepBlue)
        case "trainingLoadTrend":
            return .single(FortiFitColors.primaryAccent)
        case "workoutVolume":
            return .single(FortiFitColors.chartPurple)
        case "rpeTrend":
            return .single(FortiFitColors.chartOrange)
        case "workoutTypeBreakdown":
            return .single(FortiFitColors.primaryAccent)
        case "sessionDuration":
            return .single(FortiFitColors.chartTeal)
        default:
            return .single(FortiFitColors.primaryAccent)
        }
    }

    // MARK: - Workout Type Chart Colors

    static let workoutTypeChartColors: [String: Color] = [
        "Strength Training": Color(hex: "3b82f6"),   // Primary Accent Blue
        "HIIT": Color(hex: "60a5fa"),                 // Secondary Blue
        "Cardio": Color(hex: "10b981"),               // Positive Green
        "Yoga": Color(hex: "FFBF51"),                 // Orange
        "Pilates": Color(hex: "ef4444"),              // Alert Red
        "Other": Color(hex: "C4F648")                 // Caution Yellow
    ]

    // MARK: - Widget Info Modal Copy

    static let widgetInfoModalCopy: [String: ChartInfoCopy] = [
        "trainingLoad": ChartInfoCopy(
            title: "About Training Load",
            intro: "Training Load is a 0–100 score that summarizes how much training stress you've accumulated over the past 10 days. The zone label and advisory beneath it suggest whether to push, ease off, or rest today.",
            sections: [
                ("How it's calculated", "Each workout you've logged in the last 10 days contributes a stress value based on your Effort rating for that session, how long it lasted, the workout type, and the volume you put in (sets × reps for Strength and HIIT). Recent sessions count more than older ones — stress decays over about 10 days."),
                ("Your experience level", "Set via long-press → Configure Settings on the widget. Beginner, Intermediate, and Advanced each have a different recovery rate and stress capacity. Higher experience means stress decays faster and you can absorb more training before the score climbs into peak territory."),
                ("Consecutive training days", "Stacking training days back-to-back adds a small multiplier to your score, up to 32% extra at five or more consecutive days. Take a rest day and the multiplier resets."),
                ("Same-day floor", "If you've already trained today, the score won't drop low enough to suggest \"train hard\" — there's a built-in floor based on what you logged today that lifts on its own tomorrow."),
                ("Zones", "- Low (1–30, green): well recovered\n- Moderate (31–55, yellow): some accumulated fatigue\n- High (56–80, dark yellow): significant fatigue\n- Peak (81–100, red): high stress, prioritize recovery"),
                ("What's not counted", "Workouts logged with no exercises, no Effort rating, and no duration are skipped — they're treated as placeholder entries with no meaningful stress to add."),
                ("Minimum Data Threshold", "If you haven't logged a workout in the last 10 days, the score sits at 0 (Resting) and the advisory shows \"No recent training stress.\"")
            ]
        ),
        "powerLevel": ChartInfoCopy(
            title: "About Power Level",
            intro: "Power Level shows whether your strength training volume is rising, holding steady, or trending down compared to where you were a month ago. It answers \"am I progressing?\" at a glance.",
            sections: [
                ("How it's calculated", "FitNavi averages your workout volume across the last 30 days and compares it to your average across the prior 30 days. Volume per workout is sets × reps × weight, summed across every exercise in the session."),
                ("What workouts count", "Only Strength Training and HIIT workouts. Cardio, yoga, pilates, and other types don't track exercise sets, so they don't contribute to a volume comparison."),
                ("Bodyweight exercises", "Sets logged without a weight value count as if the weight were 1, since they still represent work performed. This keeps bodyweight volume from disappearing entirely from the comparison."),
                ("Status thresholds", "- Rising (↑, green): current 30-day average is more than 10% higher than the prior 30 days\n- Steady (—, blue): within 10% in either direction — your volume is holding consistent\n- Deloading (↓, red): current 30-day average is more than 10% lower than the prior 30 days"),
                ("Minimum Data Threshold", "If you don't have any Strength Training or HIIT workouts logged, the widget shows a prompt to start logging. If you have current workouts but no prior 30-day baseline yet (less than 31 days of history), the status defaults to Steady until you build enough data.")
            ]
        ),
        "appleActivity": ChartInfoCopy(
            title: "About Activity Rings",
            intro: "Activity Rings shows your daily Move, Exercise, and Stand progress pulled live from Apple Health, measured against goals you set in FitNavi. It's the same three-ring view you see on Apple Watch, brought into FitNavi so you can keep your activity tracking and your strength tracking in one place.",
            sections: [
                ("The three rings", "- **Move** (red): active calories burned today. Counts movement of any kind — walks, workouts, fidgeting at your desk. Goal default is 500 cal; you can set it 1–2000 in 10-cal increments.\n- **Exercise** (green): minutes of brisk activity today. The Watch decides what counts based on heart rate and motion. Goal default is 30 min; you can set it 1–240 in 5-min increments.\n- **Stand** (blue): hours where you stood and moved for at least one minute. Goal default is 12 hours; you can set it 1–24 in 1-hr increments."),
                ("How goals are set", "When you first add the widget, FitNavi imports the goals you've already set in Apple Health. After that, your FitNavi goals are independent — change them in Configure Settings, or use the \"Import from Apple Health\" button to re-sync if you change them on your watch later."),
                ("Workout contribution", "Below each ring's value, you'll see how much of today's progress came from a workout you logged in FitNavi (only workouts linked to Apple Watch contribute — manually-logged workouts that aren't HK-linked won't show up here, since their data isn't in HealthKit)."),
                ("Weekly closure rate", "The chip below the rings tells you how many days this week you closed all three rings — a quick read on your week-over-week consistency."),
                ("Tap the widget", "Tap the widget to open a detailed breakdown with sparklines and a calendar heatmap of which days you closed your rings (toggle between 7-day and 30-day views)."),
                ("Requirements", "You'll need an Apple Watch and Apple Health enabled in FitNavi Settings. If either is missing, the widget shows a message explaining what to do next.")
            ]
        )
    ]

    // MARK: - Chart Data Thresholds

    static let chartEmptyMessages: [String: String] = [
        "strengthTracker": "Log more exercises to display strength trends.",
        "trainingFrequency": "Complete your first full week to see frequency trends.",
        "personalRecords": "Log more exercises to display personal records.",
        "trainingLoadTrend": "Log more workouts to display load trends.",
        "workoutVolume": "Log more Strength or HIIT workouts to display volume trends.",
        "rpeTrend": "Log workouts with effort ratings to display effort trends.",
        "workoutTypeBreakdown": "Log more workouts to display your training breakdown.",
        "sessionDuration": "Log workouts with duration to display session length trends."
    ]

    // MARK: - Exercise Dictionary (Autocomplete)

    static let exerciseDictionary: [String] = [
        // Chest
        "Bench Press", "Incline Bench Press", "Decline Bench Press",
        "Dumbbell Bench Press", "Incline Dumbbell Press", "Dumbbell Flyes",
        "Incline Dumbbell Flyes", "Cable Crossovers", "Chest Dips",
        "Machine Chest Press", "Push-Ups",
        // Back
        "Barbell Rows", "Dumbbell Rows", "Pendlay Rows", "T-Bar Rows",
        "Seated Cable Rows", "Pull-Ups", "Chin-Ups", "Lat Pulldowns",
        "Face Pulls", "Straight-Arm Pulldowns", "Rack Pulls",
        // Shoulders
        "Overhead Press", "Dumbbell Shoulder Press", "Arnold Press",
        "Lateral Raises", "Front Raises", "Reverse Flyes",
        "Upright Rows", "Cable Lateral Raises", "Machine Shoulder Press",
        // Legs
        "Barbell Squats", "Front Squats", "Goblet Squats",
        "Bulgarian Split Squats", "Leg Press", "Hack Squats",
        "Lunges", "Walking Lunges", "Romanian Deadlifts",
        "Leg Extensions", "Leg Curls", "Hip Thrusts",
        "Glute Bridges", "Calf Raises", "Seated Calf Raises",
        // Arms
        "Barbell Curls", "Dumbbell Curls", "Hammer Curls",
        "Preacher Curls", "Concentration Curls", "Cable Curls",
        "Tricep Pushdowns", "Skull Crushers", "Overhead Tricep Extensions",
        "Tricep Dips", "Close-Grip Bench Press",
        // Compound / Full Body
        "Deadlifts", "Sumo Deadlifts", "Trap Bar Deadlifts",
        "Power Cleans", "Clean and Press", "Kettlebell Swings",
        "Farmers Walks", "Turkish Get-Ups",
        // Core
        "Planks", "Hanging Leg Raises", "Cable Crunches",
        "Ab Wheel Rollouts", "Russian Twists", "Woodchoppers",
        // HIIT / Cardio Exercises
        "Box Jumps", "Burpees", "Battle Ropes",
        "Sled Push", "Sled Pull", "Rowing Machine", "Assault Bike"
    ]

    // MARK: - Exercise Alias Map (Autocomplete)

    static let exerciseAliasMap: [String: String] = [
        "OHP": "Overhead Press",
        "BB Rows": "Barbell Rows",
        "BB Squats": "Barbell Squats",
        "BB Curls": "Barbell Curls",
        "DB Rows": "Dumbbell Rows",
        "DB Bench": "Dumbbell Bench Press",
        "DB Press": "Dumbbell Shoulder Press",
        "DB Curls": "Dumbbell Curls",
        "DB Flyes": "Dumbbell Flyes",
        "RDL": "Romanian Deadlifts",
        "RDLs": "Romanian Deadlifts",
        "SLDL": "Romanian Deadlifts",
        "BSS": "Bulgarian Split Squats",
        "CG Bench": "Close-Grip Bench Press",
        "CGBP": "Close-Grip Bench Press",
        "Skull Crusher": "Skull Crushers",
        "Tri Pushdown": "Tricep Pushdowns",
        "Tri Pushdowns": "Tricep Pushdowns",
        "Lat Raise": "Lateral Raises",
        "Lat Raises": "Lateral Raises",
        "Lat Pulldown": "Lat Pulldowns",
        "Face Pull": "Face Pulls",
        "Hip Thrust": "Hip Thrusts",
        "Calf Raise": "Calf Raises",
        "KB Swings": "Kettlebell Swings"
    ]

    // MARK: - HealthKit Strings

    enum HKOwnedField: String, CaseIterable {
        case date, startTime, duration, distance
    }

    enum HealthKit {
        // Source Indicator Info Sheet
        static let infoSheetTitle = "Imported from Apple Health"
        static let infoSheetLead = "This workout's summary details are imported from Apple Health"
        static let infoSheetReadOnlyHeadline = "Date, Start Time, and Duration are read-only for this workout."
        static let infoSheetReadOnlySubline = "Edit in Apple Health, or unlink to edit in FitNavi."
        static let infoSheetPermanentHeadline = "Unlinking is permanent."
        static let infoSheetPermanentSubline = "Apple Health summary data will be deleted, and future Apple Health edits won't sync."
        static let infoSheetDoneButton = "Done"
        static let infoSheetUnlinkLink = "Unlink from Apple Health"
        static let infoSheetActivityTypeLabel = "Activity Type"
        static let infoSheetSourceLabel = "Source"
        static let infoSheetImportedLabel = "Imported"
        static let infoSheetLastSyncedLabel = "Last synced"

        // SF Symbols
        static let infoSheetHeaderIcon = "heart.fill"
        static let infoSheetReadOnlyIcon = "pencil.slash"
        static let infoSheetPermanentIcon = "arrow.uturn.backward"

        // Unlink Confirmation Dialog (Info Sheet)
        static let unlinkConfirmTitle = "Unlink workout from Apple Health?"
        static let unlinkConfirmMessage = "This will delete all Apple Health\u{2013}sourced summary data for this workout, and you won't be able to link it back. This can't be undone."
        static let unlinkConfirmDestructive = "Unlink"
        static let unlinkConfirmCancel = "Cancel"
        static let unlinkSuccessToast = "Unlinked from Apple Health."

        // Unlink Confirmation Alert (Ellipsis Menu)
        static let ellipsisUnlinkConfirmTitle = "Unlink workout from Apple Health?"
        static let ellipsisUnlinkConfirmMessage = "This will delete all Apple Health\u{2013}sourced summary data for this workout, and you won't be able to link it back.G"
        static let ellipsisUnlinkConfirmDestructive = "Unlink"

        // Source Name Display
        static let appleWorkoutName = "Apple Workout"
        static let unknownSourceName = "another app"

        // Log Workout — HealthKit-Linked Field Popovers
        static func fieldPopoverCopy(for field: HKOwnedField) -> String {
            switch field {
            case .date:
                return "Date is sourced from Apple Health and can't be edited here. Unlink the workout to edit it in FitNavi."
            case .startTime:
                return "Start time is sourced from Apple Health and can't be edited here. Unlink the workout to edit it in FitNavi."
            case .duration:
                return "Duration is sourced from Apple Health and can't be edited here. Unlink the workout to edit it in FitNavi."
            case .distance:
                return "Distance is sourced from Apple Health and can't be edited here. Unlink the workout to edit it in FitNavi."
            }
        }
    }

    // MARK: - Scheduled Workout

    static let scheduledWorkoutStatuses = ["planned", "completed", "skipped"]

    static let recurrenceRules = ["weekly", "biweekly"]

    static let recurrenceLookaheadWeeks = 12
    static let recurrenceRegenerationThreshold = 4

    // MARK: - Activity Rings

    enum ActivityRings {
        // Card States
        static let cardHeader = "Activity Rings"
        static let moveLabel = "MOVE"
        static let exerciseLabel = "EXERCISE"
        static let standLabel = "STAND"
        static let moveUnit = "cal"
        static let exerciseUnit = "min"
        static let standUnit = "hours"

        // Three Dynamic Card States
        static let stateConnectAppleHealthMessage = "Connect Apple Health to track your activity rings."
        static let stateConnectAppleHealthCTA = "Connect"
        static let statePairAppleWatchMessage = "Pair an Apple Watch to see your Move, Exercise, and Stand activity here."

        // Workout Contribution Caption
        static func captionFromSingleWorkout(value: Int, unit: String, workoutName: String) -> String {
            "+\(value) \(unit) from today's \(workoutName)"
        }
        static func captionFromMultipleWorkouts(value: Int, unit: String) -> String {
            "+\(value) \(unit) from today's workouts"
        }

        // Weekly Closure Rate Chip
        static func weeklyClosureChip(count: Int) -> String {
            "Closed all rings \(count) \(count == 1 ? "day" : "days") this week."
        }

        // Settings Modal
        static let settingsModalHeading = "Configure Activity Rings"
        static let settingsModalMoveSliderLabel = "Move Goal (calories)"
        static let settingsModalExerciseSliderLabel = "Exercise Goal (minutes)"
        static let settingsModalStandSliderLabel = "Stand Goal (hours)"
        static let settingsModalResetButton = "Reset to defaults"
        static let settingsModalImportButton = "Import from Apple Health"
        static let settingsModalImportDisabledCaption = "Connect Apple Health to import your goals."

        // Activity Detail Sheet
        static let detailSheetHeading = "Activity"
        static let detailSheetRangeToggle7d = "7 days"
        static let detailSheetRangeToggle30d = "30 days"
        static let detailSheetMoveSparklineLabel = "Move"
        static let detailSheetExerciseSparklineLabel = "Exercise"
        static let detailSheetStandSparklineLabel = "Stand"
        static let detailSheetClosureHeatmapHeading = "Ring closure heatmap"
        static let detailSheetEmptyMessage = "Not enough data yet — wear your Apple Watch and check back."

        // Ring Chevron SF Symbols
        static let moveChevron = "chevron.right"
        static let exerciseChevron = "chevron.right.2"
        static let standChevron = "chevron.up"

        // Slider Ranges and Increments
        static let moveRange: ClosedRange<Double> = 1...2000
        static let moveIncrement: Double = 10
        static let moveDefault = 500
        static let exerciseRange: ClosedRange<Double> = 1...240
        static let exerciseIncrement: Double = 5
        static let exerciseDefault = 30
        static let standRange: ClosedRange<Double> = 1...24
        static let standIncrement: Double = 1
        static let standDefault = 12

        static func snapToIncrement(_ value: Int, increment: Int) -> Int {
            guard increment > 0 else { return value }
            return Int((Double(value) / Double(increment)).rounded()) * increment
        }
    }

    // MARK: - Chart Info Modal Copy

    struct ChartInfoCopy {
        let title: String
        let intro: String
        let sections: [(heading: String, body: String)]
    }

    static let chartInfoModalCopy: [String: ChartInfoCopy] = [
        "strengthTracker": ChartInfoCopy(
            title: "About Strength Tracker",
            intro: "Strength Tracker shows how the heaviest weight you lift for a single exercise changes over time. Pick an exercise from the dropdown to see how your top set has trended in recent sessions.",
            sections: [
                ("How it's calculated", "Each data point on the chart is the heaviest weight you lifted for the selected exercise on that date, taken from the top set across all of that day's matching workouts. If you trained the same exercise twice in one day, only the heavier of the two sets is plotted."),
                ("Time range", "The compact card toggles between 30, 60, and 90 days. Tap into the detail view for wider ranges: 30 days, 90 days, 6 months, 1 year, or All Time."),
                ("What's tracked", "Only sets with a recorded weight count toward the trend. Bodyweight exercises (logged without a weight value) aren't included — they don't have a number to plot. Exercise names are matched case-insensitively, so \"Bench Press\" and \"bench press\" share the same line."),
                ("Minimum Data Threshold", "At least 2 workouts containing the selected exercise with a recorded weight are needed before the chart can render. Until then, you'll see a prompt to log more sessions.")
            ]
        ),
        "trainingFrequency": ChartInfoCopy(
            title: "About Training Frequency",
            intro: "Training Frequency shows how many workouts you've completed each week over the last 8 weeks.",
            sections: [
                ("How it's calculated", "Each bar is the count of workouts whose date falls within that calendar week (Monday 12:00 AM through Sunday 11:59 PM). Every workout type counts equally — a yoga session and a strength session each add one to the bar for that week."),
                ("Time range", "The compact card shows the 8 most recent calendar weeks, including the current in-progress week. Tap into the detail view for wider ranges: 8 weeks, 6 months, 1 year, or All Time."),
                ("Minimum Data Threshold", "You need at least one full Monday–Sunday week with at least one logged workout before the chart renders.")
            ]
        ),
        "personalRecords": ChartInfoCopy(
            title: "About Personal Records",
            intro: "Personal Records compares your most recent PR for an exercise against the PR before it, so you can see how much you improved on your latest breakthrough.",
            sections: [
                ("What counts as a PR", "A PR is recorded the first time you exceed your previous heaviest weight for a given exercise. The very first time you log an exercise establishes your baseline — that workout isn't a PR by itself. Every subsequent workout that beats your highest weight to date logs a new PR event."),
                ("How records are tracked", "PR events are calculated per exercise name (case-insensitive) and ordered chronologically by workout date. If you log the same exercise on multiple days at the same weight, no new PR is logged — the weight has to exceed the previous record. Bodyweight exercises (logged without a weight) aren't tracked because there's no number to compare."),
                ("What you'll see", "The dropdown lists every exercise that has at least one PR event, sorted alphabetically. Selecting an exercise shows two bars: your previous record on the left and your most recent record on the right, with the date each was set."),
                ("Minimum Data Threshold", "At least one exercise needs at least one PR event before the chart renders. If you've only ever lifted the same weight on a given exercise, no PR exists yet.")
            ]
        ),
        "trainingLoadTrend": ChartInfoCopy(
            title: "About Training Load Trend",
            intro: "Training Load Trend plots your daily training load score over the last 14 days, color-coded by zone, so you can spot overtraining patterns and recovery windows at a glance.",
            sections: [
                ("How training load is calculated", "Each day's score is a 0–100 rating that combines the volume, intensity, and recency of your recent workouts. Recent sessions count more than older ones — stress decays over about 10 days. Your experience level (set via long-press → Configure Settings on the Training Load widget) affects how quickly stress decays and how much load you can absorb before the score climbs."),
                ("Zones", "Each dot is colored by its zone:\n- Low (1–30, green): well recovered\n- Moderate (31–55, yellow): some accumulated fatigue\n- High (56–80, dark yellow): significant fatigue\n- Peak (81–100, red): high stress, prioritize recovery"),
                ("The 7-day average line", "The dashed blue line is your 7-day rolling average, smoothing out single-day spikes so you can see the underlying trend. A rising line over a flat dot pattern means your overall load is climbing; a falling line means you're tapering."),
                ("Time range", "The compact card shows the last 14 days. Tap into the detail view for wider ranges: 14 days, 30 days, 90 days, or 6 months."),
                ("Minimum Data Threshold", "At least 3 days with at least one workout each in the last 14 days are needed before the chart renders.")
            ]
        ),
        "workoutVolume": ChartInfoCopy(
            title: "About Workout Volume",
            intro: "Workout Volume tracks the total weight you've moved per session over time. Each data point is one workout — together they show whether you're progressively overloading.",
            sections: [
                ("How volume is calculated", "For every set in a workout, volume is sets × reps × weight. Those values are summed across all exercises in the session to produce a single workout volume number. Bodyweight exercises (logged without a weight) count as if the weight were 1, since they still represent work performed."),
                ("What's included", "Only Strength Training and HIIT workouts appear on the chart. Cardio, yoga, pilates, and other types don't track exercise sets the same way, so including them would distort the trend."),
                ("Time range", "The compact card toggles between 30, 60, and 90 days. Tap into the detail view for wider ranges: 30 days, 90 days, 6 months, 1 year, or All Time."),
                ("Minimum Data Threshold", "At least 2 Strength Training or HIIT workouts with at least one logged exercise set are needed before the chart renders.")
            ]
        ),
        "rpeTrend": ChartInfoCopy(
            title: "About Effort Trend",
            intro: "Effort Trend shows your average perceived effort per week, so you can see whether your training intensity is creeping up, holding steady, or trending down.",
            sections: [
                ("How it's calculated", "Effort uses a 1–10 scale where 1 is barely a warm-up and 10 is an all-out max effort. Each bar is the average of every effort rating you logged within that calendar week (Monday through Sunday). Workouts you didn't rate aren't counted — they don't pull the average up or down."),
                ("The reference line", "The dashed line at Effort 7 marks the rough threshold between hard and very hard sessions. Several weeks averaging well above 7 in a row may signal it's time for a deload."),
                ("Time range", "The compact card shows the 8 most recent calendar weeks, including the current in-progress week. Tap into the detail view for wider ranges: 8 weeks, 6 months, 1 year, or All Time."),
                ("Apple Health import", "If you record a workout on Apple Watch and rate its effort there (iOS 18 or later), that effort score imports into FitNavi automatically when the workout is linked — but only if you haven't already entered an effort rating yourself. Your manually entered ratings always win."),
                ("Minimum Data Threshold", "At least one full Monday–Sunday week with at least one workout that has a recorded effort rating is needed before the chart renders.")
            ]
        ),
        "workoutTypeBreakdown": ChartInfoCopy(
            title: "About Workout Type Breakdown",
            intro: "Workout Type Breakdown shows how your training is distributed across workout types, so you can see whether your routine is balanced or concentrated in one area.",
            sections: [
                ("How it's calculated", "Each segment of the donut is the count of workouts of that type within the selected time range, divided by your total workout count. A 50% Strength Training slice means half of all your sessions in the period were Strength Training."),
                ("Workout types", "Six categories — Strength Training, HIIT, Cardio, Yoga, Pilates, and Other. Each has a fixed color shown in the legend. Workouts imported from Apple Health are mapped to one of these six based on their HealthKit activity type."),
                ("Time range", "The compact card toggles between 30 days, 60 days, 90 days, and All Time. Tap into the detail view for an additional 1 year option. \"All Time\" includes every workout you've ever logged."),
                ("Minimum Data Threshold", "At least 2 workouts of any type are needed before the chart renders.")
            ]
        ),
        "sessionDuration": ChartInfoCopy(
            title: "About Session Duration",
            intro: "Session Duration shows how long your workouts have been on average each week, so you can manage your time and pacing.",
            sections: [
                ("How it's calculated", "Each bar is the average duration in minutes of all logged workouts within that calendar week (Monday through Sunday). Workouts you didn't enter a duration for aren't counted — they don't have a number to average."),
                ("Time range", "The compact card shows the 8 most recent calendar weeks, including the current in-progress week. Tap into the detail view for wider ranges: 8 weeks, 6 months, 1 year, or All Time."),
                ("Apple Health import", "Durations from Apple Watch and other Health-connected apps are imported automatically when you link a workout, so you don't need to re-enter them."),
                ("Minimum Data Threshold", "At least one full Monday–Sunday week with at least one workout that has a recorded duration is needed before the chart renders.")
            ]
        )
    ]
}
