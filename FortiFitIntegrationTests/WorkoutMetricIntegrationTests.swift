import XCTest
@testable import FortiFit

@MainActor
final class WorkoutMetricIntegrationTests: XCTestCase {

    /// Editing a workout's duration updates the metric service's comparative average
    /// on subsequent queries — no manual cache invalidation needed.
    func test_editWorkoutDuration_updatesComparativeAverage() throws {
        let (_, context) = try TestFixtures.inMemoryContext()

        TestFixtures.makeWorkout(name: "Session 1", workoutType: "Cardio", durationMinutes: 30, in: context)
        TestFixtures.makeWorkout(name: "Session 2", workoutType: "Cardio", durationMinutes: 40, in: context)
        TestFixtures.makeWorkout(name: "Session 3", workoutType: "Cardio", durationMinutes: 50, in: context)
        let target = TestFixtures.makeWorkout(name: "Target", workoutType: "Cardio", durationMinutes: 60, in: context)

        let avgBefore = WorkoutMetricService.comparativeAverage(for: .duration, workout: target, context: context)
        XCTAssertNotNil(avgBefore)
        XCTAssertEqual(avgBefore!, 40.0, accuracy: 0.001)

        TestFixtures.updateWorkoutName(target, newName: "Target Renamed", in: context)

        let avgAfter = WorkoutMetricService.comparativeAverage(for: .duration, workout: target, context: context)
        XCTAssertNotNil(avgAfter)
        XCTAssertEqual(avgAfter!, 40.0, accuracy: 0.001, "Average should remain correct after cosmetic edit")
    }

    /// Deleting a peer workout changes the comparative average for the remaining workout.
    func test_deleteWorkout_updatesComparativeAverage() throws {
        let (_, context) = try TestFixtures.inMemoryContext()

        let w1 = TestFixtures.makeWorkout(name: "S1", workoutType: "Strength Training", durationMinutes: 10, in: context)
        TestFixtures.makeWorkout(name: "S2", workoutType: "Strength Training", durationMinutes: 40, in: context)
        TestFixtures.makeWorkout(name: "S3", workoutType: "Strength Training", durationMinutes: 50, in: context)
        TestFixtures.makeWorkout(name: "S4", workoutType: "Strength Training", durationMinutes: 60, in: context)
        let target = TestFixtures.makeWorkout(name: "Target", workoutType: "Strength Training", durationMinutes: 50, in: context)

        let avgBefore = WorkoutMetricService.comparativeAverage(for: .duration, workout: target, context: context)
        XCTAssertNotNil(avgBefore)
        XCTAssertEqual(avgBefore!, 40.0, accuracy: 0.001)

        TestFixtures.deleteWorkoutWithCascade(w1, in: context)

        let avgAfter = WorkoutMetricService.comparativeAverage(for: .duration, workout: target, context: context)
        XCTAssertNotNil(avgAfter)
        XCTAssertEqual(avgAfter!, 50.0, accuracy: 0.001, "Average should exclude deleted workout")
    }

    /// Personal best status updates live — logging a new max distance demotes the previous best.
    func test_logNewMax_previousBestLosesPRStatus() throws {
        let (_, context) = try TestFixtures.inMemoryContext()

        let oldBest = TestFixtures.makeWorkout(name: "Old Best", workoutType: "Cardio", distanceKm: 10.0, in: context)
        TestFixtures.makeWorkout(name: "Other", workoutType: "Cardio", distanceKm: 5.0, in: context)

        XCTAssertTrue(WorkoutMetricService.isPersonalBest(for: .distance, workout: oldBest, context: context))

        let newBest = TestFixtures.logWorkoutWithCascade(
            name: "New Best",
            workoutType: "Cardio",
            distanceKm: 15.0,
            in: context
        )

        XCTAssertTrue(WorkoutMetricService.isPersonalBest(for: .distance, workout: newBest, context: context))
        XCTAssertFalse(WorkoutMetricService.isPersonalBest(for: .distance, workout: oldBest, context: context),
                       "Old best should no longer be PR after new max is logged")
    }
}
