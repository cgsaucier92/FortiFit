import Foundation
import SwiftData

struct WorkoutTypeOrderService {

    // MARK: - Read

    /// Fetches all WorkoutTypeOrder records sorted by sortOrder ascending.
    static func fetchAll(context: ModelContext) -> [WorkoutTypeOrder] {
        let descriptor = FetchDescriptor<WorkoutTypeOrder>(
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Fetches the WorkoutTypeOrder for a specific workout type, if it exists.
    static func fetch(for workoutType: String, context: ModelContext) -> WorkoutTypeOrder? {
        let descriptor = FetchDescriptor<WorkoutTypeOrder>(
            predicate: #Predicate<WorkoutTypeOrder> { order in
                order.workoutType == workoutType
            }
        )
        return (try? context.fetch(descriptor))?.first
    }

    // MARK: - Create (on first workout of a type)

    /// Creates a WorkoutTypeOrder when the first workout of a new type is saved.
    /// Does nothing if a record already exists for this type.
    static func ensureOrderExists(for workoutType: String, context: ModelContext) {
        guard fetch(for: workoutType, context: context) == nil else { return }

        let allOrders = fetchAll(context: context)
        let maxSort = allOrders.map(\.sortOrder).max() ?? -1

        let order = WorkoutTypeOrder(
            workoutType: workoutType,
            sortOrder: maxSort + 1
        )
        context.insert(order)
        try? context.save()
    }

    // MARK: - Delete (when last workout of a type is removed)

    /// Removes the WorkoutTypeOrder record for a workout type if no workouts
    /// of that type remain.
    static func removeOrderIfEmpty(for workoutType: String, context: ModelContext) {
        // Check if any workouts of this type still exist
        let predicate = #Predicate<Workout> { workout in
            workout.workoutType == workoutType
        }
        let descriptor = FetchDescriptor<Workout>(predicate: predicate)
        let remaining = (try? context.fetch(descriptor))?.count ?? 0

        guard remaining == 0 else { return }
        guard let order = fetch(for: workoutType, context: context) else { return }

        context.delete(order)
        try? context.save()
    }

    // MARK: - Toggle Expand/Collapse

    /// Toggles the isExpanded state for a given workout type.
    static func toggleExpanded(for workoutType: String, context: ModelContext) {
        guard let order = fetch(for: workoutType, context: context) else { return }
        order.isExpanded.toggle()
        try? context.save()
    }

    // MARK: - Reorder

    /// Reorders workout type cards. Accepts an array of workoutType strings
    /// in the desired order and re-indexes sortOrder values starting from 0.
    static func reorder(orderedTypes: [String], context: ModelContext) {
        let allOrders = fetchAll(context: context)
        let orderMap = Dictionary(uniqueKeysWithValues: allOrders.map { ($0.workoutType, $0) })

        for (index, type) in orderedTypes.enumerated() {
            orderMap[type]?.sortOrder = index
        }
        try? context.save()
    }

    // MARK: - Sort & Filter Persistence

    /// Updates the active sort option for a given workout type.
    static func updateSortOption(_ sortOption: String, for workoutType: String, context: ModelContext) {
        guard let order = fetch(for: workoutType, context: context) else { return }
        order.activeSortOption = sortOption
        try? context.save()
    }

    /// Updates the active filters JSON for a given workout type.
    static func updateFiltersJSON(_ filtersJSON: String?, for workoutType: String, context: ModelContext) {
        guard let order = fetch(for: workoutType, context: context) else { return }
        order.activeFiltersJSON = filtersJSON
        try? context.save()
    }

    /// Resets sort to default and clears all filters for a given workout type.
    static func clearSortAndFilters(for workoutType: String, context: ModelContext) {
        guard let order = fetch(for: workoutType, context: context) else { return }
        order.activeSortOption = "newestFirst"
        order.activeFiltersJSON = nil
        try? context.save()
    }
}
