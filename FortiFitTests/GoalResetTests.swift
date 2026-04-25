import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// Section 4: GoalService Tests — Reset Goal Progress

private func makeGoalContext() throws -> ModelContext {
    let schema = Schema([Workout.self, ExerciseSet.self, Goal.self, GoalSnapshot.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

@Suite(.serialized)
struct GoalResetTests {

    // RESET-001
    @Test func resetExercisePRSetsCurrentValueToZero() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 85, sortOrder: 0)
        context.insert(goal)
        try context.save()

        GoalService.resetGoalProgress(goal: goal, context: context)

        #expect(goal.currentValueKg == 0)
    }

    // RESET-002
    @Test func resetRepsPRSetsCurrentRepsToZero() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Repetitions PR", targetReps: 15, currentReps: 12, sortOrder: 0)
        context.insert(goal)
        try context.save()

        GoalService.resetGoalProgress(goal: goal, context: context)

        #expect(goal.currentReps == 0)
    }

    // RESET-003
    @Test func resetSpeedDistanceZeroesBothValues() throws {
        let context = try makeGoalContext()
        let goal = Goal(
            title: "5K Run",
            goalType: "Speed and Distance",
            targetDistanceKm: 10,
            currentDistanceKm: 7,
            targetDurationMinutes: 60,
            currentDurationMinutes: 45,
            sortOrder: 0
        )
        context.insert(goal)
        try context.save()

        GoalService.resetGoalProgress(goal: goal, context: context)

        #expect(goal.currentDistanceKm == 0)
        #expect(goal.currentDurationMinutes == 0)
    }

    // RESET-004
    @Test func resetClearsLastCelebratedDate() throws {
        let context = try makeGoalContext()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 85, lastCelebratedDate: yesterday, sortOrder: 0)
        context.insert(goal)
        try context.save()

        GoalService.resetGoalProgress(goal: goal, context: context)

        #expect(goal.lastCelebratedDate == nil)
    }

    // RESET-005
    @Test func resetDeletesAllSnapshotsAndSetsResetDate() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 85, sortOrder: 0)
        context.insert(goal)
        try context.save()

        // Add existing snapshots
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        context.insert(GoalSnapshot(goalId: goal.id, date: today, value: 85.0))
        context.insert(GoalSnapshot(goalId: goal.id, date: calendar.date(byAdding: .day, value: -1, to: today)!, value: 70.0))
        try context.save()

        GoalService.resetGoalProgress(goal: goal, context: context)

        let snapshots = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapshots.isEmpty) // All snapshots wiped
        #expect(goal.resetDate != nil) // resetDate is set
    }

    // RESET-006
    @Test func resetAllowsReCelebrationOnNextCompletion() throws {
        let context = try makeGoalContext()
        let today = Calendar.current.startOfDay(for: Date())
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 105, lastCelebratedDate: today, sortOrder: 0)
        context.insert(goal)
        try context.save()

        // Reset the goal
        GoalService.resetGoalProgress(goal: goal, context: context)
        #expect(goal.currentValueKg == 0)
        #expect(goal.lastCelebratedDate == nil)
        #expect(goal.resetDate != nil)

        // Log a new workout that crosses 100% — lastModifiedDate ensures it's in scope
        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        workout.lastModifiedDate = .now
        let set = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 102)
        set.workout = workout
        workout.exerciseSets = [set]
        context.insert(workout)
        try context.save()

        GoalService.recalculateGoals(
            affectedExerciseNames: ["Bench Press"],
            affectedWorkoutTypes: ["Strength Training"],
            workout: workout,
            context: context
        )

        // Re-celebration allowed because reset cleared lastCelebratedDate to nil
        #expect(goal.lastCelebratedDate != nil)
        #expect(Calendar.current.isDateInToday(goal.lastCelebratedDate!))
    }
}
