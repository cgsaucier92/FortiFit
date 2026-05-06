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

    // MARK: - Header Summary Computation (Phase 6.1)

    static func headerSummary(
        for chartType: String,
        exerciseName: String? = nil,
        timeRangeDays: Int? = nil,
        context: ModelContext
    ) -> ChartSummary? {
        let allWorkouts = WorkoutService.fetchAll(context: context)

        switch chartType {
        case "strengthTracker":
            return strengthTrackerSummary(exerciseName: exerciseName, workouts: allWorkouts)
        case "trainingFrequency":
            return trainingFrequencySummary(workouts: allWorkouts)
        case "personalRecords":
            return personalRecordsSummary(exerciseName: exerciseName, workouts: allWorkouts)
        case "trainingLoadTrend":
            return trainingLoadTrendSummary(workouts: allWorkouts)
        case "workoutVolume":
            return workoutVolumeSummary(workouts: allWorkouts, timeRangeDays: timeRangeDays ?? 30)
        case "rpeTrend":
            return rpeTrendSummary(workouts: allWorkouts)
        case "workoutTypeBreakdown":
            return workoutTypeBreakdownSummary(workouts: allWorkouts, timeRangeDays: timeRangeDays)
        case "sessionDuration":
            return sessionDurationSummary(workouts: allWorkouts)
        default:
            return nil
        }
    }

    // MARK: - Per-Chart Summary Computation

    private static func strengthTrackerSummary(exerciseName: String?, workouts: [Workout]) -> ChartSummary? {
        guard let name = exerciseName, !name.isEmpty else { return nil }
        let nameLower = name.lowercased()
        let useLbs = UserSettings.shared.useLbs

        var workoutsWithExercise = 0
        var latestWeight: Double?
        var latestDate = Date.distantPast

        for workout in workouts {
            let matchingSets = workout.exerciseSets.filter {
                $0.exerciseName.lowercased() == nameLower && $0.weightKg != nil
            }
            guard !matchingSets.isEmpty else { continue }
            workoutsWithExercise += 1
            if workout.date > latestDate, let maxW = matchingSets.compactMap(\.weightKg).max() {
                latestDate = workout.date
                latestWeight = maxW
            }
        }

        guard workoutsWithExercise >= 2, let weight = latestWeight else { return nil }

        let hero = UnitConversion.displayWeight(weight, useLbs: useLbs)
        return ChartSummary(hero: hero, caption: AppConstants.Trends.captionLatest)
    }

    private static func trainingFrequencySummary(workouts: [Workout]) -> ChartSummary? {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        let now = Date()
        let currentWeekStart = now.startOfWeek

        var fullWeeks: [Int] = []
        for weeksAgo in (0..<8).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: currentWeekStart) else { continue }
            guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else { continue }
            let endOfWeek = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: weekEnd) ?? weekEnd

            guard endOfWeek < currentWeekStart else { continue }

            let count = workouts.filter { $0.date >= weekStart && $0.date <= endOfWeek }.count
            fullWeeks.append(count)
        }

        guard !fullWeeks.isEmpty, fullWeeks.contains(where: { $0 > 0 }) else { return nil }

        let avg = Double(fullWeeks.reduce(0, +)) / Double(fullWeeks.count)
        let hero = String(format: "%.1f", avg)
        return ChartSummary(hero: hero, caption: AppConstants.Trends.captionAvgLast8Weeks)
    }

    private static func personalRecordsSummary(exerciseName: String?, workouts: [Workout]) -> ChartSummary? {
        guard let name = exerciseName, !name.isEmpty else { return nil }
        let useLbs = UserSettings.shared.useLbs

        var history: [(weightKg: Double, date: Date)] = []
        for workout in workouts.sorted(by: { $0.date < $1.date }) {
            for set in workout.exerciseSets {
                guard let weight = set.weightKg,
                      set.exerciseName.lowercased() == name.lowercased() else { continue }
                history.append((weight, workout.date))
            }
        }

        guard !history.isEmpty else { return nil }

        var runningMax = history[0].weightKg
        var prEvents: [(record: Double, previous: Double)] = []

        for i in 1..<history.count {
            if history[i].weightKg > runningMax {
                prEvents.append((record: history[i].weightKg, previous: runningMax))
                runningMax = history[i].weightKg
            }
        }

        guard let latest = prEvents.last else { return nil }

        let deltaKg = latest.record - latest.previous
        let deltaDisplay: String
        if useLbs {
            let deltaLbs = Int((deltaKg * UnitConversion.kgToLbsFactor).rounded())
            deltaDisplay = "+\(deltaLbs) lbs"
        } else {
            if deltaKg.truncatingRemainder(dividingBy: 1) == 0 {
                deltaDisplay = "+\(Int(deltaKg)) kg"
            } else {
                deltaDisplay = "+\(String(format: "%.1f", deltaKg)) kg"
            }
        }

        return ChartSummary(hero: deltaDisplay, caption: AppConstants.Trends.captionLatestPR)
    }

    private static func trainingLoadTrendSummary(workouts: [Workout]) -> ChartSummary? {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let recentWorkouts = workouts.filter { $0.date >= cutoff }
        let daysWithWorkouts = Set(recentWorkouts.map { calendar.startOfDay(for: $0.date) })

        guard daysWithWorkouts.count >= 3 else { return nil }

        let settings = UserSettings.shared
        let windowStart = calendar.date(byAdding: .day, value: -10, to: Date()) ?? Date()
        let windowWorkouts = workouts.filter { $0.date >= windowStart && $0.date <= Date() }

        let result = ExerciseLoadService.calculateLoad(
            workouts: windowWorkouts,
            experienceLevel: settings.experienceLevel,
            targetMinutesPerWorkout: settings.targetMinutesPerWorkout
        )

        let hero = "\(Int(result.score.rounded()))"
        return ChartSummary(hero: hero, caption: AppConstants.Trends.captionToday)
    }

    private static func workoutVolumeSummary(workouts: [Workout], timeRangeDays: Int) -> ChartSummary? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -timeRangeDays, to: Date()) ?? Date()
        let useLbs = UserSettings.shared.useLbs

        let qualifying = workouts.filter {
            $0.date >= cutoff &&
            ($0.workoutType == "Strength Training" || $0.workoutType == "HIIT") &&
            !$0.exerciseSets.isEmpty
        }

        guard qualifying.count >= 2 else { return nil }

        let volumes = qualifying.map { PowerLevelService.workoutVolume(for: $0) }
        var avgVolume = volumes.reduce(0, +) / Double(volumes.count)

        if useLbs {
            avgVolume = avgVolume * UnitConversion.kgToLbsFactor
        }

        let unit = useLbs ? "lbs" : "kg"
        let hero: String
        if avgVolume >= 1_000_000 {
            hero = String(format: "%.1fM %@", avgVolume / 1_000_000, unit)
        } else if avgVolume >= 1_000 {
            hero = String(format: "%.1fK %@", avgVolume / 1_000, unit)
        } else {
            hero = "\(Int(avgVolume.rounded())) \(unit)"
        }

        return ChartSummary(hero: hero, caption: AppConstants.Trends.captionAvgPerSession)
    }

    private static func rpeTrendSummary(workouts: [Workout]) -> ChartSummary? {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        let now = Date()
        let currentWeekStart = now.startOfWeek

        var allRPEs: [Int] = []
        var hasFullWeek = false

        for weeksAgo in (0..<8).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: currentWeekStart) else { continue }
            guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else { continue }
            let endOfWeek = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: weekEnd) ?? weekEnd

            guard endOfWeek < currentWeekStart else { continue }

            let weekRPEs = workouts
                .filter { $0.date >= weekStart && $0.date <= endOfWeek && $0.rpe != nil }
                .compactMap(\.rpe)

            if !weekRPEs.isEmpty {
                hasFullWeek = true
                allRPEs.append(contentsOf: weekRPEs)
            }
        }

        guard hasFullWeek, !allRPEs.isEmpty else { return nil }

        let avg = Double(allRPEs.reduce(0, +)) / Double(allRPEs.count)
        let hero = String(format: "%.1f", avg)
        return ChartSummary(hero: hero, caption: AppConstants.Trends.captionAvgLast8Weeks)
    }

    private static func workoutTypeBreakdownSummary(workouts: [Workout], timeRangeDays: Int?) -> ChartSummary? {
        let filtered: [Workout]
        if let days = timeRangeDays {
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            filtered = workouts.filter { $0.date >= cutoff }
        } else {
            filtered = workouts
        }

        guard filtered.count >= 2 else { return nil }

        let hero = "\(filtered.count)"
        return ChartSummary(hero: hero, caption: AppConstants.Trends.captionWorkouts)
    }

    private static func sessionDurationSummary(workouts: [Workout]) -> ChartSummary? {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        let now = Date()
        let currentWeekStart = now.startOfWeek

        var allDurations: [Int] = []
        var hasFullWeek = false

        for weeksAgo in (0..<8).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: currentWeekStart) else { continue }
            guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else { continue }
            let endOfWeek = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: weekEnd) ?? weekEnd

            guard endOfWeek < currentWeekStart else { continue }

            let weekDurations = workouts
                .filter { $0.date >= weekStart && $0.date <= endOfWeek && $0.durationMinutes != nil }
                .compactMap(\.durationMinutes)

            if !weekDurations.isEmpty {
                hasFullWeek = true
                allDurations.append(contentsOf: weekDurations)
            }
        }

        guard hasFullWeek, !allDurations.isEmpty else { return nil }

        let avg = Double(allDurations.reduce(0, +)) / Double(allDurations.count)
        let hero = "\(Int(avg.rounded())) min"
        return ChartSummary(hero: hero, caption: AppConstants.Trends.captionAvgPerSession)
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
