import Foundation
import HealthKit
import WorkoutKit

final class DefaultHealthKitClient: HealthKitClient, @unchecked Sendable {
    private let healthStore = HKHealthStore()
    private let settings = UserSettings.shared

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.activitySummaryType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
            HKQuantityType(.flightsClimbed),
            HKQuantityType(.appleExerciseTime),
            HKCategoryType(.appleStandHour)
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

        let (rawWorkouts, deletedUUIDs, anchorData) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<([HKWorkout], [UUID], Data?), Error>) in
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
                let deleted = (deletedObjectsOrNil ?? []).map(\.uuid)

                var anchorData: Data?
                if let newAnchor {
                    anchorData = try? NSKeyedArchiver.archivedData(withRootObject: newAnchor, requiringSecureCoding: true)
                }

                continuation.resume(returning: (workouts, deleted, anchorData))
            }
            healthStore.execute(query)
        }

        var snapshots: [HealthKitWorkoutSnapshot] = []
        for workout in rawWorkouts {
            if let snapshot = await makeSnapshot(from: workout) {
                snapshots.append(snapshot)
            }
        }

        return (snapshots, deletedUUIDs, anchorData)
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

    // MARK: - Activity Rings

    func fetchActivitySummary(for date: Date) async throws -> ActivitySummarySnapshot? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.calendar = calendar

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicate(forActivitySummariesBetweenStart: components, end: components)
            let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let summary = summaries?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: self.makeActivitySnapshot(from: summary, date: date))
            }
            healthStore.execute(query)
        }
    }

    func fetchActivitySummaries(from start: Date, to end: Date) async throws -> [ActivitySummarySnapshot] {
        let calendar = Calendar.current
        var startComponents = calendar.dateComponents([.year, .month, .day], from: start)
        startComponents.calendar = calendar
        var endComponents = calendar.dateComponents([.year, .month, .day], from: end)
        endComponents.calendar = calendar

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicate(forActivitySummariesBetweenStart: startComponents, end: endComponents)
            let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let results = (summaries ?? []).compactMap { summary -> ActivitySummarySnapshot? in
                    guard let date = calendar.date(from: summary.dateComponents(for: calendar)) else { return nil }
                    return self.makeActivitySnapshot(from: summary, date: date)
                }
                continuation.resume(returning: results.sorted { $0.date < $1.date })
            }
            healthStore.execute(query)
        }
    }

    func observeActivitySummaryChanges(handler: @escaping @Sendable () -> Void) {
        let types: [HKSampleType] = [
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKCategoryType(.appleStandHour)
        ]
        for sampleType in types {
            let query = HKObserverQuery(
                sampleType: sampleType,
                predicate: nil
            ) { _, completionHandler, error in
                guard error == nil else {
                    completionHandler()
                    return
                }
                handler()
                completionHandler()
            }
            healthStore.execute(query)
        }
    }

    func hasAppleWatchData(within days: Int = 7) async throws -> Bool {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let datePredicate = HKQuery.predicateForSamples(withStart: cutoff, end: Date(), options: .strictStartDate)

        let appleWatchPredicate = NSPredicate(format: "metadata.%K == YES", HKMetadataKeyWasUserEntered)
        let sourcePredicate = HKQuery.predicateForObjects(from: HKSource.default())

        let energyType = HKQuantityType(.activeEnergyBurned)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: energyType,
                predicate: datePredicate,
                limit: 10,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let hasWatch = (samples ?? []).contains { sample in
                    sample.sourceRevision.source.bundleIdentifier.hasPrefix("com.apple.health")
                }
                continuation.resume(returning: hasWatch)
            }
            healthStore.execute(query)
        }
    }

    private func makeActivitySnapshot(from summary: HKActivitySummary, date: Date) -> ActivitySummarySnapshot {
        let moveCal = summary.activeEnergyBurned.doubleValue(for: .kilocalorie())
        let exerciseMin = summary.appleExerciseTime.doubleValue(for: .minute())
        let standHrs = Int(summary.appleStandHours.doubleValue(for: .count()))
        let moveGoal = summary.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie())
        let exerciseGoal = summary.appleExerciseTimeGoal.doubleValue(for: .minute())
        let standGoal = Int(summary.appleStandHoursGoal.doubleValue(for: .count()))

        return ActivitySummarySnapshot(
            date: date,
            moveCalories: moveCal,
            exerciseMinutes: exerciseMin,
            standHours: standHrs,
            moveGoal: moveGoal,
            exerciseGoal: exerciseGoal,
            standGoal: standGoal
        )
    }

    // MARK: - Helpers

    private func makeSnapshot(from workout: HKWorkout) async -> HealthKitWorkoutSnapshot? {
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

        var planId: UUID?
        if let plan = try? await workout.workoutPlan {
            planId = plan.id
        }

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
            indoor: isIndoor,
            workoutPlanId: planId
        )
    }
}
