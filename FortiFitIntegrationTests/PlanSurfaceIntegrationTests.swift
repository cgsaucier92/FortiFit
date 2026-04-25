//
//  PlanSurfaceIntegrationTests.swift
//  FortiFitIntegrationTests
//
//  Integration tests for the Plan surface feature: logged-only workout
//  surfacing, Remove from Plan dual-action, Show on Plan, and undo.
//
//  See SERVICES.md § PlanService → Retrieval, Remove from Plan, and
//  SERVICES.md § Deletion Cascading Behavior → Workout Hide from Plan.
//

import XCTest
import SwiftData
@testable import FortiFit

final class PlanSurfaceIntegrationTests: XCTestCase {

    // MARK: - Remove from Plan — Completed Scheduled Card (Dual-Action)

    /// Verifies that removing a completed scheduled card deletes the ScheduledWorkout
    /// AND sets hiddenFromPlan=true on the linked Workout, atomically.
    func test_removeFromPlanOnCompletedScheduledCard_deletesScheduledAndSetsWorkoutHidden() throws {
        let (_, context) = try TestFixtures.inMemoryContext()

        // Given: a template, a scheduled workout, and a completed workout linked to it
        let template = TestFixtures.makeTemplate(name: "Push Day", in: context)
        PlanService.scheduleWorkout(template: template, date: TestFixtures.startOfDay(.now), time: nil, recurrenceRule: nil, context: context)
        let sw = PlanService.fetchForDate(date: .now, context: context).first!
        PlanService.completeWorkout(scheduledWorkout: sw, date: .now, rpe: 7, durationMinutes: 45, context: context)

        let completedWorkoutId = sw.completedWorkoutId!
        let workout = try context.fetch(FetchDescriptor<Workout>()).first { $0.id == completedWorkoutId }!

        // When: Remove from Plan on the completed scheduled card
        let item = PlanCardItem.scheduled(sw)
        _ = PlanService.removeFromPlan(item: item, scope: .thisOnly, context: context)

        // Then: ScheduledWorkout is deleted and Workout has hiddenFromPlan = true
        let remainingScheduled = try context.fetch(FetchDescriptor<ScheduledWorkout>())
        XCTAssertTrue(remainingScheduled.isEmpty, "ScheduledWorkout should be deleted")
        XCTAssertTrue(workout.hiddenFromPlan, "Linked Workout should have hiddenFromPlan=true")

        // And the Workout itself still exists
        let remainingWorkouts = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(remainingWorkouts.count, 1, "Workout should survive removal from plan")
    }

    /// Verifies the dedup + hidden flag combination prevents the workout from reappearing.
    func test_removeFromPlanOnCompletedScheduledCard_workoutDoesNotReappearAsLoggedOnlyCard() throws {
        let (_, context) = try TestFixtures.inMemoryContext()

        let template = TestFixtures.makeTemplate(name: "Leg Day", in: context)
        let today = TestFixtures.startOfDay(.now)
        PlanService.scheduleWorkout(template: template, date: today, time: nil, recurrenceRule: nil, context: context)
        let sw = PlanService.fetchForDate(date: today, context: context).first!
        PlanService.completeWorkout(scheduledWorkout: sw, date: today, rpe: 8, durationMinutes: 60, context: context)

        // Remove from plan
        let item = PlanCardItem.scheduled(sw)
        _ = PlanService.removeFromPlan(item: item, scope: .thisOnly, context: context)

        // Plan surface should show nothing for today
        let items = PlanService.fetchPlanSurface(for: today, context: context)
        XCTAssertTrue(items.isEmpty, "Removed completed card should not reappear as logged-only")
    }

    /// Verifies recurring completed card removal: this-and-future deletes future planned only,
    /// preserves past completed/skipped instances.
    func test_removeFromPlanOnRecurringCompletedCard_thisAndFuture_deletesFuturePlannedOnly_preservesPastCompleted() throws {
        let (_, context) = try TestFixtures.inMemoryContext()
        let today = TestFixtures.startOfDay(.now)

        let template = TestFixtures.makeTemplate(name: "Full Body", in: context)
        PlanService.scheduleWorkout(template: template, date: today, time: nil, recurrenceRule: "weekly", context: context)

        // Get all instances in the recurring group
        let allScheduled = PlanService.fetchForDateRange(
            start: today,
            end: Calendar.current.date(byAdding: .day, value: 90, to: today)!,
            context: context
        )
        XCTAssertTrue(allScheduled.count >= 12, "Should have 12 recurring instances")

        // Complete the first (today)
        let first = allScheduled.first!
        PlanService.completeWorkout(scheduledWorkout: first, date: today, rpe: 7, durationMinutes: 50, context: context)

        // Skip the second
        let second = allScheduled[1]
        PlanService.skipWorkout(scheduledWorkout: second, context: context)

        // Remove from plan on the first (completed) with thisAndFuture scope
        let item = PlanCardItem.scheduled(first)
        _ = PlanService.removeFromPlan(item: item, scope: .thisAndFuture, context: context)

        // Then: only the skipped instance should remain (past, not future planned)
        let remaining = try context.fetch(FetchDescriptor<ScheduledWorkout>())
        // The completed one was deleted. The skipped one should survive (it's past/in the past week).
        // Future planned ones should be deleted.
        for sw in remaining {
            XCTAssertTrue(
                sw.status == "skipped" || sw.status == "completed",
                "Only skipped/completed instances should survive, got status: \(sw.status)"
            )
        }
    }

    // MARK: - Remove from Plan — Logged-Only Card

    /// Verifies removing a logged-only card preserves the Workout and all cascade data.
    func test_removeFromPlanOnLoggedOnlyCard_preservesWorkoutInWorkoutsListAndAllCascades() throws {
        let (_, context) = try TestFixtures.inMemoryContext()
        let today = TestFixtures.startOfDay(.now)

        // Given: a logged workout with a Strength PR goal
        let goal = TestFixtures.makeStrengthPRGoal(title: "Bench Press", targetKg: 100, in: context)
        let workout = TestFixtures.logWorkoutWithCascade(
            name: "Heavy Push",
            date: today,
            workoutType: "Strength Training",
            rpe: 8,
            durationMinutes: 60,
            exercises: [.init("Bench Press", sets: 4, reps: 6, weightKg: 90)],
            in: context
        )

        // Capture pre-removal values
        let goalValueBefore = goal.currentValueKg
        let streakBefore = StreakService.calculateStreak(context: context).streak
        let workoutCountBefore = try context.fetch(FetchDescriptor<Workout>()).count

        // When: Remove logged-only from plan
        let item = PlanCardItem.loggedOnly(workout)
        _ = PlanService.removeFromPlan(item: item, scope: .thisOnly, context: context)

        // Then: hiddenFromPlan is true, but everything else unchanged
        XCTAssertTrue(workout.hiddenFromPlan, "Should set hiddenFromPlan to true")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Workout>()).count, workoutCountBefore, "Workout count unchanged")
        XCTAssertEqual(goal.currentValueKg, goalValueBefore, "Goal value unchanged after hiding")
        XCTAssertEqual(StreakService.calculateStreak(context: context).streak, streakBefore, "Streak unchanged after hiding")
    }

    // MARK: - Show on Plan

    /// Verifies Show on Plan flips hiddenFromPlan back to false and the workout reappears.
    func test_showOnPlan_flipsHiddenFromPlanFalse_andWorkoutReappearsOnPlan() throws {
        let (_, context) = try TestFixtures.inMemoryContext()
        let today = TestFixtures.startOfDay(.now)

        let workout = TestFixtures.makeWorkout(name: "Yoga Flow", date: today, workoutType: "Yoga", in: context)
        workout.hiddenFromPlan = true
        try context.save()

        // Verify it's hidden
        let itemsBefore = PlanService.fetchPlanSurface(for: today, context: context)
        XCTAssertTrue(itemsBefore.isEmpty, "Hidden workout should not appear on plan")

        // When: Show on Plan
        PlanService.setHiddenFromPlan(workout: workout, hidden: false, context: context)

        // Then: appears on plan surface
        let itemsAfter = PlanService.fetchPlanSurface(for: today, context: context)
        XCTAssertEqual(itemsAfter.count, 1, "Workout should reappear on plan after Show on Plan")
        if case .loggedOnly(let w) = itemsAfter.first {
            XCTAssertEqual(w.id, workout.id)
        } else {
            XCTFail("Should appear as logged-only item")
        }
    }

    // MARK: - Undo Remove from Plan

    /// Verifies undo for logged-only card restores visibility via flag flip.
    func test_undoRemoveFromPlan_loggedOnly_restoresVisibilityViaFlagFlip() throws {
        let (_, context) = try TestFixtures.inMemoryContext()
        let today = TestFixtures.startOfDay(.now)

        let workout = TestFixtures.makeWorkout(name: "Evening Run", date: today, workoutType: "Cardio", in: context)

        // Verify it appears
        let before = PlanService.fetchPlanSurface(for: today, context: context)
        XCTAssertEqual(before.count, 1)

        // Remove
        let item = PlanCardItem.loggedOnly(workout)
        _ = PlanService.removeFromPlan(item: item, scope: .thisOnly, context: context)
        let during = PlanService.fetchPlanSurface(for: today, context: context)
        XCTAssertTrue(during.isEmpty, "Should be hidden after removal")

        // Undo (flag flip)
        PlanService.setHiddenFromPlan(workout: workout, hidden: false, context: context)
        let after = PlanService.fetchPlanSurface(for: today, context: context)
        XCTAssertEqual(after.count, 1, "Should reappear after undo")
    }

    // MARK: - Workout Deletion Cascade

    /// Verifies that deleting a logged-only workout removes the plan dot and card immediately
    /// via the existing Workout Cascade (no special Plan code needed).
    func test_deletingLoggedOnlyWorkoutFromWorkoutsList_removesPlanDotAndCard_immediately() throws {
        let (_, context) = try TestFixtures.inMemoryContext()
        let today = TestFixtures.startOfDay(.now)

        let workout = TestFixtures.logWorkoutWithCascade(
            name: "Quick HIIT",
            date: today,
            workoutType: "HIIT",
            rpe: 9,
            durationMinutes: 20,
            in: context
        )

        // Verify it shows on plan
        let before = PlanService.fetchPlanSurface(for: today, context: context)
        XCTAssertEqual(before.count, 1)

        // Delete the workout via cascade
        TestFixtures.deleteWorkoutWithCascade(workout, in: context)

        // Plan surface should be empty
        let after = PlanService.fetchPlanSurface(for: today, context: context)
        XCTAssertTrue(after.isEmpty, "Deleted workout should no longer appear on plan")
    }
}
