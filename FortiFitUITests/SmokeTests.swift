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
        case home = "HOME"
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
        XCTAssertTrue(goalTypeButton.waitForExistence(timeout: 3), "Add Goal screen did not load")
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
            app.staticTexts["Weekly Streak"].waitForExistence(timeout: 3),
            "Expected Weekly Streak widget to appear after Add"
        )
    }

    // MARK: - Smoke 8: Save as Template

    /// User can save a logged Strength workout as a template and see it in Saved Templates.
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

        // Navigate to Saved Templates via Workouts → Ellipsis
        app.tabBars.buttons[Tab.workouts.rawValue].tap()
        app.buttons["workoutsEllipsisMenu"].tap()
        app.buttons["viewSavedTemplatesMenuItem"].tap()

        XCTAssertTrue(
            app.staticTexts["Template Source"].waitForExistence(timeout: 3),
            "Expected saved template to appear in Saved Templates list"
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

    /// Navigating away from Workouts while Saved Templates is pushed should pop back to root on return.
    func test_workoutsTab_resetsNavigationOnTabSwitch() {
        app.tabBars.buttons[Tab.workouts.rawValue].tap()

        // Push into Saved Templates via ellipsis menu
        app.buttons["workoutsEllipsisMenu"].tap()
        let templatesItem = app.buttons["viewSavedTemplatesMenuItem"]
        XCTAssertTrue(templatesItem.waitForExistence(timeout: 2))
        templatesItem.tap()

        // Verify we navigated away from root (ellipsis should not be visible on Templates screen)
        XCTAssertFalse(app.buttons["workoutsEllipsisMenu"].waitForExistence(timeout: 1), "Should have navigated to Saved Templates")

        // Switch away and back
        app.tabBars.buttons[Tab.home.rawValue].tap()
        app.tabBars.buttons[Tab.workouts.rawValue].tap()

        // Should be back at Workouts root
        XCTAssertTrue(app.buttons["workoutsEllipsisMenu"].waitForExistence(timeout: 2), "Workouts ellipsis should be visible after tab reset")
    }

    // MARK: - Smoke 14: Tab Reset — Plan

    /// Navigating away from Plan while Saved Templates is pushed should pop back to root on return.
    func test_planTab_resetsNavigationOnTabSwitch() {
        app.tabBars.buttons[Tab.plan.rawValue].tap()

        // Push into Saved Templates via Plan's ellipsis menu
        app.buttons["planEllipsisMenu"].tap()
        let templatesItem = app.buttons["planSavedTemplatesMenuItem"]
        XCTAssertTrue(templatesItem.waitForExistence(timeout: 2))
        templatesItem.tap()

        // Verify we navigated away from root (Plan ellipsis should not be visible)
        XCTAssertFalse(app.buttons["planEllipsisMenu"].waitForExistence(timeout: 1), "Should have navigated to Saved Templates")

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

    /// Navigating away from Goals while Add Goal is pushed should pop back to root on return.
    func test_goalsTab_resetsNavigationOnTabSwitch() {
        app.tabBars.buttons[Tab.goals.rawValue].tap()

        // Push into Add Goal
        let addButton = app.buttons["addGoalButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        addButton.tap()

        // Verify we're on Add Goal screen (goal type selector should exist)
        XCTAssertTrue(app.buttons["Select Goal Type"].waitForExistence(timeout: 2), "Add Goal screen should be pushed")

        // Switch away and back
        app.tabBars.buttons[Tab.home.rawValue].tap()
        app.tabBars.buttons[Tab.goals.rawValue].tap()

        // Should be back at Goals root
        XCTAssertTrue(app.buttons["addGoalButton"].waitForExistence(timeout: 2), "Add Goal button should be visible after tab reset")
        XCTAssertFalse(app.buttons["Select Goal Type"].exists, "Add Goal screen should be dismissed after tab reset")
    }

    // MARK: - Smoke 17: Settings — Apple Health Section

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
            app.buttons["workoutDetail_healthSourceIndicator"].waitForExistence(timeout: 2),
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

        let durationHelper = app.buttons["logWorkout_durationReadOnlyHelper"]
        XCTAssertTrue(durationHelper.waitForExistence(timeout: 3), "Duration read-only helper should be visible")

        let distanceHelper = app.buttons["logWorkout_distanceReadOnlyHelper"]
        XCTAssertTrue(distanceHelper.exists, "Distance read-only helper should be visible")
    }

    // MARK: - Smoke HK-6: Health Glyph on Home Screen

    /// HK-linked workout shows the pink heart glyph next to its name on the Home screen.
    func test_hkLinkedWorkout_showsHealthGlyphOnHome() {
        // Wait for seed to complete on Home
        let seedLabel = app.staticTexts["HK Smoke Test Run"]
        XCTAssertTrue(seedLabel.waitForExistence(timeout: 5), "Seeded HK workout should appear on Home")

        let glyphImage = app.images["healthGlyph"]
        XCTAssertTrue(glyphImage.exists, "Heart glyph should be visible next to HK-linked workout name on Home")
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
        let homeTab = app.tabBars.buttons["HOME"]
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
