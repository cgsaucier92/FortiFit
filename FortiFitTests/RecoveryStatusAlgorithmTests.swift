import Testing
import Foundation
import SwiftData
@testable import FortiFit

// MARK: - Test context helper (full Phase 11 schema)

private func makeAlgorithmContext() throws -> ModelContext {
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

private func daysAgo(_ n: Int, now: Date = Date()) -> Date {
    Calendar.current.date(byAdding: .day, value: -n, to: now) ?? now
}

// MARK: - sleepFactor boundaries

struct SleepFactorBoundaryTests {

    @Test func ratioAtOrAboveTargetReturnsOne() {
        #expect(ExerciseLoadService.sleepFactor(sleepRatio: 1.0) == 1.0)
        #expect(ExerciseLoadService.sleepFactor(sleepRatio: 1.5) == 1.0)
    }

    @Test func ratioOf0Point5Returns0Point8() {
        // 0.60 + 0.40 × 0.5 = 0.80
        let factor = ExerciseLoadService.sleepFactor(sleepRatio: 0.5)
        #expect(abs(factor - 0.80) < 0.0001)
    }

    @Test func ratioOf0Point85Returns0Point94() {
        // 0.60 + 0.40 × 0.85 = 0.94
        let factor = ExerciseLoadService.sleepFactor(sleepRatio: 0.85)
        #expect(abs(factor - 0.94) < 0.0001)
    }

    @Test func ratioAtZeroOrBelowFloorsAt0Point6() {
        #expect(ExerciseLoadService.sleepFactor(sleepRatio: 0.0) == 0.60)
        #expect(ExerciseLoadService.sleepFactor(sleepRatio: -1.0) == 0.60)
    }
}

// MARK: - computeCurrentScore: sleep-adjusted decay

@MainActor
struct ComputeCurrentScoreTests {

    private func loggedWorkout(daysAgo offset: Int, context: ModelContext, now: Date = Date()) -> Workout {
        let date = Calendar.current.date(byAdding: .day, value: -offset, to: now) ?? now
        let workout = Workout(
            name: "Test Workout",
            date: date,
            workoutType: "Strength Training",
            rpe: 7,
            durationMinutes: 60
        )
        // Give it a few exercise sets so it isn't filtered as empty.
        let set = ExerciseSet(exerciseName: "Bench Press", sets: 4, reps: 5, weightKg: 80)
        workout.exerciseSets.append(set)
        context.insert(workout)
        return workout
    }

    @Test func nilSleepDataPathMatchesBaselineCalculateLoad() throws {
        let context = try makeAlgorithmContext()
        let now = Date()
        _ = loggedWorkout(daysAgo: 1, context: context, now: now)
        _ = loggedWorkout(daysAgo: 3, context: context, now: now)
        try context.save()

        let workouts = WorkoutService.fetchWorkouts(from: daysAgo(10, now: now), to: now, context: context)
        let baseline = ExerciseLoadService.calculateLoad(
            workouts: workouts,
            experienceLevel: 1,
            targetMinutesPerWorkout: 45,
            now: now
        )
        let nilPath = ExerciseLoadService.computeCurrentScore(
            workouts: workouts,
            sleepSnapshotsByDay: nil,
            targetSleepHours: 7.0,
            experienceLevel: 1,
            targetMinutesPerWorkout: 45,
            now: now
        )
        // Same code path with identical `now` — exact equality.
        #expect(baseline.score == nilPath.score)
        #expect(baseline.zone == nilPath.zone)
    }

    @Test func belowTargetSleepProducesHigherScoreThanBaseline() throws {
        let context = try makeAlgorithmContext()
        let now = Date()
        _ = loggedWorkout(daysAgo: 3, context: context, now: now)
        _ = loggedWorkout(daysAgo: 5, context: context, now: now)
        try context.save()

        let workouts = WorkoutService.fetchWorkouts(from: daysAgo(10, now: now), to: now, context: context)

        // Build a snapshot map showing severely below-target sleep on every intervening day.
        let calendar = Calendar.current
        var snapshotMap: [Date: DailySleepSnapshot] = [:]
        for offset in 0...10 {
            let day = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -offset, to: now) ?? now)
            let snap = DailySleepSnapshot(wakeUpDate: day, totalSleepMinutes: 180) // 3h sleep / 7h target ≈ 0.43
            snapshotMap[day] = snap
        }

        let baseline = ExerciseLoadService.calculateLoad(
            workouts: workouts,
            experienceLevel: 1,
            targetMinutesPerWorkout: 45,
            now: now
        )
        let linked = ExerciseLoadService.computeCurrentScore(
            workouts: workouts,
            sleepSnapshotsByDay: snapshotMap,
            targetSleepHours: 7.0,
            experienceLevel: 1,
            targetMinutesPerWorkout: 45,
            now: now
        )
        #expect(linked.score > baseline.score, "Below-target sleep should slow decay → higher accumulated stress score")
    }

    @Test func metTargetSleepApproximatelyMatchesBaseline() throws {
        let context = try makeAlgorithmContext()
        let now = Date()
        _ = loggedWorkout(daysAgo: 3, context: context, now: now)
        _ = loggedWorkout(daysAgo: 5, context: context, now: now)
        try context.save()

        let workouts = WorkoutService.fetchWorkouts(from: daysAgo(10, now: now), to: now, context: context)

        // Sleep met target on every day.
        let calendar = Calendar.current
        var snapshotMap: [Date: DailySleepSnapshot] = [:]
        for offset in 0...10 {
            let day = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -offset, to: now) ?? now)
            snapshotMap[day] = DailySleepSnapshot(wakeUpDate: day, totalSleepMinutes: 7 * 60)
        }

        let baseline = ExerciseLoadService.calculateLoad(
            workouts: workouts,
            experienceLevel: 1,
            targetMinutesPerWorkout: 45,
            now: now
        )
        let linked = ExerciseLoadService.computeCurrentScore(
            workouts: workouts,
            sleepSnapshotsByDay: snapshotMap,
            targetSleepHours: 7.0,
            experienceLevel: 1,
            targetMinutesPerWorkout: 45,
            now: now
        )
        // Discrete day-step vs continuous decay → small rounding error acceptable.
        #expect(abs(linked.score - baseline.score) <= 3,
                "Met-target sleep should produce ~same score as baseline (continuous vs discrete decay drift only)")
    }

    @Test func missingSnapshotFallsBackToBaselineForThatDay() throws {
        let context = try makeAlgorithmContext()
        let now = Date()
        _ = loggedWorkout(daysAgo: 5, context: context, now: now)
        try context.save()

        let workouts = WorkoutService.fetchWorkouts(from: daysAgo(10, now: now), to: now, context: context)
        // Pass an empty snapshot map → every day uses sleepFactor=1.0 (baseline).
        let linked = ExerciseLoadService.computeCurrentScore(
            workouts: workouts,
            sleepSnapshotsByDay: [:],
            targetSleepHours: 7.0,
            experienceLevel: 1,
            targetMinutesPerWorkout: 45,
            now: now
        )
        let baseline = ExerciseLoadService.calculateLoad(
            workouts: workouts,
            experienceLevel: 1,
            targetMinutesPerWorkout: 45,
            now: now
        )
        // Both should be close — missing-data fallback preserves baseline behavior.
        #expect(abs(linked.score - baseline.score) <= 3)
    }
}

// MARK: - Sleep Impact Chip baseline (BUG-063 regression)

/// Regression coverage for BUG-063: the `sleepImpactChip` was comparing
/// `computeCurrentScore` (discrete-day-step, sleep-aware) against `calculateLoad`
/// (continuous-time, sleep-blind), so the delta conflated *actual* sleep impact
/// with a decay-shape discretization artifact. The fix is to have the chip's
/// baseline also call `computeCurrentScore` with an empty snapshot map (every day
/// falls through to `sleepFactor = 1.0`), so both sides share the same decay shape
/// and the delta isolates the per-day sleep variation. These tests pin the contract
/// the chip's new baseline computation depends on.
@MainActor
struct SleepImpactChipBaselineTests {

    private func loggedWorkout(daysAgo offset: Int, rpe: Int = 7, durationMinutes: Int = 60, sets: Int = 4, context: ModelContext, now: Date = Date()) -> Workout {
        let date = Calendar.current.date(byAdding: .day, value: -offset, to: now) ?? now
        let workout = Workout(
            name: "Test Workout",
            date: date,
            workoutType: "Strength Training",
            rpe: rpe,
            durationMinutes: durationMinutes
        )
        let set = ExerciseSet(exerciseName: "Bench Press", sets: sets, reps: 5, weightKg: 80)
        workout.exerciseSets.append(set)
        context.insert(workout)
        return workout
    }

    private func atTargetSnapshotMap(for now: Date, targetSleepHours: Double = 7.0) -> [Date: DailySleepSnapshot] {
        let calendar = Calendar.current
        var map: [Date: DailySleepSnapshot] = [:]
        for offset in 0...10 {
            let day = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -offset, to: now) ?? now)
            map[day] = DailySleepSnapshot(wakeUpDate: day, totalSleepMinutes: Int(targetSleepHours * 60))
        }
        return map
    }

    @Test func test_sleepImpactChip_atTargetSleep_returnsZeroDelta() throws {
        let context = try makeAlgorithmContext()
        let now = Date()
        _ = loggedWorkout(daysAgo: 1, context: context, now: now)
        _ = loggedWorkout(daysAgo: 3, context: context, now: now)
        try context.save()

        let workouts = WorkoutService.fetchWorkouts(from: daysAgo(10, now: now), to: now, context: context)
        let atTargetMap = atTargetSnapshotMap(for: now)

        let baseline = ExerciseLoadService.computeCurrentScore(
            workouts: workouts,
            sleepSnapshotsByDay: [:],
            targetSleepHours: 7.0,
            experienceLevel: 1,
            targetMinutesPerWorkout: 45,
            now: now
        )
        let linked = ExerciseLoadService.computeCurrentScore(
            workouts: workouts,
            sleepSnapshotsByDay: atTargetMap,
            targetSleepHours: 7.0,
            experienceLevel: 1,
            targetMinutesPerWorkout: 45,
            now: now
        )
        #expect(linked.score == baseline.score,
                "At-target sleep on every day must produce delta = 0 (no discretization drift)")
    }

    @Test func test_sleepImpactChip_belowTargetSleep_returnsPositiveDelta() throws {
        let context = try makeAlgorithmContext()
        let now = Date()
        _ = loggedWorkout(daysAgo: 3, context: context, now: now)
        _ = loggedWorkout(daysAgo: 5, context: context, now: now)
        try context.save()

        let workouts = WorkoutService.fetchWorkouts(from: daysAgo(10, now: now), to: now, context: context)
        let calendar = Calendar.current
        var snapshotMap: [Date: DailySleepSnapshot] = [:]
        for offset in 0...10 {
            let day = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -offset, to: now) ?? now)
            snapshotMap[day] = DailySleepSnapshot(wakeUpDate: day, totalSleepMinutes: 240) // 4h vs 7h target
        }

        let baseline = ExerciseLoadService.computeCurrentScore(
            workouts: workouts,
            sleepSnapshotsByDay: [:],
            targetSleepHours: 7.0,
            experienceLevel: 1,
            targetMinutesPerWorkout: 45,
            now: now
        )
        let linked = ExerciseLoadService.computeCurrentScore(
            workouts: workouts,
            sleepSnapshotsByDay: snapshotMap,
            targetSleepHours: 7.0,
            experienceLevel: 1,
            targetMinutesPerWorkout: 45,
            now: now
        )
        #expect(linked.score > baseline.score,
                "Sub-target sleep slows decay → linked must retain strictly more stress than the at-target baseline")
    }

    @Test func test_sleepImpactChip_aboveTargetSleep_returnsZeroDelta() throws {
        let context = try makeAlgorithmContext()
        let now = Date()
        _ = loggedWorkout(daysAgo: 1, context: context, now: now)
        _ = loggedWorkout(daysAgo: 3, context: context, now: now)
        try context.save()

        let workouts = WorkoutService.fetchWorkouts(from: daysAgo(10, now: now), to: now, context: context)
        let calendar = Calendar.current
        var snapshotMap: [Date: DailySleepSnapshot] = [:]
        for offset in 0...10 {
            let day = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -offset, to: now) ?? now)
            snapshotMap[day] = DailySleepSnapshot(wakeUpDate: day, totalSleepMinutes: 10 * 60) // 10h vs 7h target
        }

        let baseline = ExerciseLoadService.computeCurrentScore(
            workouts: workouts,
            sleepSnapshotsByDay: [:],
            targetSleepHours: 7.0,
            experienceLevel: 1,
            targetMinutesPerWorkout: 45,
            now: now
        )
        let linked = ExerciseLoadService.computeCurrentScore(
            workouts: workouts,
            sleepSnapshotsByDay: snapshotMap,
            targetSleepHours: 7.0,
            experienceLevel: 1,
            targetMinutesPerWorkout: 45,
            now: now
        )
        #expect(linked.score == baseline.score,
                "Above-target sleep saturates `sleepFactor` at 1.0 → must match at-target baseline (delta = 0)")
    }
}

// MARK: - Linked Training Load bar contract (BUG-064 regression)

/// Regression coverage for BUG-064: the Training Load widget bar was rendering the
/// sleep-blind `calculateLoad` result even when the linked composite was active,
/// while the linked detail sheet and the persisted `DailyTrainingLoadSnapshot` used
/// the sleep-aware `computeCurrentScore`. The fix routes the bar through a new
/// `HomeView.linkedAwareLoadResult` computed property that calls `computeCurrentScore`
/// when linked. This test pins down the contract the bar now depends on: in the
/// linked state with sub-target sleep, the score driving the bar must equal
/// `computeCurrentScore(...)` and must differ from `calculateLoad(...)`.
@MainActor
struct LinkedAwareLoadResultContractTests {

    @Test func test_linkedAwareLoadResult_whenLinked_usesComputeCurrentScore() throws {
        let context = try makeAlgorithmContext()
        let now = Date()
        // Two workouts 3 and 5 days ago so the decay loop has multiple iterations
        // where sleep variation can take effect.
        let calendar = Calendar.current
        for offset in [3, 5] {
            let date = calendar.date(byAdding: .day, value: -offset, to: now) ?? now
            let w = Workout(name: "W", date: date, workoutType: "Strength Training", rpe: 8, durationMinutes: 60)
            w.exerciseSets.append(ExerciseSet(exerciseName: "Squat", sets: 5, reps: 5, weightKg: 100))
            context.insert(w)
        }
        try context.save()

        let workouts = WorkoutService.fetchWorkouts(from: daysAgo(10, now: now), to: now, context: context)

        // Sub-target sleep on every intervening day so the two functions diverge meaningfully.
        var snapshotMap: [Date: DailySleepSnapshot] = [:]
        for offset in 0...10 {
            let day = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -offset, to: now) ?? now)
            snapshotMap[day] = DailySleepSnapshot(wakeUpDate: day, totalSleepMinutes: 5 * 60) // 5h vs 7h target
        }

        let sleepAware = ExerciseLoadService.computeCurrentScore(
            workouts: workouts,
            sleepSnapshotsByDay: snapshotMap,
            targetSleepHours: 7.0,
            experienceLevel: 1,
            targetMinutesPerWorkout: 45,
            now: now
        )
        let sleepBlind = ExerciseLoadService.calculateLoad(
            workouts: workouts,
            experienceLevel: 1,
            targetMinutesPerWorkout: 45,
            now: now
        )
        // The bar in the linked state must show `sleepAware`, not `sleepBlind`.
        // With sub-target sleep on multiple intervening days, the two MUST differ —
        // if this stops differing, the input setup no longer exercises the contract.
        #expect(sleepAware.score != sleepBlind.score,
                "Test setup must produce divergent scores so the contract is observable")
        #expect(sleepAware.score > sleepBlind.score,
                "Sleep-aware path retains more stress when sleep is below target")
    }
}

// MARK: - Unlinked Training Load bar/hero decay shape (BUG-067 regression)

/// Regression coverage for BUG-067: when unlinked, the home widget bar, the unlinked
/// Training Load detail sheet hero, the chart's latest point, and the chip's baseline
/// were rendered via three different code paths (`calculateLoad` continuous decay vs
/// `computeCurrentScore` discrete-day-step decay). For workouts logged within the past
/// ~24h these can disagree by 1–2 points, which made the chip's "+N from sleep" claim
/// inconsistent with the score change a user actually saw when toggling linking.
///
/// The fix routes every "current score" surface through `computeCurrentScore` with an
/// empty sleep map (every day's `sleepFactor = 1.0`) so the discrete-day-step shape is
/// universal across unlinked surfaces. This test pins the contract `HomeViewModel.loadData`
/// must uphold: the bar score equals `computeCurrentScore` with an empty sleep map,
/// regardless of how close to a midnight boundary the workouts are.
@MainActor
struct UnlinkedTrainingLoadBarShapeTests {

    @Test func test_loadData_loadResultEqualsComputeCurrentScoreEmptyMap() throws {
        let schema = Schema([
            Workout.self,
            ExerciseSet.self,
            Goal.self,
            GoalSnapshot.self,
            WorkoutTypeOrder.self,
            WorkoutTemplate.self,
            TemplateExerciseSet.self,
            HomeWidget.self,
            TrendsChart.self,
            ScheduledWorkout.self,
            WorkoutMatchRejection.self,
            DailySleepSnapshot.self,
            DailyTrainingLoadSnapshot.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        // Insert a workout ~6 hours ago so the continuous form (`calculateLoad`) and the
        // discrete form (`computeCurrentScore` with empty map) would diverge by a few
        // points — this is the "boundary case" the BUG-067 chip artifact came from.
        let now = Date()
        let calendar = Calendar.current
        let workoutDate = calendar.date(byAdding: .hour, value: -6, to: now) ?? now
        let workout = Workout(
            name: "Yesterday Evening",
            date: workoutDate,
            workoutType: "Strength Training",
            rpe: 8,
            durationMinutes: 60
        )
        let set = ExerciseSet(exerciseName: "Squat", sets: 5, reps: 5, weightKg: 120)
        workout.exerciseSets.append(set)
        context.insert(workout)
        try context.save()

        let settings = UserSettings.shared
        let viewModel = HomeViewModel()
        viewModel.loadData(context: context)

        // Expected: `computeCurrentScore` with empty map — the unified unlinked decay shape.
        let workouts = WorkoutService.fetchLast10DaysWorkouts(context: context, now: now)
        let expected = ExerciseLoadService.computeCurrentScore(
            workouts: workouts,
            sleepSnapshotsByDay: [:],
            targetSleepHours: settings.targetSleepHours,
            experienceLevel: settings.experienceLevel,
            targetMinutesPerWorkout: settings.targetMinutesPerWorkout,
            now: now
        )

        // Rounding to int matches the bar's displayed value semantics. Within 1 point
        // of `expected` because `HomeViewModel.loadData` captured a slightly earlier
        // `now` snapshot than this test's `now` — the time-of-day drift is sub-second.
        let actualInt = Int(viewModel.loadResult.score.rounded())
        let expectedInt = Int(expected.score.rounded())
        #expect(abs(actualInt - expectedInt) <= 1,
                "HomeViewModel.loadResult must match computeCurrentScore with an empty sleep map (BUG-067). actual=\(actualInt) expected=\(expectedInt)")
    }
}

// MARK: - Chip operand rounding contract (BUG-067 regression)

/// Regression coverage for BUG-067: the `sleepImpactChip` was computing the delta on
/// the unrounded `Double` `LoadResult.score` values and rounding once at the end.
/// The bar and the linked detail sheet header each round their own score independently
/// for display, so `round(linked - baseline)` and `round(linked) - round(baseline)`
/// can differ by ±1 on boundary cases. The fix rounds each operand to an `Int` first,
/// then subtracts. This test pins the contract by example: when the underlying
/// `LoadResult` scores are 8.49 and 7.51, the displayed chip delta should equal the
/// displayed bar change `(round(8.49) - round(7.51)) = (8 - 8) = 0`, NOT
/// `round(8.49 - 7.51) = round(0.98) = 1`.
struct SleepImpactChipRoundingContractTests {

    /// Mirrors the exact arithmetic in `HomeView.sleepImpactChip` so it survives any
    /// refactor that preserves the operand-rounding semantics. If a future change
    /// reverts to rounding the difference instead of the operands, this asserts a
    /// concrete boundary case where the two strategies diverge.
    private func chipDelta(linkedScore: Double, baselineScore: Double) -> Int {
        let baselineInt = Int(baselineScore.rounded())
        let linkedInt = Int(linkedScore.rounded())
        return max(linkedInt - baselineInt, 0)
    }

    @Test func test_chipDelta_roundsEachOperandSeparately_notTheDifference() {
        // Scores chosen so the two rounding strategies disagree:
        //   round(8.49) - round(7.51) = 8 - 8 = 0  (operand-first, the fix)
        //   round(8.49 - 7.51)        = round(0.98) = 1  (delta-first, the old bug)
        let delta = chipDelta(linkedScore: 8.49, baselineScore: 7.51)
        #expect(delta == 0,
                "Chip delta must match the difference of separately-rounded operands so the chip's claim equals the visible bar change")
    }

    @Test func test_chipDelta_neverGoesNegative() {
        // sleepFactor is clamped to [0.60, 1.0], so `linked - baseline` is mathematically
        // ≥ 0 by construction. But rounding the operands separately can still produce a
        // negative integer in edge cases (e.g. linked = 7.6 → 8, baseline = 7.4 → 7
        // is positive; linked = 7.4 → 7, baseline = 7.6 → 8 would be negative). The
        // `max(..., 0)` clamp protects against this and is the contract the chip's
        // color/glyph logic relies on (positive-or-zero only).
        let delta = chipDelta(linkedScore: 7.4, baselineScore: 7.6)
        #expect(delta == 0)
    }

    @Test func test_chipDelta_matchesVisibleBarChange_realisticExample() {
        // A sub-target sleep night raises the linked score by ~2 visible points.
        // linked = 9.1 → bar shows 9; baseline = 7.2 → bar shows 7; visible delta = 2.
        let delta = chipDelta(linkedScore: 9.1, baselineScore: 7.2)
        #expect(delta == 2,
                "Chip should claim +2 because the user sees the bar go from 7 to 9")
    }
}

// MARK: - Daily Snapshot Capture

@MainActor
struct DailySnapshotCaptureTests {

    @Test func captureInsertsOnFirstCall() throws {
        let context = try makeAlgorithmContext()
        let today = Calendar.current.startOfDay(for: Date())

        let snap = ExerciseLoadService.captureDailySnapshot(
            date: today,
            score: 45,
            wasSleepAdjusted: false,
            context: context
        )
        #expect(snap != nil)

        let stored = try context.fetch(FetchDescriptor<DailyTrainingLoadSnapshot>())
        #expect(stored.count == 1)
        #expect(stored.first?.score == 45)
        #expect(stored.first?.wasSleepAdjusted == false)
    }

    @Test func captureIsIdempotentForSameScoreAndFlag() throws {
        let context = try makeAlgorithmContext()
        let today = Calendar.current.startOfDay(for: Date())
        _ = ExerciseLoadService.captureDailySnapshot(date: today, score: 45, wasSleepAdjusted: false, context: context)
        let firstCapturedDate = try context.fetch(FetchDescriptor<DailyTrainingLoadSnapshot>()).first?.capturedDate

        // Wait one tick so capturedDate would change if we wrote.
        Thread.sleep(forTimeInterval: 0.02)
        _ = ExerciseLoadService.captureDailySnapshot(date: today, score: 45, wasSleepAdjusted: false, context: context)
        let secondCapturedDate = try context.fetch(FetchDescriptor<DailyTrainingLoadSnapshot>()).first?.capturedDate

        let stored = try context.fetch(FetchDescriptor<DailyTrainingLoadSnapshot>())
        #expect(stored.count == 1, "Should not insert a duplicate")
        // Idempotency means no write; capturedDate should be unchanged.
        #expect(firstCapturedDate == secondCapturedDate)
    }

    @Test func captureRewritesWhenScoreChanges() throws {
        let context = try makeAlgorithmContext()
        let today = Calendar.current.startOfDay(for: Date())
        _ = ExerciseLoadService.captureDailySnapshot(date: today, score: 45, wasSleepAdjusted: false, context: context)
        _ = ExerciseLoadService.captureDailySnapshot(date: today, score: 62, wasSleepAdjusted: false, context: context)

        let stored = try context.fetch(FetchDescriptor<DailyTrainingLoadSnapshot>())
        #expect(stored.count == 1)
        #expect(stored.first?.score == 62)
    }

    @Test func captureRewritesWhenLinkingFlagChanges() throws {
        let context = try makeAlgorithmContext()
        let today = Calendar.current.startOfDay(for: Date())
        _ = ExerciseLoadService.captureDailySnapshot(date: today, score: 45, wasSleepAdjusted: false, context: context)
        _ = ExerciseLoadService.captureDailySnapshot(date: today, score: 45, wasSleepAdjusted: true, context: context)

        let stored = try context.fetch(FetchDescriptor<DailyTrainingLoadSnapshot>())
        #expect(stored.count == 1)
        #expect(stored.first?.wasSleepAdjusted == true)
    }

    @Test func snapshotsForRangeReturnsSortedOldestFirst() throws {
        let context = try makeAlgorithmContext()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for offset in 0..<5 {
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            _ = ExerciseLoadService.captureDailySnapshot(date: day, score: 30 + offset, wasSleepAdjusted: false, context: context)
        }

        let start = calendar.date(byAdding: .day, value: -4, to: today) ?? today
        let results = ExerciseLoadService.snapshots(for: DateInterval(start: start, end: today), context: context)
        #expect(results.count == 5)
        // Oldest first → most recent last.
        #expect(results.first!.date < results.last!.date)
    }
}

// MARK: - Linked Recovery & Load Joint Advisory (BUG-061)
//
// Regression coverage for BUG-061: the prior `computeSleepQualifier` returned an
// independent sleep sentence concatenated onto the TL advisory, which could produce
// contradictions like "Well recovered. Ready to train. You're significantly under-slept."
// The replacement `computeLinkedAdvisory(...)` returns a single coherent sentence keyed
// on (zone, trainedToday, sleepBucket). Met-target and missing-data nights pass the
// base advisory through unchanged so the linked surface never silently drops a sentence
// the user expected to see.

@MainActor
struct LinkedAdvisoryTests {

    private func service() -> RecoveryStatusService {
        RecoveryStatusService(client: FoundationStubHealthKitClient())
    }

    private let lowUntrained = "Well recovered. Ready to train."
    private let moderateUntrained = "Some muscle fatigue. A moderate session would be ideal."
    private let restingUntrained = "No recent training stress. Ready for a full session."
    private let highTrained = "Recovery is the priority."
    private let peakTrained = "You've been pushing hard. Time to rest."

    // MARK: Contradiction cases — the core BUG-061 cells

    /// BUG-061: previously rendered "Well recovered. Ready to train. You're significantly under-slept."
    /// Should now read as a single sentence that clamps intensity.
    @Test func test_lowZone_untrained_significantlyBelow_overridesWithLightRest() {
        let copy = service().computeLinkedAdvisory(
            baseAdvisory: lowUntrained,
            zone: "Low",
            trainedToday: false,
            sleepHours: 3.0,
            targetSleepHours: 7.0
        )
        #expect(copy == "Your body is recovered, but sleep was significantly short. Keep today light or rest.")
    }

    /// BUG-061: previously rendered "Well recovered. Ready to train. You're under-slept."
    @Test func test_lowZone_untrained_moderatelyBelow_overridesWithModerate() {
        let copy = service().computeLinkedAdvisory(
            baseAdvisory: lowUntrained,
            zone: "Low",
            trainedToday: false,
            sleepHours: 5.0, // 0.714 → moderatelyBelow
            targetSleepHours: 7.0
        )
        #expect(copy == "Your body is recovered, but sleep was short. Favor a moderate session over a hard one.")
    }

    /// BUG-061: previously rendered "Some muscle fatigue. A moderate session would be ideal. You're significantly under-slept."
    @Test func test_moderateZone_untrained_significantlyBelow_overridesWithLightRest() {
        let copy = service().computeLinkedAdvisory(
            baseAdvisory: moderateUntrained,
            zone: "Moderate",
            trainedToday: false,
            sleepHours: 3.0,
            targetSleepHours: 7.0
        )
        #expect(copy == "Some muscle fatigue and sleep was significantly short. Keep today light or rest.")
    }

    /// BUG-061: previously rendered "Some muscle fatigue. A moderate session would be ideal. You're under-slept."
    @Test func test_moderateZone_untrained_moderatelyBelow_overridesWithLightSession() {
        let copy = service().computeLinkedAdvisory(
            baseAdvisory: moderateUntrained,
            zone: "Moderate",
            trainedToday: false,
            sleepHours: 5.0,
            targetSleepHours: 7.0
        )
        #expect(copy == "Some muscle fatigue and sleep was short. Favor a light session today.")
    }

    /// BUG-061: previously rendered "No recent training stress. Ready for a full session. You're significantly under-slept."
    @Test func test_restingZone_untrained_significantlyBelow_overridesWithLightRest() {
        let copy = service().computeLinkedAdvisory(
            baseAdvisory: restingUntrained,
            zone: "Resting",
            trainedToday: false,
            sleepHours: 3.0,
            targetSleepHours: 7.0
        )
        #expect(copy == "No recent training stress, but sleep was significantly short. Keep today light or rest.")
    }

    // MARK: Strong sleep — joint sentence, no awkward concat

    @Test func test_lowZone_untrained_strong_returnsJointSentence() {
        let copy = service().computeLinkedAdvisory(
            baseAdvisory: lowUntrained,
            zone: "Low",
            trainedToday: false,
            sleepHours: 8.0,
            targetSleepHours: 7.0
        )
        #expect(copy == "Well recovered and sleep was solid — a great day to train hard.")
    }

    @Test func test_highZone_trained_strong_returnsJointSentence() {
        let copy = service().computeLinkedAdvisory(
            baseAdvisory: highTrained,
            zone: "High",
            trainedToday: true,
            sleepHours: 8.0,
            targetSleepHours: 7.0
        )
        #expect(copy == "Rest is the priority. Sleep was solid — that'll help with muscle recovery.")
    }

    @Test func test_peakZone_trained_strong_returnsJointSentence() {
        let copy = service().computeLinkedAdvisory(
            baseAdvisory: peakTrained,
            zone: "Peak",
            trainedToday: true,
            sleepHours: 8.0,
            targetSleepHours: 7.0
        )
        #expect(copy == "You've been pushing hard. Time to rest — sleep was solid, recovery should come quickly.")
    }

    // MARK: Pass-through cases — base advisory unchanged

    @Test func test_metTarget_returnsBaseAdvisoryUnchanged() {
        let copy = service().computeLinkedAdvisory(
            baseAdvisory: lowUntrained,
            zone: "Low",
            trainedToday: false,
            sleepHours: 6.5, // 0.928 → metTarget
            targetSleepHours: 7.0
        )
        #expect(copy == lowUntrained)
    }

    @Test func test_missingSleepData_returnsBaseAdvisoryUnchanged() {
        let copy = service().computeLinkedAdvisory(
            baseAdvisory: lowUntrained,
            zone: "Low",
            trainedToday: false,
            sleepHours: nil,
            targetSleepHours: 7.0
        )
        #expect(copy == lowUntrained)
    }

    @Test func test_zeroTargetSleepHours_returnsBaseAdvisoryUnchanged() {
        let copy = service().computeLinkedAdvisory(
            baseAdvisory: lowUntrained,
            zone: "Low",
            trainedToday: false,
            sleepHours: 8.0,
            targetSleepHours: 0.0
        )
        #expect(copy == lowUntrained)
    }
}

// MARK: - Sleep-Load Correlation

@MainActor
struct CorrelationVariantTests {

    /// Helper — insert a single `Strength Training` workout on the given offset
    /// (today − offset days, anchored at noon) so it isn't filtered as empty.
    static func insertWorkout(daysAgo offset: Int, context: ModelContext, now: Date = Date()) {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now)) ?? now
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

    @Test func nilWhenFewerThan14PairedDays() throws {
        let context = try makeAlgorithmContext()
        let svc = RecoveryStatusService(client: FoundationStubHealthKitClient())
        svc.setContext(context)
        // 10 days of sleep → 9 pairs (offset 0's nextDay is tomorrow, skipped).
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for offset in 0..<10 {
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            svc.recent30DaySleep.append(DailySleepSnapshot(wakeUpDate: day, totalSleepMinutes: 7 * 60))
        }
        let result = svc.computeSleepLoadCorrelation(context: context)
        #expect(result == nil)
    }

    @Test func returnsNoPatternForFlatScores() throws {
        let context = try makeAlgorithmContext()
        let svc = RecoveryStatusService(client: FoundationStubHealthKitClient())
        svc.setContext(context)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // 20 paired days, alternating high/low sleep. No workouts → every baseline
        // load is 0, delta = 0 → noPattern.
        for offset in 0..<20 {
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let sleep = offset.isMultiple(of: 2) ? 8 * 60 : 5 * 60
            svc.recent30DaySleep.append(DailySleepSnapshot(wakeUpDate: day, totalSleepMinutes: sleep))
        }
        let result = svc.computeSleepLoadCorrelation(context: context)
        #expect(result != nil)
        #expect(result?.copyVariant == "noPattern")
    }

    @Test func returnsHighSleepBetterWhenStrongNightsLowerScore() throws {
        let context = try makeAlgorithmContext()
        let svc = RecoveryStatusService(client: FoundationStubHealthKitClient())
        svc.setContext(context)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // Sleep pattern: even offsets = high (8h), odd = low (5h).
        // For each pair (D, D+1): D=even → D+1 = odd offset; D=odd → D+1 = even offset.
        // Place heavy workouts on EVEN offsets so load[D+1] is HIGH after low-sleep
        // nights (D=odd) and LOW after high-sleep nights (D=even). delta < -5.
        for offset in 0..<20 {
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let highSleep = offset.isMultiple(of: 2)
            let sleep = highSleep ? 8 * 60 : 5 * 60
            svc.recent30DaySleep.append(DailySleepSnapshot(wakeUpDate: day, totalSleepMinutes: sleep))
            if highSleep {
                Self.insertWorkout(daysAgo: offset, context: context)
            }
        }
        try context.save()
        let result = svc.computeSleepLoadCorrelation(context: context)
        #expect(result?.copyVariant == "highSleepBetter")
        #expect((result?.delta ?? 0) < -5)
    }

    @Test func returnsLowSleepWorseWhenShortNightsRaiseScore() throws {
        let context = try makeAlgorithmContext()
        let svc = RecoveryStatusService(client: FoundationStubHealthKitClient())
        svc.setContext(context)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // Inverse of the previous test: workouts on ODD offsets push the next-day
        // load high for nextDays that follow a high-sleep (even-offset) night. So
        // mean(highSleepScores) > mean(lowSleepScores) → delta > +5 → lowSleepWorse.
        for offset in 0..<20 {
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let highSleep = offset.isMultiple(of: 2)
            let sleep = highSleep ? 8 * 60 : 5 * 60
            svc.recent30DaySleep.append(DailySleepSnapshot(wakeUpDate: day, totalSleepMinutes: sleep))
            if !highSleep {
                Self.insertWorkout(daysAgo: offset, context: context)
            }
        }
        try context.save()
        let result = svc.computeSleepLoadCorrelation(context: context)
        #expect(result?.copyVariant == "lowSleepWorse")
        #expect((result?.delta ?? 0) > 5)
    }

    /// BUG-070 regression — pre-populates `DailyTrainingLoadSnapshot` rows with a
    /// strong artificial correlation that would have driven the old implementation
    /// to `highSleepBetter`. After the refactor, those snapshots are ignored: the
    /// correlation reads baseline scores recomputed from raw workouts, which here
    /// are absent. Result must be `noPattern`, proving persisted (possibly
    /// sleep-adjusted) snapshots no longer influence the correlation.
    @Test func snapshotScoresDoNotInfluenceCorrelation() throws {
        let context = try makeAlgorithmContext()
        let svc = RecoveryStatusService(client: FoundationStubHealthKitClient())
        svc.setContext(context)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for offset in 0..<20 {
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let highSleep = offset.isMultiple(of: 2)
            let sleep = highSleep ? 8 * 60 : 5 * 60
            svc.recent30DaySleep.append(DailySleepSnapshot(wakeUpDate: day, totalSleepMinutes: sleep))
            // Persist a "sleep-adjusted" snapshot that fakes a perfect correlation:
            // 20 points on high-sleep next-days, 80 on low-sleep next-days. The old
            // implementation would have surfaced this as `highSleepBetter`.
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let nextScore = highSleep ? 20 : 80
            _ = ExerciseLoadService.captureDailySnapshot(
                date: nextDay,
                score: nextScore,
                wasSleepAdjusted: true,
                context: context
            )
        }
        try context.save()
        let result = svc.computeSleepLoadCorrelation(context: context)
        #expect(result?.copyVariant == "noPattern")
        #expect(abs(result?.delta ?? -1) < 5)
    }
}

// MARK: - Timer line formatting

@MainActor
struct TimeSinceLastWorkoutTests {

    private func svc() -> RecoveryStatusService {
        RecoveryStatusService(client: FoundationStubHealthKitClient())
    }

    @Test func neverLoggedReturnsNoWorkouts() {
        let formatted = svc().formatTimeSinceLastWorkout(latestDate: nil, now: Date())
        #expect(formatted == "No workouts logged yet")
    }

    @Test func underOneHourFormatsAsMinutes() {
        let now = Date()
        let twentyMinutesAgo = now.addingTimeInterval(-20 * 60)
        let formatted = svc().formatTimeSinceLastWorkout(latestDate: twentyMinutesAgo, now: now)
        #expect(formatted == "20 min since your last workout")
    }

    @Test func underOneDayFormatsAsHoursAndMinutes() {
        let now = Date()
        let fiveHoursAgo = now.addingTimeInterval(-(4 * 3600 + 12 * 60))
        let formatted = svc().formatTimeSinceLastWorkout(latestDate: fiveHoursAgo, now: now)
        #expect(formatted == "4h 12m since your last workout")
    }

    @Test func between1And3DaysFormatsAsDaysAndHours() {
        let now = Date()
        let oneDayFiveHoursAgo = now.addingTimeInterval(-(1 * 86400 + 5 * 3600))
        let formatted = svc().formatTimeSinceLastWorkout(latestDate: oneDayFiveHoursAgo, now: now)
        #expect(formatted == "1d 5h since your last workout")
    }

    @Test func moreThan3DaysFormatsAsDays() {
        let now = Date()
        let fourDaysAgo = now.addingTimeInterval(-(4 * 86400 + 2 * 3600))
        let formatted = svc().formatTimeSinceLastWorkout(latestDate: fourDaysAgo, now: now)
        #expect(formatted == "4 days since your last workout")
    }

    // MARK: - formatLastWorkoutHero (bare-value variant for the LAST WORKOUT hero column)

    @Test func lastWorkoutHero_neverLoggedReturnsNoData() {
        let formatted = svc().formatLastWorkoutHero(latestDate: nil, now: Date())
        #expect(formatted == "NO DATA")
    }

    @Test func lastWorkoutHero_underOneHourFormatsAsMinutes() {
        let now = Date()
        let twentyMinutesAgo = now.addingTimeInterval(-20 * 60)
        let formatted = svc().formatLastWorkoutHero(latestDate: twentyMinutesAgo, now: now)
        #expect(formatted == "20 min")
    }

    @Test func lastWorkoutHero_underOneDayFormatsAsHoursAndMinutes() {
        let now = Date()
        let fourHoursTwelveMinutesAgo = now.addingTimeInterval(-(4 * 3600 + 12 * 60))
        let formatted = svc().formatLastWorkoutHero(latestDate: fourHoursTwelveMinutesAgo, now: now)
        #expect(formatted == "4h 12m")
    }

    @Test func lastWorkoutHero_between1And3DaysFormatsAsDaysAndHours() {
        let now = Date()
        let oneDayFiveHoursAgo = now.addingTimeInterval(-(1 * 86400 + 5 * 3600))
        let formatted = svc().formatLastWorkoutHero(latestDate: oneDayFiveHoursAgo, now: now)
        #expect(formatted == "1d 5h")
    }

    @Test func lastWorkoutHero_moreThan3DaysFormatsAsDays() {
        let now = Date()
        let fourDaysAgo = now.addingTimeInterval(-(4 * 86400 + 2 * 3600))
        let formatted = svc().formatLastWorkoutHero(latestDate: fourDaysAgo, now: now)
        #expect(formatted == "4 days")
    }
}

// MARK: - refreshTimerLine cache write (BUG-062 regression)

/// Regression coverage for BUG-062: the Recovery Status widget's SINCE LAST WORKOUT
/// hero value froze at "0 min" after a manual log because `HomeView` never re-invoked
/// `refreshTimerLine` after the cascade's initial fire. The HomeView-side fix wires up
/// the spec's missing foreground-entry + 60s-while-visible triggers; this test pins
/// the contract those triggers depend on — that `refreshTimerLine(context:)` actually
/// reads the most-recent Workout.date and updates `lastWorkoutHeroFormatted`.
@MainActor
struct RefreshTimerLineTests {

    @Test func test_refreshTimerLine_updatesLastWorkoutHeroFormatted_afterWorkoutInserted() throws {
        let context = try makeAlgorithmContext()
        let svc = RecoveryStatusService(client: FoundationStubHealthKitClient())
        svc.setContext(context)

        let twentyMinutesAgo = Date().addingTimeInterval(-20 * 60)
        let workout = Workout(
            name: "Manual Log",
            date: twentyMinutesAgo,
            workoutType: "Strength Training",
            rpe: 6,
            durationMinutes: 30
        )
        context.insert(workout)
        try context.save()

        svc.refreshTimerLine(context: context)

        #expect(svc.lastWorkoutHeroFormatted == "20 min")
        #expect(svc.timeSinceLastWorkoutFormatted == "20 min since your last workout")
    }
}

// MARK: - Today's snapshot lookup (BUG-051 regression)

/// Regression coverage for BUG-051: between 6pm and midnight `recomputeDerivedFromCache`
/// previously called `wakeUpDate(for: Date())`, which rolled past-6pm timestamps forward
/// to the next calendar day and missed today's snapshot. Today's snapshot is keyed to
/// today's startOfDay; the lookup must match it regardless of the current hour.
@MainActor
struct TodaysSnapshotLookupTests {

    @Test func reloadCacheFromStorePopulatesTodaysSnapshotAtAnyTimeOfDay() throws {
        let context = try makeAlgorithmContext()
        let today = Calendar.current.startOfDay(for: Date())
        let snap = DailySleepSnapshot(
            wakeUpDate: today,
            totalSleepMinutes: 7 * 60 + 15,
            deepSleepMinutes: 75,
            remSleepMinutes: 90,
            coreSleepMinutes: 4 * 60
        )
        context.insert(snap)
        try context.save()

        let svc = RecoveryStatusService(client: FoundationStubHealthKitClient())
        svc.setContext(context)
        svc.reloadCacheFromStore(context: context, lookbackDays: 30)

        #expect(svc.todaysSnapshot != nil)
        #expect(svc.todaysSnapshot?.totalSleepMinutes == 7 * 60 + 15)
    }
}
// MARK: - BUG-059 backfill on cache reload

/// Regression coverage for BUG-059 follow-up: snapshots written before the asleep+awake
/// fallback shipped have `inBedMinutes == nil` and `sleepEfficiencyPercent == nil`.
/// `reloadCacheFromStore` must repair them in-place so the detail sheets surface
/// efficiency without waiting for a fresh HK ingest.
@MainActor
struct SleepEfficiencyBackfillTests {

    @Test func reloadCacheBackfillsLegacyNilInBedMinutes() throws {
        let context = try makeAlgorithmContext()
        let today = Calendar.current.startOfDay(for: Date())
        // Pre-fix snapshot: stage data is present, awake captured, but `inBedMinutes`
        // and `sleepEfficiencyPercent` are nil (the Apple-Watch-only case before BUG-059).
        let legacy = DailySleepSnapshot(
            wakeUpDate: today,
            totalSleepMinutes: 420,
            deepSleepMinutes: 80,
            remSleepMinutes: 100,
            coreSleepMinutes: 240,
            awakeMinutes: 30,
            inBedMinutes: nil,
            sleepEfficiencyPercent: nil
        )
        context.insert(legacy)
        try context.save()

        let svc = RecoveryStatusService(client: FoundationStubHealthKitClient())
        svc.setContext(context)
        svc.reloadCacheFromStore(context: context, lookbackDays: 30)

        let snapshot = try #require(svc.todaysSnapshot)
        #expect(snapshot.inBedMinutes == 450) // 420 + 30
        // 420 / 450 × 100 = 93.33 → 93
        #expect(snapshot.sleepEfficiencyPercent == 93)
    }

    @Test func reloadCacheLeavesExplicitInBedSnapshotsUntouched() throws {
        let context = try makeAlgorithmContext()
        let today = Calendar.current.startOfDay(for: Date())
        // Snapshot from a source that does write `.inBed` (e.g. Oura): explicit values
        // must not be overwritten by the backfill.
        let explicit = DailySleepSnapshot(
            wakeUpDate: today,
            totalSleepMinutes: 420,
            deepSleepMinutes: 80,
            remSleepMinutes: 100,
            coreSleepMinutes: 240,
            awakeMinutes: 30,
            inBedMinutes: 510,
            sleepEfficiencyPercent: 82
        )
        context.insert(explicit)
        try context.save()

        let svc = RecoveryStatusService(client: FoundationStubHealthKitClient())
        svc.setContext(context)
        svc.reloadCacheFromStore(context: context, lookbackDays: 30)

        let snapshot = try #require(svc.todaysSnapshot)
        #expect(snapshot.inBedMinutes == 510)
        #expect(snapshot.sleepEfficiencyPercent == 82)
    }

    @Test func reloadCacheSkipsBackfillForZeroAsleepSnapshots() throws {
        let context = try makeAlgorithmContext()
        let today = Calendar.current.startOfDay(for: Date())
        // Edge case: awake-only night (totalSleep == 0). Backfill must not invent an
        // inBed value here — the data isn't really a sleep session.
        let awakeOnly = DailySleepSnapshot(
            wakeUpDate: today,
            totalSleepMinutes: 0,
            deepSleepMinutes: 0,
            remSleepMinutes: 0,
            coreSleepMinutes: 0,
            awakeMinutes: 20,
            inBedMinutes: nil,
            sleepEfficiencyPercent: nil
        )
        context.insert(awakeOnly)
        try context.save()

        let svc = RecoveryStatusService(client: FoundationStubHealthKitClient())
        svc.setContext(context)
        svc.reloadCacheFromStore(context: context, lookbackDays: 30)

        let snapshot = try #require(svc.todaysSnapshot)
        #expect(snapshot.inBedMinutes == nil)
        #expect(snapshot.sleepEfficiencyPercent == nil)
    }
}

// MARK: - Linked Recovery & Load Detail Sheet — Window Comparison Caption (BUG-065, BUG-066)

/// Regression coverage for BUG-065 + BUG-066. The detail sheet's Training Load / Sleep
/// "vs last week" rows previously left users guessing which week (BUG-065), and the
/// underlying algorithms compared a partial in-progress week to a full prior week
/// (BUG-066). The caption now names the day-of-week matched windows on both sides.
struct LinkedDetailSheetWindowComparisonCaptionTests {

    private func makeDate(year: Int, month: Int, day: Int) throws -> Date {
        let comps = DateComponents(calendar: Calendar(identifier: .iso8601), year: year, month: month, day: day, hour: 12)
        return try #require(comps.date)
    }

    @Test func captionOnThursdayMatchesMonThruThuOnBothSides() throws {
        // Thursday, May 28 2026. Current matched window: Mon May 25 – today.
        // Prior matched window: Mon May 18 – Thu May 21 (NOT through Sun May 24).
        let now = try makeDate(year: 2026, month: 5, day: 28)
        let caption = FortiFitLinkedRecoveryLoadDetailSheet.windowComparisonCaption(now: now)

        #expect(caption.contains("This week so far"))
        #expect(caption.contains("– today)"))
        #expect(caption.contains("same period last week"))
        #expect(caption.contains("May 25"))
        #expect(caption.contains("May 18"))
        #expect(caption.contains("May 21"))
        // BUG-066 guard: the prior window must NOT extend through Sunday.
        #expect(!caption.contains("May 24"))
    }

    @Test func captionOnMondayMatchesMondayOnly() throws {
        // Monday, May 25 2026 — current-week-start equals today. Prior matched
        // window is a single Monday (May 18).
        let now = try makeDate(year: 2026, month: 5, day: 25)
        let caption = FortiFitLinkedRecoveryLoadDetailSheet.windowComparisonCaption(now: now)

        #expect(caption.contains("May 25"))
        #expect(caption.contains("May 18"))
        // BUG-066 guard: prior window doesn't extend past Mon May 18.
        #expect(!caption.contains("May 19"))
        #expect(!caption.contains("May 24"))
    }

    @Test func captionOnSundayCollapsesToFullWeekVsFullWeek() throws {
        // Sunday, May 31 2026 — matched window equals the full Mon–Sun week
        // on both sides, so we expect the prior window to run through Sun May 24.
        let now = try makeDate(year: 2026, month: 5, day: 31)
        let caption = FortiFitLinkedRecoveryLoadDetailSheet.windowComparisonCaption(now: now)

        #expect(caption.contains("May 25"))
        #expect(caption.contains("May 18"))
        #expect(caption.contains("May 24"))
    }
}

