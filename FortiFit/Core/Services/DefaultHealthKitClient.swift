import Foundation
import HealthKit

final class DefaultHealthKitClient: HealthKitClient, @unchecked Sendable {
    private let healthStore = HKHealthStore()
    private let settings = UserSettings.shared

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
            HKQuantityType(.flightsClimbed),
            HKQuantityType(.appleExerciseTime)
        ]
        if #available(iOS 18.0, *) {
            types.insert(HKQuantityType(.workoutEffortScore))
        }
        return types
    }

    func requestAuthorization() async throws {
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
        settings.healthKitAuthorizationRequested = true
    }

    func authorizationStatus() -> HealthKitAuthorizationStatus {
        // HKHealthStore.authorizationStatus(for:) only reflects write/share
        // permission. For read-only apps iOS intentionally hides whether the
        // user granted or denied read access. Once we've presented the
        // authorization prompt, treat it as granted — if the user actually
        // denied read access, queries will simply return no results.
        if settings.healthKitAuthorizationRequested {
            return .granted
        }
        return .notDetermined
    }

    func fetchWorkouts(since anchor: Data?) async throws -> (workouts: [HealthKitWorkoutSnapshot], deletedUUIDs: [UUID], newAnchor: Data?) {
        let hkAnchor: HKQueryAnchor?
        if let anchorData = anchor {
            hkAnchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: anchorData)
        } else {
            hkAnchor = nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: HKObjectType.workoutType(),
                predicate: nil,
                anchor: hkAnchor,
                limit: HKObjectQueryNoLimit
            ) { _, samplesOrNil, deletedObjectsOrNil, newAnchor, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let workouts = (samplesOrNil as? [HKWorkout]) ?? []
                let snapshots = workouts.compactMap { self.makeSnapshot(from: $0) }
                let deletedUUIDs = (deletedObjectsOrNil ?? []).map(\.uuid)

                var anchorData: Data?
                if let newAnchor {
                    anchorData = try? NSKeyedArchiver.archivedData(withRootObject: newAnchor, requiringSecureCoding: true)
                }

                continuation.resume(returning: (snapshots, deletedUUIDs, anchorData))
            }
            healthStore.execute(query)
        }
    }

    func observeWorkoutChanges(handler: @escaping @Sendable () -> Void) {
        let query = HKObserverQuery(sampleType: HKObjectType.workoutType(), predicate: nil) { _, _, error in
            guard error == nil else { return }
            handler()
        }
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: HKObjectType.workoutType(), frequency: .immediate) { _, _ in }
    }

    func observeEffortScoreChanges(handler: @escaping @Sendable () -> Void) {
        guard #available(iOS 18.0, *) else { return }
        let effortType = HKQuantityType(.workoutEffortScore)
        let query = HKObserverQuery(sampleType: effortType, predicate: nil) { _, _, error in
            guard error == nil else { return }
            handler()
        }
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: effortType, frequency: .immediate) { _, _ in }
    }

    func fetchEffortScore(for hkWorkoutUUID: UUID) async throws -> Int? {
        guard #available(iOS 18.0, *) else { return nil }

        let workoutPredicate = HKQuery.predicateForObject(with: hkWorkoutUUID)
        let workoutDescriptor = HKSampleQueryDescriptor(
            predicates: [.workout(workoutPredicate)],
            sortDescriptors: []
        )
        let workouts = try await workoutDescriptor.result(for: healthStore)
        guard let workout = workouts.first else { return nil }

        let effortPredicate = HKQuery.predicateForWorkoutEffortSamplesRelated(workout: workout, activity: nil)
        let effortType = HKQuantityType(.workoutEffortScore)
        let effortDescriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: effortType, predicate: effortPredicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let samples = try await effortDescriptor.result(for: healthStore)

        guard let sample = samples.first else { return nil }
        let unit = HKUnit.appleEffortScore()
        let value = sample.quantity.doubleValue(for: unit)
        return Int(value.rounded())
    }

    func sourceName(for bundleID: String) -> String {
        let appleWatchBundlePrefix = "com.apple.health"
        if bundleID.hasPrefix(appleWatchBundlePrefix) {
            return "Apple Workout"
        }
        let knownSources: [String: String] = [
            "com.strava": "Strava",
            "com.fiit.fiit": "Fiit",
            "com.onepeloton.peloton": "Peloton"
        ]
        for (prefix, name) in knownSources {
            if bundleID.hasPrefix(prefix) {
                return name
            }
        }
        return "another app"
    }

    // MARK: - Helpers

    private func makeSnapshot(from workout: HKWorkout) -> HealthKitWorkoutSnapshot? {
        let durationMinutes = Int((workout.duration / 60.0).rounded())

        var distanceKm: Double?
        if let distanceStat = workout.statistics(for: HKQuantityType(.distanceWalkingRunning)) ?? workout.statistics(for: HKQuantityType(.distanceCycling)) ?? workout.statistics(for: HKQuantityType(.distanceSwimming)) {
            distanceKm = distanceStat.sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo))
        }

        var avgHR: Int?
        var maxHR: Int?
        if let hrStat = workout.statistics(for: HKQuantityType(.heartRate)) {
            let bpmUnit = HKUnit.count().unitDivided(by: .minute())
            if let avg = hrStat.averageQuantity() {
                avgHR = Int(avg.doubleValue(for: bpmUnit).rounded())
            }
            if let max = hrStat.maximumQuantity() {
                maxHR = Int(max.doubleValue(for: bpmUnit).rounded())
            }
        }

        var activeKcal: Double?
        if let stat = workout.statistics(for: HKQuantityType(.activeEnergyBurned)) {
            activeKcal = stat.sumQuantity()?.doubleValue(for: .kilocalorie())
        }

        var totalKcal: Double?
        if let activeVal = activeKcal {
            var basalKcal = 0.0
            if let basalStat = workout.statistics(for: HKQuantityType(.basalEnergyBurned)) {
                basalKcal = basalStat.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0.0
            }
            totalKcal = activeVal + basalKcal
        }

        var elevation: Double?
        if let stat = workout.statistics(for: HKQuantityType(.flightsClimbed)) {
            elevation = stat.sumQuantity()?.doubleValue(for: .meter())
        }

        var exerciseMin: Int?
        if let stat = workout.statistics(for: HKQuantityType(.appleExerciseTime)) {
            exerciseMin = Int((stat.sumQuantity()?.doubleValue(for: .minute()) ?? 0).rounded())
        }

        let isIndoor = workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool

        return HealthKitWorkoutSnapshot(
            uuid: workout.uuid,
            activityTypeRawValue: workout.workoutActivityType.rawValue,
            sourceBundleID: workout.sourceRevision.source.bundleIdentifier,
            startDate: workout.startDate,
            endDate: workout.endDate,
            durationMinutes: durationMinutes,
            distanceKm: distanceKm,
            avgHeartRate: avgHR,
            maxHeartRate: maxHR,
            activeEnergyKcal: activeKcal,
            totalEnergyBurnedKcal: totalKcal,
            elevationAscendedMeters: elevation,
            exerciseMinutes: exerciseMin,
            indoor: isIndoor
        )
    }
}
