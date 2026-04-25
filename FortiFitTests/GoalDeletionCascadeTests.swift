import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// Section 5: GoalService Tests — Deletion Cascade

private func makeGoalContext() throws -> ModelContext {
    let schema = Schema([Workout.self, ExerciseSet.self, Goal.self, GoalSnapshot.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

struct GoalDeletionCascadeTests {

    // DEL-001
    @Test func deletingGoalCascadeDeletesAllSnapshots() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for i in 0..<15 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            context.insert(GoalSnapshot(goalId: goal.id, date: date, value: Double(i)))
        }
        try context.save()

        GoalService.deleteGoal(goal, context: context)

        let remaining = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(remaining.isEmpty)

        let goals = try context.fetch(FetchDescriptor<Goal>())
        #expect(goals.isEmpty)
    }

    // DEL-002
    @Test func deletingGoalDoesNotAffectOtherGoalsSnapshots() throws {
        let context = try makeGoalContext()
        let goalA = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        let goalB = Goal(title: "Squat", goalType: "Strength PR", targetValueKg: 150, sortOrder: 1)
        context.insert(goalA)
        context.insert(goalB)
        try context.save()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for i in 0..<10 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            context.insert(GoalSnapshot(goalId: goalA.id, date: date, value: Double(i)))
            context.insert(GoalSnapshot(goalId: goalB.id, date: date, value: Double(i)))
        }
        try context.save()

        GoalService.deleteGoal(goalA, context: context)

        let remaining = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(remaining.count == 10)
        #expect(remaining.allSatisfy { $0.goalId == goalB.id })
    }

    // DEL-003
    @Test func deletingGoalReIndexesRemainingSortOrder() throws {
        let context = try makeGoalContext()
        let goal0 = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        let goal1 = Goal(title: "Squat", goalType: "Strength PR", targetValueKg: 150, sortOrder: 1)
        let goal2 = Goal(title: "Deadlift", goalType: "Strength PR", targetValueKg: 200, sortOrder: 2)
        context.insert(goal0)
        context.insert(goal1)
        context.insert(goal2)
        try context.save()

        // Delete the middle goal
        GoalService.deleteGoal(goal1, context: context)

        let remaining = GoalService.fetchAll(context: context)
        #expect(remaining.count == 2)
        #expect(remaining[0].sortOrder == 0)
        #expect(remaining[1].sortOrder == 1)
    }
}
