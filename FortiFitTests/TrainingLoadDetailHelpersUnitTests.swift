import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// Unit tests for the Phase 8.8 Training Load Detail Sheet helpers
/// (`fourteenDayDailyScores`, `contributingWorkouts`, `weekOverWeekComparison`).
///
/// See SERVICES.md § Training Load Algorithm → Detail Sheet Helpers.
struct TrainingLoadDetailHelpersUnitTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Workout.self, ExerciseSet.self, Goal.self, WorkoutTypeOrder.self, HomeWidget.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func insertWorkout(
        context: ModelContext,
        daysAgo: Int,
        rpe: Int? = 6,
        duration: Int? = 60,
        type: String = "Strength Training",
        now: Date = Date()
    ) {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!
        let workout = Workout(name: "TL-\(daysAgo)", workoutType: type, rpe: rpe, durationMinutes: duration)
        workout.date = date
        let set = ExerciseSet(exerciseName: "Bench", sets: 3, reps: 8, weightKg: 50, sortOrder: 0, workout: workout)
        context.insert(set)
        context.insert(workout)
        try? context.save()
    }

    @Test func test_fourteenDayDailyScores_returnsExactly14EntriesOldestFirst() throws {
        let context = try makeContext()
        let now = Date()
        insertWorkout(context: context, daysAgo: 1, now: now)
        insertWorkout(context: context, daysAgo: 5, now: now)

        let entries = ExerciseLoadService.fourteenDayDailyScores(context: context, now: now)
        #expect(entries.count == 14)
        // Oldest first: first entry should be the oldest date
        if entries.count >= 2 {
            #expect(entries.first!.date < entries.last!.date)
        }
    }

    @Test func test_contributingWorkouts_returnsAtMostFiveRows() throws {
        let context = try makeContext()
        let now = Date()
        // Insert 8 workouts in the last 7 days
        for offset in 0..<8 {
            insertWorkout(context: context, daysAgo: offset, now: now)
        }
        let rows = ExerciseLoadService.contributingWorkouts(context: context, now: now)
        #expect(rows.count <= 5)
    }

    @Test func test_contributingWorkouts_sortsByDescendingTssContribution() throws {
        let context = try makeContext()
        let now = Date()
        // Vary RPE so contribution magnitudes differ
        insertWorkout(context: context, daysAgo: 1, rpe: 9, now: now)
        insertWorkout(context: context, daysAgo: 1, rpe: 3, now: now)

        let rows = ExerciseLoadService.contributingWorkouts(context: context, now: now)
        if rows.count >= 2 {
            #expect(rows[0].tssContribution >= rows[1].tssContribution)
        }
    }

    @Test func test_contributingWorkouts_percentSumsToAtMost100() throws {
        let context = try makeContext()
        let now = Date()
        for offset in 0..<5 {
            insertWorkout(context: context, daysAgo: offset, now: now)
        }
        let rows = ExerciseLoadService.contributingWorkouts(context: context, now: now)
        let sum = rows.reduce(0) { $0 + $1.percentOfWeeklyLoad }
        #expect(sum <= 100)
    }

    // MARK: - sleepAdjustedContributingWorkouts (Phase 11 linked variant)

    /// Empty sleep map → per-day `sleepFactor` collapses to 1.0 on every day, so the
    /// sleep-adjusted contributions should rank identically to the baseline. Magnitudes
    /// differ (discrete product vs. continuous exp(-daysAgo/τ)) but the row order and
    /// the set of selected workouts must match.
    @Test func test_sleepAdjustedContributingWorkouts_emptyMapMatchesBaselineOrder() throws {
        let context = try makeContext()
        let now = Date()
        insertWorkout(context: context, daysAgo: 1, rpe: 9, duration: 90, now: now)
        insertWorkout(context: context, daysAgo: 2, rpe: 5, duration: 45, now: now)
        insertWorkout(context: context, daysAgo: 4, rpe: 7, duration: 60, now: now)

        let baseline = ExerciseLoadService.contributingWorkouts(context: context, now: now)
        let sleepAdjusted = ExerciseLoadService.sleepAdjustedContributingWorkouts(
            context: context,
            sleepSnapshotsByDay: [:],
            targetSleepHours: 7.0,
            now: now
        )
        #expect(baseline.map { $0.workoutId } == sleepAdjusted.map { $0.workoutId })
    }

    /// Below-target sleep slows decay → past workouts retain more contribution → the
    /// total of all sleep-adjusted contributions is strictly greater than the same
    /// total with an empty (sleep-neutral) map.
    @Test func test_sleepAdjustedContributingWorkouts_poorSleepIncreasesRetainedContribution() throws {
        let context = try makeContext()
        let calendar = Calendar.current
        // Pin "now" to noon so the wake-up-date math is stable across DST.
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 12
        let now = calendar.date(from: components) ?? Date()

        // One workout 4 days ago — old enough that intervening sleepFactors visibly
        // change the discrete decay product.
        insertWorkout(context: context, daysAgo: 4, rpe: 8, duration: 60, now: now)

        // Build a sleep map covering the last 4 days with sleep at 50% of a 7h target
        // (3.5 h actual). sleepFactor = 0.60 + 0.40 * 0.50 = 0.80 → smaller decay per day
        // than the sleep-neutral baseline (sleepFactor = 1.0).
        var poorSleep: [Date: DailySleepSnapshot] = [:]
        let today = calendar.startOfDay(for: now)
        for offset in 0...4 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            poorSleep[day] = DailySleepSnapshot(wakeUpDate: day, totalSleepMinutes: 210) // 3.5 h
        }

        let neutral = ExerciseLoadService.sleepAdjustedContributingWorkouts(
            context: context,
            sleepSnapshotsByDay: [:],
            targetSleepHours: 7.0,
            now: now
        )
        let adjusted = ExerciseLoadService.sleepAdjustedContributingWorkouts(
            context: context,
            sleepSnapshotsByDay: poorSleep,
            targetSleepHours: 7.0,
            now: now
        )

        let neutralTotal = neutral.reduce(0.0) { $0 + $1.tssContribution }
        let adjustedTotal = adjusted.reduce(0.0) { $0 + $1.tssContribution }
        #expect(adjustedTotal > neutralTotal)
    }

    @Test func test_sleepAdjustedContributingWorkouts_sortsByDescendingTssContribution() throws {
        let context = try makeContext()
        let now = Date()
        insertWorkout(context: context, daysAgo: 1, rpe: 9, now: now)
        insertWorkout(context: context, daysAgo: 1, rpe: 3, now: now)

        let rows = ExerciseLoadService.sleepAdjustedContributingWorkouts(
            context: context,
            sleepSnapshotsByDay: [:],
            targetSleepHours: 7.0,
            now: now
        )
        if rows.count >= 2 {
            #expect(rows[0].tssContribution >= rows[1].tssContribution)
        }
    }

    @Test func test_sleepAdjustedContributingWorkouts_percentSumsToAtMost100() throws {
        let context = try makeContext()
        let now = Date()
        for offset in 0..<5 {
            insertWorkout(context: context, daysAgo: offset, now: now)
        }
        let rows = ExerciseLoadService.sleepAdjustedContributingWorkouts(
            context: context,
            sleepSnapshotsByDay: [:],
            targetSleepHours: 7.0,
            now: now
        )
        let sum = rows.reduce(0) { $0 + $1.percentOfWeeklyLoad }
        #expect(sum <= 100)
    }

    @Test func test_sleepAdjustedContributingWorkouts_returnsAtMostFiveRows() throws {
        let context = try makeContext()
        let now = Date()
        for offset in 0..<8 {
            insertWorkout(context: context, daysAgo: offset, now: now)
        }
        let rows = ExerciseLoadService.sleepAdjustedContributingWorkouts(
            context: context,
            sleepSnapshotsByDay: [:],
            targetSleepHours: 7.0,
            now: now
        )
        #expect(rows.count <= 5)
    }

    /// BUG-045 regression: the latest data point on the 14-day chart must match the hero score
    /// at the top of the Training Load Detail Sheet. Previously the chart's today bucket
    /// projected forward to end-of-day, which caused dramatic morning-time divergence
    /// (e.g. hero Peak 83 vs. chart Moderate 53).
    ///
    /// BUG-067 update — both the hero and the chart's today branch now route through
    /// `computeCurrentScore` (with an empty sleep map for unlinked → `sleepFactor = 1.0`
    /// on every day). The chart and hero share the same algorithm shape so they continue
    /// to agree, and the unified decay shape also matches the chip baseline and the home
    /// widget bar.
    @Test func test_fourteenDayDailyScores_latestEntryMatchesHeroScore() throws {
        let context = try makeContext()
        // Pin "now" to 08:08 AM local time so the gap to end-of-day is large — this is the
        // worst-case scenario the bug surfaced under. Use a recent in-window workout so the
        // decay-rate difference between `now` and end-of-day produces a measurable delta.
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 8
        components.minute = 8
        let now = calendar.date(from: components) ?? Date()

        insertWorkout(context: context, daysAgo: 1, rpe: 8, duration: 60, now: now)

        let settings = UserSettings.shared
        let workouts = WorkoutService.fetchLast10DaysWorkouts(context: context, now: now)
        let hero = ExerciseLoadService.computeCurrentScore(
            workouts: workouts,
            sleepSnapshotsByDay: [:],
            targetSleepHours: settings.targetSleepHours,
            experienceLevel: settings.experienceLevel,
            targetMinutesPerWorkout: settings.targetMinutesPerWorkout,
            now: now
        )

        let entries = ExerciseLoadService.fourteenDayDailyScores(context: context, now: now)
        #expect(entries.last?.score == Int(hero.score.rounded()))
    }

    @Test func test_weekOverWeekComparison_zeroPreviousTss_returnsZeroDelta() throws {
        let context = try makeContext()
        let now = Date()
        // Only current-week workouts
        insertWorkout(context: context, daysAgo: 1, now: now)
        let cmp = ExerciseLoadService.weekOverWeekComparison(context: context, now: now)
        #expect(cmp.previousWeekTss == 0)
        #expect(cmp.deltaPct == 0)
    }

    /// BUG-057 regression: equivalent workloads in the current and prior ISO Mon–Sun weeks
    /// must yield ~0% delta. Previously the helper applied `exp(-daysAgo/τ)` decay relative
    /// to `now` for both weeks, which made the prior week's total ~exp(7/τ)× smaller than
    /// the current week's for identical sessions and produced deltas like "↑ 51843% vs last
    /// week" for users with similar weekly volume. The fix sums raw `sessionStress` per
    /// week (no time decay) so the comparison reflects workload performed, not residual
    /// fatigue.
    @Test func test_weekOverWeekComparison_identicalWorkouts_returnsZeroDelta() throws {
        let context = try makeContext()
        // Pin "now" to mid-week (Thursday at noon) so both weeks have headroom and the
        // Mon–Sun boundary math is stable. Use a fixed reference date to keep the test
        // deterministic across DST transitions.
        let calendar = Calendar(identifier: .iso8601)
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 28 // Thursday
        components.hour = 12
        let now = calendar.date(from: components) ?? Date()

        // Tuesday (this week, 2 days ago) + Tuesday (last week, 9 days ago) — identical RPE/duration.
        insertWorkout(context: context, daysAgo: 2, rpe: 7, duration: 60, now: now)
        insertWorkout(context: context, daysAgo: 9, rpe: 7, duration: 60, now: now)

        let cmp = ExerciseLoadService.weekOverWeekComparison(context: context, now: now)
        #expect(cmp.currentWeekTss == cmp.previousWeekTss)
        #expect(cmp.deltaPct == 0)
    }

    /// BUG-057 regression: doubling the workload in the current week vs the prior week
    /// should produce a `deltaPct` near +100%, not the inflated value the decayed-sum
    /// formula produced.
    @Test func test_weekOverWeekComparison_doubledThisWeek_returnsRoughly100PctIncrease() throws {
        let context = try makeContext()
        let calendar = Calendar(identifier: .iso8601)
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 28
        components.hour = 12
        let now = calendar.date(from: components) ?? Date()

        // Last week: 1 workout. This week: 2 identical workouts on different days.
        insertWorkout(context: context, daysAgo: 9, rpe: 7, duration: 60, now: now)
        insertWorkout(context: context, daysAgo: 1, rpe: 7, duration: 60, now: now)
        insertWorkout(context: context, daysAgo: 2, rpe: 7, duration: 60, now: now)

        let cmp = ExerciseLoadService.weekOverWeekComparison(context: context, now: now)
        #expect(cmp.previousWeekTss > 0)
        #expect(cmp.deltaPct == 100)
    }

    /// BUG-057 regression: halving the workload should yield ~-50%, confirming the raw-sum
    /// ratio is symmetric (within rounding) in both directions.
    @Test func test_weekOverWeekComparison_halvedThisWeek_returnsRoughly50PctDecrease() throws {
        let context = try makeContext()
        let calendar = Calendar(identifier: .iso8601)
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 28
        components.hour = 12
        let now = calendar.date(from: components) ?? Date()

        // Last week: 2 identical workouts. This week: 1 of the same.
        insertWorkout(context: context, daysAgo: 9, rpe: 7, duration: 60, now: now)
        insertWorkout(context: context, daysAgo: 10, rpe: 7, duration: 60, now: now)
        insertWorkout(context: context, daysAgo: 1, rpe: 7, duration: 60, now: now)

        let cmp = ExerciseLoadService.weekOverWeekComparison(context: context, now: now)
        #expect(cmp.previousWeekTss > 0)
        #expect(cmp.deltaPct == -50)
    }

    /// BUG-066 regression: on Thursday the prior window must clip to Mon–Thu of
    /// the prior ISO week, NOT extend through Sun. Setup: prior week has one
    /// workout on Tue (day 9, inside the matched window) plus a deliberate Sat
    /// outlier (day 5, outside the matched window). If the prior window were
    /// still full-Mon–Sun, the Saturday workout would inflate `previousWeekTss`
    /// and the delta would become negative. With the matched clip the Saturday
    /// workout is excluded and the deltas mirror identical-workload behavior.
    @Test func test_weekOverWeekComparison_priorWindowClippedToMatchedWeekdayOnly() throws {
        let context = try makeContext()
        let calendar = Calendar(identifier: .iso8601)
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 28 // Thursday
        components.hour = 12
        let now = calendar.date(from: components) ?? Date()

        // Prior week: Tue inside matched window + Sat OUTSIDE matched window.
        insertWorkout(context: context, daysAgo: 9, rpe: 7, duration: 60, now: now)  // Tue last week (in)
        insertWorkout(context: context, daysAgo: 5, rpe: 9, duration: 90, now: now)  // Sat last week (out)
        // This week: matching Tue workout.
        insertWorkout(context: context, daysAgo: 2, rpe: 7, duration: 60, now: now)

        let cmp = ExerciseLoadService.weekOverWeekComparison(context: context, now: now)
        #expect(cmp.matchedDayCount == 4)
        #expect(cmp.currentWeekTss == cmp.previousWeekTss)
        #expect(cmp.deltaPct == 0)
    }

    /// BUG-066: matched window is a single Mon when `now` is Monday — callers gate
    /// on `matchedDayCount < 2` for a "Not enough data" treatment.
    @Test func test_weekOverWeekComparison_mondayReportsMatchedDayCountOne() throws {
        let context = try makeContext()
        let calendar = Calendar(identifier: .iso8601)
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 25 // Monday
        components.hour = 9
        let now = calendar.date(from: components) ?? Date()

        let cmp = ExerciseLoadService.weekOverWeekComparison(context: context, now: now)
        #expect(cmp.matchedDayCount == 1)
    }

    /// BUG-066: Sunday collapses to the full Mon–Sun on both sides.
    @Test func test_weekOverWeekComparison_sundayReportsMatchedDayCountSeven() throws {
        let context = try makeContext()
        let calendar = Calendar(identifier: .iso8601)
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 31 // Sunday
        components.hour = 22
        let now = calendar.date(from: components) ?? Date()

        let cmp = ExerciseLoadService.weekOverWeekComparison(context: context, now: now)
        #expect(cmp.matchedDayCount == 7)
    }
}
