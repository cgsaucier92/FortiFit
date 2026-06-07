import Foundation
import SwiftData

@Observable
final class ProgressViewModel {

    // MARK: - Identifiable Data Types

    struct StrengthPoint: Identifiable {
        let id = UUID()
        let date: Date
        let weight: Double
    }

    struct FrequencyEntry: Identifiable {
        let id = UUID()
        let weekStart: Date
        let count: Int
    }

    struct LoadScoreEntry: Identifiable {
        let id = UUID()
        let date: Date
        let score: Double
    }

    struct RollingAverageEntry: Identifiable {
        let id = UUID()
        let date: Date
        let avg: Double
    }

    struct PRComparison {
        let exerciseName: String
        let currentRecord: Double    // weightKg
        let currentDate: Date
        let previousRecord: Double   // weightKg
        let previousDate: Date
    }

    struct VolumePoint: Identifiable {
        let id = UUID()
        let date: Date
        let volume: Double
    }

    struct RPEWeekEntry: Identifiable {
        let id = UUID()
        let weekStart: Date
        let averageRPE: Double
    }

    struct TypeBreakdownEntry: Identifiable {
        let id = UUID()
        let workoutType: String
        let count: Int
    }

    struct DurationWeekEntry: Identifiable {
        let id = UUID()
        let weekStart: Date
        let averageDuration: Double
    }

    // MARK: - Data
    var allWorkouts: [Workout] = []

    // MARK: - TrendsChart Management
    var charts: [TrendsChart] = []
    var isReorderMode: Bool = false
    var showAddChartMenu: Bool = false

    var addedChartTypes: Set<String> {
        Set(charts.map(\.chartType))
    }

    // MARK: - Strength Tracker
    var availableExercises: [String] = []
    var selectedExercise: String = ""
    var selectedTimeRange: TimeRange = .thirtyDays
    var strengthDataPoints: [StrengthPoint] = []

    // MARK: - Training Frequency
    var weeklyFrequency: [FrequencyEntry] = []

    // MARK: - Training Load Trend
    var dailyLoadScores: [LoadScoreEntry] = []
    var rollingAverage: [RollingAverageEntry] = []

    // MARK: - Personal Records
    var selectedPRExercise: String = ""

    // MARK: - Workout Volume
    var selectedVolumeTimeRange: TimeRange = .thirtyDays
    var volumeDataPoints: [VolumePoint] = []

    // MARK: - RPE Trend
    var rpeWeeklyData: [RPEWeekEntry] = []

    // MARK: - Workout Type Breakdown
    var selectedBreakdownTimeRange: BreakdownTimeRange = .allTime
    var typeBreakdownData: [TypeBreakdownEntry] = []

    // MARK: - Session Duration
    var durationWeeklyData: [DurationWeekEntry] = []

    enum TimeRange: String, CaseIterable {
        case thirtyDays = "30D"
        case sixtyDays = "60D"
        case ninetyDays = "90D"

        var days: Int {
            switch self {
            case .thirtyDays: return 30
            case .sixtyDays: return 60
            case .ninetyDays: return 90
            }
        }
    }

    enum BreakdownTimeRange: String, CaseIterable {
        case thirtyDays = "30D"
        case sixtyDays = "60D"
        case ninetyDays = "90D"
        case allTime = "ALL"

        var days: Int? {
            switch self {
            case .thirtyDays: return 30
            case .sixtyDays: return 60
            case .ninetyDays: return 90
            case .allTime: return nil
            }
        }
    }

    // MARK: - Thresholds

    var hasStrengthData: Bool {
        strengthDataPoints.count >= 2
    }

    var hasFrequencyData: Bool {
        // Need at least 1 full completed week
        let now = Date()
        return weeklyFrequency.contains { entry in
            let weekEnd = Calendar(identifier: .iso8601).date(byAdding: .day, value: 6, to: entry.weekStart) ?? entry.weekStart
            return weekEnd < now.startOfWeek && entry.count > 0
        }
    }

    var hasPRData: Bool {
        !exercisesWithPRs().isEmpty
    }

    var hasVolumeData: Bool {
        volumeDataPoints.count >= 2
    }

    var hasRPEData: Bool {
        let now = Date()
        return rpeWeeklyData.contains { entry in
            let weekEnd = Calendar(identifier: .iso8601).date(byAdding: .day, value: 6, to: entry.weekStart) ?? entry.weekStart
            return weekEnd < now.startOfWeek
        }
    }

    var hasTypeBreakdownData: Bool {
        typeBreakdownData.reduce(0) { $0 + $1.count } >= 2
    }

    var hasDurationData: Bool {
        let now = Date()
        return durationWeeklyData.contains { entry in
            let weekEnd = Calendar(identifier: .iso8601).date(byAdding: .day, value: 6, to: entry.weekStart) ?? entry.weekStart
            return weekEnd < now.startOfWeek
        }
    }

    var hasLoadTrendData: Bool {
        // Need 3 days with at least 1 workout in the last 14 days
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let recentWorkouts = allWorkouts.filter { $0.date >= cutoff }
        let daysWithWorkouts = Set(recentWorkouts.map { Calendar.current.startOfDay(for: $0.date) })
        return daysWithWorkouts.count >= 3
    }

    // MARK: - Actions

    func loadData(context: ModelContext) {
        TrendsChartService.seedDefaultsIfNeeded(context: context)
        charts = TrendsChartService.fetchAll(context: context)

        allWorkouts = WorkoutService.fetchAll(context: context)
        computeAvailableExercises()
        computeStrengthData()
        computeWeeklyFrequency()
        computeDailyLoadTrend()

        let prExercises = exercisesWithPRs()
        if !prExercises.contains(selectedPRExercise) {
            if let saved = UserDefaults.standard.string(forKey: "trendsSelectedPRExercise"),
               prExercises.contains(saved) {
                selectedPRExercise = saved
            } else {
                selectedPRExercise = prExercises.first ?? ""
                UserDefaults.standard.set(selectedPRExercise, forKey: "trendsSelectedPRExercise")
            }
        }

        computeVolumeData()
        computeRPETrend()
        computeTypeBreakdown()
        computeDurationTrend()
    }

    func selectExercise(_ exercise: String) {
        selectedExercise = exercise
        UserDefaults.standard.set(exercise, forKey: "trendsSelectedExercise")
        computeStrengthData()
    }

    func selectTimeRange(_ range: TimeRange) {
        selectedTimeRange = range
        computeStrengthData()
    }

    func selectPRExercise(_ exercise: String) {
        selectedPRExercise = exercise
        UserDefaults.standard.set(exercise, forKey: "trendsSelectedPRExercise")
    }

    func selectVolumeTimeRange(_ range: TimeRange) {
        selectedVolumeTimeRange = range
        computeVolumeData()
    }

    func selectBreakdownTimeRange(_ range: BreakdownTimeRange) {
        selectedBreakdownTimeRange = range
        computeTypeBreakdown()
    }

    // MARK: - Chart Management

    func addChart(chartType: String, context: ModelContext) {
        TrendsChartService.addChart(chartType: chartType, context: context)
        charts = TrendsChartService.fetchAll(context: context)
    }

    func deleteChart(_ chart: TrendsChart, context: ModelContext) {
        TrendsChartService.deleteChart(chart, context: context)
        charts = TrendsChartService.fetchAll(context: context)
    }

    func reorderCharts(orderedTypes: [String], context: ModelContext) {
        TrendsChartService.reorder(orderedTypes: orderedTypes, context: context)
        charts = TrendsChartService.fetchAll(context: context)
    }

    // MARK: - Computation

    private func computeAvailableExercises() {
        var exercises = Set<String>()
        for workout in allWorkouts {
            for set in workout.exerciseSets {
                if set.weightKg != nil {
                    exercises.insert(set.exerciseName)
                }
            }
        }
        availableExercises = exercises.sorted()
        if !availableExercises.contains(selectedExercise) {
            if let saved = UserDefaults.standard.string(forKey: "trendsSelectedExercise"),
               availableExercises.contains(saved) {
                selectedExercise = saved
            } else {
                selectedExercise = availableExercises.first ?? ""
                UserDefaults.standard.set(selectedExercise, forKey: "trendsSelectedExercise")
            }
        }
    }

    private func computeStrengthData() {
        guard !selectedExercise.isEmpty else {
            strengthDataPoints = []
            return
        }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -selectedTimeRange.days, to: Date()) ?? Date()
        let selectedLower = selectedExercise.lowercased()

        var dataPoints: [StrengthPoint] = []
        for workout in allWorkouts.reversed() { // oldest first
            guard workout.date >= cutoffDate else { continue }
            let matchingSets = workout.exerciseSets.filter {
                $0.exerciseName.lowercased() == selectedLower && $0.weightKg != nil
            }
            if let maxWeight = matchingSets.compactMap({ $0.weightKg }).max() {
                let dayDate = Calendar.current.startOfDay(for: workout.date)
                dataPoints.append(StrengthPoint(date: dayDate, weight: maxWeight))
            }
        }
        strengthDataPoints = dataPoints
    }

    private func forEachRecentWeek(_ body: (_ weekStart: Date, _ endOfWeek: Date) -> Void) {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        let currentWeekStart = Date().startOfWeek

        for weeksAgo in (0..<8).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: currentWeekStart),
                  let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else { continue }
            let endOfWeek = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: weekEnd) ?? weekEnd
            body(weekStart, endOfWeek)
        }
    }

    private func computeWeeklyFrequency() {
        var weeks: [FrequencyEntry] = []
        forEachRecentWeek { weekStart, endOfWeek in
            let count = allWorkouts.filter { $0.date >= weekStart && $0.date <= endOfWeek }.count
            weeks.append(FrequencyEntry(weekStart: weekStart, count: count))
        }
        weeklyFrequency = weeks
    }

    private func computeDailyLoadTrend() {
        let calendar = Calendar.current
        let settings = UserSettings.shared
        let today = Date()
        var scores: [LoadScoreEntry] = []

        // Compute 14 days of daily load scores (oldest → newest)
        for daysAgo in (0..<14).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: today)) else { continue }

            // Use current time for today; end-of-day for historical days
            let dayNow: Date
            if daysAgo == 0 {
                dayNow = today
            } else {
                dayNow = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: day) ?? day
            }

            // Workouts in the 10-day window ending at dayNow
            let windowStart = calendar.date(byAdding: .day, value: -10, to: dayNow) ?? dayNow
            let dayWorkouts = allWorkouts.filter { $0.date >= windowStart && $0.date <= dayNow }

            let result = ExerciseLoadService.calculateLoad(
                workouts: dayWorkouts,
                experienceLevel: settings.experienceLevel,
                targetMinutesPerWorkout: settings.targetMinutesPerWorkout,
                now: dayNow
            )
            scores.append(LoadScoreEntry(date: day, score: result.score))
        }
        dailyLoadScores = scores

        // 7-day rolling average (current day + 6 prior days)
        var averages: [RollingAverageEntry] = []
        for i in 0..<scores.count {
            let start = max(0, i - 6)
            let window = scores[start...i]
            let avg = window.map(\.score).reduce(0, +) / Double(window.count)
            averages.append(RollingAverageEntry(date: scores[i].date, avg: avg))
        }
        rollingAverage = averages
    }

    // MARK: - PR Detection

    /// Returns alphabetically sorted exercise names that have at least one genuine PR event.
    /// Excludes bodyweight exercises and exercises with no weight increase.
    func exercisesWithPRs() -> [String] {
        // Group exercise sets by exercise name, chronological
        var exerciseHistory: [String: [(weightKg: Double, date: Date)]] = [:]

        for workout in allWorkouts.reversed() { // oldest-first
            for exerciseSet in workout.exerciseSets {
                guard let weight = exerciseSet.weightKg else { continue }
                let key = exerciseSet.exerciseName
                exerciseHistory[key, default: []].append((weight, workout.date))
            }
        }

        var result: [String] = []
        for (name, history) in exerciseHistory {
            // Walk chronologically, track running max
            var runningMax: Double = 0
            var hasPR = false
            var isFirst = true

            for entry in history {
                if isFirst {
                    runningMax = entry.weightKg
                    isFirst = false
                } else if entry.weightKg > runningMax {
                    hasPR = true
                    runningMax = entry.weightKg
                }
            }
            if hasPR {
                result.append(name)
            }
        }
        return result.sorted()
    }

    /// Returns PR comparison data for the given exercise.
    func prComparison(for exerciseName: String) -> PRComparison? {
        // Collect all sets for this exercise chronologically (oldest first)
        var history: [(weightKg: Double, date: Date)] = []
        for workout in allWorkouts.reversed() { // oldest first
            for exerciseSet in workout.exerciseSets {
                guard let weight = exerciseSet.weightKg,
                      exerciseSet.exerciseName == exerciseName else { continue }
                history.append((weight, workout.date))
            }
        }

        guard !history.isEmpty else { return nil }

        // Walk chronologically tracking PR events
        var runningMax: Double = history[0].weightKg
        var runningMaxDate: Date = history[0].date
        var prEvents: [(record: Double, date: Date, previousRecord: Double, previousDate: Date)] = []

        for i in 1..<history.count {
            if history[i].weightKg > runningMax {
                prEvents.append((
                    record: history[i].weightKg,
                    date: history[i].date,
                    previousRecord: runningMax,
                    previousDate: runningMaxDate
                ))
                runningMax = history[i].weightKg
                runningMaxDate = history[i].date
            }
        }

        guard let latestPR = prEvents.last else { return nil }

        return PRComparison(
            exerciseName: exerciseName,
            currentRecord: latestPR.record,
            currentDate: latestPR.date,
            previousRecord: latestPR.previousRecord,
            previousDate: latestPR.previousDate
        )
    }

    // MARK: - Chart Summaries

    func chartSummary(for chartType: String, context: ModelContext) -> ChartSummary? {
        let exerciseName: String?
        let timeRangeDays: Int?

        switch chartType {
        case "strengthTracker":
            exerciseName = selectedExercise
            timeRangeDays = nil
        case "personalRecords":
            exerciseName = selectedPRExercise
            timeRangeDays = nil
        case "workoutVolume":
            exerciseName = nil
            timeRangeDays = selectedVolumeTimeRange.days
        case "workoutTypeBreakdown":
            exerciseName = nil
            timeRangeDays = selectedBreakdownTimeRange.days
        default:
            exerciseName = nil
            timeRangeDays = nil
        }

        return TrendsChartService.headerSummary(
            for: chartType,
            exerciseName: exerciseName,
            timeRangeDays: timeRangeDays,
            context: context
        )
    }

    // MARK: - Workout Volume Computation

    private func computeVolumeData() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -selectedVolumeTimeRange.days, to: Date()) ?? Date()

        var points: [VolumePoint] = []
        for workout in allWorkouts.reversed() { // oldest first
            guard workout.date >= cutoffDate else { continue }
            guard workout.workoutType == "Strength Training" || workout.workoutType == "HIIT" else { continue }
            guard !workout.exerciseSets.isEmpty else { continue }

            let volume = PowerLevelService.workoutVolume(for: workout)
            points.append(VolumePoint(date: workout.date, volume: volume))
        }
        volumeDataPoints = points
    }

    // MARK: - RPE Trend Computation

    private func computeRPETrend() {
        var weeks: [RPEWeekEntry] = []
        forEachRecentWeek { weekStart, endOfWeek in
            let weekWorkouts = allWorkouts.filter { $0.date >= weekStart && $0.date <= endOfWeek && $0.rpe != nil }
            // BUG-079 — drop empty weeks so `hasRPEData` (and therefore the chart card)
            // matches `TrendsChartService.hasEnoughData(for: "rpeTrend", ...)` used by
            // the detail view. Mirrors `computeDurationTrend`'s identical guard.
            guard !weekWorkouts.isEmpty else { return }
            let avgRPE = Double(weekWorkouts.compactMap(\.rpe).reduce(0, +)) / Double(weekWorkouts.count)
            weeks.append(RPEWeekEntry(weekStart: weekStart, averageRPE: avgRPE))
        }
        rpeWeeklyData = weeks
    }

    // MARK: - Workout Type Breakdown Computation

    private func computeTypeBreakdown() {
        let filteredWorkouts: [Workout]
        if let days = selectedBreakdownTimeRange.days {
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            filteredWorkouts = allWorkouts.filter { $0.date >= cutoff }
        } else {
            filteredWorkouts = allWorkouts
        }

        var counts: [String: Int] = [:]
        for workout in filteredWorkouts {
            counts[workout.workoutType, default: 0] += 1
        }

        typeBreakdownData = counts
            .map { TypeBreakdownEntry(workoutType: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Session Duration Computation

    private func computeDurationTrend() {
        var weeks: [DurationWeekEntry] = []
        forEachRecentWeek { weekStart, endOfWeek in

            let weekWorkouts = allWorkouts.filter { $0.date >= weekStart && $0.date <= endOfWeek && $0.durationMinutes != nil }
            guard !weekWorkouts.isEmpty else { return }

            let avgDuration = Double(weekWorkouts.compactMap(\.durationMinutes).reduce(0, +)) / Double(weekWorkouts.count)
            weeks.append(DurationWeekEntry(weekStart: weekStart, averageDuration: avgDuration))
        }
        durationWeeklyData = weeks
    }
}
