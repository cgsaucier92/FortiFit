import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// Unit tests for the Phase 8.8 Power Level Breakdown Sheet helpers
/// (`topContributingExercises`, `windowComparison`, `computeNudge`).
///
/// See SERVICES.md § Power Level Algorithm → Top Contributing Exercises / Window Comparison /
/// Nudge Computation and INFO_COPY.md § Power Level Nudge Copy.
struct PowerLevelDetailHelpersUnitTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Workout.self, ExerciseSet.self, Goal.self, WorkoutTypeOrder.self, HomeWidget.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func insertWorkout(
        context: ModelContext,
        daysAgo: Int,
        type: String = "Strength Training",
        exercises: [(name: String, sets: Int, reps: Int, weight: Double?)],
        now: Date = Date()
    ) {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
        let workout = Workout(name: "Workout-\(daysAgo)", workoutType: type)
        workout.date = date
        context.insert(workout)
        for (index, ex) in exercises.enumerated() {
            let set = ExerciseSet(
                exerciseName: ex.name,
                sets: ex.sets,
                reps: ex.reps,
                weightKg: ex.weight,
                sortOrder: index,
                workout: workout
            )
            context.insert(set)
        }
        try? context.save()
    }

    // MARK: - topContributingExercises ≥ 3-session filter

    @Test func test_topContributingExercises_excludesExercisesWithFewerThanThreeSessions() throws {
        let context = try makeContext()
        let now = Date()

        // 2 sessions of "Bench Press" — should be filtered out
        insertWorkout(context: context, daysAgo: 1, exercises: [("Bench Press", 4, 5, 50)], now: now)
        insertWorkout(context: context, daysAgo: 5, exercises: [("Bench Press", 4, 5, 50)], now: now)

        // 4 sessions of "Squats" — should pass the filter
        insertWorkout(context: context, daysAgo: 2, exercises: [("Squats", 4, 5, 60)], now: now)
        insertWorkout(context: context, daysAgo: 6, exercises: [("Squats", 4, 5, 60)], now: now)
        insertWorkout(context: context, daysAgo: 10, exercises: [("Squats", 4, 5, 60)], now: now)
        insertWorkout(context: context, daysAgo: 14, exercises: [("Squats", 4, 5, 60)], now: now)

        let result = PowerLevelService.topContributingExercises(context: context, now: now)

        #expect(result.count == 1)
        #expect(result.first?.exerciseName == "Squats")
        #expect(result.first?.sessionCountInWindow == 4)
    }

    @Test func test_topContributingExercises_returnsZeroEntriesWhenAllBelowFilter() throws {
        let context = try makeContext()
        let now = Date()

        // 5 different one-off exercises (each only 1 session)
        let exerciseNames = ["A", "B", "C", "D", "E"]
        for (i, name) in exerciseNames.enumerated() {
            insertWorkout(context: context, daysAgo: i + 1, exercises: [(name, 3, 5, 50)], now: now)
        }

        let result = PowerLevelService.topContributingExercises(context: context, now: now)
        #expect(result.isEmpty)
    }

    @Test func test_topContributingExercises_sortsByDescendingVolumeWithTieBreakers() throws {
        let context = try makeContext()
        let now = Date()

        // Exercise A: 3 sessions, total volume 1500
        for offset in [1, 5, 10] {
            insertWorkout(context: context, daysAgo: offset, exercises: [("Alpha", 5, 5, 20)], now: now) // 500
        }
        // Exercise B: 4 sessions, total volume 2000
        for offset in [2, 6, 11, 15] {
            insertWorkout(context: context, daysAgo: offset, exercises: [("Bravo", 5, 5, 20)], now: now) // 500
        }

        let result = PowerLevelService.topContributingExercises(context: context, now: now)

        #expect(result.count == 2)
        #expect(result[0].exerciseName == "Bravo")
        #expect(result[1].exerciseName == "Alpha")
    }

    // MARK: - computeNudge — Cold-Start Resolution

    @Test func test_computeNudge_fewerThanThreeWorkoutsInWindow_returnsColdStartEvenWhenStatusIsRising() throws {
        let context = try makeContext()
        let now = Date()

        // Baseline (31-60 days ago): 2 workouts at avg volume 100
        insertWorkout(context: context, daysAgo: 40, exercises: [("Bench", 2, 5, 10)], now: now) // 100
        insertWorkout(context: context, daysAgo: 50, exercises: [("Bench", 2, 5, 10)], now: now) // 100

        // Current (0-30 days ago): 2 workouts at significantly higher volume — would be `.rising` if it weren't for cold-start guard
        insertWorkout(context: context, daysAgo: 5, exercises: [("Bench", 4, 5, 50)], now: now)  // 1000
        insertWorkout(context: context, daysAgo: 15, exercises: [("Bench", 4, 5, 50)], now: now) // 1000

        let nudge = PowerLevelService.computeNudge(context: context, now: now)
        #expect(nudge.archetype == .coldStart)
        #expect(nudge.messageKey == "coldStart")
    }

    @Test func test_computeNudge_zeroQualifyingWorkouts_returnsColdStart() throws {
        let context = try makeContext()
        let now = Date()

        let nudge = PowerLevelService.computeNudge(context: context, now: now)
        #expect(nudge.archetype == .coldStart)
    }

    @Test func test_computeNudge_steadyWithNoTopExercisePassingFilter_degradesToColdStart() throws {
        let context = try makeContext()
        let now = Date()

        // Seed enough workouts in both windows so status resolves Steady (within ±10%),
        // but spread them across enough distinct exercises that none has ≥ 3 sessions in the current window.
        // Current window: 5 workouts, each on a different exercise
        let currentNames = ["A", "B", "C", "D", "E"]
        for (i, name) in currentNames.enumerated() {
            insertWorkout(context: context, daysAgo: i * 5 + 1, exercises: [(name, 4, 5, 50)], now: now)
        }
        // Baseline window: 5 workouts with same avg volume so pct_change ~ 0% (Steady)
        for (i, name) in currentNames.enumerated() {
            insertWorkout(context: context, daysAgo: 35 + i * 5, exercises: [(name, 4, 5, 50)], now: now)
        }

        let nudge = PowerLevelService.computeNudge(context: context, now: now)
        #expect(nudge.archetype == .coldStart, "Steady with no top exercise should degrade to coldStart copy")
    }

    /// Regression for BUG-046: when the user has ≥ 3 current-window workouts but zero prior-window
    /// history, `computeNudge` must emit `.noBaseline` (not `.steady`) so the UI surfaces the 60-day
    /// window limitation explicitly instead of falsely claiming the trend is flat.
    @Test func test_computeNudge_currentWindowOnlyWithEmptyBaseline_returnsNoBaseline() throws {
        let context = try makeContext()
        let now = Date()

        // 4 current-window workouts of the same exercise, no baseline-window data at all
        for offset in [2, 6, 10, 14] {
            insertWorkout(context: context, daysAgo: offset, exercises: [("Barbell Squats", 4, 5, 50)], now: now)
        }

        let nudge = PowerLevelService.computeNudge(context: context, now: now)
        #expect(nudge.archetype == .noBaseline)
        #expect(nudge.messageKey == "noBaseline")
        #expect(nudge.inputs.currentSessionCount30d == 4)
    }

    /// Regression for BUG-046: when prior-window data is absent for an exercise, the resulting
    /// `PowerLevelTopExercise.previousWindowVolume` must be exactly 0 so the detail-sheet
    /// row can render an em-dash instead of "+0%".
    @Test func test_topContributingExercises_emptyBaseline_reportsZeroPreviousVolume() throws {
        let context = try makeContext()
        let now = Date()

        for offset in [2, 6, 10, 14] {
            insertWorkout(context: context, daysAgo: offset, exercises: [("Barbell Squats", 4, 5, 50)], now: now)
        }

        let result = PowerLevelService.topContributingExercises(context: context, now: now)
        #expect(result.count == 1)
        #expect(result.first?.previousWindowVolume == 0)
        #expect(result.first?.deltaPct == 0)
    }

    /// Regression for BUG-046 follow-up: the user has prior-window workouts (so the broad
    /// `previousWorkouts.isEmpty` guard doesn't trigger) BUT the cited top exercise is brand-new
    /// in the current window with `previousWindowVolume == 0`. The steady "flat" copy would lie
    /// about this exercise — the nudge must degrade to `noBaseline` so the row's em-dash and the
    /// message agree.
    @Test func test_computeNudge_steadyWithTopExerciseLackingBaseline_returnsNoBaseline() throws {
        let context = try makeContext()
        let now = Date()

        // Current window: 4 sessions of Barbell Squats (brand-new exercise)
        for offset in [2, 6, 10, 14] {
            insertWorkout(context: context, daysAgo: offset, exercises: [("Barbell Squats", 4, 5, 50)], now: now)
        }
        // Prior window: workouts of an UNRELATED exercise so previousWorkouts is non-empty but
        // Barbell Squats specifically has zero prior-window volume. Volume per workout matches
        // the current window so overall status resolves to .steady (within ±10%).
        for offset in [35, 40, 45, 50] {
            insertWorkout(context: context, daysAgo: offset, exercises: [("Bench Press", 4, 5, 50)], now: now)
        }

        let nudge = PowerLevelService.computeNudge(context: context, now: now)
        #expect(nudge.archetype == .noBaseline, "Steady with a brand-new top exercise should degrade to noBaseline, not claim the exercise is flat")
        #expect(nudge.messageKey == "noBaseline")
    }

    @Test func test_computeNudge_steadyWithQualifyingTopExercise_returnsSteadyArchetype() throws {
        let context = try makeContext()
        let now = Date()

        // 4 current-window workouts of the SAME exercise so ≥ 3-session filter passes
        for offset in [2, 6, 10, 14] {
            insertWorkout(context: context, daysAgo: offset, exercises: [("Squats", 4, 5, 50)], now: now)
        }
        // 4 baseline-window workouts of same exercise at same volume → Steady status
        for offset in [35, 40, 45, 50] {
            insertWorkout(context: context, daysAgo: offset, exercises: [("Squats", 4, 5, 50)], now: now)
        }

        let nudge = PowerLevelService.computeNudge(context: context, now: now)
        #expect(nudge.archetype == .steady)
        #expect(nudge.inputs.topExerciseName == "Squats")
    }

    // MARK: - windowComparison

    @Test func test_windowComparison_surfacesAlgorithmIntermediates() throws {
        let context = try makeContext()
        let now = Date()

        // Current: 2 workouts, avg volume 1000
        insertWorkout(context: context, daysAgo: 5, exercises: [("Bench", 4, 5, 50)], now: now)
        insertWorkout(context: context, daysAgo: 15, exercises: [("Bench", 4, 5, 50)], now: now)
        // Baseline: 2 workouts, avg volume 500
        insertWorkout(context: context, daysAgo: 40, exercises: [("Bench", 4, 5, 25)], now: now)
        insertWorkout(context: context, daysAgo: 50, exercises: [("Bench", 4, 5, 25)], now: now)

        let comparison = PowerLevelService.windowComparison(context: context, now: now)
        #expect(comparison.current30dAvg == 1000)
        #expect(comparison.previous30dAvg == 500)
        #expect(comparison.deltaPct == 100)
    }

    @Test func test_windowComparison_zeroPreviousAvg_returnsZeroDelta() throws {
        let context = try makeContext()
        let now = Date()

        insertWorkout(context: context, daysAgo: 5, exercises: [("Bench", 4, 5, 50)], now: now)

        let comparison = PowerLevelService.windowComparison(context: context, now: now)
        #expect(comparison.previous30dAvg == 0)
        #expect(comparison.deltaPct == 0)
    }
}
