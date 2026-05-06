import Foundation
import SwiftData

struct HomeWidgetService {

    // MARK: - Read

    /// Fetches all HomeWidget records sorted by sortOrder ascending.
    static func fetchAll(context: ModelContext) -> [HomeWidget] {
        let descriptor = FetchDescriptor<HomeWidget>(
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Fetches the HomeWidget for a specific widget type, if it exists.
    static func fetch(for widgetType: String, context: ModelContext) -> HomeWidget? {
        let descriptor = FetchDescriptor<HomeWidget>(
            predicate: #Predicate<HomeWidget> { widget in
                widget.widgetType == widgetType
            }
        )
        return (try? context.fetch(descriptor))?.first
    }

    // MARK: - Seed Defaults

    /// Seeds the default Home screen widgets on first launch.
    /// Guarded by UserSettings flag — runs once, then never again.
    static func seedDefaultWidgets(context: ModelContext) {
        migrateLegacyWidgets(context: context)

        let settings = UserSettings.shared
        guard !settings.hasSeededDefaultHomeWidgets else { return }

        let existing = fetchAll(context: context)
        let existingTypes = Set(existing.map(\.widgetType))
        let maxSort = existing.map(\.sortOrder).max() ?? -1
        var nextSort = maxSort + 1

        for widgetType in AppConstants.defaultHomeWidgets {
            guard !existingTypes.contains(widgetType) else { continue }
            let widget = HomeWidget(widgetType: widgetType, sortOrder: nextSort)
            context.insert(widget)
            nextSort += 1
        }
        try? context.save()
        settings.hasSeededDefaultHomeWidgets = true
    }

    /// Removes legacy "lastWorkout" and "totalWorkouts" widgets (retired in earlier versions).
    private static func migrateLegacyWidgets(context: ModelContext) {
        let lastWorkout = fetch(for: "lastWorkout", context: context)
        let totalWorkouts = fetch(for: "totalWorkouts", context: context)

        guard lastWorkout != nil || totalWorkouts != nil else { return }

        if let lw = lastWorkout { context.delete(lw) }
        if let tw = totalWorkouts { context.delete(tw) }
        try? context.save()
        reindexSortOrder(context: context)
    }

    // MARK: - Add

    /// Adds a widget to the Home screen at the end of the list.
    /// Does nothing if a widget of this type already exists.
    static func addWidget(widgetType: String, context: ModelContext) {
        guard fetch(for: widgetType, context: context) == nil else { return }

        let allWidgets = fetchAll(context: context)
        let maxSort = allWidgets.map(\.sortOrder).max() ?? -1

        let widget = HomeWidget(widgetType: widgetType, sortOrder: maxSort + 1)
        context.insert(widget)
        try? context.save()
    }

    // MARK: - Delete

    /// Deletes a widget and re-indexes remaining sortOrder values.
    static func deleteWidget(_ widget: HomeWidget, context: ModelContext) {
        context.delete(widget)
        try? context.save()
        reindexSortOrder(context: context)
    }

    // MARK: - Reorder

    /// Reorders widgets. Accepts an array of widgetType strings
    /// in the desired order and re-indexes sortOrder values starting from 0.
    static func reorder(orderedTypes: [String], context: ModelContext) {
        let allWidgets = fetchAll(context: context)
        let widgetMap = Dictionary(uniqueKeysWithValues: allWidgets.map { ($0.widgetType, $0) })

        for (index, type) in orderedTypes.enumerated() {
            widgetMap[type]?.sortOrder = index
        }
        try? context.save()
    }

    // MARK: - Migrations

    /// Removes any existing Workout Info widget records and re-indexes sort order.
    /// Idempotent — guarded by UserSettings flag.
    static func migrateWorkoutInfoRemovalIfNeeded(context: ModelContext) {
        let settings = UserSettings.shared
        guard !settings.hasMigratedWorkoutInfoRemoval else { return }
        let stale = fetch(for: "workoutInfo", context: context)
        if let stale {
            context.delete(stale)
            try? context.save()
            reindexSortOrder(context: context)
        }
        settings.hasMigratedWorkoutInfoRemoval = true
    }

    // MARK: - Private

    /// Re-indexes sortOrder values to close gaps after a deletion.
    private static func reindexSortOrder(context: ModelContext) {
        let allWidgets = fetchAll(context: context)
        for (index, widget) in allWidgets.enumerated() {
            widget.sortOrder = index
        }
        try? context.save()
    }
}
