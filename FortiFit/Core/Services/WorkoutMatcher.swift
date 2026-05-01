import Foundation
import SwiftData

enum MatchResult {
    case highConfidence(workoutId: UUID)
    case lowerConfidence(workoutId: UUID)
    case noMatch
}

enum MatchDecision {
    case link
    case keepSeparate
    case decideLater
}

struct PendingMatch: Identifiable {
    let id = UUID()
    let workoutId: UUID
    let snapshot: HealthKitWorkoutSnapshot
}

@MainActor
@Observable
final class WorkoutMatcher {
    private var pendingQueue: [PendingMatch] = []

    func findMatch(forIncomingHKWorkout snapshot: HealthKitWorkoutSnapshot, context: ModelContext) -> MatchResult {
        let mapping = snapshot.mapping
        let hkType = mapping.workoutType
        let hkStart = snapshot.startDate
        let hkEnd = snapshot.endDate

        let manualWorkouts = fetchManualWorkouts(ofType: hkType, context: context)

        for workout in manualWorkouts {
            if isRejected(healthKitUUID: snapshot.uuid, workoutId: workout.id, context: context) {
                continue
            }

            let wStart = workout.date
            let wEnd = computeEndDate(for: workout)

            if isHighConfidence(hkStart: hkStart, hkEnd: hkEnd, wStart: wStart, wEnd: wEnd) {
                return .highConfidence(workoutId: workout.id)
            }
            if isLowerConfidence(hkStart: hkStart, wStart: wStart) {
                return .lowerConfidence(workoutId: workout.id)
            }
        }
        return .noMatch
    }

    func findMatch(forNewManualWorkout workout: Workout, context: ModelContext) -> MatchResult {
        let hkWorkouts = fetchHKLinkedWorkouts(ofType: workout.workoutType, context: context)

        let wStart = workout.date
        let wEnd = computeEndDate(for: workout)

        for hkWorkout in hkWorkouts {
            if isRejected(healthKitUUID: hkWorkout.healthKitUUID!, workoutId: workout.id, context: context) {
                continue
            }

            let hkStart = hkWorkout.date
            let hkEnd = computeEndDate(for: hkWorkout)

            if isHighConfidence(hkStart: hkStart, hkEnd: hkEnd, wStart: wStart, wEnd: wEnd) {
                return .highConfidence(workoutId: hkWorkout.id)
            }
            if isLowerConfidence(hkStart: hkStart, wStart: wStart) {
                return .lowerConfidence(workoutId: hkWorkout.id)
            }
        }
        return .noMatch
    }

    static func applyLink(workout: Workout, snapshot: HealthKitWorkoutSnapshot) {
        workout.healthKitUUID = snapshot.uuid
        workout.healthKitSourceBundleID = snapshot.sourceBundleID
        workout.healthKitActivityType = snapshot.mapping.displayString
        workout.date = snapshot.startDate
        workout.durationMinutes = snapshot.durationMinutes
        workout.distanceKm = snapshot.distanceKm
        workout.avgHeartRate = snapshot.avgHeartRate
        workout.maxHeartRate = snapshot.maxHeartRate
        workout.activeEnergyKcal = snapshot.activeEnergyKcal
        workout.totalEnergyBurnedKcal = snapshot.totalEnergyBurnedKcal
        workout.elevationAscendedMeters = snapshot.elevationAscendedMeters
        workout.exerciseMinutes = snapshot.exerciseMinutes
        workout.indoor = snapshot.indoor
        workout.lastModifiedDate = .now
    }

    // MARK: - Prompt Queue

    func queuePendingMatch(workoutId: UUID, snapshot: HealthKitWorkoutSnapshot) {
        let alreadyQueued = pendingQueue.contains { $0.workoutId == workoutId && $0.snapshot.uuid == snapshot.uuid }
        guard !alreadyQueued else { return }
        pendingQueue.append(PendingMatch(workoutId: workoutId, snapshot: snapshot))
    }

    func pendingMatches() -> [PendingMatch] {
        pendingQueue
    }

    func resolvePending(workoutId: UUID, snapshot: HealthKitWorkoutSnapshot, decision: MatchDecision, context: ModelContext) {
        switch decision {
        case .link:
            if let workout = fetchWorkout(byId: workoutId, context: context) {
                WorkoutMatcher.applyLink(workout: workout, snapshot: snapshot)
                try? context.save()
            }
        case .keepSeparate:
            let rejection = WorkoutMatchRejection(healthKitUUID: snapshot.uuid, workoutId: workoutId, reason: .keepSeparate)
            context.insert(rejection)
            try? context.save()
        case .decideLater:
            return
        }

        pendingQueue.removeAll { $0.workoutId == workoutId && $0.snapshot.uuid == snapshot.uuid }
    }

    // MARK: - Matching Rules

    private func isHighConfidence(hkStart: Date, hkEnd: Date, wStart: Date, wEnd: Date) -> Bool {
        abs(hkStart.timeIntervalSince(wStart)) <= 300 && abs(hkEnd.timeIntervalSince(wEnd)) <= 300
    }

    private func isLowerConfidence(hkStart: Date, wStart: Date) -> Bool {
        let cal = Calendar.current
        guard cal.isDate(hkStart, inSameDayAs: wStart) else { return false }
        return abs(hkStart.timeIntervalSince(wStart)) <= 14400
    }

    // MARK: - Helpers

    private func computeEndDate(for workout: Workout) -> Date {
        let durationSeconds = TimeInterval((workout.durationMinutes ?? 0) * 60)
        return workout.date.addingTimeInterval(durationSeconds)
    }

    private func fetchManualWorkouts(ofType workoutType: String, context: ModelContext) -> [Workout] {
        let predicate = #Predicate<Workout> { workout in
            workout.workoutType == workoutType && workout.healthKitUUID == nil
        }
        let descriptor = FetchDescriptor<Workout>(predicate: predicate)
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchHKLinkedWorkouts(ofType workoutType: String, context: ModelContext) -> [Workout] {
        let predicate = #Predicate<Workout> { workout in
            workout.workoutType == workoutType && workout.healthKitUUID != nil
        }
        let descriptor = FetchDescriptor<Workout>(predicate: predicate)
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchWorkout(byId id: UUID, context: ModelContext) -> Workout? {
        let predicate = #Predicate<Workout> { workout in
            workout.id == id
        }
        let descriptor = FetchDescriptor<Workout>(predicate: predicate)
        return (try? context.fetch(descriptor))?.first
    }

    private func isRejected(healthKitUUID: UUID, workoutId: UUID, context: ModelContext) -> Bool {
        let predicate = #Predicate<WorkoutMatchRejection> { rejection in
            rejection.healthKitUUID == healthKitUUID && rejection.workoutId == workoutId
        }
        let descriptor = FetchDescriptor<WorkoutMatchRejection>(predicate: predicate)
        let count = (try? context.fetchCount(descriptor)) ?? 0
        return count > 0
    }
}
