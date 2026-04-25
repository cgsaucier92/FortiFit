import Foundation
import SwiftData

struct GoalSnapshotService {

    // MARK: - Recompute Snapshot (Per-Workout, Best-of-Day)

    /// Computes and writes (or deletes) the snapshot for a goal on a specific date.
    /// Uses in-scope matching workouts on that date per per-workout value rules.
    /// Idempotent: creates, updates, or deletes the single snapshot for (goalId, date).
    static func recomputeSnapshot(goal: Goal, date: Date, context: ModelContext) {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)

        // Fetch all workouts and filter to those on this date and in-scope
        let allWorkouts = WorkoutService.fetchAll(context: context)
        let workoutsOnDate = allWorkouts.filter { calendar.isDate($0.date, inSameDayAs: targetDate) }
        let inScopeWorkouts = workoutsOnDate.filter { GoalService.isWorkoutInScope($0, for: goal) }

        // Compute best-of-day value
        let computedValue = computeBestOfDayValue(goal: goal, workouts: inScopeWorkouts, context: context)

        // Find existing snapshot for this goal+date
        let goalId = goal.id
        let predicate = #Predicate<GoalSnapshot> { snapshot in
            snapshot.goalId == goalId
        }
        let descriptor = FetchDescriptor<GoalSnapshot>(predicate: predicate)
        let existing = (try? context.fetch(descriptor)) ?? []
        let todaySnapshot = existing.first { calendar.isDate($0.date, inSameDayAs: targetDate) }

        if let value = computedValue {
            if let snapshot = todaySnapshot {
                snapshot.value = value
            } else {
                let snapshot = GoalSnapshot(goalId: goalId, date: targetDate, value: value)
                context.insert(snapshot)
            }
        } else {
            // No supporting data — delete existing snapshot if any
            if let snapshot = todaySnapshot {
                context.delete(snapshot)
            }
        }
        try? context.save()
    }

    // MARK: - Recompute Snapshots For Workout

    /// For each affected goal, recomputes the snapshot on the workout's date.
    /// If priorDate is supplied (date was changed during edit), also recomputes on priorDate.
    static func recomputeSnapshotsForWorkout(
        workout: Workout,
        affectedGoals: [Goal],
        priorDate: Date? = nil,
        context: ModelContext
    ) {
        for goal in affectedGoals {
            recomputeSnapshot(goal: goal, date: workout.date, context: context)
            if let priorDate = priorDate {
                recomputeSnapshot(goal: goal, date: priorDate, context: context)
            }
        }
    }

    // MARK: - Rebuild Snapshots

    /// Drops all existing snapshots for a goal and rebuilds from all in-scope
    /// matching workouts. Called when resetDate clears on goal definition edit.
    static func rebuildSnapshots(goal: Goal, context: ModelContext) {
        // Delete all existing snapshots for this goal
        deleteSnapshots(goalId: goal.id, context: context)

        // Fetch ALL workouts and filter to in-scope
        let allWorkouts = WorkoutService.fetchAll(context: context)
        let inScopeWorkouts = allWorkouts.filter { GoalService.isWorkoutInScope($0, for: goal) }

        // Group by calendar date
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: inScopeWorkouts) { workout in
            calendar.startOfDay(for: workout.date)
        }

        // For each date with in-scope workouts, compute and write a snapshot
        for (date, workoutsOnDate) in grouped {
            if let value = computeBestOfDayValue(goal: goal, workouts: workoutsOnDate, context: context) {
                let snapshot = GoalSnapshot(goalId: goal.id, date: date, value: value)
                context.insert(snapshot)
            }
        }
        try? context.save()
    }

    // MARK: - Fetch Snapshots

    /// Returns snapshots for the given goal within the last N days, sorted by date ascending.
    static func fetchSnapshots(goalId: UUID, days: Int = 30, context: ModelContext) -> [GoalSnapshot] {
        let calendar = Calendar.current
        let cutoff = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date())

        let predicate = #Predicate<GoalSnapshot> { snapshot in
            snapshot.goalId == goalId && snapshot.date >= cutoff
        }
        let descriptor = FetchDescriptor<GoalSnapshot>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Delete Snapshots

    /// Removes all snapshots for a given goal. Called on goal deletion cascade and Reset Goal Progress.
    static func deleteSnapshots(goalId: UUID, context: ModelContext) {
        let predicate = #Predicate<GoalSnapshot> { snapshot in
            snapshot.goalId == goalId
        }
        let descriptor = FetchDescriptor<GoalSnapshot>(predicate: predicate)
        let snapshots = (try? context.fetch(descriptor)) ?? []
        for snapshot in snapshots {
            context.delete(snapshot)
        }
        try? context.save()
    }

    // MARK: - Private: Best-of-Day Value Computation

    /// Computes the best-of-day snapshot value for a goal from a set of workouts.
    /// Returns nil if no matching data exists (snapshot should be deleted).
    private static func computeBestOfDayValue(
        goal: Goal,
        workouts: [Workout],
        context: ModelContext
    ) -> Double? {
        let goalTitleLower = goal.title.lowercased()

        switch goal.goalType {
        case "Strength PR":
            var maxWeight: Double?
            for workout in workouts {
                for set in workout.exerciseSets {
                    guard set.exerciseName.lowercased() == goalTitleLower else { continue }
                    guard let weight = set.weightKg else { continue }
                    if maxWeight == nil || weight > maxWeight! {
                        maxWeight = weight
                    }
                }
            }
            return maxWeight

        case "Repetitions PR":
            var maxReps: Int?
            for workout in workouts {
                for set in workout.exerciseSets {
                    guard set.exerciseName.lowercased() == goalTitleLower else { continue }
                    if maxReps == nil || set.reps > maxReps! {
                        maxReps = set.reps
                    }
                }
            }
            return maxReps.map { Double($0) }

        case "Speed and Distance":
            guard let linkedType = goal.linkedWorkoutType else { return nil }
            let matching = workouts.filter { $0.workoutType == linkedType }
            guard !matching.isEmpty else { return nil }

            let hasDistTarget = goal.targetDistanceKm != nil
            let hasDurTarget = goal.targetDurationMinutes != nil

            if hasDistTarget && !hasDurTarget {
                // Distance-only
                guard let targetDist = goal.targetDistanceKm, targetDist > 0 else { return nil }
                let maxDist = matching.compactMap(\.distanceKm).max()
                guard let dist = maxDist else { return nil }
                return min((dist / targetDist) * 100, 100)

            } else if !hasDistTarget && hasDurTarget {
                // Duration-only (endurance)
                guard let targetDur = goal.targetDurationMinutes, targetDur > 0 else { return nil }
                let maxDur = matching.compactMap(\.durationMinutes).map(Double.init).max()
                guard let dur = maxDur else { return nil }
                return min((dur / targetDur) * 100, 100)

            } else if hasDistTarget && hasDurTarget {
                // Speed-target: compute overallProgress% for each workout, pick max
                guard let targetDist = goal.targetDistanceKm, targetDist > 0,
                      let targetDur = goal.targetDurationMinutes, targetDur > 0 else { return nil }

                var bestProgress: Double?
                for workout in matching {
                    guard let dist = workout.distanceKm, let dur = workout.durationMinutes else { continue }
                    let durDouble = Double(dur)
                    let distPct = min((dist / targetDist) * 100, 100)
                    let durPct: Double
                    if durDouble <= targetDur {
                        durPct = 100
                    } else {
                        durPct = min((targetDur / durDouble) * 100, 100)
                    }
                    let overallProgress = min(distPct, durPct)
                    if bestProgress == nil || overallProgress > bestProgress! {
                        bestProgress = overallProgress
                    }
                }
                return bestProgress
            }
            return nil

        case "weeklyWorkouts":
            let current = WorkoutService.fetchCurrentWeekWorkouts(context: context).count
            return Double(current)

        default:
            return nil
        }
    }
}
