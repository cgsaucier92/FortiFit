import XCTest
import SwiftData
@testable import FortiFit

/// Phase 11 Step 2 — sleep ingest, observer dispatch, 30-day cache, BG refresh,
/// and 6pm catch-up.
@MainActor
final class RecoveryStatusSleepIntegrationTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        let result = try TestFixtures.inMemoryContext()
        container = result.0
        context = result.1
        // Clean snapshot store between tests since `UserSettings.shared` is a singleton.
        try clearSnapshots()
    }

    private func clearSnapshots() throws {
        let sleepDescriptor = FetchDescriptor<DailySleepSnapshot>()
        for existing in try context.fetch(sleepDescriptor) {
            context.delete(existing)
        }
        try context.save()
    }

    // MARK: - Fixture helpers

    /// Build a sleep sample whose `endDate` is `endHoursAgo` from now (mostly used
    /// to land samples inside last-night's wake-up window).
    /// Today's wake-up window in test-fixture land: anchored to 8:00 AM today (well within
    /// the 6pm-yesterday → 6pm-today window regardless of when the test actually runs).
    /// Avoids a time-of-day flake when tests run between 7pm and midnight.
    private var wakeUpWindowAnchor: Date {
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private func sample(stage: HKSleepStage, durationMinutes: Int, endOffsetMinutes: Int, source: String = "com.apple.health.sleep") -> HKSleepSampleSnapshot {
        // `endOffsetMinutes` is added to the 8 AM anchor — negative values land earlier
        // in the night, positive values land just after wake-up.
        let end = wakeUpWindowAnchor.addingTimeInterval(TimeInterval(endOffsetMinutes * 60))
        let start = end.addingTimeInterval(TimeInterval(-durationMinutes * 60))
        return HKSleepSampleSnapshot(uuid: UUID(), stage: stage, startDate: start, endDate: end, sourceBundleID: source)
    }

    /// Anchored sleep batch — all samples end before noon today and after 6pm yesterday,
    /// so every sample lands in today's wake-up window regardless of clock time.
    private func lastNightFixtureBatch() -> [HKSleepSampleSnapshot] {
        return [
            sample(stage: .inBed, durationMinutes: 480, endOffsetMinutes: 0),
            sample(stage: .asleepDeep, durationMinutes: 84, endOffsetMinutes: -120),
            sample(stage: .asleepREM, durationMinutes: 110, endOffsetMinutes: -60),
            sample(stage: .asleepCore, durationMinutes: 240, endOffsetMinutes: -30),
            sample(stage: .awake, durationMinutes: 10, endOffsetMinutes: -10)
        ]
    }

    // MARK: - Tests

    func test_ingestSamples_writesDailySleepSnapshot() async throws {
        let stub = StubHealthKitClient()
        stub.sleepSamplesToReturn = lastNightFixtureBatch()
        UserSettings.shared.healthKitEnabled = true

        let service = RecoveryStatusService(client: stub)
        service.setContext(context)

        await service.refresh()

        let descriptor = FetchDescriptor<DailySleepSnapshot>()
        let snapshots = try context.fetch(descriptor)
        XCTAssertFalse(snapshots.isEmpty, "Expected at least one DailySleepSnapshot written for last night")

        // Find the most recent snapshot and assert aggregate fields look sensible.
        let mostRecent = snapshots.sorted(by: { $0.wakeUpDate > $1.wakeUpDate }).first!
        // Deep + REM + Core (Unspecified bucketed into Core) = 84 + 110 + 240 = 434
        XCTAssertEqual(mostRecent.totalSleepMinutes, 434)
        XCTAssertEqual(mostRecent.deepSleepMinutes, 84)
        XCTAssertEqual(mostRecent.remSleepMinutes, 110)
        XCTAssertEqual(mostRecent.coreSleepMinutes, 240)
        XCTAssertEqual(mostRecent.awakeMinutes, 10)
        XCTAssertEqual(mostRecent.inBedMinutes, 480)
        XCTAssertNotNil(mostRecent.sleepEfficiencyPercent)
    }

    func test_ingestSamples_repopulates30DayCache() async throws {
        let stub = StubHealthKitClient()
        stub.sleepSamplesToReturn = lastNightFixtureBatch()
        UserSettings.shared.healthKitEnabled = true

        let service = RecoveryStatusService(client: stub)
        service.setContext(context)

        await service.refresh()

        XCTAssertFalse(service.recent30DaySleep.isEmpty)
        XCTAssertNotNil(service.todaysSnapshot ?? service.recent30DaySleep.last)
    }

    func test_refreshSkipsIngestWhenHealthKitDisabled() async throws {
        let stub = StubHealthKitClient()
        stub.sleepSamplesToReturn = lastNightFixtureBatch()
        UserSettings.shared.healthKitEnabled = false

        let service = RecoveryStatusService(client: stub)
        service.setContext(context)
        await service.refresh()

        let descriptor = FetchDescriptor<DailySleepSnapshot>()
        let snapshots = try context.fetch(descriptor)
        XCTAssertTrue(snapshots.isEmpty, "Should not ingest sleep samples when HK is disabled")
        XCTAssertEqual(service.currentGatingState, .connectAppleHealth)
    }

    func test_secondIngestUpsertsExistingSnapshotInPlace() async throws {
        let stub = StubHealthKitClient()
        stub.sleepSamplesToReturn = lastNightFixtureBatch()
        UserSettings.shared.healthKitEnabled = true

        let service = RecoveryStatusService(client: stub)
        service.setContext(context)
        await service.refresh()

        let firstCount = try context.fetch(FetchDescriptor<DailySleepSnapshot>()).count

        // Second pass with slightly different aggregates (e.g., Apple Watch synced more samples).
        stub.sleepSamplesToReturn = [
            sample(stage: .inBed, durationMinutes: 480, endOffsetMinutes: 0),
            sample(stage: .asleepDeep, durationMinutes: 90, endOffsetMinutes: -120),
            sample(stage: .asleepREM, durationMinutes: 110, endOffsetMinutes: -60),
            sample(stage: .asleepCore, durationMinutes: 250, endOffsetMinutes: -30),
            sample(stage: .awake, durationMinutes: 10, endOffsetMinutes: -10)
        ]
        await service.refresh()

        let secondCount = try context.fetch(FetchDescriptor<DailySleepSnapshot>()).count
        XCTAssertEqual(firstCount, secondCount, "Re-ingest should upsert by wakeUpDate, not insert a duplicate")

        let mostRecent = try context.fetch(FetchDescriptor<DailySleepSnapshot>()).sorted(by: { $0.wakeUpDate > $1.wakeUpDate }).first!
        XCTAssertEqual(mostRecent.deepSleepMinutes, 90)
        XCTAssertEqual(mostRecent.coreSleepMinutes, 250)
    }

    func test_handleSleepObserverFire_writesSnapshotAndUpdatesCache() async throws {
        let stub = StubHealthKitClient()
        UserSettings.shared.healthKitEnabled = true
        let service = RecoveryStatusService(client: stub)
        service.setContext(context)

        stub.sleepSamplesToReturn = lastNightFixtureBatch()
        await service.handleSleepObserverFire()

        let descriptor = FetchDescriptor<DailySleepSnapshot>()
        XCTAssertFalse(try context.fetch(descriptor).isEmpty)
        XCTAssertFalse(service.recent30DaySleep.isEmpty)
    }

    func test_refreshFromBackground_writesSnapshot() async throws {
        let stub = StubHealthKitClient()
        UserSettings.shared.healthKitEnabled = true
        let service = RecoveryStatusService(client: stub)
        service.setContext(context)

        stub.sleepSamplesToReturn = lastNightFixtureBatch()
        await service.refreshFromBackground()

        XCTAssertFalse(try context.fetch(FetchDescriptor<DailySleepSnapshot>()).isEmpty)
    }

    func test_importSleepGoalFromAppleHealth_nilGoalEmitsToast() async throws {
        let stub = StubHealthKitClient()
        stub.sleepDurationGoalToReturn = nil
        let service = RecoveryStatusService(client: stub)

        let originalTarget = UserSettings.shared.targetSleepHours
        defer { UserSettings.shared.targetSleepHours = originalTarget }

        await service.importSleepGoalFromAppleHealth()
        XCTAssertEqual(service.lastToastMessage, "No sleep goal set in Apple Health.")
    }

    func test_forceCatchUpStampsLastSleepCatchUpDate() async throws {
        let stub = StubHealthKitClient()
        stub.sleepSamplesToReturn = lastNightFixtureBatch()
        UserSettings.shared.healthKitEnabled = true
        UserSettings.shared.lastSleepCatchUpDate = nil

        let service = RecoveryStatusService(client: stub)
        service.setContext(context)

        await service.refresh(forceCatchUp: true)
        XCTAssertNotNil(UserSettings.shared.lastSleepCatchUpDate)
    }

    /// BUG-052 regression. Drive the full sample → ingest → DailySleepSnapshot
    /// pipeline with samples that carry fractional-second durations. The snapshot
    /// total must match the sum-then-round value, not the sum of per-sample
    /// rounded minutes.
    func test_fractionalSecondSamplesProduceSumThenRoundTotal() async throws {
        let stub = StubHealthKitClient()
        UserSettings.shared.healthKitEnabled = true

        // 30 × 90-second core-sleep samples staggered to land within last night's
        // wake-up window. Sum = 2700 sec = 45 minutes exactly.
        // Old round-then-sum would have written 30 × 2 = 60 minutes.
        var samples: [HKSleepSampleSnapshot] = []
        for i in 0..<30 {
            let end = wakeUpWindowAnchor.addingTimeInterval(TimeInterval(-i * 90 - 60))
            let start = end.addingTimeInterval(-90)
            samples.append(HKSleepSampleSnapshot(
                uuid: UUID(),
                stage: .asleepCore,
                startDate: start,
                endDate: end,
                sourceBundleID: "com.apple.health.sleep"
            ))
        }
        stub.sleepSamplesToReturn = samples

        let service = RecoveryStatusService(client: stub)
        service.setContext(context)
        await service.refresh()

        let snapshots = try context.fetch(FetchDescriptor<DailySleepSnapshot>())
            .sorted(by: { $0.wakeUpDate > $1.wakeUpDate })
        let mostRecent = try XCTUnwrap(snapshots.first, "Expected a DailySleepSnapshot for last night")
        XCTAssertEqual(mostRecent.coreSleepMinutes, 45)
        XCTAssertEqual(mostRecent.totalSleepMinutes, 45)
    }

    func test_sleepObserverWiredThroughSyncService() async throws {
        let stub = StubHealthKitClient()
        UserSettings.shared.healthKitEnabled = true
        stub.sleepSamplesToReturn = lastNightFixtureBatch()

        let matcher = WorkoutMatcher()
        let sync = HealthKitSyncService(client: stub, matcher: matcher)
        let recovery = RecoveryStatusService(client: stub)
        recovery.setContext(context)
        sync.recoveryStatusService = recovery
        sync.setContext(context)

        sync.startObserving()
        XCTAssertNotNil(stub.sleepObserverHandler, "Sleep observer should be registered with the client")

        // Fire the observer — the handler hops to MainActor and calls handleSleepObserverFire().
        stub.fireSleepObserver()

        // Give the dispatch + ingest a moment.
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertFalse(try context.fetch(FetchDescriptor<DailySleepSnapshot>()).isEmpty,
                       "Observer fire should propagate to a DailySleepSnapshot upsert")
    }

    // MARK: - BUG-068: observer fetch window must cover yesterday's wake-up window

    /// `observerFetchWindowStart` must anchor to the start of yesterday's 6pm-to-6pm
    /// wake-up window (with a 2-hour buffer), regardless of the current hour. Pre-fix,
    /// the window was a fixed 36 hours back — which fell short whenever the observer
    /// fired in the late afternoon or evening, leaving the early-evening hours of two
    /// days ago outside the fetch.
    func test_observerFetchWindowStart_coversYesterdayWakeUpWindow() throws {
        let stub = StubHealthKitClient()
        let service = RecoveryStatusService(client: stub)
        let calendar = Calendar.current

        // Pin "now" to 4:57 PM today — the time-of-day from the user's screenshot
        // where the bug surfaced.
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 16
        components.minute = 57
        let now = calendar.date(from: components) ?? Date()

        let windowStart = service.observerFetchWindowStart(now: now)

        // Yesterday's wake-up window start is 6 PM two days ago.
        let twoDaysAgoStartOfDay = calendar.date(byAdding: .day, value: -2, to: calendar.startOfDay(for: now))!
        let yesterdayWindowStart = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: twoDaysAgoStartOfDay)!
        let expectedWithBuffer = calendar.date(byAdding: .hour, value: -2, to: yesterdayWindowStart)!

        XCTAssertEqual(windowStart, expectedWithBuffer,
                       "Observer fetch window must start 2 hours before yesterday's 6 PM wake-up window boundary")

        // Sanity: the new window is ~48-49 hours wide (was 36 hours pre-fix).
        let hoursWide = now.timeIntervalSince(windowStart) / 3600.0
        XCTAssertGreaterThan(hoursWide, 47.0, "Fetch window must comfortably cover both today's and yesterday's wake-up windows")
    }

    /// BUG-068 regression for the defensive partial-coverage guard in `upsertSnapshot`.
    /// If a caller ever passes a `fetchWindowStart` that begins AFTER a wake-up day's
    /// 6pm-to-6pm window starts, the upsert must skip rather than overwrite the existing
    /// snapshot with the partial aggregate. Backs up the wider `observerFetchWindowStart`
    /// fix — if someone in the future tweaks the window calculation incorrectly, the
    /// guard still prevents data loss.
    ///
    /// We exercise the guard directly via `ingestSamples` with an intentionally narrow
    /// window (12h) so the bug surface is observable in test even now that the live
    /// observer fire uses a ~48h window that wouldn't trigger it.
    func test_partialFetchWindowGuard_doesNotOverwritePreviouslyCorrectSnapshot() async throws {
        let stub = StubHealthKitClient()
        UserSettings.shared.healthKitEnabled = true
        let service = RecoveryStatusService(client: stub)
        service.setContext(context)

        // STEP 1 — full overnight session for yesterday, captured via the wide initial
        // refresh. Build samples that all land in yesterday's 6pm-to-6pm wake-up window.
        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        // Anchor to 4 AM yesterday so the end dates land squarely in yesterday's
        // wake-up window (after 6 PM two days ago, before 6 PM yesterday).
        let yesterdayMorning = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: yesterday) ?? yesterday

        func sample(stage: HKSleepStage, durationMinutes: Int, endOffsetMinutes: Int) -> HKSleepSampleSnapshot {
            let end = yesterdayMorning.addingTimeInterval(TimeInterval(endOffsetMinutes * 60))
            let start = end.addingTimeInterval(TimeInterval(-durationMinutes * 60))
            return HKSleepSampleSnapshot(uuid: UUID(), stage: stage, startDate: start, endDate: end, sourceBundleID: "com.apple.health.sleep")
        }

        // Full overnight: 5h 23m = 323 minutes asleep + 20 min awake.
        let fullNight: [HKSleepSampleSnapshot] = [
            sample(stage: .asleepCore, durationMinutes: 180, endOffsetMinutes: -240),
            sample(stage: .asleepDeep, durationMinutes: 60,  endOffsetMinutes: -180),
            sample(stage: .asleepREM,  durationMinutes: 83,  endOffsetMinutes: -120),
            sample(stage: .awake,      durationMinutes: 20,  endOffsetMinutes: -100)
        ]
        stub.sleepSamplesToReturn = fullNight
        await service.refresh()

        let yesterdayWakeUp = calendar.startOfDay(for: yesterday)
        let descriptor = FetchDescriptor<DailySleepSnapshot>(
            predicate: #Predicate { $0.wakeUpDate == yesterdayWakeUp }
        )
        XCTAssertEqual(try context.fetch(descriptor).first?.totalSleepMinutes, 323,
                       "Initial refresh must capture the full 5h 23m overnight session")

        // STEP 2 — call `ingestSamples` with a narrow 12-hour window that starts AFTER
        // yesterday's wake-up window's 6 PM boundary. The stub returns only the tiny
        // 97-min sliver that survives the narrow window's endDate filter. Without the
        // guard, `upsertSnapshot` would overwrite 323 with 97. With the guard, the
        // snapshot stays at 323.
        let narrowWindowStart = calendar.date(byAdding: .hour, value: -12, to: now)!
        let partialSliver: [HKSleepSampleSnapshot] = [
            sample(stage: .asleepCore, durationMinutes: 97, endOffsetMinutes: -10)
        ]
        stub.sleepSamplesToReturn = partialSliver

        // Sanity: the narrow window must actually fail to cover yesterday's wake-up
        // window — otherwise the guard isn't exercised. yesterday's wake-up window
        // starts at 6 PM two days ago; narrowWindowStart is roughly 12 hours before
        // `now`, which is sometime today, so narrowWindowStart is somewhere yesterday.
        // That's strictly AFTER 6 PM two days ago → guard should trigger.
        let yesterdayWindowStart = calendar.date(bySettingHour: 18, minute: 0, second: 0,
            of: calendar.date(byAdding: .day, value: -2, to: calendar.startOfDay(for: now))!)!
        XCTAssertGreaterThan(narrowWindowStart, yesterdayWindowStart,
                             "Test setup must produce a narrow window that starts AFTER yesterday's wake-up window boundary")

        await service.ingestSamples(from: narrowWindowStart, to: now, context: context)

        XCTAssertEqual(try context.fetch(descriptor).first?.totalSleepMinutes, 323,
                       "Narrow-window ingest must not overwrite a previously-complete snapshot (partial-coverage guard)")
    }

    /// Positive companion to the guard test: with the *new* wide observer window
    /// (`observerFetchWindowStart` = 6 PM two days ago - 2h buffer), `handleSleepObserverFire`
    /// fully covers yesterday's wake-up window and IS allowed to legitimately update
    /// the snapshot with fresh data. Confirms the guard isn't over-eager.
    func test_observerFireWithWideWindow_updatesSnapshotWithFreshData() async throws {
        let stub = StubHealthKitClient()
        UserSettings.shared.healthKitEnabled = true
        let service = RecoveryStatusService(client: stub)
        service.setContext(context)

        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let yesterdayMorning = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: yesterday) ?? yesterday

        func sample(stage: HKSleepStage, durationMinutes: Int, endOffsetMinutes: Int) -> HKSleepSampleSnapshot {
            let end = yesterdayMorning.addingTimeInterval(TimeInterval(endOffsetMinutes * 60))
            let start = end.addingTimeInterval(TimeInterval(-durationMinutes * 60))
            return HKSleepSampleSnapshot(uuid: UUID(), stage: stage, startDate: start, endDate: end, sourceBundleID: "com.apple.health.sleep")
        }

        // Seed with one set of samples, then provide updated samples for the observer
        // fire. Yesterday's wake-up window is fully inside the new ~48h observer fetch
        // window, so the guard allows the update through.
        stub.sleepSamplesToReturn = [sample(stage: .asleepCore, durationMinutes: 300, endOffsetMinutes: -120)]
        await service.refresh()

        let yesterdayWakeUp = calendar.startOfDay(for: yesterday)
        let descriptor = FetchDescriptor<DailySleepSnapshot>(
            predicate: #Predicate { $0.wakeUpDate == yesterdayWakeUp }
        )
        XCTAssertEqual(try context.fetch(descriptor).first?.totalSleepMinutes, 300)

        // Updated samples reflect a more complete picture once the Watch finishes syncing
        // (Apple Watch often writes stage data in chunks over the morning).
        stub.sleepSamplesToReturn = [
            sample(stage: .asleepCore, durationMinutes: 300, endOffsetMinutes: -120),
            sample(stage: .asleepDeep, durationMinutes: 45,  endOffsetMinutes: -60)
        ]
        await service.handleSleepObserverFire()

        XCTAssertEqual(try context.fetch(descriptor).first?.totalSleepMinutes, 345,
                       "Observer fire whose wide window fully covers yesterday's wake-up window must update the snapshot with the new aggregate")
    }
}
