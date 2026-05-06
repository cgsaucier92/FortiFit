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
}
