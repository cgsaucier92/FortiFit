import Foundation
import SwiftData
import SwiftUI

@Observable
final class GoalsViewModel {
    // MARK: - Data
    var goals: [Goal] = []
    var showAddGoal = false
    var showDeleteConfirmation = false
    var goalToDelete: Goal?
    var isReorderMode: Bool = false

    // MARK: - Edit Goal State
    var editingGoal: Goal?
    var isEditMode: Bool { editingGoal != nil }

    // Weekly Workouts goal — computed at runtime
    var weeklyWorkoutsCurrent: Int = 0
    var weeklyWorkoutsTarget: Int = 0
    var weeklyWorkoutsPercentage: Double = 0
    var weeklyWorkoutsComplete: Bool = false

    // MARK: - Filter State
    enum GoalFilter: String, CaseIterable {
        case all, active, completed
    }
    var activeFilter: GoalFilter = .all

    var filteredGoals: [Goal] {
        switch activeFilter {
        case .all:
            return goals
        case .active:
            return goals.filter { goalProgress(for: $0) < 100 }
        case .completed:
            return goals.filter { goalProgress(for: $0) >= 100 }
        }
    }

    // MARK: - Expand/Collapse State
    var expandedGoalIds: Set<UUID> = []

    func toggleExpanded(goalId: UUID) {
        if expandedGoalIds.contains(goalId) {
            expandedGoalIds.remove(goalId)
        } else {
            expandedGoalIds.insert(goalId)
        }
    }

    func expandAll() {
        expandedGoalIds = Set(goals.map(\.id))
    }

    func collapseAll() {
        expandedGoalIds.removeAll()
    }

    var expandCollapseLabel: String {
        let expandedCount = expandedGoalIds.count
        let totalCount = goals.count
        return expandedCount > totalCount / 2 ? "Collapse All" : "Expand All"
    }

    var expandCollapseIcon: String {
        let expandedCount = expandedGoalIds.count
        let totalCount = goals.count
        return expandedCount > totalCount / 2 ? "rectangle.compress.vertical" : "rectangle.expand.vertical"
    }

    // MARK: - Sparkline Data
    var snapshotCache: [UUID: [GoalSnapshot]] = [:]

    func loadSnapshots(for goal: Goal, context: ModelContext) {
        if snapshotCache[goal.id] != nil { return }
        snapshotCache[goal.id] = GoalSnapshotService.fetchSnapshots(goalId: goal.id, context: context)
    }

    func invalidateSnapshotCache(for goalId: UUID) {
        snapshotCache.removeValue(forKey: goalId)
    }

    /// A goal is in the skeleton state when it has 0 or 1 snapshots (one snapshot alone cannot form a line).
    func isSparklineEmpty(for goal: Goal) -> Bool {
        let snapshots = snapshotCache[goal.id] ?? []
        return snapshots.count < 2
    }

    // MARK: - Legend Tooltip State (Dual-Arc Ring Tap)
    var tappedRingGoalId: UUID?

    func toggleLegendTooltip(for goalId: UUID) {
        if tappedRingGoalId == goalId {
            tappedRingGoalId = nil
        } else {
            tappedRingGoalId = goalId
        }
    }

    func dismissLegendTooltip() {
        tappedRingGoalId = nil
    }

    // MARK: - Completion Pulse State
    var pulsedGoalIds: Set<UUID> = []

    func identifyGoalsToPulse() -> [UUID] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var toPulse: [UUID] = []
        for goal in goals {
            guard let celebrated = goal.lastCelebratedDate else { continue }
            let isGoalComplete = goal.goalType == "weeklyWorkouts" ? weeklyWorkoutsComplete : GoalService.isComplete(goal)
            if isGoalComplete && calendar.isDate(celebrated, inSameDayAs: today) && !pulsedGoalIds.contains(goal.id) {
                toPulse.append(goal.id)
                pulsedGoalIds.insert(goal.id)
            }
        }
        return toPulse
    }

    func clearPulsedGoalIds() {
        pulsedGoalIds.removeAll()
    }

    // MARK: - Reset Goal Progress
    var goalToReset: Goal?
    var showResetConfirmation = false

    func resetGoalProgress(_ goal: Goal, context: ModelContext) {
        GoalService.resetGoalProgress(goal: goal, context: context)
        invalidateSnapshotCache(for: goal.id)
        loadGoals(context: context)
    }

    // MARK: - Add Goal Form State

    var selectedGoalType = ""

    // Strength PR / Repetitions PR — shared exercise picker
    var selectedExercise = ""
    var customExerciseName = ""

    // Strength PR
    var currentWeightText = ""
    var targetWeightText = ""

    // Repetitions PR
    var currentRepsText = ""
    var targetRepsText = ""

    // Speed and Distance
    var goalNameText = ""
    var selectedLinkedWorkoutType = ""
    var targetDistanceText = ""
    var targetDurationText = ""

    // Autocomplete State
    var exerciseHistory: [String] = []
    var customExerciseSuggestions: [ExerciseSuggestionService.Suggestion] = []

    var isCustomExercise: Bool {
        selectedExercise == "Custom"
    }

    var exerciseTitle: String {
        isCustomExercise ? customExerciseName : selectedExercise
    }

    var canSaveGoal: Bool {
        guard !selectedGoalType.isEmpty else { return false }
        switch selectedGoalType {
        case "Strength PR":
            let title = exerciseTitle.trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty else { return false }
            guard let target = Double(targetWeightText), target > 0 else { return false }
            return true

        case "Repetitions PR":
            let title = exerciseTitle.trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty else { return false }
            guard let target = Int(targetRepsText), target > 0 else { return false }
            return true

        case "Speed and Distance":
            let name = goalNameText.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return false }
            guard !selectedLinkedWorkoutType.isEmpty else { return false }
            let hasDistance = Double(targetDistanceText).map { $0 > 0 } ?? false
            let hasDuration = Double(targetDurationText).map { $0 > 0 } ?? false
            return hasDistance || hasDuration

        case "Number of Weekly Workouts":
            return true

        default:
            return false
        }
    }

    // MARK: - Actions

    func loadGoals(context: ModelContext) {
        goals = GoalService.fetchAll(context: context)
        exerciseHistory = ExerciseSuggestionService.fetchExerciseHistory(context: context)
        snapshotCache.removeAll()
        // Re-populate snapshots for any currently expanded goals
        for goal in goals where expandedGoalIds.contains(goal.id) {
            loadSnapshots(for: goal, context: context)
        }

        // Compute weekly workouts progress if a weeklyWorkouts goal exists
        if goals.contains(where: { $0.goalType == "weeklyWorkouts" }) {
            let progress = GoalService.weeklyWorkoutsProgress(context: context)
            weeklyWorkoutsCurrent = progress.current
            weeklyWorkoutsTarget = progress.target
            weeklyWorkoutsPercentage = progress.percentage
            weeklyWorkoutsComplete = progress.isComplete

            // Ensure lastCelebratedDate is set for completed weekly goals
            // so the pulse animation fires on the Goals screen
            if progress.isComplete {
                GoalService.ensureWeeklyGoalCelebration(context: context)
            }
        }
    }

    func updateCustomExerciseSuggestions(query: String) {
        customExerciseSuggestions = ExerciseSuggestionService.suggest(
            query: query,
            history: exerciseHistory
        )
    }

    func saveGoal(context: ModelContext) {
        let settings = UserSettings.shared

        switch selectedGoalType {
        case "Strength PR":
            let title = exerciseTitle.trimmingCharacters(in: .whitespaces)
            let targetKg: Double
            let currentKg: Double
            if settings.useLbs {
                targetKg = UnitConversion.lbsToKg(Double(targetWeightText) ?? 0) ?? 0
                currentKg = UnitConversion.lbsToKg(Double(currentWeightText) ?? 0) ?? 0
            } else {
                targetKg = Double(targetWeightText) ?? 0
                currentKg = Double(currentWeightText) ?? 0
            }
            GoalService.createExercisePRGoal(
                title: title,
                targetValueKg: targetKg,
                currentValueKg: currentKg,
                context: context
            )

        case "Repetitions PR":
            let title = exerciseTitle.trimmingCharacters(in: .whitespaces)
            GoalService.createRepsPRGoal(
                title: title,
                targetReps: Int(targetRepsText) ?? 0,
                currentReps: Int(currentRepsText) ?? 0,
                context: context
            )

        case "Speed and Distance":
            let name = goalNameText.trimmingCharacters(in: .whitespaces)
            let enteredDist = Double(targetDistanceText).flatMap { $0 > 0 ? $0 : nil }
            let targetDist: Double? = enteredDist.map { dist in
                settings.useMiles ? UnitConversion.milesToKm(dist) : dist
            }
            let targetDur = Double(targetDurationText).flatMap { $0 > 0 ? $0 : nil }
            GoalService.createSpeedDistanceGoal(
                title: name,
                targetDistanceKm: targetDist,
                targetDurationMinutes: targetDur,
                linkedWorkoutType: selectedLinkedWorkoutType.isEmpty ? nil : selectedLinkedWorkoutType,
                context: context
            )

        case "Number of Weekly Workouts":
            GoalService.createWeeklyWorkoutsGoal(context: context)

        default:
            break
        }

        loadGoals(context: context)
        resetForm()
    }

    func deleteGoal(_ goal: Goal, context: ModelContext) {
        let goalId = goal.id
        GoalService.deleteGoal(goal, context: context)
        snapshotCache.removeValue(forKey: goalId)
        expandedGoalIds.remove(goalId)
        loadGoals(context: context)
    }

    func reorderGoals(from source: IndexSet, to destination: Int, context: ModelContext) {
        goals.move(fromOffsets: source, toOffset: destination)
        GoalService.reorder(goals: goals, context: context)
    }

    func resetForm() {
        editingGoal = nil
        selectedGoalType = ""
        selectedExercise = ""
        customExerciseName = ""
        currentWeightText = ""
        targetWeightText = ""
        currentRepsText = ""
        targetRepsText = ""
        goalNameText = ""
        selectedLinkedWorkoutType = ""
        targetDistanceText = ""
        targetDurationText = ""
    }

    // MARK: - Edit Goal

    func populateFormFromGoal(_ goal: Goal) {
        editingGoal = goal
        let settings = UserSettings.shared

        switch goal.goalType {
        case "Strength PR":
            selectedGoalType = "Strength PR"
            // Check if title matches a known exercise
            if AppConstants.exerciseOptions.contains(goal.title) {
                selectedExercise = goal.title
                customExerciseName = ""
            } else {
                selectedExercise = "Custom"
                customExerciseName = goal.title
            }
            if settings.useLbs {
                currentWeightText = String(format: "%g", UnitConversion.kgToLbs(goal.currentValueKg) ?? 0)
                targetWeightText = String(format: "%g", UnitConversion.kgToLbs(goal.targetValueKg) ?? 0)
            } else {
                currentWeightText = String(format: "%g", goal.currentValueKg)
                targetWeightText = String(format: "%g", goal.targetValueKg)
            }

        case "Repetitions PR":
            selectedGoalType = "Repetitions PR"
            if AppConstants.exerciseOptions.contains(goal.title) {
                selectedExercise = goal.title
                customExerciseName = ""
            } else {
                selectedExercise = "Custom"
                customExerciseName = goal.title
            }
            currentRepsText = String(goal.currentReps)
            targetRepsText = String(goal.targetReps)

        case "Speed and Distance":
            selectedGoalType = "Speed and Distance"
            goalNameText = goal.title
            selectedLinkedWorkoutType = goal.linkedWorkoutType ?? ""
            if let dist = goal.targetDistanceKm {
                if settings.useMiles {
                    targetDistanceText = String(format: "%g", dist * UnitConversion.kmToMilesFactor)
                } else {
                    targetDistanceText = String(format: "%g", dist)
                }
            }
            if let dur = goal.targetDurationMinutes {
                targetDurationText = String(format: "%g", dur)
            }

        default:
            break
        }
    }

    func saveEditedGoal(context: ModelContext) {
        guard let goal = editingGoal else { return }
        let settings = UserSettings.shared

        switch goal.goalType {
        case "Strength PR":
            goal.title = exerciseTitle.trimmingCharacters(in: .whitespaces)
            if settings.useLbs {
                goal.targetValueKg = UnitConversion.lbsToKg(Double(targetWeightText) ?? 0) ?? 0
            } else {
                goal.targetValueKg = Double(targetWeightText) ?? 0
            }

        case "Repetitions PR":
            goal.title = exerciseTitle.trimmingCharacters(in: .whitespaces)
            goal.targetReps = Int(targetRepsText) ?? 0

        case "Speed and Distance":
            goal.title = goalNameText.trimmingCharacters(in: .whitespaces)
            goal.linkedWorkoutType = selectedLinkedWorkoutType.isEmpty ? nil : selectedLinkedWorkoutType
            let enteredDist = Double(targetDistanceText).flatMap { $0 > 0 ? $0 : nil }
            goal.targetDistanceKm = enteredDist.map { dist in
                settings.useMiles ? UnitConversion.milesToKm(dist) : dist
            }
            goal.targetDurationMinutes = Double(targetDurationText).flatMap { $0 > 0 ? $0 : nil }

        default:
            break
        }

        try? context.save()
        GoalService.handleGoalDefinitionEdit(goal: goal, context: context)
        invalidateSnapshotCache(for: goal.id)
        loadGoals(context: context)
        resetForm()
    }

    // MARK: - Goal Display Helpers

    func completionPercentage(for goal: Goal) -> Double {
        GoalService.completionPercentage(for: goal)
    }

    func isComplete(_ goal: Goal) -> Bool {
        GoalService.isComplete(goal)
    }

    func goalColor(for goal: Goal) -> Color {
        FortiFitColors.goalColors[goal.colorIndex % FortiFitColors.goalColors.count]
    }

    /// Returns the progress percentage accounting for weeklyWorkouts runtime computation.
    func goalProgress(for goal: Goal) -> Double {
        if goal.goalType == "weeklyWorkouts" {
            return weeklyWorkoutsPercentage
        }
        return completionPercentage(for: goal)
    }

    /// Returns distance progress (0–1) for Speed and Distance goals.
    func distanceProgress(for goal: Goal) -> Double {
        guard let target = goal.targetDistanceKm, target > 0 else { return 0 }
        return min(goal.currentDistanceKm / target, 1.0)
    }

    /// Returns duration progress (0–1) for Speed and Distance goals.
    /// For dual-target (speed target): uses "at or below target" semantics.
    func durationProgress(for goal: Goal) -> Double {
        guard let target = goal.targetDurationMinutes, target > 0 else { return 0 }
        // Dual-target (speed target): "at or below target" semantics
        if goal.targetDistanceKm != nil {
            // No duration logged yet means no progress
            if goal.currentDurationMinutes == 0 { return 0 }
            if goal.currentDurationMinutes <= target {
                return 1.0
            } else {
                return min(target / goal.currentDurationMinutes, 1.0)
            }
        }
        // Duration-only (endurance): higher is better
        return min(goal.currentDurationMinutes / target, 1.0)
    }
}
