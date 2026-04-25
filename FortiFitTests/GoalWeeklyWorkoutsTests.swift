import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// GoalWeeklyWorkoutsTests — Validates SERVICES.md § Number of Weekly Workouts Goals
/// Tests the Weekly Workouts goal type's runtime-derived target and current value.

private func makeGoalContext() throws -> ModelContext {
    let schema = Schema([Workout.self, ExerciseSet.self, Goal.self, GoalSnapshot.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

@Suite(.serialized)
struct GoalWeeklyWorkoutsTests {

    // WEEK-001 — Singleton enforcement: rejects creation of a second weeklyWorkouts goal
    @Test func singletonEnforcement() throws {
        let context = try makeGoalContext()

        GoalService.createWeeklyWorkoutsGoal(context: context)
        let count1 = GoalService.fetchAll(context: context).filter { $0.goalType == "weeklyWorkouts" }.count
        #expect(count1 == 1)

        // Attempt to create a second one
        GoalService.createWeeklyWorkoutsGoal(context: context)
        let count2 = GoalService.fetchAll(context: context).filter { $0.goalType == "weeklyWorkouts" }.count
        #expect(count2 == 1)
    }

    // WEEK-002 — Target value read from UserSettings.targetWorkoutsPerWeek at eval time
    @Test func targetFromUserSettings() throws {
        let context = try makeGoalContext()
        UserSettings.shared.targetWorkoutsPerWeek = 4

        GoalService.createWeeklyWorkoutsGoal(context: context)
        let progress = GoalService.weeklyWorkoutsProgress(context: context)

        #expect(progress.target == 4)
    }

    // WEEK-003 — Changing UserSettings.targetWorkoutsPerWeek updates displayed target immediately
    @Test func changingSettingsUpdatesTargetImmediately() throws {
        let context = try makeGoalContext()
        UserSettings.shared.targetWorkoutsPerWeek = 3

        GoalService.createWeeklyWorkoutsGoal(context: context)
        let progress1 = GoalService.weeklyWorkoutsProgress(context: context)
        #expect(progress1.target == 3)

        // Change the setting
        UserSettings.shared.targetWorkoutsPerWeek = 6
        let progress2 = GoalService.weeklyWorkoutsProgress(context: context)
        #expect(progress2.target == 6)
    }

    // WEEK-004 — Current value = count of workouts within current Mon 00:00 – Sun 23:59
    @Test func currentValueIsCurrentWeekCount() throws {
        let context = try makeGoalContext()
        UserSettings.shared.targetWorkoutsPerWeek = 5

        GoalService.createWeeklyWorkoutsGoal(context: context)

        let monday = Date().startOfWeek
        let calendar = Calendar.current

        // 3 workouts this week
        for i in 0..<3 {
            let date = calendar.date(byAdding: .day, value: i, to: monday)!
            let w = Workout(name: "Workout \(i+1)", date: date, workoutType: "Strength Training")
            context.insert(w)
        }

        // 1 workout last week (should not count)
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: monday)!
        let wOld = Workout(name: "Old Workout", date: lastWeek, workoutType: "Strength Training")
        context.insert(wOld)
        try context.save()

        let progress = GoalService.weeklyWorkoutsProgress(context: context)
        #expect(progress.current == 3)
    }

    // WEEK-005 — targetWorkoutsPerWeek = 0 → progress = 0% (no divide-by-zero)
    @Test func zeroTargetProgressIsZero() throws {
        let context = try makeGoalContext()
        UserSettings.shared.targetWorkoutsPerWeek = 0

        GoalService.createWeeklyWorkoutsGoal(context: context)

        let w = Workout(name: "Workout", workoutType: "Strength Training")
        context.insert(w)
        try context.save()

        let progress = GoalService.weeklyWorkoutsProgress(context: context)
        #expect(progress.percentage == 0)
        #expect(progress.isComplete == false)
    }

    // WEEK-006 — Progress crosses 100% when count ≥ target (target > 0)
    @Test func progressCrosses100WhenCountMeetsTarget() throws {
        let context = try makeGoalContext()
        UserSettings.shared.targetWorkoutsPerWeek = 2

        GoalService.createWeeklyWorkoutsGoal(context: context)

        let monday = Date().startOfWeek
        let calendar = Calendar.current

        for i in 0..<2 {
            let date = calendar.date(byAdding: .day, value: i, to: monday)!
            let w = Workout(name: "Workout \(i+1)", date: date, workoutType: "Strength Training")
            context.insert(w)
        }
        try context.save()

        let progress = GoalService.weeklyWorkoutsProgress(context: context)
        #expect(progress.percentage == 100)
        #expect(progress.isComplete == true)
    }

    // WEEK-007 — Week rollover: current value derives fresh from the new week's count
    @Test func weekRolloverDerivesFresh() throws {
        let context = try makeGoalContext()
        UserSettings.shared.targetWorkoutsPerWeek = 3

        GoalService.createWeeklyWorkoutsGoal(context: context)

        let calendar = Calendar.current
        let lastWeekMonday = calendar.date(byAdding: .day, value: -7, to: Date().startOfWeek)!

        // 3 workouts last week
        for i in 0..<3 {
            let date = calendar.date(byAdding: .day, value: i, to: lastWeekMonday)!
            let w = Workout(name: "Last Week \(i+1)", date: date, workoutType: "Strength Training")
            context.insert(w)
        }

        // 1 workout this week
        let thisMonday = Date().startOfWeek
        let wThisWeek = Workout(name: "This Week 1", date: thisMonday, workoutType: "Cardio")
        context.insert(wThisWeek)
        try context.save()

        let progress = GoalService.weeklyWorkoutsProgress(context: context)
        // Only this week's workouts count
        #expect(progress.current == 1)
    }

    // WEEK-008 — Deleting weeklyWorkouts goal does not modify targetWorkoutsPerWeek
    @Test func deletingGoalDoesNotModifySettings() throws {
        let context = try makeGoalContext()
        UserSettings.shared.targetWorkoutsPerWeek = 5

        GoalService.createWeeklyWorkoutsGoal(context: context)
        let goal = GoalService.fetchAll(context: context).first { $0.goalType == "weeklyWorkouts" }!

        GoalService.deleteGoal(goal, context: context)

        #expect(UserSettings.shared.targetWorkoutsPerWeek == 5)
    }

    // WEEK-009 — Deleting weeklyWorkouts goal does not affect Streak calculation
    @Test func deletingGoalDoesNotAffectStreak() throws {
        let context = try makeGoalContext()
        let originalStreak = UserSettings.shared.currentStreak

        GoalService.createWeeklyWorkoutsGoal(context: context)
        let goal = GoalService.fetchAll(context: context).first { $0.goalType == "weeklyWorkouts" }!

        GoalService.deleteGoal(goal, context: context)

        #expect(UserSettings.shared.currentStreak == originalStreak)
    }

    // WEEK-010 — Recalculates on workout save, edit, AND delete (same triggers as Streak)
    @Test func recalculatesOnSaveEditDelete() throws {
        let context = try makeGoalContext()
        UserSettings.shared.targetWorkoutsPerWeek = 5

        GoalService.createWeeklyWorkoutsGoal(context: context)

        // Save a workout
        let w = Workout(name: "Workout", workoutType: "Strength Training")
        WorkoutService.logWorkout(w, context: context)
        GoalService.recalculateGoals(
            affectedExerciseNames: [],
            affectedWorkoutTypes: ["Strength Training"],
            workout: w,
            context: context
        )

        let progress1 = GoalService.weeklyWorkoutsProgress(context: context)
        let count1 = progress1.current

        // Log another workout
        let w2 = Workout(name: "Workout 2", workoutType: "Cardio")
        WorkoutService.logWorkout(w2, context: context)
        GoalService.recalculateGoals(
            affectedExerciseNames: [],
            affectedWorkoutTypes: ["Cardio"],
            workout: w2,
            context: context
        )

        let progress2 = GoalService.weeklyWorkoutsProgress(context: context)
        #expect(progress2.current == count1 + 1)

        // Delete a workout
        WorkoutService.deleteWorkout(w2, context: context)
        GoalService.recalculateGoals(
            affectedExerciseNames: [],
            affectedWorkoutTypes: ["Cardio"],
            context: context
        )

        let progress3 = GoalService.weeklyWorkoutsProgress(context: context)
        #expect(progress3.current == count1)
    }
}
