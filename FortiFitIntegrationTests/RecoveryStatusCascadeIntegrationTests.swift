import XCTest
import SwiftData
@testable import FortiFit

/// Phase 11 Step 3 — Sleep Cascade hooks, Workout Cascade snapshot capture, and the
/// linked/unlinked behavioral contract on `DailyTrainingLoadSnapshot`.
@MainActor
final class RecoveryStatusCascadeIntegrationTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        let result = try TestFixtures.inMemoryContext()
        container = result.0
        context = result.1
        // Clean Phase 11 entities between tests since UserSettings.shared is a singleton.
        for snap in try context.fetch(FetchDescriptor<DailySleepSnapshot>()) { context.delete(snap) }
        for snap in try context.fetch(FetchDescriptor<DailyTrainingLoadSnapshot>()) { context.delete(snap) }
        try context.save()
        UserSettings.shared.targetSleepHours = 7.0
    }

    // MARK: - Fixture helpers

    private var wakeUpWindowAnchor: Date {
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private func sample(stage: HKSleepStage, durationMinutes: Int, endOffsetMinutes: Int, source: String = "com.apple.health.sleep") -> HKSleepSampleSnapshot {
        let end = wakeUpWindowAnchor.addingTimeInterval(TimeInterval(endOffsetMinutes * 60))
        let start = end.addingTimeInterval(TimeInterval(-durationMinutes * 60))
        return HKSleepSampleSnapshot(uuid: UUID(), stage: stage, startDate: start, endDate: end, sourceBundleID: source)
    }

    private func belowTargetSleepBatch() -> [HKSleepSampleSnapshot] {
        // 3.5h total sleep — half of a 7h target, so sleepFactor ≈ 0.8.
        // Anchored to 8 AM today; all samples land in today's wake-up window
        // regardless of clock time.
        return [
            sample(stage: .inBed, durationMinutes: 240, endOffsetMinutes: 0),
            sample(stage: .asleepDeep, durationMinutes: 30, endOffsetMinutes: -120),
            sample(stage: .asleepREM, durationMinutes: 60, endOffsetMinutes: -60),
            sample(stage: .asleepCore, durationMinutes: 120, endOffsetMinutes: -30)
        ]
    }

    private func logWorkout(daysAgo offset: Int, rpe: Int = 7) {
        let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
        let workout = Workout(
            name: "Test Lift",
            date: date,
            workoutType: "Strength Training",
            rpe: rpe,
            durationMinutes: 60
        )
        workout.exerciseSets.append(ExerciseSet(exerciseName: "Bench", sets: 4, reps: 5, weightKg: 80))
        WorkoutService.logWorkout(workout, context: context)
    }

    // MARK: - Tests

    func test_loggingWorkout_capturesTodaySnapshot() throws {
        // No snapshot exists initially.
        XCTAssertTrue(try context.fetch(FetchDescriptor<DailyTrainingLoadSnapshot>()).isEmpty)

        logWorkout(daysAgo: 0)

        let snapshots = try context.fetch(FetchDescriptor<DailyTrainingLoadSnapshot>())
        XCTAssertEqual(snapshots.count, 1, "Workout log should capture today's TL snapshot")
        let today = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(snapshots.first?.date, today)
        XCTAssertEqual(snapshots.first?.wasSleepAdjusted, false,
                       "Unlinked workout should capture baseline snapshot")
    }

    func test_loggingWorkout_rewritesSameDaySnapshot() throws {
        logWorkout(daysAgo: 0, rpe: 5)
        let firstScore = try context.fetch(FetchDescriptor<DailyTrainingLoadSnapshot>()).first?.score

        // A second, harder workout on the same day should bump today's snapshot.
        logWorkout(daysAgo: 0, rpe: 10)

        let snapshots = try context.fetch(FetchDescriptor<DailyTrainingLoadSnapshot>())
        XCTAssertEqual(snapshots.count, 1, "Same-day capture should upsert, not duplicate")
        let secondScore = snapshots.first?.score
        XCTAssertGreaterThan(secondScore ?? 0, firstScore ?? 0,
                             "Harder workout should produce a higher captured score")
    }

    func test_sleepObserverFireWhileLinked_rewritesSnapshotWithSleepAdjustedTrue() async throws {
        // Seed a workout from a couple days ago so there's something to score.
        logWorkout(daysAgo: 2)
        let baselineSnapshot = try context.fetch(FetchDescriptor<DailyTrainingLoadSnapshot>()).first
        XCTAssertEqual(baselineSnapshot?.wasSleepAdjusted, false)

        // Now flip on linking and fire a sleep observer with below-target sleep.
        let stub = StubHealthKitClient()
        UserSettings.shared.healthKitEnabled = true
        let recovery = RecoveryStatusService(client: stub)
        recovery.setContext(context)
        recovery.isLinkedActive = true
        stub.sleepSamplesToReturn = belowTargetSleepBatch()

        await recovery.handleSleepObserverFire()
        // Wait for the 500ms cascade debounce + a small buffer.
        try await Task.sleep(nanoseconds: 700_000_000)

        let after = try context.fetch(FetchDescriptor<DailyTrainingLoadSnapshot>()).first
        XCTAssertEqual(after?.wasSleepAdjusted, true,
                       "Sleep observer fire while linked should rewrite today's snapshot as sleep-adjusted")
    }

    func test_sleepObserverFireWhileUnlinked_doesNotRewriteSnapshot() async throws {
        logWorkout(daysAgo: 2)
        let before = try context.fetch(FetchDescriptor<DailyTrainingLoadSnapshot>()).first
        XCTAssertEqual(before?.wasSleepAdjusted, false)
        let beforeCapturedDate = before?.capturedDate

        let stub = StubHealthKitClient()
        UserSettings.shared.healthKitEnabled = true
        let recovery = RecoveryStatusService(client: stub)
        recovery.setContext(context)
        recovery.isLinkedActive = false // explicitly unlinked
        stub.sleepSamplesToReturn = belowTargetSleepBatch()

        await recovery.handleSleepObserverFire()
        try await Task.sleep(nanoseconds: 700_000_000)

        let after = try context.fetch(FetchDescriptor<DailyTrainingLoadSnapshot>()).first
        XCTAssertEqual(after?.wasSleepAdjusted, false, "Unlinked sleep fire should not flip the adjusted flag")
        XCTAssertEqual(after?.capturedDate, beforeCapturedDate,
                       "Unlinked sleep fire should not rewrite today's snapshot")
    }

    func test_snapshotsForRange_returnsHistoricalDays() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for offset in 0..<5 {
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            _ = ExerciseLoadService.captureDailySnapshot(
                date: day,
                score: 30 + offset * 5,
                wasSleepAdjusted: offset.isMultiple(of: 2),
                context: context
            )
        }

        let start = calendar.date(byAdding: .day, value: -4, to: today) ?? today
        let snapshots = ExerciseLoadService.snapshots(
            for: DateInterval(start: start, end: today),
            context: context
        )
        XCTAssertEqual(snapshots.count, 5)
        // Oldest first.
        XCTAssertLessThan(snapshots.first!.date, snapshots.last!.date)
        // Adjusted flag mix preserved.
        XCTAssertTrue(snapshots.contains { $0.wasSleepAdjusted })
        XCTAssertTrue(snapshots.contains { !$0.wasSleepAdjusted })
    }
}
