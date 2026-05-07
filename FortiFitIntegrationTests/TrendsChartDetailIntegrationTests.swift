//
//  TrendsChartDetailIntegrationTests.swift
//  FortiFitIntegrationTests
//
//  Cross-service cascade coverage for Phase 6.2 chart detail view data.
//  XCTest framework. Uses TestFixtures.inMemoryContext() and existing fixtures.
//

import XCTest
import SwiftData
@testable import FortiFit

final class TrendsChartDetailIntegrationTests: XCTestCase {

    private func weeksAgo(_ n: Int) -> Date {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        let currentWeekStart = Date().startOfWeek
        let weekStart = calendar.date(byAdding: .weekOfYear, value: -n, to: currentWeekStart)!
        return calendar.date(byAdding: .day, value: 2, to: weekStart)!
    }

    private func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: .now)!
    }

    // MARK: - Comparison Delta Cascade

    func test_loggingWorkout_updatesComparisonDelta() throws {
        let (_, context) = try TestFixtures.inMemoryContext()
        UserSettings.shared.useLbs = false

        TestFixtures.makeWorkout(
            date: daysAgo(120),
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 80)],
            in: context
        )
        TestFixtures.makeWorkout(
            date: daysAgo(100),
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 80)],
            in: context
        )

        TestFixtures.makeWorkout(
            date: daysAgo(10),
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 90)],
            in: context
        )
        TestFixtures.makeWorkout(
            date: daysAgo(5),
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 90)],
            in: context
        )

        let before = TrendsChartService.comparisonDelta(
            for: "strengthTracker",
            exerciseName: "Bench Press",
            range: .ninetyDays,
            context: context
        )
        XCTAssertNotNil(before)
        let beforeDirection = before?.direction

        TestFixtures.logWorkoutWithCascade(
            date: daysAgo(2),
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 100)],
            in: context
        )

        let after = TrendsChartService.comparisonDelta(
            for: "strengthTracker",
            exerciseName: "Bench Press",
            range: .ninetyDays,
            context: context
        )
        XCTAssertNotNil(after)
        XCTAssertNotEqual(before?.hero, after?.hero, "Delta hero should reflect the new heavier workout")
        _ = beforeDirection
    }

    // MARK: - PR Timeline Cascade

    func test_deletingPRWorkout_removesEventFromFullPRTimeline() throws {
        let (_, context) = try TestFixtures.inMemoryContext()

        TestFixtures.makeWorkout(
            date: daysAgo(100),
            exercises: [.init("Bench Press", sets: 3, reps: 5, weightKg: 60)],
            in: context
        )
        TestFixtures.makeWorkout(
            date: daysAgo(80),
            exercises: [.init("Bench Press", sets: 3, reps: 5, weightKg: 70)],
            in: context
        )
        TestFixtures.makeWorkout(
            date: daysAgo(60),
            exercises: [.init("Bench Press", sets: 3, reps: 5, weightKg: 80)],
            in: context
        )
        let mostRecent = TestFixtures.makeWorkout(
            date: daysAgo(40),
            exercises: [.init("Bench Press", sets: 3, reps: 5, weightKg: 90)],
            in: context
        )

        let before = TrendsChartService.fullPRTimeline(for: "Bench Press", context: context)
        XCTAssertEqual(before.count, 4)

        TestFixtures.deleteWorkoutWithCascade(mostRecent, in: context)

        let after = TrendsChartService.fullPRTimeline(for: "Bench Press", context: context)
        XCTAssertEqual(after.count, 3, "Deleting the most recent PR should remove it from timeline")
    }

    // MARK: - Data Points Range Boundary

    func test_editingWorkoutDate_movesPointAcrossRangeBoundary() throws {
        let (_, context) = try TestFixtures.inMemoryContext()
        UserSettings.shared.useLbs = false

        TestFixtures.makeWorkout(
            date: daysAgo(25),
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 80)],
            in: context
        )
        let movable = TestFixtures.makeWorkout(
            date: daysAgo(15),
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 90)],
            in: context
        )

        let before30 = TrendsChartService.dataPoints(
            for: "strengthTracker",
            exerciseName: "Bench Press",
            range: .thirtyDays,
            context: context
        )
        XCTAssertEqual(before30.count, 2)

        TestFixtures.updateWorkoutDate(movable, newDate: daysAgo(45), in: context)

        let after30 = TrendsChartService.dataPoints(
            for: "strengthTracker",
            exerciseName: "Bench Press",
            range: .thirtyDays,
            context: context
        )
        XCTAssertEqual(after30.count, 1, "Moved workout should no longer appear in 30D range")

        let after90 = TrendsChartService.dataPoints(
            for: "strengthTracker",
            exerciseName: "Bench Press",
            range: .ninetyDays,
            context: context
        )
        XCTAssertEqual(after90.count, 2, "Both workouts should appear in 90D range")
    }

    // MARK: - Breakdown Cascade

    func test_workoutCascade_refreshesBreakdownPercentages() throws {
        let (_, context) = try TestFixtures.inMemoryContext()

        TestFixtures.makeWorkout(date: daysAgo(5), workoutType: "Strength Training", in: context)
        TestFixtures.makeWorkout(date: daysAgo(4), workoutType: "HIIT", in: context)

        let before = TrendsChartService.breakdownPercentages(range: .thirtyDays, context: context)
        let beforeCount = before.reduce(0) { $0 + $1.count }
        XCTAssertEqual(beforeCount, 2)

        TestFixtures.logWorkoutWithCascade(
            date: daysAgo(1),
            workoutType: "Cardio",
            in: context
        )

        let after = TrendsChartService.breakdownPercentages(range: .thirtyDays, context: context)
        let afterCount = after.reduce(0) { $0 + $1.count }
        XCTAssertEqual(afterCount, 3, "New workout should appear in breakdown")
        XCTAssertEqual(after.count, 3, "Three distinct workout types")
    }

    // MARK: - Cosmetic Edit

    func test_cosmeticEditOnly_doesNotChangeComparisonDelta() throws {
        let (_, context) = try TestFixtures.inMemoryContext()
        UserSettings.shared.useLbs = false

        TestFixtures.makeWorkout(
            name: "Original Name",
            date: daysAgo(120),
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 80)],
            in: context
        )
        TestFixtures.makeWorkout(
            date: daysAgo(100),
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 80)],
            in: context
        )
        TestFixtures.makeWorkout(
            date: daysAgo(10),
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 100)],
            in: context
        )
        let editable = TestFixtures.makeWorkout(
            name: "Editable",
            date: daysAgo(5),
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 100)],
            in: context
        )

        let before = TrendsChartService.comparisonDelta(
            for: "strengthTracker",
            exerciseName: "Bench Press",
            range: .ninetyDays,
            context: context
        )

        editable.name = "Renamed Workout"
        try? context.save()

        let after = TrendsChartService.comparisonDelta(
            for: "strengthTracker",
            exerciseName: "Bench Press",
            range: .ninetyDays,
            context: context
        )

        XCTAssertEqual(before?.hero, after?.hero, "Cosmetic edit should not change hero")
        XCTAssertEqual(before?.delta, after?.delta, "Cosmetic edit should not change delta")
    }
}
