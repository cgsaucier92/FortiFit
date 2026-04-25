import Foundation
import SwiftData

@Model
final class WorkoutMatchRejection {
    var id: UUID
    var healthKitUUID: UUID
    var workoutId: UUID
    var rejectedDate: Date

    init(
        id: UUID = UUID(),
        healthKitUUID: UUID,
        workoutId: UUID,
        rejectedDate: Date = .now
    ) {
        self.id = id
        self.healthKitUUID = healthKitUUID
        self.workoutId = workoutId
        self.rejectedDate = rejectedDate
    }
}
