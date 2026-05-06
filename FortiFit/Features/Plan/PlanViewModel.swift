import Foundation
import SwiftData

enum CalendarMode: String {
    case week = "Week"
    case month = "Month"
}

@Observable
final class PlanViewModel {
    // MARK: - Calendar State
    var selectedDate: Date = Date()
    var dayOffset: Int = 0
    var displayedMonth: Date = Date()
    var calendarMode: CalendarMode = .week

    // MARK: - Data
    /// Plan surface items for the visible calendar range (dots).
    var planItemsForView: [PlanCardItem] = []
    /// Plan surface items for the selected day (cards).
    var selectedDayItems: [PlanCardItem] = []

    // MARK: - Sheet State
    var showScheduleSheet = false
    var showCompletionSheet = false
    var showDateResolutionPrompt = false
    var activeScheduledWorkout: ScheduledWorkout?
    var dateResolution: DateResolution?
    var resolvedDate: Date = Date()

    // MARK: - Pre-selected template (from "Schedule This Template")
    var preSelectedTemplate: WorkoutTemplate?

    // MARK: - Remove from Plan confirmation
    var showRemoveConfirmation = false
    var itemToRemove: PlanCardItem?
    var showRecurringRemovePrompt = false
    var pendingRemoveScope: RecurrenceScope = .thisOnly

    // MARK: - Completion form state
    var completionRPE: Int?
    var completionDuration: String = ""

    // MARK: - Toast
    var showCompletedToast = false
    var showRemovedFromPlanToast = false
    /// Snapshot for undo of planned/skipped removal (nil for flag-flip variants)
    var removedPlanSnapshot: RemovedPlanSnapshot?
    /// Workout to undo hiddenFromPlan (for logged-only and completed-scheduled variants)
    var removedWorkoutForUndo: Workout?

    // MARK: - Empty State
    var showEmptyState = false

    // MARK: - Navigation for Workout Detail
    var selectedWorkoutForDetail: Workout?
    var showWorkoutDetail = false

    // MARK: - Data Loading

    func loadWorkoutsForCurrentView(context: ModelContext) {
        let calendar = Calendar(identifier: .iso8601)

        switch calendarMode {
        case .week:
            guard let weekStart = calendar.date(byAdding: .day, value: dayOffset, to: Date().startOfWeek),
                  let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)
            else { return }
            planItemsForView = PlanService.fetchPlanSurface(start: weekStart, end: weekEnd, context: context)

        case .month:
            guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)),
                  let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)
            else { return }
            planItemsForView = PlanService.fetchPlanSurface(start: monthStart, end: monthEnd, context: context)
        }

        updateSelectedDayItems(context: context)
        regenerateRecurrenceIfNeeded(context: context)
        checkEmptyState(context: context)
    }

    func updateSelectedDayItems(context: ModelContext) {
        selectedDayItems = PlanService.fetchPlanSurface(for: selectedDate, context: context)
    }

    func checkEmptyState(context: ModelContext) {
        let scheduledDescriptor = FetchDescriptor<ScheduledWorkout>()
        let scheduledCount = (try? context.fetchCount(scheduledDescriptor)) ?? 0

        let workoutPredicate = #Predicate<Workout> { w in w.hiddenFromPlan == false }
        let workoutDescriptor = FetchDescriptor<Workout>(predicate: workoutPredicate)
        let visibleWorkoutCount = (try? context.fetchCount(workoutDescriptor)) ?? 0

        showEmptyState = scheduledCount == 0 && visibleWorkoutCount == 0
    }

    private func regenerateRecurrenceIfNeeded(context: ModelContext) {
        var groupIds = Set<UUID>()
        for item in planItemsForView {
            if case .scheduled(let sw) = item, let gid = sw.recurrenceGroupId {
                groupIds.insert(gid)
            }
        }
        for groupId in groupIds {
            PlanService.regenerateRecurrenceIfNeeded(groupId: groupId, context: context)
        }
    }

    // MARK: - Day Selection

    func resetToToday() {
        selectedDate = Date()
        dayOffset = 0
        displayedMonth = Date()
    }

    func selectDay(_ date: Date) {
        selectedDate = date
    }

    // MARK: - Completion Flow

    func initiateCompletion(scheduledWorkout: ScheduledWorkout) {
        activeScheduledWorkout = scheduledWorkout
        completionRPE = nil
        completionDuration = scheduledWorkout.durationMinutes.map { String($0) } ?? ""

        let resolution = PlanService.resolveDateForCompletion(scheduledWorkout: scheduledWorkout)
        dateResolution = resolution

        switch resolution {
        case .today:
            resolvedDate = Date()
            showCompletionSheet = true
        case .pastDate, .futureDate:
            showDateResolutionPrompt = true
        }
    }

    func resolveWithScheduledDate() {
        if case .pastDate(let scheduled) = dateResolution {
            resolvedDate = scheduled
        }
        showDateResolutionPrompt = false
        showCompletionSheet = true
    }

    func resolveWithToday() {
        resolvedDate = Date()
        showDateResolutionPrompt = false
        showCompletionSheet = true
    }

    func cancelDateResolution() {
        showDateResolutionPrompt = false
        activeScheduledWorkout = nil
        dateResolution = nil
    }

    func completeWorkout(context: ModelContext) {
        guard let scheduled = activeScheduledWorkout else { return }

        let rpe = completionRPE
        let duration: Int? = {
            let value = Int(completionDuration)
            return value != nil && value! > 0 ? value : nil
        }()

        PlanService.completeWorkout(
            scheduledWorkout: scheduled,
            date: resolvedDate,
            rpe: rpe,
            durationMinutes: duration,
            context: context
        )

        showCompletionSheet = false
        activeScheduledWorkout = nil
        dateResolution = nil

        showCompletedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.showCompletedToast = false
        }

        loadWorkoutsForCurrentView(context: context)
    }

    // MARK: - Skip / Restore

    func skipWorkout(_ scheduledWorkout: ScheduledWorkout, context: ModelContext) {
        PlanService.skipWorkout(scheduledWorkout: scheduledWorkout, context: context)
        loadWorkoutsForCurrentView(context: context)
    }

    func restoreWorkout(_ scheduledWorkout: ScheduledWorkout, context: ModelContext) {
        PlanService.restoreWorkout(scheduledWorkout: scheduledWorkout, context: context)
        loadWorkoutsForCurrentView(context: context)
    }

    // MARK: - Remove from Plan

    /// Initiates the Remove from Plan flow for any card type.
    func confirmRemoveFromPlan(_ item: PlanCardItem) {
        itemToRemove = item
        pendingRemoveScope = .thisOnly

        // Check if recurring and needs scope prompt first
        if case .scheduled(let sw) = item, sw.recurrenceGroupId != nil {
            showRecurringRemovePrompt = true
        } else {
            showRemoveConfirmation = true
        }
    }

    /// Called after recurrence scope selection — shows the confirmation alert.
    func proceedWithRemoveAfterScopeSelection(scope: RecurrenceScope) {
        pendingRemoveScope = scope
        showRecurringRemovePrompt = false
        showRemoveConfirmation = true
    }

    /// Executes the actual removal.
    func executeRemoveFromPlan(context: ModelContext) {
        guard let item = itemToRemove else { return }

        // For completed/logged-only, store the workout reference for undo
        switch item {
        case .loggedOnly(let workout):
            removedWorkoutForUndo = workout
            removedPlanSnapshot = nil
        case .scheduled(let sw) where sw.status == "completed":
            if let completedId = sw.completedWorkoutId {
                let predicate = #Predicate<Workout> { w in w.id == completedId }
                let descriptor = FetchDescriptor<Workout>(predicate: predicate)
                removedWorkoutForUndo = (try? context.fetch(descriptor))?.first
            }
            removedPlanSnapshot = nil
        default:
            removedWorkoutForUndo = nil
        }

        let snapshot = PlanService.removeFromPlan(
            item: item,
            scope: pendingRemoveScope,
            context: context
        )
        removedPlanSnapshot = snapshot

        itemToRemove = nil
        showRemoveConfirmation = false

        // Show undo toast
        showRemovedFromPlanToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.dismissRemoveToast()
        }

        loadWorkoutsForCurrentView(context: context)
    }

    /// Undo the most recent Remove from Plan action.
    func undoRemoveFromPlan(context: ModelContext) {
        if let snapshot = removedPlanSnapshot {
            // Planned/skipped: restore from snapshot
            PlanService.restoreRemovedPlan(snapshot: snapshot, context: context)
        } else if let workout = removedWorkoutForUndo {
            // Logged-only / completed-scheduled: flip flag back
            PlanService.setHiddenFromPlan(workout: workout, hidden: false, context: context)
        }

        dismissRemoveToast()
        loadWorkoutsForCurrentView(context: context)
    }

    func dismissRemoveToast() {
        showRemovedFromPlanToast = false
        removedPlanSnapshot = nil
        removedWorkoutForUndo = nil
    }

    // MARK: - Schedule Sheet

    func openScheduleSheet(forDate date: Date? = nil) {
        if let date {
            selectedDate = date
        }
        showScheduleSheet = true
    }

    func scheduleWorkout(
        template: WorkoutTemplate,
        date: Date,
        time: Date?,
        recurrenceRule: String?,
        context: ModelContext
    ) {
        PlanService.scheduleWorkout(
            template: template,
            date: date,
            time: time,
            recurrenceRule: recurrenceRule,
            context: context
        )
        showScheduleSheet = false
        preSelectedTemplate = nil
        loadWorkoutsForCurrentView(context: context)
    }

    // MARK: - Helpers

    /// Returns the name for a PlanCardItem (used in confirmation alerts).
    func nameForItem(_ item: PlanCardItem) -> String {
        switch item {
        case .scheduled(let sw): return sw.workoutName
        case .loggedOnly(let w): return w.name
        }
    }

    /// Whether the item's "Remove from Plan" confirmation should use destructive (red) styling.
    func isDestructiveRemoval(_ item: PlanCardItem) -> Bool {
        switch item {
        case .scheduled(let sw):
            return sw.status == "planned" || sw.status == "skipped"
        case .loggedOnly:
            return false
        }
    }

    /// Confirmation message body for Remove from Plan.
    func removeConfirmationMessage(_ item: PlanCardItem) -> String {
        switch item {
        case .scheduled(let sw) where sw.status == "completed":
            return "The workout will remain in your log"
        case .loggedOnly:
            return "The workout will remain in your log"
        default:
            return "This can't be undone"
        }
    }
}
