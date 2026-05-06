import Testing
import Foundation
import SwiftData
@testable import FortiFit

private final class ActivityStubClient: HealthKitClient, @unchecked Sendable {
    var activitySummaryToReturn: ActivitySummarySnapshot? = nil
    var activitySummariesToReturn: [ActivitySummarySnapshot] = []
    var hasAppleWatchDataToReturn: Bool = false

    func requestAuthorization() async throws {}
    func authorizationStatus() -> HealthKitAuthorizationStatus { .granted }
    func fetchWorkouts(since anchor: Data?) async throws -> (workouts: [HealthKitWorkoutSnapshot], deletedUUIDs: [UUID], newAnchor: Data?) { ([], [], nil) }
    func observeWorkoutChanges(handler: @escaping @Sendable () -> Void) {}
    func observeEffortScoreChanges(handler: @escaping @Sendable () -> Void) {}
    func fetchEffortScore(for hkWorkoutUUID: UUID) async throws -> Int? { nil }
    func sourceName(for bundleID: String) -> String { "Apple Workout" }
    func fetchActivitySummary(for date: Date) async throws -> ActivitySummarySnapshot? { activitySummaryToReturn }
    func fetchActivitySummaries(from start: Date, to end: Date) async throws -> [ActivitySummarySnapshot] { activitySummariesToReturn }
    func observeActivitySummaryChanges(handler: @escaping @Sendable () -> Void) {}
    func hasAppleWatchData(within days: Int) async throws -> Bool { hasAppleWatchDataToReturn }
}

@Suite(.serialized)
struct AppleActivityServiceTests {

    // MARK: - Progress Ratio (uncapped)

    @Test func moveProgressComputesUncappedRatio() async {
        let stub = ActivityStubClient()
        let service = await AppleActivityService(client: stub)
        let settings = await MainActor.run { UserSettings.shared }
        await MainActor.run {
            settings.targetMoveCalories = 1000
            service.moveCalories = 1500
        }
        let progress = await service.moveProgress
        #expect(progress == 1.5)
    }

    @Test func exerciseProgressComputesUncappedRatio() async {
        let stub = ActivityStubClient()
        let service = await AppleActivityService(client: stub)
        let settings = await MainActor.run { UserSettings.shared }
        await MainActor.run {
            settings.targetExerciseMinutes = 30
            service.exerciseMinutes = 60
        }
        let progress = await service.exerciseProgress
        #expect(progress == 2.0)
    }

    @Test func standProgressComputesUncappedRatio() async {
        let stub = ActivityStubClient()
        let service = await AppleActivityService(client: stub)
        let settings = await MainActor.run { UserSettings.shared }
        await MainActor.run {
            settings.targetStandHours = 12
            service.standHours = 18
        }
        let progress = await service.standProgress
        #expect(progress == 1.5)
    }

    @Test func progressUsesDefaultGoalWhenNilInSettings() async {
        let stub = ActivityStubClient()
        let service = await AppleActivityService(client: stub)
        let settings = await MainActor.run { UserSettings.shared }
        await MainActor.run {
            settings.targetMoveCalories = nil
            service.moveCalories = 500
        }
        let progress = await service.moveProgress
        let goal = await service.moveGoal
        #expect(goal == AppConstants.ActivityRings.moveDefault)
        #expect(progress == Double(500) / Double(AppConstants.ActivityRings.moveDefault))
    }

    // MARK: - All Rings Closed

    @Test func allRingsClosedTodayTrueWhenAllAboveGoal() async {
        let stub = ActivityStubClient()
        let service = await AppleActivityService(client: stub)
        let settings = await MainActor.run { UserSettings.shared }
        await MainActor.run {
            settings.targetMoveCalories = 500
            settings.targetExerciseMinutes = 30
            settings.targetStandHours = 12
            service.moveCalories = 600
            service.exerciseMinutes = 35
            service.standHours = 14
        }
        let closed = await service.allRingsClosedToday
        #expect(closed == true)
    }

    @Test func allRingsClosedTodayFalseWhenOneRingOpen() async {
        let stub = ActivityStubClient()
        let service = await AppleActivityService(client: stub)
        let settings = await MainActor.run { UserSettings.shared }
        await MainActor.run {
            settings.targetMoveCalories = 500
            settings.targetExerciseMinutes = 30
            settings.targetStandHours = 12
            service.moveCalories = 600
            service.exerciseMinutes = 20
            service.standHours = 14
        }
        let closed = await service.allRingsClosedToday
        #expect(closed == false)
    }

    @Test func allRingsClosedTodayTrueWhenExactlyAtGoal() async {
        let stub = ActivityStubClient()
        let service = await AppleActivityService(client: stub)
        let settings = await MainActor.run { UserSettings.shared }
        await MainActor.run {
            settings.targetMoveCalories = 500
            settings.targetExerciseMinutes = 30
            settings.targetStandHours = 12
            service.moveCalories = 500
            service.exerciseMinutes = 30
            service.standHours = 12
        }
        let closed = await service.allRingsClosedToday
        #expect(closed == true)
    }

    // MARK: - Goal Import

    @Test func goalImportWithValidHKGoals() async {
        let stub = ActivityStubClient()
        stub.activitySummaryToReturn = ActivitySummarySnapshot(
            date: Date(), moveCalories: 200, exerciseMinutes: 15, standHours: 8,
            moveGoal: 750, exerciseGoal: 45, standGoal: 14
        )
        let service = await AppleActivityService(client: stub)
        let settings = await MainActor.run { UserSettings.shared }
        await MainActor.run {
            settings.targetMoveCalories = nil
            settings.targetExerciseMinutes = nil
            settings.targetStandHours = nil
        }
        await service.importGoalsFromAppleHealth()
        let move = await MainActor.run { settings.targetMoveCalories }
        let exercise = await MainActor.run { settings.targetExerciseMinutes }
        let stand = await MainActor.run { settings.targetStandHours }
        #expect(move == 750)
        #expect(exercise == 45)
        #expect(stand == 14)
    }

    @Test func goalImportWithZeroHKGoalsFallsBackToDefaults() async {
        let stub = ActivityStubClient()
        stub.activitySummaryToReturn = ActivitySummarySnapshot(
            date: Date(), moveCalories: 0, exerciseMinutes: 0, standHours: 0,
            moveGoal: 0, exerciseGoal: 0, standGoal: 0
        )
        let service = await AppleActivityService(client: stub)
        let settings = await MainActor.run { UserSettings.shared }
        await MainActor.run {
            settings.targetMoveCalories = nil
            settings.targetExerciseMinutes = nil
            settings.targetStandHours = nil
        }
        await service.importGoalsFromAppleHealth()
        let move = await MainActor.run { settings.targetMoveCalories }
        let exercise = await MainActor.run { settings.targetExerciseMinutes }
        let stand = await MainActor.run { settings.targetStandHours }
        #expect(move == 500)
        #expect(exercise == 30)
        #expect(stand == 12)
    }

    @Test func goalImportWithOffIncrementValueSnapsToNearest() async {
        let stub = ActivityStubClient()
        stub.activitySummaryToReturn = ActivitySummarySnapshot(
            date: Date(), moveCalories: 200, exerciseMinutes: 15, standHours: 8,
            moveGoal: 753, exerciseGoal: 47, standGoal: 14
        )
        let service = await AppleActivityService(client: stub)
        let settings = await MainActor.run { UserSettings.shared }
        await MainActor.run {
            settings.targetMoveCalories = nil
            settings.targetExerciseMinutes = nil
            settings.targetStandHours = nil
        }
        await service.importGoalsFromAppleHealth()
        let move = await MainActor.run { settings.targetMoveCalories }
        let exercise = await MainActor.run { settings.targetExerciseMinutes }
        #expect(move == 750)
        #expect(exercise == 45)
    }

    @Test func goalImportWithNilSummaryFallsBackToDefaults() async {
        let stub = ActivityStubClient()
        stub.activitySummaryToReturn = nil
        let service = await AppleActivityService(client: stub)
        let settings = await MainActor.run { UserSettings.shared }
        await MainActor.run {
            settings.targetMoveCalories = nil
            settings.targetExerciseMinutes = nil
            settings.targetStandHours = nil
        }
        await service.importGoalsFromAppleHealth()
        let move = await MainActor.run { settings.targetMoveCalories }
        let exercise = await MainActor.run { settings.targetExerciseMinutes }
        let stand = await MainActor.run { settings.targetStandHours }
        #expect(move == 500)
        #expect(exercise == 30)
        #expect(stand == 12)
    }

    // MARK: - Workout Contributions

    @Test func workoutContributionSingleHKLinkedWorkout() async throws {
        let context = try makeTestContext()
        let stub = ActivityStubClient()
        let service = await AppleActivityService(client: stub)
        let today = Date()
        await MainActor.run {
            let workout = Workout(
                name: "Morning Run", date: today, workoutType: "Cardio",
                healthKitUUID: UUID(), activeEnergyKcal: 187, exerciseMinutes: 22
            )
            context.insert(workout)
            try? context.save()
            service.refreshWorkoutContributions(context: context)
        }
        let move = await service.todayMoveContributionFromWorkouts
        let exercise = await service.todayExerciseContributionFromWorkouts
        #expect(move == 187)
        #expect(exercise == 22)
    }

    @Test func workoutContributionMultipleHKLinkedWorkoutsSums() async throws {
        let context = try makeTestContext()
        let stub = ActivityStubClient()
        let service = await AppleActivityService(client: stub)
        let today = Date()
        await MainActor.run {
            let w1 = Workout(
                name: "Morning Run", date: today, workoutType: "Cardio",
                healthKitUUID: UUID(), activeEnergyKcal: 187, exerciseMinutes: 22
            )
            let w2 = Workout(
                name: "Evening Ride", date: today, workoutType: "Cardio",
                healthKitUUID: UUID(), activeEnergyKcal: 100, exerciseMinutes: 15
            )
            context.insert(w1)
            context.insert(w2)
            try? context.save()
            service.refreshWorkoutContributions(context: context)
        }
        let move = await service.todayMoveContributionFromWorkouts
        let exercise = await service.todayExerciseContributionFromWorkouts
        #expect(move == 287)
        #expect(exercise == 37)
    }

    @Test func workoutContributionManualWorkoutExcluded() async throws {
        let context = try makeTestContext()
        let stub = ActivityStubClient()
        let service = await AppleActivityService(client: stub)
        let today = Date()
        await MainActor.run {
            let manualWorkout = Workout(
                name: "Manual Push Day", date: today, workoutType: "Strength Training",
                durationMinutes: 60
            )
            context.insert(manualWorkout)
            try? context.save()
            service.refreshWorkoutContributions(context: context)
        }
        let move = await service.todayMoveContributionFromWorkouts
        let exercise = await service.todayExerciseContributionFromWorkouts
        #expect(move == 0)
        #expect(exercise == 0)
    }

    // MARK: - Slider Increment Rounding

    @Test func sliderIncrementRoundingSnaps753To750() async {
        let stub = ActivityStubClient()
        stub.activitySummaryToReturn = ActivitySummarySnapshot(
            date: Date(), moveCalories: 200, exerciseMinutes: 15, standHours: 8,
            moveGoal: 753, exerciseGoal: 30, standGoal: 12
        )
        let service = await AppleActivityService(client: stub)
        let settings = await MainActor.run { UserSettings.shared }
        await MainActor.run { settings.targetMoveCalories = nil }
        await service.importGoalsFromAppleHealth()
        let move = await MainActor.run { settings.targetMoveCalories }
        #expect(move == 750)
    }

    @Test func sliderIncrementRoundingSnaps758To760() async {
        let stub = ActivityStubClient()
        stub.activitySummaryToReturn = ActivitySummarySnapshot(
            date: Date(), moveCalories: 200, exerciseMinutes: 15, standHours: 8,
            moveGoal: 758, exerciseGoal: 30, standGoal: 12
        )
        let service = await AppleActivityService(client: stub)
        let settings = await MainActor.run { UserSettings.shared }
        await MainActor.run { settings.targetMoveCalories = nil }
        await service.importGoalsFromAppleHealth()
        let move = await MainActor.run { settings.targetMoveCalories }
        #expect(move == 760)
    }

    // MARK: - Widget State

    @Test func widgetStateConnectAppleHealthWhenHKDisabled() async {
        let stub = ActivityStubClient()
        let service = await AppleActivityService(client: stub)
        let settings = await MainActor.run { UserSettings.shared }
        await MainActor.run { settings.healthKitEnabled = false }
        let state = await service.widgetState
        #expect(state == .connectAppleHealth)
    }

    @Test func widgetStatePairAppleWatchWhenHKEnabledNoWatch() async {
        let stub = ActivityStubClient()
        let service = await AppleActivityService(client: stub)
        let settings = await MainActor.run { UserSettings.shared }
        await MainActor.run {
            settings.healthKitEnabled = true
            service.appleWatchDetected = false
        }
        let state = await service.widgetState
        #expect(state == .pairAppleWatch)
    }

    @Test func widgetStateLiveRingsWhenHKEnabledAndWatchDetected() async {
        let stub = ActivityStubClient()
        let service = await AppleActivityService(client: stub)
        let settings = await MainActor.run { UserSettings.shared }
        await MainActor.run {
            settings.healthKitEnabled = true
            service.appleWatchDetected = true
        }
        let state = await service.widgetState
        #expect(state == .liveRings)
    }

    // MARK: - Helpers

    private func makeTestContext() throws -> ModelContext {
        let schema = Schema([Workout.self, ExerciseSet.self, Goal.self, GoalSnapshot.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }
}
