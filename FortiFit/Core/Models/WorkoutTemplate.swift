import Foundation
import SwiftData

@Model
final class WorkoutTemplate {
    var id: UUID
    var name: String
    var workoutType: String
    var durationMinutes: Int?
    var dateCreated: Date

    @Relationship(deleteRule: .cascade, inverse: \TemplateExerciseSet.template)
    var exerciseSets: [TemplateExerciseSet]

    init(
        id: UUID = UUID(),
        name: String,
        workoutType: String,
        durationMinutes: Int? = nil,
        dateCreated: Date = Date(),
        exerciseSets: [TemplateExerciseSet] = []
    ) {
        self.id = id
        self.name = name
        self.workoutType = workoutType
        self.durationMinutes = durationMinutes
        self.dateCreated = dateCreated
        self.exerciseSets = exerciseSets
    }
}
