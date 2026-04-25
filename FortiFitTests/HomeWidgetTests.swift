import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// Helper to create an in-memory SwiftData context that includes HomeWidget.
private func makeTestContext() throws -> ModelContext {
    let schema = Schema([Workout.self, ExerciseSet.self, Goal.self, WorkoutTypeOrder.self, HomeWidget.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

// MARK: - HomeWidget Model Tests

struct HomeWidgetModelTests {

    @Test func createAndRetrieveHomeWidget() throws {
        let context = try makeTestContext()
        let widget = HomeWidget(widgetType: "trainingLoad", sortOrder: 0)
        context.insert(widget)
        try context.save()

        let descriptor = FetchDescriptor<HomeWidget>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.widgetType == "trainingLoad")
        #expect(results.first?.sortOrder == 0)
    }

    @Test func updateHomeWidgetSortOrder() throws {
        let context = try makeTestContext()
        let widget = HomeWidget(widgetType: "weekStreak", sortOrder: 0)
        context.insert(widget)
        try context.save()

        widget.sortOrder = 3
        try context.save()

        let descriptor = FetchDescriptor<HomeWidget>()
        let results = try context.fetch(descriptor)
        #expect(results.first?.sortOrder == 3)
    }

    @Test func deleteHomeWidget() throws {
        let context = try makeTestContext()
        let widget = HomeWidget(widgetType: "workoutInfo", sortOrder: 0)
        context.insert(widget)
        try context.save()

        context.delete(widget)
        try context.save()

        let descriptor = FetchDescriptor<HomeWidget>()
        let results = try context.fetch(descriptor)
        #expect(results.isEmpty)
    }
}

// MARK: - HomeWidgetService Tests

struct HomeWidgetServiceTests {

    @Test func seedDefaultWidgetsCreates3Records() throws {
        let context = try makeTestContext()

        HomeWidgetService.seedDefaultWidgets(context: context)

        let widgets = HomeWidgetService.fetchAll(context: context)
        #expect(widgets.count == 3)
        #expect(widgets[0].widgetType == "trainingLoad")
        #expect(widgets[0].sortOrder == 0)
        #expect(widgets[1].widgetType == "workoutInfo")
        #expect(widgets[1].sortOrder == 1)
        #expect(widgets[2].widgetType == "weekStreak")
        #expect(widgets[2].sortOrder == 2)
    }

    @Test func seedDefaultWidgetsIsIdempotent() throws {
        let context = try makeTestContext()

        HomeWidgetService.seedDefaultWidgets(context: context)
        HomeWidgetService.seedDefaultWidgets(context: context)

        let widgets = HomeWidgetService.fetchAll(context: context)
        #expect(widgets.count == 3)
    }

    @Test func addWidgetAssignsMaxSortOrderPlusOne() throws {
        let context = try makeTestContext()

        // Manually insert some widgets
        context.insert(HomeWidget(widgetType: "trainingLoad", sortOrder: 0))
        context.insert(HomeWidget(widgetType: "weekStreak", sortOrder: 1))
        try context.save()

        HomeWidgetService.addWidget(widgetType: "powerLevel", context: context)

        let widgets = HomeWidgetService.fetchAll(context: context)
        let powerLevel = widgets.first(where: { $0.widgetType == "powerLevel" })
        #expect(powerLevel?.sortOrder == 2)
    }

    @Test func addWidgetRejectsDuplicate() throws {
        let context = try makeTestContext()

        HomeWidgetService.addWidget(widgetType: "trainingLoad", context: context)
        HomeWidgetService.addWidget(widgetType: "trainingLoad", context: context)

        let widgets = HomeWidgetService.fetchAll(context: context)
        let trainingLoadWidgets = widgets.filter { $0.widgetType == "trainingLoad" }
        #expect(trainingLoadWidgets.count == 1)
    }

    @Test func deleteWidgetReindexesSortOrder() throws {
        let context = try makeTestContext()

        context.insert(HomeWidget(widgetType: "trainingLoad", sortOrder: 0))
        context.insert(HomeWidget(widgetType: "workoutInfo", sortOrder: 1))
        context.insert(HomeWidget(widgetType: "weekStreak", sortOrder: 2))
        try context.save()

        // Delete the middle one
        let middle = HomeWidgetService.fetch(for: "workoutInfo", context: context)!
        HomeWidgetService.deleteWidget(middle, context: context)

        let widgets = HomeWidgetService.fetchAll(context: context)
        #expect(widgets.count == 2)
        #expect(widgets[0].widgetType == "trainingLoad")
        #expect(widgets[0].sortOrder == 0)
        #expect(widgets[1].widgetType == "weekStreak")
        #expect(widgets[1].sortOrder == 1)
    }

    @Test func reorderPersistsNewSortIndices() throws {
        let context = try makeTestContext()

        context.insert(HomeWidget(widgetType: "trainingLoad", sortOrder: 0))
        context.insert(HomeWidget(widgetType: "workoutInfo", sortOrder: 1))
        context.insert(HomeWidget(widgetType: "weekStreak", sortOrder: 2))
        try context.save()

        // Reorder: weekStreak first, then trainingLoad, then workoutInfo
        HomeWidgetService.reorder(orderedTypes: ["weekStreak", "trainingLoad", "workoutInfo"], context: context)

        let widgets = HomeWidgetService.fetchAll(context: context)
        #expect(widgets[0].widgetType == "weekStreak")
        #expect(widgets[0].sortOrder == 0)
        #expect(widgets[1].widgetType == "trainingLoad")
        #expect(widgets[1].sortOrder == 1)
        #expect(widgets[2].widgetType == "workoutInfo")
        #expect(widgets[2].sortOrder == 2)
    }

    @Test func fetchAllReturnsSortedByOrder() throws {
        let context = try makeTestContext()

        // Insert in reverse order
        context.insert(HomeWidget(widgetType: "weekStreak", sortOrder: 2))
        context.insert(HomeWidget(widgetType: "trainingLoad", sortOrder: 0))
        context.insert(HomeWidget(widgetType: "workoutInfo", sortOrder: 1))
        try context.save()

        let widgets = HomeWidgetService.fetchAll(context: context)
        #expect(widgets[0].widgetType == "trainingLoad")
        #expect(widgets[1].widgetType == "workoutInfo")
        #expect(widgets[2].widgetType == "weekStreak")
    }

    @Test func deleteAllWidgetsLeavesEmptyList() throws {
        let context = try makeTestContext()

        context.insert(HomeWidget(widgetType: "trainingLoad", sortOrder: 0))
        context.insert(HomeWidget(widgetType: "workoutInfo", sortOrder: 1))
        try context.save()

        let widgets = HomeWidgetService.fetchAll(context: context)
        for widget in widgets {
            HomeWidgetService.deleteWidget(widget, context: context)
        }

        let remaining = HomeWidgetService.fetchAll(context: context)
        #expect(remaining.isEmpty)
    }
}
