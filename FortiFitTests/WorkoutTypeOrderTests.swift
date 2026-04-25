import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// Helper to create an in-memory SwiftData context that includes WorkoutTypeOrder.
private func makeTestContext() throws -> ModelContext {
    let schema = Schema([Workout.self, ExerciseSet.self, Goal.self, WorkoutTypeOrder.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

// MARK: - WorkoutTypeOrder Model Tests

struct WorkoutTypeOrderModelTests {

    @Test func createAndRetrieveWorkoutTypeOrder() throws {
        let context = try makeTestContext()
        let order = WorkoutTypeOrder(workoutType: "Strength Training", sortOrder: 0)
        context.insert(order)
        try context.save()

        let descriptor = FetchDescriptor<WorkoutTypeOrder>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.id == order.id)
        #expect(results.first?.workoutType == "Strength Training")
    }

    @Test func updateWorkoutTypeOrder() throws {
        let context = try makeTestContext()
        let order = WorkoutTypeOrder(workoutType: "Yoga", sortOrder: 0)
        context.insert(order)
        try context.save()

        order.sortOrder = 5
        try context.save()

        let descriptor = FetchDescriptor<WorkoutTypeOrder>()
        let results = try context.fetch(descriptor)
        #expect(results.first?.sortOrder == 5)
    }

    @Test func deleteWorkoutTypeOrder() throws {
        let context = try makeTestContext()
        let order = WorkoutTypeOrder(workoutType: "HIIT", sortOrder: 0)
        context.insert(order)
        try context.save()

        context.delete(order)
        try context.save()

        let descriptor = FetchDescriptor<WorkoutTypeOrder>()
        let results = try context.fetch(descriptor)
        #expect(results.isEmpty)
    }

    @Test func deletedRecordNotReturnedByFetch() throws {
        let context = try makeTestContext()
        let order = WorkoutTypeOrder(workoutType: "Cardio", sortOrder: 0)
        context.insert(order)
        try context.save()

        let id = order.id
        context.delete(order)
        try context.save()

        let results = WorkoutTypeOrderService.fetchAll(context: context)
        #expect(!results.contains(where: { $0.id == id }))
    }

    @Test func isExpandedDefaultsToFalse() throws {
        let context = try makeTestContext()
        let order = WorkoutTypeOrder(workoutType: "Pilates", sortOrder: 0)
        context.insert(order)
        try context.save()

        let descriptor = FetchDescriptor<WorkoutTypeOrder>()
        let results = try context.fetch(descriptor)
        #expect(results.first?.isExpanded == false)
    }
}

// MARK: - WorkoutTypeOrderService Tests

struct WorkoutTypeOrderServiceTests {

    @Test func savingWorkoutCreatesOrderWhenNoneExists() throws {
        let context = try makeTestContext()
        let workout = Workout(name: "Morning Yoga", workoutType: "Yoga")
        context.insert(workout)
        try context.save()

        WorkoutTypeOrderService.ensureOrderExists(for: "Yoga", context: context)

        let orders = WorkoutTypeOrderService.fetchAll(context: context)
        #expect(orders.count == 1)
        #expect(orders.first?.workoutType == "Yoga")
    }

    @Test func newOrderHasSortOrderMaxPlusOne() throws {
        let context = try makeTestContext()

        // Create first type
        let w1 = Workout(name: "Push Day", workoutType: "Strength Training")
        context.insert(w1)
        try context.save()
        WorkoutTypeOrderService.ensureOrderExists(for: "Strength Training", context: context)

        // Create second type
        let w2 = Workout(name: "Morning Yoga", workoutType: "Yoga")
        context.insert(w2)
        try context.save()
        WorkoutTypeOrderService.ensureOrderExists(for: "Yoga", context: context)

        let orders = WorkoutTypeOrderService.fetchAll(context: context)
        #expect(orders.count == 2)
        let yogaOrder = orders.first(where: { $0.workoutType == "Yoga" })
        #expect(yogaOrder?.sortOrder == 1)
    }

    @Test func newOrderHasIsExpandedFalse() throws {
        let context = try makeTestContext()
        let w = Workout(name: "Run", workoutType: "Cardio")
        context.insert(w)
        try context.save()
        WorkoutTypeOrderService.ensureOrderExists(for: "Cardio", context: context)

        let order = WorkoutTypeOrderService.fetch(for: "Cardio", context: context)
        #expect(order?.isExpanded == false)
    }

    @Test func savingWorkoutDoesNotCreateDuplicate() throws {
        let context = try makeTestContext()
        let w1 = Workout(name: "Push Day", workoutType: "Strength Training")
        context.insert(w1)
        try context.save()
        WorkoutTypeOrderService.ensureOrderExists(for: "Strength Training", context: context)

        let w2 = Workout(name: "Pull Day", workoutType: "Strength Training")
        context.insert(w2)
        try context.save()
        WorkoutTypeOrderService.ensureOrderExists(for: "Strength Training", context: context)

        let orders = WorkoutTypeOrderService.fetchAll(context: context)
        let strengthOrders = orders.filter { $0.workoutType == "Strength Training" }
        #expect(strengthOrders.count == 1)
    }

    @Test func deletingLastWorkoutRemovesOrder() throws {
        let context = try makeTestContext()
        let w = Workout(name: "Morning Yoga", workoutType: "Yoga")
        context.insert(w)
        try context.save()
        WorkoutTypeOrderService.ensureOrderExists(for: "Yoga", context: context)

        context.delete(w)
        try context.save()

        WorkoutTypeOrderService.removeOrderIfEmpty(for: "Yoga", context: context)

        let orders = WorkoutTypeOrderService.fetchAll(context: context)
        #expect(orders.isEmpty)
    }

    @Test func deletingNonLastWorkoutKeepsOrder() throws {
        let context = try makeTestContext()
        let w1 = Workout(name: "Yoga 1", workoutType: "Yoga")
        let w2 = Workout(name: "Yoga 2", workoutType: "Yoga")
        context.insert(w1)
        context.insert(w2)
        try context.save()
        WorkoutTypeOrderService.ensureOrderExists(for: "Yoga", context: context)

        context.delete(w1)
        try context.save()

        WorkoutTypeOrderService.removeOrderIfEmpty(for: "Yoga", context: context)

        let orders = WorkoutTypeOrderService.fetchAll(context: context)
        #expect(orders.count == 1)
        #expect(orders.first?.workoutType == "Yoga")
    }

    @Test func toggleExpandedFlipsFalseToTrue() throws {
        let context = try makeTestContext()
        let w = Workout(name: "Run", workoutType: "Cardio")
        context.insert(w)
        try context.save()
        WorkoutTypeOrderService.ensureOrderExists(for: "Cardio", context: context)

        WorkoutTypeOrderService.toggleExpanded(for: "Cardio", context: context)

        let order = WorkoutTypeOrderService.fetch(for: "Cardio", context: context)
        #expect(order?.isExpanded == true)
    }

    @Test func toggleExpandedFlipsTrueToFalse() throws {
        let context = try makeTestContext()
        let w = Workout(name: "Run", workoutType: "Cardio")
        context.insert(w)
        try context.save()
        WorkoutTypeOrderService.ensureOrderExists(for: "Cardio", context: context)

        // Toggle twice: false → true → false
        WorkoutTypeOrderService.toggleExpanded(for: "Cardio", context: context)
        WorkoutTypeOrderService.toggleExpanded(for: "Cardio", context: context)

        let order = WorkoutTypeOrderService.fetch(for: "Cardio", context: context)
        #expect(order?.isExpanded == false)
    }

    @Test func reorderReindexesSortOrder() throws {
        let context = try makeTestContext()

        // Create three types
        for (i, type) in ["Strength Training", "HIIT", "Yoga"].enumerated() {
            let w = Workout(name: "\(type) workout", workoutType: type)
            context.insert(w)
            try context.save()
            // Manually create order records to control initial sort
            let order = WorkoutTypeOrder(workoutType: type, sortOrder: i)
            context.insert(order)
        }
        try context.save()

        // Reorder to: HIIT (0), Strength Training (1), Yoga (2)
        WorkoutTypeOrderService.reorder(orderedTypes: ["HIIT", "Strength Training", "Yoga"], context: context)

        let orders = WorkoutTypeOrderService.fetchAll(context: context)
        #expect(orders[0].workoutType == "HIIT")
        #expect(orders[0].sortOrder == 0)
        #expect(orders[1].workoutType == "Strength Training")
        #expect(orders[1].sortOrder == 1)
        #expect(orders[2].workoutType == "Yoga")
        #expect(orders[2].sortOrder == 2)
    }

    @Test func fetchAllReturnsSortedByOrder() throws {
        let context = try makeTestContext()

        // Reorder test: create in reverse order
        WorkoutTypeOrderService.reorder(orderedTypes: [], context: context)

        let o1 = WorkoutTypeOrder(workoutType: "Yoga", sortOrder: 2)
        let o2 = WorkoutTypeOrder(workoutType: "HIIT", sortOrder: 0)
        let o3 = WorkoutTypeOrder(workoutType: "Cardio", sortOrder: 1)
        context.insert(o1)
        context.insert(o2)
        context.insert(o3)
        try context.save()

        let orders = WorkoutTypeOrderService.fetchAll(context: context)
        #expect(orders[0].workoutType == "HIIT")
        #expect(orders[1].workoutType == "Cardio")
        #expect(orders[2].workoutType == "Yoga")
    }

    @Test func savingFirstYogaCreatesCorrectOrder() throws {
        let context = try makeTestContext()

        // Pre-existing type
        let w1 = Workout(name: "Push Day", workoutType: "Strength Training")
        context.insert(w1)
        try context.save()
        WorkoutTypeOrderService.ensureOrderExists(for: "Strength Training", context: context)

        // Save first Yoga workout
        let w2 = Workout(name: "Morning Flow", workoutType: "Yoga")
        context.insert(w2)
        try context.save()
        WorkoutTypeOrderService.ensureOrderExists(for: "Yoga", context: context)

        let yogaOrder = WorkoutTypeOrderService.fetch(for: "Yoga", context: context)
        #expect(yogaOrder?.workoutType == "Yoga")
        #expect(yogaOrder?.sortOrder == 1) // max(0) + 1
        #expect(yogaOrder?.isExpanded == false)
    }

    @Test func deletingLastYogaRemovesOrder() throws {
        let context = try makeTestContext()

        let w = Workout(name: "Morning Flow", workoutType: "Yoga")
        context.insert(w)
        try context.save()
        WorkoutTypeOrderService.ensureOrderExists(for: "Yoga", context: context)

        context.delete(w)
        try context.save()
        WorkoutTypeOrderService.removeOrderIfEmpty(for: "Yoga", context: context)

        let yogaOrder = WorkoutTypeOrderService.fetch(for: "Yoga", context: context)
        #expect(yogaOrder == nil)
    }

    @Test func reorderHIITStrengthYogaSetsCorrectIndices() throws {
        let context = try makeTestContext()

        for (i, type) in ["Strength Training", "HIIT", "Yoga"].enumerated() {
            let w = Workout(name: "\(type) workout", workoutType: type)
            context.insert(w)
            let order = WorkoutTypeOrder(workoutType: type, sortOrder: i)
            context.insert(order)
        }
        try context.save()

        WorkoutTypeOrderService.reorder(orderedTypes: ["HIIT", "Strength Training", "Yoga"], context: context)

        let hiit = WorkoutTypeOrderService.fetch(for: "HIIT", context: context)
        let strength = WorkoutTypeOrderService.fetch(for: "Strength Training", context: context)
        let yoga = WorkoutTypeOrderService.fetch(for: "Yoga", context: context)

        #expect(hiit?.sortOrder == 0)
        #expect(strength?.sortOrder == 1)
        #expect(yoga?.sortOrder == 2)
    }

    // MARK: - Sort/Filter Defaults

    @Test func newOrderHasDefaultSortOption() throws {
        let context = try makeTestContext()
        let w = Workout(name: "Run", workoutType: "Cardio")
        context.insert(w)
        try context.save()
        WorkoutTypeOrderService.ensureOrderExists(for: "Cardio", context: context)

        let order = WorkoutTypeOrderService.fetch(for: "Cardio", context: context)
        #expect(order?.activeSortOption == "newestFirst")
    }

    @Test func newOrderHasNilFiltersJSON() throws {
        let context = try makeTestContext()
        let w = Workout(name: "Run", workoutType: "Cardio")
        context.insert(w)
        try context.save()
        WorkoutTypeOrderService.ensureOrderExists(for: "Cardio", context: context)

        let order = WorkoutTypeOrderService.fetch(for: "Cardio", context: context)
        #expect(order?.activeFiltersJSON == nil)
    }

    // MARK: - Sort/Filter Persistence

    @Test func updateSortOptionPersists() throws {
        let context = try makeTestContext()
        let w = Workout(name: "Push Day", workoutType: "Strength Training")
        context.insert(w)
        try context.save()
        WorkoutTypeOrderService.ensureOrderExists(for: "Strength Training", context: context)

        WorkoutTypeOrderService.updateSortOption("oldestFirst", for: "Strength Training", context: context)

        let order = WorkoutTypeOrderService.fetch(for: "Strength Training", context: context)
        #expect(order?.activeSortOption == "oldestFirst")
    }

    @Test func updateFiltersJSONPersists() throws {
        let context = try makeTestContext()
        let w = Workout(name: "Push Day", workoutType: "Strength Training")
        context.insert(w)
        try context.save()
        WorkoutTypeOrderService.ensureOrderExists(for: "Strength Training", context: context)

        let json = "{\"rpeMin\":5,\"rpeMax\":10}"
        WorkoutTypeOrderService.updateFiltersJSON(json, for: "Strength Training", context: context)

        let order = WorkoutTypeOrderService.fetch(for: "Strength Training", context: context)
        #expect(order?.activeFiltersJSON == json)
    }

    @Test func clearSortAndFiltersResetsToDefaults() throws {
        let context = try makeTestContext()
        let w = Workout(name: "Push Day", workoutType: "Strength Training")
        context.insert(w)
        try context.save()
        WorkoutTypeOrderService.ensureOrderExists(for: "Strength Training", context: context)

        // Set non-default values
        WorkoutTypeOrderService.updateSortOption("alphabetical", for: "Strength Training", context: context)
        WorkoutTypeOrderService.updateFiltersJSON("{\"rpeMin\":3}", for: "Strength Training", context: context)

        // Clear
        WorkoutTypeOrderService.clearSortAndFilters(for: "Strength Training", context: context)

        let order = WorkoutTypeOrderService.fetch(for: "Strength Training", context: context)
        #expect(order?.activeSortOption == "newestFirst")
        #expect(order?.activeFiltersJSON == nil)
    }

    @Test func sortFilterStatePersistsPerWorkoutType() throws {
        let context = try makeTestContext()

        // Create two types
        let w1 = Workout(name: "Push Day", workoutType: "Strength Training")
        let w2 = Workout(name: "Run", workoutType: "Cardio")
        context.insert(w1)
        context.insert(w2)
        try context.save()
        WorkoutTypeOrderService.ensureOrderExists(for: "Strength Training", context: context)
        WorkoutTypeOrderService.ensureOrderExists(for: "Cardio", context: context)

        // Set different sort/filter per type
        WorkoutTypeOrderService.updateSortOption("oldestFirst", for: "Strength Training", context: context)
        WorkoutTypeOrderService.updateSortOption("alphabetical", for: "Cardio", context: context)

        let strength = WorkoutTypeOrderService.fetch(for: "Strength Training", context: context)
        let cardio = WorkoutTypeOrderService.fetch(for: "Cardio", context: context)
        #expect(strength?.activeSortOption == "oldestFirst")
        #expect(cardio?.activeSortOption == "alphabetical")
    }
}

// MARK: - WorkoutFilterState Tests

struct WorkoutFilterStateTests {

    @Test func encodeAndDecodeFilterState() {
        var state = WorkoutFilterState()
        state.rpeMin = 5
        state.rpeMax = 8
        state.durationBuckets = ["30to60", "60to90"]

        let json = state.encode()
        #expect(json != nil)

        let decoded = WorkoutFilterState.decode(from: json)
        #expect(decoded.rpeMin == 5)
        #expect(decoded.rpeMax == 8)
        #expect(decoded.durationBuckets == ["30to60", "60to90"])
    }

    @Test func emptyFilterStateEncodesToNil() {
        let state = WorkoutFilterState()
        #expect(state.encode() == nil)
    }

    @Test func decodeFromNilReturnsEmpty() {
        let decoded = WorkoutFilterState.decode(from: nil)
        #expect(!decoded.hasActiveFilters)
    }

    @Test func activeFilterCountTracksCorrectly() {
        var state = WorkoutFilterState()
        #expect(state.activeFilterCount == 0)

        state.dateRangePreset = "last7"
        #expect(state.activeFilterCount == 1)

        state.rpeMin = 3
        #expect(state.activeFilterCount == 2)

        state.durationBuckets = ["under30"]
        #expect(state.activeFilterCount == 3)
    }

    @Test func allTimePresetDoesNotCountAsFilter() {
        var state = WorkoutFilterState()
        state.dateRangePreset = "allTime"
        #expect(state.activeFilterCount == 0)
        #expect(!state.hasActiveFilters)
    }

    @Test func dateRangePresetsReturnCorrectRanges() {
        var state = WorkoutFilterState()

        state.dateRangePreset = "allTime"
        #expect(state.dateRange() == nil)

        state.dateRangePreset = "last7"
        let range = state.dateRange()
        #expect(range != nil)
        let calendar = Calendar.current
        let expectedStart = calendar.date(byAdding: .day, value: -7, to: Date())!
        #expect(abs(range!.start.timeIntervalSince(expectedStart)) < 1.0)
    }

    @Test func customDateRangeOverridesPreset() {
        var state = WorkoutFilterState()
        let start = Calendar.current.date(byAdding: .month, value: -2, to: Date())!
        let end = Date()
        state.customDateStart = start
        state.customDateEnd = end
        state.dateRangePreset = "last7" // Should be ignored when custom dates are set

        let range = state.dateRange()
        #expect(range != nil)
        #expect(abs(range!.start.timeIntervalSince(start)) < 1.0)
    }
}
