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
    static let homeWidget_todaysPlan_completeWorkoutMenuItem = "homeWidget_todaysPlan_completeWorkoutMenuItem"
    static let homeWidget_todaysPlan_silhouette = "homeWidget_todaysPlan_silhouette"

    static func addWidgetRow(_ widgetType: String) -> String {
        "addWidgetRow_\(widgetType)"
    }

    // MARK: - Log Workout

    static let workoutNameInput = "workoutNameInput"
    static let workoutTypeDropdown = "workoutTypeDropdown"
    static let workoutTypeOptionPrefix = "workoutTypeOption"
    static let effortDropdown = "effortDropdown"
    static let effortOptionPrefix = "effortOption"
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

    // MARK: - Edit Workout (Strength / HIIT)

    static let editWorkoutEllipsisMenu = "editWorkout_ellipsisMenu"
    static let editWorkoutUseTemplateMenuItem = "editWorkout_useTemplateMenuItem"
    static let editWorkoutTemplateSelectorOverlay = "editWorkout_templateSelectorOverlay"

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

    // MARK: - Source Info Sheet

    static let sourceInfoSheetReadOnlyCallout = "sourceInfoSheet_readOnlyCallout"
    static let sourceInfoSheetPermanentUnlinkCallout = "sourceInfoSheet_permanentUnlinkCallout"
    static let sourceInfoSheetDoneButton = "sourceInfoSheet_doneButton"
    static let sourceInfoSheetUnlinkConfirmButton = "sourceInfoSheet_unlinkConfirmButton"
    static let sourceInfoSheetUnlinkCancelButton = "sourceInfoSheet_unlinkCancelButton"
    static let sourceInfoSheetLastSyncedRow = "sourceInfoSheet_lastSyncedRow"

    // MARK: - Log Workout (HealthKit Field Info Icons)

    static let logWorkoutHkFieldInfoIconDate = "logWorkout_hkFieldInfoIcon_date"
    static let logWorkoutHkFieldInfoIconStartTime = "logWorkout_hkFieldInfoIcon_startTime"
    static let logWorkoutHkFieldInfoIconDuration = "logWorkout_hkFieldInfoIcon_duration"
    static let logWorkoutHkFieldInfoIconDistance = "logWorkout_hkFieldInfoIcon_distance"

    // MARK: - Match Prompt Sheet

    static let matchPromptSheetLinkButton = "matchPromptSheet_linkButton"
    static let matchPromptSheetKeepSeparateButton = "matchPromptSheet_keepSeparateButton"
    static let matchPromptSheetDecideLaterButton = "matchPromptSheet_decideLaterButton"

    // MARK: - Activity Rings Widget

    static let homeWidget_appleActivity_card = "homeWidget_appleActivity_card"
    static let homeWidget_appleActivity_state_connectAppleHealth = "homeWidget_appleActivity_state_connectAppleHealth"
    static let homeWidget_appleActivity_state_pairAppleWatch = "homeWidget_appleActivity_state_pairAppleWatch"
    static let homeWidget_appleActivity_connectButton = "homeWidget_appleActivity_connectButton"
    static let homeWidget_appleActivity_moveRing = "homeWidget_appleActivity_moveRing"
    static let homeWidget_appleActivity_exerciseRing = "homeWidget_appleActivity_exerciseRing"
    static let homeWidget_appleActivity_standRing = "homeWidget_appleActivity_standRing"
    static let homeWidget_appleActivity_weeklyClosureChip = "homeWidget_appleActivity_weeklyClosureChip"
    static let homeWidget_appleActivity_seeInfo = "homeWidget_appleActivity_seeInfo"
    static let homeWidget_appleActivity_configureSettings = "homeWidget_appleActivity_configureSettings"

    // MARK: - Activity Rings Settings Modal

    static let activityRingsSettings_moveSlider = "activityRingsSettings_moveSlider"
    static let activityRingsSettings_exerciseSlider = "activityRingsSettings_exerciseSlider"
    static let activityRingsSettings_standSlider = "activityRingsSettings_standSlider"
    static let activityRingsSettings_resetButton = "activityRingsSettings_resetButton"
    static let activityRingsSettings_importButton = "activityRingsSettings_importButton"

    // MARK: - Activity Detail Sheet

    static let activityDetailSheet_closeButton = "activityDetailSheet_closeButton"
    static let activityDetailSheet_range7d = "activityDetailSheet_range7d"
    static let activityDetailSheet_range30d = "activityDetailSheet_range30d"
    static let activityDetailSheet_moveSparkline = "activityDetailSheet_moveSparkline"
    static let activityDetailSheet_exerciseSparkline = "activityDetailSheet_exerciseSparkline"
    static let activityDetailSheet_standSparkline = "activityDetailSheet_standSparkline"
    static let activityDetailSheet_closureHeatmap = "activityDetailSheet_closureHeatmap"

    // MARK: - Trends

    static let trendsEllipsisMenu = "trendsEllipsisMenu"
    static let trendsAddChartsMenuItem = "trendsAddChartsMenuItem"
    static let addChartsMenuOverlay = "addChartsMenuOverlay"
    static let trendsChart_seeInfoMenuItem = "trendsChart_seeInfoMenuItem"
    static let seeInfoModal_closeButton = "seeInfoModal_closeButton"

    // MARK: - Trends Chart Cards (Phase 6.1)

    static func trendsChartCard(_ chartId: String) -> String {
        "trendsChart_\(chartId)_card"
    }

    static func trendsChartHeaderSummary(_ chartId: String) -> String {
        "trendsChart_\(chartId)_headerSummary"
    }

    static func trendsChartDataPoint(_ chartId: String, index: Int) -> String {
        "trendsChart_\(chartId)_dataPoint_\(index)"
    }

    static let trendsChart_workoutTypeBreakdown_centerLabel = "trendsChart_workoutTypeBreakdown_centerLabel"

    static func trendsChartSelectionAnnotation(_ chartId: String) -> String {
        "trendsChart_\(chartId)_selectionAnnotation"
    }

    static func trendsChartExpandButton(_ chartId: String) -> String {
        "trendsChart_\(chartId)_expandButton"
    }

    // MARK: - Trends Chart Detail (Phase 6.2)

    static func trendsChartDetailCard(_ chartId: String) -> String {
        "trendsChartDetail_\(chartId)_card"
    }

    static func trendsChartDetailBackButton(_ chartId: String) -> String {
        "trendsChartDetail_\(chartId)_backButton"
    }

    static func trendsChartDetailHeaderSummary(_ chartId: String) -> String {
        "trendsChartDetail_\(chartId)_headerSummary"
    }

    static func trendsChartDetailSeeInfoButton(_ chartId: String) -> String {
        "trendsChartDetail_\(chartId)_seeInfoButton"
    }

    static func trendsChartDetailRangeToggle(_ chartId: String, range: String) -> String {
        "trendsChartDetail_\(chartId)_rangeToggle_\(range)"
    }

    static func trendsChartDetailDataPoint(_ chartId: String, index: Int) -> String {
        "trendsChartDetail_\(chartId)_dataPoint_\(index)"
    }

    static func trendsChartDetailSelectionAnnotation(_ chartId: String) -> String {
        "trendsChartDetail_\(chartId)_selectionAnnotation"
    }

    static func trendsChartDetailPRTimelinePoint(index: Int) -> String {
        "trendsChartDetail_personalRecords_timelinePoint_\(index)"
    }

    static func trendsChartDetailBreakdownLegendRow(index: Int) -> String {
        "trendsChartDetail_workoutTypeBreakdown_legendRow_\(index)"
    }

    static func trendsChartDetailBreakdownSortHeader(column: String) -> String {
        "trendsChartDetail_workoutTypeBreakdown_legendSortHeader_\(column)"
    }

    // MARK: - Helpers

    /// Sanitizes a display string for use in an identifier (removes spaces).
    static func optionIdentifier(prefix: String, option: String) -> String {
        "\(prefix)_\(option.replacingOccurrences(of: " ", with: ""))"
    }
}
