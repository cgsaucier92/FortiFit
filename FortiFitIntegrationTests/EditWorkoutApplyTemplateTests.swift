import XCTest
import SwiftData
@testable import FortiFit

final class EditWorkoutApplyTemplateTests: XCTestCase {

    // MARK: - Apply to manual workout (name + duration + exercises)

    func test_applyTemplateToManualWorkout_fillsNameAndDuration_appendsExercises() throws {
        let (_, context) = try TestFixtures.inMemoryContext()

        let workout = TestFixtures.makeWorkout(
            name: "",
            workoutType: "Strength Training",
            in: context
        )

        let template = TestFixtures.makeTemplate(
            name: "Push Day",
            workoutType: "Strength Training",
            durationMinutes: 60,
            exercises: [
                .init("Bench Press", sets: 4, reps: 8, weightKg: 80),
                .init("OHP", sets: 3, reps: 10, weightKg: 50),
            ],
            in: context
        )

        WorkoutTemplateService.applyToExistingWorkout(template: template, workout: workout)
        try context.save()

        XCTAssertEqual(workout.name, "Push Day")
        XCTAssertEqual(workout.durationMinutes, 60)
        XCTAssertEqual(workout.exerciseSets.count, 2)

        let sorted = workout.exerciseSets.sorted { $0.sortOrder < $1.sortOrder }
        XCTAssertEqual(sorted[0].exerciseName, "Bench Press")
        XCTAssertEqual(sorted[1].exerciseName, "OHP")
    }

    // MARK: - Apply to HK-linked workout (duration unchanged, HK fields untouched)

    func test_applyTemplateToHKLinkedWorkout_durationUnchanged_hkFieldsUntouched() throws {
        let (_, context) = try TestFixtures.inMemoryContext()

        let hkUUID = UUID()
        let workout = TestFixtures.makeLinkedWorkout(
            name: "",
            workoutType: "Strength Training",
            healthKitUUID: hkUUID,
            durationMinutes: 45,
            in: context
        )

        let template = TestFixtures.makeTemplate(
            name: "Push Day",
            workoutType: "Strength Training",
            durationMinutes: 90,
            exercises: [
                .init("Bench Press", sets: 3, reps: 8, weightKg: 80),
            ],
            in: context
        )

        WorkoutTemplateService.applyToExistingWorkout(template: template, workout: workout)
        try context.save()

        XCTAssertEqual(workout.name, "Push Day")
        XCTAssertEqual(workout.durationMinutes, 45, "Duration must not change on HK-linked workout")
        XCTAssertEqual(workout.healthKitUUID, hkUUID)
        XCTAssertEqual(workout.healthKitSourceBundleID, "com.apple.health.workout-builder")
        XCTAssertEqual(workout.exerciseSets.count, 1)
        XCTAssertEqual(workout.exerciseSets.first?.exerciseName, "Bench Press")
    }

    // MARK: - sortOrder continuation with existing exercises

    func test_applyTemplateToWorkoutWithExistingExercises_sortOrderContinuation() throws {
        let (_, context) = try TestFixtures.inMemoryContext()

        let workout = TestFixtures.makeWorkout(
            name: "Existing Workout",
            workoutType: "Strength Training",
            exercises: [
                .init("Bench Press", sets: 3, reps: 8, weightKg: 80),
                .init("Flyes", sets: 3, reps: 12, weightKg: 20),
            ],
            in: context
        )

        let template = TestFixtures.makeTemplate(
            name: "More Exercises",
            workoutType: "Strength Training",
            exercises: [
                .init("OHP", sets: 4, reps: 6, weightKg: 50),
                .init("Lat Raise", sets: 3, reps: 15, weightKg: 10),
            ],
            in: context
        )

        WorkoutTemplateService.applyToExistingWorkout(template: template, workout: workout)

        XCTAssertEqual(workout.exerciseSets.count, 4)
        let sorted = workout.exerciseSets.sorted { $0.sortOrder < $1.sortOrder }
        XCTAssertEqual(sorted[0].sortOrder, 0)
        XCTAssertEqual(sorted[0].exerciseName, "Bench Press")
        XCTAssertEqual(sorted[1].sortOrder, 1)
        XCTAssertEqual(sorted[1].exerciseName, "Flyes")
        XCTAssertEqual(sorted[2].sortOrder, 2)
        XCTAssertEqual(sorted[2].exerciseName, "OHP")
        XCTAssertEqual(sorted[3].sortOrder, 3)
        XCTAssertEqual(sorted[3].exerciseName, "Lat Raise")
    }
}
