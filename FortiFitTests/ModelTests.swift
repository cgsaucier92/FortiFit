import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// Helper to create an in-memory SwiftData context for testing.
private func makeTestContext() throws -> ModelContext {
    let schema = Schema([Workout.self, ExerciseSet.self, Goal.self, GoalSnapshot.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

// MARK: - Workout Model Tests

struct WorkoutModelTests {

    @Test func createAndRetrieveWorkout() throws {
        let context = try makeTestContext()
        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        context.insert(workout)
        try context.save()

        let descriptor = FetchDescriptor<Workout>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.id == workout.id)
        #expect(results.first?.name == "Push Day")
    }

    @Test func updateWorkoutNote() throws {
        let context = try makeTestContext()
        let workout = Workout(name: "Leg Day", workoutType: "Strength Training")
        context.insert(workout)
        try context.save()

        workout.note = "Great session"
        try context.save()

        let descriptor = FetchDescriptor<Workout>()
        let results = try context.fetch(descriptor)
        #expect(results.first?.note == "Great session")
    }

    @Test func deleteWorkout() throws {
        let context = try makeTestContext()
        let workout = Workout(name: "Pull Day", workoutType: "Strength Training")
        context.insert(workout)
        try context.save()

        context.delete(workout)
        try context.save()

        let descriptor = FetchDescriptor<Workout>()
        let results = try context.fetch(descriptor)
        #expect(results.isEmpty)
    }
}

// MARK: - ExerciseSet Model Tests

struct ExerciseSetModelTests {

    @Test func createExerciseSetWithinWorkout() throws {
        let context = try makeTestContext()
        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let exerciseSet = ExerciseSet(exerciseName: "Bench Press", sets: 4, reps: 8, weightKg: 80, sortOrder: 0)
        workout.exerciseSets.append(exerciseSet)
        context.insert(workout)
        try context.save()

        let descriptor = FetchDescriptor<ExerciseSet>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.exerciseName == "Bench Press")
        #expect(results.first?.workout?.id == workout.id)
    }

    @Test func fetchWorkoutReturnsExerciseSets() throws {
        let context = try makeTestContext()
        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let set1 = ExerciseSet(exerciseName: "Bench Press", sets: 4, reps: 8, weightKg: 80, sortOrder: 0)
        let set2 = ExerciseSet(exerciseName: "Incline Bench Press", sets: 3, reps: 10, weightKg: 60, sortOrder: 1)
        workout.exerciseSets.append(set1)
        workout.exerciseSets.append(set2)
        context.insert(workout)
        try context.save()

        let descriptor = FetchDescriptor<Workout>()
        let fetched = try context.fetch(descriptor).first!
        #expect(fetched.exerciseSets.count == 2)
    }

    @Test func deletingWorkoutCascadesExerciseSets() throws {
        let context = try makeTestContext()
        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let set1 = ExerciseSet(exerciseName: "Bench Press", sets: 4, reps: 8, weightKg: 80, sortOrder: 0)
        workout.exerciseSets.append(set1)
        context.insert(workout)
        try context.save()

        context.delete(workout)
        try context.save()

        let setDescriptor = FetchDescriptor<ExerciseSet>()
        let remainingSets = try context.fetch(setDescriptor)
        #expect(remainingSets.isEmpty)
    }

    @Test func deleteIndividualExerciseSetKeepsWorkout() throws {
        let context = try makeTestContext()
        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let set1 = ExerciseSet(exerciseName: "Bench Press", sets: 4, reps: 8, weightKg: 80, sortOrder: 0)
        let set2 = ExerciseSet(exerciseName: "Flyes", sets: 3, reps: 12, weightKg: 20, sortOrder: 1)
        workout.exerciseSets.append(set1)
        workout.exerciseSets.append(set2)
        context.insert(workout)
        try context.save()

        context.delete(set1)
        try context.save()

        let workoutDescriptor = FetchDescriptor<Workout>()
        let workouts = try context.fetch(workoutDescriptor)
        #expect(workouts.count == 1)

        let setDescriptor = FetchDescriptor<ExerciseSet>()
        let sets = try context.fetch(setDescriptor)
        #expect(sets.count == 1)
        #expect(sets.first?.exerciseName == "Flyes")
    }
}

// MARK: - Goal Model Tests

struct GoalModelTests {

    @Test func createAndRetrieveGoal() throws {
        let context = try makeTestContext()
        let goal = Goal(title: "Bench Press", targetValueKg: 100)
        context.insert(goal)
        try context.save()

        let descriptor = FetchDescriptor<Goal>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.id == goal.id)
        #expect(results.first?.title == "Bench Press")
    }

    @Test func updateGoal() throws {
        let context = try makeTestContext()
        let goal = Goal(title: "Bench Press", targetValueKg: 100)
        context.insert(goal)
        try context.save()

        goal.currentValueKg = 90
        try context.save()

        let descriptor = FetchDescriptor<Goal>()
        let results = try context.fetch(descriptor)
        #expect(results.first?.currentValueKg == 90)
    }

    @Test func deleteGoal() throws {
        let context = try makeTestContext()
        let goal = Goal(title: "Bench Press", targetValueKg: 100)
        context.insert(goal)
        try context.save()

        context.delete(goal)
        try context.save()

        let descriptor = FetchDescriptor<Goal>()
        let results = try context.fetch(descriptor)
        #expect(results.isEmpty)
    }

    @Test func exercisePRGoalStoresCorrectFields() throws {
        let context = try makeTestContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 75, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Goal>()).first!
        #expect(fetched.goalType == "Strength PR")
        #expect(fetched.targetValueKg == 100)
        #expect(fetched.currentValueKg == 75)
        #expect(fetched.targetDistanceKm == nil)
        #expect(fetched.targetDurationMinutes == nil)
        #expect(fetched.targetReps == 0)
    }

    @Test func repetitionsPRGoalStoresCorrectFields() throws {
        let context = try makeTestContext()
        let goal = Goal(title: "Pull-ups", goalType: "Repetitions PR", targetReps: 20, currentReps: 12, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Goal>()).first!
        #expect(fetched.goalType == "Repetitions PR")
        #expect(fetched.targetReps == 20)
        #expect(fetched.currentReps == 12)
        #expect(fetched.targetDistanceKm == nil)
        #expect(fetched.targetDurationMinutes == nil)
        #expect(fetched.targetValueKg == 0)
    }

    @Test func speedDistanceGoalBothTargetsStoresCorrectFields() throws {
        let context = try makeTestContext()
        let goal = Goal(title: "5K Run", goalType: "Speed and Distance",
                        targetDistanceKm: 5, targetDurationMinutes: 30, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Goal>()).first!
        #expect(fetched.goalType == "Speed and Distance")
        #expect(fetched.targetDistanceKm == 5)
        #expect(fetched.targetDurationMinutes == 30)
        #expect(fetched.targetValueKg == 0)
        #expect(fetched.targetReps == 0)
    }

    @Test func speedDistanceGoalDistanceOnlyStoresCorrectFields() throws {
        let context = try makeTestContext()
        let goal = Goal(title: "10K Run", goalType: "Speed and Distance", targetDistanceKm: 10, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Goal>()).first!
        #expect(fetched.goalType == "Speed and Distance")
        #expect(fetched.targetDistanceKm == 10)
        #expect(fetched.targetDurationMinutes == nil)
    }

    @Test func speedDistanceGoalDurationOnlyStoresCorrectFields() throws {
        let context = try makeTestContext()
        let goal = Goal(title: "Endurance Run", goalType: "Speed and Distance", targetDurationMinutes: 60, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Goal>()).first!
        #expect(fetched.goalType == "Speed and Distance")
        #expect(fetched.targetDurationMinutes == 60)
        #expect(fetched.targetDistanceKm == nil)
    }

    @Test func reorderGoals() throws {
        let context = try makeTestContext()
        let g1 = Goal(title: "Bench", targetValueKg: 100, sortOrder: 0)
        let g2 = Goal(title: "Squat", targetValueKg: 130, sortOrder: 1)
        let g3 = Goal(title: "Deadlift", targetValueKg: 180, sortOrder: 2)
        context.insert(g1)
        context.insert(g2)
        context.insert(g3)
        try context.save()

        // Reorder: Deadlift first, Bench second, Squat third
        g3.sortOrder = 0
        g1.sortOrder = 1
        g2.sortOrder = 2
        try context.save()

        let descriptor = FetchDescriptor<Goal>(
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )
        let results = try context.fetch(descriptor)
        #expect(results[0].title == "Deadlift")
        #expect(results[1].title == "Bench")
        #expect(results[2].title == "Squat")
    }
}

// MARK: - Goal Header Label Tests

struct GoalHeaderLabelTests {

    @Test func test_headerLabel_exercisePR_returnsStrengthGoal() {
        let goal = Goal(title: "Bench Press", goalType: "Strength PR")
        #expect(goal.headerLabel == AppConstants.GoalHeaderLabel.strength)
    }

    @Test func test_headerLabel_repsPR_returnsRepsGoal() {
        let goal = Goal(title: "Pull-Ups", goalType: "Repetitions PR")
        #expect(goal.headerLabel == AppConstants.GoalHeaderLabel.reps)
    }

    @Test func test_headerLabel_weeklyWorkouts_returnsFrequencyGoal() {
        let goal = Goal(title: "Weekly Target", goalType: "weeklyWorkouts")
        #expect(goal.headerLabel == AppConstants.GoalHeaderLabel.frequency)
    }

    @Test func test_headerLabel_speedDistanceBothTargets_returnsSpeedGoal() {
        let goal = Goal(
            title: "5K Run",
            goalType: "Speed and Distance",
            targetDistanceKm: 5.0,
            targetDurationMinutes: 25.0
        )
        #expect(goal.headerLabel == AppConstants.GoalHeaderLabel.speed)
    }

    @Test func test_headerLabel_speedDistanceDurationOnly_returnsEnduranceGoal() {
        let goal = Goal(
            title: "30 Min Run",
            goalType: "Speed and Distance",
            targetDistanceKm: nil,
            targetDurationMinutes: 30.0
        )
        #expect(goal.headerLabel == AppConstants.GoalHeaderLabel.endurance)
    }

    @Test func test_headerLabel_speedDistanceDistanceOnly_returnsDistanceGoal() {
        let goal = Goal(
            title: "10K Distance",
            goalType: "Speed and Distance",
            targetDistanceKm: 10.0,
            targetDurationMinutes: nil
        )
        #expect(goal.headerLabel == AppConstants.GoalHeaderLabel.distance)
    }
}
