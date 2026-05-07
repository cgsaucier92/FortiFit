import Testing
import Foundation
import SwiftData
@testable import FortiFit

private func makeTestContext() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Workout.self, ExerciseSet.self, Goal.self, GoalSnapshot.self,
             WorkoutTypeOrder.self, WorkoutTemplate.self, TemplateExerciseSet.self,
             ScheduledWorkout.self, HomeWidget.self, TrendsChart.self,
             WorkoutMatchRejection.self,
        configurations: config
    )
    return ModelContext(container)
}

private func makeWorkout(
    name: String = "Test",
    date: Date,
    workoutType: String = "Strength Training",
    rpe: Int? = nil,
    durationMinutes: Int? = nil,
    exercises: [(String, Int, Int, Double?)] = [],
    in context: ModelContext
) {
    let workout = Workout(
        name: name,
        date: date,
        workoutType: workoutType,
        rpe: rpe,
        durationMinutes: durationMinutes
    )
    context.insert(workout)
    for (i, ex) in exercises.enumerated() {
        let set = ExerciseSet(
            exerciseName: ex.0,
            sets: ex.1,
            reps: ex.2,
            weightKg: ex.3,
            sortOrder: i,
            workout: workout
        )
        context.insert(set)
    }
    try? context.save()
}

private func daysAgo(_ n: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: -n, to: .now)!
}

private func weeksAgo(_ n: Int) -> Date {
    var calendar = Calendar(identifier: .iso8601)
    calendar.firstWeekday = 2
    let currentWeekStart = Date().startOfWeek
    let weekStart = calendar.date(byAdding: .weekOfYear, value: -n, to: currentWeekStart)!
    return calendar.date(byAdding: .day, value: 2, to: weekStart)!
}

// MARK: - Comparison Delta Tests

@Suite(.serialized)
struct ComparisonDeltaTests {

    @Test func test_comparisonDelta_belowThreshold_returnsNil() throws {
        let context = try makeTestContext()
        UserSettings.shared.useLbs = false

        let chartTypes = AppConstants.trendsChartTypes
        for chartType in chartTypes {
            let result = TrendsChartService.comparisonDelta(
                for: chartType,
                exerciseName: chartType == "strengthTracker" || chartType == "personalRecords" ? "Bench Press" : nil,
                range: DetailTimeRange.defaultRange(for: chartType),
                context: context
            )
            #expect(result == nil, "Expected nil for \(chartType) below threshold")
        }
    }

    @Test func test_comparisonDelta_strengthTracker_currentExceedsPrior_returnsUpDirection() throws {
        let context = try makeTestContext()
        UserSettings.shared.useLbs = true

        makeWorkout(date: daysAgo(120), exercises: [("Bench Press", 3, 8, 90.72)], in: context)
        makeWorkout(date: daysAgo(100), exercises: [("Bench Press", 3, 8, 90.72)], in: context)

        makeWorkout(date: daysAgo(60), exercises: [("Bench Press", 3, 8, 99.79)], in: context)
        makeWorkout(date: daysAgo(10), exercises: [("Bench Press", 3, 8, 99.79)], in: context)

        let result = TrendsChartService.comparisonDelta(
            for: "strengthTracker",
            exerciseName: "Bench Press",
            range: .ninetyDays,
            context: context
        )
        #expect(result != nil)
        #expect(result?.direction == .up)
        #expect(result?.delta != nil)
        #expect(result?.delta?.contains("+") == true)
    }

    @Test func test_comparisonDelta_currentBelowPrior_returnsDownDirection() throws {
        let context = try makeTestContext()
        UserSettings.shared.useLbs = false

        makeWorkout(date: daysAgo(120), exercises: [("Bench Press", 3, 8, 100.0)], in: context)
        makeWorkout(date: daysAgo(100), exercises: [("Bench Press", 3, 8, 100.0)], in: context)

        makeWorkout(date: daysAgo(60), exercises: [("Bench Press", 3, 8, 80.0)], in: context)
        makeWorkout(date: daysAgo(10), exercises: [("Bench Press", 3, 8, 80.0)], in: context)

        let result = TrendsChartService.comparisonDelta(
            for: "strengthTracker",
            exerciseName: "Bench Press",
            range: .ninetyDays,
            context: context
        )
        #expect(result != nil)
        #expect(result?.direction == .down)
    }

    @Test func test_comparisonDelta_noPriorPeriodData_returnsFlatDirectionAndNilDelta() throws {
        let context = try makeTestContext()
        UserSettings.shared.useLbs = false

        makeWorkout(date: daysAgo(10), exercises: [("Bench Press", 3, 8, 100.0)], in: context)
        makeWorkout(date: daysAgo(5), exercises: [("Bench Press", 3, 8, 100.0)], in: context)

        let result = TrendsChartService.comparisonDelta(
            for: "strengthTracker",
            exerciseName: "Bench Press",
            range: .thirtyDays,
            context: context
        )
        #expect(result != nil)
        #expect(result?.direction == .flat)
        #expect(result?.delta == nil)
    }
}

// MARK: - Data Points Tests

@Suite(.serialized)
struct DataPointsTests {

    @Test func test_dataPoints_strengthTracker_30d_returnsPointsInRange() throws {
        let context = try makeTestContext()
        UserSettings.shared.useLbs = false

        makeWorkout(date: daysAgo(90), exercises: [("Bench Press", 3, 8, 80.0)], in: context)
        makeWorkout(date: daysAgo(20), exercises: [("Bench Press", 3, 8, 90.0)], in: context)
        makeWorkout(date: daysAgo(5), exercises: [("Bench Press", 3, 8, 100.0)], in: context)

        let points = TrendsChartService.dataPoints(
            for: "strengthTracker",
            exerciseName: "Bench Press",
            range: .thirtyDays,
            context: context
        )

        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        #expect(points.count == 2)
        for point in points {
            #expect(point.x >= cutoff)
        }
        let dates = points.map(\.x)
        #expect(dates == dates.sorted())
    }

    @Test func test_dataPoints_oneYearRange_includesOlderPoints() throws {
        let context = try makeTestContext()
        UserSettings.shared.useLbs = false

        makeWorkout(date: daysAgo(200), exercises: [("Bench Press", 3, 8, 80.0)], in: context)
        makeWorkout(date: daysAgo(90), exercises: [("Bench Press", 3, 8, 90.0)], in: context)
        makeWorkout(date: daysAgo(5), exercises: [("Bench Press", 3, 8, 100.0)], in: context)

        let points = TrendsChartService.dataPoints(
            for: "strengthTracker",
            exerciseName: "Bench Press",
            range: .oneYear,
            context: context
        )
        #expect(points.count == 3)
    }

    @Test func test_dataPoints_excludesNilWeightForStrengthTracker() throws {
        let context = try makeTestContext()
        UserSettings.shared.useLbs = false

        makeWorkout(date: daysAgo(20), exercises: [("Bench Press", 3, 8, 90.0)], in: context)
        makeWorkout(date: daysAgo(10), exercises: [("Push-ups", 3, 20, nil)], in: context)
        makeWorkout(date: daysAgo(5), exercises: [("Bench Press", 3, 8, 100.0)], in: context)

        let points = TrendsChartService.dataPoints(
            for: "strengthTracker",
            exerciseName: "Bench Press",
            range: .thirtyDays,
            context: context
        )
        #expect(points.count == 2)
    }
}

// MARK: - PR Timeline Tests

@Suite(.serialized)
struct PRTimelineTests {

    @Test func test_fullPRTimeline_returnsEveryPREventChronologically() throws {
        let context = try makeTestContext()

        makeWorkout(date: daysAgo(100), exercises: [("Bench Press", 3, 5, 61.24)], in: context)   // 135 lbs baseline
        makeWorkout(date: daysAgo(80), exercises: [("Bench Press", 3, 5, 70.31)], in: context)    // 155 lbs PR
        makeWorkout(date: daysAgo(60), exercises: [("Bench Press", 3, 5, 79.38)], in: context)    // 175 lbs — not a PR if 185 already set... but we seed in order
        makeWorkout(date: daysAgo(40), exercises: [("Bench Press", 3, 5, 83.91)], in: context)    // 185 lbs PR
        makeWorkout(date: daysAgo(20), exercises: [("Bench Press", 3, 5, 93.0)], in: context)     // 205 lbs PR

        let timeline = TrendsChartService.fullPRTimeline(for: "Bench Press", context: context)

        #expect(timeline.count == 5)
        let weights = timeline.map(\.weightKg)
        #expect(weights == weights.sorted())

        #expect(timeline[0].deltaKg > 0)
        #expect(timeline[1].deltaKg > 0)
        #expect(timeline[2].deltaKg > 0)
        #expect(timeline[3].deltaKg > 0)
        #expect(timeline[4].deltaKg > 0)
    }

    @Test func test_fullPRTimeline_singleWorkout_returnsEmpty() throws {
        let context = try makeTestContext()

        makeWorkout(date: daysAgo(30), exercises: [("Bench Press", 3, 5, 100.0)], in: context)

        let timeline = TrendsChartService.fullPRTimeline(for: "Bench Press", context: context)
        #expect(timeline.isEmpty)
    }

    @Test func test_fullPRTimeline_emptyExercise_returnsEmptyArray() throws {
        let context = try makeTestContext()

        let timeline = TrendsChartService.fullPRTimeline(for: "Nonexistent Exercise", context: context)
        #expect(timeline.isEmpty)
    }
}

// MARK: - Breakdown Percentages Tests

@Suite(.serialized)
struct BreakdownPercentagesTests {

    @Test func test_breakdownPercentages_30dRange_returnsCountAndPercentPerType() throws {
        let context = try makeTestContext()

        for i in 0..<5 {
            makeWorkout(date: daysAgo(i + 1), workoutType: "Strength Training", in: context)
        }
        for i in 0..<3 {
            makeWorkout(date: daysAgo(i + 6), workoutType: "HIIT", in: context)
        }
        for i in 0..<2 {
            makeWorkout(date: daysAgo(i + 10), workoutType: "Cardio", in: context)
        }

        let rows = TrendsChartService.breakdownPercentages(range: .thirtyDays, context: context)
        let totalCount = rows.reduce(0) { $0 + $1.count }
        let totalPercent = rows.reduce(0.0) { $0 + $1.percent }

        #expect(totalCount == 10)
        #expect(abs(totalPercent - 100.0) < 0.1)
        #expect(rows.count == 3)
    }

    @Test func test_breakdownPercentages_avgDurationExcludesNilDuration() throws {
        let context = try makeTestContext()

        makeWorkout(date: daysAgo(1), workoutType: "Strength Training", durationMinutes: 60, in: context)
        makeWorkout(date: daysAgo(2), workoutType: "Strength Training", durationMinutes: 40, in: context)
        makeWorkout(date: daysAgo(3), workoutType: "Strength Training", durationMinutes: nil, in: context)

        let rows = TrendsChartService.breakdownPercentages(range: .thirtyDays, context: context)
        let strengthRow = rows.first { $0.type == "Strength Training" }

        #expect(strengthRow != nil)
        #expect(strengthRow?.avgDurationMinutes == 50)
    }
}

// MARK: - Time Range Eligibility Tests

struct TimeRangeEligibilityTests {

    @Test func test_timeRangeEligibility_perChartType() {
        let expected: [String: [DetailTimeRange]] = [
            "strengthTracker": [.thirtyDays, .ninetyDays, .sixMonths, .oneYear, .allTime],
            "trainingFrequency": [.eightWeeks, .sixMonths, .oneYear, .allTime],
            "personalRecords": [.allTime],
            "trainingLoadTrend": [.fourteenDays, .thirtyDays, .ninetyDays, .sixMonths],
            "workoutVolume": [.thirtyDays, .ninetyDays, .sixMonths, .oneYear, .allTime],
            "rpeTrend": [.eightWeeks, .sixMonths, .oneYear, .allTime],
            "workoutTypeBreakdown": [.thirtyDays, .sixtyDays, .ninetyDays, .oneYear, .allTime],
            "sessionDuration": [.eightWeeks, .sixMonths, .oneYear, .allTime]
        ]

        for (chartType, expectedRanges) in expected {
            let actual = DetailTimeRange.eligibleRanges(for: chartType)
            #expect(actual == expectedRanges, "Eligible ranges mismatch for \(chartType)")
        }
    }
}
