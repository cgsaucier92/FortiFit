import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// GoalSpeedTargetTests — Validates SERVICES.md § Goal Progress Calculation → speedDistance (both)
/// Tests speed target progress and completion formula.

private func makeGoalContext() throws -> ModelContext {
    let schema = Schema([Workout.self, ExerciseSet.self, Goal.self, GoalSnapshot.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

@Suite(.serialized)
struct GoalSpeedTargetTests {

    // SPEED-001 — Beating target time: durationProgress clamps to 100, overall = 100, goal completes
    @Test func beatingTargetTimeClampsTo100AndCompletes() throws {
        let context = try makeGoalContext()
        let goal = Goal(
            title: "5K Run", goalType: "Speed and Distance",
            targetDistanceKm: 5.0, currentDistanceKm: 5.5,
            targetDurationMinutes: 30.0, currentDurationMinutes: 25.0,
            linkedWorkoutType: "Cardio", sortOrder: 0
        )
        context.insert(goal)
        try context.save()

        let percentage = GoalService.completionPercentage(for: goal)
        let complete = GoalService.isComplete(goal)

        // distance: min(5.5/5.0*100, 100) = 100
        // duration: 25 <= 30 → 100
        // overall: min(100, 100) = 100
        #expect(percentage == 100)
        #expect(complete == true)
    }

    // SPEED-002 — Exactly meeting target distance AND time: overall = 100, goal completes
    @Test func exactlyMeetingBothTargetsCompletes() throws {
        let context = try makeGoalContext()
        let goal = Goal(
            title: "5K Run", goalType: "Speed and Distance",
            targetDistanceKm: 5.0, currentDistanceKm: 5.0,
            targetDurationMinutes: 30.0, currentDurationMinutes: 30.0,
            linkedWorkoutType: "Cardio", sortOrder: 0
        )
        context.insert(goal)
        try context.save()

        let percentage = GoalService.completionPercentage(for: goal)
        let complete = GoalService.isComplete(goal)

        #expect(percentage == 100)
        #expect(complete == true)
    }

    // SPEED-003 — Exceeds distance but over target time: durationProgress < 100, no completion
    @Test func exceedsDistanceButOverTimeDoesNotComplete() throws {
        let context = try makeGoalContext()
        let goal = Goal(
            title: "5K Run", goalType: "Speed and Distance",
            targetDistanceKm: 5.0, currentDistanceKm: 6.0,
            targetDurationMinutes: 30.0, currentDurationMinutes: 40.0,
            linkedWorkoutType: "Cardio", sortOrder: 0
        )
        context.insert(goal)
        try context.save()

        let percentage = GoalService.completionPercentage(for: goal)
        let complete = GoalService.isComplete(goal)

        // distance: 100 (clamped)
        // duration: (30/40)*100 = 75
        // overall: min(100, 75) = 75
        #expect(percentage == 75)
        #expect(complete == false)
    }

    // SPEED-004 — Spec example: goal 5mi in 30min, actual 5mi in 45min → 67%, no completion
    @Test func specExampleFiveInThirtyActualFiveInFortyFive() throws {
        let context = try makeGoalContext()
        let goal = Goal(
            title: "5 Mile Run", goalType: "Speed and Distance",
            targetDistanceKm: 5.0, currentDistanceKm: 5.0,
            targetDurationMinutes: 30.0, currentDurationMinutes: 45.0,
            linkedWorkoutType: "Cardio", sortOrder: 0
        )
        context.insert(goal)
        try context.save()

        let percentage = GoalService.completionPercentage(for: goal)

        // distance: 100%
        // duration: (30/45)*100 ≈ 66.67%
        // overall: min(100, 66.67) ≈ 66.67
        #expect(abs(percentage - 66.67) < 0.1)
        #expect(GoalService.isComplete(goal) == false)
    }

    // SPEED-005 — overallProgress = min(distanceProgress, durationProgress) when both below 100
    @Test func overallProgressIsMinOfBothWhenBothBelow100() throws {
        let context = try makeGoalContext()
        let goal = Goal(
            title: "10K Run", goalType: "Speed and Distance",
            targetDistanceKm: 10.0, currentDistanceKm: 6.0,
            targetDurationMinutes: 50.0, currentDurationMinutes: 60.0,
            linkedWorkoutType: "Cardio", sortOrder: 0
        )
        context.insert(goal)
        try context.save()

        let percentage = GoalService.completionPercentage(for: goal)

        // distance: (6/10)*100 = 60%
        // duration: (50/60)*100 ≈ 83.33%
        // overall: min(60, 83.33) = 60
        #expect(abs(percentage - 60) < 0.1)
    }

    // SPEED-006 — distanceProgress clamped 0–100 (running further than target does not exceed 100%)
    @Test func distanceProgressClampedAt100() throws {
        let context = try makeGoalContext()
        let goal = Goal(
            title: "5K Run", goalType: "Speed and Distance",
            targetDistanceKm: 5.0, currentDistanceKm: 8.0,
            targetDurationMinutes: 30.0, currentDurationMinutes: 35.0,
            linkedWorkoutType: "Cardio", sortOrder: 0
        )
        context.insert(goal)
        try context.save()

        let percentage = GoalService.completionPercentage(for: goal)

        // distance: min(8/5*100, 100) = 100 (clamped)
        // duration: (30/35)*100 ≈ 85.7%
        // overall: min(100, 85.7) ≈ 85.7
        #expect(abs(percentage - 85.71) < 0.1)
    }

    // SPEED-007 — Speed target logic ONLY when both targets set; duration-only uses "higher is better"
    @Test func durationOnlyUsesHigherIsBetter() throws {
        let context = try makeGoalContext()
        // Duration-only goal (no targetDistanceKm)
        let goal = Goal(
            title: "Endurance Run", goalType: "Speed and Distance",
            targetDurationMinutes: 60.0, currentDurationMinutes: 45.0,
            linkedWorkoutType: "Cardio", sortOrder: 0
        )
        context.insert(goal)
        try context.save()

        let percentage = GoalService.completionPercentage(for: goal)

        // Duration-only: (45/60)*100 = 75% — higher is better
        #expect(percentage == 75)
    }

    // SPEED-008 — Distance-only progress = currentDistance / target × 100, clamped 0–100
    @Test func distanceOnlyProgressCalculation() throws {
        let context = try makeGoalContext()
        let goal = Goal(
            title: "Marathon Prep", goalType: "Speed and Distance",
            targetDistanceKm: 42.0, currentDistanceKm: 21.0,
            linkedWorkoutType: "Cardio", sortOrder: 0
        )
        context.insert(goal)
        try context.save()

        let percentage = GoalService.completionPercentage(for: goal)

        // (21/42)*100 = 50
        #expect(percentage == 50)
    }
}
