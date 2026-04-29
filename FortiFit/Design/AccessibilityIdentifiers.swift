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
    static let homeWidget_trainingLoad_seeInfo = "homeWidget_trainingLoad_seeInfo"
    static let homeWidget_powerLevel_seeInfo = "homeWidget_powerLevel_seeInfo"
    static let homeWidget_trainingLoad_configureSettings = "homeWidget_trainingLoad_configureSettings"
    static let homeWidget_weeklyStreak_configureSettings = "homeWidget_weeklyStreak_configureSettings"

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

    // MARK: - Workout Detail Summary Stat Cards

    static let workoutDetail_summaryCard_effort = "workoutDetail_summaryCard_effort"
    static let workoutDetail_summaryCard_duration = "workoutDetail_summaryCard_duration"
    static let workoutDetail_summaryCard_distance = "workoutDetail_summaryCard_distance"
    static let workoutDetail_summaryCard_avgHR = "workoutDetail_summaryCard_avgHR"
    static let workoutDetail_summaryCard_maxHR = "workoutDetail_summaryCard_maxHR"
    static let workoutDetail_summaryCard_activeKcal = "workoutDetail_summaryCard_activeKcal"
    static let workoutDetail_summaryCard_totalKcal = "workoutDetail_summaryCard_totalKcal"
    static let workoutDetail_summaryCard_elevation = "workoutDetail_summaryCard_elevation"
    static let workoutDetail_summaryCard_exerciseMinutes = "workoutDetail_summaryCard_exerciseMinutes"
    static let metricDetailSheet_closeButton = "metricDetailSheet_closeButton"

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

    // MARK: - Match Prompt Sheet

    static let matchPromptSheetLinkButton = "matchPromptSheet_linkButton"
    static let matchPromptSheetKeepSeparateButton = "matchPromptSheet_keepSeparateButton"
    static let matchPromptSheetDecideLaterButton = "matchPromptSheet_decideLaterButton"

    // MARK: - Trends

    static let trendsEllipsisMenu = "trendsEllipsisMenu"
    static let trendsAddChartsMenuItem = "trendsAddChartsMenuItem"
    static let addChartsMenuOverlay = "addChartsMenuOverlay"
    static let trendsChart_seeInfoMenuItem = "trendsChart_seeInfoMenuItem"
    static let seeInfoModal_closeButton = "seeInfoModal_closeButton"

    // MARK: - Helpers

    /// Sanitizes a display string for use in an identifier (removes spaces).
    static func optionIdentifier(prefix: String, option: String) -> String {
        "\(prefix)_\(option.replacingOccurrences(of: " ", with: ""))"
    }
}
