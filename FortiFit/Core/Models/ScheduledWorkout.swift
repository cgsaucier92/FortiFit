import Foundation
import SwiftData

@Model
final class ScheduledWorkout {
    var id: UUID
    var templateId: UUID?
    @Attribute(originalName: "templateSnapshot") var scheduledWorkoutSnapshot: Data?
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
    var syncToAppleWatch: Bool = false
    var appleWorkoutPlanId: UUID?

    init(
        id: UUID = UUID(),
        templateId: UUID? = nil,
        scheduledWorkoutSnapshot: Data? = nil,
        scheduledDate: Date,
        scheduledTime: Date? = nil,
        workoutType: String,
        workoutName: String,
        durationMinutes: Int? = nil,
        status: String = "planned",
        completedWorkoutId: UUID? = nil,
        recurrenceRule: String? = nil,
        recurrenceGroupId: UUID? = nil,
        dateCreated: Date = Date(),
        syncToAppleWatch: Bool = false,
        appleWorkoutPlanId: UUID? = nil
    ) {
        self.id = id
        self.templateId = templateId
        self.scheduledWorkoutSnapshot = scheduledWorkoutSnapshot
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
        self.syncToAppleWatch = syncToAppleWatch
        self.appleWorkoutPlanId = appleWorkoutPlanId
    }
}
