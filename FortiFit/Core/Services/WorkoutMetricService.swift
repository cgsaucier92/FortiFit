import Foundation
import SwiftData

enum WorkoutMetric: CaseIterable, Identifiable {
    var id: String { displayLabel }
    case effort, duration, distance,
         avgHR, maxHR,
         activeKcal, totalKcal,
         elevation, exerciseMinutes

    var displayLabel: String {
        switch self {
        case .effort: return "Effort"
        case .duration: return "Duration"
        case .distance: return "Distance"
        case .avgHR: return "Avg HR"
        case .maxHR: return "Max HR"
        case .activeKcal: return "Active kcal"
        case .totalKcal: return "Total kcal"
        case .elevation: return "Elevation"
        case .exerciseMinutes: return "Exercise min"
        }
    }

    var sfSymbol: String {
        switch self {
        case .effort: return AppConstants.summaryFieldSymbols["RPE"] ?? "chart.bar.fill"
        case .duration: return AppConstants.summaryFieldSymbols["Duration"] ?? "clock"
        case .distance: return AppConstants.summaryFieldSymbols["Distance"] ?? "ruler"
        case .avgHR: return AppConstants.summaryFieldSymbols["AvgHR"] ?? "heart.fill"
        case .maxHR: return AppConstants.summaryFieldSymbols["MaxHR"] ?? "heart.fill"
        case .activeKcal: return AppConstants.summaryFieldSymbols["ActiveKcal"] ?? "flame.fill"
        case .totalKcal: return AppConstants.summaryFieldSymbols["TotalKcal"] ?? "flame"
        case .elevation: return AppConstants.summaryFieldSymbols["Elevation"] ?? "arrow.up.right"
        case .exerciseMinutes: return AppConstants.summaryFieldSymbols["ExerciseMinutes"] ?? "figure.walk"
        }
    }

    var isPReligible: Bool {
        switch self {
        case .distance, .activeKcal, .totalKcal, .elevation: return true
        default: return false
        }
    }

    func value(from workout: Workout) -> Double? {
        switch self {
        case .effort: return workout.rpe.map { Double($0) }
        case .duration: return workout.durationMinutes.map { Double($0) }
        case .distance: return workout.distanceKm
        case .avgHR: return workout.avgHeartRate.map { Double($0) }
        case .maxHR: return workout.maxHeartRate.map { Double($0) }
        case .activeKcal: return workout.activeEnergyKcal
        case .totalKcal: return workout.totalEnergyBurnedKcal
        case .elevation: return workout.elevationAscendedMeters
        case .exerciseMinutes: return workout.exerciseMinutes.map { Double($0) }
        }
    }
}

enum WorkoutMetricService {
    static func comparativeAverage(for metric: WorkoutMetric, workout: Workout, context: ModelContext) -> Double? {
        let workoutType = workout.workoutType
        let workoutID = workout.id
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { w in
                w.workoutType == workoutType && w.id != workoutID
            }
        )
        guard let workouts = try? context.fetch(descriptor) else { return nil }
        let values = workouts.compactMap { metric.value(from: $0) }
        guard values.count >= 3 else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    static func sparklineData(for metric: WorkoutMetric, workout: Workout, days: Int = 30, context: ModelContext) -> [(date: Date, value: Double)] {
        let workoutType = workout.workoutType
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { w in
                w.workoutType == workoutType && w.date >= cutoff
            },
            sortBy: [SortDescriptor(\.date)]
        )
        guard let workouts = try? context.fetch(descriptor) else { return [] }
        let points: [(date: Date, value: Double)] = workouts.compactMap { w in
            guard let val = metric.value(from: w) else { return nil }
            return (date: w.date, value: val)
        }
        return points.count >= 3 ? points : []
    }

    static func isPersonalBest(for metric: WorkoutMetric, workout: Workout, context: ModelContext) -> Bool {
        guard metric.isPReligible else { return false }
        guard let currentValue = metric.value(from: workout) else { return false }
        let workoutType = workout.workoutType
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { w in
                w.workoutType == workoutType
            }
        )
        guard let workouts = try? context.fetch(descriptor) else { return false }
        let values = workouts.compactMap { metric.value(from: $0) }
        guard values.count >= 2 else { return false }
        guard let maxValue = values.max() else { return false }
        return currentValue >= maxValue
    }
}
