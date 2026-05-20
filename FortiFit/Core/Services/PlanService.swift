import Foundation
import SwiftData

// MARK: - Snapshot Exercise

struct SnapshotExercise: Codable {
    let exerciseName: String
    let sets: Int
    let reps: Int
    let weightKg: Double?
    let sortOrder: Int
    let restSeconds: Int?
    let displayAsTime: Bool?

    init(exerciseName: String, sets: Int, reps: Int, weightKg: Double?, sortOrder: Int, restSeconds: Int? = nil, displayAsTime: Bool? = nil) {
        self.exerciseName = exerciseName
        self.sets = sets
        self.reps = reps
        self.weightKg = weightKg
        self.sortOrder = sortOrder
        self.restSeconds = restSeconds
        self.displayAsTime = displayAsTime
    }
}

// MARK: - Date Resolution

enum DateResolution {
    case today
    case pastDate(scheduled: Date)
    case futureDate(scheduled: Date)
}

// MARK: - PlanCardItem

/// A union type representing either a scheduled workout or a logged-only workout
/// on the Plan screen. Callers pattern-match to render the appropriate card.
enum PlanCardItem: Identifiable {
    case scheduled(ScheduledWorkout)
    case loggedOnly(Workout)

    var id: UUID {
        switch self {
        case .scheduled(let sw): return sw.id
        case .loggedOnly(let w): return w.id
        }
    }

    var date: Date {
        switch self {
        case .scheduled(let sw): return sw.scheduledDate
        case .loggedOnly(let w): return w.date
        }
    }

    /// Sort priority within a single day: planned/skipped (0) precede completed/logged (1)
    /// so finished work sinks to the bottom of the stack and upcoming work stays on top.
    var dayOrderPriority: Int {
        switch self {
        case .scheduled(let sw): return sw.status == "completed" ? 1 : 0
        case .loggedOnly: return 1
        }
    }
}

// MARK: - Recurrence Scope

enum RecurrenceScope {
    case thisOnly
    case thisAndFuture
}

// MARK: - Remove from Plan Snapshot

/// Holds pre-delete data for planned/skipped ScheduledWorkout removal, enabling undo
/// within the toast lifetime.
struct RemovedPlanSnapshot {
    let templateId: UUID?
    let scheduledWorkoutSnapshot: Data?
    let scheduledDate: Date
    let scheduledTime: Date?
    let workoutType: String
    let workoutName: String
    let durationMinutes: Int?
    let status: String
    let completedWorkoutId: UUID?
    let recurrenceRule: String?
    let recurrenceGroupId: UUID?
    let dateCreated: Date
}

// MARK: - PlanService

struct PlanService {

    // MARK: - Snapshot Encoding/Decoding

    static func encodeSnapshot(template: WorkoutTemplate) -> Data? {
        let exercises = template.exerciseSets
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { set in
                SnapshotExercise(
                    exerciseName: set.exerciseName,
                    sets: set.sets,
                    reps: set.reps,
                    weightKg: set.weightKg,
                    sortOrder: set.sortOrder,
                    restSeconds: set.restSeconds,
                    displayAsTime: set.displayAsTime
                )
            }
        return try? JSONEncoder().encode(exercises)
    }

    static func decodeSnapshot(data: Data) -> [SnapshotExercise] {
        (try? JSONDecoder().decode([SnapshotExercise].self, from: data)) ?? []
    }

    // MARK: - Scheduling

    @discardableResult
    static func scheduleWorkout(
        template: WorkoutTemplate,
        date: Date,
        time: Date?,
        recurrenceRule: String?,
        syncToAppleWatch: Bool = false,
        context: ModelContext
    ) -> [ScheduledWorkout] {
        let today = Calendar.current.startOfDay(for: Date())
        let targetDate = Calendar.current.startOfDay(for: date)
        guard targetDate >= today else { return [] }

        let snapshot = encodeSnapshot(template: template)

        if let rule = recurrenceRule {
            return generateRecurrence(
                template: template,
                snapshot: snapshot,
                startDate: targetDate,
                time: time,
                rule: rule,
                syncToAppleWatch: syncToAppleWatch,
                context: context
            )
        } else {
            let scheduled = ScheduledWorkout(
                templateId: template.id,
                scheduledWorkoutSnapshot: snapshot,
                scheduledDate: targetDate,
                scheduledTime: time,
                workoutType: template.workoutType,
                workoutName: template.name,
                durationMinutes: template.durationMinutes,
                syncToAppleWatch: syncToAppleWatch
            )
            context.insert(scheduled)
            try? context.save()
            return [scheduled]
        }
    }

    @discardableResult
    static func generateRecurrence(
        template: WorkoutTemplate,
        snapshot: Data?,
        startDate: Date,
        time: Date?,
        rule: String,
        syncToAppleWatch: Bool = false,
        context: ModelContext
    ) -> [ScheduledWorkout] {
        let groupId = UUID()
        let interval = rule == "biweekly" ? 14 : 7
        let totalWeeks = AppConstants.recurrenceLookaheadWeeks
        let instanceCount = (totalWeeks * 7) / interval

        var created: [ScheduledWorkout] = []
        for i in 0..<instanceCount {
            guard let date = Calendar.current.date(byAdding: .day, value: i * interval, to: startDate) else { continue }
            let scheduled = ScheduledWorkout(
                templateId: template.id,
                scheduledWorkoutSnapshot: snapshot,
                scheduledDate: date,
                scheduledTime: time,
                workoutType: template.workoutType,
                workoutName: template.name,
                durationMinutes: template.durationMinutes,
                recurrenceRule: rule,
                recurrenceGroupId: groupId,
                syncToAppleWatch: syncToAppleWatch
            )
            context.insert(scheduled)
            created.append(scheduled)
        }
        try? context.save()
        return created
    }

    static func regenerateRecurrenceIfNeeded(groupId: UUID, context: ModelContext) {
        let today = Calendar.current.startOfDay(for: Date())

        let predicate = #Predicate<ScheduledWorkout> { sw in
            sw.recurrenceGroupId == groupId
        }
        let descriptor = FetchDescriptor<ScheduledWorkout>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.scheduledDate, order: .reverse)]
        )
        guard let allInstances = try? context.fetch(descriptor), !allInstances.isEmpty else { return }

        let futureInstances = allInstances.filter { $0.scheduledDate >= today }
        guard futureInstances.count < AppConstants.recurrenceRegenerationThreshold else { return }

        guard let latestInstance = allInstances.first else { return }
        let rule = latestInstance.recurrenceRule ?? "weekly"
        let interval = rule == "biweekly" ? 14 : 7

        let targetWeeks = AppConstants.recurrenceLookaheadWeeks
        let targetCount = (targetWeeks * 7) / interval
        let needed = targetCount - futureInstances.count

        guard needed > 0, let lastDate = allInstances.first?.scheduledDate else { return }

        for i in 1...needed {
            guard let date = Calendar.current.date(byAdding: .day, value: i * interval, to: lastDate) else { continue }
            let scheduled = ScheduledWorkout(
                templateId: latestInstance.templateId,
                scheduledWorkoutSnapshot: latestInstance.scheduledWorkoutSnapshot,
                scheduledDate: date,
                scheduledTime: latestInstance.scheduledTime,
                workoutType: latestInstance.workoutType,
                workoutName: latestInstance.workoutName,
                durationMinutes: latestInstance.durationMinutes,
                recurrenceRule: rule,
                recurrenceGroupId: groupId,
                syncToAppleWatch: latestInstance.syncToAppleWatch
            )
            context.insert(scheduled)
        }
        try? context.save()
    }

    // MARK: - Retrieval

    static func fetchForDateRange(start: Date, end: Date, context: ModelContext) -> [ScheduledWorkout] {
        let startDay = Calendar.current.startOfDay(for: start)
        let endDay = Calendar.current.startOfDay(for: end)

        let predicate = #Predicate<ScheduledWorkout> { sw in
            sw.scheduledDate >= startDay && sw.scheduledDate <= endDay
        }
        let descriptor = FetchDescriptor<ScheduledWorkout>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\.scheduledDate, order: .forward),
                SortDescriptor(\.scheduledTime, order: .forward)
            ]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func fetchForDate(date: Date, context: ModelContext) -> [ScheduledWorkout] {
        let targetDay = Calendar.current.startOfDay(for: date)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: targetDay)!

        let predicate = #Predicate<ScheduledWorkout> { sw in
            sw.scheduledDate >= targetDay && sw.scheduledDate < nextDay
        }
        let descriptor = FetchDescriptor<ScheduledWorkout>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.scheduledTime, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Returns all ScheduledWorkouts for today, sorted by status (planned/skipped first,
    /// completed last — mirrors the Plan tab's day-detail stack order), then within each
    /// group by scheduledTime ascending and dateCreated.
    static func fetchTodaysScheduledWorkouts(context: ModelContext) -> [ScheduledWorkout] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        let predicate = #Predicate<ScheduledWorkout> { sw in
            sw.scheduledDate >= today && sw.scheduledDate < tomorrow
        }
        let descriptor = FetchDescriptor<ScheduledWorkout>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\.scheduledTime, order: .forward),
                SortDescriptor(\.dateCreated, order: .forward)
            ]
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        // Stable partition: completed rows sink to the bottom; relative scheduledTime/
        // dateCreated order within each group is preserved by Swift's stable sort.
        return rows.sorted { lhs, rhs in
            let lhsCompleted = lhs.status == "completed"
            let rhsCompleted = rhs.status == "completed"
            if lhsCompleted == rhsCompleted { return false }
            return !lhsCompleted
        }
    }

    static func fetchTodaysPlanned(context: ModelContext) -> ScheduledWorkout? {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let plannedStatus = "planned"

        let predicate = #Predicate<ScheduledWorkout> { sw in
            sw.scheduledDate >= today && sw.scheduledDate < tomorrow && sw.status == plannedStatus
        }
        let descriptor = FetchDescriptor<ScheduledWorkout>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.scheduledTime, order: .forward)]
        )
        return (try? context.fetch(descriptor))?.first
    }

    // MARK: - Plan Surface (Unified Retrieval)

    /// Fetches the unified Plan surface for a date range, merging ScheduledWorkouts
    /// and logged-only Workouts. Returns date-sorted PlanCardItems.
    static func fetchPlanSurface(start: Date, end: Date, context: ModelContext) -> [PlanCardItem] {
        let startDay = Calendar.current.startOfDay(for: start)
        let endDay = Calendar.current.startOfDay(for: end)
        let nextDayAfterEnd = Calendar.current.date(byAdding: .day, value: 1, to: endDay)!

        // 1. All ScheduledWorkouts in range
        let swPredicate = #Predicate<ScheduledWorkout> { sw in
            sw.scheduledDate >= startDay && sw.scheduledDate <= endDay
        }
        let swDescriptor = FetchDescriptor<ScheduledWorkout>(
            predicate: swPredicate,
            sortBy: [
                SortDescriptor(\.scheduledDate, order: .forward),
                SortDescriptor(\.scheduledTime, order: .forward)
            ]
        )
        let scheduledWorkouts = (try? context.fetch(swDescriptor)) ?? []

        // Collect completedWorkoutIds for dedup
        let completedIds = Set(scheduledWorkouts.compactMap { $0.completedWorkoutId })

        // 2. All Workouts in range that are NOT linked and NOT hidden
        let hiddenFalse = false
        let wPredicate = #Predicate<Workout> { w in
            w.date >= startDay && w.date < nextDayAfterEnd && w.hiddenFromPlan == hiddenFalse
        }
        let wDescriptor = FetchDescriptor<Workout>(
            predicate: wPredicate,
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let allWorkouts = (try? context.fetch(wDescriptor)) ?? []
        let loggedOnly = allWorkouts.filter { !completedIds.contains($0.id) }

        // 3. Merge and sort by date, then by status priority so completed/logged
        // items always render after planned/skipped within the same day.
        var items: [PlanCardItem] = scheduledWorkouts.map { .scheduled($0) }
        items.append(contentsOf: loggedOnly.map { .loggedOnly($0) })
        items.sort { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.dayOrderPriority < rhs.dayOrderPriority
        }

        return items
    }

    /// Fetches the unified Plan surface for a single date.
    static func fetchPlanSurface(for date: Date, context: ModelContext) -> [PlanCardItem] {
        let startDay = Calendar.current.startOfDay(for: date)
        let endDay = startDay // same day
        return fetchPlanSurface(start: startDay, end: endDay, context: context)
    }

    // MARK: - Remove from Plan

    /// Sets the hiddenFromPlan flag on a Workout. Used by removeFromPlan and
    /// the Workout Detail "Show on Plan" action.
    static func setHiddenFromPlan(workout: Workout, hidden: Bool, context: ModelContext) {
        workout.hiddenFromPlan = hidden
        try? context.save()
    }

    /// Unified "Remove from Plan" action. Returns a snapshot for planned/skipped
    /// removals (enabling undo), or nil for flag-flip variants.
    @discardableResult
    static func removeFromPlan(
        item: PlanCardItem,
        scope: RecurrenceScope = .thisOnly,
        context: ModelContext
    ) -> RemovedPlanSnapshot? {
        switch item {
        case .loggedOnly(let workout):
            // Just flip the flag
            setHiddenFromPlan(workout: workout, hidden: true, context: context)
            return nil

        case .scheduled(let sw):
            if sw.status == "completed" {
                // Dual-action: delete ScheduledWorkout AND hide linked Workout
                if scope == .thisAndFuture, let groupId = sw.recurrenceGroupId {
                    // Delete future planned instances in the group
                    deleteFuturePlannedInGroup(
                        groupId: groupId,
                        fromDate: sw.scheduledDate,
                        excludingId: sw.id,
                        context: context
                    )
                }

                // Hide the linked workout
                if let completedId = sw.completedWorkoutId {
                    let predicate = #Predicate<Workout> { w in w.id == completedId }
                    let descriptor = FetchDescriptor<Workout>(predicate: predicate)
                    if let workout = (try? context.fetch(descriptor))?.first {
                        workout.hiddenFromPlan = true
                    }
                }

                // Delete the ScheduledWorkout
                context.delete(sw)
                try? context.save()
                return nil

            } else {
                // Planned or skipped — capture snapshot for undo
                let snapshot = RemovedPlanSnapshot(
                    templateId: sw.templateId,
                    scheduledWorkoutSnapshot: sw.scheduledWorkoutSnapshot,
                    scheduledDate: sw.scheduledDate,
                    scheduledTime: sw.scheduledTime,
                    workoutType: sw.workoutType,
                    workoutName: sw.workoutName,
                    durationMinutes: sw.durationMinutes,
                    status: sw.status,
                    completedWorkoutId: sw.completedWorkoutId,
                    recurrenceRule: sw.recurrenceRule,
                    recurrenceGroupId: sw.recurrenceGroupId,
                    dateCreated: sw.dateCreated
                )

                if scope == .thisAndFuture, let groupId = sw.recurrenceGroupId {
                    // Delete this and future planned/skipped in group
                    let cutoffDate = sw.scheduledDate
                    let predicate = #Predicate<ScheduledWorkout> { item in
                        item.recurrenceGroupId == groupId && item.scheduledDate >= cutoffDate
                    }
                    let descriptor = FetchDescriptor<ScheduledWorkout>(predicate: predicate)
                    if let toDelete = try? context.fetch(descriptor) {
                        for instance in toDelete {
                            // Skip past completed/skipped? No — for planned/skipped we delete all future
                            context.delete(instance)
                        }
                    }
                } else {
                    context.delete(sw)
                }

                try? context.save()
                return snapshot
            }
        }
    }

    /// Restores a previously removed planned/skipped ScheduledWorkout from a snapshot.
    static func restoreRemovedPlan(snapshot: RemovedPlanSnapshot, context: ModelContext) {
        let restored = ScheduledWorkout(
            templateId: snapshot.templateId,
            scheduledWorkoutSnapshot: snapshot.scheduledWorkoutSnapshot,
            scheduledDate: snapshot.scheduledDate,
            scheduledTime: snapshot.scheduledTime,
            workoutType: snapshot.workoutType,
            workoutName: snapshot.workoutName,
            durationMinutes: snapshot.durationMinutes,
            status: snapshot.status,
            completedWorkoutId: snapshot.completedWorkoutId,
            recurrenceRule: snapshot.recurrenceRule,
            recurrenceGroupId: snapshot.recurrenceGroupId
        )
        context.insert(restored)
        try? context.save()
    }

    /// Deletes future planned instances in a recurrence group from a given date,
    /// excluding a specific ID (the instance being dual-actioned).
    private static func deleteFuturePlannedInGroup(
        groupId: UUID,
        fromDate: Date,
        excludingId: UUID,
        context: ModelContext
    ) {
        let plannedStatus = "planned"
        let predicate = #Predicate<ScheduledWorkout> { sw in
            sw.recurrenceGroupId == groupId &&
            sw.scheduledDate >= fromDate &&
            sw.id != excludingId &&
            sw.status == plannedStatus
        }
        let descriptor = FetchDescriptor<ScheduledWorkout>(predicate: predicate)
        if let toDelete = try? context.fetch(descriptor) {
            for instance in toDelete {
                context.delete(instance)
            }
        }
    }

    // MARK: - Date Resolution

    static func resolveDateForCompletion(scheduledWorkout: ScheduledWorkout) -> DateResolution {
        let today = Calendar.current.startOfDay(for: Date())
        let scheduled = Calendar.current.startOfDay(for: scheduledWorkout.scheduledDate)

        if scheduled == today {
            return .today
        } else if scheduled < today {
            return .pastDate(scheduled: scheduled)
        } else {
            return .futureDate(scheduled: scheduled)
        }
    }

    // MARK: - Completion

    static func completeWorkout(
        scheduledWorkout: ScheduledWorkout,
        date: Date,
        rpe: Int?,
        durationMinutes: Int?,
        context: ModelContext
    ) {
        let exercises: [SnapshotExercise]
        if let snapshotData = scheduledWorkout.scheduledWorkoutSnapshot {
            exercises = decodeSnapshot(data: snapshotData)
        } else {
            exercises = []
        }

        let workout = Workout(
            name: scheduledWorkout.workoutName,
            date: date,
            workoutType: scheduledWorkout.workoutType,
            rpe: rpe,
            durationMinutes: durationMinutes,
            time: Date()
        )

        // Create ExerciseSets if Strength Training or HIIT
        if scheduledWorkout.workoutType == "Strength Training" || scheduledWorkout.workoutType == "HIIT" {
            for exercise in exercises {
                let set = ExerciseSet(
                    exerciseName: exercise.exerciseName,
                    sets: exercise.sets,
                    reps: exercise.reps,
                    weightKg: exercise.weightKg,
                    sortOrder: exercise.sortOrder,
                    restSeconds: exercise.restSeconds,
                    displayAsTime: exercise.displayAsTime
                )
                workout.exerciseSets.append(set)
            }
        }

        // Log workout and trigger cascades (same as normal Log Workout)
        WorkoutService.logWorkout(workout, context: context)
        WorkoutTypeOrderService.ensureOrderExists(for: workout.workoutType, context: context)
        let exerciseNames = workout.exerciseSets.map { $0.exerciseName }
        GoalService.recalculateGoals(
            affectedExerciseNames: exerciseNames,
            affectedWorkoutTypes: [workout.workoutType],
            workout: workout,
            context: context
        )

        // Mark scheduled slot as completed and align its date with the logged workout
        scheduledWorkout.status = "completed"
        scheduledWorkout.completedWorkoutId = workout.id
        scheduledWorkout.scheduledDate = Calendar.current.startOfDay(for: date)
        try? context.save()
    }

    static func markCompletedFromLogWorkout(
        scheduledWorkoutId: UUID,
        workoutId: UUID,
        context: ModelContext
    ) {
        let predicate = #Predicate<ScheduledWorkout> { sw in
            sw.id == scheduledWorkoutId
        }
        let descriptor = FetchDescriptor<ScheduledWorkout>(predicate: predicate)
        guard let scheduled = (try? context.fetch(descriptor))?.first else { return }

        scheduled.status = "completed"
        scheduled.completedWorkoutId = workoutId
        try? context.save()
    }

    // MARK: - Skip / Restore / Delete

    static func skipWorkout(scheduledWorkout: ScheduledWorkout, context: ModelContext) {
        scheduledWorkout.status = "skipped"
        try? context.save()
    }

    static func restoreWorkout(scheduledWorkout: ScheduledWorkout, context: ModelContext) {
        guard scheduledWorkout.status == "skipped" else { return }
        scheduledWorkout.status = "planned"
        try? context.save()
    }

    static func deleteWorkout(scheduledWorkout: ScheduledWorkout, context: ModelContext) {
        context.delete(scheduledWorkout)
        try? context.save()
    }

    static func deleteThisAndFuture(scheduledWorkout: ScheduledWorkout, context: ModelContext) {
        guard let groupId = scheduledWorkout.recurrenceGroupId else {
            deleteWorkout(scheduledWorkout: scheduledWorkout, context: context)
            return
        }

        let cutoffDate = scheduledWorkout.scheduledDate

        let predicate = #Predicate<ScheduledWorkout> { sw in
            sw.recurrenceGroupId == groupId && sw.scheduledDate >= cutoffDate
        }
        let descriptor = FetchDescriptor<ScheduledWorkout>(predicate: predicate)
        guard let toDelete = try? context.fetch(descriptor) else { return }

        for item in toDelete {
            context.delete(item)
        }
        try? context.save()
    }

    // MARK: - Workout Deletion Linkage

    static func revertScheduledWorkoutsForDeletedWorkout(workoutId: UUID, context: ModelContext) {
        let predicate = #Predicate<ScheduledWorkout> { sw in
            sw.completedWorkoutId == workoutId
        }
        let descriptor = FetchDescriptor<ScheduledWorkout>(predicate: predicate)
        guard let linked = try? context.fetch(descriptor) else { return }

        for scheduled in linked {
            scheduled.completedWorkoutId = nil
            scheduled.status = "planned"
        }
        try? context.save()
    }

    // MARK: - Plan-ID Lookup (Phase 8.7)

    static func findByPlanId(_ planId: UUID, context: ModelContext) -> ScheduledWorkout? {
        let predicate = #Predicate<ScheduledWorkout> { sw in
            sw.appleWorkoutPlanId == planId
        }
        let descriptor = FetchDescriptor<ScheduledWorkout>(predicate: predicate)
        return (try? context.fetch(descriptor))?.first
    }

    // MARK: - Complete from Watch (Phase 8.7)

    static func completeFromWatch(
        scheduledWorkout: ScheduledWorkout,
        hkSnapshot: HealthKitWorkoutSnapshot,
        context: ModelContext
    ) {
        let exercises: [SnapshotExercise]
        if let snapshotData = scheduledWorkout.scheduledWorkoutSnapshot {
            exercises = decodeSnapshot(data: snapshotData)
        } else {
            exercises = []
        }

        let activityTypeDisplay = OutboundHKMapping.activityTypeDisplayString(for: scheduledWorkout.workoutType) ?? hkSnapshot.mapping.displayString

        let workout = Workout(
            name: scheduledWorkout.workoutName,
            date: hkSnapshot.startDate,
            workoutType: scheduledWorkout.workoutType,
            durationMinutes: hkSnapshot.durationMinutes,
            distanceKm: hkSnapshot.distanceKm,
            time: hkSnapshot.startDate,
            healthKitUUID: hkSnapshot.uuid,
            healthKitSourceBundleID: hkSnapshot.sourceBundleID,
            healthKitActivityType: activityTypeDisplay,
            avgHeartRate: hkSnapshot.avgHeartRate,
            maxHeartRate: hkSnapshot.maxHeartRate,
            activeEnergyKcal: hkSnapshot.activeEnergyKcal,
            totalEnergyBurnedKcal: hkSnapshot.totalEnergyBurnedKcal,
            elevationAscendedMeters: hkSnapshot.elevationAscendedMeters,
            exerciseMinutes: hkSnapshot.exerciseMinutes,
            indoor: hkSnapshot.indoor
        )

        if scheduledWorkout.workoutType == "Strength Training" || scheduledWorkout.workoutType == "HIIT" {
            for exercise in exercises {
                let set = ExerciseSet(
                    exerciseName: exercise.exerciseName,
                    sets: exercise.sets,
                    reps: exercise.reps,
                    weightKg: exercise.weightKg,
                    sortOrder: exercise.sortOrder,
                    restSeconds: exercise.restSeconds,
                    displayAsTime: exercise.displayAsTime
                )
                workout.exerciseSets.append(set)
            }
        }

        WorkoutService.logWorkout(workout, context: context)
        WorkoutTypeOrderService.ensureOrderExists(for: workout.workoutType, context: context)
        let exerciseNames = workout.exerciseSets.map { $0.exerciseName }
        GoalService.recalculateGoals(
            affectedExerciseNames: exerciseNames,
            affectedWorkoutTypes: [workout.workoutType],
            workout: workout,
            context: context
        )

        scheduledWorkout.status = "completed"
        scheduledWorkout.completedWorkoutId = workout.id
        try? context.save()
    }

    // MARK: - Edit Scheduled Workout (Phase 8.7)

    struct ScheduledWorkoutEdits {
        var workoutName: String
        var scheduledDate: Date
        var scheduledTime: Date?
        var durationMinutes: Int?
        var exercises: [SnapshotExercise]
        var syncToAppleWatch: Bool
        var workoutType: String
    }

    static func editScheduledWorkout(
        _ scheduledWorkout: ScheduledWorkout,
        edits: ScheduledWorkoutEdits,
        applyTo: RecurrenceScope,
        context: ModelContext
    ) -> [ScheduledWorkout] {
        let dateChanged = Calendar.current.startOfDay(for: edits.scheduledDate) != scheduledWorkout.scheduledDate
        let effectiveScope: RecurrenceScope
        if dateChanged && scheduledWorkout.recurrenceGroupId != nil {
            effectiveScope = .thisOnly
        } else {
            effectiveScope = applyTo
        }

        let snapshotData = try? JSONEncoder().encode(edits.exercises)

        var affected: [ScheduledWorkout] = []

        switch effectiveScope {
        case .thisOnly:
            applyEdits(to: scheduledWorkout, edits: edits, snapshotData: snapshotData)
            affected = [scheduledWorkout]

        case .thisAndFuture:
            guard let groupId = scheduledWorkout.recurrenceGroupId else {
                applyEdits(to: scheduledWorkout, edits: edits, snapshotData: snapshotData)
                affected = [scheduledWorkout]
                break
            }

            let cutoffDate = scheduledWorkout.scheduledDate
            let plannedStatus = "planned"
            let predicate = #Predicate<ScheduledWorkout> { sw in
                sw.recurrenceGroupId == groupId &&
                sw.scheduledDate >= cutoffDate &&
                sw.status == plannedStatus
            }
            let descriptor = FetchDescriptor<ScheduledWorkout>(predicate: predicate)
            let instances = (try? context.fetch(descriptor)) ?? []

            for instance in instances {
                applyEdits(to: instance, edits: edits, snapshotData: snapshotData, preserveDate: instance.id != scheduledWorkout.id)
            }
            affected = instances
        }

        try? context.save()
        return affected
    }

    private static func applyEdits(
        to sw: ScheduledWorkout,
        edits: ScheduledWorkoutEdits,
        snapshotData: Data?,
        preserveDate: Bool = false
    ) {
        sw.workoutName = edits.workoutName
        if !preserveDate {
            sw.scheduledDate = Calendar.current.startOfDay(for: edits.scheduledDate)
            sw.scheduledTime = edits.scheduledTime
        }
        sw.durationMinutes = edits.durationMinutes
        sw.workoutType = edits.workoutType
        sw.scheduledWorkoutSnapshot = snapshotData
        sw.syncToAppleWatch = edits.syncToAppleWatch
    }
}
