import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// Section 13: Integration Tests — End-to-End Flows

private func makeGoalContext() throws -> ModelContext {
    let schema = Schema([Workout.self, ExerciseSet.self, Goal.self, GoalSnapshot.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

@Suite(.serialized)
struct GoalIntegrationTests {

    // INT-001
    @Test func fullLifecycleCreateLogAchieveFlame() throws {
        let context = try makeGoalContext()

        // Create goal
        GoalService.createExercisePRGoal(title: "Bench Press", targetValueKg: 100, context: context)
        let goals = GoalService.fetchAll(context: context)
        let goal = goals.first!

        // Step 1: Log workout at 60kg
        let w1 = Workout(name: "Day 1", workoutType: "Strength Training")
        let s1 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 60)
        s1.workout = w1
        w1.exerciseSets = [s1]
        context.insert(w1)
        try context.save()
        GoalService.recalculateGoals(
            affectedExerciseNames: ["Bench Press"],
            affectedWorkoutTypes: ["Strength Training"],
            workout: w1,
            context: context
        )

        #expect(goal.currentValueKg == 60)
        let snap1 = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snap1.count == 1)
        #expect(snap1.first?.value == 60.0)

        // Step 2: Log workout at 80kg (same day — snapshot updated, not duplicated)
        let w2 = Workout(name: "Day 1 pt2", workoutType: "Strength Training")
        let s2 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 80)
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

        #expect(goal.currentValueKg == 80)
        let snap2 = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snap2.count == 1) // same day dedup
        #expect(snap2.first?.value == 80.0)

        // Step 3: Simulate next day with 105kg (crosses 100%)
        // Insert a snapshot manually for "yesterday" to simulate the previous day's state
        let calendar = Calendar.current
        let yesterday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: Date())!)
        // Update existing snapshot to yesterday to simulate day transition
        snap2.first?.date = yesterday
        try context.save()

        let w3 = Workout(name: "Day 2", workoutType: "Strength Training")
        let s3 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 105)
        s3.workout = w3
        w3.exerciseSets = [s3]
        context.insert(w3)
        try context.save()
        GoalService.recalculateGoals(
            affectedExerciseNames: ["Bench Press"],
            affectedWorkoutTypes: ["Strength Training"],
            workout: w3,
            context: context
        )

        #expect(goal.currentValueKg == 105)
        #expect(goal.lastCelebratedDate != nil)
        #expect(Calendar.current.isDateInToday(goal.lastCelebratedDate!))

        // Verify sparkline data
        let allSnaps = GoalSnapshotService.fetchSnapshots(goalId: goal.id, context: context)
        #expect(allSnaps.count == 2) // yesterday + today
    }

    // INT-002
    @Test func fullLifecycleResetAfterAchievementReAchieve() throws {
        let context = try makeGoalContext()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!

        let goal = Goal(
            title: "Bench Press",
            goalType: "Strength PR",
            targetValueKg: 100,
            currentValueKg: 100,
            lastCelebratedDate: yesterday,
            sortOrder: 0
        )
        context.insert(goal)
        try context.save()

        // Step 1: Reset
        GoalService.resetGoalProgress(goal: goal, context: context)
        #expect(goal.currentValueKg == 0)
        #expect(goal.lastCelebratedDate == nil)
        #expect(goal.resetDate != nil)

        let snapshots = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapshots.isEmpty) // Snapshots wiped on reset

        // Step 2: Log new workout that crosses 100%
        let w = Workout(name: "Push Day", workoutType: "Strength Training")
        w.lastModifiedDate = .now
        let s = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 102)
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

        // Re-celebration allowed after reset (lastCelebratedDate was nil)
        #expect(goal.lastCelebratedDate != nil)
        #expect(goal.currentValueKg == 102)
    }

    // INT-003
    @Test func goalDeletionCleansUpAllAssociatedData() throws {
        let context = try makeGoalContext()
        let vm = GoalsViewModel()

        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for i in 0..<20 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            context.insert(GoalSnapshot(goalId: goal.id, date: date, value: Double(i)))
        }
        try context.save()

        vm.loadGoals(context: context)
        vm.toggleExpanded(goalId: goal.id)
        #expect(vm.expandedGoalIds.contains(goal.id))

        vm.deleteGoal(goal, context: context)

        let remainingSnapshots = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(remainingSnapshots.isEmpty)
        #expect(!vm.expandedGoalIds.contains(goal.id))

        let remainingGoals = GoalService.fetchAll(context: context)
        #expect(remainingGoals.isEmpty)
    }

    // INT-004
    @Test func filterPlusExpandInteraction() throws {
        let context = try makeGoalContext()
        let vm = GoalsViewModel()

        let goalA = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 50, sortOrder: 0)
        let goalB = Goal(title: "Squat", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 100, sortOrder: 1) // Victory
        let goalC = Goal(title: "Deadlift", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 75, sortOrder: 2)
        context.insert(goalA)
        context.insert(goalB)
        context.insert(goalC)
        try context.save()

        vm.loadGoals(context: context)
        vm.toggleExpanded(goalId: goalA.id)
        vm.toggleExpanded(goalId: goalB.id)

        // Filter to active
        vm.activeFilter = .active
        let filtered = vm.filteredGoals
        #expect(filtered.count == 2)
        #expect(filtered.contains { $0.id == goalA.id })
        #expect(filtered.contains { $0.id == goalC.id })
        #expect(!filtered.contains { $0.id == goalB.id })

        // A should still be expanded
        #expect(vm.expandedGoalIds.contains(goalA.id))
        // B's expanded state preserved even though filtered out
        #expect(vm.expandedGoalIds.contains(goalB.id))

        // Switch back to all — B should reappear expanded
        vm.activeFilter = .all
        #expect(vm.filteredGoals.count == 3)
        #expect(vm.expandedGoalIds.contains(goalB.id))
    }

    // INT-005
    @Test func workoutEditDropsGoalBelowThenReCrossesFiresFlame() throws {
        let context = try makeGoalContext()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!

        let goal = Goal(
            title: "Bench Press",
            goalType: "Strength PR",
            targetValueKg: 100,
            currentValueKg: 105,
            lastCelebratedDate: yesterday,
            sortOrder: 0
        )
        context.insert(goal)

        // Original workout
        let w1 = Workout(name: "Push Day", workoutType: "Strength Training")
        let s1 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 105)
        s1.workout = w1
        w1.exerciseSets = [s1]
        context.insert(w1)
        try context.save()

        // Step 1: Edit W1 to reduce weight to 80kg
        s1.weightKg = 80
        try context.save()
        GoalService.recalculateGoals(
            affectedExerciseNames: ["Bench Press"],
            affectedWorkoutTypes: ["Strength Training"],
            context: context
        )
        #expect(goal.currentValueKg == 80)

        // Step 2: Log new workout that crosses 100%
        let w2 = Workout(name: "Push Day 2", workoutType: "Strength Training")
        let s2 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 101)
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

        #expect(goal.currentValueKg == 101)
        #expect(goal.lastCelebratedDate != nil)
        #expect(Calendar.current.isDateInToday(goal.lastCelebratedDate!))
    }
}
