import Foundation
import SwiftData

@Model
final class Workout {
    var id: UUID
    var name: String
    var date: Date
    var workoutType: String
    var rpe: Int?
    var note: String?
    var durationMinutes: Int?
    var distanceKm: Double?
    var time: Date?
    var lastModifiedDate: Date? = nil
    var hiddenFromPlan: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.workout)
    var exerciseSets: [ExerciseSet]

    init(
        id: UUID = UUID(),
        name: String,
        date: Date = Date(),
        workoutType: String,
        rpe: Int? = nil,
        note: String? = nil,
        durationMinutes: Int? = nil,
        distanceKm: Double? = nil,
        time: Date? = nil,
        exerciseSets: [ExerciseSet] = []
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.workoutType = workoutType
        self.rpe = rpe
        self.note = note
        self.durationMinutes = durationMinutes
        self.distanceKm = distanceKm
        self.time = time
        self.exerciseSets = exerciseSets
    }
}
