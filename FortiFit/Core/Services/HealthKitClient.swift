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

protocol HealthKitClient: Sendable {
    func requestAuthorization() async throws
    func authorizationStatus() -> HealthKitAuthorizationStatus
    func fetchWorkouts(since anchor: Data?) async throws -> (workouts: [HealthKitWorkoutSnapshot], deletedUUIDs: [UUID], newAnchor: Data?)
    func observeWorkoutChanges(handler: @escaping @Sendable () -> Void)
    func observeEffortScoreChanges(handler: @escaping @Sendable () -> Void)
    func fetchEffortScore(for hkWorkoutUUID: UUID) async throws -> Int?
    func sourceName(for bundleID: String) -> String?
}
