import Foundation
import SwiftData

@Model
final class ScheduledWorkout {
    var id: UUID
    var templateId: UUID?
    var templateSnapshot: Data?
    var scheduledDate: Date
    var scheduledTime: Date?
    var workoutType: String
    var workoutName: String
    var durationMinutes: Int?
    var status: String
    var completedWorkoutId: UUID?
    var recurrenceRule: String?
    var recurrenceGroupId: UUID?
    var dateCreated: Date

    init(
        id: UUID = UUID(),
        templateId: UUID? = nil,
        templateSnapshot: Data? = nil,
        scheduledDate: Date,
        scheduledTime: Date? = nil,
        workoutType: String,
        workoutName: String,
        durationMinutes: Int? = nil,
        status: String = "planned",
        completedWorkoutId: UUID? = nil,
        recurrenceRule: String? = nil,
        recurrenceGroupId: UUID? = nil,
        dateCreated: Date = Date()
    ) {
        self.id = id
        self.templateId = templateId
        self.templateSnapshot = templateSnapshot
        // Zero time component for day-level matching
        self.scheduledDate = Calendar.current.startOfDay(for: scheduledDate)
        self.scheduledTime = scheduledTime
        self.workoutType = workoutType
        self.workoutName = workoutName
        self.durationMinutes = durationMinutes
        self.status = status
        self.completedWorkoutId = completedWorkoutId
        self.recurrenceRule = recurrenceRule
        self.recurrenceGroupId = recurrenceGroupId
        self.dateCreated = dateCreated
    }
}
