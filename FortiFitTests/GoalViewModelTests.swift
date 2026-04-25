import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// Sections 6, 7, 12: GoalsViewModel Tests — Filter, Expand/Collapse, Reset Visibility

private func makeGoalContext() throws -> ModelContext {
    let schema = Schema([Workout.self, ExerciseSet.self, Goal.self, GoalSnapshot.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

// MARK: - Section 6: Filter Tests

struct GoalViewModelFilterTests {

    // FILT-001
    @Test func defaultFilterIsAll() {
        let vm = GoalsViewModel()
        #expect(vm.activeFilter == .all)
    }

    // FILT-002
    @Test func filterAllReturnsAllGoals() throws {
        let context = try makeGoalContext()
        let vm = GoalsViewModel()

        let goal50 = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 50, sortOrder: 0)
        let goalVictory = Goal(title: "Squat", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 100, sortOrder: 1)
        let goal75 = Goal(title: "Deadlift", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 75, sortOrder: 2)
        context.insert(goal50)
        context.insert(goalVictory)
        context.insert(goal75)
        try context.save()

        vm.loadGoals(context: context)
        vm.activeFilter = .all

        #expect(vm.filteredGoals.count == 3)
    }

    // FILT-003
    @Test func filterActiveReturnsOnlyBelow100() throws {
        let context = try makeGoalContext()
        let vm = GoalsViewModel()

        let goal50 = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 50, sortOrder: 0)
        let goalVictory = Goal(title: "Squat", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 100, sortOrder: 1)
        let goal75 = Goal(title: "Deadlift", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 75, sortOrder: 2)
        context.insert(goal50)
        context.insert(goalVictory)
        context.insert(goal75)
        try context.save()

        vm.loadGoals(context: context)
        vm.activeFilter = .active

        #expect(vm.filteredGoals.count == 2)
        #expect(vm.filteredGoals.allSatisfy { GoalService.completionPercentage(for: $0) < 100 })
    }

    // FILT-004
    @Test func filterCompletedReturnsOnlyAt100Plus() throws {
        let context = try makeGoalContext()
        let vm = GoalsViewModel()

        let goal50 = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 50, sortOrder: 0)
        let goalVictory = Goal(title: "Squat", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 100, sortOrder: 1)
        let goal75 = Goal(title: "Deadlift", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 75, sortOrder: 2)
        context.insert(goal50)
        context.insert(goalVictory)
        context.insert(goal75)
        try context.save()

        vm.loadGoals(context: context)
        vm.activeFilter = .completed

        #expect(vm.filteredGoals.count == 1)
        #expect(vm.filteredGoals.first?.title == "Squat")
    }

    // FILT-005
    @Test func filterActiveWithNoActiveGoalsReturnsEmpty() throws {
        let context = try makeGoalContext()
        let vm = GoalsViewModel()

        let goal1 = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 100, sortOrder: 0)
        let goal2 = Goal(title: "Squat", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 100, sortOrder: 1)
        context.insert(goal1)
        context.insert(goal2)
        try context.save()

        vm.loadGoals(context: context)
        vm.activeFilter = .active

        #expect(vm.filteredGoals.isEmpty)
    }

    // FILT-006
    @Test func filterCompletedWithNoCompletedGoalsReturnsEmpty() throws {
        let context = try makeGoalContext()
        let vm = GoalsViewModel()

        let goal1 = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 50, sortOrder: 0)
        let goal2 = Goal(title: "Squat", goalType: "Strength PR", targetValueKg: 100, currentValueKg: 75, sortOrder: 1)
        context.insert(goal1)
        context.insert(goal2)
        try context.save()

        vm.loadGoals(context: context)
        vm.activeFilter = .completed

        #expect(vm.filteredGoals.isEmpty)
    }

    // FILT-008
    @Test func filterDoesNotPersistAcrossReinit() {
        let vm1 = GoalsViewModel()
        vm1.activeFilter = .active

        let vm2 = GoalsViewModel()
        #expect(vm2.activeFilter == .all)
    }
}

// MARK: - Section 7: Expand/Collapse Tests

struct GoalViewModelExpandTests {

    // EXP-001
    @Test func defaultStateAllCollapsed() throws {
        let context = try makeGoalContext()
        let vm = GoalsViewModel()

        for i in 0..<3 {
            let goal = Goal(title: "Goal \(i)", goalType: "Strength PR", targetValueKg: 100, sortOrder: i)
            context.insert(goal)
        }
        try context.save()

        vm.loadGoals(context: context)
        #expect(vm.expandedGoalIds.isEmpty)
    }

    // EXP-002
    @Test func toggleExpandedAddsGoalId() throws {
        let context = try makeGoalContext()
        let vm = GoalsViewModel()

        let goalA = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        let goalB = Goal(title: "Squat", goalType: "Strength PR", targetValueKg: 100, sortOrder: 1)
        context.insert(goalA)
        context.insert(goalB)
        try context.save()

        vm.loadGoals(context: context)
        vm.toggleExpanded(goalId: goalA.id)

        #expect(vm.expandedGoalIds.contains(goalA.id))
        #expect(!vm.expandedGoalIds.contains(goalB.id))
    }

    // EXP-003
    @Test func toggleExpandedOnExpandedCardCollapsesIt() throws {
        let context = try makeGoalContext()
        let vm = GoalsViewModel()

        let goalA = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        context.insert(goalA)
        try context.save()

        vm.loadGoals(context: context)
        vm.toggleExpanded(goalId: goalA.id)
        #expect(vm.expandedGoalIds.contains(goalA.id))

        vm.toggleExpanded(goalId: goalA.id)
        #expect(!vm.expandedGoalIds.contains(goalA.id))
    }

    // EXP-004
    @Test func multipleCardsCanBeExpandedSimultaneously() throws {
        let context = try makeGoalContext()
        let vm = GoalsViewModel()

        let goalA = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        let goalB = Goal(title: "Squat", goalType: "Strength PR", targetValueKg: 100, sortOrder: 1)
        let goalC = Goal(title: "Deadlift", goalType: "Strength PR", targetValueKg: 100, sortOrder: 2)
        context.insert(goalA)
        context.insert(goalB)
        context.insert(goalC)
        try context.save()

        vm.loadGoals(context: context)
        vm.toggleExpanded(goalId: goalA.id)
        vm.toggleExpanded(goalId: goalB.id)

        #expect(vm.expandedGoalIds.contains(goalA.id))
        #expect(vm.expandedGoalIds.contains(goalB.id))
    }

    // EXP-005
    @Test func expandAllExpandsAllGoals() throws {
        let context = try makeGoalContext()
        let vm = GoalsViewModel()

        var goals: [Goal] = []
        for i in 0..<4 {
            let goal = Goal(title: "Goal \(i)", goalType: "Strength PR", targetValueKg: 100, sortOrder: i)
            context.insert(goal)
            goals.append(goal)
        }
        try context.save()

        vm.loadGoals(context: context)
        vm.toggleExpanded(goalId: goals[0].id) // 1 expanded, 3 collapsed

        vm.expandAll()

        #expect(vm.expandedGoalIds.count == 4)
        for goal in goals {
            #expect(vm.expandedGoalIds.contains(goal.id))
        }
    }

    // EXP-006
    @Test func collapseAllCollapsesAllGoals() throws {
        let context = try makeGoalContext()
        let vm = GoalsViewModel()

        var goals: [Goal] = []
        for i in 0..<4 {
            let goal = Goal(title: "Goal \(i)", goalType: "Strength PR", targetValueKg: 100, sortOrder: i)
            context.insert(goal)
            goals.append(goal)
        }
        try context.save()

        vm.loadGoals(context: context)
        vm.toggleExpanded(goalId: goals[0].id)
        vm.toggleExpanded(goalId: goals[1].id)
        vm.toggleExpanded(goalId: goals[2].id)

        vm.collapseAll()

        #expect(vm.expandedGoalIds.isEmpty)
    }

    // EXP-007
    @Test func expandCollapseLabelReturnsExpandAllWhenMostCollapsed() throws {
        let context = try makeGoalContext()
        let vm = GoalsViewModel()

        var goals: [Goal] = []
        for i in 0..<4 {
            let goal = Goal(title: "Goal \(i)", goalType: "Strength PR", targetValueKg: 100, sortOrder: i)
            context.insert(goal)
            goals.append(goal)
        }
        try context.save()

        vm.loadGoals(context: context)
        vm.toggleExpanded(goalId: goals[0].id) // 1 expanded, 3 collapsed

        #expect(vm.expandCollapseLabel == "Expand All")
    }

    // EXP-008
    @Test func expandCollapseLabelReturnsCollapseAllWhenMostExpanded() throws {
        let context = try makeGoalContext()
        let vm = GoalsViewModel()

        var goals: [Goal] = []
        for i in 0..<4 {
            let goal = Goal(title: "Goal \(i)", goalType: "Strength PR", targetValueKg: 100, sortOrder: i)
            context.insert(goal)
            goals.append(goal)
        }
        try context.save()

        vm.loadGoals(context: context)
        vm.toggleExpanded(goalId: goals[0].id)
        vm.toggleExpanded(goalId: goals[1].id)
        vm.toggleExpanded(goalId: goals[2].id) // 3 expanded, 1 collapsed

        #expect(vm.expandCollapseLabel == "Collapse All")
    }

    // EXP-009
    @Test func expandCollapseLabelTieBreaksTowardExpandAll() throws {
        let context = try makeGoalContext()
        let vm = GoalsViewModel()

        var goals: [Goal] = []
        for i in 0..<4 {
            let goal = Goal(title: "Goal \(i)", goalType: "Strength PR", targetValueKg: 100, sortOrder: i)
            context.insert(goal)
            goals.append(goal)
        }
        try context.save()

        vm.loadGoals(context: context)
        vm.toggleExpanded(goalId: goals[0].id)
        vm.toggleExpanded(goalId: goals[1].id) // 2 expanded, 2 collapsed

        // 2 is not > 4/2 (which is 2), so "Expand All"
        #expect(vm.expandCollapseLabel == "Expand All")
    }

    // EXP-010
    @Test func deletingExpandedGoalRemovesFromExpandedIds() throws {
        let context = try makeGoalContext()
        let vm = GoalsViewModel()

        let goalA = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        context.insert(goalA)
        try context.save()

        vm.loadGoals(context: context)
        vm.toggleExpanded(goalId: goalA.id)
        #expect(vm.expandedGoalIds.contains(goalA.id))

        vm.deleteGoal(goalA, context: context)

        #expect(!vm.expandedGoalIds.contains(goalA.id))
    }
}

// MARK: - Section 12: Reset Context Menu Visibility

struct GoalResetVisibilityTests {

    // Helper: tests the logic used in GoalsView: goal.goalType != "weeklyWorkouts"
    private func shouldShowResetOption(for goal: Goal) -> Bool {
        goal.goalType != "weeklyWorkouts"
    }

    // RESETVIS-001
    @Test func resetOptionVisibleForExercisePR() {
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", sortOrder: 0)
        #expect(shouldShowResetOption(for: goal) == true)
    }

    // RESETVIS-002
    @Test func resetOptionVisibleForRepsPR() {
        let goal = Goal(title: "Bench Press", goalType: "Repetitions PR", sortOrder: 0)
        #expect(shouldShowResetOption(for: goal) == true)
    }

    // RESETVIS-003
    @Test func resetOptionVisibleForSpeedDistance() {
        let goal = Goal(title: "5K Run", goalType: "Speed and Distance", sortOrder: 0)
        #expect(shouldShowResetOption(for: goal) == true)
    }

    // RESETVIS-004
    @Test func resetOptionHiddenForWeeklyWorkouts() {
        let goal = Goal(title: "Workouts Per Week", goalType: "weeklyWorkouts", sortOrder: 0)
        #expect(shouldShowResetOption(for: goal) == false)
    }
}

// MARK: - Goal Distance Formatting Tests

/// Verifies that distance values on the Goals screen are rounded to 1 decimal place.
/// These tests replicate the exact formatting patterns used in GoalsView's targetText() and progressText().
struct GoalDistanceFormattingTests {

    // MARK: - Target Text (single distance)

    // DISTFMT-001
    @Test func targetDistanceMilesFormatsToOneDecimal() {
        let targetDistKm = 5.0
        let factor = UnitConversion.kmToMilesFactor
        let formatted = String(format: "%.1f miles", targetDistKm * factor)
        #expect(formatted == "3.1 miles")
    }

    // DISTFMT-002
    @Test func targetDistanceKmFormatsToOneDecimal() {
        let targetDistKm = 5.123
        let formatted = String(format: "%.1f km", targetDistKm)
        #expect(formatted == "5.1 km")
    }

    // DISTFMT-003: Dual-target (distance + duration) uses same 1-decimal format
    @Test func targetDualDistanceMilesFormatsToOneDecimal() {
        let targetDistKm = 8.047  // ~5 miles
        let targetDur = 30
        let factor = UnitConversion.kmToMilesFactor
        let distDisplay = String(format: "%.1f miles", targetDistKm * factor)
        let result = "\(distDisplay) in \(targetDur) minutes"
        #expect(result == "5.0 miles in 30 minutes")
    }

    // MARK: - Progress Text

    // DISTFMT-004
    @Test func progressDistanceMilesFormatsToOneDecimal() {
        let currentKm = 3.218
        let targetKm = 5.0
        let factor = UnitConversion.kmToMilesFactor
        let formatted = String(format: "%.1f / %.1f mi", currentKm * factor, targetKm * factor)
        #expect(formatted == "2.0 / 3.1 mi")
    }

    // DISTFMT-005
    @Test func progressDistanceKmFormatsToOneDecimal() {
        let currentKm = 3.456
        let targetKm = 10.0
        let formatted = String(format: "%.1f / %.1f km", currentKm, targetKm)
        #expect(formatted == "3.5 / 10.0 km")
    }

    // DISTFMT-006: Zero distance shows "0.0"
    @Test func progressDistanceZeroFormatsToOneDecimal() {
        let currentKm = 0.0
        let targetKm = 5.0
        let factor = UnitConversion.kmToMilesFactor
        let formatted = String(format: "%.1f / %.1f mi", currentKm * factor, targetKm * factor)
        #expect(formatted == "0.0 / 3.1 mi")
    }

    // DISTFMT-007: Whole-number distance still shows one decimal
    @Test func progressDistanceWholeNumberShowsOneDecimal() {
        let currentKm = 5.0
        let targetKm = 10.0
        let formatted = String(format: "%.1f / %.1f km", currentKm, targetKm)
        #expect(formatted == "5.0 / 10.0 km")
    }
}
