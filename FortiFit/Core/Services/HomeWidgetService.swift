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

    // MARK: - Widget Linking (Phase 11)

    /// Decides whether the Recovery Status + Training Load pair should render as a
    /// single `FortiFitLinkedRecoveryLoadComposite` (shared border, zero padding) or
    /// as two independent cards.
    ///
    /// Five gate rules in strict order per SERVICES.md § HomeWidgetService → Widget Linking:
    ///   1. `settings.recoveryLoadManuallyUnlinked == true` → false
    ///   2. Both `"recoveryStatus"` and `"trainingLoad"` must be present → else false
    ///   3. Their `sortOrder` must be adjacent (`abs(rs - tl) == 1`) → else false
    ///   4. Recovery Status gating must be `.live` → else false
    ///   5. All gates passed → true
    @MainActor
    static func isLinkedActive(widgets: [HomeWidget], settings: UserSettings) -> Bool {
        // Rule 1: sticky manual override.
        if settings.recoveryLoadManuallyUnlinked { return false }

        // Rule 2: both widgets present.
        guard let rs = widgets.first(where: { $0.widgetType == "recoveryStatus" }),
              let tl = widgets.first(where: { $0.widgetType == "trainingLoad" })
        else { return false }

        // Rule 3: adjacent in sortOrder.
        guard abs(rs.sortOrder - tl.sortOrder) == 1 else { return false }

        // Rule 4: Recovery Status must be in Live gating state.
        guard RecoveryStatusService.current?.currentGatingState == .live else { return false }

        return true
    }

    /// Returns a new ordered `widgetType` array with the linked Recovery Status +
    /// Training Load pair moved together to land adjacent to `targetType`, preserving
    /// the pair's relative order (per SCREENS § Linked Recovery & Load Composite →
    /// Edit Mode: "The composite drags as one unit — dragging either card moves both").
    /// Returns nil if any input is invalid (pair widget missing, target IS a pair
    /// member, or target not present in the array).
    ///
    /// Shared between `HomeView`'s composite-as-destination path and the
    /// composite-as-source path so the pair travels together regardless of which
    /// card the user grabs and which card they drop onto.
    static func movePairOrderedTypes(
        previousOrderedTypes: [String],
        targetType: String
    ) -> [String]? {
        guard let rsIdx = previousOrderedTypes.firstIndex(of: "recoveryStatus"),
              let tlIdx = previousOrderedTypes.firstIndex(of: "trainingLoad")
        else { return nil }
        guard targetType != "recoveryStatus", targetType != "trainingLoad" else { return nil }
        guard let targetIdx = previousOrderedTypes.firstIndex(of: targetType) else { return nil }

        let pairOrdered: [String] = rsIdx < tlIdx
            ? ["recoveryStatus", "trainingLoad"]
            : ["trainingLoad", "recoveryStatus"]
        let pairWasBeforeTarget = min(rsIdx, tlIdx) < targetIdx

        var withoutPair = previousOrderedTypes.filter { $0 != "recoveryStatus" && $0 != "trainingLoad" }
        guard let anchor = withoutPair.firstIndex(of: targetType) else { return nil }
        let insertAt = pairWasBeforeTarget ? anchor + 1 : anchor
        withoutPair.insert(contentsOf: pairOrdered, at: insertAt)
        return withoutPair
    }

    /// Clears `UserSettings.recoveryLoadManuallyUnlinked` when a reorder operation
    /// actually changes the `sortOrder` of either Recovery Status or Training Load.
    /// Per SERVICES.md § Widget Linking → Clearing the manual flag.
    ///
    /// Pass the `previousOrderedTypes` snapshot taken before the reorder so this
    /// helper can compare against the new order. Entering edit mode without dragging
    /// does NOT clear the flag — the order is unchanged.
    static func clearManualUnlinkIfReorderAffectedPair(
        previousOrderedTypes: [String],
        newOrderedTypes: [String],
        settings: UserSettings
    ) {
        guard settings.recoveryLoadManuallyUnlinked else { return }
        let prevRS = previousOrderedTypes.firstIndex(of: "recoveryStatus")
        let prevTL = previousOrderedTypes.firstIndex(of: "trainingLoad")
        let newRS = newOrderedTypes.firstIndex(of: "recoveryStatus")
        let newTL = newOrderedTypes.firstIndex(of: "trainingLoad")
        if prevRS != newRS || prevTL != newTL {
            settings.recoveryLoadManuallyUnlinked = false
        }
    }
}
