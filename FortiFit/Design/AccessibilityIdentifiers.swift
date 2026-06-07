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
    static let homeWidget_powerLevel_card = "homeWidget_powerLevel_card"
    static let homeWidget_powerLevel_deltaCaption = "homeWidget_powerLevel_deltaCaption"
    static let homeWidget_powerLevel_gauge = "homeWidget_powerLevel_gauge"
    static let homeWidget_powerLevel_gaugeThumb = "homeWidget_powerLevel_gaugeThumb"
    static let homeWidget_powerLevel_gaugeOverflowIndicator = "homeWidget_powerLevel_gaugeOverflowIndicator"
    static let homeWidget_powerLevel_gaugeThumbPulse = "homeWidget_powerLevel_gaugeThumbPulse"
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
    static let workoutDetail_summaryCard_effortBars = "workoutDetail_summaryCard_effortBars"
    static let metricDetailSheet_closeButton = "metricDetailSheet_closeButton"
    static let metricDetailSheet_hero_effortBars = "metricDetailSheet_hero_effortBars"

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
    static let activityRingsSettings_importButton = "activityRingsSettings_importButton"
    static let activityRingsSettings_doneButton = "activityRingsSettings_doneButton"

    // MARK: - Settings Modal Done Buttons (Phase 8.8)

    static let weeklyStreakSettings_doneButton = "weeklyStreakSettings_doneButton"
    static let trainingLoadSettings_doneButton = "trainingLoadSettings_doneButton"

    // MARK: - Activity Detail Sheet

    static let activityDetailSheet_closeButton = "activityDetailSheet_closeButton"
    static let activityDetailSheet_range7d = "activityDetailSheet_range7d"
    static let activityDetailSheet_range30d = "activityDetailSheet_range30d"
    static let activityDetailSheet_moveSparkline = "activityDetailSheet_moveSparkline"
    static let activityDetailSheet_exerciseSparkline = "activityDetailSheet_exerciseSparkline"
    static let activityDetailSheet_standSparkline = "activityDetailSheet_standSparkline"
    static let activityDetailSheet_closureHeatmap = "activityDetailSheet_closureHeatmap"
    static let activityDetailSheet_seeInfoButton = "activityDetailSheet_seeInfoButton"
    static let activityDetailSheet_configureSettingsButton = "activityDetailSheet_configureSettingsButton"

    static let activityDetailSheet_moveChartSelectionAnnotation = "activityDetailSheet_moveChartSelectionAnnotation"
    static let activityDetailSheet_exerciseChartSelectionAnnotation = "activityDetailSheet_exerciseChartSelectionAnnotation"
    static let activityDetailSheet_standChartSelectionAnnotation = "activityDetailSheet_standChartSelectionAnnotation"

    static func activityDetailSheet_moveChartDataPoint(_ index: Int) -> String {
        "activityDetailSheet_moveChartDataPoint_\(index)"
    }

    static func activityDetailSheet_exerciseChartDataPoint(_ index: Int) -> String {
        "activityDetailSheet_exerciseChartDataPoint_\(index)"
    }

    static func activityDetailSheet_standChartDataPoint(_ index: Int) -> String {
        "activityDetailSheet_standChartDataPoint_\(index)"
    }

    // MARK: - Today's Plan Detail Sheet (Phase 8.8)

    static let todaysPlanDetailSheet_closeButton = "todaysPlanDetailSheet_closeButton"
    static let todaysPlanDetailSheet_emptyState = "todaysPlanDetailSheet_emptyState"
    // `todaysPlanDetailSheet_scheduleMoreButton` retired — chip removed from the Today's Plan
    // Detail Sheet (Phase 8.8 follow-up).

    static func todaysPlanDetailSheet_rowCompleteButton(scheduledWorkoutId: UUID) -> String {
        "todaysPlanDetailSheet_row_\(scheduledWorkoutId.uuidString)_completeButton"
    }

    // MARK: - Training Load Detail Sheet (Phase 8.8)

    static let trainingLoadDetailSheet_closeButton = "trainingLoadDetailSheet_closeButton"
    static let trainingLoadDetailSheet_hero = "trainingLoadDetailSheet_hero"
    static let trainingLoadDetailSheet_dailyChart = "trainingLoadDetailSheet_dailyChart"
    static let trainingLoadDetailSheet_chartSelectionAnnotation = "trainingLoadDetailSheet_chartSelectionAnnotation"

    static func trainingLoadDetailSheet_chartDataPoint(_ index: Int) -> String {
        "trainingLoadDetailSheet_chartDataPoint_\(index)"
    }

    static let trainingLoadDetailSheet_contributingWorkouts = "trainingLoadDetailSheet_contributingWorkouts"
    static let trainingLoadDetailSheet_weekComparison = "trainingLoadDetailSheet_weekComparison"
    static let trainingLoadDetailSheet_weekComparisonCaption = "trainingLoadDetailSheet_weekComparisonCaption"
    static let trainingLoadDetailSheet_recoveryCallout = "trainingLoadDetailSheet_recoveryCallout"
    static let trainingLoadDetailSheet_seeInfoButton = "trainingLoadDetailSheet_seeInfoButton"
    static let trainingLoadDetailSheet_configureSettingsButton = "trainingLoadDetailSheet_configureSettingsButton"
    static let trainingLoadDetailSheet_emptyState_coldStart = "trainingLoadDetailSheet_emptyState_coldStart"

    // MARK: - Weekly Streak Insights Sheet (Phase 8.8)

    static let weeklyStreakDetailSheet_closeButton = "weeklyStreakDetailSheet_closeButton"
    static let weeklyStreakDetailSheet_hero = "weeklyStreakDetailSheet_hero"
    static let weeklyStreakDetailSheet_statRow = "weeklyStreakDetailSheet_statRow"
    static let weeklyStreakDetailSheet_thisWeekRing = "weeklyStreakDetailSheet_thisWeekRing"
    static let weeklyStreakDetailSheet_heatmap = "weeklyStreakDetailSheet_heatmap"
    static let weeklyStreakDetailSheet_milestoneShelf = "weeklyStreakDetailSheet_milestoneShelf"
    static let weeklyStreakDetailSheet_configureSettingsButton = "weeklyStreakDetailSheet_configureSettingsButton"

    static func weeklyStreakDetailSheet_heatmapCell(_ index: Int) -> String {
        "weeklyStreakDetailSheet_heatmap_cell_\(index)"
    }

    static func weeklyStreakDetailSheet_milestone(_ mark: Int) -> String {
        "weeklyStreakDetailSheet_milestone_\(mark)"
    }

    // MARK: - Power Level Breakdown Sheet (Phase 8.8)

    static let powerLevelDetailSheet_closeButton = "powerLevelDetailSheet_closeButton"
    static let powerLevelDetailSheet_hero = "powerLevelDetailSheet_hero"
    static let powerLevelDetailSheet_topExercises = "powerLevelDetailSheet_topExercises"
    static let powerLevelDetailSheet_windowComparison = "powerLevelDetailSheet_windowComparison"
    static let powerLevelDetailSheet_nudge = "powerLevelDetailSheet_nudge"
    static let powerLevelDetailSheet_seeInfoButton = "powerLevelDetailSheet_seeInfoButton"

    static func powerLevelDetailSheet_topExerciseRow(_ index: Int) -> String {
        "powerLevelDetailSheet_topExerciseRow_\(index)"
    }

    // MARK: - Power Level Gauge (Phase 12)

    static let powerLevelDetailSheet_heroGauge = "powerLevelDetailSheet_heroGauge"
    static let powerLevelDetailSheet_heroGaugeThumb = "powerLevelDetailSheet_heroGaugeThumb"
    static let powerLevelDetailSheet_heroGaugeOverflowIndicator = "powerLevelDetailSheet_heroGaugeOverflowIndicator"
    static let powerLevelDetailSheet_heroGaugeThumbPulse = "powerLevelDetailSheet_heroGaugeThumbPulse"
    static let powerLevelDetailSheet_windowComparison_deltaChip = "powerLevelDetailSheet_windowComparison_deltaChip"
    static let powerLevelDetailSheet_windowComparison_previousBar = "powerLevelDetailSheet_windowComparison_previousBar"
    static let powerLevelDetailSheet_windowComparison_currentBar = "powerLevelDetailSheet_windowComparison_currentBar"

    // MARK: - Recovery Status Widget (Phase 11)

    static let homeWidget_recoveryStatus_card = "homeWidget_recoveryStatus_card"
    static let homeWidget_recoveryStatus_state_connectAppleHealth = "homeWidget_recoveryStatus_state_connectAppleHealth"
    static let homeWidget_recoveryStatus_state_sleepAccessDenied = "homeWidget_recoveryStatus_state_sleepAccessDenied"
    static let homeWidget_recoveryStatus_state_noSleepTracker = "homeWidget_recoveryStatus_state_noSleepTracker"
    static let homeWidget_recoveryStatus_state_live = "homeWidget_recoveryStatus_state_live"
    static let homeWidget_recoveryStatus_connectButton = "homeWidget_recoveryStatus_connectButton"
    static let homeWidget_recoveryStatus_openIOSSettingsButton = "homeWidget_recoveryStatus_openIOSSettingsButton"
    static let homeWidget_recoveryStatus_sleepHero = "homeWidget_recoveryStatus_sleepHero"
    static let homeWidget_recoveryStatus_sleepValue = "homeWidget_recoveryStatus_sleepValue"
    static let homeWidget_recoveryStatus_deepSleepCaption = "homeWidget_recoveryStatus_deepSleepCaption"
    static let homeWidget_recoveryStatus_lastWorkoutHero = "homeWidget_recoveryStatus_lastWorkoutHero"
    static let homeWidget_recoveryStatus_lastWorkoutValue = "homeWidget_recoveryStatus_lastWorkoutValue"
    static let homeWidget_recoveryStatus_lastWorkoutCaption = "homeWidget_recoveryStatus_lastWorkoutCaption"
    static let homeWidget_recoveryStatus_watermark = "homeWidget_recoveryStatus_watermark"
    static let homeWidget_recoveryStatus_seeInfo = "homeWidget_recoveryStatus_seeInfo"
    static let homeWidget_recoveryStatus_configureSettings = "homeWidget_recoveryStatus_configureSettings"

    // MARK: - Recovery Status Settings Modal (Phase 11)

    static let recoveryStatusSettings_modal = "recoveryStatusSettings_modal"
    static let recoveryStatusSettings_closeButton = "recoveryStatusSettings_closeButton"
    static let recoveryStatusSettings_targetSleepHoursSlider = "recoveryStatusSettings_targetSleepHoursSlider"
    static let recoveryStatusSettings_importButton = "recoveryStatusSettings_importButton"
    static let recoveryStatusSettings_doneButton = "recoveryStatusSettings_doneButton"

    // MARK: - Recovery Status Detail Sheet (Phase 11)

    static let recoveryStatusDetailSheet_sheet = "recoveryStatusDetailSheet_sheet"
    static let recoveryStatusDetailSheet_closeButton = "recoveryStatusDetailSheet_closeButton"
    static let recoveryStatusDetailSheet_hero = "recoveryStatusDetailSheet_hero"
    static let recoveryStatusDetailSheet_stagesBar = "recoveryStatusDetailSheet_stagesBar"
    static let recoveryStatusDetailSheet_stagesLegend = "recoveryStatusDetailSheet_stagesLegend"
    static let recoveryStatusDetailSheet_sleepEfficiencyCaption = "recoveryStatusDetailSheet_sleepEfficiencyCaption"
    static let recoveryStatusDetailSheet_sleepSparkline = "recoveryStatusDetailSheet_sleepSparkline"
    static let recoveryStatusDetailSheet_chartSelectionAnnotation = "recoveryStatusDetailSheet_chartSelectionAnnotation"

    static func recoveryStatusDetailSheet_chartDataPoint(_ index: Int) -> String {
        "recoveryStatusDetailSheet_chartDataPoint_\(index)"
    }

    static let recoveryStatusDetailSheet_last7NightsStatRow = "recoveryStatusDetailSheet_last7NightsStatRow"
    static let recoveryStatusDetailSheet_timeSinceWorkout = "recoveryStatusDetailSheet_timeSinceWorkout"
    static let recoveryStatusDetailSheet_timeSinceWorkout_headline = "recoveryStatusDetailSheet_timeSinceWorkout_headline"
    static let recoveryStatusDetailSheet_emptyState_coldStart = "recoveryStatusDetailSheet_emptyState_coldStart"
    static let recoveryStatusDetailSheet_seeInfoButton = "recoveryStatusDetailSheet_seeInfoButton"
    static let recoveryStatusDetailSheet_configureSettingsButton = "recoveryStatusDetailSheet_configureSettingsButton"

    static func recoveryStatusDetailSheet_timeSinceWorkout_typeRow(_ type: String) -> String {
        "recoveryStatusDetailSheet_timeSinceWorkout_typeRow_\(type.replacingOccurrences(of: " ", with: "_"))"
    }

    // MARK: - Linked Recovery & Load Composite (Phase 11)

    static let homeWidget_linkedRecoveryLoad_composite = "homeWidget_linkedRecoveryLoad_composite"
    static let homeWidget_linkedRecoveryLoad_unlinkMenuItem = "homeWidget_linkedRecoveryLoad_unlinkMenuItem"
    static let homeWidget_trainingLoad_sleepImpactChip = "homeWidget_trainingLoad_sleepImpactChip"

    // MARK: - Linked Recovery & Load Settings Modal (Phase 11)

    static let linkedRecoveryLoadSettings_modal = "linkedRecoveryLoadSettings_modal"
    static let linkedRecoveryLoadSettings_closeButton = "linkedRecoveryLoadSettings_closeButton"
    static let linkedRecoveryLoadSettings_experienceLevelSlider = "linkedRecoveryLoadSettings_experienceLevelSlider"
    static let linkedRecoveryLoadSettings_targetWorkoutDurationSlider = "linkedRecoveryLoadSettings_targetWorkoutDurationSlider"
    static let linkedRecoveryLoadSettings_targetSleepHoursSlider = "linkedRecoveryLoadSettings_targetSleepHoursSlider"
    static let linkedRecoveryLoadSettings_importButton = "linkedRecoveryLoadSettings_importButton"
    static let linkedRecoveryLoadSettings_doneButton = "linkedRecoveryLoadSettings_doneButton"

    // MARK: - Linked Recovery & Load Detail Sheet (Phase 11)

    static let linkedRecoveryLoadDetailSheet_sheet = "linkedRecoveryLoadDetailSheet_sheet"
    static let linkedRecoveryLoadDetailSheet_closeButton = "linkedRecoveryLoadDetailSheet_closeButton"
    static let linkedRecoveryLoadDetailSheet_dualHero = "linkedRecoveryLoadDetailSheet_dualHero"
    static let linkedRecoveryLoadDetailSheet_recoveryHero = "linkedRecoveryLoadDetailSheet_recoveryHero"
    static let linkedRecoveryLoadDetailSheet_loadHero = "linkedRecoveryLoadDetailSheet_loadHero"
    static let linkedRecoveryLoadDetailSheet_stagesBar = "linkedRecoveryLoadDetailSheet_stagesBar"
    static let linkedRecoveryLoadDetailSheet_sleepEfficiencyCaption = "linkedRecoveryLoadDetailSheet_sleepEfficiencyCaption"
    static let linkedRecoveryLoadDetailSheet_combinedChart = "linkedRecoveryLoadDetailSheet_combinedChart"
    static let linkedRecoveryLoadDetailSheet_combinedSelectionAnnotation = "linkedRecoveryLoadDetailSheet_combinedSelectionAnnotation"

    static func linkedRecoveryLoadDetailSheet_loadChartDataPoint(_ index: Int) -> String {
        "linkedRecoveryLoadDetailSheet_loadChartDataPoint_\(index)"
    }

    static func linkedRecoveryLoadDetailSheet_sleepChartDataPoint(_ index: Int) -> String {
        "linkedRecoveryLoadDetailSheet_sleepChartDataPoint_\(index)"
    }

    static let linkedRecoveryLoadDetailSheet_windowComparison = "linkedRecoveryLoadDetailSheet_windowComparison"
    static let linkedRecoveryLoadDetailSheet_windowComparisonCaption = "linkedRecoveryLoadDetailSheet_windowComparisonCaption"
    static let linkedRecoveryLoadDetailSheet_last3Nights = "linkedRecoveryLoadDetailSheet_last3Nights"
    static let linkedRecoveryLoadDetailSheet_contributingWorkouts = "linkedRecoveryLoadDetailSheet_contributingWorkouts"
    static let linkedRecoveryLoadDetailSheet_timeSinceWorkout = "linkedRecoveryLoadDetailSheet_timeSinceWorkout"
    static let linkedRecoveryLoadDetailSheet_timeSinceWorkout_headline = "linkedRecoveryLoadDetailSheet_timeSinceWorkout_headline"
    static let linkedRecoveryLoadDetailSheet_recoveryCallout = "linkedRecoveryLoadDetailSheet_recoveryCallout"
    static let linkedRecoveryLoadDetailSheet_seeInfoButton = "linkedRecoveryLoadDetailSheet_seeInfoButton"
    static let linkedRecoveryLoadDetailSheet_configureSettingsButton = "linkedRecoveryLoadDetailSheet_configureSettingsButton"

    static let linkedRecoveryLoadDetailSheet_windowComparison_chevron = "linkedRecoveryLoadDetailSheet_windowComparison_chevron"
    static let linkedRecoveryLoadDetailSheet_last3Nights_chevron = "linkedRecoveryLoadDetailSheet_last3Nights_chevron"
    static let linkedRecoveryLoadDetailSheet_contributingWorkouts_chevron = "linkedRecoveryLoadDetailSheet_contributingWorkouts_chevron"
    static let linkedRecoveryLoadDetailSheet_timeSinceWorkout_chevron = "linkedRecoveryLoadDetailSheet_timeSinceWorkout_chevron"

    static func linkedRecoveryLoadDetailSheet_timeSinceWorkout_typeRow(_ type: String) -> String {
        "linkedRecoveryLoadDetailSheet_timeSinceWorkout_typeRow_\(type.replacingOccurrences(of: " ", with: "_"))"
    }

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

    // MARK: - Watch Sync (Phase 8.7)

    static let settingsAppleWatchToggle = "settings_appleWatchToggle"
    static let settingsAppleWatchOpenSettingsButton = "settings_appleWatchOpenSettingsButton"

    static func scheduledWorkoutCardWatchSyncGlyph(_ index: Int) -> String {
        "scheduledWorkoutCard_\(index)_watchSyncGlyph"
    }

    static let editScheduledWorkout_watchSyncToggle = "editScheduledWorkout_watchSyncToggle"
    static let editScheduledWorkout_watchSyncInfoPopover = "editScheduledWorkout_watchSyncInfoPopover"
    static let editScheduledWorkout_recurrencePrompt_thisOnly = "editScheduledWorkout_recurrencePrompt_thisOnly"
    static let editScheduledWorkout_recurrencePrompt_thisAndFuture = "editScheduledWorkout_recurrencePrompt_thisAndFuture"
    static let editScheduledWorkout_saveButton = "editScheduledWorkout_saveButton"
    static let editScheduledWorkout_backButton = "editScheduledWorkout_backButton"
    static let editScheduledWorkout_dateField = "editScheduledWorkout_dateField"
    static let editScheduledWorkout_timeField = "editScheduledWorkout_timeField"

    static func exerciseCardRestPerSetField(_ index: Int) -> String {
        "exerciseCard_\(index)_restPerSetField"
    }

    static func exerciseCardRestPerSetInfoPopover(_ index: Int) -> String {
        "exerciseCard_\(index)_restPerSetInfoPopover"
    }

    static func exerciseCardRepsTimeToggle(_ index: Int) -> String {
        "exerciseCard_\(index)_repsTimeToggle"
    }

    static let masterSyncOff_popover = "masterSyncOff_popover"
    static let masterSyncOff_openSettingsButton = "masterSyncOff_openSettingsButton"
    static let watchSyncErrorToast = "watchSyncErrorToast"
    static let watchSyncErrorToast_retryButton = "watchSyncErrorToast_retryButton"

    // MARK: - Schedule Workout (Phase 8.7.1)

    static let scheduleWorkout_pushToAppleWatchToggle = "scheduleWorkout_pushToAppleWatchToggle"
    static let scheduleWorkout_pushToAppleWatchInfoPopover = "scheduleWorkout_pushToAppleWatchInfoPopover"

    static let planScheduledCardEditMenuItem = "planScheduledCardEditMenuItem"

    // MARK: - Helpers

    /// Sanitizes a display string for use in an identifier (removes spaces).
    static func optionIdentifier(prefix: String, option: String) -> String {
        "\(prefix)_\(option.replacingOccurrences(of: " ", with: ""))"
    }
}
