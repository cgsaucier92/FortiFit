import XCTest
import SwiftData
@testable import FortiFit

/// Phase 11 Step 7 — exercises the `RealisticUserScenarioBuilder` end-to-end against
/// the full Phase 11 surface: derived state from the scenario, gating, smart
/// suggestion, correlation, personal insights, and snapshot reads.
@MainActor
final class RealisticUserScenarioBuilderTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        let result = try TestFixtures.inMemoryContext()
        container = result.0
        context = result.1
        for snap in try context.fetch(FetchDescriptor<DailySleepSnapshot>()) { context.delete(snap) }
        for snap in try context.fetch(FetchDescriptor<DailyTrainingLoadSnapshot>()) { context.delete(snap) }
        for w in try context.fetch(FetchDescriptor<Workout>()) { context.delete(w) }
        try context.save()
        UserSettings.shared.targetSleepHours = 7.0
        UserSettings.shared.healthKitEnabled = true
        UserSettings.shared.recoveryLoadManuallyUnlinked = false
    }

    func test_twoWeeksConsistentTrainingSeedsSnapshotsAndWorkouts() throws {
        let scenario = RealisticUserScenarioBuilder.twoWeeksConsistentTraining()
        let result = try RealisticUserScenarioBuilder.build(days: scenario, context: context)

        // Sleep snapshots: 13 days (offsets -1 through -13).
        XCTAssertEqual(result.sleepSnapshots.count, 13)
        // Half the days trained (every other day, even offsets).
        XCTAssertGreaterThanOrEqual(result.workouts.count, 6)
        XCTAssertLessThanOrEqual(result.workouts.count, 7)
    }

    func test_threeWeeksLowSleepScenarioYieldsEnoughPairedDaysForCorrelation() throws {
        let scenario = RealisticUserScenarioBuilder.threeWeeksLowSleepDrivesScoreHigher()
        let result = try RealisticUserScenarioBuilder.build(days: scenario, context: context)
        XCTAssertEqual(result.sleepSnapshots.count, 21)

        // BUG-070 — `computeSleepLoadCorrelation` now recomputes baseline scores from
        // raw workouts, so the test seeds workouts (not TL snapshots). Scenario sleep
        // pattern: good sleep on even offsets, short sleep on odd offsets. Place
        // workouts on even-offset days (including offset 0 = today) so load[D+1] runs
        // higher when D+1 follows a short-sleep (odd-offset) night → delta ≤ -5 →
        // `highSleepBetter`. Offset 0 anchors the most-recent pair so its load is
        // driven by a same-day workout rather than only decay tails.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for offset in stride(from: 0, through: 20, by: 2) {
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let date = calendar.date(byAdding: .hour, value: 12, to: day) ?? day
            let workout = Workout(
                name: "Workout",
                date: date,
                workoutType: "Strength Training",
                rpe: 8,
                durationMinutes: 60
            )
            workout.exerciseSets.append(ExerciseSet(exerciseName: "Squat", sets: 4, reps: 5, weightKg: 80))
            context.insert(workout)
        }
        try context.save()

        let stub = StubHealthKitClient()
        let svc = RecoveryStatusService(client: stub)
        svc.setContext(context)
        svc.recent30DaySleep = result.sleepSnapshots

        let correlation = svc.computeSleepLoadCorrelation(context: context)
        XCTAssertNotNil(correlation)
        // When high sleep correlates with lower next-day score, the formula's
        // `mean(highSleep) − mean(lowSleep)` is negative → `highSleepBetter`.
        // Same direction as "short sleep raises score" — different framing, same data.
        XCTAssertEqual(correlation?.copyVariant, "highSleepBetter",
                       "High-sleep nights correlating with lower next-day scores → highSleepBetter")
        XCTAssertLessThan(correlation?.delta ?? 0, -5)
    }

    func test_twoWeeksConsistentScenarioFeedsTrendsChartWithSnapshots() throws {
        // Seed 14 days of TL snapshots manually so the Trends chart has data to render.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for offset in 0..<14 {
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            _ = ExerciseLoadService.captureDailySnapshot(
                date: day,
                score: 40 + (offset % 3) * 10, // alternating 40, 50, 60
                wasSleepAdjusted: offset.isMultiple(of: 2),
                context: context
            )
        }

        // Read back via the snapshot-aware 14-day helper.
        let series = ExerciseLoadService.fourteenDayDailyScores(context: context)
        XCTAssertEqual(series.count, 14)
        // First (oldest) entry should not be 0 — snapshot at offset 13 had score 40 + (13%3)*10 = 40 + 10 = 50.
        XCTAssertEqual(series.first?.score, 50)
        // Today's entry (last) is recomputed live → 0 since no workouts.
        XCTAssertEqual(series.last?.score, 0)
    }
}
