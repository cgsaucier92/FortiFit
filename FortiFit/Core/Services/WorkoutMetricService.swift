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

    enum SparklineMode: Equatable {
        /// Trailing N-day window ending at the workout's date.
        case trailingWindow(days: Int, anchorDate: Date)
        /// Last N same-type sessions at-or-before the workout's date — used when the
        /// trailing window doesn't have enough points (sparse cadence types like a
        /// once-a-month long run).
        case recentFallback(sessionCount: Int)
    }

    struct SparklineResult: Equatable {
        var points: [(date: Date, value: Double)]
        var mode: SparklineMode

        static func == (lhs: SparklineResult, rhs: SparklineResult) -> Bool {
            guard lhs.mode == rhs.mode, lhs.points.count == rhs.points.count else { return false }
            for (a, b) in zip(lhs.points, rhs.points) where a.date != b.date || a.value != b.value {
                return false
            }
            return true
        }
    }

    /// Returns sparkline points and the mode used to compute them, or nil if fewer than 3
    /// same-type sessions with this metric exist at-or-before the workout's date.
    ///
    /// The window is anchored to `workout.date` (not `Date()`), so opening the detail sheet
    /// for an older workout shows the 30 days *leading up to that workout* rather than the
    /// last 30 days relative to today (see BUG-072).
    static func sparklineData(for metric: WorkoutMetric, workout: Workout, days: Int = 30, fallbackSessionCount: Int = 5, context: ModelContext) -> SparklineResult? {
        let workoutType = workout.workoutType
        let anchor = workout.date
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: anchor) ?? anchor

        let windowDescriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { w in
                w.workoutType == workoutType && w.date >= cutoff && w.date <= anchor
            },
            sortBy: [SortDescriptor(\.date)]
        )
        if let windowWorkouts = try? context.fetch(windowDescriptor) {
            let windowPoints: [(date: Date, value: Double)] = windowWorkouts.compactMap { w in
                guard let val = metric.value(from: w) else { return nil }
                return (date: w.date, value: val)
            }
            if windowPoints.count >= 3 {
                return SparklineResult(
                    points: windowPoints,
                    mode: .trailingWindow(days: days, anchorDate: anchor)
                )
            }
        }

        var fallbackDescriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { w in
                w.workoutType == workoutType && w.date <= anchor
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        fallbackDescriptor.fetchLimit = fallbackSessionCount
        guard let recent = try? context.fetch(fallbackDescriptor) else { return nil }
        let fallbackPoints: [(date: Date, value: Double)] = recent.reversed().compactMap { w in
            guard let val = metric.value(from: w) else { return nil }
            return (date: w.date, value: val)
        }
        guard fallbackPoints.count >= 3 else { return nil }
        return SparklineResult(
            points: fallbackPoints,
            mode: .recentFallback(sessionCount: fallbackPoints.count)
        )
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
