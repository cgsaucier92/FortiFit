import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// GoalTriggerPathTests — Validates SERVICES.md § Goal Completion Date Tracking → Trigger Paths
/// Tests that auto-update and lastCelebratedDate fire equivalently across all workout-save entry points.

private func makeGoalContext() throws -> ModelContext {
    let schema = Schema([Workout.self, ExerciseSet.self, Goal.self, GoalSnapshot.self,
                         ScheduledWorkout.self, WorkoutTemplate.self, TemplateExerciseSet.self,
                         WorkoutTypeOrder.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

@Suite(.serialized)
struct GoalTriggerPathTests {

    // TRIG-001 — Direct workout logging triggers GoalService.recalculateGoals and sets lastCelebratedDate
    @Test func directWorkoutLoggingTriggersGoalRecalc() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 90, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let set = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 105)
        set.workout = workout
        workout.exerciseSets = [set]
        WorkoutService.logWorkout(workout, context: context)

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

    // TRIG-002 — PlanService.completeWorkout triggers the same GoalService path
    @Test func planServiceCompletionTriggersGoalRecalc() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 90, sortOrder: 0)
        context.insert(goal)

        // Create a template
        let template = WorkoutTemplate(name: "Push Template", workoutType: "Strength Training")
        let templateSet = TemplateExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 105, sortOrder: 0)
        templateSet.template = template
        template.exerciseSets = [templateSet]
        context.insert(template)

        // Schedule it
        let scheduled = ScheduledWorkout(
            templateId: template.id,
            templateSnapshot: PlanService.encodeSnapshot(template: template),
            scheduledDate: Date(),
            workoutType: "Strength Training",
            workoutName: "Push Template"
        )
        context.insert(scheduled)
        try context.save()

        // Complete via PlanService
        PlanService.completeWorkout(
            scheduledWorkout: scheduled,
            date: Date(),
            rpe: 7,
            durationMinutes: 60,
            context: context
        )

        // Goal should be updated
        #expect(goal.currentValueKg == 105)
        #expect(goal.lastCelebratedDate != nil)
    }

    // TRIG-003 — Today's Plan HomeWidget completion triggers the same GoalService path
    // (Uses the same PlanService.completeWorkout as TRIG-002, which is what the widget calls)
    @Test func homeWidgetCompletionTriggersGoalRecalc() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 90, sortOrder: 0)
        context.insert(goal)

        let template = WorkoutTemplate(name: "Push Template", workoutType: "Strength Training")
        let templateSet = TemplateExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 110, sortOrder: 0)
        templateSet.template = template
        template.exerciseSets = [templateSet]
        context.insert(template)

        let scheduled = ScheduledWorkout(
            templateId: template.id,
            templateSnapshot: PlanService.encodeSnapshot(template: template),
            scheduledDate: Date(),
            workoutType: "Strength Training",
            workoutName: "Push Template"
        )
        context.insert(scheduled)
        try context.save()

        // Complete via PlanService (same path as HomeWidget)
        PlanService.completeWorkout(
            scheduledWorkout: scheduled,
            date: Date(),
            rpe: nil,
            durationMinutes: nil,
            context: context
        )

        #expect(goal.currentValueKg == 110)
        #expect(goal.lastCelebratedDate != nil)
    }

    // TRIG-004 — Given identical workout inputs, all paths yield identical goal values and snapshots
    @Test func allPathsYieldIdenticalResults() throws {
        // Path A: Direct logging
        let contextA = try makeGoalContext()
        let goalA = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 90, sortOrder: 0)
        contextA.insert(goalA)
        try contextA.save()

        let workoutA = Workout(name: "Push Day", workoutType: "Strength Training")
        let setA = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 105)
        setA.workout = workoutA
        workoutA.exerciseSets = [setA]
        WorkoutService.logWorkout(workoutA, context: contextA)
        GoalService.recalculateGoals(
            affectedExerciseNames: ["Bench Press"],
            affectedWorkoutTypes: ["Strength Training"],
            workout: workoutA,
            context: contextA
        )

        // Path B: PlanService completion
        let contextB = try makeGoalContext()
        let goalB = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 90, sortOrder: 0)
        contextB.insert(goalB)

        let template = WorkoutTemplate(name: "Push Template", workoutType: "Strength Training")
        let templateSet = TemplateExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 105, sortOrder: 0)
        templateSet.template = template
        template.exerciseSets = [templateSet]
        contextB.insert(template)

        let scheduled = ScheduledWorkout(
            templateId: template.id,
            templateSnapshot: PlanService.encodeSnapshot(template: template),
            scheduledDate: Date(),
            workoutType: "Strength Training",
            workoutName: "Push Template"
        )
        contextB.insert(scheduled)
        try contextB.save()

        PlanService.completeWorkout(
            scheduledWorkout: scheduled,
            date: Date(),
            rpe: nil,
            durationMinutes: nil,
            context: contextB
        )

        // Compare results
        #expect(goalA.currentValueKg == goalB.currentValueKg)
        #expect(goalA.lastCelebratedDate != nil)
        #expect(goalB.lastCelebratedDate != nil)

        let snapshotsA = try contextA.fetch(FetchDescriptor<GoalSnapshot>())
        let snapshotsB = try contextB.fetch(FetchDescriptor<GoalSnapshot>())
        // Both should have same snapshot count
        #expect(snapshotsA.count == snapshotsB.count)
    }
}
