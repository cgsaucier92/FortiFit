import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// Section 3: GoalService Tests — Completion Date Tracking
/// Tests verify completion via lastCelebratedDate (per-goal, race-safe).

private func makeGoalContext() throws -> ModelContext {
    let schema = Schema([Workout.self, ExerciseSet.self, Goal.self, GoalSnapshot.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

@Suite(.serialized)
struct GoalCompletionTests {

    // COMP-001
    @Test func goalCrossing100SetsLastCelebratedAndFlag() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 90, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let set = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 105)
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

        #expect(goal.currentValueKg == 105)
        #expect(goal.lastCelebratedDate != nil)
        #expect(Calendar.current.isDateInToday(goal.lastCelebratedDate!))
    }

    // COMP-002
    @Test func goalCrossing100SetsLastCelebratedDate() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 90, sortOrder: 0)
        context.insert(goal)
        try context.save()

        #expect(goal.lastCelebratedDate == nil)

        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let set = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 105)
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

        let today = Calendar.current.startOfDay(for: Date())
        #expect(goal.lastCelebratedDate != nil)
        #expect(Calendar.current.isDate(goal.lastCelebratedDate!, inSameDayAs: today))
    }

    // COMP-003
    @Test func goalAlreadyAt100DoesNotReFireSameDay() throws {
        let context = try makeGoalContext()
        let today = Calendar.current.startOfDay(for: Date())
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 100, lastCelebratedDate: today, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let set = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 110)
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

        // Already at 100%+ before (previousProgress >= 100), so completion check never fires
        #expect(goal.lastCelebratedDate != nil)
        #expect(Calendar.current.isDate(goal.lastCelebratedDate!, inSameDayAs: today))
        #expect(goal.currentValueKg == 110)
    }

    // COMP-004
    @Test func goalDroppedAndReCrossesOnLaterDateFiresFlame() throws {
        let context = try makeGoalContext()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 90, lastCelebratedDate: yesterday, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
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

        // Today is strictly after yesterday, so re-fire is allowed
        #expect(Calendar.current.isDateInToday(goal.lastCelebratedDate!))
        #expect(goal.currentValueKg == 102)
    }

    // COMP-005
    @Test func goalDroppedAndReCrossesSameDayDoesNotReFire() throws {
        let context = try makeGoalContext()
        let today = Calendar.current.startOfDay(for: Date())
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 90, lastCelebratedDate: today, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let set = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 101)
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

        // today is NOT strictly after today, so checkAndFireCompletion guards early
        #expect(goal.currentValueKg == 101)
        #expect(goal.lastCelebratedDate != nil)
        #expect(Calendar.current.isDate(goal.lastCelebratedDate!, inSameDayAs: today))
    }

    // COMP-006
    @Test func multipleGoalsCrossing100SetsFlagOnce() throws {
        let context = try makeGoalContext()
        let goalBench = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 90, sortOrder: 0)
        let goalSquat = Goal(title: "Barbell Squats", goalType: "Strength PR", targetValueKg: 120, currentValueKg: 115, sortOrder: 1)
        context.insert(goalBench)
        context.insert(goalSquat)
        try context.save()

        let workout = Workout(name: "Full Body", workoutType: "Strength Training")
        let set1 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 105, sortOrder: 0)
        let set2 = ExerciseSet(exerciseName: "Barbell Squats", sets: 3, reps: 5, weightKg: 125, sortOrder: 1)
        set1.workout = workout
        set2.workout = workout
        workout.exerciseSets = [set1, set2]
        context.insert(workout)
        try context.save()

        GoalService.recalculateGoals(
            affectedExerciseNames: ["Bench Press", "Barbell Squats"],
            affectedWorkoutTypes: ["Strength Training"],
            workout: workout,
            context: context
        )

        // Both goals crossed 100% — lastCelebratedDate set on both
        let today = Calendar.current.startOfDay(for: Date())
        #expect(goalBench.lastCelebratedDate != nil)
        #expect(Calendar.current.isDate(goalBench.lastCelebratedDate!, inSameDayAs: today))
        #expect(goalSquat.lastCelebratedDate != nil)
        #expect(Calendar.current.isDate(goalSquat.lastCelebratedDate!, inSameDayAs: today))
    }

    // COMP-007
    @Test func goalBelow100DoesNotSetFlag() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 50, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let set = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 70)
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

        #expect(goal.currentValueKg == 70)
        #expect(goal.lastCelebratedDate == nil) // No completion fired
    }

    // COMP-008
    @Test func repsPRCrossing100SetsFlag() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Repetitions PR", targetReps: 15, currentReps: 12, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let set = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 16)
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

        #expect(goal.currentReps == 16)
        #expect(goal.lastCelebratedDate != nil)
        #expect(Calendar.current.isDateInToday(goal.lastCelebratedDate!))
    }

    // COMP-009
    @Test func speedDistanceBothTargetsRequiresBothMet() throws {
        let context = try makeGoalContext()
        // Start incomplete: distance not yet met, duration under target (good)
        let goal = Goal(
            title: "5K Run",
            goalType: "Speed and Distance",
            targetDistanceKm: 5.0,
            currentDistanceKm: 4.0,
            targetDurationMinutes: 30.0,
            currentDurationMinutes: 28.0,
            linkedWorkoutType: "Cardio",
            sortOrder: 0
        )
        context.insert(goal)
        try context.save()

        // Workout pushes distance past target; duration stays under target → complete
        let workout = Workout(name: "Evening Run", workoutType: "Cardio", durationMinutes: 29, distanceKm: 5.5)
        context.insert(workout)
        try context.save()

        GoalService.recalculateGoals(
            affectedExerciseNames: [],
            affectedWorkoutTypes: ["Cardio"],
            workout: workout,
            context: context
        )

        #expect(goal.currentDistanceKm == 5.5)
        #expect(goal.currentDurationMinutes == 29.0)
        #expect(goal.lastCelebratedDate != nil)
        #expect(Calendar.current.isDateInToday(goal.lastCelebratedDate!))
    }

    // COMP-010
    @Test func weeklyWorkoutsCrossing100SetsFlag() throws {
        let context = try makeGoalContext()

        let goal = Goal(title: "Workouts Per Week", goalType: "weeklyWorkouts", sortOrder: 0)
        context.insert(goal)

        // Log 3 workouts this week using the same week definition as the service (ISO 8601)
        let today = Date()
        let monday = today.startOfWeek
        let calendar = Calendar.current

        for i in 0..<3 {
            let date = calendar.date(byAdding: .day, value: i, to: monday)!
            let w = Workout(name: "Workout \(i+1)", date: date, workoutType: "Strength Training")
            context.insert(w)
        }
        try context.save()

        let progress = GoalService.weeklyWorkoutsProgress(context: context, target: 3)
        #expect(progress.current >= 3)
        #expect(progress.isComplete == true)
    }

    // COMP-012
    @Test func snapshotAppendedWhenGoalValueChanges() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 50, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let set = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 70)
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

        let snapshots = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapshots.count == 1)
        #expect(snapshots.first?.value == 70.0)
    }
}
