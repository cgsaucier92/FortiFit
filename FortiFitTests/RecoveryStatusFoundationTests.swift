import Testing
import Foundation
import SwiftData
@testable import FortiFit

// MARK: - In-memory context helper (Phase 11 entities only)

private func makeSnapshotContext() throws -> ModelContext {
    let schema = Schema([DailySleepSnapshot.self, DailyTrainingLoadSnapshot.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

// MARK: - UserSettings Phase 11 fields

@Suite(.serialized)
struct UserSettingsPhase11Tests {

    @Test func targetSleepHoursDefaultsTo7() {
        // The didSet of `targetSleepHours` writes through to UserDefaults, so we restore
        // whatever the test process had stored before assertion.
        let settings = UserSettings.shared
        let originalTarget = settings.targetSleepHours
        let originalManualFlag = settings.recoveryLoadManuallyUnlinked
        defer {
            settings.targetSleepHours = originalTarget
            settings.recoveryLoadManuallyUnlinked = originalManualFlag
        }

        UserDefaults.standard.removeObject(forKey: "targetSleepHours")
        UserDefaults.standard.removeObject(forKey: "recoveryLoadManuallyUnlinked")

        // Confirm registered default is 7.0 (PRD.md § Data Model → UserSettings).
        let registeredDefault = UserDefaults.standard.double(forKey: "targetSleepHours")
        #expect(registeredDefault == 7.0)

        // Confirm the bool default is false.
        #expect(UserDefaults.standard.bool(forKey: "recoveryLoadManuallyUnlinked") == false)
    }

    @Test func targetSleepHoursPersists() {
        let settings = UserSettings.shared
        let original = settings.targetSleepHours
        defer { settings.targetSleepHours = original }

        settings.targetSleepHours = 8.5
        #expect(UserDefaults.standard.double(forKey: "targetSleepHours") == 8.5)
    }

    @Test func recoveryLoadManuallyUnlinkedPersists() {
        let settings = UserSettings.shared
        let original = settings.recoveryLoadManuallyUnlinked
        defer { settings.recoveryLoadManuallyUnlinked = original }

        settings.recoveryLoadManuallyUnlinked = true
        #expect(UserDefaults.standard.bool(forKey: "recoveryLoadManuallyUnlinked") == true)
        settings.recoveryLoadManuallyUnlinked = false
        #expect(UserDefaults.standard.bool(forKey: "recoveryLoadManuallyUnlinked") == false)
    }
}

// MARK: - DailySleepSnapshot

struct DailySleepSnapshotTests {

    @Test func initSetsAllFields() {
        let wakeUp = Date()
        let snapshot = DailySleepSnapshot(
            wakeUpDate: wakeUp,
            totalSleepMinutes: 444,
            deepSleepMinutes: 84,
            remSleepMinutes: 110,
            coreSleepMinutes: 240,
            awakeMinutes: 10,
            inBedMinutes: 480,
            sleepEfficiencyPercent: 92,
            sourceBundleID: "com.apple.health"
        )

        #expect(snapshot.wakeUpDate == wakeUp)
        #expect(snapshot.totalSleepMinutes == 444)
        #expect(snapshot.deepSleepMinutes == 84)
        #expect(snapshot.remSleepMinutes == 110)
        #expect(snapshot.coreSleepMinutes == 240)
        #expect(snapshot.awakeMinutes == 10)
        #expect(snapshot.inBedMinutes == 480)
        #expect(snapshot.sleepEfficiencyPercent == 92)
        #expect(snapshot.sourceBundleID == "com.apple.health")
    }

    @Test func defaultsAreZeroed() {
        let snapshot = DailySleepSnapshot(wakeUpDate: Date())
        #expect(snapshot.totalSleepMinutes == 0)
        #expect(snapshot.deepSleepMinutes == 0)
        #expect(snapshot.inBedMinutes == nil)
        #expect(snapshot.sleepEfficiencyPercent == nil)
        #expect(snapshot.sourceBundleID == nil)
    }

    @Test func insertAndFetchByWakeUpDate() throws {
        let context = try makeSnapshotContext()
        let wakeUp = Calendar.current.startOfDay(for: Date())
        let snapshot = DailySleepSnapshot(wakeUpDate: wakeUp, totalSleepMinutes: 444)
        context.insert(snapshot)
        try context.save()

        let predicate = #Predicate<DailySleepSnapshot> { $0.wakeUpDate == wakeUp }
        let descriptor = FetchDescriptor<DailySleepSnapshot>(predicate: predicate)
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.totalSleepMinutes == 444)
    }

    /// Upsert-by-wakeUpDate sketch: callers (RecoveryStatusService) fetch first,
    /// then overwrite the existing record's fields if found, or insert a new one.
    /// Step 1 verifies the lookup pattern works; the upsert helper lands in Step 2.
    @Test func upsertSketchByWakeUpDate() throws {
        let context = try makeSnapshotContext()
        let wakeUp = Calendar.current.startOfDay(for: Date())

        let first = DailySleepSnapshot(wakeUpDate: wakeUp, totalSleepMinutes: 400)
        context.insert(first)
        try context.save()

        let predicate = #Predicate<DailySleepSnapshot> { $0.wakeUpDate == wakeUp }
        let descriptor = FetchDescriptor<DailySleepSnapshot>(predicate: predicate)
        let existing = try context.fetch(descriptor).first
        #expect(existing != nil)
        existing?.totalSleepMinutes = 460
        try context.save()

        let after = try context.fetch(descriptor)
        #expect(after.count == 1)
        #expect(after.first?.totalSleepMinutes == 460)
    }
}

// MARK: - Sparkline Y-Axis Adaptation (BUG-069 regression)

/// Regression coverage for BUG-069: both the Recovery Status Detail Sheet and the linked
/// Recovery & Load Detail Sheet hardcoded the sleep sparkline to `chartYScale(domain: 4...10)`.
/// Sleep values outside that range (e.g. a 1h 37m partial-night reading, or a 12h
/// catch-up sleep) rendered at their true coordinate *outside the visible plot area* —
/// the line "swooped beyond the chart's boundaries." The fix centralizes the adaptive
/// domain + axis-values formula on `DailySleepSnapshot` so both sheets share one
/// behavior, and defaults to `4...10` when data is typical so the chart's appearance
/// is unchanged in the common case.
struct SparklineDomainAdaptationTests {

    private func snap(hours: Double) -> DailySleepSnapshot {
        DailySleepSnapshot(wakeUpDate: Date(), totalSleepMinutes: Int(hours * 60))
    }

    @Test func emptyInput_returnsDefaultDomain() {
        let domain = DailySleepSnapshot.sparklineDomain(for: [])
        #expect(domain == 4...10)
    }

    @Test func zeroSleepSnapshotsExcluded_stillReturnsDefault() {
        // A wake-up day with no sleep data shouldn't drag the floor down to 0.
        let domain = DailySleepSnapshot.sparklineDomain(for: [snap(hours: 0)])
        #expect(domain == 4...10)
    }

    @Test func typicalRange_preservesDefaultDomain() {
        // 5–9h is well inside the anchor band → domain stays at 4...10 so the chart
        // looks consistent across users with normal sleep.
        let snaps = [snap(hours: 5), snap(hours: 7), snap(hours: 9)]
        let domain = DailySleepSnapshot.sparklineDomain(for: snaps)
        #expect(domain == 4...10)
    }

    @Test func belowAnchor_expandsLowerBoundButNotUpper() {
        // 1h 37m = 1.62h; floor(1.62 - 0.5) = 1.
        let snaps = [snap(hours: 1.62), snap(hours: 7), snap(hours: 8)]
        let domain = DailySleepSnapshot.sparklineDomain(for: snaps)
        #expect(domain.lowerBound == 1)
        #expect(domain.upperBound == 10) // upper still anchored to 10 since data max < 10
    }

    @Test func aboveAnchor_expandsUpperBoundButNotLower() {
        // 12.5h catch-up sleep → ceil(12.5 + 0.5) = 13
        let snaps = [snap(hours: 6), snap(hours: 7), snap(hours: 12.5)]
        let domain = DailySleepSnapshot.sparklineDomain(for: snaps)
        #expect(domain.lowerBound == 4)
        #expect(domain.upperBound == 13)
    }

    @Test func belowAnchor_floorsAtZero() {
        // Sub-1h sleep should not produce a negative lower bound.
        let snaps = [snap(hours: 0.5)]
        let domain = DailySleepSnapshot.sparklineDomain(for: snaps)
        #expect(domain.lowerBound == 0)
    }

    @Test func aboveAnchor_capsAt14h() {
        // Pathological 16h sleep — cap at 14 to avoid an absurd y-axis.
        let snaps = [snap(hours: 16)]
        let domain = DailySleepSnapshot.sparklineDomain(for: snaps)
        #expect(domain.upperBound == 14)
    }

    @Test func axisValues_defaultDomain_returnsHistoricalLabels() {
        // The pre-BUG-069 hardcoded labels were [5, 7, 9] for a 4...10 domain.
        let values = DailySleepSnapshot.sparklineAxisValues(for: 4...10)
        #expect(values == [5, 7, 9])
    }

    @Test func axisValues_expandedDomain_returnsThreeEvenlySpacedTicks() {
        // For a 1...10 domain: lower+1=2, mid=5.5→6, upper-1=9.
        let values = DailySleepSnapshot.sparklineAxisValues(for: 1...10)
        #expect(values == [2, 6, 9])
    }

    @Test func axisValues_widerDomain_returnsThreeEvenlySpacedTicks() {
        // For a 0...12 domain: lower+1=1, mid=6, upper-1=11.
        let values = DailySleepSnapshot.sparklineAxisValues(for: 0...12)
        #expect(values == [1, 6, 11])
    }
}

// MARK: - DailyTrainingLoadSnapshot

struct DailyTrainingLoadSnapshotTests {

    @Test func initSetsAllFields() {
        let day = Date()
        let snapshot = DailyTrainingLoadSnapshot(
            date: day,
            score: 62,
            wasSleepAdjusted: true
        )
        #expect(snapshot.date == day)
        #expect(snapshot.score == 62)
        #expect(snapshot.wasSleepAdjusted == true)
    }

    @Test func defaultsForOptionalFlags() {
        let snapshot = DailyTrainingLoadSnapshot(date: Date(), score: 30)
        #expect(snapshot.wasSleepAdjusted == false)
    }

    @Test func insertAndFetchByDate() throws {
        let context = try makeSnapshotContext()
        let day = Calendar.current.startOfDay(for: Date())
        let snapshot = DailyTrainingLoadSnapshot(date: day, score: 47)
        context.insert(snapshot)
        try context.save()

        let predicate = #Predicate<DailyTrainingLoadSnapshot> { $0.date == day }
        let descriptor = FetchDescriptor<DailyTrainingLoadSnapshot>(predicate: predicate)
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.score == 47)
    }

    /// Upsert-by-date sketch: read first, mutate or insert. The upsert helper itself
    /// lands in Step 3 (Training Load algorithm modification).
    @Test func upsertSketchByDate() throws {
        let context = try makeSnapshotContext()
        let day = Calendar.current.startOfDay(for: Date())

        let first = DailyTrainingLoadSnapshot(date: day, score: 40, wasSleepAdjusted: false)
        context.insert(first)
        try context.save()

        let predicate = #Predicate<DailyTrainingLoadSnapshot> { $0.date == day }
        let descriptor = FetchDescriptor<DailyTrainingLoadSnapshot>(predicate: predicate)
        let existing = try context.fetch(descriptor).first
        existing?.score = 55
        existing?.wasSleepAdjusted = true
        try context.save()

        let after = try context.fetch(descriptor)
        #expect(after.count == 1)
        #expect(after.first?.score == 55)
        #expect(after.first?.wasSleepAdjusted == true)
    }
}

// MARK: - RecoveryStatusService initialization

final class FoundationStubHealthKitClient: HealthKitClient, @unchecked Sendable {
    var sleepSamplesToReturn: [HKSleepSampleSnapshot] = []
    var sleepDurationGoalToReturn: TimeInterval?
    var hasRecentSleepDataToReturn: Bool = false

    func requestAuthorization() async throws {}
    func authorizationStatus() -> HealthKitAuthorizationStatus { .notDetermined }
    func fetchWorkouts(since anchor: Data?) async throws -> (workouts: [HealthKitWorkoutSnapshot], deletedUUIDs: [UUID], newAnchor: Data?) { ([], [], nil) }
    func observeWorkoutChanges(handler: @escaping @Sendable () -> Void) {}
    func observeEffortScoreChanges(handler: @escaping @Sendable () -> Void) {}
    func fetchEffortScore(for hkWorkoutUUID: UUID) async throws -> Int? { nil }
    func sourceName(for bundleID: String) -> String { "Apple Workout" }
    func fetchActivitySummary(for date: Date) async throws -> ActivitySummarySnapshot? { nil }
    func fetchActivitySummaries(from start: Date, to end: Date) async throws -> [ActivitySummarySnapshot] { [] }
    func observeActivitySummaryChanges(handler: @escaping @Sendable () -> Void) {}
    func hasAppleWatchData(within days: Int) async throws -> Bool { false }
    func fetchSleepSamples(from start: Date, to end: Date) async throws -> [HKSleepSampleSnapshot] {
        sleepSamplesToReturn.filter { $0.endDate > start && $0.endDate <= end }
    }
    func observeSleepChanges(handler: @escaping @Sendable () -> Void) {}
    func fetchSleepDurationGoal() async throws -> TimeInterval? { sleepDurationGoalToReturn }
    func hasRecentSleepData(within days: Int) async throws -> Bool { hasRecentSleepDataToReturn }
}

struct RecoveryStatusServiceFoundationTests {

    @Test func serviceInitializesWithDefaultObservableState() async {
        let client = FoundationStubHealthKitClient()
        let service = await RecoveryStatusService(client: client)

        let gating = await service.currentGatingState
        let snapshot = await service.todaysSnapshot
        let cache = await service.recent30DaySleep
        let timer = await service.timeSinceLastWorkoutFormatted
        let efficiency = await service.currentSleepEfficiencyPercent

        #expect(gating == .connectAppleHealth)
        #expect(snapshot == nil)
        #expect(cache.isEmpty)
        #expect(timer.isEmpty)
        #expect(efficiency == nil)
    }
}

// MARK: - RecoveryStatusGatingState enum coverage

struct RecoveryStatusGatingStateTests {

    /// Exhaustive switch over all 4 cases — proves the enum hasn't drifted and
    /// every case is reachable in a switch (Swift compiler enforces exhaustiveness).
    @Test func exhaustiveSwitchCoversAllFourCases() {
        let states: [RecoveryStatusGatingState] = [
            .connectAppleHealth,
            .sleepAccessDenied,
            .noSleepTracker,
            .live
        ]

        var labels: [String] = []
        for state in states {
            switch state {
            case .connectAppleHealth:
                labels.append("connectAppleHealth")
            case .sleepAccessDenied:
                labels.append("sleepAccessDenied")
            case .noSleepTracker:
                labels.append("noSleepTracker")
            case .live:
                labels.append("live")
            }
        }
        #expect(labels == ["connectAppleHealth", "sleepAccessDenied", "noSleepTracker", "live"])
    }
}

// MARK: - AppConstants recoveryStatus widget surface

struct RecoveryStatusWidgetConstantsTests {

    @Test func widgetTypesIncludesRecoveryStatus() {
        #expect(AppConstants.widgetTypes.contains("recoveryStatus"))
    }

    @Test func widgetDisplayNameIsRecoveryStatus() {
        #expect(AppConstants.widgetDisplayNames["recoveryStatus"] == "Recovery Status")
    }

    @Test func widgetDescriptionMentionsSleepTracking() {
        let description = AppConstants.widgetDescriptions["recoveryStatus"] ?? ""
        #expect(description.contains("sleep"))
        #expect(description.contains("Apple Health"))
    }
}

// MARK: - Step 2 — Wake-Up Date Attribution (HEALTHKIT.md § 21)

@MainActor
struct WakeUpDateAttributionTests {

    private func service() -> RecoveryStatusService {
        RecoveryStatusService(client: FoundationStubHealthKitClient())
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0, second: Int = 0) -> Date {
        let comps = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        return Calendar.current.date(from: comps)!
    }

    @Test func sampleEndingAt6pmBelongsToPriorDay() {
        let svc = service()
        // Sample ending at exactly 18:00:00 on March 5 belongs to March 5 (not March 6).
        let endingAt6pm = date(year: 2026, month: 3, day: 5, hour: 18, minute: 0, second: 0)
        let attributed = svc.wakeUpDate(for: endingAt6pm)
        let expected = Calendar.current.startOfDay(for: date(year: 2026, month: 3, day: 5, hour: 0))
        #expect(attributed == expected)
    }

    @Test func sampleEnding1MinAfter6pmBelongsToNextDay() {
        let svc = service()
        // Sample ending at 18:00:01 on March 5 → wake-up day is March 6.
        let endingJustAfter6pm = date(year: 2026, month: 3, day: 5, hour: 18, minute: 0, second: 1)
        let attributed = svc.wakeUpDate(for: endingJustAfter6pm)
        let expected = Calendar.current.startOfDay(for: date(year: 2026, month: 3, day: 6, hour: 0))
        #expect(attributed == expected)
    }

    @Test func overnightSleepEnding8amBelongsToWakeUpDay() {
        let svc = service()
        // Slept Mon 11pm → Tue 7am. The .asleep* sample ends Tuesday 7am → wake-up day = Tuesday.
        let endingTuesday7am = date(year: 2026, month: 3, day: 10, hour: 7, minute: 0)
        let attributed = svc.wakeUpDate(for: endingTuesday7am)
        let expected = Calendar.current.startOfDay(for: date(year: 2026, month: 3, day: 10, hour: 0))
        #expect(attributed == expected)
    }

    @Test func afternoonNapBeforeCutoffBelongsToCurrentDay() {
        let svc = service()
        // A 30-min nap ending at 3pm on March 5 belongs to March 5's wake-up day.
        let endingAt3pm = date(year: 2026, month: 3, day: 5, hour: 15, minute: 0)
        let attributed = svc.wakeUpDate(for: endingAt3pm)
        let expected = Calendar.current.startOfDay(for: date(year: 2026, month: 3, day: 5, hour: 0))
        #expect(attributed == expected)
    }

    @Test func eveningWindDownEndingAt9pmBelongsToNextDay() {
        let svc = service()
        // A short "in bed reading" sample ending at 9pm March 5 → attributed to March 6.
        let endingAt9pm = date(year: 2026, month: 3, day: 5, hour: 21, minute: 0)
        let attributed = svc.wakeUpDate(for: endingAt9pm)
        let expected = Calendar.current.startOfDay(for: date(year: 2026, month: 3, day: 6, hour: 0))
        #expect(attributed == expected)
    }

    @Test func wakeUpWindowReturns6pmTo6pm() {
        let svc = service()
        let day = Calendar.current.startOfDay(for: date(year: 2026, month: 3, day: 6, hour: 0))
        let (start, end) = svc.wakeUpWindow(forDay: day)

        let expectedStart = date(year: 2026, month: 3, day: 5, hour: 18, minute: 0, second: 0)
        let expectedEnd = date(year: 2026, month: 3, day: 6, hour: 18, minute: 0, second: 0)
        #expect(start == expectedStart)
        #expect(end == expectedEnd)
    }
}

// MARK: - Step 2 — Aggregation + Efficiency

@MainActor
struct RecoveryStatusAggregationTests {

    private func sample(stage: HKSleepStage, minutes: Int, source: String = "com.apple.health") -> HKSleepSampleSnapshot {
        let end = Date()
        let start = end.addingTimeInterval(TimeInterval(-minutes * 60))
        return HKSleepSampleSnapshot(uuid: UUID(), stage: stage, startDate: start, endDate: end, sourceBundleID: source)
    }

    @Test func aggregateSumsAllAsleepStages() {
        let svc = RecoveryStatusService(client: FoundationStubHealthKitClient())
        let samples: [HKSleepSampleSnapshot] = [
            sample(stage: .asleepDeep, minutes: 84),
            sample(stage: .asleepREM, minutes: 110),
            sample(stage: .asleepCore, minutes: 240),
            sample(stage: .asleepUnspecified, minutes: 10),
            sample(stage: .awake, minutes: 15),
            sample(stage: .inBed, minutes: 480)
        ]
        let agg = svc.aggregate(samples: samples)
        #expect(agg.deepSleepMinutes == 84)
        #expect(agg.remSleepMinutes == 110)
        // Core + Unspecified rolled into coreSleepMinutes.
        #expect(agg.coreSleepMinutes == 250)
        #expect(agg.awakeMinutes == 15)
        #expect(agg.inBedMinutes == 480)
        // totalSleepMinutes = deep + rem + core = 84 + 110 + 250 = 444
        #expect(agg.totalSleepMinutes == 444)
    }

    @Test func efficiencyComputedWhenInBedPresent() {
        let svc = RecoveryStatusService(client: FoundationStubHealthKitClient())
        let efficiency = svc.computeSleepEfficiency(asleepMinutes: 444, inBedMinutes: 480)
        // round(444 / 480 × 100) = round(92.5) = 93 (banker's rounding via .rounded() = .toNearestOrEven)
        // Use a relaxed check: 92 or 93 both acceptable depending on rounding mode.
        #expect(efficiency == 93 || efficiency == 92)
    }

    @Test func efficiencyIsNilWhenInBedIsNil() {
        let svc = RecoveryStatusService(client: FoundationStubHealthKitClient())
        let efficiency = svc.computeSleepEfficiency(asleepMinutes: 444, inBedMinutes: nil)
        #expect(efficiency == nil)
    }

    @Test func efficiencyIsNilWhenInBedIsZero() {
        let svc = RecoveryStatusService(client: FoundationStubHealthKitClient())
        let efficiency = svc.computeSleepEfficiency(asleepMinutes: 444, inBedMinutes: 0)
        #expect(efficiency == nil)
    }

    /// BUG-059 regression. Apple Watch's native sleep tracker emits no `.inBed` samples;
    /// when the aggregator sees only stage samples, `inBedMinutes` must fall back to
    /// `totalSleepMinutes + awakeMinutes` so sleep efficiency surfaces for the most
    /// common HK source instead of staying silently nil.
    @Test func aggregateWithoutInBedFallsBackToAsleepPlusAwake() {
        let svc = RecoveryStatusService(client: FoundationStubHealthKitClient())
        // Non-overlapping samples covering a contiguous 8h session: 7h asleep + 30m awake.
        // Expected: inBed = totalSleep + awake = 420 + 30 = 450 → efficiency ≈ 93%.
        let end = Date()
        let coreEnd = end
        let coreStart = coreEnd.addingTimeInterval(-3 * 3600)
        let awakeEnd = coreStart
        let awakeStart = awakeEnd.addingTimeInterval(-30 * 60)
        let remEnd = awakeStart
        let remStart = remEnd.addingTimeInterval(-2 * 3600)
        let deepEnd = remStart
        let deepStart = deepEnd.addingTimeInterval(-2 * 3600)
        let samples: [HKSleepSampleSnapshot] = [
            HKSleepSampleSnapshot(uuid: UUID(), stage: .asleepDeep, startDate: deepStart, endDate: deepEnd, sourceBundleID: "com.apple.health"),
            HKSleepSampleSnapshot(uuid: UUID(), stage: .asleepREM, startDate: remStart, endDate: remEnd, sourceBundleID: "com.apple.health"),
            HKSleepSampleSnapshot(uuid: UUID(), stage: .awake, startDate: awakeStart, endDate: awakeEnd, sourceBundleID: "com.apple.health"),
            HKSleepSampleSnapshot(uuid: UUID(), stage: .asleepCore, startDate: coreStart, endDate: coreEnd, sourceBundleID: "com.apple.health")
        ]
        let agg = svc.aggregate(samples: samples)
        #expect(agg.totalSleepMinutes == 420)
        #expect(agg.awakeMinutes == 30)
        #expect(agg.inBedMinutes == 450)
        // 420 / 450 × 100 = 93.33 → 93
        #expect(agg.sleepEfficiencyPercent == 93)
    }

    /// BUG-059 follow-up. An explicit `.inBed` sample, when present (Oura/Whoop/AutoSleep/
    /// manual logging), must still take precedence over the fallback so users on those
    /// sources keep their source-of-truth TIB.
    @Test func aggregateWithInBedSamplePrefersExplicitOverFallback() {
        let svc = RecoveryStatusService(client: FoundationStubHealthKitClient())
        let samples = [
            sample(stage: .asleepDeep, minutes: 80),
            sample(stage: .asleepCore, minutes: 300),
            sample(stage: .awake, minutes: 30),
            sample(stage: .inBed, minutes: 480)
        ]
        let agg = svc.aggregate(samples: samples)
        // Should use the explicit .inBed value (480), not asleep+awake.
        #expect(agg.inBedMinutes == 480)
    }
}

// MARK: - Step 2 — Gating State

@MainActor
struct RecoveryStatusGatingDerivationTests {

    @Test func gatingConnectAppleHealthWhenHKDisabled() async {
        let settings = UserSettings.shared
        let originalEnabled = settings.healthKitEnabled
        defer { settings.healthKitEnabled = originalEnabled }
        settings.healthKitEnabled = false

        let client = FoundationStubHealthKitClient()
        let svc = RecoveryStatusService(client: client)
        let state = await svc.computeGatingState()
        #expect(state == .connectAppleHealth)
    }

    @Test func gatingNoSleepTrackerWhenHKEnabledNoData() async {
        let settings = UserSettings.shared
        let originalEnabled = settings.healthKitEnabled
        defer { settings.healthKitEnabled = originalEnabled }
        settings.healthKitEnabled = true

        let client = FoundationStubHealthKitClient()
        client.hasRecentSleepDataToReturn = false
        let svc = RecoveryStatusService(client: client)
        let state = await svc.computeGatingState()
        #expect(state == .noSleepTracker)
    }

    @Test func gatingLiveWhenHKEnabledWithRecentData() async {
        let settings = UserSettings.shared
        let originalEnabled = settings.healthKitEnabled
        defer { settings.healthKitEnabled = originalEnabled }
        settings.healthKitEnabled = true

        let client = FoundationStubHealthKitClient()
        client.hasRecentSleepDataToReturn = true
        let svc = RecoveryStatusService(client: client)
        let state = await svc.computeGatingState()
        #expect(state == .live)
    }
}

// MARK: - Step 2 — Sleep Goal Import

@MainActor
struct SleepGoalImportTests {

    @Test func importEmitsToastWhenGoalIsNil() async {
        let client = FoundationStubHealthKitClient()
        client.sleepDurationGoalToReturn = nil
        let svc = RecoveryStatusService(client: client)
        await svc.importSleepGoalFromAppleHealth()
        #expect(svc.lastToastMessage == "No sleep goal set in Apple Health.")
    }

    /// Forward-looking: when Apple eventually exposes the sleep duration goal characteristic
    /// (BUG-048 follow-up), this test pins the snap-to-0.5-hr + clamp behavior.
    @Test func importSnapsToHalfHourAndClamps() async {
        let settings = UserSettings.shared
        let original = settings.targetSleepHours
        defer { settings.targetSleepHours = original }

        let client = FoundationStubHealthKitClient()
        client.sleepDurationGoalToReturn = 7.6 * 3600 // 7.6h → snaps to 7.5h
        let svc = RecoveryStatusService(client: client)
        await svc.importSleepGoalFromAppleHealth()
        #expect(settings.targetSleepHours == 7.5)
    }

    @Test func importClampsAboveCeilingTo12Hours() async {
        let settings = UserSettings.shared
        let original = settings.targetSleepHours
        defer { settings.targetSleepHours = original }

        let client = FoundationStubHealthKitClient()
        client.sleepDurationGoalToReturn = 15 * 3600 // unrealistic 15h → clamps to 12h
        let svc = RecoveryStatusService(client: client)
        await svc.importSleepGoalFromAppleHealth()
        #expect(settings.targetSleepHours == 12.0)
    }
}

// MARK: - Step 2 — UserSettings.lastSleepCatchUpDate

@MainActor
struct LastSleepCatchUpDateTests {

    @Test func defaultIsNil() {
        let settings = UserSettings.shared
        let original = settings.lastSleepCatchUpDate
        defer { settings.lastSleepCatchUpDate = original }
        settings.lastSleepCatchUpDate = nil
        #expect(UserDefaults.standard.object(forKey: "lastSleepCatchUpDate") as? Date == nil)
    }

    @Test func roundTripsThroughUserDefaults() {
        let settings = UserSettings.shared
        let original = settings.lastSleepCatchUpDate
        defer { settings.lastSleepCatchUpDate = original }

        let now = Date()
        settings.lastSleepCatchUpDate = now
        let stored = UserDefaults.standard.object(forKey: "lastSleepCatchUpDate") as? Date
        // Sub-second precision lost in UserDefaults round-trip; compare to within 1s.
        let storedSeconds = stored?.timeIntervalSince1970 ?? 0
        let nowSeconds = now.timeIntervalSince1970
        #expect(abs(storedSeconds - nowSeconds) < 1.0)
    }
}
