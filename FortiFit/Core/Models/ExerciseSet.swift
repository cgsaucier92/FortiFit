import Foundation
import SwiftData

@Model
final class ExerciseSet {
    var id: UUID
    var exerciseName: String
    var sets: Int
    var reps: Int
    var weightKg: Double?
    var sortOrder: Int
    var workout: Workout?

    init(
        id: UUID = UUID(),
        exerciseName: String,
        sets: Int,
        reps: Int,
        weightKg: Double? = nil,
        sortOrder: Int = 0,
        workout: Workout? = nil
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.sets = sets
        self.reps = reps
        self.weightKg = weightKg
        self.sortOrder = sortOrder
        self.workout = workout
    }
}
