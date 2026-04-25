import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// GoalAutoUpdateTests — Validates SERVICES.md § Strength PR Goals, § Repetitions PR Goals, § Speed and Distance Goals
/// Tests the "best-ever within scope" semantic in GoalService.recalculateGoals.

private func makeGoalContext() throws -> ModelContext {
    let schema = Schema([Workout.self, ExerciseSet.self, Goal.self, GoalSnapshot.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

@Suite(.serialized)
struct GoalAutoUpdateTests {

    // AUTO-001 — Strength PR: currentValueKg is the max matching weightKg across all in-scope workouts
    @Test func strengthPRMaxWeightAcrossAllWorkouts() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        context.insert(goal)

        let calendar = Calendar.current
        for (i, weight) in [60.0, 80.0, 75.0].enumerated() {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let w = Workout(name: "Day \(i)", date: date, workoutType: "Strength Training")
            let s = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: weight)
            s.workout = w
            w.exerciseSets = [s]
            context.insert(w)
        }
        try context.save()

        GoalService.recalculateGoals(
            affectedExerciseNames: ["Bench Press"],
            affectedWorkoutTypes: ["Strength Training"],
            context: context
        )

        #expect(goal.currentValueKg == 80.0)
    }

    // AUTO-002 — Strength PR: deleting top-weight workout regresses currentValueKg
    @Test func strengthPRDeleteTopWeightWorkoutRegresses() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        context.insert(goal)

        let w1 = Workout(name: "Day 1", workoutType: "Strength Training")
        let s1 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 70)
        s1.workout = w1
        w1.exerciseSets = [s1]
        context.insert(w1)

        let w2 = Workout(name: "Day 2", workoutType: "Strength Training")
        let s2 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 90)
        s2.workout = w2
        w2.exerciseSets = [s2]
        context.insert(w2)
        try context.save()

        GoalService.recalculateGoals(
            affectedExerciseNames: ["Bench Press"],
            affectedWorkoutTypes: ["Strength Training"],
            workout: w2,
            context: context
        )
        #expect(goal.currentValueKg == 90)

        // Delete the top-weight workout
        let deletedDate = w2.date
        WorkoutService.deleteWorkout(w2, context: context)
        GoalService.recalculateGoals(
            affectedExerciseNames: ["Bench Press"],
            affectedWorkoutTypes: ["Strength Training"],
            context: context
        )
        GoalSnapshotService.recomputeSnapshot(goal: goal, date: deletedDate, context: context)

        #expect(goal.currentValueKg == 70)
    }

    // AUTO-003 — Strength PR: editing a PR workout's weight downward regresses
    @Test func strengthPREditWeightDownwardRegresses() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        context.insert(goal)

        let w1 = Workout(name: "Day 1", workoutType: "Strength Training")
        let s1 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 60)
        s1.workout = w1
        w1.exerciseSets = [s1]
        context.insert(w1)

        let w2 = Workout(name: "Day 2", workoutType: "Strength Training")
        let s2 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 85)
        s2.workout = w2
        w2.exerciseSets = [s2]
        context.insert(w2)
        try context.save()

        GoalService.recalculateGoals(
            affectedExerciseNames: ["Bench Press"],
            affectedWorkoutTypes: ["Strength Training"],
            workout: w2,
            context: context
        )
        #expect(goal.currentValueKg == 85)

        // Edit w2's weight down
        let newSet = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 55)
        WorkoutService.updateWorkout(
            w2, name: "Day 2", date: w2.date, time: nil, rpe: nil,
            durationMinutes: nil, distanceKm: nil, newExerciseSets: [newSet]
        )

        GoalService.recalculateGoals(
            affectedExerciseNames: ["Bench Press"],
            affectedWorkoutTypes: ["Strength Training"],
            context: context
        )

        #expect(goal.currentValueKg == 60)
    }

    // AUTO-004 — Strength PR: exercise name match is case-insensitive
    @Test func strengthPRCaseInsensitiveMatch() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        context.insert(goal)

        let w = Workout(name: "Push Day", workoutType: "Strength Training")
        let s = ExerciseSet(exerciseName: "bench press", sets: 3, reps: 5, weightKg: 77)
        s.workout = w
        w.exerciseSets = [s]
        context.insert(w)
        try context.save()

        GoalService.recalculateGoals(
            affectedExerciseNames: ["bench press"],
            affectedWorkoutTypes: ["Strength Training"],
            workout: w,
            context: context
        )

        #expect(goal.currentValueKg == 77)
    }

    // AUTO-005 — Strength PR: custom-titled goals matching no exerciseName are never auto-updated
    @Test func strengthPRNoMatchingExerciseNotAutoUpdated() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Unicorn Lift", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        context.insert(goal)

        let w = Workout(name: "Push Day", workoutType: "Strength Training")
        let s = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 90)
        s.workout = w
        w.exerciseSets = [s]
        context.insert(w)
        try context.save()

        GoalService.recalculateGoals(
            affectedExerciseNames: ["Bench Press"],
            affectedWorkoutTypes: ["Strength Training"],
            workout: w,
            context: context
        )

        #expect(goal.currentValueKg == 0)
    }

    // AUTO-006 — Strength PR: zero in-scope matching workouts → currentValueKg resets to 0
    @Test func strengthPRZeroInScopeWorkoutsResetsToZero() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 80, sortOrder: 0)
        goal.resetDate = Date() // reset just now, so all existing workouts are out-of-scope
        context.insert(goal)

        let calendar = Calendar.current
        let oldDate = calendar.date(byAdding: .day, value: -5, to: Date())!
        let w = Workout(name: "Old Workout", date: oldDate, workoutType: "Strength Training")
        w.lastModifiedDate = oldDate
        let s = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 80)
        s.workout = w
        w.exerciseSets = [s]
        context.insert(w)
        try context.save()

        GoalService.recalculateGoals(
            affectedExerciseNames: ["Bench Press"],
            affectedWorkoutTypes: ["Strength Training"],
            context: context
        )

        #expect(goal.currentValueKg == 0)
    }

    // AUTO-007 — Reps PR: currentReps = max matching reps across all in-scope workouts
    @Test func repsPRMaxRepsAcrossWorkouts() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Push-ups", goalType: "Repetitions PR", targetReps: 30, sortOrder: 0)
        context.insert(goal)

        let calendar = Calendar.current
        for (i, reps) in [15, 25, 20].enumerated() {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let w = Workout(name: "Day \(i)", date: date, workoutType: "Strength Training")
            let s = ExerciseSet(exerciseName: "Push-ups", sets: 1, reps: reps)
            s.workout = w
            w.exerciseSets = [s]
            context.insert(w)
        }
        try context.save()

        GoalService.recalculateGoals(
            affectedExerciseNames: ["Push-ups"],
            affectedWorkoutTypes: ["Strength Training"],
            context: context
        )

        #expect(goal.currentReps == 25)
    }

    // AUTO-008 — Reps PR: deleting top-reps workout regresses
    @Test func repsPRDeleteTopRepsRegresses() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Push-ups", goalType: "Repetitions PR", targetReps: 30, sortOrder: 0)
        context.insert(goal)

        let w1 = Workout(name: "Day 1", workoutType: "Strength Training")
        let s1 = ExerciseSet(exerciseName: "Push-ups", sets: 1, reps: 18)
        s1.workout = w1
        w1.exerciseSets = [s1]
        context.insert(w1)

        let w2 = Workout(name: "Day 2", workoutType: "Strength Training")
        let s2 = ExerciseSet(exerciseName: "Push-ups", sets: 1, reps: 28)
        s2.workout = w2
        w2.exerciseSets = [s2]
        context.insert(w2)
        try context.save()

        GoalService.recalculateGoals(
            affectedExerciseNames: ["Push-ups"],
            affectedWorkoutTypes: ["Strength Training"],
            workout: w2,
            context: context
        )
        #expect(goal.currentReps == 28)

        WorkoutService.deleteWorkout(w2, context: context)
        GoalService.recalculateGoals(
            affectedExerciseNames: ["Push-ups"],
            affectedWorkoutTypes: ["Strength Training"],
            context: context
        )

        #expect(goal.currentReps == 18)
    }

    // AUTO-009 — Speed and Distance distance-only: currentDistanceKm = highest distanceKm
    @Test func speedDistanceDistanceOnlyMaxDistance() throws {
        let context = try makeGoalContext()
        let goal = Goal(
            title: "10K Run", goalType: "Speed and Distance",
            targetDistanceKm: 10, linkedWorkoutType: "Cardio", sortOrder: 0
        )
        context.insert(goal)

        let calendar = Calendar.current
        for (i, dist) in [5.0, 8.0, 6.5].enumerated() {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let w = Workout(name: "Run \(i)", date: date, workoutType: "Cardio", distanceKm: dist)
            context.insert(w)
        }
        try context.save()

        GoalService.recalculateGoals(
            affectedExerciseNames: [],
            affectedWorkoutTypes: ["Cardio"],
            context: context
        )

        #expect(goal.currentDistanceKm == 8.0)
    }

    // AUTO-010 — Speed and Distance duration-only (endurance): currentDurationMinutes = highest durationMinutes
    @Test func speedDistanceDurationOnlyMaxDuration() throws {
        let context = try makeGoalContext()
        let goal = Goal(
            title: "Long Run", goalType: "Speed and Distance",
            targetDurationMinutes: 60, linkedWorkoutType: "Cardio", sortOrder: 0
        )
        context.insert(goal)

        let calendar = Calendar.current
        for (i, dur) in [30, 50, 45].enumerated() {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let w = Workout(name: "Run \(i)", date: date, workoutType: "Cardio", durationMinutes: dur)
            context.insert(w)
        }
        try context.save()

        GoalService.recalculateGoals(
            affectedExerciseNames: [],
            affectedWorkoutTypes: ["Cardio"],
            context: context
        )

        #expect(goal.currentDurationMinutes == 50)
    }

    // AUTO-011 — Speed target: values copied from SINGLE best overallProgress% workout (no compositing)
    @Test func speedTargetCopiesFromSingleBestWorkout() throws {
        let context = try makeGoalContext()
        let goal = Goal(
            title: "5K Run", goalType: "Speed and Distance",
            targetDistanceKm: 5, targetDurationMinutes: 30,
            linkedWorkoutType: "Cardio", sortOrder: 0
        )
        context.insert(goal)

        // Workout A: 4km in 25min → dist=80%, dur=100% (25≤30), overall=80%
        let w1 = Workout(name: "Run A", workoutType: "Cardio", durationMinutes: 25, distanceKm: 4.0)
        context.insert(w1)

        // Workout B: 5km in 45min → dist=100%, dur=30/45=66.7%, overall=66.7%
        let w2 = Workout(name: "Run B", workoutType: "Cardio", durationMinutes: 45, distanceKm: 5.0)
        context.insert(w2)
        try context.save()

        GoalService.recalculateGoals(
            affectedExerciseNames: [],
            affectedWorkoutTypes: ["Cardio"],
            workout: w2,
            context: context
        )

        // Best is Run A (80% overall), so values copied from Run A
        #expect(goal.currentDistanceKm == 4.0)
        #expect(goal.currentDurationMinutes == 25)
    }

    // AUTO-012 — Speed target tie-breaker: when two workouts have equal overallProgress%, most recent wins
    @Test func speedTargetTieBreakerMostRecentWins() throws {
        let context = try makeGoalContext()
        let goal = Goal(
            title: "5K Run", goalType: "Speed and Distance",
            targetDistanceKm: 5, targetDurationMinutes: 30,
            linkedWorkoutType: "Cardio", sortOrder: 0
        )
        context.insert(goal)

        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!

        // Both workouts: 4km in 25min → same overallProgress=80%
        let w1 = Workout(name: "Run Yesterday", date: yesterday, workoutType: "Cardio", durationMinutes: 25, distanceKm: 4.0)
        context.insert(w1)

        let w2 = Workout(name: "Run Today", workoutType: "Cardio", durationMinutes: 25, distanceKm: 4.0)
        context.insert(w2)
        try context.save()

        GoalService.recalculateGoals(
            affectedExerciseNames: [],
            affectedWorkoutTypes: ["Cardio"],
            workout: w2,
            context: context
        )

        // Both have equal progress; most recent date wins
        #expect(goal.currentDistanceKm == 4.0)
        #expect(goal.currentDurationMinutes == 25)
    }

    // AUTO-013 — Speed target: deleting the "best" workout causes regression to next-best
    @Test func speedTargetDeleteBestWorkoutRegresses() throws {
        let context = try makeGoalContext()
        let goal = Goal(
            title: "5K Run", goalType: "Speed and Distance",
            targetDistanceKm: 5, targetDurationMinutes: 30,
            linkedWorkoutType: "Cardio", sortOrder: 0
        )
        context.insert(goal)

        // Workout A: 4km in 25min → 80% overall (best)
        let w1 = Workout(name: "Run A", workoutType: "Cardio", durationMinutes: 25, distanceKm: 4.0)
        context.insert(w1)

        // Workout B: 3km in 20min → 60% overall (second best)
        let w2 = Workout(name: "Run B", workoutType: "Cardio", durationMinutes: 20, distanceKm: 3.0)
        context.insert(w2)
        try context.save()

        GoalService.recalculateGoals(
            affectedExerciseNames: [],
            affectedWorkoutTypes: ["Cardio"],
            workout: w1,
            context: context
        )
        #expect(goal.currentDistanceKm == 4.0)

        // Delete the best workout
        let deletedDate = w1.date
        WorkoutService.deleteWorkout(w1, context: context)
        GoalService.recalculateGoals(
            affectedExerciseNames: [],
            affectedWorkoutTypes: ["Cardio"],
            context: context
        )
        GoalSnapshotService.recomputeSnapshot(goal: goal, date: deletedDate, context: context)

        // Should regress to Run B's values
        #expect(goal.currentDistanceKm == 3.0)
        #expect(goal.currentDurationMinutes == 20)
    }
}
