import Foundation
import SwiftData

enum RejectionReason: String, Codable {
    case keepSeparate
    case unlinked
}

@Model
final class WorkoutMatchRejection {
    var id: UUID
    var healthKitUUID: UUID
    var workoutId: UUID
    var rejectedDate: Date
    var reason: String

    init(
        id: UUID = UUID(),
        healthKitUUID: UUID,
        workoutId: UUID,
        rejectedDate: Date = .now,
        reason: RejectionReason = .keepSeparate
    ) {
        self.id = id
        self.healthKitUUID = healthKitUUID
        self.workoutId = workoutId
        self.rejectedDate = rejectedDate
        self.reason = reason.rawValue
    }

    var rejectionReason: RejectionReason {
        RejectionReason(rawValue: reason) ?? .keepSeparate
    }
}
