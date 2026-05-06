import XCTest
import SwiftData
@testable import FortiFit

@MainActor
final class ActivityRingsIntegrationTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        let result = try TestFixtures.inMemoryContext()
        container = result.0
        context = result.1
    }

    // MARK: - Weekly Closure Count

    func test_closedAllRingsDayCount_correctlyCountsClosedDays() async throws {
        let stubClient = StubHealthKitClient()
        let service = AppleActivityService(client: stubClient)

        UserSettings.shared.targetMoveCalories = 500
        UserSettings.shared.targetExerciseMinutes = 30
        UserSettings.shared.targetStandHours = 12

        let calendar = Calendar.current
        let today = Date()
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else {
            XCTFail("Could not determine current calendar week")
            return
        }
        let weekStart = weekInterval.start
        let elapsedDays = calendar.dateComponents([.day], from: weekStart, to: calendar.startOfDay(for: today)).day! + 1

        var summaries: [ActivitySummarySnapshot] = []
        for dayOffset in 0..<elapsedDays {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
            let allClosed = dayOffset % 2 == 0
            summaries.append(ActivitySummarySnapshot(
                date: date,
                moveCalories: allClosed ? 600 : 200,
                exerciseMinutes: allClosed ? 35 : 10,
                standHours: allClosed ? 14 : 5,
                moveGoal: 500,
                exerciseGoal: 30,
                standGoal: 12
            ))
        }

        stubClient.activitySummariesToReturn = summaries

        await service.refreshWeeklyClosure()

        let expectedClosedDays = summaries.filter { s in
            s.moveCalories >= 500 && s.exerciseMinutes >= 30 && s.standHours >= 12
        }.count

        XCTAssertEqual(service.closedAllRingsDayCount, expectedClosedDays)
        XCTAssertEqual(service.weekElapsedDays, elapsedDays)
    }

    // MARK: - Widget State Transitions

    func test_widgetState_transitionsFromState1ToState3() async throws {
        let stubClient = StubHealthKitClient()
        let service = AppleActivityService(client: stubClient)

        UserSettings.shared.healthKitEnabled = false
        XCTAssertEqual(service.widgetState, .connectAppleHealth, "State 1: HK disabled")

        UserSettings.shared.healthKitEnabled = true
        service.appleWatchDetected = false
        XCTAssertEqual(service.widgetState, .pairAppleWatch, "State 2: HK enabled, no Watch")

        stubClient.hasAppleWatchDataToReturn = true
        await service.refreshWatchDetection()
        XCTAssertEqual(service.widgetState, .liveRings, "State 3: HK enabled + Watch detected")
    }

    // MARK: - First-Config Goal Import

    func test_firstWidgetAdd_populatesUserSettingsFromHKGoals() async throws {
        let stubClient = StubHealthKitClient()
        stubClient.activitySummaryToReturn = ActivitySummarySnapshot(
            date: Date(),
            moveCalories: 300,
            exerciseMinutes: 20,
            standHours: 8,
            moveGoal: 650,
            exerciseGoal: 40,
            standGoal: 14
        )
        let service = AppleActivityService(client: stubClient)

        UserSettings.shared.targetMoveCalories = nil
        UserSettings.shared.targetExerciseMinutes = nil
        UserSettings.shared.targetStandHours = nil

        await service.importGoalsFromAppleHealth()

        XCTAssertEqual(UserSettings.shared.targetMoveCalories, 650)
        XCTAssertEqual(UserSettings.shared.targetExerciseMinutes, 40)
        XCTAssertEqual(UserSettings.shared.targetStandHours, 14)
    }

    // MARK: - Workout Contribution Refresh

    func test_workoutContribution_hkLinkedWorkoutUpdatesContributions() async throws {
        let stubClient = StubHealthKitClient()
        let service = AppleActivityService(client: stubClient)

        let hkWorkout = Workout(
            name: "Apple Watch Run",
            date: Date(),
            workoutType: "Cardio",
            healthKitUUID: UUID(),
            activeEnergyKcal: 320,
            exerciseMinutes: 28
        )
        context.insert(hkWorkout)
        try context.save()

        service.refreshWorkoutContributions(context: context)

        XCTAssertEqual(service.todayMoveContributionFromWorkouts, 320)
        XCTAssertEqual(service.todayExerciseContributionFromWorkouts, 28)
        XCTAssertEqual(service.todayContributingWorkoutNames, ["Apple Watch Run"])
    }

    func test_workoutContribution_manualWorkoutDoesNotContribute() async throws {
        let stubClient = StubHealthKitClient()
        let service = AppleActivityService(client: stubClient)

        let manualWorkout = Workout(
            name: "Manual Push Day",
            date: Date(),
            workoutType: "Strength Training",
            durationMinutes: 60
        )
        context.insert(manualWorkout)
        try context.save()

        service.refreshWorkoutContributions(context: context)

        XCTAssertEqual(service.todayMoveContributionFromWorkouts, 0)
        XCTAssertEqual(service.todayExerciseContributionFromWorkouts, 0)
        XCTAssertTrue(service.todayContributingWorkoutNames.isEmpty)
    }

    // MARK: - Watch Detection

    func test_watchDetection_updatesFromClient() async throws {
        let stubClient = StubHealthKitClient()
        let service = AppleActivityService(client: stubClient)

        stubClient.hasAppleWatchDataToReturn = false
        await service.refreshWatchDetection()
        XCTAssertFalse(service.appleWatchDetected)

        stubClient.hasAppleWatchDataToReturn = true
        await service.refreshWatchDetection()
        XCTAssertTrue(service.appleWatchDetected)
    }
}
