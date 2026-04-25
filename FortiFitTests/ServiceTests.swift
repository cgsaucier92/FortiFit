import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// Helper to create an in-memory SwiftData context for testing.
private func makeTestContext() throws -> ModelContext {
    let schema = Schema([Workout.self, ExerciseSet.self, Goal.self, GoalSnapshot.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

// MARK: - WorkoutService Tests

struct WorkoutServiceTests {

    @Test func logWorkoutPersists() throws {
        let context = try makeTestContext()
        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        WorkoutService.logWorkout(workout, context: context)

        let results = WorkoutService.fetchAll(context: context)
        #expect(results.count == 1)
        #expect(results.first?.name == "Push Day")
    }

    @Test func fetchAllReturnsNewestFirst() throws {
        let context = try makeTestContext()
        let older = Workout(name: "Monday", date: Date().addingTimeInterval(-86400 * 3), workoutType: "Strength Training")
        let newer = Workout(name: "Thursday", date: Date(), workoutType: "Strength Training")
        WorkoutService.logWorkout(older, context: context)
        WorkoutService.logWorkout(newer, context: context)

        let results = WorkoutService.fetchAll(context: context)
        #expect(results.count == 2)
        #expect(results[0].name == "Thursday")
        #expect(results[1].name == "Monday")
    }

    @Test func updateNoteOnWorkout() throws {
        let context = try makeTestContext()
        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        WorkoutService.logWorkout(workout, context: context)

        WorkoutService.updateNote(workout, note: "Felt strong today", context: context)
        let results = WorkoutService.fetchAll(context: context)
        #expect(results.first?.note == "Felt strong today")
    }

    @Test func deleteWorkoutCascadesExerciseSets() throws {
        let context = try makeTestContext()
        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let exerciseSet = ExerciseSet(exerciseName: "Bench Press", sets: 4, reps: 8, weightKg: 80, sortOrder: 0)
        workout.exerciseSets.append(exerciseSet)
        WorkoutService.logWorkout(workout, context: context)

        let exerciseNames = WorkoutService.deleteWorkout(workout, context: context)
        #expect(exerciseNames.contains("Bench Press"))

        let workouts = WorkoutService.fetchAll(context: context)
        #expect(workouts.isEmpty)

        let setDescriptor = FetchDescriptor<ExerciseSet>()
        let remainingSets = try context.fetch(setDescriptor)
        #expect(remainingSets.isEmpty)
    }

    @Test func prTimelineComputesCorrectly() throws {
        let context = try makeTestContext()

        // First workout: bench 80kg
        let w1 = Workout(name: "Day 1", date: Date().addingTimeInterval(-86400 * 7), workoutType: "Strength Training")
        let s1 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 8, weightKg: 80, sortOrder: 0)
        w1.exerciseSets.append(s1)
        WorkoutService.logWorkout(w1, context: context)

        // Second workout: bench 85kg (PR)
        let w2 = Workout(name: "Day 2", date: Date().addingTimeInterval(-86400 * 3), workoutType: "Strength Training")
        let s2 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 8, weightKg: 85, sortOrder: 0)
        w2.exerciseSets.append(s2)
        WorkoutService.logWorkout(w2, context: context)

        // Third workout: bench 82kg (not a PR)
        let w3 = Workout(name: "Day 3", date: Date(), workoutType: "Strength Training")
        let s3 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 8, weightKg: 82, sortOrder: 0)
        w3.exerciseSets.append(s3)
        WorkoutService.logWorkout(w3, context: context)

        let timeline = WorkoutService.computePRTimeline(context: context)
        // Only one PR: 80→85
        #expect(timeline.count == 1)
        #expect(timeline[0].newValue == 85)
        #expect(timeline[0].previousValue == 80)
    }
}

// MARK: - GoalService Tests

struct GoalServiceTests {

    @Test func completionPercentageCalculation() {
        let goal = Goal(title: "Bench", targetValueKg: 100, currentValueKg: 75, sortOrder: 0)
        let pct = GoalService.completionPercentage(for: goal)
        #expect(pct == 75.0)
    }

    @Test func goalDetectsCompletion() {
        let goal = Goal(title: "Bench", targetValueKg: 100, currentValueKg: 100, sortOrder: 0)
        #expect(GoalService.isComplete(goal))
    }

    @Test func goalNotCompleteUnder100() {
        let goal = Goal(title: "Bench", targetValueKg: 100, currentValueKg: 99, sortOrder: 0)
        #expect(!GoalService.isComplete(goal))
    }

    @Test func reorderGoalsPersists() throws {
        let context = try makeTestContext()
        let g1 = Goal(title: "Bench", targetValueKg: 100, sortOrder: 0)
        let g2 = Goal(title: "Squat", targetValueKg: 130, sortOrder: 1)
        context.insert(g1)
        context.insert(g2)
        try context.save()

        GoalService.reorder(goals: [g2, g1], context: context)
        let fetched = GoalService.fetchAll(context: context)
        #expect(fetched[0].title == "Squat")
        #expect(fetched[1].title == "Bench")
    }

    @Test func deleteGoalReindexesSortOrder() throws {
        let context = try makeTestContext()
        let g1 = Goal(title: "Bench", targetValueKg: 100, sortOrder: 0)
        let g2 = Goal(title: "Squat", targetValueKg: 130, sortOrder: 1)
        let g3 = Goal(title: "Deadlift", targetValueKg: 180, sortOrder: 2)
        context.insert(g1)
        context.insert(g2)
        context.insert(g3)
        try context.save()

        GoalService.deleteGoal(g2, context: context)
        let remaining = GoalService.fetchAll(context: context)
        #expect(remaining.count == 2)
        #expect(remaining[0].sortOrder == 0)
        #expect(remaining[1].sortOrder == 1)
    }

    @Test func autoUpdateGoalAfterWorkoutSave() throws {
        let context = try makeTestContext()
        let goal = Goal(title: "Bench Press", targetValueKg: 100, currentValueKg: 80, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let exerciseSet = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 90, sortOrder: 0)
        workout.exerciseSets.append(exerciseSet)
        WorkoutService.logWorkout(workout, context: context)

        GoalService.recalculateGoals(
            affectedExerciseNames: ["Bench Press"],
            affectedWorkoutTypes: ["Strength Training"],
            workout: workout,
            context: context
        )
        #expect(goal.currentValueKg == 90)
    }

    @Test func autoUpdateIsCaseInsensitive() throws {
        let context = try makeTestContext()
        let goal = Goal(title: "Bench Press", targetValueKg: 100, currentValueKg: 80, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let exerciseSet = ExerciseSet(exerciseName: "bench press", sets: 3, reps: 5, weightKg: 95, sortOrder: 0)
        workout.exerciseSets.append(exerciseSet)
        WorkoutService.logWorkout(workout, context: context)

        GoalService.recalculateGoals(
            affectedExerciseNames: ["bench press"],
            affectedWorkoutTypes: ["Strength Training"],
            workout: workout,
            context: context
        )
        #expect(goal.currentValueKg == 95)
    }

    @Test func recalculateAfterDeletionResetsToZeroIfNoMatch() throws {
        let context = try makeTestContext()
        let goal = Goal(title: "Bench Press", targetValueKg: 100, currentValueKg: 90, sortOrder: 0)
        context.insert(goal)

        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let exerciseSet = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 90, sortOrder: 0)
        workout.exerciseSets.append(exerciseSet)
        WorkoutService.logWorkout(workout, context: context)

        // Delete the only workout
        let names = WorkoutService.deleteWorkout(workout, context: context)
        GoalService.recalculateGoals(affectedExerciseNames: names, context: context)

        #expect(goal.currentValueKg == 0)
    }

    @Test func recalculateAfterDeletionFindsHighestRemaining() throws {
        let context = try makeTestContext()
        let goal = Goal(title: "Bench Press", targetValueKg: 100, currentValueKg: 90, sortOrder: 0)
        context.insert(goal)

        // Workout 1: bench 85kg
        let w1 = Workout(name: "Day 1", date: Date().addingTimeInterval(-86400), workoutType: "Strength Training")
        let s1 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 85, sortOrder: 0)
        w1.exerciseSets.append(s1)
        WorkoutService.logWorkout(w1, context: context)

        // Workout 2: bench 90kg (this will be deleted)
        let w2 = Workout(name: "Day 2", date: Date(), workoutType: "Strength Training")
        let s2 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 90, sortOrder: 0)
        w2.exerciseSets.append(s2)
        WorkoutService.logWorkout(w2, context: context)

        let names = WorkoutService.deleteWorkout(w2, context: context)
        GoalService.recalculateGoals(affectedExerciseNames: names, context: context)

        // Should recalculate to 85 (the remaining workout)
        #expect(goal.currentValueKg == 85)
    }
}

// MARK: - ExerciseSet Sort Order Tests

struct ExerciseSetSortOrderTests {

    @Test func saveWorkoutAssignsGlobalSortOrder() throws {
        let context = try makeTestContext()
        let vm = WorkoutViewModel()
        vm.workoutName = "Push Day"
        vm.workoutType = "Strength Training"

        // Exercise 1: Bench Press with 2 rows
        let bench = ExerciseFormEntry()
        bench.name = "Bench Press"
        let benchRow1 = SetRow(); benchRow1.sets = "4"; benchRow1.reps = "8"; benchRow1.weight = "80"
        let benchRow2 = SetRow(); benchRow2.sets = "3"; benchRow2.reps = "10"; benchRow2.weight = "70"
        bench.rows = [benchRow1, benchRow2]

        // Exercise 2: Overhead Press with 2 rows
        let ohp = ExerciseFormEntry()
        ohp.name = "Overhead Press"
        let ohpRow1 = SetRow(); ohpRow1.sets = "3"; ohpRow1.reps = "8"; ohpRow1.weight = "50"
        let ohpRow2 = SetRow(); ohpRow2.sets = "2"; ohpRow2.reps = "6"; ohpRow2.weight = "55"
        ohp.rows = [ohpRow1, ohpRow2]

        // Exercise 3: Lateral Raise with 1 row
        let lateral = ExerciseFormEntry()
        lateral.name = "Lateral Raise"
        let lateralRow1 = SetRow(); lateralRow1.sets = "3"; lateralRow1.reps = "15"; lateralRow1.weight = "10"
        lateral.rows = [lateralRow1]

        vm.exercises = [bench, ohp, lateral]
        vm.saveWorkout(context: context)

        let workouts = WorkoutService.fetchAll(context: context)
        #expect(workouts.count == 1)

        let sorted = workouts[0].exerciseSets.sorted { $0.sortOrder < $1.sortOrder }
        #expect(sorted.count == 5)

        // Verify every sortOrder is unique and sequential
        for (i, set) in sorted.enumerated() {
            #expect(set.sortOrder == i)
        }

        // Verify exercise order matches input order
        #expect(sorted[0].exerciseName == "Bench Press")
        #expect(sorted[1].exerciseName == "Bench Press")
        #expect(sorted[2].exerciseName == "Overhead Press")
        #expect(sorted[3].exerciseName == "Overhead Press")
        #expect(sorted[4].exerciseName == "Lateral Raise")

        // Verify row data within each exercise preserves input order (reps only, weight depends on unit settings)
        #expect(sorted[0].reps == 8)
        #expect(sorted[1].reps == 10)
        #expect(sorted[2].reps == 8)
        #expect(sorted[3].reps == 6)
        #expect(sorted[4].reps == 15)
    }

    @Test func editWorkoutPreservesGlobalSortOrder() throws {
        let context = try makeTestContext()

        // Create initial workout with 3 exercises
        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let s0 = ExerciseSet(exerciseName: "Bench Press", sets: 4, reps: 8, weightKg: 80, sortOrder: 0)
        let s1 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 10, weightKg: 70, sortOrder: 1)
        let s2 = ExerciseSet(exerciseName: "Overhead Press", sets: 3, reps: 8, weightKg: 50, sortOrder: 2)
        workout.exerciseSets = [s0, s1, s2]
        WorkoutService.logWorkout(workout, context: context)

        // Populate VM from saved workout and re-save (simulates edit)
        let vm = WorkoutViewModel()
        vm.populateForm(from: workout)

        // Verify form was populated in correct order
        #expect(vm.exercises.count == 2)
        #expect(vm.exercises[0].name == "Bench Press")
        #expect(vm.exercises[0].rows.count == 2)
        #expect(vm.exercises[1].name == "Overhead Press")
        #expect(vm.exercises[1].rows.count == 1)

        vm.saveEditedWorkout(context: context)

        let updated = WorkoutService.fetchAll(context: context).first!
        let sorted = updated.exerciseSets.sorted { $0.sortOrder < $1.sortOrder }
        #expect(sorted.count == 3)

        // All sortOrders must be unique and sequential
        for (i, set) in sorted.enumerated() {
            #expect(set.sortOrder == i)
        }

        // Exercise order preserved
        #expect(sorted[0].exerciseName == "Bench Press")
        #expect(sorted[1].exerciseName == "Bench Press")
        #expect(sorted[2].exerciseName == "Overhead Press")
    }

    @Test func populateFormPreservesRowOrderFromSortOrder() throws {
        let context = try makeTestContext()

        // Create workout with specific row ordering via sortOrder
        let workout = Workout(name: "Leg Day", workoutType: "Strength Training")
        let s0 = ExerciseSet(exerciseName: "Squat", sets: 5, reps: 5, weightKg: 100, sortOrder: 0)
        let s1 = ExerciseSet(exerciseName: "Squat", sets: 3, reps: 8, weightKg: 80, sortOrder: 1)
        let s2 = ExerciseSet(exerciseName: "Squat", sets: 2, reps: 12, weightKg: 60, sortOrder: 2)
        let s3 = ExerciseSet(exerciseName: "Leg Press", sets: 4, reps: 10, weightKg: 150, sortOrder: 3)
        workout.exerciseSets = [s0, s1, s2, s3]
        WorkoutService.logWorkout(workout, context: context)

        let vm = WorkoutViewModel()
        vm.populateForm(from: workout)

        #expect(vm.exercises.count == 2)

        // Squat rows should be in weight-descending order (100, 80, 60)
        let squatRows = vm.exercises[0].rows
        #expect(squatRows.count == 3)
        #expect(squatRows[0].reps == "5")
        #expect(squatRows[1].reps == "8")
        #expect(squatRows[2].reps == "12")

        // Leg Press
        #expect(vm.exercises[1].name == "Leg Press")
        #expect(vm.exercises[1].rows.count == 1)
    }
}

// MARK: - Helper: create a date for a specific weekday offset from a given Monday
private func mondayAt(_ weeksAgo: Int) -> Date {
    var calendar = Calendar(identifier: .iso8601)
    calendar.firstWeekday = 2
    let now = Date()
    let currentWeekStart = now.startOfWeek
    return calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: currentWeekStart)!
}

/// Creates N workouts spread across a given week (starting from weekMonday).
private func createWorkouts(count: Int, inWeekStarting weekMonday: Date, context: ModelContext) {
    for i in 0..<count {
        let date = Calendar.current.date(byAdding: .day, value: i % 7, to: weekMonday)!
        let w = Workout(name: "W-\(i)", date: date, workoutType: "Strength Training")
        WorkoutService.logWorkout(w, context: context)
    }
}

// MARK: - StreakService Tests

@Suite(.serialized)
struct StreakServiceTests {

    // TEST.md line 177: returns currentStreak = 0 and tier "Dormant" when no workouts exist
    @Test func noWorkoutsReturnsDormant() throws {
        let context = try makeTestContext()
        let original = UserSettings.shared.targetWorkoutsPerWeek
        let originalLongest = UserSettings.shared.longestStreak
        defer {
            UserSettings.shared.targetWorkoutsPerWeek = original
            UserSettings.shared.longestStreak = originalLongest
        }
        UserSettings.shared.targetWorkoutsPerWeek = 3

        let result = StreakService.calculateStreak(context: context)
        #expect(result.streak == 0)
        #expect(result.tier == .dormant)
    }

    // TEST.md line 178: returns currentStreak = 0 and tier "Dormant" when target is 0
    @Test func targetZeroReturnsDormant() throws {
        let context = try makeTestContext()
        let original = UserSettings.shared.targetWorkoutsPerWeek
        let originalLongest = UserSettings.shared.longestStreak
        defer {
            UserSettings.shared.targetWorkoutsPerWeek = original
            UserSettings.shared.longestStreak = originalLongest
        }
        UserSettings.shared.targetWorkoutsPerWeek = 0

        // Log some workouts anyway
        createWorkouts(count: 5, inWeekStarting: mondayAt(1), context: context)

        let result = StreakService.calculateStreak(context: context)
        #expect(result.streak == 0)
        #expect(result.tier == .dormant)
    }

    // TEST.md line 179: 1 completed week returns streak=1 and tier "Building"
    @Test func oneCompletedWeekReturnsBuilding() throws {
        let context = try makeTestContext()
        let original = UserSettings.shared.targetWorkoutsPerWeek
        let originalLongest = UserSettings.shared.longestStreak
        defer {
            UserSettings.shared.targetWorkoutsPerWeek = original
            UserSettings.shared.longestStreak = originalLongest
        }
        UserSettings.shared.targetWorkoutsPerWeek = 3

        createWorkouts(count: 3, inWeekStarting: mondayAt(1), context: context)

        let result = StreakService.calculateStreak(context: context)
        #expect(result.streak == 1)
        #expect(result.tier == .building)
    }

    // TEST.md line 180: 3 consecutive completed weeks returns streak=3 and tier "Building"
    @Test func threeWeeksReturnsBuilding() throws {
        let context = try makeTestContext()
        let original = UserSettings.shared.targetWorkoutsPerWeek
        let originalLongest = UserSettings.shared.longestStreak
        defer {
            UserSettings.shared.targetWorkoutsPerWeek = original
            UserSettings.shared.longestStreak = originalLongest
        }
        UserSettings.shared.targetWorkoutsPerWeek = 2

        for w in 1...3 {
            createWorkouts(count: 2, inWeekStarting: mondayAt(w), context: context)
        }

        let result = StreakService.calculateStreak(context: context)
        #expect(result.streak == 3)
        #expect(result.tier == .building)
    }

    // TEST.md line 181: 4 consecutive completed weeks returns streak=4 and tier "Committed"
    @Test func fourWeeksReturnsCommitted() throws {
        let context = try makeTestContext()
        let original = UserSettings.shared.targetWorkoutsPerWeek
        let originalLongest = UserSettings.shared.longestStreak
        defer {
            UserSettings.shared.targetWorkoutsPerWeek = original
            UserSettings.shared.longestStreak = originalLongest
        }
        UserSettings.shared.targetWorkoutsPerWeek = 2

        for w in 1...4 {
            createWorkouts(count: 2, inWeekStarting: mondayAt(w), context: context)
        }

        let result = StreakService.calculateStreak(context: context)
        #expect(result.streak == 4)
        #expect(result.tier == .committed)
    }

    // TEST.md line 182: 7 consecutive completed weeks returns streak=7 and tier "Committed"
    @Test func sevenWeeksReturnsCommitted() throws {
        let context = try makeTestContext()
        let original = UserSettings.shared.targetWorkoutsPerWeek
        let originalLongest = UserSettings.shared.longestStreak
        defer {
            UserSettings.shared.targetWorkoutsPerWeek = original
            UserSettings.shared.longestStreak = originalLongest
        }
        UserSettings.shared.targetWorkoutsPerWeek = 1

        for w in 1...7 {
            createWorkouts(count: 1, inWeekStarting: mondayAt(w), context: context)
        }

        let result = StreakService.calculateStreak(context: context)
        #expect(result.streak == 7)
        #expect(result.tier == .committed)
    }

    // TEST.md line 183: 8 consecutive completed weeks returns streak=8 and tier "Elite"
    @Test func eightWeeksReturnsElite() throws {
        let context = try makeTestContext()
        let original = UserSettings.shared.targetWorkoutsPerWeek
        let originalLongest = UserSettings.shared.longestStreak
        defer {
            UserSettings.shared.targetWorkoutsPerWeek = original
            UserSettings.shared.longestStreak = originalLongest
        }
        UserSettings.shared.targetWorkoutsPerWeek = 1

        for w in 1...8 {
            createWorkouts(count: 1, inWeekStarting: mondayAt(w), context: context)
        }

        let result = StreakService.calculateStreak(context: context)
        #expect(result.streak == 8)
        #expect(result.tier == .elite)
    }

    // TEST.md line 184: missed week between two completed weeks resets streak
    @Test func missedWeekResetsStreak() throws {
        let context = try makeTestContext()
        let original = UserSettings.shared.targetWorkoutsPerWeek
        let originalLongest = UserSettings.shared.longestStreak
        defer {
            UserSettings.shared.targetWorkoutsPerWeek = original
            UserSettings.shared.longestStreak = originalLongest
        }
        UserSettings.shared.targetWorkoutsPerWeek = 2

        // Weeks 3,2 completed; week 1 missed (gap); should count only from most recent consecutive
        // Actually: week 1 (most recent completed) = streak continues; we need gap BEFORE recent streak
        // Completed: weeks 2 and 1; missed: week 3; completed: weeks 5 and 4
        // Walking back from week 1: week 1 ✓, week 2 ✓, week 3 ✗ → streak = 2
        createWorkouts(count: 2, inWeekStarting: mondayAt(1), context: context)
        createWorkouts(count: 2, inWeekStarting: mondayAt(2), context: context)
        // week 3 = gap (no workouts)
        createWorkouts(count: 2, inWeekStarting: mondayAt(4), context: context)
        createWorkouts(count: 2, inWeekStarting: mondayAt(5), context: context)

        let result = StreakService.calculateStreak(context: context)
        #expect(result.streak == 2)
    }

    // TEST.md line 185: 5 completed + 1 missed + 2 completed = currentStreak = 2
    @Test func fiveCompletedOneMissedTwoCompletedReturnsTwoStreak() throws {
        let context = try makeTestContext()
        let original = UserSettings.shared.targetWorkoutsPerWeek
        let originalLongest = UserSettings.shared.longestStreak
        defer {
            UserSettings.shared.targetWorkoutsPerWeek = original
            UserSettings.shared.longestStreak = originalLongest
        }
        UserSettings.shared.targetWorkoutsPerWeek = 1

        // Most recent 2 completed weeks: weeks 1, 2
        createWorkouts(count: 1, inWeekStarting: mondayAt(1), context: context)
        createWorkouts(count: 1, inWeekStarting: mondayAt(2), context: context)
        // Week 3: missed (gap)
        // Weeks 4-8: 5 completed
        for w in 4...8 {
            createWorkouts(count: 1, inWeekStarting: mondayAt(w), context: context)
        }

        let result = StreakService.calculateStreak(context: context)
        #expect(result.streak == 2)
    }

    // TEST.md line 186: week = Monday 00:00:00 through Sunday 23:59:59
    @Test func weekBoundaryMondayToSunday() throws {
        let context = try makeTestContext()
        let original = UserSettings.shared.targetWorkoutsPerWeek
        let originalLongest = UserSettings.shared.longestStreak
        defer {
            UserSettings.shared.targetWorkoutsPerWeek = original
            UserSettings.shared.longestStreak = originalLongest
        }
        UserSettings.shared.targetWorkoutsPerWeek = 1

        // Place a workout on Sunday of last week (day 6 from Monday)
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        let lastWeekMonday = mondayAt(1)
        let lastWeekSunday = calendar.date(byAdding: .day, value: 6, to: lastWeekMonday)!
        let sundayEvening = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: lastWeekSunday)!

        let w = Workout(name: "Sunday", date: sundayEvening, workoutType: "Yoga")
        WorkoutService.logWorkout(w, context: context)

        let result = StreakService.calculateStreak(context: context)
        #expect(result.streak == 1)
    }

    // TEST.md line 187: provisional +1 extension when current week meets target
    @Test func provisionalExtensionWhenCurrentWeekMeetsTarget() throws {
        let context = try makeTestContext()
        let original = UserSettings.shared.targetWorkoutsPerWeek
        let originalLongest = UserSettings.shared.longestStreak
        defer {
            UserSettings.shared.targetWorkoutsPerWeek = original
            UserSettings.shared.longestStreak = originalLongest
        }
        UserSettings.shared.targetWorkoutsPerWeek = 2

        // Last week completed
        createWorkouts(count: 2, inWeekStarting: mondayAt(1), context: context)
        // Current week also meets target
        createWorkouts(count: 2, inWeekStarting: mondayAt(0), context: context)

        let result = StreakService.calculateStreak(context: context)
        // 1 (last week) + 1 (provisional current) = 2
        #expect(result.streak == 2)
    }

    // TEST.md line 188: no provisional extension when current week below target
    @Test func noProvisionalExtensionWhenCurrentWeekBelowTarget() throws {
        let context = try makeTestContext()
        let original = UserSettings.shared.targetWorkoutsPerWeek
        let originalLongest = UserSettings.shared.longestStreak
        defer {
            UserSettings.shared.targetWorkoutsPerWeek = original
            UserSettings.shared.longestStreak = originalLongest
        }
        UserSettings.shared.targetWorkoutsPerWeek = 3

        // Last week completed
        createWorkouts(count: 3, inWeekStarting: mondayAt(1), context: context)
        // Current week has only 1 workout (below target of 3)
        createWorkouts(count: 1, inWeekStarting: mondayAt(0), context: context)

        let result = StreakService.calculateStreak(context: context)
        #expect(result.streak == 1) // no provisional extension
    }

    // TEST.md line 189: lowering target can increase streak
    @Test func loweringTargetIncreasesStreak() throws {
        let context = try makeTestContext()
        let original = UserSettings.shared.targetWorkoutsPerWeek
        let originalLongest = UserSettings.shared.longestStreak
        defer {
            UserSettings.shared.targetWorkoutsPerWeek = original
            UserSettings.shared.longestStreak = originalLongest
        }

        // 3 weeks with 2 workouts each
        for w in 1...3 {
            createWorkouts(count: 2, inWeekStarting: mondayAt(w), context: context)
        }

        // With target=3, none of these weeks meet the target
        UserSettings.shared.targetWorkoutsPerWeek = 3
        let highTarget = StreakService.calculateStreak(context: context)
        #expect(highTarget.streak == 0)

        // Lower target to 2: all 3 weeks now meet the target
        UserSettings.shared.targetWorkoutsPerWeek = 2
        let lowTarget = StreakService.calculateStreak(context: context)
        #expect(lowTarget.streak == 3)
    }

    // TEST.md line 190: raising target can reset streak
    @Test func raisingTargetResetsStreak() throws {
        let context = try makeTestContext()
        let original = UserSettings.shared.targetWorkoutsPerWeek
        let originalLongest = UserSettings.shared.longestStreak
        defer {
            UserSettings.shared.targetWorkoutsPerWeek = original
            UserSettings.shared.longestStreak = originalLongest
        }

        // 3 weeks with 2 workouts each
        for w in 1...3 {
            createWorkouts(count: 2, inWeekStarting: mondayAt(w), context: context)
        }

        // With target=2, all weeks meet target
        UserSettings.shared.targetWorkoutsPerWeek = 2
        let lowTarget = StreakService.calculateStreak(context: context)
        #expect(lowTarget.streak == 3)

        // Raise target to 5: no weeks meet the target
        UserSettings.shared.targetWorkoutsPerWeek = 5
        let highTarget = StreakService.calculateStreak(context: context)
        #expect(highTarget.streak == 0)
    }

    // TEST.md line 191: longestStreak updates when currentStreak exceeds it
    @Test func longestStreakUpdatesWhenCurrentExceedsIt() throws {
        let context = try makeTestContext()
        let original = UserSettings.shared.targetWorkoutsPerWeek
        let originalLongest = UserSettings.shared.longestStreak
        defer {
            UserSettings.shared.targetWorkoutsPerWeek = original
            UserSettings.shared.longestStreak = originalLongest
        }
        UserSettings.shared.targetWorkoutsPerWeek = 1
        UserSettings.shared.longestStreak = 0

        // 3 completed weeks
        for w in 1...3 {
            createWorkouts(count: 1, inWeekStarting: mondayAt(w), context: context)
        }

        let result = StreakService.calculateStreak(context: context)
        #expect(result.streak == 3)
        #expect(UserSettings.shared.longestStreak == 3)
    }

    // TEST.md line 192: longestStreak does not decrease when currentStreak resets
    @Test func longestStreakDoesNotDecrease() throws {
        let context = try makeTestContext()
        let original = UserSettings.shared.targetWorkoutsPerWeek
        let originalLongest = UserSettings.shared.longestStreak
        defer {
            UserSettings.shared.targetWorkoutsPerWeek = original
            UserSettings.shared.longestStreak = originalLongest
        }
        UserSettings.shared.targetWorkoutsPerWeek = 1
        UserSettings.shared.longestStreak = 10

        // Only 1 completed week → streak = 1, but longest should stay 10
        createWorkouts(count: 1, inWeekStarting: mondayAt(1), context: context)

        let result = StreakService.calculateStreak(context: context)
        #expect(result.streak == 1)
        #expect(UserSettings.shared.longestStreak == 10)
    }

    // TEST.md line 193 (implied): retroactive recalculation when target changes
    @Test func retroactiveRecalculationOnTargetChange() throws {
        let context = try makeTestContext()
        let original = UserSettings.shared.targetWorkoutsPerWeek
        let originalLongest = UserSettings.shared.longestStreak
        defer {
            UserSettings.shared.targetWorkoutsPerWeek = original
            UserSettings.shared.longestStreak = originalLongest
        }

        // Week 1: 3 workouts, Week 2: 2 workouts, Week 3: 3 workouts
        createWorkouts(count: 3, inWeekStarting: mondayAt(1), context: context)
        createWorkouts(count: 2, inWeekStarting: mondayAt(2), context: context)
        createWorkouts(count: 3, inWeekStarting: mondayAt(3), context: context)

        // Target=3: week 2 misses → streak = 1 (only week 1)
        UserSettings.shared.targetWorkoutsPerWeek = 3
        let high = StreakService.calculateStreak(context: context)
        #expect(high.streak == 1)

        // Target=2: all 3 weeks meet → streak = 3
        UserSettings.shared.targetWorkoutsPerWeek = 2
        let low = StreakService.calculateStreak(context: context)
        #expect(low.streak == 3)
    }
}

// MARK: - GoalService Repetitions PR Tests

struct GoalServiceRepsPRTests {

    @Test func repsPRCompletionPercentage() {
        let goal = Goal(title: "Bench Press", goalType: "Repetitions PR", targetReps: 10, currentReps: 7, sortOrder: 0)
        let pct = GoalService.completionPercentage(for: goal)
        #expect(pct == 70.0)
    }

    @Test func repsPRDetectsCompletion() {
        let goal = Goal(title: "Bench Press", goalType: "Repetitions PR", targetReps: 10, currentReps: 10, sortOrder: 0)
        #expect(GoalService.isComplete(goal))
    }

    @Test func repsPRNotCompleteUnder100() {
        let goal = Goal(title: "Bench Press", goalType: "Repetitions PR", targetReps: 10, currentReps: 9, sortOrder: 0)
        #expect(!GoalService.isComplete(goal))
    }

    @Test func autoUpdateRepsPRAfterWorkoutSave() throws {
        let context = try makeTestContext()
        let goal = Goal(title: "Bench Press", goalType: "Repetitions PR", targetReps: 15, currentReps: 8, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let exerciseSet = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 12, weightKg: 80, sortOrder: 0)
        workout.exerciseSets.append(exerciseSet)
        WorkoutService.logWorkout(workout, context: context)

        GoalService.recalculateGoals(
            affectedExerciseNames: ["Bench Press"],
            affectedWorkoutTypes: ["Strength Training"],
            workout: workout,
            context: context
        )
        #expect(goal.currentReps == 12)
    }

    @Test func repsPRAutoUpdateIsCaseInsensitive() throws {
        let context = try makeTestContext()
        let goal = Goal(title: "Bench Press", goalType: "Repetitions PR", targetReps: 15, currentReps: 5, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let exerciseSet = ExerciseSet(exerciseName: "bench press", sets: 3, reps: 10, weightKg: 80, sortOrder: 0)
        workout.exerciseSets.append(exerciseSet)
        WorkoutService.logWorkout(workout, context: context)

        GoalService.recalculateGoals(
            affectedExerciseNames: ["bench press"],
            affectedWorkoutTypes: ["Strength Training"],
            workout: workout,
            context: context
        )
        #expect(goal.currentReps == 10)
    }

    @Test func recalculateRepsPRAfterDeletionResetsToZero() throws {
        let context = try makeTestContext()
        let goal = Goal(title: "Bench Press", goalType: "Repetitions PR", targetReps: 15, currentReps: 10, sortOrder: 0)
        context.insert(goal)

        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let exerciseSet = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 10, weightKg: 80, sortOrder: 0)
        workout.exerciseSets.append(exerciseSet)
        WorkoutService.logWorkout(workout, context: context)

        let names = WorkoutService.deleteWorkout(workout, context: context)
        GoalService.recalculateGoals(affectedExerciseNames: names, context: context)

        #expect(goal.currentReps == 0)
    }

    @Test func recalculateRepsPRAfterDeletionFindsHighestRemaining() throws {
        let context = try makeTestContext()
        let goal = Goal(title: "Bench Press", goalType: "Repetitions PR", targetReps: 20, currentReps: 12, sortOrder: 0)
        context.insert(goal)

        let w1 = Workout(name: "Day 1", date: Date().addingTimeInterval(-86400), workoutType: "Strength Training")
        let s1 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 8, weightKg: 80, sortOrder: 0)
        w1.exerciseSets.append(s1)
        WorkoutService.logWorkout(w1, context: context)

        let w2 = Workout(name: "Day 2", date: Date(), workoutType: "Strength Training")
        let s2 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 12, weightKg: 80, sortOrder: 0)
        w2.exerciseSets.append(s2)
        WorkoutService.logWorkout(w2, context: context)

        let names = WorkoutService.deleteWorkout(w2, context: context)
        GoalService.recalculateGoals(affectedExerciseNames: names, context: context)

        #expect(goal.currentReps == 8)
    }
}

// MARK: - GoalService Speed and Distance Tests

struct GoalServiceSpeedDistanceTests {

    @Test func distanceOnlyCompletionPercentage() {
        let goal = Goal(title: "5K Run", goalType: "Speed and Distance",
                        targetDistanceKm: 5, currentDistanceKm: 2.5, sortOrder: 0)
        let pct = GoalService.completionPercentage(for: goal)
        #expect(pct == 50.0)
    }

    @Test func durationOnlyCompletionPercentage() {
        let goal = Goal(title: "Endurance", goalType: "Speed and Distance",
                        targetDurationMinutes: 60, currentDurationMinutes: 45, sortOrder: 0)
        let pct = GoalService.completionPercentage(for: goal)
        #expect(pct == 75.0)
    }

    @Test func bothTargetsUsesLowerPercentage() {
        // Speed target: distance 80%, duration over target (45 > 30 → (30/45)*100 = 66.67%) → overall = 66.67%
        let goal = Goal(title: "Sprint Goal", goalType: "Speed and Distance",
                        targetDistanceKm: 10, currentDistanceKm: 8,
                        targetDurationMinutes: 30, currentDurationMinutes: 45, sortOrder: 0)
        let pct = GoalService.completionPercentage(for: goal)
        #expect(abs(pct - 66.67) < 0.1)
    }

    @Test func bothTargetsCompleteOnlyWhenBothReach100() {
        // distance 100%, duration over target (70 > 60) → not complete
        let notDone = Goal(title: "Sprint Goal", goalType: "Speed and Distance",
                           targetDistanceKm: 10, currentDistanceKm: 10,
                           targetDurationMinutes: 60, currentDurationMinutes: 70, sortOrder: 0)
        #expect(!GoalService.isComplete(notDone))

        // distance met, duration at target → complete
        let done = Goal(title: "Sprint Goal", goalType: "Speed and Distance",
                        targetDistanceKm: 10, currentDistanceKm: 10,
                        targetDurationMinutes: 60, currentDurationMinutes: 60, sortOrder: 0)
        #expect(GoalService.isComplete(done))

        // distance met, duration under target (beat the time) → complete
        let beaten = Goal(title: "Sprint Goal", goalType: "Speed and Distance",
                          targetDistanceKm: 10, currentDistanceKm: 10,
                          targetDurationMinutes: 60, currentDurationMinutes: 50, sortOrder: 0)
        #expect(GoalService.isComplete(beaten))
    }

    @Test func speedDistanceNotAutoUpdatedOnWorkoutSave() throws {
        let context = try makeTestContext()
        let goal = Goal(title: "5K Run", goalType: "Speed and Distance",
                        targetDistanceKm: 5, currentDistanceKm: 0, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let workout = Workout(name: "Cardio", workoutType: "Cardio")
        WorkoutService.logWorkout(workout, context: context)
        GoalService.recalculateGoals(
            affectedExerciseNames: [],
            affectedWorkoutTypes: ["Cardio"],
            workout: workout,
            context: context
        )

        #expect(goal.currentDistanceKm == 0)
    }

    @Test func speedDistanceNotAffectedByWorkoutDeletion() throws {
        let context = try makeTestContext()
        let goal = Goal(title: "5K Run", goalType: "Speed and Distance",
                        targetDistanceKm: 5, currentDistanceKm: 3, sortOrder: 0)
        context.insert(goal)

        let workout = Workout(name: "Cardio", workoutType: "Cardio")
        WorkoutService.logWorkout(workout, context: context)

        let names = WorkoutService.deleteWorkout(workout, context: context)
        GoalService.recalculateGoals(affectedExerciseNames: names, context: context)

        #expect(goal.currentDistanceKm == 3)
    }
}

// MARK: - GoalService Edit Workout Tests

struct GoalServiceEditWorkoutTests {

    @Test func repsPRRecalculatesAfterWorkoutEdit() throws {
        let context = try makeTestContext()
        let goal = Goal(title: "Bench Press", goalType: "Repetitions PR", targetReps: 20, currentReps: 5, sortOrder: 0)
        context.insert(goal)

        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let oldSet = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 80, sortOrder: 0)
        workout.exerciseSets.append(oldSet)
        context.insert(workout)
        try context.save()

        // Edit: increase reps to 12
        let newSet = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 12, weightKg: 80, sortOrder: 0)
        let result = WorkoutService.updateWorkout(
            workout, name: "Push Day", date: workout.date,
            time: nil, rpe: nil, durationMinutes: nil, distanceKm: nil,
            newExerciseSets: [newSet]
        )
        GoalService.recalculateGoals(
            affectedExerciseNames: result.affectedNames,
            affectedWorkoutTypes: ["Strength Training"],
            workout: workout,
            priorDate: result.priorDate,
            context: context
        )

        #expect(goal.currentReps == 12)
    }

    @Test func colorCyclingAcrossGoalTypes() throws {
        let context = try makeTestContext()

        GoalService.createExercisePRGoal(title: "Bench Press", targetValueKg: 100, context: context)
        GoalService.createRepsPRGoal(title: "Pull-ups", targetReps: 20, context: context)
        GoalService.createSpeedDistanceGoal(title: "5K Run", targetDistanceKm: 5, targetDurationMinutes: nil, context: context)

        let goals = GoalService.fetchAll(context: context)
        #expect(goals[0].colorIndex == 0)  // Blue
        #expect(goals[1].colorIndex == 1)  // Light Blue
        #expect(goals[2].colorIndex == 2)  // Green
    }
}

// MARK: - GoalService Mixed-Type Tests

struct GoalServiceMixedTypeTests {

    @Test func reorderMixedTypeGoals() throws {
        let context = try makeTestContext()
        let g1 = Goal(title: "Bench", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        let g2 = Goal(title: "Pull-ups", goalType: "Repetitions PR", targetReps: 20, sortOrder: 1)
        let g3 = Goal(title: "5K Run", goalType: "Speed and Distance", targetDistanceKm: 5, sortOrder: 2)
        context.insert(g1); context.insert(g2); context.insert(g3)
        try context.save()

        GoalService.reorder(goals: [g3, g1, g2], context: context)
        let fetched = GoalService.fetchAll(context: context)
        #expect(fetched[0].title == "5K Run")
        #expect(fetched[1].title == "Bench")
        #expect(fetched[2].title == "Pull-ups")
    }

    @Test func deletingOneTypeDoesNotAffectOthers() throws {
        let context = try makeTestContext()
        let g1 = Goal(title: "Bench", goalType: "Strength PR", targetValueKg: 100, sortOrder: 0)
        let g2 = Goal(title: "Pull-ups", goalType: "Repetitions PR", targetReps: 20, sortOrder: 1)
        let g3 = Goal(title: "5K Run", goalType: "Speed and Distance", targetDistanceKm: 5, sortOrder: 2)
        context.insert(g1); context.insert(g2); context.insert(g3)
        try context.save()

        GoalService.deleteGoal(g2, context: context)
        let remaining = GoalService.fetchAll(context: context)
        #expect(remaining.count == 2)
        #expect(remaining[0].title == "Bench")
        #expect(remaining[0].sortOrder == 0)
        #expect(remaining[1].title == "5K Run")
        #expect(remaining[1].sortOrder == 1)
    }
}

// MARK: - StreakService Tier and Message Tests

struct StreakTierMessageTests {
    @Test func tierClassification() {
        #expect(StreakService.tier(for: 0) == .dormant)
        #expect(StreakService.tier(for: 1) == .building)
        #expect(StreakService.tier(for: 3) == .building)
        #expect(StreakService.tier(for: 4) == .committed)
        #expect(StreakService.tier(for: 7) == .committed)
        #expect(StreakService.tier(for: 8) == .elite)
        #expect(StreakService.tier(for: 12) == .elite)
    }

    @Test func messageForZeroStreak() {
        #expect(StreakService.message(for: 0) == "Hit your weekly target to start a streak")
    }
}


