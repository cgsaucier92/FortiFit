import Foundation
import SwiftData

struct GoalService {

    // MARK: - Create

    /// Creates a new Strength PR goal.
    static func createExercisePRGoal(
        title: String,
        targetValueKg: Double,
        currentValueKg: Double = 0,
        context: ModelContext
    ) {
        let existingGoals = fetchAll(context: context)
        let goal = Goal(
            title: title,
            goalType: "Strength PR",
            targetValueKg: targetValueKg,
            currentValueKg: currentValueKg,
            colorIndex: existingGoals.count,
            sortOrder: existingGoals.count
        )
        context.insert(goal)
        try? context.save()
    }

    /// Creates a new Repetitions PR goal.
    static func createRepsPRGoal(
        title: String,
        targetReps: Int,
        currentReps: Int = 0,
        context: ModelContext
    ) {
        let existingGoals = fetchAll(context: context)
        let goal = Goal(
            title: title,
            goalType: "Repetitions PR",
            targetReps: targetReps,
            currentReps: currentReps,
            colorIndex: existingGoals.count,
            sortOrder: existingGoals.count
        )
        context.insert(goal)
        try? context.save()
    }

    /// Creates a new Speed and Distance goal.
    static func createSpeedDistanceGoal(
        title: String,
        targetDistanceKm: Double?,
        targetDurationMinutes: Double?,
        linkedWorkoutType: String? = nil,
        context: ModelContext
    ) {
        let existingGoals = fetchAll(context: context)
        let goal = Goal(
            title: title,
            goalType: "Speed and Distance",
            targetDistanceKm: targetDistanceKm,
            targetDurationMinutes: targetDurationMinutes,
            linkedWorkoutType: linkedWorkoutType,
            colorIndex: existingGoals.count,
            sortOrder: existingGoals.count
        )
        context.insert(goal)
        try? context.save()
    }

    /// Creates a new Weekly Workouts goal. Singleton — only one allowed at a time.
    static func createWeeklyWorkoutsGoal(context: ModelContext) {
        let existingGoals = fetchAll(context: context)
        guard !existingGoals.contains(where: { $0.goalType == "weeklyWorkouts" }) else { return }
        let goal = Goal(
            title: "Workouts Per Week",
            goalType: "weeklyWorkouts",
            colorIndex: existingGoals.count,
            sortOrder: existingGoals.count
        )
        context.insert(goal)
        try? context.save()
    }

    /// Returns true if a weeklyWorkouts goal already exists.
    static func weeklyWorkoutsGoalExists(context: ModelContext) -> Bool {
        fetchAll(context: context).contains { $0.goalType == "weeklyWorkouts" }
    }

    // MARK: - Read

    /// Fetches all goals sorted by sortOrder ascending.
    static func fetchAll(context: ModelContext) -> [Goal] {
        let descriptor = FetchDescriptor<Goal>(
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Reset Scoping

    /// Determines if a workout is in-scope for a given goal, considering the goal's resetDate.
    /// A workout is in-scope if: goal has no resetDate, OR workout.date > resetDate,
    /// OR workout.lastModifiedDate > resetDate.
    static func isWorkoutInScope(_ workout: Workout, for goal: Goal) -> Bool {
        guard let resetDate = goal.resetDate else { return true }
        if workout.date > resetDate { return true }
        if let lastModified = workout.lastModifiedDate, lastModified > resetDate {
            return true
        }
        return false
    }

    // MARK: - Weekly Workouts Progress

    /// Computes the weekly workouts goal progress at runtime.
    /// Target comes from UserSettings, current from this week's workout count.
    static func weeklyWorkoutsProgress(context: ModelContext) -> (current: Int, target: Int, percentage: Double, isComplete: Bool) {
        let target = UserSettings.shared.targetWorkoutsPerWeek
        let current = WorkoutService.fetchCurrentWeekWorkouts(context: context).count
        let percentage = target > 0 ? min(Double(current) / Double(target) * 100, 100) : 0
        let isComplete = target > 0 && current >= target
        return (current: current, target: target, percentage: percentage, isComplete: isComplete)
    }

    // MARK: - Progress

    /// Calculates goal completion percentage (0–100) based on goal type.
    /// For Speed and Distance with both targets (speed target), duration uses "at or below target" semantics.
    static func completionPercentage(for goal: Goal) -> Double {
        switch goal.goalType {
        case "Strength PR":
            guard goal.targetValueKg > 0 else { return 0 }
            return min((goal.currentValueKg / goal.targetValueKg) * 100, 100)

        case "Repetitions PR":
            guard goal.targetReps > 0 else { return 0 }
            return min((Double(goal.currentReps) / Double(goal.targetReps)) * 100, 100)

        case "Speed and Distance":
            let distancePct: Double? = goal.targetDistanceKm.map { target -> Double in
                guard target > 0 else { return 0 }
                return min((goal.currentDistanceKm / target) * 100, 100)
            }
            let durationPct: Double? = goal.targetDurationMinutes.map { target -> Double in
                guard target > 0 else { return 0 }
                // Dual-target (speed target): "at or below target" semantics
                if goal.targetDistanceKm != nil {
                    // No duration logged yet means no progress
                    if goal.currentDurationMinutes == 0 { return 0 }
                    if goal.currentDurationMinutes <= target {
                        return 100
                    } else {
                        return min((target / goal.currentDurationMinutes) * 100, 100)
                    }
                }
                // Duration-only (endurance): higher is better
                return min((goal.currentDurationMinutes / target) * 100, 100)
            }
            switch (distancePct, durationPct) {
            case let (d?, dur?): return min(d, dur)
            case let (d?, nil): return d
            case let (nil, dur?): return dur
            default: return 0
            }

        default:
            guard goal.targetValueKg > 0 else { return 0 }
            return min((goal.currentValueKg / goal.targetValueKg) * 100, 100)
        }
    }

    /// Returns true if the goal is complete.
    /// For Speed and Distance with both targets: distance >= target AND duration <= target.
    static func isComplete(_ goal: Goal) -> Bool {
        if goal.goalType == "Speed and Distance",
           let targetDist = goal.targetDistanceKm,
           let targetDur = goal.targetDurationMinutes,
           targetDist > 0, targetDur > 0 {
            // No duration logged yet means not complete
            guard goal.currentDurationMinutes > 0 else { return false }
            return goal.currentDistanceKm >= targetDist && goal.currentDurationMinutes <= targetDur
        }
        return completionPercentage(for: goal) >= 100
    }

    // MARK: - Reorder

    /// Reorders goals by updating sortOrder values based on the new order.
    static func reorder(goals: [Goal], context: ModelContext) {
        for (index, goal) in goals.enumerated() {
            goal.sortOrder = index
        }
        try? context.save()
    }

    // MARK: - Reset Goal Progress

    /// Resets a goal's current values to zero, sets resetDate, clears lastCelebratedDate,
    /// and wipes all snapshots. Does NOT append a zero snapshot.
    static func resetGoalProgress(goal: Goal, context: ModelContext) {
        switch goal.goalType {
        case "Strength PR":
            goal.currentValueKg = 0
        case "Repetitions PR":
            goal.currentReps = 0
        case "Speed and Distance":
            goal.currentDistanceKm = 0
            goal.currentDurationMinutes = 0
        default:
            break // weeklyWorkouts is runtime-derived, not resettable
        }
        goal.resetDate = .now
        goal.lastCelebratedDate = nil
        GoalSnapshotService.deleteSnapshots(goalId: goal.id, context: context)
        try? context.save()
    }

    // MARK: - Delete

    /// Deletes a goal, cascade-deletes GoalSnapshots, and re-indexes remaining goals' sortOrder.
    static func deleteGoal(_ goal: Goal, context: ModelContext) {
        GoalSnapshotService.deleteSnapshots(goalId: goal.id, context: context)
        context.delete(goal)
        try? context.save()

        let remaining = fetchAll(context: context)
        for (index, g) in remaining.enumerated() {
            g.sortOrder = index
        }
        try? context.save()
    }

    // MARK: - Unified Goal Recalculation

    /// Recalculates current values for all affected goals using best-ever-within-scope logic.
    /// Strength PR and Repetitions PR goals are matched by title against affectedExerciseNames.
    /// Speed and Distance goals are matched by linkedWorkoutType against affectedWorkoutTypes.
    /// If a workout is provided, snapshots are automatically recomputed on its date (and priorDate).
    /// For delete flows where the workout is already removed, callers recompute snapshots manually.
    static func recalculateGoals(
        affectedExerciseNames: [String] = [],
        affectedWorkoutTypes: [String] = [],
        workout: Workout? = nil,
        priorDate: Date? = nil,
        context: ModelContext
    ) {
        let goals = fetchAll(context: context)
        let affectedLower = Set(affectedExerciseNames.map { $0.lowercased() })
        let affectedTypes = Set(affectedWorkoutTypes)

        let affectedGoals = goals.filter {
            (($0.goalType == "Strength PR" || $0.goalType == "Repetitions PR") &&
             affectedLower.contains($0.title.lowercased())) ||
            ($0.goalType == "Speed and Distance" &&
             $0.linkedWorkoutType.map { affectedTypes.contains($0) } == true)
        }

        let allWorkouts = WorkoutService.fetchAll(context: context)

        for goal in affectedGoals {
            let previousProgress = completionPercentage(for: goal)
            let inScopeWorkouts = allWorkouts.filter { isWorkoutInScope($0, for: goal) }
            let goalTitleLower = goal.title.lowercased()

            switch goal.goalType {
            case "Strength PR":
                var maxWeight: Double = 0
                for w in inScopeWorkouts {
                    for set in w.exerciseSets {
                        guard set.exerciseName.lowercased() == goalTitleLower else { continue }
                        guard let weight = set.weightKg else { continue }
                        if weight > maxWeight { maxWeight = weight }
                    }
                }
                goal.currentValueKg = maxWeight

            case "Repetitions PR":
                var maxReps: Int = 0
                for w in inScopeWorkouts {
                    for set in w.exerciseSets {
                        guard set.exerciseName.lowercased() == goalTitleLower else { continue }
                        if set.reps > maxReps { maxReps = set.reps }
                    }
                }
                goal.currentReps = maxReps

            case "Speed and Distance":
                guard let linkedType = goal.linkedWorkoutType else { continue }
                let matching = inScopeWorkouts.filter { $0.workoutType == linkedType }

                let hasDistTarget = goal.targetDistanceKm != nil
                let hasDurTarget = goal.targetDurationMinutes != nil

                if hasDistTarget && hasDurTarget {
                    // Speed-target: find workout with highest overallProgress%, copy its values
                    guard let targetDist = goal.targetDistanceKm, targetDist > 0,
                          let targetDur = goal.targetDurationMinutes, targetDur > 0 else { continue }

                    var bestProgress: Double = -1
                    var bestDate: Date = .distantPast
                    var newDist: Double = 0
                    var newDur: Double = 0

                    for w in matching {
                        guard let dist = w.distanceKm, let dur = w.durationMinutes else { continue }
                        let durDouble = Double(dur)
                        let distPct = min((dist / targetDist) * 100, 100)
                        let durPct: Double = durDouble <= targetDur
                            ? 100
                            : min((targetDur / durDouble) * 100, 100)
                        let overallProgress = min(distPct, durPct)
                        if overallProgress > bestProgress ||
                           (overallProgress == bestProgress && w.date > bestDate) {
                            bestProgress = overallProgress
                            bestDate = w.date
                            newDist = dist
                            newDur = durDouble
                        }
                    }
                    goal.currentDistanceKm = newDist
                    goal.currentDurationMinutes = newDur

                } else if hasDistTarget {
                    // Distance-only: max distance across all in-scope matching workouts
                    goal.currentDistanceKm = matching.compactMap(\.distanceKm).max() ?? 0

                } else if hasDurTarget {
                    // Duration-only: max duration across all in-scope matching workouts
                    goal.currentDurationMinutes = matching.compactMap(\.durationMinutes).map(Double.init).max() ?? 0
                }

            default:
                break
            }

            // Check for goal completion notification
            let newProgress = completionPercentage(for: goal)
            if newProgress >= 100 && previousProgress < 100 {
                checkAndFireCompletion(goal: goal)
            }
        }

        try? context.save()

        // Recompute snapshots for affected goals on the workout's date(s)
        if let workout = workout {
            GoalSnapshotService.recomputeSnapshotsForWorkout(
                workout: workout,
                affectedGoals: affectedGoals,
                priorDate: priorDate,
                context: context
            )
        }

        // Always recompute weeklyWorkouts snapshot for today and check for completion
        if let weeklyGoal = goals.first(where: { $0.goalType == "weeklyWorkouts" }) {
            GoalSnapshotService.recomputeSnapshot(goal: weeklyGoal, date: Date(), context: context)
            let progress = weeklyWorkoutsProgress(context: context)
            if progress.isComplete {
                checkAndFireCompletion(goal: weeklyGoal)
                try? context.save()
            }
        }
    }

    // MARK: - Handle Goal Definition Edit

    /// Called after a goal's definition (title, targets, etc.) is edited.
    /// If the goal had a resetDate, clears it and rebuilds all snapshots from full history,
    /// then recalculates the goal's current value from all workouts.
    static func handleGoalDefinitionEdit(goal: Goal, context: ModelContext) {
        if goal.resetDate != nil {
            goal.resetDate = nil
            try? context.save()
            GoalSnapshotService.rebuildSnapshots(goal: goal, context: context)
        }

        // Determine affected names/types for recalculation
        var names: [String] = []
        var types: [String] = []
        if goal.goalType == "Strength PR" || goal.goalType == "Repetitions PR" {
            names = [goal.title]
        } else if goal.goalType == "Speed and Distance", let linkedType = goal.linkedWorkoutType {
            types = [linkedType]
        }
        recalculateGoals(
            affectedExerciseNames: names,
            affectedWorkoutTypes: types,
            context: context
        )
    }

    // MARK: - Goal Completion Date Tracking

    /// Sets lastCelebratedDate when a goal crosses 100%.
    /// Only updates if lastCelebratedDate is nil or the current date is strictly after the existing value.
    /// Ensures `lastCelebratedDate` is set to today for a completed weekly workouts goal.
    /// Called from GoalsViewModel.loadGoals to handle cases where the goal was already
    /// complete before the Goals screen was visited (e.g. completed earlier in the week).
    static func ensureWeeklyGoalCelebration(context: ModelContext) {
        let goals = fetchAll(context: context)
        guard let weeklyGoal = goals.first(where: { $0.goalType == "weeklyWorkouts" }) else { return }
        let progress = weeklyWorkoutsProgress(context: context)
        guard progress.isComplete else { return }
        checkAndFireCompletion(goal: weeklyGoal)
        try? context.save()
    }

    private static func checkAndFireCompletion(goal: Goal) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastCelebrated = goal.lastCelebratedDate {
            let lastCelebratedDay = calendar.startOfDay(for: lastCelebrated)
            guard today > lastCelebratedDay else { return }
        }

        goal.lastCelebratedDate = today
    }
}
