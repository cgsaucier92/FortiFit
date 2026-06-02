import XCTest
import SwiftData
@testable import FortiFit

/// Phase 11 — BUG-067 integration coverage for the linked Recovery & Load surface.
///
/// Three end-to-end contracts that together resolve BUG-067:
///   1. **Linked detail sheet:** the chart's latest data point on the
///      "Last 14 Days · Training Load (Sleep-Adjusted)" chart must equal the rounded
///      hero score at the top of the sheet. Previously the chart was sourced from
///      `fourteenDayDailyScores`, which called `calculateLoad` for today — the
///      sleep-blind path — while the hero was computed via `computeCurrentScore`.
///   2. **Trends chart:** `TrendsChartService.headerSummary` for `trainingLoadTrend`
///      and `TrendsChartService.dataPoints` for the same chart must produce the
///      sleep-adjusted score when Recovery Status is linked with Training Load on
///      the Home screen (resolved via `RecoveryStatusService.current` +
///      `HomeWidgetService.isLinkedActive`).
///   3. **Unlinked Trends chart:** when nothing is linked,
///      `TrendsChartService.headerSummary` for `trainingLoadTrend` falls back to the
///      baseline `calculateLoad` result (preserves prior behavior for unlinked users).
@MainActor
final class LinkedSleepAdjustedChartIntegrationTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        let result = try TestFixtures.inMemoryContext()
        container = result.0
        context = result.1
        // Clean Phase 11 entities + Home widgets between tests since UserSettings is a singleton.
        for snap in try context.fetch(FetchDescriptor<DailySleepSnapshot>()) { context.delete(snap) }
        for snap in try context.fetch(FetchDescriptor<DailyTrainingLoadSnapshot>()) { context.delete(snap) }
        for widget in try context.fetch(FetchDescriptor<HomeWidget>()) { context.delete(widget) }
        try context.save()
        UserSettings.shared.recoveryLoadManuallyUnlinked = false
        UserSettings.shared.healthKitEnabled = true
        UserSettings.shared.targetSleepHours = 7.0
    }

    // MARK: - Helpers

    private func seedLinkedWidgets() throws {
        // Adjacent placement, RS at 0 and TL at 1, both present.
        let rs = HomeWidget(widgetType: "recoveryStatus", sortOrder: 0)
        let tl = HomeWidget(widgetType: "trainingLoad", sortOrder: 1)
        context.insert(rs)
        context.insert(tl)
        try context.save()
    }

    /// Spins up a `RecoveryStatusService` in the `.live` gating state with sub-target
    /// sleep snapshots for the last 11 days, then returns the held reference so the
    /// test can keep it alive across the assertion.
    private func makeLinkedRecoveryService(now: Date, sleepMinutes: Int) -> RecoveryStatusService {
        let stub = StubHealthKitClient()
        stub.hasRecentSleepDataToReturn = true
        let svc = RecoveryStatusService(client: stub)
        svc.currentGatingState = .live
        svc.isLinkedActive = true
        svc.setContext(context)
        // Sub-target sleep on each of the last 11 days — covers the 10-day window.
        let calendar = Calendar.current
        var snaps: [DailySleepSnapshot] = []
        for offset in 0...10 {
            let day = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -offset, to: now) ?? now)
            let snap = DailySleepSnapshot(wakeUpDate: day, totalSleepMinutes: sleepMinutes)
            snaps.append(snap)
        }
        svc.recent30DaySleep = snaps
        return svc
    }

    private func insertHeavyWorkout(daysAgo: Int, now: Date) {
        TestFixtures.makeWorkout(
            name: "Heavy",
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: now) ?? now,
            workoutType: "Strength Training",
            rpe: 8,
            durationMinutes: 60,
            exercises: [TestFixtures.SetSpec("Squat", sets: 5, reps: 5, weightKg: 120)],
            in: context
        )
    }

    // MARK: - Contract 1 — linked detail sheet chart matches hero

    /// BUG-067 regression: in the linked composite, `fourteenDayDailyScores` called with
    /// the live sleep map must produce a final entry whose `score` equals the rounded
    /// `computeCurrentScore` result (the same result the linked detail sheet's hero
    /// renders). The chart-vs-hero mismatch that triggered this bug is gone.
    func test_linkedDetailSheet_chartLatestPointEqualsHero() throws {
        try seedLinkedWidgets()
        let now = Date()
        // Two workouts that together leave a decay tail for sleep adjustment to act on.
        insertHeavyWorkout(daysAgo: 2, now: now)
        insertHeavyWorkout(daysAgo: 4, now: now)

        let recovery = makeLinkedRecoveryService(now: now, sleepMinutes: 240) // 4h vs 7h target

        withExtendedLifetime(recovery) {
            // Pre-conditions: linking is actually active.
            let widgets = HomeWidgetService.fetchAll(context: context)
            XCTAssertTrue(
                HomeWidgetService.isLinkedActive(widgets: widgets, settings: UserSettings.shared),
                "Linking must be active for this test to exercise BUG-067"
            )

            // The linked detail sheet's hero is computed via this exact call.
            let settings = UserSettings.shared
            let workouts = WorkoutService.fetchWorkouts(
                from: Calendar.current.date(byAdding: .day, value: -10, to: now) ?? now,
                to: now,
                context: context
            )
            let expectedHero = ExerciseLoadService.computeCurrentScore(
                workouts: workouts,
                sleepSnapshotsByDay: recovery.cachedSnapshotsByDay(),
                targetSleepHours: settings.targetSleepHours,
                experienceLevel: settings.experienceLevel,
                targetMinutesPerWorkout: settings.targetMinutesPerWorkout,
                now: now
            )

            // The chart on the linked detail sheet calls `fourteenDayDailyScores` with
            // exactly these arguments.
            let entries = ExerciseLoadService.fourteenDayDailyScores(
                context: context,
                sleepSnapshotsByDay: recovery.cachedSnapshotsByDay(),
                targetSleepHours: settings.targetSleepHours,
                now: now
            )

            XCTAssertEqual(
                entries.last?.score, Int(expectedHero.score.rounded()),
                "Linked detail sheet chart's last point must equal the hero score (BUG-067)"
            )

            // The setup must produce a sleep-adjusted value that differs from the baseline,
            // otherwise the test wouldn't exercise the contract.
            let baselineHero = ExerciseLoadService.calculateLoad(
                workouts: workouts,
                experienceLevel: settings.experienceLevel,
                targetMinutesPerWorkout: settings.targetMinutesPerWorkout,
                now: now
            )
            XCTAssertNotEqual(
                Int(expectedHero.score.rounded()), Int(baselineHero.score.rounded()),
                "Test fixture must produce a sleep-adjusted vs baseline divergence"
            )
        }
    }

    // MARK: - Contract 2 — Trends chart uses sleep-adjusted score when linked

    /// BUG-067 regression: when Recovery Status is linked with Training Load on the
    /// Home screen, the Trends `trainingLoadTrend` chart's today data point and the
    /// header summary's hero must reflect the sleep-adjusted score — the same one
    /// the home widget bar and the linked detail sheet display. Previously this
    /// surface always used the baseline `calculateLoad`.
    ///
    /// The auto-resolution path is only reachable on the main thread (where
    /// `RecoveryStatusService.current` is MainActor-isolated), so this test must
    /// run on the main actor — confirmed by the `@MainActor` class annotation.
    func test_trendsChart_trainingLoadTrend_usesSleepAdjustedScore_whenLinked() throws {
        try seedLinkedWidgets()
        let now = Date()
        // ≥ 3 days with workouts in the last 14 days so `trainingLoadTrendSummary`
        // doesn't bail out early.
        insertHeavyWorkout(daysAgo: 1, now: now)
        insertHeavyWorkout(daysAgo: 3, now: now)
        insertHeavyWorkout(daysAgo: 5, now: now)

        let recovery = makeLinkedRecoveryService(now: now, sleepMinutes: 240)

        withExtendedLifetime(recovery) {
            let widgets = HomeWidgetService.fetchAll(context: context)
            XCTAssertTrue(
                HomeWidgetService.isLinkedActive(widgets: widgets, settings: UserSettings.shared),
                "Linking must be active for the Trends chart auto-resolution to kick in"
            )

            let settings = UserSettings.shared
            let workouts = WorkoutService.fetchWorkouts(
                from: Calendar.current.date(byAdding: .day, value: -10, to: now) ?? now,
                to: now,
                context: context
            )
            let expectedHero = ExerciseLoadService.computeCurrentScore(
                workouts: workouts,
                sleepSnapshotsByDay: recovery.cachedSnapshotsByDay(),
                targetSleepHours: settings.targetSleepHours,
                experienceLevel: settings.experienceLevel,
                targetMinutesPerWorkout: settings.targetMinutesPerWorkout,
                now: now
            )
            let baselineHero = ExerciseLoadService.calculateLoad(
                workouts: workouts,
                experienceLevel: settings.experienceLevel,
                targetMinutesPerWorkout: settings.targetMinutesPerWorkout,
                now: now
            )
            // Set up must actually diverge — else the test passes trivially.
            XCTAssertNotEqual(
                Int(expectedHero.score.rounded()), Int(baselineHero.score.rounded()),
                "Test fixture must produce a sleep-adjusted vs baseline divergence"
            )

            // Trends chart header summary.
            let summary = TrendsChartService.headerSummary(for: "trainingLoadTrend", context: context)
            XCTAssertNotNil(summary)
            XCTAssertEqual(
                summary?.hero, "\(Int(expectedHero.score.rounded()))",
                "Trends chart trainingLoadTrend hero must reflect the sleep-adjusted score when linked (BUG-067)"
            )

            // Trends chart data points — today's point (last entry) must match.
            let points = TrendsChartService.dataPoints(
                for: "trainingLoadTrend",
                range: .thirtyDays,
                context: context
            )
            XCTAssertFalse(points.isEmpty)
            // The y value of today's point must equal the sleep-adjusted score, not the
            // baseline. Compare as the rounded integer the chart actually plots.
            XCTAssertEqual(
                Int((points.last?.y ?? 0).rounded()),
                Int(expectedHero.score.rounded()),
                "Trends chart today's data point must equal the sleep-adjusted score when linked (BUG-067)"
            )
        }
    }

    // MARK: - Contract 3 — Unlinked Trends chart falls back to baseline

    /// When the user is unlinked, the Trends chart's `trainingLoadTrend` surface must
    /// behave exactly as it did before BUG-067 — using `calculateLoad` so today's
    /// data point matches the score the user sees on the (unlinked) home widget bar
    /// and the unlinked Training Load detail sheet hero. The auto-resolution helper
    /// inside `TrendsChartService` must return nil when widgets aren't both present
    /// and adjacent.
    func test_trendsChart_trainingLoadTrend_fallsBackToBaseline_whenUnlinked() throws {
        // Only Training Load widget — no Recovery Status → not linked.
        let tl = HomeWidget(widgetType: "trainingLoad", sortOrder: 0)
        context.insert(tl)
        try context.save()

        let now = Date()
        insertHeavyWorkout(daysAgo: 1, now: now)
        insertHeavyWorkout(daysAgo: 3, now: now)
        insertHeavyWorkout(daysAgo: 5, now: now)

        // Spin up the service in `.live` so its presence alone doesn't satisfy the
        // gating — but we don't seed Recovery Status as a widget, so linking is off.
        let recovery = makeLinkedRecoveryService(now: now, sleepMinutes: 240)

        withExtendedLifetime(recovery) {
            let widgets = HomeWidgetService.fetchAll(context: context)
            XCTAssertFalse(
                HomeWidgetService.isLinkedActive(widgets: widgets, settings: UserSettings.shared),
                "Linking must be off for this test"
            )

            let settings = UserSettings.shared
            let workouts = WorkoutService.fetchWorkouts(
                from: Calendar.current.date(byAdding: .day, value: -10, to: now) ?? now,
                to: now,
                context: context
            )
            let baseline = ExerciseLoadService.calculateLoad(
                workouts: workouts,
                experienceLevel: settings.experienceLevel,
                targetMinutesPerWorkout: settings.targetMinutesPerWorkout,
                now: now
            )

            let summary = TrendsChartService.headerSummary(for: "trainingLoadTrend", context: context)
            XCTAssertNotNil(summary)
            XCTAssertEqual(
                summary?.hero, "\(Int(baseline.score.rounded()))",
                "Unlinked Trends chart must use baseline calculateLoad (BUG-067 preserves prior behavior)"
            )
        }
    }
}
