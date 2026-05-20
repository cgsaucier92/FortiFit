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

    /// BUG-045 regression: the latest data point on the 14-day chart must match the hero score
    /// at the top of the Training Load Detail Sheet. Both should call `calculateLoad` with the
    /// same `now`; previously the chart's today bucket projected forward to end-of-day, which
    /// caused dramatic morning-time divergence (e.g. hero Peak 83 vs. chart Moderate 53).
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
        let hero = ExerciseLoadService.calculateLoad(
            workouts: workouts,
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
}
