import Foundation
import SwiftData

@Model
final class Goal {
    var id: UUID
    var title: String
    var goalType: String        // "Strength PR", "Repetitions PR", "Speed and Distance", "weeklyWorkouts"
    var colorIndex: Int
    var sortOrder: Int

    // Strength PR
    var targetValueKg: Double
    var currentValueKg: Double

    // Repetitions PR
    var targetReps: Int
    var currentReps: Int

    // Speed and Distance
    var targetDistanceKm: Double?
    var currentDistanceKm: Double
    var targetDurationMinutes: Double?
    var currentDurationMinutes: Double
    var linkedWorkoutType: String?
    var lastCelebratedDate: Date?
    var resetDate: Date? = nil

    var headerLabel: String {
        switch goalType {
        case "Strength PR":
            return AppConstants.GoalHeaderLabel.strength
        case "Repetitions PR":
            return AppConstants.GoalHeaderLabel.reps
        case "Speed and Distance":
            switch (targetDistanceKm != nil, targetDurationMinutes != nil) {
            case (true, true):   return AppConstants.GoalHeaderLabel.speed
            case (false, true):  return AppConstants.GoalHeaderLabel.endurance
            case (true, false):  return AppConstants.GoalHeaderLabel.distance
            case (false, false): return AppConstants.GoalHeaderLabel.speed
            }
        case "weeklyWorkouts":
            return AppConstants.GoalHeaderLabel.frequency
        default:
            return AppConstants.GoalHeaderLabel.strength
        }
    }

    init(
        id: UUID = UUID(),
        title: String,
        goalType: String = "Strength PR",
        targetValueKg: Double = 0,
        currentValueKg: Double = 0,
        targetReps: Int = 0,
        currentReps: Int = 0,
        targetDistanceKm: Double? = nil,
        currentDistanceKm: Double = 0,
        targetDurationMinutes: Double? = nil,
        currentDurationMinutes: Double = 0,
        linkedWorkoutType: String? = nil,
        lastCelebratedDate: Date? = nil,
        colorIndex: Int = 0,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.goalType = goalType
        self.targetValueKg = targetValueKg
        self.currentValueKg = currentValueKg
        self.targetReps = targetReps
        self.currentReps = currentReps
        self.targetDistanceKm = targetDistanceKm
        self.currentDistanceKm = currentDistanceKm
        self.targetDurationMinutes = targetDurationMinutes
        self.currentDurationMinutes = currentDurationMinutes
        self.linkedWorkoutType = linkedWorkoutType
        self.lastCelebratedDate = lastCelebratedDate
        self.colorIndex = colorIndex
        self.sortOrder = sortOrder
    }
}
