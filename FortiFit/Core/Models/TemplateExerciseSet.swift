import Foundation
import SwiftData

@Model
final class TemplateExerciseSet {
    var id: UUID
    var exerciseName: String
    var sets: Int
    var reps: Int
    var weightKg: Double?
    var sortOrder: Int
    var template: WorkoutTemplate?

    init(
        id: UUID = UUID(),
        exerciseName: String,
        sets: Int,
        reps: Int,
        weightKg: Double? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.sets = sets
        self.reps = reps
        self.weightKg = weightKg
        self.sortOrder = sortOrder
    }
}
