import Testing
import Foundation
import SwiftData
@testable import FortiFit

private func makeTestContext() throws -> ModelContext {
    let schema = Schema([
        Workout.self, ExerciseSet.self, Goal.self,
        WorkoutTypeOrder.self, HomeWidget.self,
        WorkoutTemplate.self, TemplateExerciseSet.self,
        TrendsChart.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

private let strengthExerciseKey = "trendsSelectedExercise"
private let prExerciseKey = "trendsSelectedPRExercise"

@Suite(.serialized)
struct ProgressViewModelSelectionTests {

    init() {
        UserDefaults.standard.removeObject(forKey: strengthExerciseKey)
        UserDefaults.standard.removeObject(forKey: prExerciseKey)
    }

    // MARK: - Strength Tracker

    @Test func selectExercise_persistsToUserDefaults() {
        let vm = ProgressViewModel()
        vm.availableExercises = ["Bench Press", "Squat"]
        vm.selectExercise("Squat")

        #expect(UserDefaults.standard.string(forKey: strengthExerciseKey) == "Squat")
    }

    @Test func loadData_restoresSavedExercise() throws {
        let context = try makeTestContext()

        let workout = Workout(
            name: "Test",
            date: Date().addingTimeInterval(-86400),
            workoutType: "Strength Training"
        )
        context.insert(workout)
        let set1 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 10, weightKg: 60, workout: workout)
        let set2 = ExerciseSet(exerciseName: "Squat", sets: 3, reps: 8, weightKg: 100, workout: workout)
        context.insert(set1)
        context.insert(set2)
        try context.save()

        UserDefaults.standard.set("Squat", forKey: strengthExerciseKey)

        let vm = ProgressViewModel()
        vm.loadData(context: context)

        #expect(vm.selectedExercise == "Squat")
    }

    @Test func loadData_fallsBackToFirst_whenSavedExerciseNoLongerExists() throws {
        let context = try makeTestContext()

        let workout = Workout(
            name: "Test",
            date: Date().addingTimeInterval(-86400),
            workoutType: "Strength Training"
        )
        context.insert(workout)
        let set1 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 10, weightKg: 60, workout: workout)
        context.insert(set1)
        try context.save()

        UserDefaults.standard.set("Deadlift", forKey: strengthExerciseKey)

        let vm = ProgressViewModel()
        vm.loadData(context: context)

        #expect(vm.selectedExercise == "Bench Press")
    }

    // MARK: - Personal Records

    @Test func selectPRExercise_persistsToUserDefaults() {
        let vm = ProgressViewModel()
        vm.selectPRExercise("Overhead Press")

        #expect(UserDefaults.standard.string(forKey: prExerciseKey) == "Overhead Press")
    }

    @Test func loadData_restoresSavedPRExercise() throws {
        let context = try makeTestContext()

        let w1 = Workout(name: "W1", date: Date().addingTimeInterval(-86400 * 2), workoutType: "Strength Training")
        context.insert(w1)
        context.insert(ExerciseSet(exerciseName: "Squat", sets: 3, reps: 5, weightKg: 80, workout: w1))
        context.insert(ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 50, workout: w1))

        let w2 = Workout(name: "W2", date: Date().addingTimeInterval(-86400), workoutType: "Strength Training")
        context.insert(w2)
        context.insert(ExerciseSet(exerciseName: "Squat", sets: 3, reps: 5, weightKg: 100, workout: w2))
        context.insert(ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 60, workout: w2))
        try context.save()

        UserDefaults.standard.set("Squat", forKey: prExerciseKey)

        let vm = ProgressViewModel()
        vm.loadData(context: context)

        #expect(vm.selectedPRExercise == "Squat")
    }

    @Test func loadData_fallsBackToFirst_whenSavedPRExerciseNoLongerExists() throws {
        let context = try makeTestContext()

        let w1 = Workout(name: "W1", date: Date().addingTimeInterval(-86400 * 2), workoutType: "Strength Training")
        context.insert(w1)
        context.insert(ExerciseSet(exerciseName: "Squat", sets: 3, reps: 5, weightKg: 80, workout: w1))

        let w2 = Workout(name: "W2", date: Date().addingTimeInterval(-86400), workoutType: "Strength Training")
        context.insert(w2)
        context.insert(ExerciseSet(exerciseName: "Squat", sets: 3, reps: 5, weightKg: 100, workout: w2))
        try context.save()

        UserDefaults.standard.set("Deadlift", forKey: prExerciseKey)

        let vm = ProgressViewModel()
        vm.loadData(context: context)

        #expect(vm.selectedPRExercise == "Squat")
    }
}
