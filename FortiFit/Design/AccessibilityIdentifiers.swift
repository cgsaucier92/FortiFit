import Foundation

/// Single source of truth for accessibility identifiers shared between
/// SwiftUI views and XCUI smoke tests. See TESTING.md § Accessibility Identifiers.
enum AccessibilityID {

    // MARK: - Tab Bar

    static let tabBarHome = "tabBar_home"
    static let tabBarWorkouts = "tabBar_workouts"
    static let tabBarPlan = "tabBar_plan"
    static let tabBarTrends = "tabBar_trends"
    static let tabBarGoals = "tabBar_goals"

    // MARK: - Home

    static let logWorkoutCTA = "logWorkoutCTA"
    static let settingsGearIcon = "settingsGearIcon"
    static let homeEllipsisMenu = "homeEllipsisMenu"
    static let addWidgetsMenuItem = "addWidgetsMenuItem"
    static let addWidgetsMenuDismiss = "addWidgetsMenuDismiss"

    static func addWidgetRow(_ widgetType: String) -> String {
        "addWidgetRow_\(widgetType)"
    }

    // MARK: - Log Workout

    static let workoutNameInput = "workoutNameInput"
    static let workoutTypeDropdown = "workoutTypeDropdown"
    static let workoutTypeOptionPrefix = "workoutTypeOption"
    static let addExerciseButton = "addExerciseButton"
    static let saveWorkoutButton = "saveWorkoutButton"
    static let durationInput = "durationInput"
    static let distanceInput = "distanceInput"

    static func exerciseNameInput(_ exerciseIndex: Int) -> String {
        "exerciseNameInput_\(exerciseIndex)"
    }

    static func setsInput(_ exerciseIndex: Int, _ rowIndex: Int) -> String {
        "setsInput_\(exerciseIndex)_\(rowIndex)"
    }

    static func repsInput(_ exerciseIndex: Int, _ rowIndex: Int) -> String {
        "repsInput_\(exerciseIndex)_\(rowIndex)"
    }

    static func weightInput(_ exerciseIndex: Int, _ rowIndex: Int) -> String {
        "weightInput_\(exerciseIndex)_\(rowIndex)"
    }

    // MARK: - Goals

    static let addGoalButton = "addGoalButton"
    static let goalExerciseDropdown = "goalExerciseDropdown"
    static let goalExerciseOptionPrefix = "goalExerciseOption"
    static let goalTargetWeightInput = "goalTargetWeightInput"
    static let saveGoalButton = "saveGoalButton"

    // MARK: - Settings

    static let settingsWeightUnitToggle = "settings_weightUnitToggle"
    static let settingsBackButton = "settingsBackButton"
    static let settingsAppleHealthToggle = "settings_appleHealthToggle"
    static let settingsAppleHealthSyncNowButton = "settings_appleHealthSyncNowButton"
    static let settingsAppleHealthOpenSettingsButton = "settings_appleHealthOpenSettingsButton"

    // MARK: - Log Workout (HealthKit)

    static let logWorkoutDateReadOnlyHelper = "logWorkout_dateReadOnlyHelper"
    static let logWorkoutDurationReadOnlyHelper = "logWorkout_durationReadOnlyHelper"
    static let logWorkoutDistanceReadOnlyHelper = "logWorkout_distanceReadOnlyHelper"

    // MARK: - Workout Detail

    static let workoutDetailEllipsis = "workoutDetailEllipsis"
    static let saveAsTemplateMenuItem = "saveAsTemplateMenuItem"
    static let saveTemplateConfirmButton = "saveTemplateConfirmButton"
    static let workoutDetailHealthSourceIndicator = "workoutDetail_healthSourceIndicator"
    static let workoutDetailHealthUnlinkButton = "workoutDetail_healthUnlinkButton"

    // MARK: - Workout List

    static let workoutsEllipsisMenu = "workoutsEllipsisMenu"
    static let viewSavedTemplatesMenuItem = "viewSavedTemplatesMenuItem"

    static func workoutTypeCard(_ typeName: String) -> String {
        "workoutTypeCard_\(typeName.replacingOccurrences(of: " ", with: ""))"
    }

    // MARK: - Plan

    static let planEllipsisMenu = "planEllipsisMenu"
    static let planSavedTemplatesMenuItem = "planSavedTemplatesMenuItem"
    static let planAddButton = "planAddButton"
    static let scheduleWorkoutConfirmButton = "scheduleWorkoutConfirmButton"

    static func templateSelectionRow(_ index: Int) -> String {
        "templateSelectionRow_\(index)"
    }

    static func scheduledWorkoutCard(_ index: Int) -> String {
        "scheduledWorkoutCard_\(index)"
    }

    static func planLoggedOnlyCard(_ index: Int) -> String {
        "planLoggedOnlyCard_\(index)"
    }

    static let planRemoveFromPlanMenuItem = "planRemoveFromPlanMenuItem"
    static let planScheduledCardSkipMenuItem = "planScheduledCardSkipMenuItem"
    static let planScheduledCardRestoreMenuItem = "planScheduledCardRestoreMenuItem"
    static let planRemoveUndoToastAction = "planRemoveUndoToastAction"

    // MARK: - Workout Detail

    static let workoutDetailShowOnPlanMenuItem = "workoutDetailShowOnPlanMenuItem"

    // MARK: - Trends

    static let trendsEllipsisMenu = "trendsEllipsisMenu"
    static let trendsAddChartsMenuItem = "trendsAddChartsMenuItem"
    static let addChartsMenuOverlay = "addChartsMenuOverlay"

    // MARK: - Helpers

    /// Sanitizes a display string for use in an identifier (removes spaces).
    static func optionIdentifier(prefix: String, option: String) -> String {
        "\(prefix)_\(option.replacingOccurrences(of: " ", with: ""))"
    }
}
