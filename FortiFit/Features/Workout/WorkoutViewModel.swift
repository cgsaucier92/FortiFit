import Foundation
import SwiftUI
import SwiftData

#if os(iOS)
import UIKit
#endif

// MARK: - Filter State Model

struct WorkoutFilterState: Codable, Equatable {
    var dateRangePreset: String?
    var customDateStart: Date?
    var customDateEnd: Date?
    var rpeMin: Int?
    var rpeMax: Int?
    var durationBuckets: [String]?

    static let datePresets = ["last7", "last30", "last3months", "last6months", "thisYear", "allTime"]

    static let durationBucketLabels: [String: String] = [
        "under30": "Under 30 min",
        "30to60": "30–60 min",
        "60to90": "60–90 min",
        "90plus": "90+ min"
    ]

    static let allDurationBuckets = ["under30", "30to60", "60to90", "90plus"]

    var activeFilterCount: Int {
        var count = 0
        if let preset = dateRangePreset, preset != "allTime" { count += 1 }
        if customDateStart != nil || customDateEnd != nil { count += 1 }
        if rpeMin != nil || rpeMax != nil { count += 1 }
        if let buckets = durationBuckets, !buckets.isEmpty { count += 1 }
        return count
    }

    var hasActiveFilters: Bool { activeFilterCount > 0 }

    func dateRange() -> (start: Date, end: Date)? {
        if let start = customDateStart, let end = customDateEnd {
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
            return (start, endOfDay)
        }
        guard let preset = dateRangePreset, preset != "allTime" else { return nil }
        let now = Date()
        let calendar = Calendar.current
        switch preset {
        case "last7": return (calendar.date(byAdding: .day, value: -7, to: now)!, now)
        case "last30": return (calendar.date(byAdding: .day, value: -30, to: now)!, now)
        case "last3months": return (calendar.date(byAdding: .month, value: -3, to: now)!, now)
        case "last6months": return (calendar.date(byAdding: .month, value: -6, to: now)!, now)
        case "thisYear":
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
            return (startOfYear, now)
        default: return nil
        }
    }

    static func datePresetLabel(_ preset: String) -> String {
        switch preset {
        case "last7": return "Last 7 days"
        case "last30": return "Last 30 days"
        case "last3months": return "Last 3 months"
        case "last6months": return "Last 6 months"
        case "thisYear": return "This year"
        case "allTime": return "All time"
        default: return preset
        }
    }

    func encode() -> String? {
        guard hasActiveFilters || dateRangePreset != nil else { return nil }
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(from json: String?) -> WorkoutFilterState {
        guard let json, let data = json.data(using: .utf8),
              let state = try? JSONDecoder().decode(WorkoutFilterState.self, from: data) else {
            return WorkoutFilterState()
        }
        return state
    }
}

// MARK: - Sort Options

enum WorkoutSortOption: String, CaseIterable {
    case newestFirst
    case oldestFirst
    case alphabetical

    var label: String {
        switch self {
        case .newestFirst: return "Newest first"
        case .oldestFirst: return "Oldest first"
        case .alphabetical: return "Alphabetical (A–Z)"
        }
    }
}

@Observable
final class WorkoutViewModel {
    // MARK: - Data
    var workouts: [Workout] = []
    var workoutsByType: [String: [Workout]] = [:]
    var prTimeline: [PREntry] = []
    var typeOrders: [WorkoutTypeOrder] = []

    // MARK: - Log Workout Form State
    var workoutName = ""
    var workoutDate = Date()
    var workoutType = AppConstants.workoutTypes[0]
    var selectedRPE: Int?
    var exercises: [ExerciseFormEntry] = [ExerciseFormEntry()]
    var durationMinutes: String = ""
    var distanceKm: String = ""

    // MARK: - Edit Mode
    var isEditMode = false
    var editingWorkout: Workout?

    // MARK: - Navigation
    var showLogWorkout = false
    var selectedWorkout: Workout?
    var showDeleteConfirmation = false
    var workoutToDelete: Workout?
    var showDeleteTypeConfirmation = false
    var workoutTypeToDelete: String?
    var draggingTypeID: UUID?

    // MARK: - Reorder Mode
    var isReorderMode = false

    // MARK: - Pagination State (per workout type)
    var paginationLoadedCount: [String: Int] = [:]
    static let pageSize = 30

    // MARK: - Search State (per workout type)
    var searchQueries: [String: String] = [:]

    // MARK: - Filter UI State
    var showCustomDateRangePicker = false
    var customDateRangeWorkoutType: String?
    var customDateStart = Date()
    var customDateEnd = Date()

    // MARK: - Template Navigation (WorkoutListView)
    var showCreateTemplate = false
    var showSavedTemplates = false

    // MARK: - Template Features (LogWorkoutView)
    var templates: [WorkoutTemplate] = []
    var showTemplateSelector = false
    var showSaveAsTemplatePrompt = false
    var saveAsTemplateName = ""
    var showTemplateSavedToast = false

    // MARK: - Plan Integration
    var scheduledWorkoutId: UUID?

    // MARK: - Share State
    #if os(iOS)
    var shareImage: UIImage?
    #endif
    var showShareError = false

    // MARK: - Template QR Sharing State
    var templateToShare: WorkoutTemplate?

    // MARK: - Template Import State
    var templatePayloadToImport: TemplatePayload?
    var showImportError = false
    var showImportPrompt = false

    // MARK: - Autocomplete State
    var exerciseHistory: [String] = []
    var exerciseSuggestions: [ExerciseSuggestionService.Suggestion] = []
    var activeExerciseID: UUID?

    // MARK: - Computed

    var canSaveWorkout: Bool {
        !workoutName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var canSaveAsTemplate: Bool {
        isStrengthOrHIIT &&
        !workoutName.trimmingCharacters(in: .whitespaces).isEmpty &&
        exercises.contains { entry in
            !entry.name.trimmingCharacters(in: .whitespaces).isEmpty &&
            entry.rows.contains { !$0.sets.isEmpty && !$0.reps.isEmpty }
        }
    }

    var isStrengthOrHIIT: Bool {
        workoutType == "Strength Training" || workoutType == "HIIT"
    }

    var isCardioOrSprints: Bool {
        workoutType == "Cardio"
    }

    var isYogaOrPilates: Bool {
        workoutType == "Yoga" || workoutType == "Pilates"
    }

    var isHealthKitLinked: Bool {
        editingWorkout?.isHealthKitLinked == true
    }

    // MARK: - Actions

    func loadWorkouts(context: ModelContext) {
        workouts = WorkoutService.fetchAll(context: context)
        workoutsByType = Dictionary(grouping: workouts, by: \.workoutType)
        prTimeline = WorkoutService.computePRTimeline(context: context)
        typeOrders = WorkoutTypeOrderService.fetchAll(context: context)
        exerciseHistory = ExerciseSuggestionService.fetchExerciseHistory(context: context)
    }

    // MARK: - Autocomplete

    func updateSuggestions(for query: String, exerciseID: UUID) {
        activeExerciseID = exerciseID
        exerciseSuggestions = ExerciseSuggestionService.suggest(
            query: query,
            history: exerciseHistory
        )
    }

    func suggestionsForExercise(_ exercise: ExerciseFormEntry) -> [ExerciseSuggestionService.Suggestion] {
        activeExerciseID == exercise.id ? exerciseSuggestions : []
    }

    // MARK: - Workout Type Order & Sort/Filter Pipeline

    /// Returns ALL workouts for a type, sorted and filtered (no pagination or search).
    func filteredSortedWorkouts(forType workoutType: String) -> [Workout] {
        let typeWorkouts = workoutsByType[workoutType] ?? []
        let typeOrder = typeOrders.first { $0.workoutType == workoutType }
        let sortOption = WorkoutSortOption(rawValue: typeOrder?.activeSortOption ?? "newestFirst") ?? .newestFirst
        let filterState = WorkoutFilterState.decode(from: typeOrder?.activeFiltersJSON)

        // Apply sort
        let sorted: [Workout]
        switch sortOption {
        case .newestFirst:
            sorted = typeWorkouts.sorted { $0.date > $1.date }
        case .oldestFirst:
            sorted = typeWorkouts.sorted { $0.date < $1.date }
        case .alphabetical:
            sorted = typeWorkouts.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        // Apply filters
        guard filterState.hasActiveFilters else { return sorted }
        return sorted.filter { workout in
            // Date range filter
            if let range = filterState.dateRange() {
                guard workout.date >= range.start && workout.date <= range.end else { return false }
            }
            // RPE filter (excludes nil RPE)
            if filterState.rpeMin != nil || filterState.rpeMax != nil {
                guard let rpe = workout.rpe else { return false }
                if let min = filterState.rpeMin, rpe < min { return false }
                if let max = filterState.rpeMax, rpe > max { return false }
            }
            // Duration buckets (OR logic within, AND with other filters)
            if let buckets = filterState.durationBuckets, !buckets.isEmpty {
                guard let duration = workout.durationMinutes else { return false }
                let matchesBucket = buckets.contains { bucket in
                    switch bucket {
                    case "under30": return duration < 30
                    case "30to60": return duration >= 30 && duration <= 60
                    case "60to90": return duration > 60 && duration <= 90
                    case "90plus": return duration > 90
                    default: return false
                    }
                }
                if !matchesBucket { return false }
            }
            return true
        }
    }

    /// Returns workouts for display (applies search or pagination on top of sort+filter).
    func displayedWorkouts(forType workoutType: String) -> [Workout] {
        let base = filteredSortedWorkouts(forType: workoutType)
        let query = searchQueries[workoutType] ?? ""

        if !query.isEmpty {
            // Search replaces pagination — show all matches
            return base.filter { $0.name.localizedCaseInsensitiveContains(query) }
        }

        // Paginate
        let loaded = paginationLoadedCount[workoutType] ?? Self.pageSize
        return Array(base.prefix(loaded))
    }

    /// Total count after sort+filter (before pagination/search).
    func totalFilteredCount(forType workoutType: String) -> Int {
        filteredSortedWorkouts(forType: workoutType).count
    }

    /// Whether the "Show More" button should be visible.
    func showMoreVisible(forType workoutType: String) -> Bool {
        let query = searchQueries[workoutType] ?? ""
        guard query.isEmpty else { return false }
        let total = totalFilteredCount(forType: workoutType)
        let loaded = paginationLoadedCount[workoutType] ?? Self.pageSize
        return loaded < total
    }

    /// Dynamic text for the "Show More" button.
    func showMoreText(forType workoutType: String) -> String {
        let total = totalFilteredCount(forType: workoutType)
        let loaded = paginationLoadedCount[workoutType] ?? Self.pageSize
        let remaining = total - loaded
        let nextBatch = min(remaining, Self.pageSize)
        return "Show next \(nextBatch) workouts (\(total) total)"
    }

    /// Whether the search bar should appear (type has >20 workouts).
    func shouldShowSearchBar(forType workoutType: String) -> Bool {
        (workoutsByType[workoutType]?.count ?? 0) > 20
    }

    /// Whether the filter result set is empty (for showing "No workouts match your filters").
    func isFilterResultEmpty(forType workoutType: String) -> Bool {
        let typeOrder = typeOrders.first { $0.workoutType == workoutType }
        let filterState = WorkoutFilterState.decode(from: typeOrder?.activeFiltersJSON)
        guard filterState.hasActiveFilters else { return false }
        return filteredSortedWorkouts(forType: workoutType).isEmpty
    }

    /// Whether search returned no results.
    func isSearchEmpty(forType workoutType: String) -> Bool {
        let query = searchQueries[workoutType] ?? ""
        guard !query.isEmpty else { return false }
        return displayedWorkouts(forType: workoutType).isEmpty
    }

    // MARK: - Sort Actions

    func sortOption(forType workoutType: String) -> WorkoutSortOption {
        let typeOrder = typeOrders.first { $0.workoutType == workoutType }
        return WorkoutSortOption(rawValue: typeOrder?.activeSortOption ?? "newestFirst") ?? .newestFirst
    }

    func setSortOption(_ option: WorkoutSortOption, forType workoutType: String, context: ModelContext) {
        WorkoutTypeOrderService.updateSortOption(option.rawValue, for: workoutType, context: context)
        typeOrders = WorkoutTypeOrderService.fetchAll(context: context)
        resetPagination(forType: workoutType)
    }

    // MARK: - Filter Actions

    func filterState(forType workoutType: String) -> WorkoutFilterState {
        let typeOrder = typeOrders.first { $0.workoutType == workoutType }
        return WorkoutFilterState.decode(from: typeOrder?.activeFiltersJSON)
    }

    func updateFilterState(_ state: WorkoutFilterState, forType workoutType: String, context: ModelContext) {
        WorkoutTypeOrderService.updateFiltersJSON(state.encode(), for: workoutType, context: context)
        typeOrders = WorkoutTypeOrderService.fetchAll(context: context)
        resetPagination(forType: workoutType)
    }

    func clearSortAndFilters(forType workoutType: String, context: ModelContext) {
        WorkoutTypeOrderService.clearSortAndFilters(for: workoutType, context: context)
        typeOrders = WorkoutTypeOrderService.fetchAll(context: context)
        resetPagination(forType: workoutType)
    }

    func hasNonDefaultSortOrFilters(forType workoutType: String) -> Bool {
        let sort = sortOption(forType: workoutType)
        let filters = filterState(forType: workoutType)
        return sort != .newestFirst || filters.hasActiveFilters
    }

    /// Whether the duration filter should be shown (hidden for Yoga/Pilates).
    func showDurationFilter(forType workoutType: String) -> Bool {
        workoutType != "Yoga" && workoutType != "Pilates"
    }

    // MARK: - Pagination Actions

    func loadMore(forType workoutType: String) {
        let current = paginationLoadedCount[workoutType] ?? Self.pageSize
        paginationLoadedCount[workoutType] = current + Self.pageSize
    }

    func resetPagination(forType workoutType: String) {
        paginationLoadedCount[workoutType] = Self.pageSize
    }

    // MARK: - Search Actions

    func searchQuery(forType workoutType: String) -> String {
        searchQueries[workoutType] ?? ""
    }

    func setSearchQuery(_ query: String, forType workoutType: String) {
        searchQueries[workoutType] = query
    }

    func clearSearch(forType workoutType: String) {
        searchQueries[workoutType] = ""
    }

    // MARK: - Expand/Collapse & Reorder

    func toggleExpanded(for workoutType: String, context: ModelContext) {
        guard !isReorderMode else { return }
        // Reset pagination on re-expand (sort/filter preserved)
        let typeOrder = typeOrders.first { $0.workoutType == workoutType }
        let wasExpanded = typeOrder?.isExpanded ?? false
        WorkoutTypeOrderService.toggleExpanded(for: workoutType, context: context)
        typeOrders = WorkoutTypeOrderService.fetchAll(context: context)
        if wasExpanded {
            resetPagination(forType: workoutType)
        }
    }

    func enterReorderMode() {
        isReorderMode = true
    }

    func exitReorderMode() {
        isReorderMode = false
    }

    func reorderTypes(orderedTypes: [String], context: ModelContext) {
        WorkoutTypeOrderService.reorder(orderedTypes: orderedTypes, context: context)
        typeOrders = WorkoutTypeOrderService.fetchAll(context: context)
    }

    func saveWorkout(context: ModelContext) {
        let workout = Workout(
            name: workoutName.trimmingCharacters(in: .whitespaces),
            date: workoutDate,
            workoutType: workoutType,
            rpe: selectedRPE,
            durationMinutes: parseDuration(),
            distanceKm: parseDistance(),
            time: workoutDate
        )

        if isStrengthOrHIIT {
            var globalSortOrder = 0
            for entry in exercises {
                guard !entry.name.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
                for row in entry.rows {
                    let exerciseSet = ExerciseSet(
                        exerciseName: entry.name.trimmingCharacters(in: .whitespaces),
                        sets: max(Int(row.sets) ?? 1, 1),
                        reps: max(Int(row.reps) ?? 1, 1),
                        weightKg: parseWeight(row.weight),
                        sortOrder: globalSortOrder
                    )
                    workout.exerciseSets.append(exerciseSet)
                    globalSortOrder += 1
                }
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

        // Plan integration: mark scheduled slot as completed
        if let swId = scheduledWorkoutId {
            PlanService.markCompletedFromLogWorkout(
                scheduledWorkoutId: swId,
                workoutId: workout.id,
                context: context
            )
        }

        loadWorkouts(context: context)
        resetForm()
    }

    func deleteWorkout(_ workout: Workout, context: ModelContext) {
        let workoutType = workout.workoutType
        let deletedDate = workout.date
        let exerciseNames = workout.exerciseSets.map { $0.exerciseName }

        // Identify affected goals before deletion for snapshot recompute
        let allGoals = GoalService.fetchAll(context: context)
        let affectedLower = Set(exerciseNames.map { $0.lowercased() })
        let affectedGoals = allGoals.filter {
            (($0.goalType == "Strength PR" || $0.goalType == "Repetitions PR") &&
             affectedLower.contains($0.title.lowercased())) ||
            ($0.goalType == "Speed and Distance" &&
             $0.linkedWorkoutType == workoutType)
        }

        _ = WorkoutService.deleteWorkout(workout, context: context)
        WorkoutTypeOrderService.removeOrderIfEmpty(for: workoutType, context: context)
        GoalService.recalculateGoals(
            affectedExerciseNames: exerciseNames,
            affectedWorkoutTypes: [workoutType],
            context: context
        )

        // Manually recompute snapshots on the deleted workout's date
        for goal in affectedGoals {
            GoalSnapshotService.recomputeSnapshot(goal: goal, date: deletedDate, context: context)
        }
        loadWorkouts(context: context)
    }

    func deleteWorkoutType(_ workoutType: String, context: ModelContext) {
        // Capture dates and exercise names before deletion for snapshot recompute
        let typeWorkouts = workoutsByType[workoutType] ?? []
        let deletedDates = Set(typeWorkouts.map { Calendar.current.startOfDay(for: $0.date) })
        let exerciseNames = Array(Set(typeWorkouts.flatMap { $0.exerciseSets.map { $0.exerciseName } }))

        // Identify affected goals before deletion
        let allGoals = GoalService.fetchAll(context: context)
        let affectedLower = Set(exerciseNames.map { $0.lowercased() })
        let affectedGoals = allGoals.filter {
            (($0.goalType == "Strength PR" || $0.goalType == "Repetitions PR") &&
             affectedLower.contains($0.title.lowercased())) ||
            ($0.goalType == "Speed and Distance" &&
             $0.linkedWorkoutType == workoutType)
        }

        _ = WorkoutService.deleteAllForType(workoutType, context: context)
        WorkoutTypeOrderService.removeOrderIfEmpty(for: workoutType, context: context)
        GoalService.recalculateGoals(
            affectedExerciseNames: exerciseNames,
            affectedWorkoutTypes: [workoutType],
            context: context
        )

        // Manually recompute snapshots for all affected goals on all deleted dates
        for goal in affectedGoals {
            for date in deletedDates {
                GoalSnapshotService.recomputeSnapshot(goal: goal, date: date, context: context)
            }
        }
        loadWorkouts(context: context)
    }

    func updateNote(_ workout: Workout, note: String?, context: ModelContext) {
        WorkoutService.updateNote(workout, note: note, context: context)
        // Note edit bumps lastModifiedDate, which may re-scope the workout for goals
        let exerciseNames = workout.exerciseSets.map { $0.exerciseName }
        GoalService.recalculateGoals(
            affectedExerciseNames: exerciseNames,
            affectedWorkoutTypes: [workout.workoutType],
            workout: workout,
            context: context
        )
        loadWorkouts(context: context)
    }

    func populateForm(from workout: Workout) {
        isEditMode = true
        editingWorkout = workout
        workoutName = workout.name
        workoutDate = workout.time ?? workout.date
        workoutType = workout.workoutType
        selectedRPE = workout.rpe
        durationMinutes = workout.durationMinutes.map { String($0) } ?? ""

        let settings = UserSettings.shared
        if let km = workout.distanceKm {
            if settings.useMiles {
                distanceKm = String(format: "%g", UnitConversion.kmToMiles(km))
            } else {
                distanceKm = String(km)
            }
        } else {
            distanceKm = ""
        }

        // Group exercise sets by name, preserving sortOrder
        let sorted = workout.exerciseSets.sorted { $0.sortOrder < $1.sortOrder }
        let grouped = Dictionary(grouping: sorted, by: { $0.exerciseName })
        let orderedNames = sorted.map { $0.exerciseName }
        var seen = Set<String>()
        let uniqueNames = orderedNames.filter { seen.insert($0).inserted }

        if uniqueNames.isEmpty {
            exercises = [ExerciseFormEntry()]
        } else {
            exercises = uniqueNames.map { name in
                let entry = ExerciseFormEntry()
                entry.name = name
                if let sets = grouped[name] {
                    entry.rows = sets.map { exerciseSet in
                        let row = SetRow()
                        row.sets = String(exerciseSet.sets)
                        row.reps = String(exerciseSet.reps)
                        if let weightKg = exerciseSet.weightKg {
                            if settings.useLbs, let lbs = UnitConversion.kgToLbs(weightKg) {
                                row.weight = String(Int(round(lbs)))
                            } else {
                                row.weight = String(format: "%g", weightKg)
                            }
                        }
                        return row
                    }
                }
                return entry
            }
        }
    }

    func saveEditedWorkout(context: ModelContext) {
        guard let workout = editingWorkout else { return }

        // Build new exercise sets
        var newSets: [ExerciseSet] = []
        if isStrengthOrHIIT {
            var globalSortOrder = 0
            for entry in exercises {
                guard !entry.name.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
                for row in entry.rows {
                    let exerciseSet = ExerciseSet(
                        exerciseName: entry.name.trimmingCharacters(in: .whitespaces),
                        sets: max(Int(row.sets) ?? 1, 1),
                        reps: max(Int(row.reps) ?? 1, 1),
                        weightKg: parseWeight(row.weight),
                        sortOrder: globalSortOrder
                    )
                    newSets.append(exerciseSet)
                    globalSortOrder += 1
                }
            }
        }

        let result = WorkoutService.updateWorkout(
            workout,
            name: workoutName.trimmingCharacters(in: .whitespaces),
            date: workoutDate,
            time: workoutDate,
            rpe: selectedRPE,
            durationMinutes: parseDuration(),
            distanceKm: parseDistance(),
            newExerciseSets: newSets
        )

        // Cascading recalculation with priorDate for date-change snapshot handling
        GoalService.recalculateGoals(
            affectedExerciseNames: result.affectedNames,
            affectedWorkoutTypes: [workout.workoutType],
            workout: workout,
            priorDate: result.priorDate,
            context: context
        )
        loadWorkouts(context: context)
        resetForm()
    }

    func resetForm() {
        isEditMode = false
        editingWorkout = nil
        workoutName = ""
        workoutDate = Date()
        workoutType = AppConstants.workoutTypes[0]
        selectedRPE = nil
        exercises = [ExerciseFormEntry()]
        scheduledWorkoutId = nil
        durationMinutes = ""
        distanceKm = ""
    }

    // MARK: - Template Actions

    func loadTemplates(context: ModelContext) {
        if isEditMode {
            templates = WorkoutTemplateService.templates(matching: workoutType, context: context)
        } else {
            templates = WorkoutTemplateService.fetchAll(context: context)
        }
    }

    func applyTemplate(_ template: WorkoutTemplate) {
        let snapshot = WorkoutTemplateService.snapshot(from: template)
        workoutName = snapshot.name
        workoutType = snapshot.workoutType
        durationMinutes = snapshot.durationMinutes.map { String($0) } ?? ""
        workoutDate = Date()
        selectedRPE = nil

        let settings = UserSettings.shared
        let sorted = snapshot.exercises.sorted { $0.sortOrder < $1.sortOrder }
        var seen = Set<String>()
        var uniqueNames: [String] = []
        for ex in sorted {
            if seen.insert(ex.name).inserted { uniqueNames.append(ex.name) }
        }
        let grouped = Dictionary(grouping: sorted, by: { $0.name })

        if uniqueNames.isEmpty {
            exercises = [ExerciseFormEntry()]
        } else {
            exercises = uniqueNames.map { name in
                let entry = ExerciseFormEntry()
                entry.name = name
                if let rows = grouped[name] {
                    entry.rows = rows.map { ex in
                        let row = SetRow()
                        row.sets = String(ex.sets)
                        row.reps = String(ex.reps)
                        if let weightKg = ex.weightKg {
                            if settings.useLbs, let lbs = UnitConversion.kgToLbs(weightKg) {
                                row.weight = String(Int(round(lbs)))
                            } else {
                                row.weight = String(format: "%g", weightKg)
                            }
                        }
                        return row
                    }
                }
                return entry
            }
        }
    }

    func applyTemplateToEditingWorkout(_ template: WorkoutTemplate) {
        let snapshot = WorkoutTemplateService.snapshot(from: template)
        let settings = UserSettings.shared

        let isFormEmpty = exercises.count == 1
            && exercises[0].name.trimmingCharacters(in: .whitespaces).isEmpty
            && exercises[0].rows.allSatisfy { $0.sets.isEmpty && $0.reps.isEmpty && $0.weight.isEmpty }
        if isFormEmpty {
            exercises.removeAll()
        }

        let sorted = snapshot.exercises.sorted { $0.sortOrder < $1.sortOrder }
        var seen = Set<String>()
        var uniqueNames: [String] = []
        for ex in sorted {
            if seen.insert(ex.name).inserted { uniqueNames.append(ex.name) }
        }
        let grouped = Dictionary(grouping: sorted, by: { $0.name })

        for name in uniqueNames {
            let entry = ExerciseFormEntry()
            entry.name = name
            if let rows = grouped[name] {
                entry.rows = rows.map { ex in
                    let row = SetRow()
                    row.sets = String(ex.sets)
                    row.reps = String(ex.reps)
                    if let weightKg = ex.weightKg {
                        if settings.useLbs, let lbs = UnitConversion.kgToLbs(weightKg) {
                            row.weight = String(Int(round(lbs)))
                        } else {
                            row.weight = String(format: "%g", weightKg)
                        }
                    }
                    return row
                }
            }
            exercises.append(entry)
        }

        if workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            workoutName = snapshot.name
        }

        if !isHealthKitLinked && durationMinutes.trimmingCharacters(in: .whitespaces).isEmpty {
            if let dur = snapshot.durationMinutes {
                durationMinutes = String(dur)
            }
        }
    }

    func saveWorkoutAsTemplate(name: String, workout: Workout, context: ModelContext) {
        let data = workout.exerciseSets
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { set in
                WorkoutTemplateService.ExerciseData(
                    name: set.exerciseName,
                    sets: set.sets,
                    reps: set.reps,
                    weightKg: set.weightKg,
                    sortOrder: set.sortOrder
                )
            }
        WorkoutTemplateService.create(
            name: name.trimmingCharacters(in: .whitespaces),
            workoutType: workout.workoutType,
            durationMinutes: workout.durationMinutes,
            exercises: data,
            context: context
        )
    }

    func saveCurrentFormAsTemplate(name: String, context: ModelContext) {
        var data: [WorkoutTemplateService.ExerciseData] = []
        var globalSortOrder = 0
        for entry in exercises {
            guard !entry.name.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            for row in entry.rows {
                data.append(WorkoutTemplateService.ExerciseData(
                    name: entry.name.trimmingCharacters(in: .whitespaces),
                    sets: max(Int(row.sets) ?? 1, 1),
                    reps: max(Int(row.reps) ?? 1, 1),
                    weightKg: parseWeight(row.weight),
                    sortOrder: globalSortOrder
                ))
                globalSortOrder += 1
            }
        }
        WorkoutTemplateService.create(
            name: name.trimmingCharacters(in: .whitespaces),
            workoutType: workoutType,
            durationMinutes: parseDuration(),
            exercises: data,
            context: context
        )
        loadTemplates(context: context)
    }

    // MARK: - Template Deep Link

    func handleTemplateDeepLink(url: URL) {
        if let payload = TemplateShareService.decodeTemplateURL(url: url) {
            templatePayloadToImport = payload
            showImportError = false
            showImportPrompt = true
        } else {
            templatePayloadToImport = nil
            showImportError = true
            showImportPrompt = true
        }
    }

    // MARK: - Share Actions

    #if os(iOS)
    @MainActor
    func exportWorkout(_ workout: Workout) {
        let settings = UserSettings.shared
        if let image = WorkoutShareService.renderShareImage(workout: workout, userSettings: settings) {
            shareImage = image
        } else {
            showShareError = true
        }
    }
    #endif

    // MARK: - Helpers

    private func parseDuration() -> Int? {
        let value = Int(durationMinutes)
        return value != nil && value! > 0 ? value : nil
    }

    private func parseDistance() -> Double? {
        guard isCardioOrSprints else { return nil }
        guard let value = Double(distanceKm), value > 0 else { return nil }
        let settings = UserSettings.shared
        return settings.useMiles ? UnitConversion.milesToKm(value) : value
    }

    private func parseWeight(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let settings = UserSettings.shared
        if let value = Double(trimmed) {
            if settings.useLbs {
                return UnitConversion.lbsToKg(value)
            }
            return value
        }
        return nil
    }
}

// MARK: - Form Entry Models

@Observable
final class ExerciseFormEntry: Identifiable {
    let id = UUID()
    var name: String = ""
    var rows: [SetRow] = [SetRow()]

    func addRow() {
        rows.append(SetRow())
    }

    func removeRow(_ row: SetRow) {
        rows.removeAll { $0.id == row.id }
        if rows.isEmpty { rows.append(SetRow()) }
    }
}

@Observable
final class SetRow: Identifiable {
    let id = UUID()
    var sets: String = ""
    var reps: String = ""
    var weight: String = ""
}
