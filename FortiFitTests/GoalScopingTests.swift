import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// GoalScopingTests — Validates SERVICES.md § Goal Auto-Update → Reset Scoping
/// Tests GoalService auto-update and GoalSnapshotService scope filtering against each goal's resetDate.

private func makeGoalContext() throws -> ModelContext {
    let schema = Schema([Workout.self, ExerciseSet.self, Goal.self, GoalSnapshot.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

@Suite(.serialized)
struct GoalScopingTests {

    // SCOPE-001 — Nil resetDate: all workouts are in-scope
    @Test func nilResetDateAllWorkoutsInScope() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        // goal.resetDate is nil by default
        context.insert(goal)

        let calendar = Calendar.current
        // Create workouts across a wide date range
        let oldDate = calendar.date(byAdding: .month, value: -6, to: Date())!
        let w1 = Workout(name: "Old Workout", date: oldDate, workoutType: "Strength Training")
        let s1 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 80)
        s1.workout = w1
        w1.exerciseSets = [s1]
        context.insert(w1)

        let w2 = Workout(name: "Recent Workout", workoutType: "Strength Training")
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

        // currentValueKg reflects the max weight across full history (90)
        #expect(goal.currentValueKg == 90)
    }

    // SCOPE-002 — workout.date > resetDate: in-scope
    @Test func workoutDateAfterResetDateIsInScope() throws {
        let context = try makeGoalContext()
        let calendar = Calendar.current
        let resetDate = calendar.date(byAdding: .day, value: -3, to: Date())!

        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        goal.resetDate = resetDate
        context.insert(goal)

        // Workout dated after resetDate
        let postResetDate = calendar.date(byAdding: .day, value: -1, to: Date())!
        let w = Workout(name: "Post Reset", date: postResetDate, workoutType: "Strength Training")
        let s = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 75)
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

        #expect(goal.currentValueKg == 75)
    }

    // SCOPE-003 — workout.date ≤ resetDate AND workout.lastModifiedDate ≤ resetDate: out-of-scope
    @Test func workoutBeforeResetDateAndNotModifiedIsOutOfScope() throws {
        let context = try makeGoalContext()
        let calendar = Calendar.current
        let now = Date()
        let resetDate = calendar.date(byAdding: .day, value: -1, to: now)!

        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        goal.resetDate = resetDate
        context.insert(goal)

        // Workout dated before resetDate, lastModifiedDate also before
        let oldDate = calendar.date(byAdding: .day, value: -5, to: now)!
        let w = Workout(name: "Old Workout", date: oldDate, workoutType: "Strength Training")
        w.lastModifiedDate = calendar.date(byAdding: .day, value: -4, to: now)!
        let s = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 95)
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

        // Out-of-scope workout ignored — currentValueKg stays at 0
        #expect(goal.currentValueKg == 0)
    }

    // SCOPE-004 — workout.lastModifiedDate > resetDate re-scopes a pre-reset workout
    @Test func lastModifiedDateAfterResetDateReScopesWorkout() throws {
        let context = try makeGoalContext()
        let calendar = Calendar.current
        let now = Date()
        let resetDate = calendar.date(byAdding: .day, value: -2, to: now)!

        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        goal.resetDate = resetDate
        context.insert(goal)

        // Workout date is before resetDate, but lastModifiedDate is after
        let oldDate = calendar.date(byAdding: .day, value: -5, to: now)!
        let w = Workout(name: "Old Workout", date: oldDate, workoutType: "Strength Training")
        w.lastModifiedDate = now // modified after reset
        let s = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 85)
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

        #expect(goal.currentValueKg == 85)
    }

    // SCOPE-005 — Cosmetic edit bumps lastModifiedDate; previously out-of-scope workout becomes in-scope
    @Test func cosmeticEditBumpsLastModifiedDateAndRescopes() throws {
        let context = try makeGoalContext()
        let calendar = Calendar.current
        let now = Date()
        let resetDate = calendar.date(byAdding: .day, value: -2, to: now)!

        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        goal.resetDate = resetDate
        context.insert(goal)

        // Workout before reset, lastModified also before reset → out of scope
        let oldDate = calendar.date(byAdding: .day, value: -5, to: now)!
        let w = Workout(name: "Old Workout", date: oldDate, workoutType: "Strength Training")
        w.lastModifiedDate = calendar.date(byAdding: .day, value: -4, to: now)!
        let s = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 88)
        s.workout = w
        w.exerciseSets = [s]
        context.insert(w)
        try context.save()

        #expect(!GoalService.isWorkoutInScope(w, for: goal))

        // Simulate cosmetic edit (notes-only) which bumps lastModifiedDate
        WorkoutService.updateNote(w, note: "Good session", context: context)

        // Now lastModifiedDate is after resetDate → in-scope
        #expect(GoalService.isWorkoutInScope(w, for: goal))

        GoalService.recalculateGoals(
            affectedExerciseNames: ["Bench Press"],
            affectedWorkoutTypes: ["Strength Training"],
            context: context
        )

        #expect(goal.currentValueKg == 88)
    }

    // SCOPE-006 — Editing goal definition clears resetDate; pre-reset workouts re-enter scope
    @Test func goalDefinitionEditClearsResetDate() throws {
        let context = try makeGoalContext()
        let calendar = Calendar.current
        let now = Date()
        let resetDate = calendar.date(byAdding: .day, value: -2, to: now)!

        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        goal.resetDate = resetDate
        context.insert(goal)

        // Old workout that's out-of-scope due to resetDate
        let oldDate = calendar.date(byAdding: .day, value: -10, to: now)!
        let w = Workout(name: "Old Heavy Workout", date: oldDate, workoutType: "Strength Training")
        w.lastModifiedDate = oldDate
        let s = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 92)
        s.workout = w
        w.exerciseSets = [s]
        context.insert(w)
        try context.save()

        // Verify out-of-scope initially
        #expect(!GoalService.isWorkoutInScope(w, for: goal))

        // Simulate goal definition edit
        GoalService.handleGoalDefinitionEdit(goal: goal, context: context)

        // resetDate should be cleared
        #expect(goal.resetDate == nil)

        // Now all workouts are in-scope
        #expect(GoalService.isWorkoutInScope(w, for: goal))
        #expect(goal.currentValueKg == 92)
    }

    // SCOPE-007 — On goal definition edit with resetDate cleared, rebuildSnapshots drops and rebuilds
    @Test func goalDefinitionEditRebuildsSnapshots() throws {
        let context = try makeGoalContext()
        let calendar = Calendar.current
        let now = Date()
        let resetDate = calendar.date(byAdding: .day, value: -2, to: now)!

        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        goal.resetDate = resetDate
        context.insert(goal)

        // Create a stale snapshot from before reset
        let staleDate = calendar.date(byAdding: .day, value: -5, to: now)!
        context.insert(GoalSnapshot(goalId: goal.id, date: staleDate, value: 50.0))

        // Add a workout that will become in-scope after resetDate clears
        let oldDate = calendar.date(byAdding: .day, value: -7, to: now)!
        let w = Workout(name: "Old Workout", date: oldDate, workoutType: "Strength Training")
        w.lastModifiedDate = oldDate
        let s = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 70)
        s.workout = w
        w.exerciseSets = [s]
        context.insert(w)
        try context.save()

        GoalService.handleGoalDefinitionEdit(goal: goal, context: context)

        let snapshots = try context.fetch(FetchDescriptor<GoalSnapshot>())
        // Should have been rebuilt — stale snapshot replaced with new one based on workout data
        #expect(snapshots.count >= 1)
        #expect(snapshots.contains { $0.value == 70.0 })
    }

    // SCOPE-008 — Workout edits that change value-affecting fields bump lastModifiedDate and re-scope
    @Test func workoutEditBumpsLastModifiedDateAndReScopes() throws {
        let context = try makeGoalContext()
        let calendar = Calendar.current
        let now = Date()
        let resetDate = calendar.date(byAdding: .day, value: -2, to: now)!

        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        goal.resetDate = resetDate
        context.insert(goal)

        // Workout before reset, not modified
        let oldDate = calendar.date(byAdding: .day, value: -5, to: now)!
        let w = Workout(name: "Old Workout", date: oldDate, workoutType: "Strength Training")
        w.lastModifiedDate = calendar.date(byAdding: .day, value: -4, to: now)!
        let s = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 70)
        s.workout = w
        w.exerciseSets = [s]
        context.insert(w)
        try context.save()

        #expect(!GoalService.isWorkoutInScope(w, for: goal))

        // Edit the workout's weight (value-affecting field)
        let newSet = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 85)
        WorkoutService.updateWorkout(
            w,
            name: "Old Workout",
            date: oldDate,
            time: nil,
            rpe: nil,
            durationMinutes: nil,
            distanceKm: nil,
            newExerciseSets: [newSet]
        )

        // lastModifiedDate should now be after resetDate
        #expect(GoalService.isWorkoutInScope(w, for: goal))
    }

    // SCOPE-009 — Weekly Workouts goals treat resetDate as always nil; scoping has no effect
    @Test func weeklyWorkoutsGoalIgnoresResetDate() throws {
        let context = try makeGoalContext()

        let goal = Goal(title: "Workouts Per Week", goalType: "weeklyWorkouts", sortOrder: 0)
        goal.resetDate = Date() // set a resetDate; should be ignored for weekly workouts
        context.insert(goal)

        // Log 2 workouts this week
        let monday = Date().startOfWeek
        for i in 0..<2 {
            let date = Calendar.current.date(byAdding: .day, value: i, to: monday)!
            let w = Workout(name: "Workout \(i+1)", date: date, workoutType: "Strength Training")
            context.insert(w)
        }
        try context.save()

        // Weekly workouts count is runtime-derived, not affected by resetDate
        let progress = GoalService.weeklyWorkoutsProgress(context: context, target: 3)
        #expect(progress.current >= 2)
    }

    // SCOPE-010 — Subsequent workout edits do NOT clear resetDate; only goal definition edit clears it
    @Test func workoutEditDoesNotClearResetDate() throws {
        let context = try makeGoalContext()
        let calendar = Calendar.current
        let now = Date()
        let resetDate = calendar.date(byAdding: .day, value: -1, to: now)!

        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        goal.resetDate = resetDate
        context.insert(goal)

        let w = Workout(name: "Post Reset", workoutType: "Strength Training")
        let s = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 80)
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

        // resetDate should still be set after workout-triggered recalculation
        #expect(goal.resetDate != nil)
    }
}
