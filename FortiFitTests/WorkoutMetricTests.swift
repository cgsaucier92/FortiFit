import Testing
import Foundation
import SwiftData
@testable import FortiFit

private func makeTestContext() throws -> ModelContext {
    let schema = Schema([
        Workout.self, ExerciseSet.self, Goal.self, GoalSnapshot.self,
        WorkoutTypeOrder.self, WorkoutMatchRejection.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

// MARK: - Effort Label Mapping Tests

struct EffortLabelTests {

    @Test func effortLabelMapping_returnsCorrectBandForEveryInteger() {
        #expect(AppConstants.effortLabel(for: 1) == "Easy")
        #expect(AppConstants.effortLabel(for: 2) == "Easy")
        #expect(AppConstants.effortLabel(for: 3) == "Light")
        #expect(AppConstants.effortLabel(for: 4) == "Light")
        #expect(AppConstants.effortLabel(for: 5) == "Moderate")
        #expect(AppConstants.effortLabel(for: 6) == "Moderate")
        #expect(AppConstants.effortLabel(for: 7) == "Hard")
        #expect(AppConstants.effortLabel(for: 8) == "Hard")
        #expect(AppConstants.effortLabel(for: 9) == "All Out")
        #expect(AppConstants.effortLabel(for: 10) == "All Out")
    }

    @Test func effortLabelMapping_outOfRange_returnsUnknown() {
        #expect(AppConstants.effortLabel(for: 0) == "Unknown")
        #expect(AppConstants.effortLabel(for: 11) == "Unknown")
        #expect(AppConstants.effortLabel(for: -1) == "Unknown")
    }
}

// MARK: - Effort Color Mapping Tests

struct EffortColorTests {

    @Test func effortColor_returnsCorrectBandForEveryInteger() {
        let green = FortiFitColors.positive
        let yellow = FortiFitColors.caution
        let red = FortiFitColors.alert

        #expect(AppConstants.effortColor(for: 1) == green)
        #expect(AppConstants.effortColor(for: 2) == green)
        #expect(AppConstants.effortColor(for: 3) == green)
        #expect(AppConstants.effortColor(for: 4) == green)
        #expect(AppConstants.effortColor(for: 5) == yellow)
        #expect(AppConstants.effortColor(for: 6) == yellow)
        #expect(AppConstants.effortColor(for: 7) == red)
        #expect(AppConstants.effortColor(for: 8) == red)
        #expect(AppConstants.effortColor(for: 9) == red)
        #expect(AppConstants.effortColor(for: 10) == red)
    }

    @Test func effortColor_outOfRange_returnsMutedText() {
        let muted = FortiFitColors.mutedText
        #expect(AppConstants.effortColor(for: 0) == muted)
        #expect(AppConstants.effortColor(for: 11) == muted)
        #expect(AppConstants.effortColor(for: -1) == muted)
    }
}

// MARK: - WorkoutMetricService Tests

@MainActor
struct WorkoutMetricServiceTests {

    @Test func comparativeAverage_excludesCurrentWorkout() throws {
        let context = try makeTestContext()

        let durations = [30, 40, 50, 60, 70]
        for dur in durations {
            let w = Workout(name: "Strength \(dur)", workoutType: "Strength Training", durationMinutes: dur)
            context.insert(w)
        }

        let current = Workout(name: "Current", workoutType: "Strength Training", durationMinutes: 100)
        context.insert(current)
        try context.save()

        let avg = WorkoutMetricService.comparativeAverage(for: .duration, workout: current, context: context)
        let expectedAvg = Double(durations.reduce(0, +)) / Double(durations.count)
        #expect(avg != nil)
        #expect(abs(avg! - expectedAvg) < 0.001, "Average should be mean of the other 5, not 6")
    }

    @Test func comparativeAverage_returnsNilWhenInsufficientData() throws {
        let context = try makeTestContext()

        let w1 = Workout(name: "W1", workoutType: "Cardio", durationMinutes: 30)
        let w2 = Workout(name: "W2", workoutType: "Cardio", durationMinutes: 40)
        context.insert(w1)
        context.insert(w2)

        let current = Workout(name: "Current", workoutType: "Cardio", durationMinutes: 50)
        context.insert(current)
        try context.save()

        let avg = WorkoutMetricService.comparativeAverage(for: .duration, workout: current, context: context)
        #expect(avg == nil, "Fewer than 3 same-type workouts (excluding current) should return nil")
    }

    @Test func isPersonalBest_falseForIneligibleMetrics() throws {
        let context = try makeTestContext()

        let w1 = Workout(name: "W1", workoutType: "Strength Training", rpe: 5, durationMinutes: 30, avgHeartRate: 120, maxHeartRate: 150, exerciseMinutes: 25)
        let w2 = Workout(name: "W2", workoutType: "Strength Training", rpe: 7, durationMinutes: 60, avgHeartRate: 140, maxHeartRate: 170, exerciseMinutes: 55)
        context.insert(w1)
        context.insert(w2)
        try context.save()

        #expect(WorkoutMetricService.isPersonalBest(for: .effort, workout: w2, context: context) == false)
        #expect(WorkoutMetricService.isPersonalBest(for: .avgHR, workout: w2, context: context) == false)
        #expect(WorkoutMetricService.isPersonalBest(for: .maxHR, workout: w2, context: context) == false)
        #expect(WorkoutMetricService.isPersonalBest(for: .duration, workout: w2, context: context) == false)
        #expect(WorkoutMetricService.isPersonalBest(for: .exerciseMinutes, workout: w2, context: context) == false)
    }

    @Test func isPersonalBest_trueWhenWorkoutHoldsMaxValue() throws {
        let context = try makeTestContext()

        let w1 = Workout(name: "Run 1", workoutType: "Cardio", distanceKm: 5.0)
        let w2 = Workout(name: "Run 2", workoutType: "Cardio", distanceKm: 8.0)
        let best = Workout(name: "Best Run", workoutType: "Cardio", distanceKm: 12.0)
        context.insert(w1)
        context.insert(w2)
        context.insert(best)
        try context.save()

        #expect(WorkoutMetricService.isPersonalBest(for: .distance, workout: best, context: context) == true)
        #expect(WorkoutMetricService.isPersonalBest(for: .distance, workout: w1, context: context) == false)
    }

    // MARK: - Sparkline Windowing (BUG-072)

    /// Regression test for BUG-072: opening the metric detail sheet for an older workout
    /// in a type with dense history must return points from the *workout's neighborhood*,
    /// not the last 30 days relative to today. Pre-fix, the cutoff was anchored to `Date()`
    /// and the window slid entirely past the workout being viewed.
    @Test func sparklineData_olderWorkoutInDenseHistory_returnsTrailingWindowAroundWorkoutDate() throws {
        let context = try makeTestContext()
        let now = Date()
        let calendar = Calendar.current

        // 70 HIIT workouts at weekly cadence — mirrors the screenshot user's data shape.
        var inserted: [Workout] = []
        for weekIndex in 0..<70 {
            let date = calendar.date(byAdding: .day, value: -7 * weekIndex, to: now)!
            let kcal = 200.0 + Double(weekIndex)
            let w = Workout(name: "HIIT \(weekIndex)", date: date, workoutType: "HIIT", activeEnergyKcal: kcal)
            context.insert(w)
            inserted.append(w)
        }
        try context.save()

        // Pick the workout from 8 weeks ago (~56 days back from "today" in the test).
        let target = inserted[8]
        let result = WorkoutMetricService.sparklineData(for: .activeKcal, workout: target, context: context)

        #expect(result != nil, "Sparkline must return data for a workout with 70 dense same-type peers (pre-fix returned nil)")
        guard let result else { return }
        #expect(result.points.count >= 3, "Trailing 30-day window around the workout must yield ≥ 3 points")
        if case .trailingWindow(_, let anchorDate) = result.mode {
            #expect(calendar.isDate(anchorDate, inSameDayAs: target.date), "Window anchor must be the workout's date")
        } else {
            Issue.record("Dense-history case must use trailingWindow mode, got \(result.mode)")
        }
        let cutoff = calendar.date(byAdding: .day, value: -30, to: target.date)!
        for point in result.points {
            #expect(point.date >= cutoff && point.date <= target.date,
                    "All sparkline points must fall within [workout.date - 30d, workout.date]")
        }
    }

    /// Regression test for BUG-072: when same-type cadence is sparser than the 30-day window
    /// (e.g., a once-a-month long run), the service falls back to the last 5 sessions of
    /// that type at-or-before the workout's date so the sparkline can still render.
    @Test func sparklineData_sparseCadenceType_returnsRecentFallback() throws {
        let context = try makeTestContext()
        let now = Date()
        let calendar = Calendar.current

        // 12 monthly long runs — only one of them ever sits inside a 30-day window.
        var inserted: [Workout] = []
        for monthIndex in 0..<12 {
            let date = calendar.date(byAdding: .day, value: -30 * monthIndex, to: now)!
            let w = Workout(name: "Long Run \(monthIndex)", date: date, workoutType: "Cardio", distanceKm: 15.0 + Double(monthIndex))
            context.insert(w)
            inserted.append(w)
        }
        try context.save()

        let target = inserted[0]
        let result = WorkoutMetricService.sparklineData(for: .distance, workout: target, context: context)

        #expect(result != nil, "Sparse-cadence types must still render via fallback when ≥ 3 sessions exist in history")
        guard let result else { return }
        if case .recentFallback(let sessionCount) = result.mode {
            #expect(sessionCount == 5, "Default fallback session count is 5")
            #expect(result.points.count == 5, "Fallback must return exactly 5 points when ≥ 5 sessions exist at-or-before anchor")
        } else {
            Issue.record("Sparse-cadence case must use recentFallback mode, got \(result.mode)")
        }
        // Every fallback point must be at-or-before the target workout's date.
        for point in result.points {
            #expect(point.date <= target.date, "Fallback must not include workouts dated after the target")
        }
    }

    /// Regression test for BUG-072: a user with only 2 sessions of a type at-or-before the
    /// target workout still legitimately has "not enough data" — the sparkline returns nil,
    /// matching the comparative-average nil path so the empty state is consistent.
    @Test func sparklineData_fewerThanThreeSessionsOfType_returnsNil() throws {
        let context = try makeTestContext()
        let now = Date()

        let w1 = Workout(name: "Solo 1", date: now.addingTimeInterval(-86400), workoutType: "Yoga", activeEnergyKcal: 150)
        let target = Workout(name: "Solo 2", date: now, workoutType: "Yoga", activeEnergyKcal: 175)
        context.insert(w1)
        context.insert(target)
        try context.save()

        let result = WorkoutMetricService.sparklineData(for: .activeKcal, workout: target, context: context)
        #expect(result == nil, "Genuine no-data case must return nil so the empty state renders")
    }

    /// Regression test for BUG-072: the contradictory state observed in the bug — comparative
    /// average renders ("199 kcal typical") AND sparkline empty state renders ("log a few more
    /// sessions") on the same sheet — must no longer be reachable. Whenever the comparative
    /// average is non-nil, the sparkline must also be non-nil.
    @Test func sparklineData_neverEmptyWhenComparativeAverageExists() throws {
        let context = try makeTestContext()
        let now = Date()
        let calendar = Calendar.current

        // 5 monthly HIIT sessions — comparative.peers = 4 (≥ 3) → non-nil.
        // Pre-fix the 30-day window held only 1 session and tripped the empty state.
        var inserted: [Workout] = []
        for monthIndex in 0..<5 {
            let date = calendar.date(byAdding: .day, value: -30 * monthIndex, to: now)!
            let w = Workout(name: "HIIT \(monthIndex)", date: date, workoutType: "HIIT", activeEnergyKcal: 200.0 + Double(monthIndex) * 20)
            context.insert(w)
            inserted.append(w)
        }
        try context.save()

        let target = inserted[0]
        let avg = WorkoutMetricService.comparativeAverage(for: .activeKcal, workout: target, context: context)
        let sparkline = WorkoutMetricService.sparklineData(for: .activeKcal, workout: target, context: context)

        #expect(avg != nil, "Test precondition: ≥ 3 peer sessions of the same type")
        #expect(sparkline != nil, "Sparkline must not be empty when comparative average is non-nil (the BUG-072 contradiction)")
    }
}

// MARK: - Source Name Tests

struct SourceNameTests {

    @Test func sourceName_appleWatchBundle_returnsAppleWorkout() {
        let client = DefaultHealthKitClient()
        #expect(client.sourceName(for: "com.apple.health.workout-builder") == "Apple Workout")
        #expect(client.sourceName(for: "com.apple.health") == "Apple Workout")
    }

    @Test func sourceName_unrecognizedBundle_returnsAnotherApp() {
        let client = DefaultHealthKitClient()
        #expect(client.sourceName(for: "com.unknowndev.randomapp") == "another app")
        #expect(client.sourceName(for: "org.example.fitness") == "another app")
    }

    @Test func sourceName_knownThirdParty_returnsCleanName() {
        let client = DefaultHealthKitClient()
        #expect(client.sourceName(for: "com.strava.run") == "Strava")
        #expect(client.sourceName(for: "com.onepeloton.peloton") == "Peloton")
        #expect(client.sourceName(for: "com.fiit.fiit") == "Fiit")
    }
}

// MARK: - WorkoutMetric Enum Tests

struct WorkoutMetricEnumTests {

    @Test func prEligibility_onlyDistanceActiveKcalTotalKcalElevation() {
        let eligible: Set<WorkoutMetric> = [.distance, .activeKcal, .totalKcal, .elevation]
        for metric in WorkoutMetric.allCases {
            #expect(metric.isPReligible == eligible.contains(metric), "\(metric.displayLabel) PR eligibility mismatch")
        }
    }

    @Test func value_extractsCorrectFieldFromWorkout() {
        let workout = Workout(
            name: "Test",
            workoutType: "Cardio",
            rpe: 7,
            durationMinutes: 45,
            distanceKm: 10.5,
            avgHeartRate: 155,
            maxHeartRate: 178,
            activeEnergyKcal: 420,
            totalEnergyBurnedKcal: 612,
            elevationAscendedMeters: 73,
            exerciseMinutes: 43
        )
        #expect(WorkoutMetric.effort.value(from: workout) == 7)
        #expect(WorkoutMetric.duration.value(from: workout) == 45)
        #expect(WorkoutMetric.distance.value(from: workout) == 10.5)
        #expect(WorkoutMetric.avgHR.value(from: workout) == 155)
        #expect(WorkoutMetric.maxHR.value(from: workout) == 178)
        #expect(WorkoutMetric.activeKcal.value(from: workout) == 420)
        #expect(WorkoutMetric.totalKcal.value(from: workout) == 612)
        #expect(WorkoutMetric.elevation.value(from: workout) == 73)
        #expect(WorkoutMetric.exerciseMinutes.value(from: workout) == 43)
    }

    @Test func value_returnsNilForMissingFields() {
        let workout = Workout(name: "Minimal", workoutType: "Strength Training")
        for metric in WorkoutMetric.allCases {
            #expect(metric.value(from: workout) == nil, "\(metric.displayLabel) should be nil for minimal workout")
        }
    }
}
