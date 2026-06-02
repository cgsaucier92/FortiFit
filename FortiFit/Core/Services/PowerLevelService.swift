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
            indicatorColor = "737373"
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

    // MARK: - Detail Sheet Helpers (Phase 8.8)

    struct PowerLevelTopExercise: Hashable, Identifiable {
        let exerciseName: String
        let currentWindowVolume: Double
        let previousWindowVolume: Double
        let deltaPct: Double
        let sessionCountInWindow: Int
        let sparkline30d: [Double]

        var id: String { exerciseName.lowercased() }
    }

    struct PowerLevelWindowComparison {
        let current30dAvg: Double
        let previous30dAvg: Double
        let deltaPct: Double
    }

    enum PowerLevelNudgeArchetype: String {
        case deloading
        case steady
        case rising
        case coldStart
        /// Emitted when the user has ≥ 3 qualifying workouts in the current 30d window but zero
        /// in the prior 30d window — trend percentages cannot be computed against an empty baseline.
        case noBaseline
    }

    struct NudgeInputs {
        var currentSessionCount30d: Int?
        var previousSessionCount30d: Int?
        var topExerciseName: String?
        var avgSessionsPerWeek30d: Double?
        var deltaPct: Int?
    }

    struct PowerLevelNudge {
        let archetype: PowerLevelNudgeArchetype
        let inputs: NudgeInputs
        /// `risingNoTop` when archetype is `.rising` and `topExerciseName` is nil; otherwise rawValue of archetype.
        let messageKey: String
    }

    /// Returns up to `limit` top contributing exercises (current 30d), applying the ≥ 3-session filter.
    static func topContributingExercises(context: ModelContext, now: Date = Date(), limit: Int = 3) -> [PowerLevelTopExercise] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let currentStart = calendar.date(byAdding: .day, value: -30, to: today),
              let currentEnd = calendar.date(byAdding: .day, value: 1, to: today),
              let previousStart = calendar.date(byAdding: .day, value: -60, to: today),
              let previousEnd = calendar.date(byAdding: .day, value: -30, to: today) else {
            return []
        }

        let currentWorkouts = fetchQualifyingWorkouts(from: currentStart, to: currentEnd, context: context)
        let previousWorkouts = fetchQualifyingWorkouts(from: previousStart, to: previousEnd, context: context)

        // Aggregate per-exercise volume + session count + sparkline (current window) and per-exercise volume (previous window)
        struct Aggregate {
            var displayName: String
            var currentVolume: Double = 0
            var sessionsCurrent: Set<UUID> = []
            var sparkline: [Double] = Array(repeating: 0.0, count: 30)
            var previousVolume: Double = 0
        }
        var aggregates: [String: Aggregate] = [:]

        for workout in currentWorkouts {
            for set in workout.exerciseSets {
                let key = set.exerciseName.lowercased()
                var entry = aggregates[key] ?? Aggregate(displayName: set.exerciseName)
                entry.displayName = set.exerciseName
                let weight = set.weightKg ?? 1.0
                let setVolume = Double(set.sets) * Double(set.reps) * weight
                entry.currentVolume += setVolume
                entry.sessionsCurrent.insert(workout.id)
                if let dayIndex = calendar.dateComponents([.day], from: calendar.startOfDay(for: workout.date), to: today).day {
                    let bucket = 29 - dayIndex
                    if bucket >= 0 && bucket < 30 {
                        entry.sparkline[bucket] += setVolume
                    }
                }
                aggregates[key] = entry
            }
        }

        for workout in previousWorkouts {
            for set in workout.exerciseSets {
                let key = set.exerciseName.lowercased()
                guard var entry = aggregates[key] else {
                    // Track previous-window volume even if not in current window (so deltaPct can render meaningfully if filter passes for current)
                    var fresh = Aggregate(displayName: set.exerciseName)
                    let weight = set.weightKg ?? 1.0
                    fresh.previousVolume += Double(set.sets) * Double(set.reps) * weight
                    aggregates[key] = fresh
                    continue
                }
                let weight = set.weightKg ?? 1.0
                entry.previousVolume += Double(set.sets) * Double(set.reps) * weight
                aggregates[key] = entry
            }
        }

        // Apply ≥ 3-session filter
        let qualifying = aggregates.values.filter { $0.sessionsCurrent.count >= 3 }

        let sorted = qualifying.sorted { lhs, rhs in
            if lhs.currentVolume != rhs.currentVolume { return lhs.currentVolume > rhs.currentVolume }
            if lhs.sessionsCurrent.count != rhs.sessionsCurrent.count { return lhs.sessionsCurrent.count > rhs.sessionsCurrent.count }
            return lhs.displayName.lowercased() < rhs.displayName.lowercased()
        }

        return sorted.prefix(limit).map { entry in
            let delta: Double
            if entry.previousVolume > 0 {
                delta = ((entry.currentVolume - entry.previousVolume) / entry.previousVolume) * 100
            } else {
                delta = 0
            }
            return PowerLevelTopExercise(
                exerciseName: entry.displayName,
                currentWindowVolume: entry.currentVolume,
                previousWindowVolume: entry.previousVolume,
                deltaPct: delta,
                sessionCountInWindow: entry.sessionsCurrent.count,
                sparkline30d: entry.sparkline
            )
        }
    }

    /// Returns the current/previous 30d averages and percentage change.
    static func windowComparison(context: ModelContext, now: Date = Date()) -> PowerLevelWindowComparison {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let currentStart = calendar.date(byAdding: .day, value: -30, to: today),
              let currentEnd = calendar.date(byAdding: .day, value: 1, to: today),
              let previousStart = calendar.date(byAdding: .day, value: -60, to: today),
              let previousEnd = calendar.date(byAdding: .day, value: -30, to: today) else {
            return PowerLevelWindowComparison(current30dAvg: 0, previous30dAvg: 0, deltaPct: 0)
        }

        let currentWorkouts = fetchQualifyingWorkouts(from: currentStart, to: currentEnd, context: context)
        let previousWorkouts = fetchQualifyingWorkouts(from: previousStart, to: previousEnd, context: context)

        let currentAvg = averageVolume(for: currentWorkouts)
        let previousAvg = averageVolume(for: previousWorkouts)

        let delta: Double
        if previousAvg > 0 {
            delta = ((currentAvg - previousAvg) / previousAvg) * 100
        } else {
            delta = 0
        }

        return PowerLevelWindowComparison(
            current30dAvg: currentAvg,
            previous30dAvg: previousAvg,
            deltaPct: delta
        )
    }

    /// Computes the calculated contextual nudge per Phase 8.8 resolution order.
    /// Cold-start (< 3 in-window workouts) overrides status. Steady-with-no-top-exercise degrades to cold-start copy.
    static func computeNudge(context: ModelContext, now: Date = Date()) -> PowerLevelNudge {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let currentStart = calendar.date(byAdding: .day, value: -30, to: today),
              let currentEnd = calendar.date(byAdding: .day, value: 1, to: today),
              let previousStart = calendar.date(byAdding: .day, value: -60, to: today),
              let previousEnd = calendar.date(byAdding: .day, value: -30, to: today) else {
            return PowerLevelNudge(archetype: .coldStart, inputs: NudgeInputs(), messageKey: PowerLevelNudgeArchetype.coldStart.rawValue)
        }

        let currentWorkouts = fetchQualifyingWorkouts(from: currentStart, to: currentEnd, context: context)
        let previousWorkouts = fetchQualifyingWorkouts(from: previousStart, to: previousEnd, context: context)

        // Cold-start guard runs first
        if currentWorkouts.count < 3 {
            return PowerLevelNudge(
                archetype: .coldStart,
                inputs: NudgeInputs(),
                messageKey: PowerLevelNudgeArchetype.coldStart.rawValue
            )
        }

        // No-baseline guard: ≥ 3 current-window workouts but zero prior-window history.
        // Trend percentages can't be computed against an empty baseline, so surface that
        // explicitly instead of falling into the steady "flat" copy.
        if previousWorkouts.isEmpty {
            return PowerLevelNudge(
                archetype: .noBaseline,
                inputs: NudgeInputs(currentSessionCount30d: currentWorkouts.count),
                messageKey: PowerLevelNudgeArchetype.noBaseline.rawValue
            )
        }

        let result = calculatePowerLevel(context: context, now: now)
        let currentAvg = averageVolume(for: currentWorkouts)
        let previousAvg = averageVolume(for: previousWorkouts)
        let pctChange: Double
        if previousAvg > 0 {
            pctChange = ((currentAvg - previousAvg) / previousAvg) * 100
        } else {
            pctChange = 0
        }

        let avgSessionsPerWeek = (Double(currentWorkouts.count) / (30.0 / 7.0))
        let avgSessionsRounded = (avgSessionsPerWeek * 10).rounded() / 10

        switch result.status {
        case .deloading:
            return PowerLevelNudge(
                archetype: .deloading,
                inputs: NudgeInputs(
                    currentSessionCount30d: currentWorkouts.count,
                    previousSessionCount30d: previousWorkouts.count
                ),
                messageKey: PowerLevelNudgeArchetype.deloading.rawValue
            )

        case .steady:
            let top = topContributingExercises(context: context, now: now, limit: 1).first
            if let top {
                // The steady "Volume on {top} is flat" copy is only honest if {top} actually has
                // a prior-window baseline. If the cited exercise is new (previousWindowVolume == 0),
                // fall back to the noBaseline copy so the message agrees with the row's em-dash.
                if top.previousWindowVolume > 0 {
                    return PowerLevelNudge(
                        archetype: .steady,
                        inputs: NudgeInputs(topExerciseName: top.exerciseName),
                        messageKey: PowerLevelNudgeArchetype.steady.rawValue
                    )
                } else {
                    return PowerLevelNudge(
                        archetype: .noBaseline,
                        inputs: NudgeInputs(currentSessionCount30d: currentWorkouts.count),
                        messageKey: PowerLevelNudgeArchetype.noBaseline.rawValue
                    )
                }
            } else {
                // Graceful degrade to cold-start copy
                return PowerLevelNudge(
                    archetype: .coldStart,
                    inputs: NudgeInputs(),
                    messageKey: PowerLevelNudgeArchetype.coldStart.rawValue
                )
            }

        case .rising:
            let topAll = topContributingExercises(context: context, now: now, limit: 1).first
            // Only cite the top exercise as a "biggest gainer" when it actually has a prior-window
            // baseline to compare against — otherwise it's a new addition, not a gainer.
            let top = (topAll?.previousWindowVolume ?? 0) > 0 ? topAll : nil
            var inputs = NudgeInputs(
                topExerciseName: top?.exerciseName,
                avgSessionsPerWeek30d: avgSessionsRounded,
                deltaPct: Int(pctChange.rounded())
            )
            inputs.currentSessionCount30d = currentWorkouts.count
            let messageKey = top != nil ? PowerLevelNudgeArchetype.rising.rawValue : "risingNoTop"
            return PowerLevelNudge(
                archetype: .rising,
                inputs: inputs,
                messageKey: messageKey
            )

        case .noData:
            return PowerLevelNudge(
                archetype: .coldStart,
                inputs: NudgeInputs(),
                messageKey: PowerLevelNudgeArchetype.coldStart.rawValue
            )
        }
    }
}
