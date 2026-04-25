import Foundation
import SwiftUI

enum AppConstants {
    static let workoutTypes = [
        "Strength Training",
        "HIIT",
        "Sprints",
        "Cardio",
        "Yoga",
        "Pilates"
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
        "Sprints": 0.9,
        "Cardio": 0.7,
        "Pilates": 0.5,
        "Yoga": 0.3
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
        "Sprints": "figure.run",
        "Cardio": "figure.mixed.cardio",
        "Yoga": "figure.yoga",
        "Pilates": "figure.pilates"
    ]

    // MARK: - Workout Detail Summary Icons
    static let summaryFieldSymbols: [String: String] = [
        "RPE": "heart.gauge.open",
        "Duration": "clock",
        "Distance": "ruler"
    ]

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

    // MARK: - Widgets

    static let widgetTypes = [
        "trainingLoad",
        "workoutInfo",
        "weekStreak",
        "powerLevel",
        "todaysPlan"
    ]

    static let defaultHomeWidgets = [
        "trainingLoad",
        "powerLevel",
        "todaysPlan"
    ]

    static let widgetDisplayNames: [String: String] = [
        "trainingLoad": "Training Load",
        "workoutInfo": "Workout Info",
        "weekStreak": "Weekly Streak",
        "powerLevel": "Power Level",
        "todaysPlan": "Today's Plan"
    ]

    static let widgetDescriptions: [String: String] = [
        "trainingLoad": "Shows your accumulated training stress score and recovery readiness based on recent workout intensity, volume, and frequency.",
        "workoutInfo": "Displays your most recent workout and total workout count at a glance.",
        "weekStreak": "Tracks how many consecutive weeks you've met your weekly workout target.",
        "powerLevel": "Measures your average strength volume trend over the last 30 days across Strength Training and HIIT workouts.",
        "todaysPlan": "Shows your scheduled workout for today so you can jump straight into logging."
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
        "rpeTrend": "RPE Trend",
        "workoutTypeBreakdown": "Workout Type Breakdown",
        "sessionDuration": "Session Duration"
    ]

    static let trendsChartDescriptions: [String: String] = [
        "strengthTracker": "Tracks your max weight for a selected exercise over time so you can see strength progression at a glance.",
        "trainingFrequency": "Shows how many workouts you completed each week.",
        "personalRecords": "Compares your latest personal record against the previous record for each exercise.",
        "trainingLoadTrend": "Visualizes your daily training load score over the last two weeks so you can spot overtraining or recovery windows.",
        "workoutVolume": "Tracks your total training volume per session over time to reveal whether you're progressively overloading.",
        "rpeTrend": "Shows your average perceived exertion per week so you can monitor training intensity over time.",
        "workoutTypeBreakdown": "Shows the distribution of your workout types so you can see if your training is balanced.",
        "sessionDuration": "Tracks your average workout duration per week to help you manage your time in the gym."
    ]

    // MARK: - Workout Type Chart Colors

    static let workoutTypeChartColors: [String: Color] = [
        "Strength Training": Color(hex: "3b82f6"),   // Primary Accent Blue
        "HIIT": Color(hex: "60a5fa"),                 // Secondary Blue
        "Sprints": Color(hex: "4B2893"),              // Purple
        "Cardio": Color(hex: "10b981"),               // Positive Green
        "Yoga": Color(hex: "FFBF51"),                 // Orange
        "Pilates": Color(hex: "ef4444")               // Alert Red
    ]

    // MARK: - Chart Data Thresholds

    static let chartEmptyMessages: [String: String] = [
        "strengthTracker": "Log more workouts to display strength trends.",
        "trainingFrequency": "Complete your first full week to see frequency trends.",
        "personalRecords": "Log more workouts to display personal records.",
        "trainingLoadTrend": "Log more workouts to display load trends.",
        "workoutVolume": "Log more Strength or HIIT workouts to display volume trends.",
        "rpeTrend": "Log workouts with RPE ratings to display effort trends.",
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

    // MARK: - Scheduled Workout

    static let scheduledWorkoutStatuses = ["planned", "completed", "skipped"]

    static let recurrenceRules = ["weekly", "biweekly"]

    static let recurrenceLookaheadWeeks = 12
    static let recurrenceRegenerationThreshold = 4
}
