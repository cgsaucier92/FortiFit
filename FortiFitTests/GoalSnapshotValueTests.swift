import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// Section 9: GoalSnapshotService Tests — Per-Workout Snapshot Value Computation

private func makeGoalContext() throws -> ModelContext {
    let schema = Schema([Workout.self, ExerciseSet.self, Goal.self, GoalSnapshot.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

@Suite(.serialized)
struct GoalSnapshotValueTests {

    // SNAPVAL-001
    @Test func exercisePRSnapshotValueIsMaxWeightOnDay() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        context.insert(goal)

        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let set = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 82.5)
        set.workout = workout
        workout.exerciseSets = [set]
        context.insert(workout)
        try context.save()

        GoalSnapshotService.recomputeSnapshot(goal: goal, date: workout.date, context: context)

        let snapshots = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapshots.first?.value == 82.5)
    }

    // SNAPVAL-002
    @Test func repsPRSnapshotValueIsMaxRepsAsDouble() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Repetitions PR", targetReps: 15, sortOrder: 0)
        context.insert(goal)

        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let set = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 12)
        set.workout = workout
        workout.exerciseSets = [set]
        context.insert(workout)
        try context.save()

        GoalSnapshotService.recomputeSnapshot(goal: goal, date: workout.date, context: context)

        let snapshots = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapshots.first?.value == 12.0)
    }

    // SNAPVAL-003
    @Test func speedDistanceBothTargetsSnapshotIsOverallProgress() throws {
        let context = try makeGoalContext()
        let goal = Goal(
            title: "5K Run",
            goalType: "Speed and Distance",
            targetDistanceKm: 10,
            targetDurationMinutes: 60,
            linkedWorkoutType: "Cardio",
            sortOrder: 0
        )
        context.insert(goal)

        // 8km in 54min: distPct=80%, durPct=100% (54<=60), overall=80%
        let workout = Workout(name: "Run", workoutType: "Cardio", durationMinutes: 54, distanceKm: 8.0)
        context.insert(workout)
        try context.save()

        GoalSnapshotService.recomputeSnapshot(goal: goal, date: workout.date, context: context)

        let snapshots = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapshots.first?.value == 80.0)
    }

    // SNAPVAL-004
    @Test func speedDistanceDistanceOnlySnapshotIsDistancePercentage() throws {
        let context = try makeGoalContext()
        let goal = Goal(
            title: "10K Run",
            goalType: "Speed and Distance",
            targetDistanceKm: 10,
            linkedWorkoutType: "Cardio",
            sortOrder: 0
        )
        context.insert(goal)

        let workout = Workout(name: "Run", workoutType: "Cardio", distanceKm: 7.0)
        context.insert(workout)
        try context.save()

        GoalSnapshotService.recomputeSnapshot(goal: goal, date: workout.date, context: context)

        let snapshots = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapshots.first?.value == 70.0)
    }

    // SNAPVAL-005
    @Test func speedDistanceDurationOnlySnapshotIsDurationPercentage() throws {
        let context = try makeGoalContext()
        let goal = Goal(
            title: "Long Run",
            goalType: "Speed and Distance",
            targetDurationMinutes: 60,
            linkedWorkoutType: "Cardio",
            sortOrder: 0
        )
        context.insert(goal)

        let workout = Workout(name: "Run", workoutType: "Cardio", durationMinutes: 45)
        context.insert(workout)
        try context.save()

        GoalSnapshotService.recomputeSnapshot(goal: goal, date: workout.date, context: context)

        let snapshots = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapshots.first?.value == 75.0)
    }

    // SNAPVAL-006
    @Test func weeklyWorkoutsSnapshotValueIsCurrentWorkoutCount() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Workouts Per Week", goalType: "weeklyWorkouts", sortOrder: 0)
        context.insert(goal)

        // Log 5 workouts this week
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!

        for i in 0..<5 {
            let dayOffset = min(i, 6) // stay within the week
            let date = calendar.date(byAdding: .day, value: dayOffset, to: monday)!
            let w = Workout(name: "Workout \(i+1)", date: date, workoutType: "Strength Training")
            context.insert(w)
        }
        try context.save()

        GoalSnapshotService.recomputeSnapshot(goal: goal, date: today, context: context)

        let snapshots = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapshots.first?.value == 5.0)
    }

    // SNAPVAL-007 — Strength PR: two matching workouts same date → snapshot value = higher weight
    @Test func strengthPRTwoWorkoutsSameDateHigherWeightWins() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        context.insert(goal)

        let w1 = Workout(name: "Morning Push", workoutType: "Strength Training")
        let s1 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 60)
        s1.workout = w1
        w1.exerciseSets = [s1]
        context.insert(w1)

        let w2 = Workout(name: "Evening Push", workoutType: "Strength Training")
        let s2 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 75)
        s2.workout = w2
        w2.exerciseSets = [s2]
        context.insert(w2)
        try context.save()

        GoalSnapshotService.recomputeSnapshot(goal: goal, date: Date(), context: context)

        let snapshots = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapshots.count == 1)
        #expect(snapshots.first?.value == 75.0)
    }

    // SNAPVAL-008 — Reps PR: two matching workouts same date → snapshot value = higher rep count
    @Test func repsPRTwoWorkoutsSameDateHigherRepsWins() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Push-ups", goalType: "Repetitions PR", targetReps: 30, sortOrder: 0)
        context.insert(goal)

        let w1 = Workout(name: "Morning", workoutType: "Strength Training")
        let s1 = ExerciseSet(exerciseName: "Push-ups", sets: 1, reps: 15)
        s1.workout = w1
        w1.exerciseSets = [s1]
        context.insert(w1)

        let w2 = Workout(name: "Evening", workoutType: "Strength Training")
        let s2 = ExerciseSet(exerciseName: "Push-ups", sets: 1, reps: 22)
        s2.workout = w2
        w2.exerciseSets = [s2]
        context.insert(w2)
        try context.save()

        GoalSnapshotService.recomputeSnapshot(goal: goal, date: Date(), context: context)

        let snapshots = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapshots.count == 1)
        #expect(snapshots.first?.value == 22.0)
    }

    // SNAPVAL-009 — Speed target: two matching-type workouts same date → snapshot = higher overallProgress%
    @Test func speedTargetTwoWorkoutsSameDateHigherProgressWins() throws {
        let context = try makeGoalContext()
        let goal = Goal(
            title: "5K Run", goalType: "Speed and Distance",
            targetDistanceKm: 5, targetDurationMinutes: 30,
            linkedWorkoutType: "Cardio", sortOrder: 0
        )
        context.insert(goal)

        // Workout A: 3km in 20min → dist=60%, dur=100%, overall=60%
        let w1 = Workout(name: "Run A", workoutType: "Cardio", durationMinutes: 20, distanceKm: 3.0)
        context.insert(w1)

        // Workout B: 4km in 25min → dist=80%, dur=100%, overall=80%
        let w2 = Workout(name: "Run B", workoutType: "Cardio", durationMinutes: 25, distanceKm: 4.0)
        context.insert(w2)
        try context.save()

        GoalSnapshotService.recomputeSnapshot(goal: goal, date: Date(), context: context)

        let snapshots = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapshots.count == 1)
        #expect(snapshots.first?.value == 80.0)
    }

    // SNAPVAL-010 — Speed target ties same date: most recent workout wins
    // Note: Within the same day, computeBestOfDayValue picks the max overallProgress.
    // If both are equal, the implementation picks the first one encountered.
    @Test func speedTargetTieSameDatePicksHigher() throws {
        let context = try makeGoalContext()
        let goal = Goal(
            title: "5K Run", goalType: "Speed and Distance",
            targetDistanceKm: 5, targetDurationMinutes: 30,
            linkedWorkoutType: "Cardio", sortOrder: 0
        )
        context.insert(goal)

        // Both: 4km in 25min → dist=80%, dur=100%, overall=80%
        let w1 = Workout(name: "Run A", workoutType: "Cardio", durationMinutes: 25, distanceKm: 4.0)
        context.insert(w1)

        let w2 = Workout(name: "Run B", workoutType: "Cardio", durationMinutes: 25, distanceKm: 4.0)
        context.insert(w2)
        try context.save()

        GoalSnapshotService.recomputeSnapshot(goal: goal, date: Date(), context: context)

        let snapshots = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapshots.count == 1)
        #expect(snapshots.first?.value == 80.0)
    }

    // SNAPVAL-011 — Distance-only: snapshot value uses higher distanceKm of the day
    @Test func distanceOnlyHigherDistanceKmWins() throws {
        let context = try makeGoalContext()
        let goal = Goal(
            title: "10K Run", goalType: "Speed and Distance",
            targetDistanceKm: 10, linkedWorkoutType: "Cardio", sortOrder: 0
        )
        context.insert(goal)

        let w1 = Workout(name: "Run A", workoutType: "Cardio", distanceKm: 5.0)
        context.insert(w1)
        let w2 = Workout(name: "Run B", workoutType: "Cardio", distanceKm: 7.0)
        context.insert(w2)
        try context.save()

        GoalSnapshotService.recomputeSnapshot(goal: goal, date: Date(), context: context)

        let snapshots = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapshots.count == 1)
        // 7/10 * 100 = 70%
        #expect(snapshots.first?.value == 70.0)
    }

    // SNAPVAL-012 — Duration-only (endurance): snapshot value uses higher durationMinutes
    @Test func durationOnlyHigherDurationWins() throws {
        let context = try makeGoalContext()
        let goal = Goal(
            title: "Long Run", goalType: "Speed and Distance",
            targetDurationMinutes: 60, linkedWorkoutType: "Cardio", sortOrder: 0
        )
        context.insert(goal)

        let w1 = Workout(name: "Run A", workoutType: "Cardio", durationMinutes: 30)
        context.insert(w1)
        let w2 = Workout(name: "Run B", workoutType: "Cardio", durationMinutes: 45)
        context.insert(w2)
        try context.save()

        GoalSnapshotService.recomputeSnapshot(goal: goal, date: Date(), context: context)

        let snapshots = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapshots.count == 1)
        // 45/60 * 100 = 75%
        #expect(snapshots.first?.value == 75.0)
    }

    // SNAPVAL-013 — Out-of-scope workouts on a date are ignored by best-of-day computation
    @Test func outOfScopeWorkoutsIgnoredInBestOfDay() throws {
        let context = try makeGoalContext()
        let calendar = Calendar.current
        let now = Date()
        let resetDate = calendar.date(byAdding: .day, value: -2, to: now)!

        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        goal.resetDate = resetDate
        context.insert(goal)

        // Both workouts on the same date (5 days ago — before resetDate)
        let workoutDate = calendar.date(byAdding: .day, value: -5, to: now)!

        // Out-of-scope workout: date before resetDate, lastModified also before resetDate
        let w1 = Workout(name: "Old Workout", date: workoutDate, workoutType: "Strength Training")
        w1.lastModifiedDate = workoutDate
        let s1 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 95)
        s1.workout = w1
        w1.exerciseSets = [s1]
        context.insert(w1)

        // In-scope workout: same date, but lastModifiedDate AFTER resetDate (re-scoped via edit)
        let w2 = Workout(name: "Re-scoped Workout", date: workoutDate, workoutType: "Strength Training")
        w2.lastModifiedDate = now
        let s2 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 60)
        s2.workout = w2
        w2.exerciseSets = [s2]
        context.insert(w2)
        try context.save()

        GoalSnapshotService.recomputeSnapshot(goal: goal, date: workoutDate, context: context)

        let snapshots = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapshots.count == 1)
        // The out-of-scope workout (95kg) should be ignored; only in-scope (60kg) counted
        #expect(snapshots.first?.value == 60.0)
    }
}
