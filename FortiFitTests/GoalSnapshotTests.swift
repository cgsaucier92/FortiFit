import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// Helper to create an in-memory SwiftData context for goal snapshot testing.
private func makeGoalContext() throws -> ModelContext {
    let schema = Schema([Workout.self, ExerciseSet.self, Goal.self, GoalSnapshot.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

// MARK: - GoalSnapshot Model Tests (Section 1)

struct GoalSnapshotModelTests {

    // SNAP-001
    @Test func snapshotInitializesWithCorrectProperties() {
        let goalId = UUID()
        let today = Calendar.current.startOfDay(for: Date())
        let snapshot = GoalSnapshot(goalId: goalId, date: today, value: 85.0)

        #expect(snapshot.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        #expect(snapshot.goalId == goalId)
        #expect(snapshot.value == 85.0)
    }

    // SNAP-002
    @Test func snapshotPersistsToSwiftData() throws {
        let context = try makeGoalContext()
        let goalId = UUID()
        let today = Calendar.current.startOfDay(for: Date())
        let snapshot = GoalSnapshot(goalId: goalId, date: today, value: 85.0)
        context.insert(snapshot)
        try context.save()

        let descriptor = FetchDescriptor<GoalSnapshot>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.goalId == goalId)
        #expect(results.first?.value == 85.0)
    }

    // SNAP-003
    @Test func snapshotDateStoredWithZeroedTime() throws {
        let context = try makeGoalContext()
        let calendar = Calendar.current
        // Create date with non-zero time
        var components = DateComponents()
        components.year = 2026; components.month = 4; components.day = 16
        components.hour = 15; components.minute = 45; components.second = 22
        let dateWithTime = calendar.date(from: components)!
        let zeroed = calendar.startOfDay(for: dateWithTime)

        let snapshot = GoalSnapshot(goalId: UUID(), date: zeroed, value: 50.0)
        context.insert(snapshot)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<GoalSnapshot>()).first!
        let fetchedComponents = calendar.dateComponents([.hour, .minute, .second], from: fetched.date)
        #expect(fetchedComponents.hour == 0)
        #expect(fetchedComponents.minute == 0)
        #expect(fetchedComponents.second == 0)
    }
}

// MARK: - GoalSnapshotService Tests (Section 2)

struct GoalSnapshotServiceTests {

    // SNAPSERV-001
    @Test func recomputeSnapshotCreatesNewWhenWorkoutExists() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        context.insert(goal)

        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let set = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 50)
        set.workout = workout
        workout.exerciseSets = [set]
        context.insert(workout)
        try context.save()

        GoalSnapshotService.recomputeSnapshot(goal: goal, date: workout.date, context: context)

        let snapshots = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapshots.count == 1)
        #expect(snapshots.first?.goalId == goal.id)
        #expect(snapshots.first?.value == 50.0)
    }

    // SNAPSERV-002
    @Test func recomputeSnapshotUpdatesExistingForSameDay() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        context.insert(goal)

        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let set = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 50)
        set.workout = workout
        workout.exerciseSets = [set]
        context.insert(workout)
        try context.save()

        GoalSnapshotService.recomputeSnapshot(goal: goal, date: workout.date, context: context)

        // Now add a heavier workout on the same day
        let workout2 = Workout(name: "Push Day pt2", workoutType: "Strength Training")
        let set2 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 75)
        set2.workout = workout2
        workout2.exerciseSets = [set2]
        context.insert(workout2)
        try context.save()

        GoalSnapshotService.recomputeSnapshot(goal: goal, date: workout.date, context: context)

        let snapshots = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapshots.count == 1)
        #expect(snapshots.first?.value == 75.0)
    }

    // SNAPSERV-003
    @Test func recomputeSnapshotCreatesSeparateForDifferentDays() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        context.insert(goal)

        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!

        let w1 = Workout(name: "Yesterday Push", date: yesterday, workoutType: "Strength Training")
        let s1 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 40)
        s1.workout = w1
        w1.exerciseSets = [s1]
        context.insert(w1)

        let w2 = Workout(name: "Today Push", workoutType: "Strength Training")
        let s2 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 60)
        s2.workout = w2
        w2.exerciseSets = [s2]
        context.insert(w2)
        try context.save()

        GoalSnapshotService.recomputeSnapshot(goal: goal, date: yesterday, context: context)
        GoalSnapshotService.recomputeSnapshot(goal: goal, date: Date(), context: context)

        let snapshots = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapshots.count == 2)
    }

    // SNAPSERV-004
    @Test func recomputeSnapshotCreatesSeparateForDifferentGoalsSameDay() throws {
        let context = try makeGoalContext()
        let goalA = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        let goalB = Goal(title: "Squat", goalType: "Strength PR", targetValueKg: 150, sortOrder: 1)
        context.insert(goalA)
        context.insert(goalB)

        let workout = Workout(name: "Full Body", workoutType: "Strength Training")
        let s1 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 50)
        let s2 = ExerciseSet(exerciseName: "Squat", sets: 3, reps: 5, weightKg: 80)
        s1.workout = workout
        s2.workout = workout
        workout.exerciseSets = [s1, s2]
        context.insert(workout)
        try context.save()

        GoalSnapshotService.recomputeSnapshot(goal: goalA, date: workout.date, context: context)
        GoalSnapshotService.recomputeSnapshot(goal: goalB, date: workout.date, context: context)

        let snapshots = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapshots.count == 2)
    }

    // SNAPSERV-005
    @Test func fetchSnapshotsReturnsWithinWindowSortedAscending() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", targetValueKg: 100, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let offsets = [-25, -15, -5, -1, 0]
        let values: [Double] = [10, 20, 30, 40, 50]

        for (offset, value) in zip(offsets, values) {
            let date = calendar.date(byAdding: .day, value: offset, to: today)!
            let snapshot = GoalSnapshot(goalId: goal.id, date: date, value: value)
            context.insert(snapshot)
        }
        try context.save()

        let results = GoalSnapshotService.fetchSnapshots(goalId: goal.id, days: 30, context: context)
        #expect(results.count == 5)
        #expect(results.map(\.value) == [10, 20, 30, 40, 50])
    }

    // SNAPSERV-006
    @Test func fetchSnapshotsExcludesOutsideWindow() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", targetValueKg: 100, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let offsets = [-45, -31, -30, -5, 0]

        for offset in offsets {
            let date = calendar.date(byAdding: .day, value: offset, to: today)!
            let snapshot = GoalSnapshot(goalId: goal.id, date: date, value: Double(-offset))
            context.insert(snapshot)
        }
        try context.save()

        let results = GoalSnapshotService.fetchSnapshots(goalId: goal.id, days: 30, context: context)
        #expect(results.count == 3)
    }

    // SNAPSERV-007
    @Test func fetchSnapshotsReturnsEmptyForNoSnapshots() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", targetValueKg: 100, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let results = GoalSnapshotService.fetchSnapshots(goalId: goal.id, days: 30, context: context)
        #expect(results.isEmpty)
    }

    // SNAPSERV-008
    @Test func fetchSnapshotsOnlyReturnsRequestedGoal() throws {
        let context = try makeGoalContext()
        let goalA = Goal(title: "Bench Press", targetValueKg: 100, sortOrder: 0)
        let goalB = Goal(title: "Squat", targetValueKg: 150, sortOrder: 1)
        context.insert(goalA)
        context.insert(goalB)
        try context.save()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for i in 0..<3 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            context.insert(GoalSnapshot(goalId: goalA.id, date: date, value: Double(i)))
        }
        for i in 0..<2 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            context.insert(GoalSnapshot(goalId: goalB.id, date: date, value: Double(i)))
        }
        try context.save()

        let results = GoalSnapshotService.fetchSnapshots(goalId: goalA.id, days: 30, context: context)
        #expect(results.count == 3)
        #expect(results.allSatisfy { $0.goalId == goalA.id })
    }

    // SNAPSERV-009
    @Test func deleteSnapshotsRemovesAll() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", targetValueKg: 100, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for i in 0..<10 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            context.insert(GoalSnapshot(goalId: goal.id, date: date, value: Double(i)))
        }
        try context.save()

        GoalSnapshotService.deleteSnapshots(goalId: goal.id, context: context)

        let remaining = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(remaining.isEmpty)
    }

    // SNAPSERV-010
    @Test func deleteSnapshotsDoesNotAffectOtherGoals() throws {
        let context = try makeGoalContext()
        let goalA = Goal(title: "Bench Press", targetValueKg: 100, sortOrder: 0)
        let goalB = Goal(title: "Squat", targetValueKg: 150, sortOrder: 1)
        context.insert(goalA)
        context.insert(goalB)
        try context.save()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for i in 0..<5 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            context.insert(GoalSnapshot(goalId: goalA.id, date: date, value: Double(i)))
            context.insert(GoalSnapshot(goalId: goalB.id, date: date, value: Double(i)))
        }
        try context.save()

        GoalSnapshotService.deleteSnapshots(goalId: goalA.id, context: context)

        let remaining = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(remaining.count == 5)
        #expect(remaining.allSatisfy { $0.goalId == goalB.id })
    }

    // SNAPSERV-011 — Workout edit with unchanged date: snapshot on workout.date recomputes
    @Test func workoutEditUnchangedDateRecomputesSnapshot() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        context.insert(goal)

        let w = Workout(name: "Push Day", workoutType: "Strength Training")
        let s = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 60)
        s.workout = w
        w.exerciseSets = [s]
        context.insert(w)
        try context.save()

        GoalSnapshotService.recomputeSnapshot(goal: goal, date: w.date, context: context)
        let snap1 = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snap1.first?.value == 60.0)

        // Edit workout weight (same date)
        let newSet = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 80)
        WorkoutService.updateWorkout(
            w, name: "Push Day", date: w.date, time: nil, rpe: nil,
            durationMinutes: nil, distanceKm: nil, newExerciseSets: [newSet]
        )

        GoalSnapshotService.recomputeSnapshot(goal: goal, date: w.date, context: context)
        let snap2 = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snap2.count == 1)
        #expect(snap2.first?.value == 80.0)
    }

    // SNAPSERV-012 — Workout edit with date change: snapshots on BOTH old and new date recompute
    @Test func workoutEditDateChangeRecomputesBothDates() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        context.insert(goal)

        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!

        let w = Workout(name: "Push Day", date: yesterday, workoutType: "Strength Training")
        let s = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 70)
        s.workout = w
        w.exerciseSets = [s]
        context.insert(w)
        try context.save()

        GoalSnapshotService.recomputeSnapshot(goal: goal, date: yesterday, context: context)
        let snapBefore = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapBefore.count == 1)

        // Move workout to today
        let newSet = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 70)
        let (_, priorDate) = WorkoutService.updateWorkout(
            w, name: "Push Day", date: Date(), time: nil, rpe: nil,
            durationMinutes: nil, distanceKm: nil, newExerciseSets: [newSet]
        )

        // Recompute both old and new date
        GoalSnapshotService.recomputeSnapshot(goal: goal, date: Date(), context: context)
        if let prior = priorDate {
            GoalSnapshotService.recomputeSnapshot(goal: goal, date: prior, context: context)
        }

        let snapAfter = try context.fetch(FetchDescriptor<GoalSnapshot>())
        // Old date snapshot should be deleted (no more workouts on that date)
        // New date snapshot should exist
        let todaySnaps = snapAfter.filter { calendar.isDateInToday($0.date) }
        let yesterdaySnaps = snapAfter.filter { calendar.isDate($0.date, inSameDayAs: yesterday) }
        #expect(todaySnaps.count == 1)
        #expect(yesterdaySnaps.count == 0)
    }

    // SNAPSERV-013 — Workout deletion: last supporting workout → snapshot deleted
    @Test func workoutDeletionLastSupportingRemovesSnapshot() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        context.insert(goal)

        let w = Workout(name: "Push Day", workoutType: "Strength Training")
        let s = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 65)
        s.workout = w
        w.exerciseSets = [s]
        context.insert(w)
        try context.save()

        GoalSnapshotService.recomputeSnapshot(goal: goal, date: w.date, context: context)
        #expect(try context.fetch(FetchDescriptor<GoalSnapshot>()).count == 1)

        let deletedDate = w.date
        WorkoutService.deleteWorkout(w, context: context)

        // Recompute snapshot for the deleted date — should delete since no supporting data
        GoalSnapshotService.recomputeSnapshot(goal: goal, date: deletedDate, context: context)

        let remaining = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(remaining.isEmpty)
    }

    // SNAPSERV-014 — Workout deletion: other matching workouts remain → snapshot recomputes to new best
    @Test func workoutDeletionOtherWorkoutsRemainRecomputes() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        context.insert(goal)

        let w1 = Workout(name: "Morning Push", workoutType: "Strength Training")
        let s1 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 80)
        s1.workout = w1
        w1.exerciseSets = [s1]
        context.insert(w1)

        let w2 = Workout(name: "Evening Push", workoutType: "Strength Training")
        let s2 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 60)
        s2.workout = w2
        w2.exerciseSets = [s2]
        context.insert(w2)
        try context.save()

        GoalSnapshotService.recomputeSnapshot(goal: goal, date: Date(), context: context)
        let snap1 = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snap1.first?.value == 80.0)

        // Delete the heavier workout
        let deletedDate = w1.date
        WorkoutService.deleteWorkout(w1, context: context)
        GoalSnapshotService.recomputeSnapshot(goal: goal, date: deletedDate, context: context)

        let snap2 = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snap2.count == 1)
        #expect(snap2.first?.value == 60.0)
    }

    // SNAPSERV-015 — rebuildSnapshots drops all and rebuilds from in-scope matching workouts
    @Test func rebuildSnapshotsDropsAndRebuilds() throws {
        let context = try makeGoalContext()
        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        context.insert(goal)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Add stale snapshots
        context.insert(GoalSnapshot(goalId: goal.id, date: today, value: 999))
        context.insert(GoalSnapshot(goalId: goal.id, date: yesterday, value: 888))

        // Add workouts
        let w1 = Workout(name: "Yesterday Push", date: yesterday, workoutType: "Strength Training")
        let s1 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 55)
        s1.workout = w1
        w1.exerciseSets = [s1]
        context.insert(w1)

        let w2 = Workout(name: "Today Push", workoutType: "Strength Training")
        let s2 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 65)
        s2.workout = w2
        w2.exerciseSets = [s2]
        context.insert(w2)
        try context.save()

        GoalSnapshotService.rebuildSnapshots(goal: goal, context: context)

        let snapshots = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapshots.count == 2)
        // Stale values should be gone; replaced with correct values
        let yesterdaySnap = snapshots.first { calendar.isDate($0.date, inSameDayAs: yesterday) }
        let todaySnap = snapshots.first { calendar.isDate($0.date, inSameDayAs: today) }
        #expect(yesterdaySnap?.value == 55.0)
        #expect(todaySnap?.value == 65.0)
    }

    // SNAPSERV-016 — rebuildSnapshots is invoked when goal definition edit clears resetDate
    @Test func rebuildSnapshotsOnGoalDefinitionEditClearingResetDate() throws {
        let context = try makeGoalContext()
        let calendar = Calendar.current
        let now = Date()
        let resetDate = calendar.date(byAdding: .day, value: -2, to: now)!

        let goal = Goal(title: "Bench Press", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        goal.resetDate = resetDate
        context.insert(goal)

        // Add a workout from before reset (out-of-scope initially)
        let oldDate = calendar.date(byAdding: .day, value: -5, to: now)!
        let w = Workout(name: "Old Workout", date: oldDate, workoutType: "Strength Training")
        w.lastModifiedDate = oldDate
        let s = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 75)
        s.workout = w
        w.exerciseSets = [s]
        context.insert(w)
        try context.save()

        // No snapshots should exist yet (workout was out of scope)
        let snapsBefore = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapsBefore.isEmpty)

        // Edit goal definition (clears resetDate and triggers rebuildSnapshots)
        GoalService.handleGoalDefinitionEdit(goal: goal, context: context)

        #expect(goal.resetDate == nil)
        let snapsAfter = try context.fetch(FetchDescriptor<GoalSnapshot>())
        // Now the old workout should have generated a snapshot
        #expect(snapsAfter.count >= 1)
        #expect(snapsAfter.contains { $0.value == 75.0 })
    }

    // SNAPSERV-017 — No historical backfill: creating a new goal does not generate snapshots for past dates
    @Test func creatingNewGoalDoesNotBackfillSnapshots() throws {
        let context = try makeGoalContext()

        // Add some historical workouts first
        let calendar = Calendar.current
        for i in 1...5 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let w = Workout(name: "Day \(i)", date: date, workoutType: "Strength Training")
            let s = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: Double(i * 10))
            s.workout = w
            w.exerciseSets = [s]
            context.insert(w)
        }
        try context.save()

        // Now create a new goal
        GoalService.createExercisePRGoal(title: "Bench Press", targetValueKg: 100, context: context)

        // No snapshots should exist — creating a goal doesn't generate historical snapshots
        let snapshots = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapshots.isEmpty)
    }

    // SNAPSERV-018 — Workout type deletion: bulk snapshot recompute; orphaned snapshots deleted
    @Test func workoutTypeDeletionBulkSnapshotRecompute() throws {
        let context = try makeGoalContext()
        let goal = Goal(
            title: "10K Run", goalType: "Speed and Distance",
            targetDistanceKm: 10, linkedWorkoutType: "Cardio", sortOrder: 0
        )
        context.insert(goal)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let w1 = Workout(name: "Run 1", date: yesterday, workoutType: "Cardio", distanceKm: 5.0)
        context.insert(w1)
        let w2 = Workout(name: "Run 2", workoutType: "Cardio", distanceKm: 7.0)
        context.insert(w2)
        try context.save()

        GoalSnapshotService.recomputeSnapshot(goal: goal, date: yesterday, context: context)
        GoalSnapshotService.recomputeSnapshot(goal: goal, date: today, context: context)
        let snapsBefore = try context.fetch(FetchDescriptor<GoalSnapshot>())
        #expect(snapsBefore.count == 2)

        // Delete all Cardio workouts
        WorkoutService.deleteAllForType("Cardio", context: context)

        // Recompute snapshots on both dates
        GoalSnapshotService.recomputeSnapshot(goal: goal, date: yesterday, context: context)
        GoalSnapshotService.recomputeSnapshot(goal: goal, date: today, context: context)

        let snapsAfter = try context.fetch(FetchDescriptor<GoalSnapshot>())
        // All snapshots should be deleted since no supporting workouts exist
        #expect(snapsAfter.isEmpty)
    }
}
