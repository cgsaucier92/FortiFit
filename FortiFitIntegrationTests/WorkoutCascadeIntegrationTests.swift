//
//  WorkoutCascadeIntegrationTests.swift
//  FortiFitIntegrationTests
//
//  Integration tests for the shared Workout Cascade defined in
//  SERVICES.md § Deletion Cascading Behavior → Workout Cascade.
//
//  Each test uses an isolated in-memory SwiftData container via
//  TestFixtures.inMemoryContext(). Tests are named in the form
//  `test_situation_expectedOutcome` — the name alone should describe
//  the bullet from the cascade spec that's being verified.
//
//  These tests assume your services expose static or dependency-injected
//  methods like `WorkoutService.log(...)` that trigger the full cascade.
//  If your APIs differ, adjust the `When:` blocks — the `Given:` and
//  `Then:` blocks should remain stable.
//

import XCTest
import SwiftData
@testable import FortiFit

final class WorkoutCascadeIntegrationTests: XCTestCase {

    // MARK: - Log Workout → Cascade

    /// Cascade bullet: "Strength PR goals — recalculate currentValueKg
    /// for matching goals across remaining in-scope workouts"
    func test_loggingWorkoutWithMatchingExercise_updatesStrengthPRGoalCurrentValue() throws {
        // Given: a Strength PR goal for "Bench Press" with target 102 kg
        let (_, context) = try TestFixtures.inMemoryContext()
        let goal = TestFixtures.makeStrengthPRGoal(
            title: "Bench Press",
            targetKg: 102.0,
            in: context
        )

        // When: user logs a workout containing Bench Press @ 84 kg
        TestFixtures.logWorkoutWithCascade(
            name: "Push Day",
            workoutType: "Strength Training",
            exercises: [.init("Bench Press", sets: 4, reps: 8, weightKg: 84.0)],
            in: context
        )

        // Then: goal's currentValueKg reflects the lifted weight
        XCTAssertEqual(goal.currentValueKg, 84.0)
    }

    /// Cascade bullet: "GoalSnapshot records — for each affected goal,
    /// recompute snapshots on the affected date(s)"
    func test_loggingWorkoutWithMatchingExercise_writesGoalSnapshotForThatDay() throws {
        // Given: a Strength PR goal for "Bench Press"
        let (_, context) = try TestFixtures.inMemoryContext()
        let goal = TestFixtures.makeStrengthPRGoal(
            title: "Bench Press",
            targetKg: 102.0,
            in: context
        )

        // When: user logs a matching workout today
        TestFixtures.logWorkoutWithCascade(
            name: "Push Day",
            workoutType: "Strength Training",
            exercises: [.init("Bench Press", sets: 4, reps: 8, weightKg: 84.0)],
            in: context
        )

        // Then: exactly one snapshot exists for today with value 84
        let snapshots = GoalSnapshotService.fetchSnapshots(goalId: goal.id, days: 30, context: context)
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots.first?.value, 84.0)
    }

    // MARK: - Edit Workout → Cascade

    /// Cascade bullet (edit-specific): "Date changed — the cascade runs
    /// against both the old and new workout.date — Training Frequency hits
    /// both weeks; GoalSnapshot recomputes both the old-date and new-date snapshots"
    func test_editingWorkoutDate_recomputesSnapshotsOnBothOldAndNewDates() throws {
        // Given: a Strength PR goal and a workout logged 7 days ago
        let (_, context) = try TestFixtures.inMemoryContext()
        let goal = TestFixtures.makeStrengthPRGoal(title: "Bench Press", targetKg: 102.0, in: context)
        let workout = TestFixtures.logWorkoutWithCascade(
            name: "Old Session",
            date: TestFixtures.daysAgo(7),
            workoutType: "Strength Training",
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 80.0)],
            in: context
        )

        // Verify the starting snapshot exists on the old date
        let before = GoalSnapshotService.fetchSnapshots(goalId: goal.id, days: 30, context: context)
        XCTAssertEqual(before.count, 1)

        // When: user edits the workout to move it to today
        TestFixtures.updateWorkoutDate(workout, newDate: Date(), in: context)

        // Then: no snapshot remains on the OLD date (7 days ago)
        // And: a new snapshot exists on today with the workout's value
        let after = GoalSnapshotService.fetchSnapshots(goalId: goal.id, days: 30, context: context)
        XCTAssertEqual(after.count, 1)
        let todayStart = TestFixtures.startOfDay(Date())
        XCTAssertEqual(TestFixtures.startOfDay(after.first!.date), todayStart)
    }

    /// Cascade bullet (edit-specific): "Cosmetic-only change — lastModifiedDate
    /// still bumps, which re-scopes the workout against any goal resetDate and
    /// triggers full goal auto-update and snapshot recalc"
    func test_cosmeticEditOnly_bumpsLastModifiedDateAndTriggersGoalRescope() throws {
        // Given: a workout that predates a goal's resetDate (so initially out-of-scope)
        let (_, context) = try TestFixtures.inMemoryContext()
        let twoDaysAgo = TestFixtures.daysAgo(2)
        let workout = TestFixtures.makeWorkout(
            name: "Original",
            date: twoDaysAgo,
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 90.0)],
            in: context
        )
        // Manually set lastModifiedDate into the past so the reset actually scopes it out
        workout.lastModifiedDate = twoDaysAgo
        try context.save()

        // And: a Strength PR goal with resetDate = yesterday (so the old workout is out of scope)
        let goal = TestFixtures.makeStrengthPRGoal(
            title: "Bench Press",
            targetKg: 100.0,
            resetDate: TestFixtures.daysAgo(1),
            in: context
        )
        // Confirm the goal starts at 0 because the workout is out of scope
        GoalService.recalculateGoals(
            affectedExerciseNames: [goal.title],
            context: context
        )
        XCTAssertEqual(goal.currentValueKg, 0)

        // When: user makes a cosmetic-only edit (rename) to the old workout
        TestFixtures.updateWorkoutName(workout, newName: "Renamed", in: context)

        // Then: lastModifiedDate has been bumped to now
        XCTAssertNotNil(workout.lastModifiedDate)
        XCTAssertTrue(workout.lastModifiedDate! > TestFixtures.daysAgo(1))

        // And: the workout is now back in scope, so the goal picks up the 90 kg value
        XCTAssertEqual(goal.currentValueKg, 90.0)
    }

    // MARK: - Delete Workout → Cascade

    /// Cascade bullet: "Strength PR goals — No in-scope matches → 0"
    func test_deletingOnlyMatchingWorkout_resetsStrengthPRGoalToZero() throws {
        // Given: a goal and its only supporting workout
        let (_, context) = try TestFixtures.inMemoryContext()
        let goal = TestFixtures.makeStrengthPRGoal(title: "Squats", targetKg: 140.0, in: context)
        let workout = TestFixtures.logWorkoutWithCascade(
            name: "Leg Day",
            workoutType: "Strength Training",
            exercises: [.init("Squats", sets: 5, reps: 5, weightKg: 120.0)],
            in: context
        )
        XCTAssertEqual(goal.currentValueKg, 120.0)

        // When: user deletes the workout
        TestFixtures.deleteWorkoutWithCascade(workout, in: context)

        // Then: goal's currentValueKg resets to 0 (no matching in-scope workouts remain)
        XCTAssertEqual(goal.currentValueKg, 0.0)

        // And: the GoalSnapshot for that date is deleted
        let snapshots = GoalSnapshotService.fetchSnapshots(goalId: goal.id, days: 30, context: context)
        XCTAssertEqual(snapshots.count, 0)
    }

    /// Cascade bullet: "Workout Type card — If the last workout of a type is
    /// gone, remove the card and delete the WorkoutTypeOrder record"
    func test_deletingLastWorkoutOfType_removesWorkoutTypeOrderRecord() throws {
        // Given: a single Yoga workout (creates its WorkoutTypeOrder on save)
        let (_, context) = try TestFixtures.inMemoryContext()
        let yoga = TestFixtures.logWorkoutWithCascade(
            name: "Morning Flow",
            workoutType: "Yoga",
            in: context
        )
        let yogaOrders = WorkoutTypeOrderService.fetchAll(context: context)
        XCTAssertTrue(yogaOrders.contains { $0.workoutType == "Yoga" })

        // When: user deletes the only Yoga workout
        TestFixtures.deleteWorkoutWithCascade(yoga, in: context)

        // Then: the WorkoutTypeOrder record for Yoga is gone
        let remaining = WorkoutTypeOrderService.fetchAll(context: context)
        XCTAssertFalse(remaining.contains { $0.workoutType == "Yoga" })
    }

    /// Cascade bullet: "Scheduled workout linkage — if a deleted workout's ID
    /// matches any ScheduledWorkout.completedWorkoutId, set that field to nil
    /// and revert status to 'planned'"
    func test_deletingWorkoutLinkedToScheduledWorkout_revertsSlotToPlanned() throws {
        // Given: a scheduled workout marked completed, linked to a Workout
        let (_, context) = try TestFixtures.inMemoryContext()
        let template = TestFixtures.makeTemplate(
            name: "Push Day",
            exercises: [.init("Bench Press", sets: 4, reps: 8, weightKg: 80.0)],
            in: context
        )
        let scheduled = TestFixtures.makeScheduledWorkout(from: template, on: .now, in: context)
        PlanService.completeWorkout(
            scheduledWorkout: scheduled,
            date: Date(),
            rpe: 7,
            durationMinutes: 60,
            context: context
        )
        XCTAssertEqual(scheduled.status, "completed")
        XCTAssertNotNil(scheduled.completedWorkoutId)
        let completedWorkout = try XCTUnwrap(
            WorkoutService.fetchAll(context: context).first { $0.id == scheduled.completedWorkoutId }
        )

        // When: user deletes the completed Workout
        TestFixtures.deleteWorkoutWithCascade(completedWorkout, in: context)

        // Then: the ScheduledWorkout slot reverts to "planned" with completedWorkoutId cleared
        XCTAssertEqual(scheduled.status, "planned")
        XCTAssertNil(scheduled.completedWorkoutId)
    }

    // MARK: - Workout Type Deletion (Batch)

    /// Cascade bullet (type deletion): "All ExerciseSets across all deleted
    /// workouts are cascade-deleted from SwiftData"
    func test_deletingWorkoutType_removesAllWorkoutsAndExerciseSets() throws {
        // Given: 3 Strength workouts with multiple exercise sets each
        let (_, context) = try TestFixtures.inMemoryContext()
        for i in 1...3 {
            TestFixtures.logWorkoutWithCascade(
                name: "Session \(i)",
                date: TestFixtures.daysAgo(i),
                workoutType: "Strength Training",
                exercises: [
                    .init("Bench Press", sets: 3, reps: 8, weightKg: 80.0),
                    .init("Rows", sets: 3, reps: 10, weightKg: 60.0)
                ],
                in: context
            )
        }

        let workoutsBefore = try context.fetch(FetchDescriptor<Workout>())
        let setsBefore = try context.fetch(FetchDescriptor<ExerciseSet>())
        XCTAssertEqual(workoutsBefore.count, 3)
        XCTAssertEqual(setsBefore.count, 6)

        // When: user triggers workout type deletion for "Strength Training"
        TestFixtures.deleteAllForTypeWithCascade("Strength Training", in: context)

        // Then: all 3 workouts and all 6 exercise sets are gone
        let workoutsAfter = try context.fetch(FetchDescriptor<Workout>())
        let setsAfter = try context.fetch(FetchDescriptor<ExerciseSet>())
        XCTAssertEqual(workoutsAfter.count, 0)
        XCTAssertEqual(setsAfter.count, 0)

        // And: the WorkoutTypeOrder record for Strength Training is removed
        let orders = WorkoutTypeOrderService.fetchAll(context: context)
        XCTAssertFalse(orders.contains { $0.workoutType == "Strength Training" })
    }

    // MARK: - Reset Goal Progress → Snapshots Wiped

    /// Cascade bullet (Reset Goal Progress): "Wipe GoalSnapshot history —
    /// Delete all GoalSnapshot records for this goal"
    func test_resettingGoalProgress_wipesAllSnapshotsAndSetsResetDate() throws {
        // Given: a goal with several days of snapshot history
        let (_, context) = try TestFixtures.inMemoryContext()
        let goal = TestFixtures.makeStrengthPRGoal(title: "Deadlift", targetKg: 180.0, in: context)
        for i in 1...5 {
            TestFixtures.logWorkoutWithCascade(
                name: "Pull \(i)",
                date: TestFixtures.daysAgo(i),
                workoutType: "Strength Training",
                exercises: [.init("Deadlift", sets: 3, reps: 5, weightKg: 150.0 + Double(i))],
                in: context
            )
        }
        let before = GoalSnapshotService.fetchSnapshots(goalId: goal.id, days: 30, context: context)
        XCTAssertEqual(before.count, 5)
        XCTAssertNil(goal.resetDate)

        // When: user invokes Reset Goal Progress
        GoalService.resetGoalProgress(goal: goal, context: context)

        // Then: currentValueKg is 0, resetDate is set, lastCelebratedDate is nil
        XCTAssertEqual(goal.currentValueKg, 0.0)
        XCTAssertNotNil(goal.resetDate)
        XCTAssertNil(goal.lastCelebratedDate)

        // And: all snapshots are gone
        let after = GoalSnapshotService.fetchSnapshots(goalId: goal.id, days: 30, context: context)
        XCTAssertEqual(after.count, 0)
    }

    // MARK: - Speed and Distance Goals

    /// Cascade bullet: "Speed-target (both distance and duration set) — take
    /// the full workout (distance + duration together), never a composite"
    func test_speedTargetGoal_picksSingleBestWorkout_notCherryPickedComposite() throws {
        // Given: a speed-target goal: 5 km in 25 min
        let (_, context) = try TestFixtures.inMemoryContext()
        let goal = TestFixtures.makeSpeedDistanceGoal(
            title: "5K Run",
            targetDistanceKm: 5.0,
            targetDurationMinutes: 25,
            in: context
        )

        // When: user logs two Cardio workouts:
        //   - Run A: 5 km in 35 min (great distance, slow)
        //   - Run B: 3 km in 18 min (fast pace, short distance)
        // A cherry-picked composite (5km from A + 18min from B) would fake 100%.
        // The correct behavior is to take the full workout with highest overallProgress%.
        TestFixtures.logWorkoutWithCascade(
            name: "Run A",
            date: TestFixtures.daysAgo(2),
            workoutType: "Cardio",
            durationMinutes: 35,
            distanceKm: 5.0,
            in: context
        )
        TestFixtures.logWorkoutWithCascade(
            name: "Run B",
            date: TestFixtures.daysAgo(1),
            workoutType: "Cardio",
            durationMinutes: 18,
            distanceKm: 3.0,
            in: context
        )

        // Then: the goal stores values from a SINGLE workout, not a composite.
        // Run A: distance 100%, duration 25/35 ≈ 71%  → overall 71%
        // Run B: distance 60%,  duration 100% (beat time) → overall 60%
        // Winner: Run A. So currentDistanceKm = 5.0 and currentDurationMinutes = 35.
        XCTAssertEqual(goal.currentDistanceKm, 5.0)
        XCTAssertEqual(goal.currentDurationMinutes, 35.0)
    }
}
