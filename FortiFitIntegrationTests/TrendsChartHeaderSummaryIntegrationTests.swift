//
//  TrendsChartHeaderSummaryIntegrationTests.swift
//  FortiFitIntegrationTests
//
//  Cross-service cascade coverage for Phase 6.1 header summary values.
//  XCTest framework. Uses TestFixtures.inMemoryContext() and existing
//  fixtures; mirrors WorkoutCascadeIntegrationTests structure.
//

import XCTest
import SwiftData
@testable import FortiFit

final class TrendsChartHeaderSummaryIntegrationTests: XCTestCase {

    private func weeksAgo(_ n: Int) -> Date {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        let currentWeekStart = Date().startOfWeek
        let weekStart = calendar.date(byAdding: .weekOfYear, value: -n, to: currentWeekStart)!
        return calendar.date(byAdding: .day, value: 2, to: weekStart)!
    }

    // MARK: - Strength Tracker Cascade

    func test_loggingHeavierWorkout_updatesStrengthTrackerHeaderSummary() throws {
        let (_, context) = try TestFixtures.inMemoryContext()
        UserSettings.shared.useLbs = false

        TestFixtures.makeWorkout(
            date: weeksAgo(3),
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 200)],
            in: context
        )
        TestFixtures.makeWorkout(
            date: weeksAgo(2),
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 200)],
            in: context
        )

        let before = TrendsChartService.headerSummary(
            for: "strengthTracker", exerciseName: "Bench Press", context: context
        )
        XCTAssertEqual(before?.hero, "200 kg")

        TestFixtures.logWorkoutWithCascade(
            date: weeksAgo(1),
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 220)],
            in: context
        )

        let after = TrendsChartService.headerSummary(
            for: "strengthTracker", exerciseName: "Bench Press", context: context
        )
        XCTAssertEqual(after?.hero, "220 kg")
    }

    // MARK: - Personal Records Cascade

    func test_deletingMostRecentPR_recomputesPersonalRecordsHeaderSummary() throws {
        let (_, context) = try TestFixtures.inMemoryContext()
        UserSettings.shared.useLbs = false

        TestFixtures.makeWorkout(
            date: weeksAgo(5),
            exercises: [.init("Bench Press", sets: 3, reps: 5, weightKg: 135)],
            in: context
        )
        TestFixtures.makeWorkout(
            date: weeksAgo(3),
            exercises: [.init("Bench Press", sets: 3, reps: 5, weightKg: 155)],
            in: context
        )
        let w185 = TestFixtures.makeWorkout(
            date: weeksAgo(1),
            exercises: [.init("Bench Press", sets: 3, reps: 5, weightKg: 185)],
            in: context
        )

        let before = TrendsChartService.headerSummary(
            for: "personalRecords", exerciseName: "Bench Press", context: context
        )
        XCTAssertNotNil(before)

        TestFixtures.deleteWorkoutWithCascade(w185, in: context)

        let after = TrendsChartService.headerSummary(
            for: "personalRecords", exerciseName: "Bench Press", context: context
        )
        XCTAssertNotNil(after)
        XCTAssertEqual(after?.hero, "+20 kg")
    }

    func test_deletingAllPRs_returnsNilForPersonalRecordsHeaderSummary() throws {
        let (_, context) = try TestFixtures.inMemoryContext()
        UserSettings.shared.useLbs = false

        let w1 = TestFixtures.makeWorkout(
            date: weeksAgo(3),
            exercises: [.init("Bench Press", sets: 3, reps: 5, weightKg: 135)],
            in: context
        )
        let w2 = TestFixtures.makeWorkout(
            date: weeksAgo(1),
            exercises: [.init("Bench Press", sets: 3, reps: 5, weightKg: 155)],
            in: context
        )

        TestFixtures.deleteWorkoutWithCascade(w2, in: context)
        TestFixtures.deleteWorkoutWithCascade(w1, in: context)

        let result = TrendsChartService.headerSummary(
            for: "personalRecords", exerciseName: "Bench Press", context: context
        )
        XCTAssertNil(result)
    }

    // MARK: - Workout Volume Threshold Boundary

    func test_workoutVolume_thresholdBoundary_appearsAtSecondQualifyingWorkout() throws {
        let (_, context) = try TestFixtures.inMemoryContext()

        TestFixtures.makeWorkout(
            date: Date().addingTimeInterval(-86400 * 5),
            exercises: [.init("Bench Press", sets: 3, reps: 10, weightKg: 60)],
            in: context
        )

        let oneWorkout = TrendsChartService.headerSummary(
            for: "workoutVolume", timeRangeDays: 30, context: context
        )
        XCTAssertNil(oneWorkout)

        TestFixtures.logWorkoutWithCascade(
            date: Date().addingTimeInterval(-86400 * 2),
            exercises: [.init("Bench Press", sets: 3, reps: 10, weightKg: 60)],
            in: context
        )

        let twoWorkouts = TrendsChartService.headerSummary(
            for: "workoutVolume", timeRangeDays: 30, context: context
        )
        XCTAssertNotNil(twoWorkouts)
    }

    // MARK: - Workout Type Breakdown Threshold Boundary

    func test_workoutTypeBreakdown_thresholdBoundary_appearsAtSecondWorkout() throws {
        let (_, context) = try TestFixtures.inMemoryContext()

        TestFixtures.makeWorkout(
            date: Date().addingTimeInterval(-86400 * 5),
            in: context
        )

        let oneWorkout = TrendsChartService.headerSummary(
            for: "workoutTypeBreakdown", timeRangeDays: 30, context: context
        )
        XCTAssertNil(oneWorkout)

        TestFixtures.logWorkoutWithCascade(
            date: Date().addingTimeInterval(-86400 * 2),
            in: context
        )

        let twoWorkouts = TrendsChartService.headerSummary(
            for: "workoutTypeBreakdown", timeRangeDays: 30, context: context
        )
        XCTAssertNotNil(twoWorkouts)
        XCTAssertEqual(twoWorkouts?.hero, "2")
    }

    // MARK: - Date Edit Cascade

    func test_editingWorkoutDate_acrossEightWeekBoundary_recomputesAffectedSummaries() throws {
        let (_, context) = try TestFixtures.inMemoryContext()

        for i in 1...4 {
            TestFixtures.makeWorkout(
                date: weeksAgo(i),
                rpe: 7,
                durationMinutes: 40,
                in: context
            )
        }

        let beforeFreq = TrendsChartService.headerSummary(for: "trainingFrequency", context: context)
        XCTAssertNotNil(beforeFreq)

        let allWorkouts = WorkoutService.fetchAll(context: context)
        if let mostRecent = allWorkouts.first {
            TestFixtures.updateWorkoutDate(mostRecent, newDate: weeksAgo(10), in: context)
        }

        let afterFreq = TrendsChartService.headerSummary(for: "trainingFrequency", context: context)
        XCTAssertNotNil(afterFreq)
    }

    // MARK: - Cosmetic Edit

    func test_cosmeticEditOnly_doesNotChangeNumericSummaries() throws {
        let (_, context) = try TestFixtures.inMemoryContext()
        UserSettings.shared.useLbs = false

        TestFixtures.makeWorkout(
            name: "Push Day",
            date: weeksAgo(3),
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 100)],
            in: context
        )
        TestFixtures.makeWorkout(
            name: "Push Day 2",
            date: weeksAgo(2),
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 120)],
            in: context
        )

        let beforeStrength = TrendsChartService.headerSummary(
            for: "strengthTracker", exerciseName: "Bench Press", context: context
        )

        let allWorkouts = WorkoutService.fetchAll(context: context)
        if let first = allWorkouts.first {
            TestFixtures.updateWorkoutName(first, newName: "Renamed Push Day", in: context)
        }

        let afterStrength = TrendsChartService.headerSummary(
            for: "strengthTracker", exerciseName: "Bench Press", context: context
        )
        XCTAssertEqual(beforeStrength?.hero, afterStrength?.hero)
    }
}
