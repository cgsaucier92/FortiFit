import Foundation
import SwiftData

@Model
final class Workout {
    var id: UUID
    var name: String
    var date: Date
    var workoutType: String
    var rpe: Int?
    var rpeFromHK: Bool = false
    var note: String?
    var durationMinutes: Int?
    var distanceKm: Double?
    var time: Date?
    var lastModifiedDate: Date? = nil
    var hiddenFromPlan: Bool = false

    // HealthKit fields (Phase 8)
    var healthKitUUID: UUID?
    var healthKitSourceBundleID: String?
    var healthKitActivityType: String?
    var avgHeartRate: Int?
    var maxHeartRate: Int?
    var activeEnergyKcal: Double?
    var totalEnergyBurnedKcal: Double?
    var elevationAscendedMeters: Double?
    var exerciseMinutes: Int?
    var indoor: Bool?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.workout)
    var exerciseSets: [ExerciseSet]

    var isHealthKitLinked: Bool {
        healthKitUUID != nil
    }

    var isAppleWatchSourced: Bool {
        guard healthKitUUID != nil,
              let bundleID = healthKitSourceBundleID else { return false }
        return bundleID.hasPrefix("com.apple.health")
    }

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
        exerciseSets: [ExerciseSet] = [],
        healthKitUUID: UUID? = nil,
        healthKitSourceBundleID: String? = nil,
        healthKitActivityType: String? = nil,
        avgHeartRate: Int? = nil,
        maxHeartRate: Int? = nil,
        activeEnergyKcal: Double? = nil,
        totalEnergyBurnedKcal: Double? = nil,
        elevationAscendedMeters: Double? = nil,
        exerciseMinutes: Int? = nil,
        indoor: Bool? = nil
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
        self.healthKitUUID = healthKitUUID
        self.healthKitSourceBundleID = healthKitSourceBundleID
        self.healthKitActivityType = healthKitActivityType
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.activeEnergyKcal = activeEnergyKcal
        self.totalEnergyBurnedKcal = totalEnergyBurnedKcal
        self.elevationAscendedMeters = elevationAscendedMeters
        self.exerciseMinutes = exerciseMinutes
        self.indoor = indoor
    }
}
