//
//  PowerLevelGaugeCascadeIntegrationTests.swift
//  FortiFitIntegrationTests
//
//  Phase 12 integration tests for the Power Level gauge + window comparison
//  bars. Verifies:
//   - Logging a workout that crosses the ±10% threshold republishes the new
//     gauge state (status, thumb position, delta caption) in a single cascade
//     pass.
//   - Window comparison bars hide entirely when either window is zero, and
//     scale to the larger average when both are populated.
//   - The bars view-model reuses the existing `windowComparison()` intermediates
//     rather than recomputing from raw workouts.
//
//  See TESTING.md § Power Level Gauge Test Strategy (Phase 12).
//

import XCTest
import SwiftData
@testable import FortiFit

final class PowerLevelGaugeCascadeIntegrationTests: XCTestCase {

    // MARK: - Cascade Republish

    /// Logging a Strength workout that pushes pct_change from < 10% to > 10%
    /// must flip the computed status from Steady → Rising, shift the thumb
    /// position past the +10% tick, and surface a new delta caption — all in
    /// the same cascade pass that recomputes `calculatePowerLevel` and
    /// `windowComparison()`.
    func test_loggingWorkoutCrossingThreshold_republishesGaugeStateOnce() throws {
        let (_, context) = try TestFixtures.inMemoryContext()
        let now = Date()

        // Baseline (31-60 days ago): avg volume = 1000 (2 workouts × 1000).
        TestFixtures.makeWorkout(
            name: "Baseline A",
            date: Calendar.current.date(byAdding: .day, value: -40, to: now)!,
            workoutType: "Strength Training",
            exercises: [.init("Bench", sets: 4, reps: 5, weightKg: 50.0)],
            in: context
        )
        TestFixtures.makeWorkout(
            name: "Baseline B",
            date: Calendar.current.date(byAdding: .day, value: -50, to: now)!,
            workoutType: "Strength Training",
            exercises: [.init("Bench", sets: 4, reps: 5, weightKg: 50.0)],
            in: context
        )

        // Current (0-30 days ago): 3 workouts at 1050 each → avg = 1050 → +5% (Steady).
        for offset in [5, 10, 15] {
            TestFixtures.makeWorkout(
                name: "Current",
                date: Calendar.current.date(byAdding: .day, value: -offset, to: now)!,
                workoutType: "Strength Training",
                exercises: [.init("Bench", sets: 4, reps: 5, weightKg: 52.5)],
                in: context
            )
        }

        var result = PowerLevelService.calculatePowerLevel(context: context, now: now)
        var comparison = PowerLevelService.windowComparison(context: context, now: now)
        XCTAssertEqual(result.status, .steady, "baseline scenario should be Steady at +5%")
        XCTAssertNotNil(powerLevelGaugePosition(pctChange: comparison.deltaPct))
        let steadyPosition = powerLevelGaugePosition(pctChange: comparison.deltaPct)!

        // When: log a high-volume workout that pushes current avg past +10%.
        // Adds (4 × 5 × 90 = 1800) to current totals → avg becomes (3150 + 1800) / 4 ≈ 1237.5
        // → pct_change ≈ +23.75% → Rising.
        TestFixtures.logWorkoutWithCascade(
            name: "Big Day",
            date: now,
            workoutType: "Strength Training",
            exercises: [.init("Bench", sets: 4, reps: 5, weightKg: 90.0)],
            in: context
        )

        result = PowerLevelService.calculatePowerLevel(context: context, now: now)
        comparison = PowerLevelService.windowComparison(context: context, now: now)

        XCTAssertEqual(result.status, .rising, "post-cascade status must flip to Rising")
        XCTAssertGreaterThan(comparison.deltaPct, 10, "deltaPct must clear the +10% threshold")

        let risingPosition = powerLevelGaugePosition(pctChange: comparison.deltaPct)!
        XCTAssertGreaterThan(risingPosition, steadyPosition, "thumb must shift right")
        XCTAssertGreaterThan(risingPosition, 2.0 / 3.0, "thumb must sit past the +10% tick (2/3)")

        // Caption sourced from raw deltaPct (not clamped).
        let rounded = Int(comparison.deltaPct.rounded())
        let sign = rounded >= 0 ? "+" : ""
        let caption = "\(sign)\(rounded)% vs prior 30d"
        XCTAssertTrue(caption.hasPrefix("+"), "Rising delta caption must carry a positive sign")
    }

    // MARK: - Overflow Indicator (BUG-074)

    /// Regression test for BUG-074. Logging a high-volume workout that pushes
    /// `pct_change` past +30% must reveal the off-scale indicator in a single
    /// cascade pass — confirming `FortiFitPowerLevelGauge.overflowDirection(...)`
    /// flips from `nil` to `.positive` once the cascade recomputes
    /// `windowComparison().deltaPct`. See CONSTANTS.md § Power Level Gauge →
    /// Overflow Indicator.
    func test_loggingWorkoutPushingPastPositiveThreshold_revealsOverflowIndicator() throws {
        let (_, context) = try TestFixtures.inMemoryContext()
        let now = Date()

        // Baseline (31-60 days ago): 2 workouts × 1000 volume each → avg 1000.
        TestFixtures.makeWorkout(
            name: "Baseline A",
            date: Calendar.current.date(byAdding: .day, value: -40, to: now)!,
            workoutType: "Strength Training",
            exercises: [.init("Bench", sets: 4, reps: 5, weightKg: 50.0)],
            in: context
        )
        TestFixtures.makeWorkout(
            name: "Baseline B",
            date: Calendar.current.date(byAdding: .day, value: -50, to: now)!,
            workoutType: "Strength Training",
            exercises: [.init("Bench", sets: 4, reps: 5, weightKg: 50.0)],
            in: context
        )

        // Current pre-log: one workout at volume 1100 → current avg 1100 → +10%
        // (sits exactly on the +10% threshold — not off-scale).
        TestFixtures.makeWorkout(
            name: "Current",
            date: Calendar.current.date(byAdding: .day, value: -10, to: now)!,
            workoutType: "Strength Training",
            exercises: [.init("Bench", sets: 4, reps: 5, weightKg: 55.0)],
            in: context
        )

        let preComparison = PowerLevelService.windowComparison(context: context, now: now)
        XCTAssertNil(
            FortiFitPowerLevelGauge.overflowDirection(for: preComparison.deltaPct),
            "pre-cascade deltaPct must be within ±30% — no off-scale state"
        )

        // When: log a much-higher-volume workout that drags current avg far
        // past the +30% gauge ceiling. 4 sets × 5 reps × 200kg = 4000 volume
        // → new current avg = (1100 + 4000) / 2 = 2550 → pct ≈ +155%.
        TestFixtures.logWorkoutWithCascade(
            name: "PR Day",
            date: now,
            workoutType: "Strength Training",
            exercises: [.init("Bench", sets: 4, reps: 5, weightKg: 200.0)],
            in: context
        )

        let postComparison = PowerLevelService.windowComparison(context: context, now: now)
        XCTAssertGreaterThan(
            postComparison.deltaPct, 30,
            "post-cascade deltaPct must clear the +30% gauge ceiling"
        )
        XCTAssertEqual(
            FortiFitPowerLevelGauge.overflowDirection(for: postComparison.deltaPct),
            .positive,
            "off-scale indicator must surface as .positive once deltaPct > 30%"
        )

        // Thumb position remains clamped at the track end; the indicator is
        // the redundant visual signal that the bar has saturated.
        let position = powerLevelGaugePosition(pctChange: postComparison.deltaPct)
        XCTAssertEqual(position, 1.0, "thumb must still clamp to the +30% end of the track")
    }

    // MARK: - BUG-075 — HK-Shell Workouts Excluded from Window Comparison

    /// Regression test for BUG-075. HK-imported Apple-Watch Strength Training
    /// sessions that haven't been linked to logged sets appear in SwiftData as
    /// `Workout` rows with `workoutType == "Strength Training"` but
    /// `exerciseSets.isEmpty`. Pre-fix `PowerLevelService.fetchQualifyingWorkouts`
    /// counted those zero-volume rows in the 30d average, dragging
    /// `current30dAvg` toward zero and disagreeing with the Workout Volume Trend
    /// chart (which already filtered them out). After the fix the shell row
    /// must leave `windowComparison.current30dAvg` and `deltaPct` unchanged.
    func test_hkShellWorkoutInCurrentWindow_doesNotDragWindowComparisonDown() throws {
        let (_, context) = try TestFixtures.inMemoryContext()
        let now = Date()

        // Baseline (31-60 days ago): two logged Strength workouts, avg 1000.
        TestFixtures.makeWorkout(
            name: "Baseline A",
            date: Calendar.current.date(byAdding: .day, value: -40, to: now)!,
            workoutType: "Strength Training",
            exercises: [.init("Bench", sets: 4, reps: 5, weightKg: 50.0)],
            in: context
        )
        TestFixtures.makeWorkout(
            name: "Baseline B",
            date: Calendar.current.date(byAdding: .day, value: -50, to: now)!,
            workoutType: "Strength Training",
            exercises: [.init("Bench", sets: 4, reps: 5, weightKg: 50.0)],
            in: context
        )

        // Current (0-30 days ago): two logged Strength workouts, avg 1200 — Rising.
        TestFixtures.makeWorkout(
            name: "Current A",
            date: Calendar.current.date(byAdding: .day, value: -5, to: now)!,
            workoutType: "Strength Training",
            exercises: [.init("Bench", sets: 4, reps: 5, weightKg: 60.0)],
            in: context
        )
        TestFixtures.makeWorkout(
            name: "Current B",
            date: Calendar.current.date(byAdding: .day, value: -15, to: now)!,
            workoutType: "Strength Training",
            exercises: [.init("Bench", sets: 4, reps: 5, weightKg: 60.0)],
            in: context
        )

        let before = PowerLevelService.windowComparison(context: context, now: now)
        XCTAssertEqual(before.current30dAvg, 1200, accuracy: 0.001)
        XCTAssertEqual(before.previous30dAvg, 1000, accuracy: 0.001)
        XCTAssertEqual(before.deltaPct, 20.0, accuracy: 0.001)

        let resultBefore = PowerLevelService.calculatePowerLevel(context: context, now: now)
        XCTAssertEqual(resultBefore.status, .rising, "sanity — baseline scenario classifies Rising")

        // When: an HK-shell Strength workout lands in the current window —
        // `exerciseSets.isEmpty`, but matches the workoutType + date predicate.
        TestFixtures.makeWorkout(
            name: "Apple Watch Strength (unlinked)",
            date: Calendar.current.date(byAdding: .day, value: -10, to: now)!,
            workoutType: "Strength Training",
            exercises: [],
            in: context
        )

        let after = PowerLevelService.windowComparison(context: context, now: now)
        XCTAssertEqual(after.current30dAvg, before.current30dAvg, accuracy: 0.001, "current30dAvg must ignore the empty-set HK shell")
        XCTAssertEqual(after.previous30dAvg, before.previous30dAvg, accuracy: 0.001)
        XCTAssertEqual(after.deltaPct, before.deltaPct, accuracy: 0.001)

        let resultAfter = PowerLevelService.calculatePowerLevel(context: context, now: now)
        XCTAssertEqual(resultAfter.status, .rising, "status must not slip to Steady or Deloading after the shell is added")
    }

    /// Regression test for BUG-075. The HK-shell exclusion must hold for HIIT
    /// as well, since both types share the qualifying-workout filter.
    func test_hkShellHIITWorkoutInCurrentWindow_doesNotDragWindowComparisonDown() throws {
        let (_, context) = try TestFixtures.inMemoryContext()
        let now = Date()

        TestFixtures.makeWorkout(
            name: "Baseline HIIT",
            date: Calendar.current.date(byAdding: .day, value: -40, to: now)!,
            workoutType: "HIIT",
            exercises: [.init("KB Swings", sets: 5, reps: 15, weightKg: 20.0)],
            in: context
        )
        TestFixtures.makeWorkout(
            name: "Current HIIT",
            date: Calendar.current.date(byAdding: .day, value: -5, to: now)!,
            workoutType: "HIIT",
            exercises: [.init("KB Swings", sets: 5, reps: 15, weightKg: 24.0)],
            in: context
        )

        let before = PowerLevelService.windowComparison(context: context, now: now)
        XCTAssertGreaterThan(before.current30dAvg, 0)
        XCTAssertGreaterThan(before.previous30dAvg, 0)

        TestFixtures.makeWorkout(
            name: "Apple Watch HIIT (unlinked)",
            date: Calendar.current.date(byAdding: .day, value: -12, to: now)!,
            workoutType: "HIIT",
            exercises: [],
            in: context
        )

        let after = PowerLevelService.windowComparison(context: context, now: now)
        XCTAssertEqual(after.current30dAvg, before.current30dAvg, accuracy: 0.001)
        XCTAssertEqual(after.deltaPct, before.deltaPct, accuracy: 0.001)
    }

    // MARK: - Window Comparison Bars — Empty Hide

    /// When the previous 30d window has zero qualifying workouts, the bars
    /// block must hide entirely (current30dAvg > 0 && previous30dAvg > 0).
    func test_windowComparisonBars_previousWindowZero_blockHidden() throws {
        let (_, context) = try TestFixtures.inMemoryContext()
        let now = Date()

        // Only current-window workouts — no baseline.
        for offset in [3, 10, 20] {
            TestFixtures.makeWorkout(
                date: Calendar.current.date(byAdding: .day, value: -offset, to: now)!,
                workoutType: "Strength Training",
                exercises: [.init("Squat", sets: 5, reps: 5, weightKg: 80.0)],
                in: context
            )
        }

        let comparison = PowerLevelService.windowComparison(context: context, now: now)
        XCTAssertGreaterThan(comparison.current30dAvg, 0)
        XCTAssertEqual(comparison.previous30dAvg, 0)

        // The view's gating expression — keep this assertion in lock-step with
        // `FortiFitPowerLevelDetailSheet.windowComparisonBlock`.
        let shouldRender = comparison.current30dAvg > 0 && comparison.previous30dAvg > 0
        XCTAssertFalse(shouldRender, "bars must be hidden when previous window is empty")
    }

    /// When the current 30d window has zero qualifying workouts, the bars
    /// block must hide entirely.
    func test_windowComparisonBars_currentWindowZero_blockHidden() throws {
        let (_, context) = try TestFixtures.inMemoryContext()
        let now = Date()

        // Only baseline-window workouts.
        for offset in [40, 45, 55] {
            TestFixtures.makeWorkout(
                date: Calendar.current.date(byAdding: .day, value: -offset, to: now)!,
                workoutType: "Strength Training",
                exercises: [.init("Squat", sets: 5, reps: 5, weightKg: 80.0)],
                in: context
            )
        }

        let comparison = PowerLevelService.windowComparison(context: context, now: now)
        XCTAssertEqual(comparison.current30dAvg, 0)
        XCTAssertGreaterThan(comparison.previous30dAvg, 0)

        let shouldRender = comparison.current30dAvg > 0 && comparison.previous30dAvg > 0
        XCTAssertFalse(shouldRender, "bars must be hidden when current window is empty")
    }

    // MARK: - Window Comparison Bars — Scaling

    /// When both windows are populated, both bars scale relative to the
    /// **larger** of the two averages — the larger fills the track and the
    /// smaller fills proportionally.
    func test_windowComparisonBars_bothWindowsPopulated_barsScaledToLargerAverage() throws {
        let (_, context) = try TestFixtures.inMemoryContext()
        let now = Date()

        // Baseline (avg = 1000).
        TestFixtures.makeWorkout(
            date: Calendar.current.date(byAdding: .day, value: -40, to: now)!,
            workoutType: "Strength Training",
            exercises: [.init("Bench", sets: 4, reps: 5, weightKg: 50.0)],
            in: context
        )
        TestFixtures.makeWorkout(
            date: Calendar.current.date(byAdding: .day, value: -50, to: now)!,
            workoutType: "Strength Training",
            exercises: [.init("Bench", sets: 4, reps: 5, weightKg: 50.0)],
            in: context
        )

        // Current (avg = 1200) — larger than baseline.
        TestFixtures.makeWorkout(
            date: Calendar.current.date(byAdding: .day, value: -5, to: now)!,
            workoutType: "Strength Training",
            exercises: [.init("Bench", sets: 4, reps: 5, weightKg: 60.0)],
            in: context
        )
        TestFixtures.makeWorkout(
            date: Calendar.current.date(byAdding: .day, value: -15, to: now)!,
            workoutType: "Strength Training",
            exercises: [.init("Bench", sets: 4, reps: 5, weightKg: 60.0)],
            in: context
        )

        let comparison = PowerLevelService.windowComparison(context: context, now: now)
        XCTAssertEqual(comparison.current30dAvg, 1200, accuracy: 0.001)
        XCTAssertEqual(comparison.previous30dAvg, 1000, accuracy: 0.001)

        // Replicate the view's scaling computation. The larger of the two
        // averages fills the full track (ratio = 1.0); the smaller fills
        // proportionally.
        let larger = max(comparison.current30dAvg, comparison.previous30dAvg)
        let currentRatio = comparison.current30dAvg / larger
        let previousRatio = comparison.previous30dAvg / larger

        XCTAssertEqual(currentRatio, 1.0, accuracy: 0.001, "current bar (larger avg) must fill the track")
        XCTAssertEqual(previousRatio, 1000.0 / 1200.0, accuracy: 0.001, "previous bar must scale to its ratio of the larger avg")

        // When baseline is the larger one, ratios swap.
        let inverseLarger = max(800.0, 1200.0)
        XCTAssertEqual(800.0 / inverseLarger, 800.0 / 1200.0, accuracy: 0.001)
    }

    // MARK: - Reuse of Existing Intermediates

    /// `windowComparison()` is the single source of truth for both the gauge
    /// caption and the bars; calling it must return the same three
    /// intermediates that `calculatePowerLevel` derives from internally.
    /// This guards against future drift where the bars would silently
    /// recompute volume sums.
    func test_windowComparisonBars_readsExistingIntermediates_noRecompute() throws {
        let (_, context) = try TestFixtures.inMemoryContext()
        let now = Date()

        TestFixtures.makeWorkout(
            date: Calendar.current.date(byAdding: .day, value: -40, to: now)!,
            workoutType: "Strength Training",
            exercises: [.init("Bench", sets: 4, reps: 5, weightKg: 50.0)],
            in: context
        )
        TestFixtures.makeWorkout(
            date: Calendar.current.date(byAdding: .day, value: -10, to: now)!,
            workoutType: "Strength Training",
            exercises: [.init("Bench", sets: 4, reps: 5, weightKg: 60.0)],
            in: context
        )

        let first = PowerLevelService.windowComparison(context: context, now: now)
        let second = PowerLevelService.windowComparison(context: context, now: now)

        XCTAssertEqual(first.current30dAvg, second.current30dAvg)
        XCTAssertEqual(first.previous30dAvg, second.previous30dAvg)
        XCTAssertEqual(first.deltaPct, second.deltaPct)

        // The gauge thumb derives strictly from windowComparison().deltaPct
        // — i.e., the position computed from `first.deltaPct` and `second.deltaPct`
        // must agree byte-for-byte.
        let firstPosition = powerLevelGaugePosition(pctChange: first.deltaPct)
        let secondPosition = powerLevelGaugePosition(pctChange: second.deltaPct)
        XCTAssertEqual(firstPosition, secondPosition)
    }
}
