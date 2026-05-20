import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// Unit tests for the Phase 8.8 Weekly Streak Insights Sheet helpers
/// (`fetchHeatmap`, `thisWeekProgress`, `historySummary`).
///
/// See SERVICES.md § Streak Algorithm → Weekly Streak Insights Helpers.
///
/// Serialized because `historySummary` reads from the `UserSettings.shared` singleton
/// for current/longest streaks; parallel tests that mutate that singleton would race.
@Suite(.serialized)
struct StreakInsightsHelpersUnitTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Workout.self, ExerciseSet.self, Goal.self, WorkoutTypeOrder.self, HomeWidget.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func insertWorkout(context: ModelContext, daysAgo: Int, now: Date = Date()) {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!
        let workout = Workout(name: "W\(daysAgo)", workoutType: "Strength Training")
        workout.date = date
        context.insert(workout)
        try? context.save()
    }

    @Test func test_fetchHeatmap_returnsExactly26CellsByDefault() throws {
        let context = try makeContext()
        let cells = StreakService.fetchHeatmap(context: context, target: 3)
        #expect(cells.count == 26)
    }

    @Test func test_fetchHeatmap_index0IsCurrentWeek() throws {
        let context = try makeContext()
        let cells = StreakService.fetchHeatmap(context: context, target: 3)
        #expect(cells.first?.isCurrentWeek == true)
        #expect(cells.first?.status == .inProgress)
    }

    @Test func test_fetchHeatmap_cellsBeforeFirstWorkoutAreUntracked() throws {
        let context = try makeContext()
        // Single workout 1 day ago — every prior week is untracked
        insertWorkout(context: context, daysAgo: 1)
        let cells = StreakService.fetchHeatmap(context: context, weeks: 10, target: 3)
        // The earliest cells (far in the past) should be untracked
        #expect(cells.last?.status == .untracked)
    }

    @Test func test_thisWeekProgress_currentCountMatchesInWeekWorkouts() throws {
        let context = try makeContext()
        // Two workouts in the current ISO week
        insertWorkout(context: context, daysAgo: 0)
        insertWorkout(context: context, daysAgo: 1)
        let progress = StreakService.thisWeekProgress(context: context, target: 3)
        #expect(progress.currentCount >= 1)
        #expect(progress.target == 3)
    }

    @Test func test_thisWeekProgress_daysRemainingIsBetweenZeroAndSix() throws {
        let context = try makeContext()
        let progress = StreakService.thisWeekProgress(context: context, target: 3)
        #expect(progress.daysRemainingThisWeek >= 0)
        #expect(progress.daysRemainingThisWeek <= 6)
    }

    @Test func test_historySummary_unlockedMilestonesMatchFilterAgainstCurrentStreak() throws {
        let context = try makeContext()
        // Force current streak to a known value via UserSettings (the live source).
        let settings = UserSettings.shared
        let original = settings.currentStreak
        settings.currentStreak = 5
        defer { settings.currentStreak = original }

        let summary = StreakService.historySummary(context: context, target: 3)
        // Milestones at 1, 4, 12, 26, 52 → with streak=5, only 1 and 4 unlocked.
        #expect(summary.unlockedMilestones == [1, 4])
        #expect(summary.nextUnlockedMilestone == 12)
    }

    @Test func test_historySummary_nextMilestoneNilWhenAllUnlocked() throws {
        let context = try makeContext()
        let settings = UserSettings.shared
        let original = settings.currentStreak
        settings.currentStreak = 100
        defer { settings.currentStreak = original }

        let summary = StreakService.historySummary(context: context, target: 3)
        #expect(summary.unlockedMilestones == [1, 4, 12, 26, 52])
        #expect(summary.nextUnlockedMilestone == nil)
    }
}
