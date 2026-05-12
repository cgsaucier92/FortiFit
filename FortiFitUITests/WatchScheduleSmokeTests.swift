import XCTest

final class WatchScheduleSmokeTests: XCTestCase {

    enum Tab: String {
        case home = "DASHBOARD"
        case workouts = "WORKOUTS"
        case plan = "PLAN"
    }

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

        XCTAssertTrue(app.tabBars.buttons[Tab.home.rawValue].waitForExistence(timeout: 5))
    }

    // MARK: - Settings Apple Watch Section

    func test_settings_appleWatchSection_showsToggleAndDescription() {
        app.tabBars.buttons[Tab.home.rawValue].tap()
        app.buttons["settingsGearIcon"].tap()

        let toggle = app.switches["settings_appleWatchToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3), "Apple Watch toggle should exist in Settings")

        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Apple Watch")).firstMatch.exists,
            "Apple Watch toggle label should be visible"
        )

        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Push planned workouts")).firstMatch.exists,
            "Apple Watch toggle label should use 'Push' wording"
        )
    }

    // MARK: - Schedule Workout Push Toggle

    func test_scheduleWorkout_pushToggleExists() {
        app.tabBars.buttons[Tab.home.rawValue].tap()
        app.buttons["logWorkoutCTA"].tap()

        let nameField = app.textFields["workoutNameInput"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("Push Toggle Test")
        app.buttons["addExerciseButton"].tap()
        let exerciseName = app.textFields["exerciseNameInput_0"]
        exerciseName.tap()
        exerciseName.typeText("Squat\n")
        app.textFields["setsInput_0_0"].tap(); app.textFields["setsInput_0_0"].typeText("3")
        app.textFields["repsInput_0_0"].tap(); app.textFields["repsInput_0_0"].typeText("5")
        app.buttons["saveWorkoutButton"].tap()

        let workoutCell = app.staticTexts["Push Toggle Test"]
        XCTAssertTrue(workoutCell.waitForExistence(timeout: 3))
        workoutCell.tap()
        app.buttons["workoutDetailEllipsis"].tap()
        app.buttons["saveAsTemplateMenuItem"].tap()
        app.alerts.buttons["Save"].firstMatch.tap()

        app.tabBars.buttons[Tab.plan.rawValue].tap()
        app.buttons["planAddButton"].tap()

        let templateRow = app.buttons["templateSelectionRow_0"]
        XCTAssertTrue(templateRow.waitForExistence(timeout: 3))

        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Push to Apple Watch")).firstMatch.waitForExistence(timeout: 3),
            "Push to Apple Watch toggle label should appear on Schedule Workout sheet"
        )
    }

    // MARK: - Edit Scheduled Workout Flow

    func test_editScheduledWorkout_opensAndSaves() {
        app.tabBars.buttons[Tab.home.rawValue].tap()
        app.buttons["logWorkoutCTA"].tap()

        let nameField = app.textFields["workoutNameInput"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("Edit Flow Test")
        app.buttons["addExerciseButton"].tap()
        let exerciseName = app.textFields["exerciseNameInput_0"]
        exerciseName.tap()
        exerciseName.typeText("Squat\n")
        app.textFields["setsInput_0_0"].tap(); app.textFields["setsInput_0_0"].typeText("3")
        app.textFields["repsInput_0_0"].tap(); app.textFields["repsInput_0_0"].typeText("5")
        app.buttons["saveWorkoutButton"].tap()

        let workoutCell = app.staticTexts["Edit Flow Test"]
        XCTAssertTrue(workoutCell.waitForExistence(timeout: 3))
        workoutCell.tap()
        app.buttons["workoutDetailEllipsis"].tap()
        app.buttons["saveAsTemplateMenuItem"].tap()
        app.alerts.buttons["Save"].firstMatch.tap()

        app.tabBars.buttons[Tab.plan.rawValue].tap()
        app.buttons["planAddButton"].tap()

        let templateRow = app.buttons["templateSelectionRow_0"]
        XCTAssertTrue(templateRow.waitForExistence(timeout: 3))
        templateRow.tap()
        app.buttons["scheduleWorkoutConfirmButton"].tap()

        let card = app.buttons["scheduledWorkoutCard_0"]
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        card.press(forDuration: 1.0)

        let editMenuItem = app.buttons["planScheduledCardEditMenuItem"]
        XCTAssertTrue(editMenuItem.waitForExistence(timeout: 3))
        editMenuItem.tap()

        let saveButton = app.buttons["editScheduledWorkout_saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Edit Planned Workout screen should load with save button")

        saveButton.tap()

        XCTAssertTrue(
            app.buttons["scheduledWorkoutCard_0"].waitForExistence(timeout: 3),
            "Scheduled workout card should persist after edit-save"
        )
    }
}
