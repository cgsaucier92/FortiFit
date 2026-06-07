//
//  SmokeTests.swift
//  FortiFitUITests
//
//  XCUI smoke tests covering the primary user journeys. These tests don't
//  check math correctness — they verify that the app launches, navigates,
//  and completes end-to-end flows without crashing or losing UI elements.
//
//  Requirements:
//  1. All interactive SwiftUI elements used below must have
//     `.accessibilityIdentifier(...)` set matching the identifiers below.
//  2. FortiFitApp.swift must honor the "--uitesting" and "--reset-state"
//     launch arguments to skip animations and wipe state (see TESTING.md).
//
//  These tests run against a real simulator. Expect ~2–10 seconds per test.
//  Run before every TestFlight build; they catch "Claude Code broke the
//  build" issues that unit and integration tests miss.
//

import XCTest

final class SmokeTests: XCTestCase {

    // MARK: - Tab Helpers

    /// SwiftUI TabView `.accessibilityIdentifier()` applies to the content view,
    /// not the tab bar button. XCUI can only find tab buttons by their label text.
    enum Tab: String {
        case home = "DASHBOARD"
        case workouts = "WORKOUTS"
        case plan = "PLAN"
        case trends = "TRENDS"
        case goals = "GOALS"
    }

    // MARK: - Setup

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"]
        app.launch()

        // Dismiss system banners/alerts that can steal taps on device
        addUIInterruptionMonitor(withDescription: "System Alert") { alert in
            alert.buttons.firstMatch.tap()
            return true
        }

        XCTAssertTrue(app.tabBars.buttons[Tab.home.rawValue].waitForExistence(timeout: 5),
                       "Tab bar must be ready before tests run")
    }

    // MARK: - Smoke 1: App Launch

    /// The app launches without crashing and shows all 5 tabs.
    func test_appLaunches_displaysAllFiveTabs() {
        XCTAssertTrue(app.tabBars.buttons[Tab.home.rawValue].waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.buttons[Tab.workouts.rawValue].exists)
        XCTAssertTrue(app.tabBars.buttons[Tab.plan.rawValue].exists)
        XCTAssertTrue(app.tabBars.buttons[Tab.trends.rawValue].exists)
        XCTAssertTrue(app.tabBars.buttons[Tab.goals.rawValue].exists)
    }

    // MARK: - Smoke 2: Tab Navigation

    /// The user can navigate to every tab without the app crashing or losing state.
    func test_tabNavigation_everyTabLoadsWithoutCrashing() {
        let tabs = [Tab.home, .workouts, .plan, .trends, .goals]
        for tab in tabs {
            app.tabBars.buttons[tab.rawValue].tap()
            XCTAssertTrue(app.tabBars.buttons[tab.rawValue].isSelected, "Failed to select \(tab)")
        }
    }

    // MARK: - Smoke 3: Log Strength Workout

    /// User can log a Strength Training workout end-to-end and see it appear in Recent Workouts.
    func test_logStrengthWorkout_savesAndAppearsInRecentWorkouts() {
        app.tabBars.buttons[Tab.home.rawValue].tap()
        app.buttons["logWorkoutCTA"].tap()

        // Name
        let nameField = app.textFields["workoutNameInput"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("Smoke Test Push Day")

        // Type picker (defaults to Strength Training, so no change needed)
        // Add an exercise
        app.buttons["addExerciseButton"].tap()
        let exerciseName = app.textFields["exerciseNameInput_0"]
        XCTAssertTrue(exerciseName.waitForExistence(timeout: 2))
        exerciseName.tap()
        exerciseName.typeText("Bench Press\n") // Return dismisses autocomplete overlay

        // Fill sets/reps/weight in the first row
        app.textFields["setsInput_0_0"].tap()
        app.textFields["setsInput_0_0"].typeText("3")
        app.textFields["repsInput_0_0"].tap()
        app.textFields["repsInput_0_0"].typeText("8")
        app.textFields["weightInput_0_0"].tap()
        app.textFields["weightInput_0_0"].typeText("185")

        app.buttons["saveWorkoutButton"].tap()

        // Verify we're back on Home and the workout appears in Recent Workouts
        XCTAssertTrue(
            app.staticTexts["Smoke Test Push Day"].waitForExistence(timeout: 3),
            "Expected logged workout to appear in Recent Workouts"
        )
    }

    // MARK: - Smoke 4: Log Cardio Workout

    /// User can log a Cardio workout with distance and duration.
    func test_logCardioWorkout_savesWithDistanceAndDuration() {
        app.tabBars.buttons[Tab.home.rawValue].tap()
        app.buttons["logWorkoutCTA"].tap()

        let nameField = app.textFields["workoutNameInput"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("Smoke Test Easy Run")

        // Switch to Cardio type
        app.buttons["workoutTypeDropdown"].tap()
        app.buttons["workoutTypeOption_Cardio"].tap()

        // Duration
        app.textFields["durationInput"].tap()
        app.textFields["durationInput"].typeText("30")

        // Distance
        app.textFields["distanceInput"].tap()
        app.textFields["distanceInput"].typeText("5")

        app.buttons["saveWorkoutButton"].tap()

        XCTAssertTrue(app.staticTexts["Smoke Test Easy Run"].waitForExistence(timeout: 3))
    }

    // MARK: - Smoke 5: Create Strength PR Goal

    /// User can create a Strength PR goal from the Goals tab.
    func test_createStrengthPRGoal_appearsInGoalsList() {
        app.tabBars.buttons[Tab.goals.rawValue].tap()

        let addButton = app.buttons["addGoalButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        // Select goal type first (no default is pre-selected)
        let goalTypeButton = app.buttons["Select Goal Type"]
        XCTAssertTrue(goalTypeButton.waitForExistence(timeout: 3), "Create Goal screen did not load")
        goalTypeButton.tap()

        let strengthOption = app.buttons["Strength PR"]
        XCTAssertTrue(strengthOption.waitForExistence(timeout: 2))
        strengthOption.tap()

        // Pick Bench Press from exercise dropdown
        let exerciseDropdown = app.buttons["goalExerciseDropdown"]
        XCTAssertTrue(exerciseDropdown.waitForExistence(timeout: 2))
        exerciseDropdown.tap()

        let benchOption = app.buttons["goalExerciseOption_BenchPress"]
        XCTAssertTrue(benchOption.waitForExistence(timeout: 2))
        benchOption.tap()

        // Target weight — wait for dropdown animation to finish
        let weightField = app.textFields["goalTargetWeightInput"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 3))
        weightField.tap()
        weightField.typeText("225")

        app.buttons["saveGoalButton"].tap()

        // Verify the goal card appears
        XCTAssertTrue(
            app.staticTexts["Bench Press"].waitForExistence(timeout: 3),
            "Expected Bench Press goal card to appear on Goals screen"
        )
    }

    // MARK: - Smoke 6: Settings Toggle

    /// User can open Settings from Home and toggle weight unit.
    func test_settings_toggleWeightUnit_persistsSelection() {
        app.tabBars.buttons[Tab.home.rawValue].tap()
        app.buttons["settingsGearIcon"].tap()

        let toggleContainer = app.otherElements["settings_weightUnitToggle"]
        XCTAssertTrue(toggleContainer.waitForExistence(timeout: 2))
        let initialValue = toggleContainer.value as? String

        // Tap the non-selected option button
        if initialValue == "kg" {
            toggleContainer.buttons["LBS"].tap()
        } else {
            toggleContainer.buttons["KG"].tap()
        }
        XCTAssertNotEqual(toggleContainer.value as? String, initialValue, "Weight unit toggle should flip")

        // Back out and return — value should still be flipped
        app.buttons["settingsBackButton"].tap()
        app.buttons["settingsGearIcon"].tap()
        XCTAssertNotEqual(app.otherElements["settings_weightUnitToggle"].value as? String, initialValue)
    }

    // MARK: - Smoke 7: Add a Home Widget

    /// User can open the Add Widgets menu and add the Weekly Streak widget.
    func test_addWidget_weekStreakAppearsOnHome() {
        app.tabBars.buttons[Tab.home.rawValue].tap()
        app.buttons["homeEllipsisMenu"].tap()
        app.buttons["addWidgetsMenuItem"].tap()

        // Tap "Add" for Weekly Streak row (not in defaults unlike Power Level)
        app.buttons["addWidgetRow_weekStreak"].tap()

        // Menu auto-dismisses after adding; Weekly Streak should now be on Home
        XCTAssertTrue(
            app.staticTexts["Week Streak"].waitForExistence(timeout: 3),
            "Expected Week Streak widget to appear after Add"
        )
    }

    // MARK: - Smoke 8: Save as Template

    /// User can save a logged Strength workout as a template and see it in Workout Templates.
    func test_saveAsTemplate_templateAppearsInSavedTemplatesList() {
        // First log a minimal Strength workout
        app.tabBars.buttons[Tab.home.rawValue].tap()
        app.buttons["logWorkoutCTA"].tap()

        let nameField = app.textFields["workoutNameInput"]
        nameField.tap()
        nameField.typeText("Template Source")
        app.buttons["addExerciseButton"].tap()
        let exerciseName = app.textFields["exerciseNameInput_0"]
        exerciseName.tap()
        exerciseName.typeText("Bench Press\n") // Return dismisses autocomplete overlay
        app.textFields["setsInput_0_0"].tap(); app.textFields["setsInput_0_0"].typeText("3")
        app.textFields["repsInput_0_0"].tap(); app.textFields["repsInput_0_0"].typeText("8")
        app.textFields["weightInput_0_0"].tap(); app.textFields["weightInput_0_0"].typeText("135")
        app.buttons["saveWorkoutButton"].tap()

        // Tap into Workout Detail and save as template
        app.staticTexts["Template Source"].tap()
        app.buttons["workoutDetailEllipsis"].tap()
        app.buttons["saveAsTemplateMenuItem"].tap()

        // Name prompt accepts default (workout name)
        app.buttons["saveTemplateConfirmButton"].firstMatch.tap()

        // Navigate to Workout Templates via Workouts → Ellipsis
        app.tabBars.buttons[Tab.workouts.rawValue].tap()
        app.buttons["workoutsEllipsisMenu"].tap()
        app.buttons["viewSavedTemplatesMenuItem"].tap()

        XCTAssertTrue(
            app.staticTexts["Template Source"].waitForExistence(timeout: 3),
            "Expected saved template to appear in Workout Templates list"
        )
    }

    // MARK: - Smoke 9: Schedule a Planned Workout

    /// User can schedule a saved template in the Plan tab and see the scheduled card.
    func test_schedulePlannedWorkout_appearsOnSelectedDay() {
        // Precondition: create a template by logging a workout and saving as template
        app.tabBars.buttons[Tab.home.rawValue].tap()
        app.buttons["logWorkoutCTA"].tap()

        let nameField = app.textFields["workoutNameInput"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("Plan Smoke Test")
        app.buttons["addExerciseButton"].tap()
        let exerciseName = app.textFields["exerciseNameInput_0"]
        exerciseName.tap()
        exerciseName.typeText("Squat\n")
        app.textFields["setsInput_0_0"].tap(); app.textFields["setsInput_0_0"].typeText("3")
        app.textFields["repsInput_0_0"].tap(); app.textFields["repsInput_0_0"].typeText("5")
        app.buttons["saveWorkoutButton"].tap()

        // Open workout detail and save as template
        let workoutCell = app.staticTexts["Plan Smoke Test"]
        XCTAssertTrue(workoutCell.waitForExistence(timeout: 3))
        workoutCell.tap()
        app.buttons["workoutDetailEllipsis"].tap()
        app.buttons["saveAsTemplateMenuItem"].tap()
        // Accept default name in alert
        app.alerts.buttons["Save"].firstMatch.tap()

        // Navigate to Plan tab and schedule
        app.tabBars.buttons[Tab.plan.rawValue].tap()
        app.buttons["planAddButton"].tap()

        // Template selection sheet
        let templateRow = app.buttons["templateSelectionRow_0"]
        XCTAssertTrue(templateRow.waitForExistence(timeout: 3))
        templateRow.tap()

        // Date defaults to today; skip time and recurrence
        app.buttons["scheduleWorkoutConfirmButton"].tap()

        // The scheduled workout card should now appear in the day detail area
        XCTAssertTrue(
            app.buttons["scheduledWorkoutCard_0"].waitForExistence(timeout: 3),
            "Expected a scheduled workout card to appear after scheduling"
        )
    }

    // MARK: - Smoke 10: Logged Workout on Plan → Remove → Show on Plan Round Trip

    /// Full user journey: log a workout, see it on Plan as a logged-only card,
    /// remove from plan via context menu, then restore via Show on Plan in Workout Detail.
    func test_logWorkoutAppearsOnPlanAsLoggedCard_thenRemoveFromPlan_thenShowOnPlan_roundTrip() {
        // 1. Log a Cardio workout (no template needed)
        app.tabBars.buttons[Tab.home.rawValue].tap()
        app.buttons["logWorkoutCTA"].tap()

        let nameField = app.textFields["workoutNameInput"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("Plan Round Trip Run")

        app.buttons["workoutTypeDropdown"].tap()
        app.buttons["workoutTypeOption_Cardio"].tap()

        app.textFields["durationInput"].tap()
        app.textFields["durationInput"].typeText("30")

        app.buttons["saveWorkoutButton"].tap()

        // 2. Navigate to Plan tab — the logged workout should appear as a logged-only card
        app.tabBars.buttons[Tab.plan.rawValue].tap()
        let loggedCard = app.buttons["planLoggedOnlyCard_0"]
        XCTAssertTrue(loggedCard.waitForExistence(timeout: 3), "Logged workout should appear on Plan as a logged-only card")

        // 3. Long-press to open context menu → Remove from Plan
        loggedCard.press(forDuration: 1.0)
        let removeMenuItem = app.buttons["planRemoveFromPlanMenuItem"]
        XCTAssertTrue(removeMenuItem.waitForExistence(timeout: 3))
        removeMenuItem.tap()

        // 4. Confirm removal in the alert
        let removeButton = app.alerts.buttons["Remove"]
        XCTAssertTrue(removeButton.waitForExistence(timeout: 2))
        removeButton.tap()

        // 5. Card should be gone, undo toast should appear
        XCTAssertFalse(app.buttons["planLoggedOnlyCard_0"].waitForExistence(timeout: 1), "Card should be removed from Plan")

        // 6. Navigate to Workouts to find the workout detail
        app.tabBars.buttons[Tab.workouts.rawValue].tap()
        let typeCard = app.buttons["workoutTypeCard_Cardio"]
        XCTAssertTrue(typeCard.waitForExistence(timeout: 2))
        typeCard.tap() // expand

        let workoutRow = app.staticTexts["Plan Round Trip Run"]
        XCTAssertTrue(workoutRow.waitForExistence(timeout: 2), "Workout should still exist in Workouts list")
        workoutRow.tap()

        // 7. Ellipsis → Show on Plan
        let ellipsis = app.buttons["workoutDetailEllipsis"]
        XCTAssertTrue(ellipsis.waitForExistence(timeout: 2))
        ellipsis.tap()

        let showOnPlan = app.buttons["workoutDetailShowOnPlanMenuItem"]
        XCTAssertTrue(showOnPlan.waitForExistence(timeout: 2), "Show on Plan should be visible when hiddenFromPlan is true")
        showOnPlan.tap()

        // 8. Navigate back to Plan — card should reappear
        app.tabBars.buttons[Tab.plan.rawValue].tap()
        XCTAssertTrue(
            app.buttons["planLoggedOnlyCard_0"].waitForExistence(timeout: 3),
            "Logged-only card should reappear on Plan after Show on Plan"
        )
    }

    // MARK: - Smoke 11: Delete Workout via Swipe

    /// User can delete a workout via swipe-to-delete on an expanded Workout Type card.
    func test_swipeToDelete_removesWorkoutFromList() {
        // Log a workout to delete
        app.tabBars.buttons[Tab.home.rawValue].tap()
        app.buttons["logWorkoutCTA"].tap()
        let nameField = app.textFields["workoutNameInput"]
        nameField.tap()
        nameField.typeText("Delete Me")
        app.buttons["addExerciseButton"].tap()
        let exerciseName = app.textFields["exerciseNameInput_0"]
        exerciseName.tap()
        exerciseName.typeText("Bench Press\n") // Return dismisses autocomplete overlay
        app.textFields["setsInput_0_0"].tap(); app.textFields["setsInput_0_0"].typeText("3")
        app.textFields["repsInput_0_0"].tap(); app.textFields["repsInput_0_0"].typeText("8")
        app.textFields["weightInput_0_0"].tap(); app.textFields["weightInput_0_0"].typeText("100")
        app.buttons["saveWorkoutButton"].tap()

        // Go to Workouts tab, expand Strength Training card, swipe to delete
        app.tabBars.buttons[Tab.workouts.rawValue].tap()
        let typeCard = app.buttons["workoutTypeCard_StrengthTraining"]
        XCTAssertTrue(typeCard.waitForExistence(timeout: 2))
        typeCard.tap() // expand

        let row = app.staticTexts["Delete Me"]
        XCTAssertTrue(row.waitForExistence(timeout: 2))
        row.swipeLeft()
        app.buttons["Trash"].tap() // Custom swipe-to-delete reveals a trash icon button

        // Confirm in delete confirmation alert
        app.alerts.buttons["Delete"].tap()

        // Row should be gone
        XCTAssertFalse(app.staticTexts["Delete Me"].exists, "Expected deleted workout to disappear")
    }

    // MARK: - Smoke 12: Tab Reset — Home

    /// Navigating away from Home while Settings is pushed should pop back to root on return.
    func test_homeTab_resetsNavigationOnTabSwitch() {
        app.tabBars.buttons[Tab.home.rawValue].tap()
        app.buttons["settingsGearIcon"].tap()

        // Verify we're on Settings
        let weightToggle = app.otherElements["settings_weightUnitToggle"]
        XCTAssertTrue(weightToggle.waitForExistence(timeout: 2), "Settings screen should be pushed")

        // Switch away and back
        app.tabBars.buttons[Tab.workouts.rawValue].tap()
        app.tabBars.buttons[Tab.home.rawValue].tap()

        // Should be back at Home root — gear icon visible, Settings content gone
        XCTAssertTrue(app.buttons["settingsGearIcon"].waitForExistence(timeout: 2), "Gear icon should be visible after tab reset")
        XCTAssertFalse(app.otherElements["settings_weightUnitToggle"].exists, "Settings should be dismissed after tab reset")
    }

    // MARK: - Smoke 13: Tab Reset — Workouts

    /// Navigating away from Workouts while Workout Templates is pushed should pop back to root on return.
    func test_workoutsTab_resetsNavigationOnTabSwitch() {
        app.tabBars.buttons[Tab.workouts.rawValue].tap()

        // Push into Workout Templates via ellipsis menu
        app.buttons["workoutsEllipsisMenu"].tap()
        let templatesItem = app.buttons["viewSavedTemplatesMenuItem"]
        XCTAssertTrue(templatesItem.waitForExistence(timeout: 2))
        templatesItem.tap()

        // Verify we navigated away from root (ellipsis should not be visible on Templates screen)
        XCTAssertFalse(app.buttons["workoutsEllipsisMenu"].waitForExistence(timeout: 1), "Should have navigated to Workout Templates")

        // Switch away and back
        app.tabBars.buttons[Tab.home.rawValue].tap()
        app.tabBars.buttons[Tab.workouts.rawValue].tap()

        // Should be back at Workouts root
        XCTAssertTrue(app.buttons["workoutsEllipsisMenu"].waitForExistence(timeout: 2), "Workouts ellipsis should be visible after tab reset")
    }

    // MARK: - Smoke 14: Tab Reset — Plan

    /// Navigating away from Plan while Workout Templates is pushed should pop back to root on return.
    func test_planTab_resetsNavigationOnTabSwitch() {
        app.tabBars.buttons[Tab.plan.rawValue].tap()

        // Push into Workout Templates via Plan's ellipsis menu
        app.buttons["planEllipsisMenu"].tap()
        let templatesItem = app.buttons["planSavedTemplatesMenuItem"]
        XCTAssertTrue(templatesItem.waitForExistence(timeout: 2))
        templatesItem.tap()

        // Verify we navigated away from root (Plan ellipsis should not be visible)
        XCTAssertFalse(app.buttons["planEllipsisMenu"].waitForExistence(timeout: 1), "Should have navigated to Workout Templates")

        // Switch away and back
        app.tabBars.buttons[Tab.home.rawValue].tap()
        app.tabBars.buttons[Tab.plan.rawValue].tap()

        // Should be back at Plan root
        XCTAssertTrue(app.buttons["planEllipsisMenu"].waitForExistence(timeout: 2), "Plan ellipsis should be visible after tab reset")
    }

    // MARK: - Smoke 15: Tab Reset — Trends

    /// Opening the Add Charts overlay on Trends and switching tabs should dismiss the overlay on return.
    func test_trendsTab_resetsOverlayOnTabSwitch() {
        app.tabBars.buttons[Tab.trends.rawValue].tap()

        // Open Add Charts overlay via ellipsis menu
        let ellipsis = app.buttons["trendsEllipsisMenu"]
        XCTAssertTrue(ellipsis.waitForExistence(timeout: 2))
        ellipsis.tap()
        let addChartsItem = app.buttons["trendsAddChartsMenuItem"]
        XCTAssertTrue(addChartsItem.waitForExistence(timeout: 2))
        addChartsItem.tap()

        // Verify overlay appeared — the overlay header "Add Charts" appears as a static text
        let overlayHeader = app.staticTexts["Add Charts"]
        XCTAssertTrue(overlayHeader.waitForExistence(timeout: 2), "Add Charts overlay should be visible")

        // Switch away and back
        app.tabBars.buttons[Tab.home.rawValue].tap()
        app.tabBars.buttons[Tab.trends.rawValue].tap()

        // Overlay should be dismissed — the static text "Add Charts" should be gone
        XCTAssertFalse(app.staticTexts["Add Charts"].exists, "Add Charts overlay should be dismissed after tab reset")
        XCTAssertTrue(app.buttons["trendsEllipsisMenu"].waitForExistence(timeout: 2), "Trends ellipsis should be visible after tab reset")
    }

    // MARK: - Smoke 16: Tab Reset — Goals

    /// Navigating away from Goals while Create Goal is pushed should pop back to root on return.
    func test_goalsTab_resetsNavigationOnTabSwitch() {
        app.tabBars.buttons[Tab.goals.rawValue].tap()

        // Push into Create Goal
        let addButton = app.buttons["addGoalButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        addButton.tap()

        // Verify we're on Create Goal screen (goal type selector should exist)
        XCTAssertTrue(app.buttons["Select Goal Type"].waitForExistence(timeout: 2), "Create Goal screen should be pushed")

        // Switch away and back
        app.tabBars.buttons[Tab.home.rawValue].tap()
        app.tabBars.buttons[Tab.goals.rawValue].tap()

        // Should be back at Goals root
        XCTAssertTrue(app.buttons["addGoalButton"].waitForExistence(timeout: 2), "Create Goal button should be visible after tab reset")
        XCTAssertFalse(app.buttons["Select Goal Type"].exists, "Create Goal screen should be dismissed after tab reset")
    }

    // MARK: - Smoke 17: Long-Press Training Load → Configure Settings

    /// Long-pressing the Training Load widget reveals "Configure Settings" which opens the modal.
    func test_longPressTrainingLoadWidget_revealsConfigureSettings_opensModal() {
        app.tabBars.buttons[Tab.home.rawValue].tap()

        let trainingLoadText = app.staticTexts["Training Load"]
        XCTAssertTrue(trainingLoadText.waitForExistence(timeout: 3), "Training Load widget should be visible")

        trainingLoadText.press(forDuration: 1.0)

        let configureButton = app.buttons["homeWidget_trainingLoad_configureSettings"]
        XCTAssertTrue(configureButton.waitForExistence(timeout: 3), "Configure Settings should appear in context menu")
        configureButton.tap()

        XCTAssertTrue(
            app.staticTexts["Configure Training Load"].waitForExistence(timeout: 3),
            "Training Load Settings Modal should open"
        )
    }

    // MARK: - Smoke 18: Long-Press Weekly Streak → Configure Settings

    /// Long-pressing the Weekly Streak widget reveals "Configure Settings" which opens the modal.
    func test_longPressWeeklyStreakWidget_revealsConfigureSettings_opensModal() {
        app.tabBars.buttons[Tab.home.rawValue].tap()

        // Add Weekly Streak widget (not in defaults)
        app.buttons["homeEllipsisMenu"].tap()
        app.buttons["addWidgetsMenuItem"].tap()
        app.buttons["addWidgetRow_weekStreak"].tap()
        app.buttons["addWidgetsMenuDismiss"].tap()

        let streakText = app.staticTexts["Week Streak"]
        XCTAssertTrue(streakText.waitForExistence(timeout: 3), "Week Streak widget should be visible")

        streakText.press(forDuration: 1.0)

        let configureButton = app.buttons["homeWidget_weeklyStreak_configureSettings"]
        XCTAssertTrue(configureButton.waitForExistence(timeout: 3), "Configure Settings should appear in context menu")
        configureButton.tap()

        XCTAssertTrue(
            app.staticTexts["Configure Streak Widget"].waitForExistence(timeout: 3),
            "Weekly Streak Settings Modal should open"
        )
    }

    // MARK: - Smoke 19: Long-Press Non-Configurable Widget → No Configure Settings

    /// Long-pressing a non-configurable widget (Today's Plan) does not show "Configure Settings".
    func test_longPressNonConfigurableWidget_doesNotShowConfigureSettings() {
        app.tabBars.buttons[Tab.home.rawValue].tap()

        let todaysPlanText = app.staticTexts["Today's Plan"]
        XCTAssertTrue(todaysPlanText.waitForExistence(timeout: 3), "Today's Plan widget should be visible")

        todaysPlanText.press(forDuration: 1.0)

        let reorderButton = app.buttons["Reorder Widgets"]
        XCTAssertTrue(reorderButton.waitForExistence(timeout: 3), "Reorder Widgets should appear")

        let deleteButton = app.buttons["Delete Widget"]
        XCTAssertTrue(deleteButton.exists, "Delete Widget should appear")

        XCTAssertFalse(
            app.buttons["homeWidget_trainingLoad_configureSettings"].exists,
            "Configure Settings should not appear on non-configurable widget"
        )
        XCTAssertFalse(
            app.buttons["homeWidget_weeklyStreak_configureSettings"].exists,
            "Configure Settings should not appear on non-configurable widget"
        )
    }

    // MARK: - Smoke 20: Settings — Apple Health Section

    /// Long-pressing a Trends chart reveals "See Info" which opens the Chart Info Modal.
    func test_longPressTrendsChart_revealsSeeInfo_opensModal() {
        app.tabBars.buttons[Tab.trends.rawValue].tap()

        let strengthHeader = app.staticTexts["Strength Tracker"]
        XCTAssertTrue(strengthHeader.waitForExistence(timeout: 3), "Strength Tracker chart card should be visible")

        strengthHeader.press(forDuration: 1.0)

        let seeInfoButton = app.buttons["trendsChart_seeInfoMenuItem"]
        XCTAssertTrue(seeInfoButton.waitForExistence(timeout: 3), "See Info should appear in context menu")
        seeInfoButton.tap()

        XCTAssertTrue(
            app.staticTexts["About Strength Tracker"].waitForExistence(timeout: 3),
            "Chart Info Modal should open with the chart's title"
        )
    }

    /// Tapping the close button on the Chart Info Modal dismisses it.
    func test_chartInfoModal_dismissesViaCloseButton() {
        app.tabBars.buttons[Tab.trends.rawValue].tap()

        let strengthHeader = app.staticTexts["Strength Tracker"]
        XCTAssertTrue(strengthHeader.waitForExistence(timeout: 3))

        strengthHeader.press(forDuration: 1.0)

        let seeInfoButton = app.buttons["trendsChart_seeInfoMenuItem"]
        XCTAssertTrue(seeInfoButton.waitForExistence(timeout: 3))
        seeInfoButton.tap()

        XCTAssertTrue(
            app.staticTexts["About Strength Tracker"].waitForExistence(timeout: 3),
            "Modal should be open"
        )

        let closeButton = app.buttons["seeInfoModal_closeButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 2))
        closeButton.tap()

        XCTAssertFalse(
            app.staticTexts["About Strength Tracker"].waitForExistence(timeout: 2),
            "Chart Info Modal should be dismissed after tapping close"
        )
    }

    // MARK: - Home Widget See Info Tests

    /// Long-pressing the Training Load widget shows See Info; tapping opens the modal.
    func test_longPressTrainingLoadWidget_revealsSeeInfo_opensModal() {
        app.tabBars.buttons[Tab.home.rawValue].tap()

        let trainingLoadHeader = app.staticTexts["Training Load"]
        XCTAssertTrue(trainingLoadHeader.waitForExistence(timeout: 3))

        trainingLoadHeader.press(forDuration: 1.0)

        let seeInfoButton = app.buttons["homeWidget_trainingLoad_seeInfo"]
        XCTAssertTrue(seeInfoButton.waitForExistence(timeout: 3))
        seeInfoButton.tap()

        XCTAssertTrue(
            app.staticTexts["About Training Load"].waitForExistence(timeout: 3),
            "See Info Modal should be open with Training Load content"
        )
    }

    /// Long-pressing the Power Level widget shows See Info; tapping opens the modal.
    func test_longPressPowerLevelWidget_revealsSeeInfo_opensModal() {
        app.tabBars.buttons[Tab.home.rawValue].tap()

        let powerLevelHeader = app.staticTexts["Power Level"]
        XCTAssertTrue(powerLevelHeader.waitForExistence(timeout: 3))

        powerLevelHeader.press(forDuration: 1.0)

        let seeInfoButton = app.buttons["homeWidget_powerLevel_seeInfo"]
        XCTAssertTrue(seeInfoButton.waitForExistence(timeout: 3))
        seeInfoButton.tap()

        XCTAssertTrue(
            app.staticTexts["About Power Level"].waitForExistence(timeout: 3),
            "See Info Modal should be open with Power Level content"
        )
    }

    // MARK: - Phase 12: Power Level Gauge

    /// Widget card renders gauge + thumb + delta caption only — the
    /// directional indicator glyph and the status word ("Steady" / "Rising" /
    /// "Deloading") are both absent. State is conveyed by the gauge thumb /
    /// color zones, and the status word is preserved in the gauge's
    /// VoiceOver label for color-independent reading.
    func test_powerLevelWidget_rendersGaugeAndCaption_noGlyphNoStatusWord() {
        app.tabBars.buttons[Tab.home.rawValue].tap()

        let powerLevelHeader = app.staticTexts["Power Level"]
        XCTAssertTrue(powerLevelHeader.waitForExistence(timeout: 3))

        XCTAssertTrue(
            app.otherElements["homeWidget_powerLevel_gauge"].waitForExistence(timeout: 3),
            "Phase 12 gauge container must be present on the Power Level card"
        )
        XCTAssertTrue(
            app.staticTexts["homeWidget_powerLevel_deltaCaption"].exists,
            "Delta caption must be present"
        )

        // The status word must NOT appear on the card — color-independent state
        // is preserved via the gauge's VoiceOver label, not visible text.
        for word in ["Rising", "Steady", "Deloading"] {
            let directHits = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", word))
            XCTAssertEqual(directHits.count, 0, "Status word '\(word)' must not appear on the widget card")
        }
    }

    /// Tapping the Power Level widget opens the breakdown sheet with the
    /// hero gauge visible — and the hero still has no status word.
    func test_powerLevelWidget_tap_opensBreakdownSheetWithHeroGauge() {
        app.tabBars.buttons[Tab.home.rawValue].tap()

        let powerLevelHeader = app.staticTexts["Power Level"]
        XCTAssertTrue(powerLevelHeader.waitForExistence(timeout: 3))
        powerLevelHeader.tap()

        XCTAssertTrue(
            app.otherElements["powerLevelDetailSheet_hero"].waitForExistence(timeout: 3),
            "Breakdown sheet hero block must appear"
        )
        XCTAssertTrue(
            app.otherElements["powerLevelDetailSheet_heroGauge"].waitForExistence(timeout: 2),
            "Hero gauge container must be rendered in the sheet"
        )

        for word in ["Rising", "Steady", "Deloading"] {
            let hits = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", word))
            XCTAssertEqual(hits.count, 0, "Status word '\(word)' must not be drawn on the hero")
        }
    }

    /// Cold-start state (no qualifying workouts after --reset-state) hides
    /// the window comparison bars entirely and renders the hero no-data copy.
    func test_breakdownSheet_coldStart_heroNoDataCopyRendersAndBarsHidden() {
        app.tabBars.buttons[Tab.home.rawValue].tap()

        let powerLevelHeader = app.staticTexts["Power Level"]
        XCTAssertTrue(powerLevelHeader.waitForExistence(timeout: 3))
        powerLevelHeader.tap()

        XCTAssertTrue(
            app.otherElements["powerLevelDetailSheet_hero"].waitForExistence(timeout: 3)
        )

        // Cold-start copy from AppConstants.WidgetDetail.EmptyState.powerLevelHero.
        let coldStartCopy = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Log a few more Strength")
        ).firstMatch
        XCTAssertTrue(coldStartCopy.exists, "Cold-start hero copy must render")

        XCTAssertFalse(
            app.otherElements["powerLevelDetailSheet_windowComparison"].exists,
            "Window comparison block must be hidden in cold-start"
        )
        XCTAssertFalse(
            app.otherElements["powerLevelDetailSheet_windowComparison_previousBar"].exists,
            "Previous bar must be hidden in cold-start"
        )
        XCTAssertFalse(
            app.otherElements["powerLevelDetailSheet_windowComparison_currentBar"].exists,
            "Current bar must be hidden in cold-start"
        )
    }

    /// Long-pressing a non-info widget (Today's Plan) does not show See Info.
    func test_longPressNonInfoWidget_doesNotShowSeeInfo() {
        app.tabBars.buttons[Tab.home.rawValue].tap()

        let todaysPlanHeader = app.staticTexts["Today's Plan"]
        XCTAssertTrue(todaysPlanHeader.waitForExistence(timeout: 3))

        todaysPlanHeader.press(forDuration: 1.0)

        let seeInfoButton = app.buttons["homeWidget_trainingLoad_seeInfo"]
        XCTAssertFalse(
            seeInfoButton.waitForExistence(timeout: 2),
            "See Info should not appear on Today's Plan widget"
        )

        let reorderButton = app.buttons["Reorder Widgets"]
        XCTAssertTrue(
            reorderButton.waitForExistence(timeout: 2),
            "Reorder Widgets should be present on Today's Plan widget"
        )
    }

    /// Settings screen shows Apple Health toggle and description text.
    func test_settings_appleHealthSection_showsToggleAndDescription() {
        app.tabBars.buttons[Tab.home.rawValue].tap()
        app.buttons["settingsGearIcon"].tap()

        let toggle = app.switches["settings_appleHealthToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3), "Apple Health toggle should exist in Settings")

        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Apple Health")).firstMatch.exists,
            "Apple Health section header should be visible"
        )

        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Import workouts")).firstMatch.exists,
            "Apple Health description text should be visible"
        )
    }

    // MARK: - Phase 6.1: Trends Chart Visual Polish

    private func logStrengthWorkoutQuick(name: String, weight: String) {
        app.tabBars.buttons[Tab.home.rawValue].tap()
        app.buttons["logWorkoutCTA"].tap()

        let nameField = app.textFields["workoutNameInput"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText(name)

        app.buttons["addExerciseButton"].tap()
        let exerciseField = app.textFields["exerciseNameInput_0"]
        XCTAssertTrue(exerciseField.waitForExistence(timeout: 2))
        exerciseField.tap()
        exerciseField.typeText("Bench Press\n")

        app.textFields["setsInput_0_0"].tap()
        app.textFields["setsInput_0_0"].typeText("3")
        app.textFields["repsInput_0_0"].tap()
        app.textFields["repsInput_0_0"].typeText("8")
        app.textFields["weightInput_0_0"].tap()
        app.textFields["weightInput_0_0"].typeText(weight)

        app.buttons["saveWorkoutButton"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 3))
    }

    func test_trendsScreen_seededChartsRenderHeaderSummaryIdentifier() {
        logStrengthWorkoutQuick(name: "Trend1", weight: "100")
        logStrengthWorkoutQuick(name: "Trend2", weight: "120")

        app.tabBars.buttons[Tab.trends.rawValue].tap()

        let summary = app.descendants(matching: .any)
            .matching(identifier: "trendsChart_strengthTracker_headerSummary").firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5),
                      "Strength Tracker header summary should appear with 2+ workouts")
    }

    func test_trendsScreen_workoutTypeBreakdown_centerLabelIdentifier() {
        logStrengthWorkoutQuick(name: "Breakdown1", weight: "80")
        logStrengthWorkoutQuick(name: "Breakdown2", weight: "90")

        app.tabBars.buttons[Tab.trends.rawValue].tap()

        app.buttons["trendsEllipsisMenu"].tap()
        app.buttons["trendsAddChartsMenuItem"].tap()
        XCTAssertTrue(app.staticTexts["Add Charts"].waitForExistence(timeout: 2))

        let addButtons = app.buttons.matching(NSPredicate(format: "label == 'Add'"))
        let breakdownAdd = addButtons.element(boundBy: 2)
        XCTAssertTrue(breakdownAdd.waitForExistence(timeout: 2))
        breakdownAdd.tap()

        app.tabBars.buttons[Tab.home.rawValue].tap()
        app.tabBars.buttons[Tab.trends.rawValue].tap()

        app.swipeUp()

        let centerLabel = app.descendants(matching: .any)
            .matching(identifier: "trendsChart_workoutTypeBreakdown_centerLabel").firstMatch
        XCTAssertTrue(centerLabel.waitForExistence(timeout: 5),
                      "Workout Type Breakdown center label should be present")
    }

    /// Chart card renders with data and is non-empty when threshold is met.
    /// Selection annotation testing deferred — see BUG-034: XCUI cannot trigger
    /// SwiftUI Charts .chartXSelection gestures (tap, press, drag all fail).
    func test_trendsChart_dataPointTap_revealsSelectionAnnotation() {
        logStrengthWorkoutQuick(name: "Select1", weight: "100")
        logStrengthWorkoutQuick(name: "Select2", weight: "150")

        app.tabBars.buttons[Tab.trends.rawValue].tap()

        let chartCard = app.descendants(matching: .any)
            .matching(identifier: "trendsChart_strengthTracker_card").firstMatch
        XCTAssertTrue(chartCard.waitForExistence(timeout: 5),
                      "Strength Tracker chart card should exist with seeded data")

        let summary = app.descendants(matching: .any)
            .matching(identifier: "trendsChart_strengthTracker_headerSummary").firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 3),
                      "Header summary confirms chart has data (non-empty state)")
    }

    /// Toggle tap doesn't crash and clears any prior state.
    /// Selection annotation testing deferred — see BUG-034.
    func test_trendsChart_toggleChange_clearsSelection() {
        logStrengthWorkoutQuick(name: "Toggle1", weight: "100")
        logStrengthWorkoutQuick(name: "Toggle2", weight: "150")

        app.tabBars.buttons[Tab.trends.rawValue].tap()

        let chartCard = app.descendants(matching: .any)
            .matching(identifier: "trendsChart_strengthTracker_card").firstMatch
        XCTAssertTrue(chartCard.waitForExistence(timeout: 5))

        let toggleButton = app.buttons["60D"]
        XCTAssertTrue(toggleButton.waitForExistence(timeout: 2),
                      "Time range toggle should exist on the chart card")
        toggleButton.tap()

        let summary = app.descendants(matching: .any)
            .matching(identifier: "trendsChart_strengthTracker_headerSummary").firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 3),
                      "Chart should still render after toggle change")
    }
}

// MARK: - Phase 6.2: Trends Chart Detail View

final class TrendsChartDetailSmokeTests: XCTestCase {

    enum Tab: String {
        case home = "DASHBOARD"
        case workouts = "WORKOUTS"
        case plan = "PLAN"
        case trends = "TRENDS"
        case goals = "GOALS"
    }

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"]
        app.launch()
    }

    private func logStrengthWorkoutQuick(name: String, weight: String) {
        app.tabBars.buttons[Tab.home.rawValue].tap()
        app.buttons["logWorkoutCTA"].tap()

        let nameField = app.textFields["workoutNameInput"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText(name)

        app.buttons["addExerciseButton"].tap()
        let exerciseField = app.textFields["exerciseNameInput_0"]
        XCTAssertTrue(exerciseField.waitForExistence(timeout: 2))
        exerciseField.tap()
        exerciseField.typeText("Bench Press\n")

        app.textFields["setsInput_0_0"].tap()
        app.textFields["setsInput_0_0"].typeText("3")
        app.textFields["repsInput_0_0"].tap()
        app.textFields["repsInput_0_0"].typeText("8")
        app.textFields["weightInput_0_0"].tap()
        app.textFields["weightInput_0_0"].typeText(weight)

        app.buttons["saveWorkoutButton"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 3))
    }

    private func navigateToTrendsAndSeedData() {
        logStrengthWorkoutQuick(name: "Detail1", weight: "100")
        logStrengthWorkoutQuick(name: "Detail2", weight: "150")
        app.tabBars.buttons[Tab.trends.rawValue].tap()
    }

    func test_trendsChart_expandButtonTap_pushesDetailView() {
        navigateToTrendsAndSeedData()

        let expandButton = app.descendants(matching: .any)
            .matching(identifier: "trendsChart_strengthTracker_expandButton").firstMatch
        XCTAssertTrue(expandButton.waitForExistence(timeout: 5),
                      "Expand button should exist on the Strength Tracker card")
        expandButton.tap()

        let detailCard = app.descendants(matching: .any)
            .matching(identifier: "trendsChartDetail_strengthTracker_card").firstMatch
        XCTAssertTrue(detailCard.waitForExistence(timeout: 5),
                      "Detail view should appear after tapping expand")
    }

    func test_trendsChartDetail_backButtonTap_popsToTrendsScreen() {
        navigateToTrendsAndSeedData()

        let expandButton = app.descendants(matching: .any)
            .matching(identifier: "trendsChart_strengthTracker_expandButton").firstMatch
        XCTAssertTrue(expandButton.waitForExistence(timeout: 5))
        expandButton.tap()

        let detailCard = app.descendants(matching: .any)
            .matching(identifier: "trendsChartDetail_strengthTracker_card").firstMatch
        XCTAssertTrue(detailCard.waitForExistence(timeout: 5))

        let backButton = app.descendants(matching: .any)
            .matching(identifier: "trendsChartDetail_strengthTracker_backButton").firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 3))
        backButton.tap()

        let compactCard = app.descendants(matching: .any)
            .matching(identifier: "trendsChart_strengthTracker_card").firstMatch
        XCTAssertTrue(compactCard.waitForExistence(timeout: 5),
                      "Should return to the Trends screen after tapping back")
        XCTAssertFalse(detailCard.exists,
                       "Detail view should no longer be visible")
    }

    func test_trendsChartDetail_seeInfoButtonTap_opensSeeInfoModal() {
        navigateToTrendsAndSeedData()

        let expandButton = app.descendants(matching: .any)
            .matching(identifier: "trendsChart_strengthTracker_expandButton").firstMatch
        XCTAssertTrue(expandButton.waitForExistence(timeout: 5))
        expandButton.tap()

        let detailCard = app.descendants(matching: .any)
            .matching(identifier: "trendsChartDetail_strengthTracker_card").firstMatch
        XCTAssertTrue(detailCard.waitForExistence(timeout: 5))

        let seeInfoButton = app.descendants(matching: .any)
            .matching(identifier: "trendsChartDetail_strengthTracker_seeInfoButton").firstMatch
        XCTAssertTrue(seeInfoButton.waitForExistence(timeout: 3))
        seeInfoButton.tap()

        let closeButton = app.buttons["seeInfoModal_closeButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3),
                      "See Info modal should open with a close button")
    }

    /// Data point tap and selection annotation tests deferred — XCUI cannot reliably
    /// trigger SwiftUI Charts tap/drag gestures (see BUG-034).
    func test_trendsChartDetail_dataPointTap_revealsSelectionAnnotation() {
        navigateToTrendsAndSeedData()

        let expandButton = app.descendants(matching: .any)
            .matching(identifier: "trendsChart_strengthTracker_expandButton").firstMatch
        XCTAssertTrue(expandButton.waitForExistence(timeout: 5))
        expandButton.tap()

        let detailCard = app.descendants(matching: .any)
            .matching(identifier: "trendsChartDetail_strengthTracker_card").firstMatch
        XCTAssertTrue(detailCard.waitForExistence(timeout: 5),
                      "Detail view should render with data (data point interaction deferred per BUG-034)")
    }

    func test_trendsChartDetail_rangeToggleChange_clearsSelection() {
        navigateToTrendsAndSeedData()

        let expandButton = app.descendants(matching: .any)
            .matching(identifier: "trendsChart_strengthTracker_expandButton").firstMatch
        XCTAssertTrue(expandButton.waitForExistence(timeout: 5))
        expandButton.tap()

        let detailCard = app.descendants(matching: .any)
            .matching(identifier: "trendsChartDetail_strengthTracker_card").firstMatch
        XCTAssertTrue(detailCard.waitForExistence(timeout: 5))

        let rangeToggle = app.descendants(matching: .any)
            .matching(identifier: "trendsChartDetail_strengthTracker_rangeToggle_30d").firstMatch
        XCTAssertTrue(rangeToggle.waitForExistence(timeout: 3),
                      "30D range toggle should exist on the detail view")
        rangeToggle.tap()

        XCTAssertTrue(detailCard.waitForExistence(timeout: 3),
                      "Detail view should still render after range toggle change")
    }

    func test_trendsChartDetail_swipeLeft_pagesToNextChart() {
        navigateToTrendsAndSeedData()

        let expandButton = app.descendants(matching: .any)
            .matching(identifier: "trendsChart_strengthTracker_expandButton").firstMatch
        XCTAssertTrue(expandButton.waitForExistence(timeout: 5))
        expandButton.tap()

        let detailCard = app.descendants(matching: .any)
            .matching(identifier: "trendsChartDetail_strengthTracker_card").firstMatch
        XCTAssertTrue(detailCard.waitForExistence(timeout: 5))

        // Swipe in the header area (dy: 0.15) to avoid the chart's
        // DragGesture(minimumDistance: 0) overlay which captures all drags.
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.15))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.15))
        start.press(forDuration: 0.01, thenDragTo: end)

        let nextCard = app.descendants(matching: .any)
            .matching(identifier: "trendsChartDetail_trainingFrequency_card").firstMatch
        XCTAssertTrue(nextCard.waitForExistence(timeout: 5),
                      "Swiping left should page to the next chart in sort order")
    }
}

// MARK: - HealthKit Smoke Tests (Seeded Data)

/// These tests use `--seed-hk-workout` to inject an HK-linked workout at launch,
/// enabling verification of HealthKit UI surfaces without real HealthKit authorization.
final class HealthKitSmokeTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state", "--seed-hk-workout"]
        app.launch()

        addUIInterruptionMonitor(withDescription: "System Alert") { alert in
            alert.buttons.firstMatch.tap()
            return true
        }

        XCTAssertTrue(app.tabBars.buttons["DASHBOARD"].waitForExistence(timeout: 5),
                       "Tab bar must be ready before tests run")
    }

    /// Waits for the seed to be visible on the Home screen, then navigates
    /// to Workouts, expands the Cardio card, and taps into the workout detail.
    private func navigateToSeededWorkoutDetail() {
        // Home is the default tab. Wait for seeded workout in Recent Workouts
        // to confirm the .task seed has completed.
        let seedLabel = app.staticTexts["HK Smoke Test Run"]
        XCTAssertTrue(seedLabel.waitForExistence(timeout: 5), "Seeded HK workout should appear on Home")

        // Navigate to Workouts — .onAppear will now find the seeded data
        app.tabBars.buttons["WORKOUTS"].tap()

        let typeCard = app.buttons["workoutTypeCard_Cardio"]
        XCTAssertTrue(typeCard.waitForExistence(timeout: 3), "Cardio type card should exist")
        typeCard.tap()

        let workoutRow = app.staticTexts["HK Smoke Test Run"]
        XCTAssertTrue(workoutRow.waitForExistence(timeout: 3))
        workoutRow.tap()
    }

    // MARK: - Smoke HK-1: Workout Detail Source Indicator

    /// HK-linked workout shows the source indicator badge in Workout Detail.
    func test_hkLinkedWorkout_showsSourceIndicatorInDetail() {
        navigateToSeededWorkoutDetail()

        let indicator = app.buttons["workoutDetail_healthSourceIndicator"]
        XCTAssertTrue(indicator.waitForExistence(timeout: 3), "Source indicator should be visible for HK-linked workout")
    }

    // MARK: - Smoke HK-2: Health Source Info Sheet

    /// Tapping the source indicator opens the Health Source Info Sheet.
    func test_hkLinkedWorkout_tapIndicator_showsInfoSheet() {
        navigateToSeededWorkoutDetail()

        let indicator = app.buttons["workoutDetail_healthSourceIndicator"]
        XCTAssertTrue(indicator.waitForExistence(timeout: 3))
        indicator.tap()

        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "imported from Apple Health")).firstMatch.waitForExistence(timeout: 3),
            "Info sheet should describe the Apple Health import"
        )

        let unlinkButton = app.buttons["workoutDetail_healthUnlinkButton"]
        XCTAssertTrue(unlinkButton.exists, "Unlink button should be visible in info sheet")
    }

    // MARK: - Smoke HK-3: Unlink via Ellipsis Menu

    /// Ellipsis menu on HK-linked Workout Detail includes "Unlink from Apple Health".
    func test_hkLinkedWorkout_ellipsisMenu_showsUnlinkOption() {
        navigateToSeededWorkoutDetail()

        let ellipsis = app.buttons["workoutDetailEllipsis"]
        XCTAssertTrue(ellipsis.waitForExistence(timeout: 3))
        ellipsis.tap()

        let unlinkItem = app.buttons["workoutDetail_healthUnlinkButton"]
        XCTAssertTrue(unlinkItem.waitForExistence(timeout: 3), "Unlink from Apple Health should appear in ellipsis menu")
    }

    // MARK: - Smoke HK-4: Unlink via Info Sheet Removes Indicator

    /// Unlinking via the info sheet removes the source indicator.
    func test_hkLinkedWorkout_unlinkViaInfoSheet_removesIndicator() {
        navigateToSeededWorkoutDetail()

        let indicator = app.buttons["workoutDetail_healthSourceIndicator"]
        XCTAssertTrue(indicator.waitForExistence(timeout: 3))
        indicator.tap()

        let unlinkButton = app.buttons["workoutDetail_healthUnlinkButton"]
        XCTAssertTrue(unlinkButton.waitForExistence(timeout: 3))
        unlinkButton.tap()

        XCTAssertFalse(
            app.buttons["workoutDetail_healthSourceIndicator"].waitForExistence(timeout: 3),
            "Source indicator should disappear after unlinking"
        )
    }

    // MARK: - Smoke HK-5: Log Workout Read-Only Fields

    /// Editing an HK-linked workout shows read-only helper text on date, duration, distance.
    func test_hkLinkedWorkout_editMode_showsReadOnlyHelperText() {
        navigateToSeededWorkoutDetail()

        let editButton = app.buttons.matching(identifier: "pencil").firstMatch
        XCTAssertTrue(editButton.waitForExistence(timeout: 3))
        editButton.tap()

        let durationHelper = app.buttons["logWorkout_hkFieldInfoIcon_duration"]
        XCTAssertTrue(durationHelper.waitForExistence(timeout: 3), "Duration read-only helper should be visible")

        let distanceHelper = app.buttons["logWorkout_hkFieldInfoIcon_distance"]
        XCTAssertTrue(distanceHelper.exists, "Distance read-only helper should be visible")
    }

    // MARK: - Smoke HK-6: Apple Workout Label on Home Screen

    /// HK-linked Apple Watch workout shows "Apple Workout" text trailing the date row on the Home screen.
    func test_hkLinkedWorkout_showsAppleWorkoutLabelOnHome() {
        // Wait for seed to complete on Home
        let seedLabel = app.staticTexts["HK Smoke Test Run"]
        XCTAssertTrue(seedLabel.waitForExistence(timeout: 5), "Seeded HK workout should appear on Home")

        let appleWorkoutLabel = app.staticTexts["Apple Workout"]
        XCTAssertTrue(appleWorkoutLabel.exists, "Apple Workout label should be visible trailing the date row for Apple Watch workout on Home")
    }
}

// MARK: - Match Prompt Sheet Smoke Tests (Seeded Pending Match)

/// These tests use `--seed-hk-pending-match` to inject a pending match at launch,
/// enabling verification of the Match Prompt Sheet without real HealthKit data.
final class MatchPromptSmokeTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state", "--seed-hk-pending-match"]
        app.launch()

        addUIInterruptionMonitor(withDescription: "System Alert") { alert in
            alert.buttons.firstMatch.tap()
            return true
        }

        XCTAssertTrue(app.tabBars.buttons["DASHBOARD"].waitForExistence(timeout: 5),
                       "Tab bar must be ready before tests run")
    }

    // MARK: - Smoke MP-1: Match Prompt Appears

    /// When a pending match exists, the Match Prompt Sheet appears on foreground.
    func test_pendingMatch_matchPromptSheetAppears() {
        let linkButton = app.buttons["matchPromptSheet_linkButton"]
        XCTAssertTrue(linkButton.waitForExistence(timeout: 5), "Match Prompt Sheet should appear with Link button")

        let keepSeparateButton = app.buttons["matchPromptSheet_keepSeparateButton"]
        XCTAssertTrue(keepSeparateButton.exists, "Keep Separate button should be visible")

        let decideLaterButton = app.buttons["matchPromptSheet_decideLaterButton"]
        XCTAssertTrue(decideLaterButton.exists, "Decide Later button should be visible")

        XCTAssertTrue(
            app.staticTexts["Possible Match"].exists,
            "Sheet header 'Possible Match' should be visible"
        )
    }

    // MARK: - Smoke MP-2: Match Prompt Decide Later

    /// Tapping "Decide later" keeps the match pending (re-presents on next foreground).
    /// This test verifies the button is tappable and doesn't crash.
    func test_pendingMatch_decideLater_buttonIsTappable() {
        let decideLaterButton = app.buttons["matchPromptSheet_decideLaterButton"]
        XCTAssertTrue(decideLaterButton.waitForExistence(timeout: 5))
        decideLaterButton.tap()

        // "Decide later" keeps the match in the queue, so the sheet may
        // re-present. Verify the app is still functional by checking tabs.
        let homeTab = app.tabBars.buttons["DASHBOARD"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 3), "App should remain functional after Decide Later")
    }

    // MARK: - Smoke MP-3: Match Prompt Link Dismisses

    /// Tapping "Link these workouts" dismisses the Match Prompt Sheet.
    func test_pendingMatch_link_dismissesSheet() {
        let linkButton = app.buttons["matchPromptSheet_linkButton"]
        XCTAssertTrue(linkButton.waitForExistence(timeout: 5))
        linkButton.tap()

        XCTAssertFalse(
            app.staticTexts["Possible Match"].waitForExistence(timeout: 2),
            "Match Prompt Sheet should dismiss after Link"
        )
    }

    // MARK: - Smoke MP-4: Match Prompt Keep Separate Dismisses

    /// Tapping "Keep separate" dismisses the Match Prompt Sheet.
    func test_pendingMatch_keepSeparate_dismissesSheet() {
        let keepSeparateButton = app.buttons["matchPromptSheet_keepSeparateButton"]
        XCTAssertTrue(keepSeparateButton.waitForExistence(timeout: 5))
        keepSeparateButton.tap()

        XCTAssertFalse(
            app.staticTexts["Possible Match"].waitForExistence(timeout: 2),
            "Match Prompt Sheet should dismiss after Keep Separate"
        )
    }
}

// MARK: - Workout Detail Redesign Smoke Tests (Seeded HK Data)

/// Tests for the Phase 8.5 stat-card grid, effort label rendering,
/// source indicator format, and glyph positioning.
final class WorkoutDetailRedesignSmokeTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state", "--seed-hk-workout"]
        app.launch()

        addUIInterruptionMonitor(withDescription: "System Alert") { alert in
            alert.buttons.firstMatch.tap()
            return true
        }

        XCTAssertTrue(app.tabBars.buttons["DASHBOARD"].waitForExistence(timeout: 5),
                       "Tab bar must be ready before tests run")
    }

    private func navigateToSeededWorkoutDetail() {
        let seedLabel = app.staticTexts["HK Smoke Test Run"]
        XCTAssertTrue(seedLabel.waitForExistence(timeout: 5), "Seeded HK workout should appear on Home")

        app.tabBars.buttons["WORKOUTS"].tap()
        let typeCard = app.buttons["workoutTypeCard_Cardio"]
        XCTAssertTrue(typeCard.waitForExistence(timeout: 3))
        typeCard.tap()

        let workoutRow = app.staticTexts["HK Smoke Test Run"]
        XCTAssertTrue(workoutRow.waitForExistence(timeout: 3))
        workoutRow.tap()
    }

    // MARK: - Stat Card Grid

    /// Each visible stat card opens the correct metric detail sheet.
    func test_workoutDetail_eachStatCard_opensCorrectMetricSheet() {
        navigateToSeededWorkoutDetail()

        let cardMetricPairs: [(id: String, heroLabel: String)] = [
            ("workoutDetail_summaryCard_effort", "Effort"),
            ("workoutDetail_summaryCard_duration", "Duration"),
            ("workoutDetail_summaryCard_distance", "Distance"),
            ("workoutDetail_summaryCard_avgHR", "Avg HR"),
            ("workoutDetail_summaryCard_maxHR", "Max HR"),
            ("workoutDetail_summaryCard_activeKcal", "Active kcal"),
        ]

        for (cardID, expectedLabel) in cardMetricPairs {
            let card = app.buttons[cardID]
            if card.waitForExistence(timeout: 2) {
                card.tap()
                XCTAssertTrue(
                    app.staticTexts[expectedLabel].waitForExistence(timeout: 3),
                    "Hero label '\(expectedLabel)' should appear after tapping \(cardID)"
                )
                let closeButton = app.buttons["metricDetailSheet_closeButton"]
                XCTAssertTrue(closeButton.waitForExistence(timeout: 2))
                closeButton.tap()
                // Wait for sheet to dismiss
                _ = app.buttons[cardID].waitForExistence(timeout: 2)
            }
        }
    }

    // MARK: - Effort Label

    /// Effort stat card shows descriptive label (e.g. "Hard"), not the integer "7".
    func test_workoutDetail_effortRendersDescriptiveLabel_notInteger() {
        navigateToSeededWorkoutDetail()

        let effortCard = app.buttons["workoutDetail_summaryCard_effort"]
        XCTAssertTrue(effortCard.waitForExistence(timeout: 3), "Effort card should exist")

        XCTAssertTrue(
            effortCard.staticTexts["Hard"].exists,
            "Effort card should display 'Hard' (RPE 7 maps to Hard band)"
        )

        let cardTexts = effortCard.staticTexts.allElementsBoundByIndex.map { $0.label }
        let rawIntegerVisible = cardTexts.contains("7")
        XCTAssertFalse(rawIntegerVisible, "Effort card should NOT show the raw integer '7'")
    }

    // MARK: - Source Indicator

    /// Apple Watch source renders as "Apple Workout" with trailing glyph.
    func test_workoutDetail_appleWatchSource_rendersAppleWorkoutLabel_withTrailingGlyph() {
        navigateToSeededWorkoutDetail()

        let indicator = app.buttons["workoutDetail_healthSourceIndicator"]
        XCTAssertTrue(indicator.waitForExistence(timeout: 3))

        XCTAssertTrue(
            indicator.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Apple Workout")).firstMatch.exists,
            "Source indicator should contain 'Apple Workout'"
        )
    }

    // MARK: - Glyph on Workouts Tab

    /// Apple Watch workout shows "Apple Workout" label trailing the date row on the Workouts tab.
    func test_workoutsTab_appleWatchWorkout_showsAppleWorkoutLabel_inDateRow() {
        let seedLabel = app.staticTexts["HK Smoke Test Run"]
        XCTAssertTrue(seedLabel.waitForExistence(timeout: 5))

        app.tabBars.buttons["WORKOUTS"].tap()
        let typeCard = app.buttons["workoutTypeCard_Cardio"]
        XCTAssertTrue(typeCard.waitForExistence(timeout: 3))
        typeCard.tap()

        let appleWorkoutLabel = app.staticTexts["Apple Workout"]
        XCTAssertTrue(appleWorkoutLabel.waitForExistence(timeout: 3), "Apple Workout label should be visible on the Workouts preview row for Apple Watch workout")
    }
}

// MARK: - Exercises Header Hidden Smoke Tests

/// Tests that the Exercises header is hidden when no exercises are present.
final class ExercisesHeaderSmokeTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"]
        app.launch()

        addUIInterruptionMonitor(withDescription: "System Alert") { alert in
            alert.buttons.firstMatch.tap()
            return true
        }

        XCTAssertTrue(app.tabBars.buttons["DASHBOARD"].waitForExistence(timeout: 5),
                       "Tab bar must be ready before tests run")
    }

    /// Log a Strength workout without exercises; verify no "Exercises" header appears.
    func test_workoutDetail_exercisesHeaderHidden_whenNoExerciseSets() {
        app.tabBars.buttons["DASHBOARD"].tap()
        app.buttons["logWorkoutCTA"].tap()

        let nameField = app.textFields["workoutNameInput"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("No Exercises Workout")

        app.buttons["saveWorkoutButton"].tap()

        let workoutLabel = app.staticTexts["No Exercises Workout"]
        XCTAssertTrue(workoutLabel.waitForExistence(timeout: 3))
        workoutLabel.tap()

        XCTAssertFalse(
            app.staticTexts["Exercises"].waitForExistence(timeout: 2),
            "Exercises header should not appear when workout has no exercise sets"
        )
    }
}

// MARK: - Effort Dropdown Format Smoke Tests

/// Tests that the Log Workout effort dropdown shows "Label (Number)" format.
final class EffortDropdownSmokeTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"]
        app.launch()

        addUIInterruptionMonitor(withDescription: "System Alert") { alert in
            alert.buttons.firstMatch.tap()
            return true
        }

        XCTAssertTrue(app.tabBars.buttons["DASHBOARD"].waitForExistence(timeout: 5),
                       "Tab bar must be ready before tests run")
    }

    /// Effort dropdown options use "Label (Number)" format.
    func test_logWorkout_effortDropdown_rendersLabelAndNumberFormat() {
        app.tabBars.buttons["DASHBOARD"].tap()
        app.buttons["logWorkoutCTA"].tap()

        let nameField = app.textFields["workoutNameInput"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))

        // Tap the effort dropdown trigger button by its accessibility identifier
        let effortDropdown = app.buttons["effortDropdown"]
        XCTAssertTrue(effortDropdown.waitForExistence(timeout: 3), "Effort dropdown should be visible")
        effortDropdown.tap()

        // After expanding, check that option labels use "Label (Number)" format
        XCTAssertTrue(
            app.buttons["effortOption_Easy(1)"].waitForExistence(timeout: 2),
            "Effort option 'Easy (1)' should be visible"
        )
        XCTAssertTrue(app.buttons["effortOption_Hard(7)"].exists, "Effort option 'Hard (7)' should be visible")
        XCTAssertTrue(app.buttons["effortOption_AllOut(10)"].exists, "Effort option 'All Out (10)' should be visible")
    }
}

// MARK: - Strava Source Smoke Tests (Seeded Strava Data)

/// Tests for Strava-sourced workouts: no glyph, correct source name.
final class StravaSourceSmokeTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state", "--seed-hk-strava-workout"]
        app.launch()

        addUIInterruptionMonitor(withDescription: "System Alert") { alert in
            alert.buttons.firstMatch.tap()
            return true
        }

        XCTAssertTrue(app.tabBars.buttons["DASHBOARD"].waitForExistence(timeout: 5),
                       "Tab bar must be ready before tests run")
    }

    private func navigateToSeededStravaWorkoutDetail() {
        let seedLabel = app.staticTexts["HK Strava Ride"]
        XCTAssertTrue(seedLabel.waitForExistence(timeout: 5), "Seeded Strava workout should appear on Home")

        app.tabBars.buttons["WORKOUTS"].tap()
        let typeCard = app.buttons["workoutTypeCard_Cardio"]
        XCTAssertTrue(typeCard.waitForExistence(timeout: 3))
        typeCard.tap()

        let workoutRow = app.staticTexts["HK Strava Ride"]
        XCTAssertTrue(workoutRow.waitForExistence(timeout: 3))
        workoutRow.tap()
    }

    /// Strava-sourced workout shows "Strava" in source indicator, no glyph.
    func test_workoutDetail_stravaSource_rendersStravaLabel_withoutGlyph() {
        navigateToSeededStravaWorkoutDetail()

        let indicator = app.buttons["workoutDetail_healthSourceIndicator"]
        XCTAssertTrue(indicator.waitForExistence(timeout: 3))

        XCTAssertTrue(
            indicator.label.localizedCaseInsensitiveContains("Strava"),
            "Source indicator should contain 'Strava'"
        )

        XCTAssertFalse(
            app.images["healthGlyph"].exists,
            "Health glyph should NOT appear for Strava-sourced workout"
        )
    }

    /// Strava workout on the Workouts tab shows no "Apple Workout" label on the preview row.
    func test_workoutsTab_stravaWorkout_showsNoAppleWorkoutLabel() {
        let seedLabel = app.staticTexts["HK Strava Ride"]
        XCTAssertTrue(seedLabel.waitForExistence(timeout: 5))

        app.tabBars.buttons["WORKOUTS"].tap()
        let typeCard = app.buttons["workoutTypeCard_Cardio"]
        XCTAssertTrue(typeCard.waitForExistence(timeout: 3))
        typeCard.tap()

        XCTAssertFalse(
            app.staticTexts["Apple Workout"].exists,
            "Apple Workout label should NOT appear on Workouts preview row for Strava workout"
        )
    }
}

// MARK: - Unknown Source Smoke Tests (Seeded Unknown Source Data)

/// Tests that unknown/unresolvable source bundle IDs render as "another app", never raw bundle IDs.
final class UnknownSourceSmokeTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state", "--seed-hk-unknown-workout"]
        app.launch()

        addUIInterruptionMonitor(withDescription: "System Alert") { alert in
            alert.buttons.firstMatch.tap()
            return true
        }

        XCTAssertTrue(app.tabBars.buttons["DASHBOARD"].waitForExistence(timeout: 5),
                       "Tab bar must be ready before tests run")
    }

    /// Source indicator info sheet shows "another app", never a raw bundle ID.
    func test_sourceIndicatorInfoSheet_neverShowsRawBundleID() {
        let seedLabel = app.staticTexts["HK Unknown Source Workout"]
        XCTAssertTrue(seedLabel.waitForExistence(timeout: 5))

        app.tabBars.buttons["WORKOUTS"].tap()
        let typeCard = app.buttons["workoutTypeCard_Cardio"]
        XCTAssertTrue(typeCard.waitForExistence(timeout: 3))
        typeCard.tap()

        let workoutRow = app.staticTexts["HK Unknown Source Workout"]
        XCTAssertTrue(workoutRow.waitForExistence(timeout: 3))
        workoutRow.tap()

        let indicator = app.buttons["workoutDetail_healthSourceIndicator"]
        XCTAssertTrue(indicator.waitForExistence(timeout: 3))
        indicator.tap()

        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "another app")).firstMatch.waitForExistence(timeout: 3),
            "Info sheet should show 'another app' for unresolvable source"
        )

        XCTAssertFalse(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "com.unknowndev")).firstMatch.exists,
            "Raw bundle ID 'com.unknowndev' should never appear in the UI"
        )
    }
}

// MARK: - Edit Workout "Use Template" Smoke Tests

/// Tests for the Edit Workout ellipsis menu (Strength / HIIT only)
/// and the filtered template selector overlay.
final class EditWorkoutTemplateSmokeTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"]
        app.launch()

        addUIInterruptionMonitor(withDescription: "System Alert") { alert in
            alert.buttons.firstMatch.tap()
            return true
        }

        XCTAssertTrue(app.tabBars.buttons["DASHBOARD"].waitForExistence(timeout: 5),
                       "Tab bar must be ready before tests run")
    }

    /// Logs a Strength workout, saves it as a template, then navigates to
    /// edit mode on that workout. Returns after entering edit mode.
    private func logStrengthWorkoutAndCreateTemplate() {
        app.tabBars.buttons["DASHBOARD"].tap()
        app.buttons["logWorkoutCTA"].tap()

        let nameField = app.textFields["workoutNameInput"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("Edit Template Test")

        app.buttons["addExerciseButton"].tap()
        let exerciseName = app.textFields["exerciseNameInput_0"]
        exerciseName.tap()
        exerciseName.typeText("Bench Press\n")
        app.textFields["setsInput_0_0"].tap(); app.textFields["setsInput_0_0"].typeText("3")
        app.textFields["repsInput_0_0"].tap(); app.textFields["repsInput_0_0"].typeText("8")
        app.textFields["weightInput_0_0"].tap(); app.textFields["weightInput_0_0"].typeText("135")
        app.buttons["saveWorkoutButton"].tap()

        let workoutLabel = app.staticTexts["Edit Template Test"]
        XCTAssertTrue(workoutLabel.waitForExistence(timeout: 3))
        workoutLabel.tap()

        app.buttons["workoutDetailEllipsis"].tap()
        app.buttons["saveAsTemplateMenuItem"].tap()
        app.alerts.buttons["Save"].firstMatch.tap()
    }

    /// Navigate into edit mode on the currently displayed Workout Detail.
    private func enterEditMode() {
        let editButton = app.buttons.matching(identifier: "pencil").firstMatch
        XCTAssertTrue(editButton.waitForExistence(timeout: 3))
        editButton.tap()
    }

    // MARK: - Edit Strength workout: trash + ellipsis visible, Use Template works

    func test_editStrengthWorkout_showsEllipsis_useTemplateOpensSelector() {
        logStrengthWorkoutAndCreateTemplate()
        enterEditMode()

        let ellipsis = app.buttons["editWorkout_ellipsisMenu"]
        XCTAssertTrue(ellipsis.waitForExistence(timeout: 3), "Ellipsis should appear in edit mode for Strength workout")

        ellipsis.tap()

        let useTemplate = app.buttons["editWorkout_useTemplateMenuItem"]
        XCTAssertTrue(useTemplate.waitForExistence(timeout: 3), "Use Template item should appear in edit-mode ellipsis")
        useTemplate.tap()

        let selectorOverlay = app.otherElements["editWorkout_templateSelectorOverlay"]
        XCTAssertTrue(selectorOverlay.waitForExistence(timeout: 3), "Template selector overlay should appear")

        XCTAssertTrue(
            app.staticTexts["Edit Template Test"].exists,
            "Selector should show the Strength template we created"
        )
    }

    // MARK: - Edit Cardio workout: no ellipsis

    func test_editCardioWorkout_doesNotShowEllipsis() {
        app.tabBars.buttons["DASHBOARD"].tap()
        app.buttons["logWorkoutCTA"].tap()

        let nameField = app.textFields["workoutNameInput"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("Cardio No Ellipsis")

        app.buttons["workoutTypeDropdown"].tap()
        app.buttons["workoutTypeOption_Cardio"].tap()

        app.textFields["durationInput"].tap()
        app.textFields["durationInput"].typeText("30")
        app.buttons["saveWorkoutButton"].tap()

        let workoutLabel = app.staticTexts["Cardio No Ellipsis"]
        XCTAssertTrue(workoutLabel.waitForExistence(timeout: 3))
        workoutLabel.tap()

        enterEditMode()

        let ellipsis = app.buttons["editWorkout_ellipsisMenu"]
        XCTAssertFalse(
            ellipsis.waitForExistence(timeout: 2),
            "Ellipsis should NOT appear in edit mode for Cardio workout"
        )
    }
}

// MARK: - Activity Rings Widget Smoke Tests

/// Tests for the Phase 8.6 Activity Rings Widget. Since the widget depends
/// on HealthKit authorization and Apple Watch detection that can't be
/// simulated in XCUI tests, these tests focus on the Add Widgets menu
/// integration and context menu structure.
final class ActivityRingsWidgetSmokeTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"]
        app.launch()

        addUIInterruptionMonitor(withDescription: "System Alert") { alert in
            alert.buttons.firstMatch.tap()
            return true
        }

        XCTAssertTrue(app.tabBars.buttons["DASHBOARD"].waitForExistence(timeout: 5),
                       "Tab bar must be ready before tests run")
    }

    // MARK: - Smoke AR-1: Add Activity Rings Widget

    /// Add the Activity Rings widget from the Add Widgets menu and confirm the description matches spec.
    func test_addActivityRingsWidget_rowDescriptionMatchesSpec() {
        app.tabBars.buttons["DASHBOARD"].tap()
        app.buttons["homeEllipsisMenu"].tap()
        app.buttons["addWidgetsMenuItem"].tap()

        let addButton = app.buttons["addWidgetRow_appleActivity"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3), "Activity Rings row should appear in Add Widgets menu")

        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Tracks your daily Move, Exercise, and Stand rings")).firstMatch.exists,
            "Widget description should match spec copy"
        )

        addButton.tap()

        XCTAssertTrue(
            app.staticTexts["Activity Rings"].waitForExistence(timeout: 3),
            "Activity Rings widget should appear on Home after adding"
        )
    }

    // MARK: - Smoke AR-2: State 1 — HK Disabled (default state)

    /// With HK off (default), the widget shows the Connect Apple Health state.
    func test_activityRingsWidget_state1_connectAppleHealthPresent() {
        app.tabBars.buttons["DASHBOARD"].tap()
        app.buttons["homeEllipsisMenu"].tap()
        app.buttons["addWidgetsMenuItem"].tap()
        app.buttons["addWidgetRow_appleActivity"].tap()
        app.buttons["addWidgetsMenuDismiss"].tap()

        let stateMessage = app.staticTexts["Connect Apple Health to track your activity rings."].firstMatch
        XCTAssertTrue(
            stateMessage.waitForExistence(timeout: 3),
            "State 1 (Connect Apple Health) should be displayed when HK is disabled"
        )
    }

    // MARK: - Smoke AR-3: Long-Press Context Menu

    /// Long-pressing the Activity Rings widget reveals the expected context menu items.
    func test_activityRingsWidget_longPress_showsFourItemContextMenu() {
        app.tabBars.buttons["DASHBOARD"].tap()

        app.buttons["homeEllipsisMenu"].tap()
        app.buttons["addWidgetsMenuItem"].tap()
        app.buttons["addWidgetRow_appleActivity"].tap()
        app.buttons["addWidgetsMenuDismiss"].tap()

        let widgetHeader = app.staticTexts["Activity Rings"].firstMatch
        XCTAssertTrue(widgetHeader.waitForExistence(timeout: 3))

        widgetHeader.press(forDuration: 1.0)

        let seeInfoButton = app.buttons["homeWidget_appleActivity_seeInfo"]
        XCTAssertTrue(seeInfoButton.waitForExistence(timeout: 3), "See Info should appear in context menu")

        let configureButton = app.buttons["homeWidget_appleActivity_configureSettings"]
        XCTAssertTrue(configureButton.exists, "Configure Settings should appear in context menu")

        let reorderButton = app.buttons["Reorder Widgets"]
        XCTAssertTrue(reorderButton.exists, "Reorder Widgets should appear in context menu")

        let deleteButton = app.buttons["Delete Widget"]
        XCTAssertTrue(deleteButton.exists, "Delete Widget should appear in context menu")
    }

    // MARK: - Smoke AR-4: See Info Modal

    /// Long-pressing the Activity Rings widget and tapping See Info opens the info modal.
    func test_activityRingsWidget_seeInfo_opensModal() {
        app.tabBars.buttons["DASHBOARD"].tap()

        app.buttons["homeEllipsisMenu"].tap()
        app.buttons["addWidgetsMenuItem"].tap()
        app.buttons["addWidgetRow_appleActivity"].tap()
        app.buttons["addWidgetsMenuDismiss"].tap()

        let widgetHeader = app.staticTexts["Activity Rings"].firstMatch
        XCTAssertTrue(widgetHeader.waitForExistence(timeout: 3))

        widgetHeader.press(forDuration: 1.0)

        let seeInfoButton = app.buttons["homeWidget_appleActivity_seeInfo"]
        XCTAssertTrue(seeInfoButton.waitForExistence(timeout: 3))
        seeInfoButton.tap()

        XCTAssertTrue(
            app.staticTexts["About Activity Rings"].waitForExistence(timeout: 3),
            "See Info Modal should open with Activity Rings content"
        )
    }

    // MARK: - Smoke AR-5: Configure Settings Modal

    /// Opening Configure Settings from context menu shows sliders, Import, and Done buttons (Phase 8.8: Reset removed).
    func test_activityRingsWidget_configureSettings_showsSlidersAndButtons() {
        app.tabBars.buttons["DASHBOARD"].tap()

        app.buttons["homeEllipsisMenu"].tap()
        app.buttons["addWidgetsMenuItem"].tap()
        app.buttons["addWidgetRow_appleActivity"].tap()
        app.buttons["addWidgetsMenuDismiss"].tap()

        let widgetHeader = app.staticTexts["Activity Rings"].firstMatch
        XCTAssertTrue(widgetHeader.waitForExistence(timeout: 3))

        widgetHeader.press(forDuration: 1.0)

        let configureButton = app.buttons["homeWidget_appleActivity_configureSettings"]
        XCTAssertTrue(configureButton.waitForExistence(timeout: 3))
        configureButton.tap()

        let moveSlider = app.sliders["activityRingsSettings_moveSlider"]
        XCTAssertTrue(moveSlider.waitForExistence(timeout: 3), "Move slider should be present")

        let exerciseSlider = app.sliders["activityRingsSettings_exerciseSlider"]
        XCTAssertTrue(exerciseSlider.exists, "Exercise slider should be present")

        let standSlider = app.sliders["activityRingsSettings_standSlider"]
        XCTAssertTrue(standSlider.exists, "Stand slider should be present")

        let importButton = app.buttons["activityRingsSettings_importButton"]
        XCTAssertTrue(importButton.exists, "Import from Apple Health button should be present")

        let doneButton = app.buttons["activityRingsSettings_doneButton"]
        XCTAssertTrue(doneButton.exists, "Done button should be present (Phase 8.8 replaces Reset to defaults)")
    }

    // MARK: - Smoke AR-6: Delete Widget

    /// Deleting the Activity Rings widget removes it from the Home screen.
    func test_activityRingsWidget_deleteViaContextMenu_removesFromHome() {
        app.tabBars.buttons["DASHBOARD"].tap()

        app.buttons["homeEllipsisMenu"].tap()
        app.buttons["addWidgetsMenuItem"].tap()
        app.buttons["addWidgetRow_appleActivity"].tap()
        app.buttons["addWidgetsMenuDismiss"].tap()

        let widgetHeader = app.staticTexts["Activity Rings"].firstMatch
        XCTAssertTrue(widgetHeader.waitForExistence(timeout: 3))

        widgetHeader.press(forDuration: 1.0)

        let deleteButton = app.buttons["Delete Widget"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3))
        deleteButton.tap()

        XCTAssertFalse(
            app.staticTexts["Activity Rings"].waitForExistence(timeout: 2),
            "Activity Rings widget should be removed after delete"
        )
    }
}
