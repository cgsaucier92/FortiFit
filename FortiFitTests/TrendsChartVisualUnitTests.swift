import Testing
import Foundation
import SwiftData
import SwiftUI
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

private func weeksAgo(_ n: Int) -> Date {
    var calendar = Calendar(identifier: .iso8601)
    calendar.firstWeekday = 2
    let currentWeekStart = Date().startOfWeek
    let weekStart = calendar.date(byAdding: .weekOfYear, value: -n, to: currentWeekStart)!
    return calendar.date(byAdding: .day, value: 2, to: weekStart)!
}

// MARK: - Color Token Tests

struct ChartColorTokenTests {

    @Test func test_chartOrangeToken_equalsFFBF51() {
        let expected = Color(hex: "FFBF51")
        #expect(FortiFitColors.chartOrange == expected)
    }
}

// MARK: - Gradient Anchor Tests

struct ChartGradientAnchorTests {

    @Test func test_chartGradientAnchor_singleColorCharts_returnDocumentedAnchor() {
        let singleColorCharts: [(String, Color)] = [
            ("strengthTracker", FortiFitColors.chartPink),
            ("trainingFrequency", FortiFitColors.positive),
            ("trainingLoadTrend", FortiFitColors.primaryAccent),
            ("workoutVolume", FortiFitColors.chartPurple),
            ("rpeTrend", FortiFitColors.chartOrange),
            ("workoutTypeBreakdown", FortiFitColors.primaryAccent),
            ("sessionDuration", FortiFitColors.chartTeal),
        ]

        for (chartType, expectedColor) in singleColorCharts {
            let anchor = AppConstants.chartGradientAnchor(for: chartType)
            if case .single(let color) = anchor {
                #expect(color == expectedColor, "Mismatch for \(chartType)")
            } else {
                Issue.record("Expected .single for \(chartType)")
            }
        }
    }

    @Test func test_chartGradientAnchor_personalRecords_returnsHorizontalSplit() {
        let anchor = AppConstants.chartGradientAnchor(for: "personalRecords")
        if case .horizontalSplit(let leading, let trailing) = anchor {
            #expect(leading == FortiFitColors.chartLightCyan)
            #expect(trailing == FortiFitColors.chartDeepBlue)
        } else {
            Issue.record("Expected .horizontalSplit for personalRecords")
        }
    }
}

// MARK: - Header Summary Tests

@Suite(.serialized)
struct HeaderSummaryTests {

    // MARK: - Below Threshold

    @Test func test_headerSummary_belowThreshold_returnsNil() throws {
        let context = try makeTestContext()
        for chartType in AppConstants.trendsChartTypes {
            let result = TrendsChartService.headerSummary(
                for: chartType,
                exerciseName: chartType == "strengthTracker" || chartType == "personalRecords" ? "Bench Press" : nil,
                context: context
            )
            #expect(result == nil, "Expected nil for \(chartType) with no data")
        }
    }

    // MARK: - Strength Tracker

    @Test func test_headerSummary_strengthTracker_returnsLatestWeightWithUnit_lbs() throws {
        let context = try makeTestContext()
        UserSettings.shared.useLbs = true

        makeWorkout(date: weeksAgo(3), exercises: [("Bench Press", 3, 8, 100)], in: context)
        makeWorkout(date: weeksAgo(2), exercises: [("Bench Press", 3, 8, 150)], in: context)
        makeWorkout(date: weeksAgo(1), exercises: [("Bench Press", 3, 8, 200)], in: context)

        let result = TrendsChartService.headerSummary(
            for: "strengthTracker", exerciseName: "Bench Press", context: context
        )
        #expect(result != nil)
        #expect(result?.hero == "441 lbs")
        #expect(result?.caption == AppConstants.Trends.captionLatest)
    }

    @Test func test_headerSummary_strengthTracker_returnsLatestWeightWithUnit_kg() throws {
        let context = try makeTestContext()
        UserSettings.shared.useLbs = false

        makeWorkout(date: weeksAgo(3), exercises: [("Bench Press", 3, 8, 100)], in: context)
        makeWorkout(date: weeksAgo(2), exercises: [("Bench Press", 3, 8, 150)], in: context)
        makeWorkout(date: weeksAgo(1), exercises: [("Bench Press", 3, 8, 200)], in: context)

        let result = TrendsChartService.headerSummary(
            for: "strengthTracker", exerciseName: "Bench Press", context: context
        )
        #expect(result != nil)
        #expect(result?.hero == "200 kg")
        #expect(result?.caption == AppConstants.Trends.captionLatest)
    }

    // MARK: - Training Frequency

    @Test func test_headerSummary_trainingFrequency_returnsAvgPerWeekOneDecimal() throws {
        let context = try makeTestContext()
        let counts = [3, 2, 4, 3, 3, 2, 4]
        for (i, count) in counts.enumerated() {
            for j in 0..<count {
                var calendar = Calendar(identifier: .iso8601)
                calendar.firstWeekday = 2
                let weekStart = calendar.date(byAdding: .weekOfYear, value: -(i + 1), to: Date().startOfWeek)!
                let dayOffset = j % 7
                let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
                makeWorkout(date: date, in: context)
            }
        }

        let result = TrendsChartService.headerSummary(for: "trainingFrequency", context: context)
        #expect(result != nil)
        #expect(result?.hero == "3.0")
        #expect(result?.caption == AppConstants.Trends.captionAvgLast8Weeks)
    }

    // MARK: - Personal Records

    @Test func test_headerSummary_personalRecords_returnsDeltaWithUnit() throws {
        let context = try makeTestContext()
        UserSettings.shared.useLbs = true

        makeWorkout(date: weeksAgo(3), exercises: [("Bench Press", 3, 8, 61.235)], in: context)
        makeWorkout(date: weeksAgo(1), exercises: [("Bench Press", 3, 8, 70.308)], in: context)

        let result = TrendsChartService.headerSummary(
            for: "personalRecords", exerciseName: "Bench Press", context: context
        )
        #expect(result != nil)
        let deltaKg = 70.308 - 61.235
        let deltaLbs = Int((deltaKg * UnitConversion.kgToLbsFactor).rounded())
        #expect(result?.hero == "+\(deltaLbs) lbs")
        #expect(result?.caption == AppConstants.Trends.captionLatestPR)
    }

    @Test func test_headerSummary_personalRecords_multipleEvents_usesLatestTwo() throws {
        let context = try makeTestContext()
        UserSettings.shared.useLbs = true

        makeWorkout(date: weeksAgo(5), exercises: [("Bench Press", 3, 5, 61.235)], in: context)
        makeWorkout(date: weeksAgo(3), exercises: [("Bench Press", 3, 5, 70.308)], in: context)
        makeWorkout(date: weeksAgo(1), exercises: [("Bench Press", 3, 5, 83.915)], in: context)

        let result = TrendsChartService.headerSummary(
            for: "personalRecords", exerciseName: "Bench Press", context: context
        )
        #expect(result != nil)
        let deltaKg = 83.915 - 70.308
        let deltaLbs = Int((deltaKg * UnitConversion.kgToLbsFactor).rounded())
        #expect(result?.hero == "+\(deltaLbs) lbs")
    }

    // MARK: - Training Load Trend

    @Test func test_headerSummary_trainingLoadTrend_returnsTodaysScoreInteger() throws {
        let context = try makeTestContext()
        let cal = Calendar.current

        for daysAgo in [1, 3, 5, 7, 9] {
            let date = cal.date(byAdding: .day, value: -daysAgo, to: Date())!
            makeWorkout(date: date, rpe: 7, durationMinutes: 60, exercises: [("Squats", 4, 8, 100)], in: context)
        }

        let result = TrendsChartService.headerSummary(for: "trainingLoadTrend", context: context)
        #expect(result != nil)
        #expect(result?.caption == AppConstants.Trends.captionToday)
        if let hero = result?.hero, let val = Int(hero) {
            #expect(val >= 0 && val <= 100)
        } else {
            Issue.record("Hero should be a valid integer")
        }
    }

    // MARK: - Workout Volume

    @Test func test_headerSummary_workoutVolume_formatsKSuffix() throws {
        let context = try makeTestContext()
        UserSettings.shared.useLbs = true

        makeWorkout(
            date: Date().addingTimeInterval(-86400 * 5),
            exercises: [("Bench Press", 3, 10, 68.04)],
            in: context
        )
        makeWorkout(
            date: Date().addingTimeInterval(-86400 * 2),
            exercises: [("Bench Press", 3, 10, 68.04)],
            in: context
        )

        let result = TrendsChartService.headerSummary(
            for: "workoutVolume", timeRangeDays: 30, context: context
        )
        #expect(result != nil)
        #expect(result?.caption == AppConstants.Trends.captionAvgPerSession)
        #expect(result?.hero.contains("lbs") == true)
    }

    // MARK: - RPE Trend

    @Test func test_headerSummary_rpeTrend_returnsAvgOneDecimal() throws {
        let context = try makeTestContext()
        let rpeValues = [5, 6, 7, 6, 8, 7, 5, 7]

        for (i, rpe) in rpeValues.enumerated() {
            makeWorkout(date: weeksAgo(i + 1), rpe: rpe, in: context)
        }

        let result = TrendsChartService.headerSummary(for: "rpeTrend", context: context)
        #expect(result != nil)
        #expect(result?.caption == AppConstants.Trends.captionAvgLast8Weeks)
        if let hero = result?.hero, let val = Double(hero) {
            #expect(val > 0 && val <= 10)
        }
    }

    @Test func test_headerSummary_rpeTrend_excludesNilRpe() throws {
        let context = try makeTestContext()

        makeWorkout(date: weeksAgo(2), rpe: 8, in: context)
        makeWorkout(date: weeksAgo(2), rpe: nil, in: context)
        makeWorkout(date: weeksAgo(2), rpe: 6, in: context)

        let result = TrendsChartService.headerSummary(for: "rpeTrend", context: context)
        #expect(result != nil)
        #expect(result?.hero == "7.0")
    }

    // MARK: - Workout Type Breakdown

    @Test func test_headerSummary_workoutTypeBreakdown_returnsTotalCount_30D() throws {
        let context = try makeTestContext()

        for i in 0..<12 {
            makeWorkout(date: Date().addingTimeInterval(-86400 * Double(i + 1)), in: context)
        }
        for i in 0..<5 {
            makeWorkout(date: Date().addingTimeInterval(-86400 * Double(40 + i)), in: context)
        }

        let result = TrendsChartService.headerSummary(
            for: "workoutTypeBreakdown", timeRangeDays: 30, context: context
        )
        #expect(result != nil)
        #expect(result?.hero == "12")
        #expect(result?.caption == AppConstants.Trends.captionWorkouts)
    }

    // MARK: - Session Duration

    @Test func test_headerSummary_sessionDuration_excludesNilDuration() throws {
        let context = try makeTestContext()

        makeWorkout(date: weeksAgo(2), durationMinutes: 40, in: context)
        makeWorkout(date: weeksAgo(2), durationMinutes: nil, in: context)
        makeWorkout(date: weeksAgo(2), durationMinutes: 50, in: context)

        let result = TrendsChartService.headerSummary(for: "sessionDuration", context: context)
        #expect(result != nil)
        #expect(result?.hero == "45 min")
    }

    @Test func test_headerSummary_sessionDuration_returnsAvgMinutes() throws {
        let context = try makeTestContext()
        let durations = [30, 35, 40, 45, 30, 35, 40, 36]

        for (i, dur) in durations.enumerated() {
            makeWorkout(date: weeksAgo(i + 1), durationMinutes: dur, in: context)
        }

        let result = TrendsChartService.headerSummary(for: "sessionDuration", context: context)
        #expect(result != nil)
        #expect(result?.caption == AppConstants.Trends.captionAvgPerSession)
        let expectedAvg = Double(durations.reduce(0, +)) / Double(durations.count)
        #expect(result?.hero == "\(Int(expectedAvg.rounded())) min")
    }
}
