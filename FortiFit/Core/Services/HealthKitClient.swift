import Foundation

enum HealthKitAuthorizationStatus {
    case notDetermined
    case granted
    case denied
}

struct HealthKitWorkoutSnapshot {
    let uuid: UUID
    let activityTypeRawValue: UInt
    let sourceBundleID: String
    let startDate: Date
    let endDate: Date
    let durationMinutes: Int
    let distanceKm: Double?
    let avgHeartRate: Int?
    let maxHeartRate: Int?
    let activeEnergyKcal: Double?
    let totalEnergyBurnedKcal: Double?
    let elevationAscendedMeters: Double?
    let exerciseMinutes: Int?
    let indoor: Bool?
    let workoutPlanId: UUID?

    init(uuid: UUID, activityTypeRawValue: UInt, sourceBundleID: String, startDate: Date, endDate: Date, durationMinutes: Int, distanceKm: Double? = nil, avgHeartRate: Int? = nil, maxHeartRate: Int? = nil, activeEnergyKcal: Double? = nil, totalEnergyBurnedKcal: Double? = nil, elevationAscendedMeters: Double? = nil, exerciseMinutes: Int? = nil, indoor: Bool? = nil, workoutPlanId: UUID? = nil) {
        self.uuid = uuid
        self.activityTypeRawValue = activityTypeRawValue
        self.sourceBundleID = sourceBundleID
        self.startDate = startDate
        self.endDate = endDate
        self.durationMinutes = durationMinutes
        self.distanceKm = distanceKm
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.activeEnergyKcal = activeEnergyKcal
        self.totalEnergyBurnedKcal = totalEnergyBurnedKcal
        self.elevationAscendedMeters = elevationAscendedMeters
        self.exerciseMinutes = exerciseMinutes
        self.indoor = indoor
        self.workoutPlanId = workoutPlanId
    }

    var mapping: HealthKitTypeMapping {
        HealthKitTypeMapping.map(activityTypeRawValue: activityTypeRawValue)
    }
}

struct ActivitySummarySnapshot {
    let date: Date
    let moveCalories: Double
    let exerciseMinutes: Double
    let standHours: Int
    let moveGoal: Double
    let exerciseGoal: Double
    let standGoal: Int
}

// MARK: - Sleep (Phase 11)

/// Stage values for sleep-analysis category samples. Mirrors
/// `HKCategoryValueSleepAnalysis` cases consumed by FitNavi, keeping the HealthKit
/// framework out of consumer code.
enum HKSleepStage {
    case asleepDeep
    case asleepREM
    case asleepCore
    case asleepUnspecified
    case awake
    case inBed
}

/// Plain Swift struct returned by `HealthKitClient.fetchSleepSamples(from:to:)`.
/// Mirrors `HealthKitWorkoutSnapshot`'s protocol-boundary pattern.
/// See SERVICES.md § HealthKitClient → HKSleepSampleSnapshot.
struct HKSleepSampleSnapshot {
    let uuid: UUID
    let stage: HKSleepStage
    let startDate: Date
    let endDate: Date
    let sourceBundleID: String

    /// Raw, un-rounded duration in seconds. Aggregation must sum these and round
    /// once at the very end (BUG-052) — per-sample rounding to minutes drifts by
    /// several minutes across a night's worth of stage-transition samples vs.
    /// Apple Health's `TIME ASLEEP`.
    var durationSeconds: TimeInterval {
        max(endDate.timeIntervalSince(startDate), 0)
    }
}

protocol HealthKitClient: Sendable {
    func requestAuthorization() async throws
    func authorizationStatus() -> HealthKitAuthorizationStatus
    func fetchWorkouts(since anchor: Data?) async throws -> (workouts: [HealthKitWorkoutSnapshot], deletedUUIDs: [UUID], newAnchor: Data?)
    func observeWorkoutChanges(handler: @escaping @Sendable () -> Void)
    func observeEffortScoreChanges(handler: @escaping @Sendable () -> Void)
    func fetchEffortScore(for hkWorkoutUUID: UUID) async throws -> Int?
    func sourceName(for bundleID: String) -> String

    // Activity Rings (Phase 8.6)
    func fetchActivitySummary(for date: Date) async throws -> ActivitySummarySnapshot?
    func fetchActivitySummaries(from start: Date, to end: Date) async throws -> [ActivitySummarySnapshot]
    func observeActivitySummaryChanges(handler: @escaping @Sendable () -> Void)
    func hasAppleWatchData(within days: Int) async throws -> Bool

    // Sleep (Phase 11)
    func fetchSleepSamples(from start: Date, to end: Date) async throws -> [HKSleepSampleSnapshot]
    func observeSleepChanges(handler: @escaping @Sendable () -> Void)
    func fetchSleepDurationGoal() async throws -> TimeInterval?
    func hasRecentSleepData(within days: Int) async throws -> Bool
}

final class NoOpHealthKitClient: HealthKitClient, @unchecked Sendable {
    func requestAuthorization() async throws {}
    func authorizationStatus() -> HealthKitAuthorizationStatus { .notDetermined }
    func fetchWorkouts(since anchor: Data?) async throws -> (workouts: [HealthKitWorkoutSnapshot], deletedUUIDs: [UUID], newAnchor: Data?) { ([], [], nil) }
    func observeWorkoutChanges(handler: @escaping @Sendable () -> Void) {}
    func observeEffortScoreChanges(handler: @escaping @Sendable () -> Void) {}
    func fetchEffortScore(for hkWorkoutUUID: UUID) async throws -> Int? { nil }
    func sourceName(for bundleID: String) -> String { "another app" }
    func fetchActivitySummary(for date: Date) async throws -> ActivitySummarySnapshot? { nil }
    func fetchActivitySummaries(from start: Date, to end: Date) async throws -> [ActivitySummarySnapshot] { [] }
    func observeActivitySummaryChanges(handler: @escaping @Sendable () -> Void) {}
    func hasAppleWatchData(within days: Int) async throws -> Bool { false }
    func fetchSleepSamples(from start: Date, to end: Date) async throws -> [HKSleepSampleSnapshot] { [] }
    func observeSleepChanges(handler: @escaping @Sendable () -> Void) {}
    func fetchSleepDurationGoal() async throws -> TimeInterval? { nil }
    func hasRecentSleepData(within days: Int) async throws -> Bool { false }
}
