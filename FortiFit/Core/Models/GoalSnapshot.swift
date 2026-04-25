import Foundation
import SwiftData

@Model
final class GoalSnapshot {
    var id: UUID
    var goalId: UUID
    var date: Date
    var value: Double

    init(
        id: UUID = UUID(),
        goalId: UUID,
        date: Date,
        value: Double
    ) {
        self.id = id
        self.goalId = goalId
        self.date = date
        self.value = value
    }
}
