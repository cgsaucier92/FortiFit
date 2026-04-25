import Foundation
import SwiftData

struct PowerLevelService {

    // MARK: - Result Type

    enum Status: String {
        case deloading = "Deloading"
        case steady = "Steady"
        case rising = "Rising"
        case noData = "No Data"
    }

    struct PowerLevelResult {
        let status: Status
        let statusLabel: String
        let indicator: String
        let indicatorColor: String  // hex
        let message: String
    }

    // MARK: - Public

    /// Calculates the Power Level status by comparing average volume per workout
    /// in the current 30-day window vs. the prior 30-day baseline window.
    /// Scoped to Strength Training and HIIT workouts only.
    static func calculatePowerLevel(context: ModelContext, now: Date = Date()) -> PowerLevelResult {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        // Current period: today - 30 days through today (inclusive)
        let currentStart = calendar.date(byAdding: .day, value: -30, to: today)!
        let currentEnd = calendar.date(byAdding: .day, value: 1, to: today)!  // exclusive upper bound

        // Baseline period: today - 60 days through today - 31 days (inclusive)
        let baselineStart = calendar.date(byAdding: .day, value: -60, to: today)!
        let baselineEnd = calendar.date(byAdding: .day, value: -30, to: today)!  // exclusive upper bound (day -31 + 1 = day -30)

        let currentWorkouts = fetchQualifyingWorkouts(from: currentStart, to: currentEnd, context: context)
        let baselineWorkouts = fetchQualifyingWorkouts(from: baselineStart, to: baselineEnd, context: context)

        let currentAvg = averageVolume(for: currentWorkouts)
        let baselineAvg = averageVolume(for: baselineWorkouts)

        // Both periods empty → no data
        if currentWorkouts.isEmpty && baselineWorkouts.isEmpty {
            return PowerLevelResult(
                status: .noData,
                statusLabel: "",
                indicator: "",
                indicatorColor: "737373",
                message: "Log Strength Training or HIIT workouts to track your power level."
            )
        }

        // No baseline → default to Steady
        if baselineAvg == 0 {
            return makeResult(for: .steady)
        }

        // Current empty with baseline → Deloading
        if currentWorkouts.isEmpty && baselineAvg > 0 {
            return makeResult(for: .deloading)
        }

        // Percentage change
        let pctChange = ((currentAvg - baselineAvg) / baselineAvg) * 100

        if pctChange < -10 {
            return makeResult(for: .deloading)
        } else if pctChange > 10 {
            return makeResult(for: .rising)
        } else {
            return makeResult(for: .steady)
        }
    }

    /// Calculates the total volume for a single workout.
    /// Volume = sum of (sets × reps × effective_weight) across all ExerciseSets.
    /// Bodyweight exercises (weightKg == nil) use effective_weight = 1.0.
    static func workoutVolume(for workout: Workout) -> Double {
        workout.exerciseSets.reduce(0.0) { total, exerciseSet in
            let effectiveWeight = exerciseSet.weightKg ?? 1.0
            return total + Double(exerciseSet.sets) * Double(exerciseSet.reps) * effectiveWeight
        }
    }

    // MARK: - Private

    /// Fetches Strength Training and HIIT workouts within a date range.
    private static func fetchQualifyingWorkouts(
        from startDate: Date, to endDate: Date, context: ModelContext
    ) -> [Workout] {
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { workout in
                workout.date >= startDate && workout.date < endDate &&
                (workout.workoutType == "Strength Training" || workout.workoutType == "HIIT")
            }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Computes the average volume per workout for a list of workouts.
    private static func averageVolume(for workouts: [Workout]) -> Double {
        guard !workouts.isEmpty else { return 0 }
        let totalVolume = workouts.reduce(0.0) { $0 + workoutVolume(for: $1) }
        return totalVolume / Double(workouts.count)
    }

    /// Creates a PowerLevelResult for a given status.
    private static func makeResult(for status: Status) -> PowerLevelResult {
        let indicator: String
        let indicatorColor: String
        let message: String

        switch status {
        case .deloading:
            indicator = "↓"
            indicatorColor = "ef4444"
            message = "Your volume has decreased over the last 30 days."
        case .steady:
            indicator = "—"
            indicatorColor = "3b82f6"
            message = "Your volume has been consistent over the last 30 days."
        case .rising:
            indicator = "↑"
            indicatorColor = "10b981"
            message = "Your volume has been increasing over the last 30 days."
        case .noData:
            indicator = ""
            indicatorColor = "737373"
            message = "Log Strength Training or HIIT workouts to track your power level."
        }

        return PowerLevelResult(
            status: status,
            statusLabel: status.rawValue,
            indicator: indicator,
            indicatorColor: indicatorColor,
            message: message
        )
    }
}
