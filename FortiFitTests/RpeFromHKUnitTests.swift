import Testing
import Foundation
import SwiftData
@testable import FortiFit

private func makeTestContext() throws -> ModelContext {
    let schema = Schema([
        Workout.self, ExerciseSet.self, Goal.self, GoalSnapshot.self,
        WorkoutTypeOrder.self, WorkoutMatchRejection.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

@MainActor
struct RpeFromHKUnitTests {

    @Test func test_manualLogWorkout_rpeFromHKDefaultsFalse() throws {
        let context = try makeTestContext()
        let workout = Workout(name: "Push Day", workoutType: "Strength Training", rpe: 7)
        context.insert(workout)
        try context.save()

        #expect(workout.rpeFromHK == false)
    }

    @Test func test_userEditsRPEOnImportedWorkout_rpeFromHKClearsToFalse() throws {
        let context = try makeTestContext()
        let workout = Workout(
            name: "HK Strength",
            workoutType: "Strength Training",
            rpe: 5,
            healthKitUUID: UUID(),
            healthKitSourceBundleID: "com.apple.health.workout-builder",
            healthKitActivityType: "Traditional Strength Training"
        )
        workout.rpeFromHK = true
        context.insert(workout)
        try context.save()

        WorkoutService.updateWorkout(
            workout,
            name: workout.name,
            date: workout.date,
            time: workout.time,
            rpe: 7,
            durationMinutes: workout.durationMinutes,
            distanceKm: workout.distanceKm,
            newExerciseSets: []
        )

        #expect(workout.rpeFromHK == false)
        #expect(workout.rpe == 7)
    }

    @Test func test_linkFlowToManualWorkoutWithExistingRPE_rpeFromHKStaysFalse() throws {
        let context = try makeTestContext()
        let now = Date()
        let workout = Workout(
            name: "My Run",
            date: now,
            workoutType: "Cardio",
            rpe: 6
        )
        context.insert(workout)
        try context.save()

        let snapshot = HealthKitWorkoutSnapshot(
            uuid: UUID(),
            activityTypeRawValue: 37,
            sourceBundleID: "com.apple.health.workout-builder",
            startDate: now,
            endDate: now.addingTimeInterval(1800),
            durationMinutes: 30,
            distanceKm: nil,
            avgHeartRate: 142,
            maxHeartRate: 168,
            activeEnergyKcal: 487,
            totalEnergyBurnedKcal: 612,
            elevationAscendedMeters: nil,
            exerciseMinutes: 28,
            indoor: false
        )
        WorkoutMatcher.applyLink(workout: workout, snapshot: snapshot)

        #expect(workout.rpe == 6, "User-entered RPE should be unchanged")
        #expect(workout.rpeFromHK == false, "HK never overwrites user-entered RPE")
    }
}
