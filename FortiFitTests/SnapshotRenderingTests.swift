import Testing
import Foundation
import SwiftData
@testable import FortiFit

private func makeSnapshotRenderingContext() throws -> ModelContext {
    let schema = Schema([
        Workout.self,
        ExerciseSet.self,
        Goal.self,
        GoalSnapshot.self,
        WorkoutTypeOrder.self,
        DailySleepSnapshot.self,
        DailyTrainingLoadSnapshot.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

// MARK: - fourteenDayDailyScores prefers snapshots for historical days

@MainActor
struct FourteenDayDailyScoresSnapshotTests {

    @Test func historicalDaysPreferStoredSnapshot() throws {
        let context = try makeSnapshotRenderingContext()
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        // Seed snapshots for the last 14 days (skipping today).
        for offset in 1..<14 {
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            _ = ExerciseLoadService.captureDailySnapshot(
                date: day,
                score: 50 + offset,
                wasSleepAdjusted: offset.isMultiple(of: 2),
                context: context
            )
        }

        let results = ExerciseLoadService.fourteenDayDailyScores(context: context, now: now)
        // 14 entries, oldest first.
        #expect(results.count == 14)

        // Historical scores should match the seeded snapshot values.
        for (index, daily) in results.enumerated() {
            let offset = 13 - index // newest index = today
            if offset == 0 {
                // Today — live recompute; with no workouts the score should be 0.
                #expect(daily.score == 0)
            } else {
                #expect(daily.score == 50 + offset, "Snapshot at offset \(offset) should be preserved exactly")
            }
        }
    }

    @Test func todayIsAlwaysLiveAndNotFromSnapshot() throws {
        let context = try makeSnapshotRenderingContext()
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        // Seed a clearly-wrong snapshot for today.
        _ = ExerciseLoadService.captureDailySnapshot(
            date: today,
            score: 99,
            wasSleepAdjusted: false,
            context: context
        )

        // No workouts → live recompute yields 0, not 99.
        let results = ExerciseLoadService.fourteenDayDailyScores(context: context, now: now)
        let todayResult = results.last
        #expect(todayResult?.score == 0)
    }

    @Test func preFeatureLaunchDaysFallBackToBaselineCompute() throws {
        let context = try makeSnapshotRenderingContext()
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        // No snapshots seeded — every historical day should fall back to live recompute.
        let results = ExerciseLoadService.fourteenDayDailyScores(context: context, now: now)
        #expect(results.count == 14)
        // With no workouts at all, every day's baseline recompute is 0.
        for daily in results {
            #expect(daily.score == 0)
        }
        // The first entry must be 14 days ago in oldest-first ordering.
        if let first = results.first {
            let expectedFirstDay = calendar.date(byAdding: .day, value: -13, to: today) ?? today
            #expect(calendar.isDate(first.date, inSameDayAs: expectedFirstDay))
        }
    }

    // MARK: - BUG-067: Linked path passes sleep map → today's entry must match the
    // sleep-adjusted hero, not the baseline `calculateLoad` result.

    /// BUG-067 regression: when the linked detail sheet passes a real sleep snapshot
    /// map into `fourteenDayDailyScores`, today's data point must equal the rounded
    /// `computeCurrentScore` result (the sleep-adjusted path), NOT the baseline
    /// `calculateLoad`. Previously the chart's latest dot showed the baseline value
    /// while the header hero showed the sleep-adjusted value — they could differ by
    /// several points on a sub-target sleep night.
    @Test func test_fourteenDayDailyScores_withSleepMap_todayMatchesComputeCurrentScore() throws {
        let context = try makeSnapshotRenderingContext()
        let calendar = Calendar.current
        let now = Date()

        // Insert a workout 2 days ago so the decay loop has intervening days where the
        // sub-target sleep factor can take effect.
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now) ?? now
        let workout = Workout(
            name: "Heavy Day",
            date: twoDaysAgo,
            workoutType: "Strength Training",
            rpe: 8,
            durationMinutes: 60
        )
        let set = ExerciseSet(exerciseName: "Squat", sets: 5, reps: 5, weightKg: 120)
        workout.exerciseSets.append(set)
        context.insert(workout)
        try context.save()

        // Build a sub-target sleep map: 4h on every intervening day → sleepFactor < 1.
        var sleepMap: [Date: DailySleepSnapshot] = [:]
        for offset in 0...10 {
            let day = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -offset, to: now) ?? now)
            sleepMap[day] = DailySleepSnapshot(wakeUpDate: day, totalSleepMinutes: 240)
        }

        let settings = UserSettings.shared
        let windowWorkouts = WorkoutService.fetchWorkouts(
            from: calendar.date(byAdding: .day, value: -10, to: now) ?? now,
            to: now,
            context: context
        )

        let expectedHero = ExerciseLoadService.computeCurrentScore(
            workouts: windowWorkouts,
            sleepSnapshotsByDay: sleepMap,
            targetSleepHours: settings.targetSleepHours,
            experienceLevel: settings.experienceLevel,
            targetMinutesPerWorkout: settings.targetMinutesPerWorkout,
            now: now
        )
        let baselineHero = ExerciseLoadService.calculateLoad(
            workouts: windowWorkouts,
            experienceLevel: settings.experienceLevel,
            targetMinutesPerWorkout: settings.targetMinutesPerWorkout,
            now: now
        )

        let results = ExerciseLoadService.fourteenDayDailyScores(
            context: context,
            sleepSnapshotsByDay: sleepMap,
            targetSleepHours: settings.targetSleepHours,
            now: now
        )
        #expect(results.last?.score == Int(expectedHero.score.rounded()),
                "Today's data point must equal the sleep-adjusted hero score")
        // The setup must produce divergent values so the contract is actually exercised
        // (if the algorithms agreed, the test would pass trivially).
        #expect(Int(expectedHero.score.rounded()) != Int(baselineHero.score.rounded()),
                "Test setup must produce divergent sleep-adjusted vs baseline scores")
    }

    /// BUG-067 regression: when no sleep map is passed (unlinked TL detail sheet path),
    /// today's data point must equal `computeCurrentScore` with an empty sleep map —
    /// the unified sleep-blind path that the home widget bar, the unlinked TL detail
    /// sheet hero, and the chip baseline all share. This makes the chart's latest dot
    /// equal to the hero on every unlinked surface.
    @Test func test_fourteenDayDailyScores_withoutSleepMap_todayMatchesUnifiedBaseline() throws {
        let context = try makeSnapshotRenderingContext()
        let calendar = Calendar.current
        let now = Date()

        let oneDayAgo = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let workout = Workout(
            name: "Light Day",
            date: oneDayAgo,
            workoutType: "Strength Training",
            rpe: 7,
            durationMinutes: 45
        )
        let set = ExerciseSet(exerciseName: "Bench", sets: 4, reps: 8, weightKg: 80)
        workout.exerciseSets.append(set)
        context.insert(workout)
        try context.save()

        let settings = UserSettings.shared
        let windowWorkouts = WorkoutService.fetchWorkouts(
            from: calendar.date(byAdding: .day, value: -10, to: now) ?? now,
            to: now,
            context: context
        )
        let unifiedBaseline = ExerciseLoadService.computeCurrentScore(
            workouts: windowWorkouts,
            sleepSnapshotsByDay: [:],
            targetSleepHours: settings.targetSleepHours,
            experienceLevel: settings.experienceLevel,
            targetMinutesPerWorkout: settings.targetMinutesPerWorkout,
            now: now
        )

        let results = ExerciseLoadService.fourteenDayDailyScores(context: context, now: now)
        #expect(results.last?.score == Int(unifiedBaseline.score.rounded()),
                "Without a sleep map, today's entry must match the unified empty-map computeCurrentScore result")
    }
}

// MARK: - Backdated invalidation

@MainActor
struct BackdatedInvalidationTests {

    @Test func invalidatesSnapshotsWithinPlusOrMinus14Days() throws {
        let context = try makeSnapshotRenderingContext()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Seed snapshots: 5 days ago, 10 days ago, 20 days ago.
        let day5 = calendar.date(byAdding: .day, value: -5, to: today)!
        let day10 = calendar.date(byAdding: .day, value: -10, to: today)!
        let day20 = calendar.date(byAdding: .day, value: -20, to: today)!
        _ = ExerciseLoadService.captureDailySnapshot(date: day5, score: 50, wasSleepAdjusted: false, context: context)
        _ = ExerciseLoadService.captureDailySnapshot(date: day10, score: 40, wasSleepAdjusted: false, context: context)
        _ = ExerciseLoadService.captureDailySnapshot(date: day20, score: 30, wasSleepAdjusted: false, context: context)

        // A workout edit at day 10 affects all snapshots within ±14 days of day 10
        // → day 5 (within), day 10 (within), day 20 (within 14 of day 10 = days 24…+4).
        // Note: day20 is 10 days BEFORE day10 — within range. Should also be invalidated.
        ExerciseLoadService.invalidateSnapshotsAroundDate(day10, context: context)

        let remaining = try context.fetch(FetchDescriptor<DailyTrainingLoadSnapshot>())
        #expect(remaining.count == 0, "All three snapshots are within ±14 days of day-10 and should be deleted")
    }

    @Test func doesNotInvalidateSnapshotsOutsideWindow() throws {
        let context = try makeSnapshotRenderingContext()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let day10 = calendar.date(byAdding: .day, value: -10, to: today)!
        let day40 = calendar.date(byAdding: .day, value: -40, to: today)!

        _ = ExerciseLoadService.captureDailySnapshot(date: day10, score: 50, wasSleepAdjusted: false, context: context)
        _ = ExerciseLoadService.captureDailySnapshot(date: day40, score: 30, wasSleepAdjusted: false, context: context)

        // Invalidate around day 10 → day 40 is OUTSIDE the ±14 window.
        ExerciseLoadService.invalidateSnapshotsAroundDate(day10, context: context)

        let remaining = try context.fetch(FetchDescriptor<DailyTrainingLoadSnapshot>())
        #expect(remaining.count == 1)
        #expect(calendar.isDate(remaining.first!.date, inSameDayAs: day40))
    }

    @Test func todaysSnapshotIsNeverDeletedByInvalidation() throws {
        let context = try makeSnapshotRenderingContext()
        let today = Calendar.current.startOfDay(for: Date())

        _ = ExerciseLoadService.captureDailySnapshot(date: today, score: 60, wasSleepAdjusted: false, context: context)

        // Invalidate around today — historical days are wiped, today is preserved
        // because `captureTodaySnapshot` will rewrite it after the cascade.
        ExerciseLoadService.invalidateSnapshotsAroundDate(today, context: context)

        let remaining = try context.fetch(FetchDescriptor<DailyTrainingLoadSnapshot>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.score == 60)
    }
}

// MARK: - Training Load See Info copy now mentions Linking with Recovery Status

struct TrainingLoadSeeInfoLinkingTests {

    @Test func trainingLoadCopyIncludesLinkingSection() {
        let copy = AppConstants.widgetInfoModalCopy["trainingLoad"]
        let hasLinkingSection = copy?.sections.contains(where: { $0.heading == "Linking with Recovery Status" }) ?? false
        #expect(hasLinkingSection)
    }

    @Test func trainingLoadTrendChartCopyIncludesCalculationSection() {
        let copy = AppConstants.chartInfoModalCopy["trainingLoadTrend"]
        let hasCalculationSection = copy?.sections.contains(where: { $0.heading == "About this chart's calculation" }) ?? false
        #expect(hasCalculationSection)
    }

    @Test func trainingLoadTrendCalculationSectionMentionsRecoveryStatus() {
        let copy = AppConstants.chartInfoModalCopy["trainingLoadTrend"]
        let calculationSection = copy?.sections.first(where: { $0.heading == "About this chart's calculation" })
        #expect(calculationSection?.body.contains("Recovery Status") == true)
    }
}

// `SleepQualifierCompositionTests` removed per BUG-061. The qualifier-only API
// (`computeSleepQualifier(...)`) has been replaced with the joint-advisory API
// (`computeLinkedAdvisory(...)`). Coverage now lives in
// `RecoveryStatusAlgorithmTests.LinkedAdvisoryTests`.
