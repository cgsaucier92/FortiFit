import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// Helper to create an in-memory SwiftData context that includes TrendsChart.
private func makeTestContext() throws -> ModelContext {
    let schema = Schema([
        Workout.self, ExerciseSet.self, Goal.self,
        WorkoutTypeOrder.self, HomeWidget.self,
        WorkoutTemplate.self, TemplateExerciseSet.self,
        TrendsChart.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

// MARK: - TrendsChart Model Tests

struct TrendsChartModelTests {

    @Test func createAndRetrieveTrendsChart() throws {
        let context = try makeTestContext()
        let chart = TrendsChart(chartType: "strengthTracker", sortOrder: 0)
        context.insert(chart)
        try context.save()

        let descriptor = FetchDescriptor<TrendsChart>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.chartType == "strengthTracker")
        #expect(results.first?.sortOrder == 0)
    }

    @Test func updateTrendsChartSortOrder() throws {
        let context = try makeTestContext()
        let chart = TrendsChart(chartType: "trainingFrequency", sortOrder: 0)
        context.insert(chart)
        try context.save()

        chart.sortOrder = 5
        try context.save()

        let descriptor = FetchDescriptor<TrendsChart>()
        let results = try context.fetch(descriptor)
        #expect(results.first?.sortOrder == 5)
    }

    @Test func deleteTrendsChart() throws {
        let context = try makeTestContext()
        let chart = TrendsChart(chartType: "personalRecords", sortOrder: 0)
        context.insert(chart)
        try context.save()

        context.delete(chart)
        try context.save()

        let descriptor = FetchDescriptor<TrendsChart>()
        let results = try context.fetch(descriptor)
        #expect(results.isEmpty)
    }

    @Test func deletedChartNotReturnedByFetch() throws {
        let context = try makeTestContext()
        let chart1 = TrendsChart(chartType: "strengthTracker", sortOrder: 0)
        let chart2 = TrendsChart(chartType: "trainingFrequency", sortOrder: 1)
        context.insert(chart1)
        context.insert(chart2)
        try context.save()

        context.delete(chart1)
        try context.save()

        let descriptor = FetchDescriptor<TrendsChart>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.chartType == "trainingFrequency")
    }

    @Test func duplicateChartTypePreventedByService() throws {
        let context = try makeTestContext()
        TrendsChartService.addChart(chartType: "strengthTracker", context: context)
        TrendsChartService.addChart(chartType: "strengthTracker", context: context)

        let charts = TrendsChartService.fetchAll(context: context)
        let strengthCharts = charts.filter { $0.chartType == "strengthTracker" }
        #expect(strengthCharts.count == 1)
    }

    @Test func multipleChartTypesFetchedSortedBySortOrder() throws {
        let context = try makeTestContext()
        // Insert in reverse order
        context.insert(TrendsChart(chartType: "trainingLoadTrend", sortOrder: 3))
        context.insert(TrendsChart(chartType: "strengthTracker", sortOrder: 0))
        context.insert(TrendsChart(chartType: "personalRecords", sortOrder: 2))
        context.insert(TrendsChart(chartType: "trainingFrequency", sortOrder: 1))
        try context.save()

        let charts = TrendsChartService.fetchAll(context: context)
        #expect(charts.count == 4)
        #expect(charts[0].chartType == "strengthTracker")
        #expect(charts[1].chartType == "trainingFrequency")
        #expect(charts[2].chartType == "personalRecords")
        #expect(charts[3].chartType == "trainingLoadTrend")
    }
}

// MARK: - TrendsChartService Tests

@Suite(.serialized)
struct TrendsChartServiceTests {

    // MARK: - Seeding

    @Test func seedDefaultChartsCreates4Records() throws {
        let context = try makeTestContext()
        // Reset seeding flag for a clean test
        UserSettings.shared.hasSeededDefaultTrendsCharts = false

        TrendsChartService.seedDefaultsIfNeeded(context: context)

        let charts = TrendsChartService.fetchAll(context: context)
        #expect(charts.count == 4)
        #expect(charts[0].chartType == "strengthTracker")
        #expect(charts[0].sortOrder == 0)
        #expect(charts[1].chartType == "trainingFrequency")
        #expect(charts[1].sortOrder == 1)
        #expect(charts[2].chartType == "personalRecords")
        #expect(charts[2].sortOrder == 2)
        #expect(charts[3].chartType == "trainingLoadTrend")
        #expect(charts[3].sortOrder == 3)

        // Clean up
        UserSettings.shared.hasSeededDefaultTrendsCharts = false
    }

    @Test func seedDefaultChartsSetsFlag() throws {
        let context = try makeTestContext()
        UserSettings.shared.hasSeededDefaultTrendsCharts = false

        TrendsChartService.seedDefaultsIfNeeded(context: context)

        #expect(UserSettings.shared.hasSeededDefaultTrendsCharts == true)

        // Clean up
        UserSettings.shared.hasSeededDefaultTrendsCharts = false
    }

    @Test func seedDefaultChartsNoReseedOnSubsequentCalls() throws {
        let context = try makeTestContext()
        UserSettings.shared.hasSeededDefaultTrendsCharts = false

        TrendsChartService.seedDefaultsIfNeeded(context: context)
        TrendsChartService.seedDefaultsIfNeeded(context: context)

        let charts = TrendsChartService.fetchAll(context: context)
        #expect(charts.count == 4)

        // Clean up
        UserSettings.shared.hasSeededDefaultTrendsCharts = false
    }

    @Test func noReseedAfterAllChartsDeleted() throws {
        let context = try makeTestContext()
        UserSettings.shared.hasSeededDefaultTrendsCharts = false

        TrendsChartService.seedDefaultsIfNeeded(context: context)

        // Verify flag is set
        #expect(UserSettings.shared.hasSeededDefaultTrendsCharts == true)

        // Delete all charts
        let charts = TrendsChartService.fetchAll(context: context)
        for chart in charts {
            TrendsChartService.deleteChart(chart, context: context)
        }
        #expect(TrendsChartService.fetchAll(context: context).isEmpty)

        // Flag should still be true after deletion
        #expect(UserSettings.shared.hasSeededDefaultTrendsCharts == true)

        // Attempt re-seed — flag is still true, so it should not re-seed
        TrendsChartService.seedDefaultsIfNeeded(context: context)
        let remaining = TrendsChartService.fetchAll(context: context)
        #expect(remaining.isEmpty)

        // Clean up
        UserSettings.shared.hasSeededDefaultTrendsCharts = false
    }

    // MARK: - Add

    @Test func addChartAssignsMaxSortOrderPlusOne() throws {
        let context = try makeTestContext()
        context.insert(TrendsChart(chartType: "strengthTracker", sortOrder: 0))
        context.insert(TrendsChart(chartType: "trainingFrequency", sortOrder: 1))
        try context.save()

        TrendsChartService.addChart(chartType: "personalRecords", context: context)

        let charts = TrendsChartService.fetchAll(context: context)
        let added = charts.first(where: { $0.chartType == "personalRecords" })
        #expect(added?.sortOrder == 2)
    }

    @Test func addChartRejectsDuplicate() throws {
        let context = try makeTestContext()
        TrendsChartService.addChart(chartType: "rpeTrend", context: context)
        TrendsChartService.addChart(chartType: "rpeTrend", context: context)

        let charts = TrendsChartService.fetchAll(context: context)
        let rpeCharts = charts.filter { $0.chartType == "rpeTrend" }
        #expect(rpeCharts.count == 1)
    }

    @Test func addChartToEmptyListGetsSortOrder0() throws {
        let context = try makeTestContext()
        TrendsChartService.addChart(chartType: "workoutVolume", context: context)

        let charts = TrendsChartService.fetchAll(context: context)
        #expect(charts.count == 1)
        #expect(charts[0].sortOrder == 0)
    }

    // MARK: - Delete

    @Test func deleteChartRemovesRecord() throws {
        let context = try makeTestContext()
        let chart = TrendsChart(chartType: "strengthTracker", sortOrder: 0)
        context.insert(chart)
        try context.save()

        TrendsChartService.deleteChart(chart, context: context)

        let charts = TrendsChartService.fetchAll(context: context)
        #expect(charts.isEmpty)
    }

    @Test func deleteChartReindexesSortOrder() throws {
        let context = try makeTestContext()
        context.insert(TrendsChart(chartType: "strengthTracker", sortOrder: 0))
        context.insert(TrendsChart(chartType: "trainingFrequency", sortOrder: 1))
        context.insert(TrendsChart(chartType: "personalRecords", sortOrder: 2))
        try context.save()

        // Delete the middle chart
        let middle = TrendsChartService.fetch(for: "trainingFrequency", context: context)!
        TrendsChartService.deleteChart(middle, context: context)

        let charts = TrendsChartService.fetchAll(context: context)
        #expect(charts.count == 2)
        #expect(charts[0].chartType == "strengthTracker")
        #expect(charts[0].sortOrder == 0)
        #expect(charts[1].chartType == "personalRecords")
        #expect(charts[1].sortOrder == 1)
    }

    @Test func deleteChartDoesNotAffectWorkoutData() throws {
        let context = try makeTestContext()

        // Create a workout
        let workout = Workout(
            name: "Test Workout",
            workoutType: "Strength Training",
            rpe: 7,
            durationMinutes: 60
        )
        context.insert(workout)
        let exerciseSet = ExerciseSet(
            exerciseName: "Bench Press",
            sets: 3,
            reps: 10,
            weightKg: 80.0,
            workout: workout
        )
        context.insert(exerciseSet)

        // Create and delete a chart
        let chart = TrendsChart(chartType: "strengthTracker", sortOrder: 0)
        context.insert(chart)
        try context.save()

        TrendsChartService.deleteChart(chart, context: context)

        // Verify workout data is intact
        let workouts = WorkoutService.fetchAll(context: context)
        #expect(workouts.count == 1)
        #expect(workouts.first?.exerciseSets.count == 1)
    }

    // MARK: - Reorder

    @Test func reorderReindexesSortValues() throws {
        let context = try makeTestContext()
        context.insert(TrendsChart(chartType: "strengthTracker", sortOrder: 0))
        context.insert(TrendsChart(chartType: "trainingFrequency", sortOrder: 1))
        context.insert(TrendsChart(chartType: "personalRecords", sortOrder: 2))
        try context.save()

        // Reorder: personalRecords first, then strengthTracker, then trainingFrequency
        TrendsChartService.reorder(
            orderedTypes: ["personalRecords", "strengthTracker", "trainingFrequency"],
            context: context
        )

        let charts = TrendsChartService.fetchAll(context: context)
        #expect(charts[0].chartType == "personalRecords")
        #expect(charts[0].sortOrder == 0)
        #expect(charts[1].chartType == "strengthTracker")
        #expect(charts[1].sortOrder == 1)
        #expect(charts[2].chartType == "trainingFrequency")
        #expect(charts[2].sortOrder == 2)
    }

    @Test func reorderFetchReturnNewOrder() throws {
        let context = try makeTestContext()
        context.insert(TrendsChart(chartType: "strengthTracker", sortOrder: 0))
        context.insert(TrendsChart(chartType: "trainingFrequency", sortOrder: 1))
        context.insert(TrendsChart(chartType: "personalRecords", sortOrder: 2))
        context.insert(TrendsChart(chartType: "trainingLoadTrend", sortOrder: 3))
        try context.save()

        TrendsChartService.reorder(
            orderedTypes: ["trainingLoadTrend", "personalRecords", "trainingFrequency", "strengthTracker"],
            context: context
        )

        let charts = TrendsChartService.fetchAll(context: context)
        #expect(charts.map(\.chartType) == ["trainingLoadTrend", "personalRecords", "trainingFrequency", "strengthTracker"])
    }
}

// MARK: - AppConstants Chart Type Tests

struct AppConstantsChartTypeTests {

    @Test func trendsChartTypesContains8Types() {
        #expect(AppConstants.trendsChartTypes.count == 8)
        #expect(AppConstants.trendsChartTypes.contains("strengthTracker"))
        #expect(AppConstants.trendsChartTypes.contains("trainingFrequency"))
        #expect(AppConstants.trendsChartTypes.contains("personalRecords"))
        #expect(AppConstants.trendsChartTypes.contains("trainingLoadTrend"))
        #expect(AppConstants.trendsChartTypes.contains("workoutVolume"))
        #expect(AppConstants.trendsChartTypes.contains("rpeTrend"))
        #expect(AppConstants.trendsChartTypes.contains("workoutTypeBreakdown"))
        #expect(AppConstants.trendsChartTypes.contains("sessionDuration"))
    }

    @Test func defaultTrendsChartsContains4Entries() {
        #expect(AppConstants.defaultTrendsCharts.count == 4)
        #expect(AppConstants.defaultTrendsCharts == [
            "strengthTracker", "trainingFrequency", "personalRecords", "trainingLoadTrend"
        ])
    }

    @Test func displayNamesDefinedForAll8ChartTypes() {
        for chartType in AppConstants.trendsChartTypes {
            #expect(AppConstants.trendsChartDisplayNames[chartType] != nil,
                    "Missing display name for \(chartType)")
        }
        #expect(AppConstants.trendsChartDisplayNames["strengthTracker"] == "Strength Tracker")
        #expect(AppConstants.trendsChartDisplayNames["trainingFrequency"] == "Training Frequency")
        #expect(AppConstants.trendsChartDisplayNames["personalRecords"] == "Personal Records")
        #expect(AppConstants.trendsChartDisplayNames["trainingLoadTrend"] == "Training Load Trend")
        #expect(AppConstants.trendsChartDisplayNames["workoutVolume"] == "Workout Volume")
        #expect(AppConstants.trendsChartDisplayNames["rpeTrend"] == "Effort Trend")
        #expect(AppConstants.trendsChartDisplayNames["workoutTypeBreakdown"] == "Workout Type Breakdown")
        #expect(AppConstants.trendsChartDisplayNames["sessionDuration"] == "Session Duration")
    }

    @Test func descriptionsDefinedForAll8ChartTypes() {
        for chartType in AppConstants.trendsChartTypes {
            #expect(AppConstants.trendsChartDescriptions[chartType] != nil,
                    "Missing description for \(chartType)")
        }
    }

    @Test func workoutTypeChartColorsDefinedForAll6Types() {
        for workoutType in AppConstants.workoutTypes {
            #expect(AppConstants.workoutTypeChartColors[workoutType] != nil,
                    "Missing chart color for \(workoutType)")
        }
    }
}

// MARK: - Chart Info Modal Copy Tests

struct ChartInfoModalCopyTests {

    @Test func eachChartType_hasInfoModalCopy() {
        for chartType in AppConstants.trendsChartTypes {
            let copy = AppConstants.chartInfoModalCopy[chartType]
            #expect(copy != nil, "Missing chartInfoModalCopy for \(chartType)")
            #expect(copy?.title.isEmpty == false, "Empty title for \(chartType)")
            #expect(copy?.intro.isEmpty == false, "Empty intro for \(chartType)")
            #expect((copy?.sections.count ?? 0) >= 1, "No sections for \(chartType)")
        }
    }

    @Test func chartInfoModalCopy_keysMatchChartTypes() {
        let copyKeys = Set(AppConstants.chartInfoModalCopy.keys)
        let chartTypes = Set(AppConstants.trendsChartTypes)
        #expect(copyKeys == chartTypes, "chartInfoModalCopy keys don't match trendsChartTypes")
    }
}

// MARK: - UserSettings Seeding Flag Tests

struct UserSettingsTrendsChartTests {

    @Test func hasSeededDefaultTrendsChartsPropertyExists() {
        // Verify the property exists and is accessible
        let _ = UserSettings.shared.hasSeededDefaultTrendsCharts
        // If this compiles and doesn't crash, the property exists
    }

    @Test func hasSeededDefaultTrendsChartsSetAndGet() {
        // Test that setting the value via the property updates UserDefaults
        let original = UserSettings.shared.hasSeededDefaultTrendsCharts
        UserSettings.shared.hasSeededDefaultTrendsCharts = !original
        #expect(UserSettings.shared.hasSeededDefaultTrendsCharts == !original)
        // Restore
        UserSettings.shared.hasSeededDefaultTrendsCharts = original
    }
}
