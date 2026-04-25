import Foundation
import SwiftData

struct TrendsChartService {

    // MARK: - Read

    /// Fetches all TrendsChart records sorted by sortOrder ascending.
    static func fetchAll(context: ModelContext) -> [TrendsChart] {
        let descriptor = FetchDescriptor<TrendsChart>(
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Fetches the TrendsChart for a specific chart type, if it exists.
    static func fetch(for chartType: String, context: ModelContext) -> TrendsChart? {
        let descriptor = FetchDescriptor<TrendsChart>(
            predicate: #Predicate<TrendsChart> { chart in
                chart.chartType == chartType
            }
        )
        return (try? context.fetch(descriptor))?.first
    }

    // MARK: - Seed Defaults

    /// Seeds the default Trends charts on first launch.
    /// Uses `hasSeededDefaultTrendsCharts` flag to prevent re-seeding
    /// after user removes all charts.
    static func seedDefaultsIfNeeded(context: ModelContext) {
        let settings = UserSettings.shared
        guard !settings.hasSeededDefaultTrendsCharts else { return }

        for (index, chartType) in AppConstants.defaultTrendsCharts.enumerated() {
            guard fetch(for: chartType, context: context) == nil else { continue }
            let chart = TrendsChart(chartType: chartType, sortOrder: index)
            context.insert(chart)
        }
        try? context.save()
        settings.hasSeededDefaultTrendsCharts = true
    }

    // MARK: - Add

    /// Adds a chart to the Trends screen at the end of the list.
    /// Does nothing if a chart of this type already exists.
    static func addChart(chartType: String, context: ModelContext) {
        guard fetch(for: chartType, context: context) == nil else { return }

        let allCharts = fetchAll(context: context)
        let maxSort = allCharts.map(\.sortOrder).max() ?? -1

        let chart = TrendsChart(chartType: chartType, sortOrder: maxSort + 1)
        context.insert(chart)
        try? context.save()
    }

    // MARK: - Delete

    /// Deletes a chart and re-indexes remaining sortOrder values.
    static func deleteChart(_ chart: TrendsChart, context: ModelContext) {
        context.delete(chart)
        try? context.save()
        reindexSortOrder(context: context)
    }

    // MARK: - Reorder

    /// Reorders charts. Accepts an array of chartType strings
    /// in the desired order and re-indexes sortOrder values starting from 0.
    static func reorder(orderedTypes: [String], context: ModelContext) {
        let allCharts = fetchAll(context: context)
        let chartMap = Dictionary(uniqueKeysWithValues: allCharts.map { ($0.chartType, $0) })

        for (index, type) in orderedTypes.enumerated() {
            chartMap[type]?.sortOrder = index
        }
        try? context.save()
    }

    // MARK: - Private

    /// Re-indexes sortOrder values to close gaps after a deletion.
    private static func reindexSortOrder(context: ModelContext) {
        let allCharts = fetchAll(context: context)
        for (index, chart) in allCharts.enumerated() {
            chart.sortOrder = index
        }
        try? context.save()
    }
}
