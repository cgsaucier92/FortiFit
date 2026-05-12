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

    // MARK: - Header Summary Computation

    static func headerSummary(
        for chartType: String,
        exerciseName: String? = nil,
        timeRangeDays: Int? = nil,
        useLbs: Bool? = nil,
        context: ModelContext
    ) -> ChartSummary? {
        let allWorkouts = WorkoutService.fetchAll(context: context)

        switch chartType {
        case "strengthTracker":
            return strengthTrackerSummary(exerciseName: exerciseName, workouts: allWorkouts, useLbs: useLbs)
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

    private static func strengthTrackerSummary(exerciseName: String?, workouts: [Workout], useLbs: Bool? = nil) -> ChartSummary? {
        guard let name = exerciseName, !name.isEmpty else { return nil }
        let nameLower = name.lowercased()
        let useLbs = useLbs ?? UserSettings.shared.useLbs

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
        var fullWeeks: [Int] = []
        forEachCompletedWeek { weekStart, endOfWeek in
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
        var allRPEs: [Int] = []
        var hasFullWeek = false

        forEachCompletedWeek { weekStart, endOfWeek in
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
        var allDurations: [Int] = []
        var hasFullWeek = false

        forEachCompletedWeek { weekStart, endOfWeek in
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

    // MARK: - Comparison Delta Computation

    static func comparisonDelta(
        for chartType: String,
        exerciseName: String? = nil,
        range: DetailTimeRange,
        context: ModelContext
    ) -> ChartDelta? {
        let summary = headerSummary(for: chartType, exerciseName: exerciseName, timeRangeDays: range.days, context: context)
        guard let summary else { return nil }

        let allWorkouts = WorkoutService.fetchAll(context: context)
        let calendar = Calendar.current
        let now = Date()
        let useLbs = UserSettings.shared.useLbs

        switch chartType {
        case "strengthTracker":
            return strengthTrackerDelta(exerciseName: exerciseName, range: range, workouts: allWorkouts, calendar: calendar, now: now, useLbs: useLbs, summary: summary)
        case "trainingFrequency":
            return trainingFrequencyDelta(range: range, workouts: allWorkouts, calendar: calendar, now: now, summary: summary)
        case "personalRecords":
            return personalRecordsDelta(exerciseName: exerciseName, workouts: allWorkouts, useLbs: useLbs, summary: summary)
        case "trainingLoadTrend":
            return trainingLoadDelta(workouts: allWorkouts, calendar: calendar, now: now, summary: summary, context: context)
        case "workoutVolume":
            return workoutVolumeDelta(range: range, workouts: allWorkouts, calendar: calendar, now: now, useLbs: useLbs, summary: summary)
        case "rpeTrend":
            return rpeTrendDelta(range: range, workouts: allWorkouts, calendar: calendar, now: now, summary: summary)
        case "workoutTypeBreakdown":
            return workoutTypeBreakdownDelta(range: range, workouts: allWorkouts, calendar: calendar, now: now, summary: summary)
        case "sessionDuration":
            return sessionDurationDelta(range: range, workouts: allWorkouts, calendar: calendar, now: now, summary: summary)
        default:
            return nil
        }
    }

    // MARK: - Data Point Fetch (Detail View)

    static func dataPoints(
        for chartType: String,
        exerciseName: String? = nil,
        range: DetailTimeRange,
        context: ModelContext
    ) -> [ChartDataPoint] {
        let eligible = DetailTimeRange.eligibleRanges(for: chartType)
        guard eligible.contains(range) else { return [] }

        let allWorkouts = WorkoutService.fetchAll(context: context)
        let calendar = Calendar.current
        let now = Date()
        let useLbs = UserSettings.shared.useLbs

        switch chartType {
        case "strengthTracker":
            return strengthTrackerPoints(exerciseName: exerciseName, range: range, workouts: allWorkouts, calendar: calendar, now: now, useLbs: useLbs)
        case "trainingFrequency":
            return trainingFrequencyPoints(range: range, workouts: allWorkouts, calendar: calendar, now: now)
        case "trainingLoadTrend":
            return trainingLoadPoints(range: range, workouts: allWorkouts, calendar: calendar, now: now, context: context)
        case "workoutVolume":
            return workoutVolumePoints(range: range, workouts: allWorkouts, calendar: calendar, now: now, useLbs: useLbs)
        case "rpeTrend":
            return rpeTrendPoints(range: range, workouts: allWorkouts, calendar: calendar, now: now)
        case "sessionDuration":
            return sessionDurationPoints(range: range, workouts: allWorkouts, calendar: calendar, now: now)
        default:
            return []
        }
    }

    // MARK: - PR Exercise List

    static func exercisesWithPRs(context: ModelContext) -> [String] {
        let allWorkouts = WorkoutService.fetchAll(context: context)
        var exerciseHistory: [String: [Double]] = [:]

        for workout in allWorkouts.sorted(by: { $0.date < $1.date }) {
            for set in workout.exerciseSets {
                guard let weight = set.weightKg else { continue }
                exerciseHistory[set.exerciseName, default: []].append(weight)
            }
        }

        var result: [String] = []
        for (name, weights) in exerciseHistory {
            guard let first = weights.first else { continue }
            var runningMax = first
            for weight in weights.dropFirst() {
                if weight > runningMax {
                    result.append(name)
                    break
                }
                runningMax = max(runningMax, weight)
            }
        }
        return result.sorted()
    }

    // MARK: - Strength Tracker Exercise List

    static func exercisesWithStrengthData(context: ModelContext) -> [String] {
        let allWorkouts = WorkoutService.fetchAll(context: context)
        var exercises = Set<String>()
        for workout in allWorkouts {
            for set in workout.exerciseSets {
                if set.weightKg != nil {
                    exercises.insert(set.exerciseName)
                }
            }
        }
        return exercises.sorted()
    }

    // MARK: - PR Timeline Fetch

    static func fullPRTimeline(for exerciseName: String, context: ModelContext) -> [PRTimelineEvent] {
        let allWorkouts = WorkoutService.fetchAll(context: context)
        let nameLower = exerciseName.lowercased()

        var history: [(weightKg: Double, date: Date)] = []
        for workout in allWorkouts.sorted(by: { $0.date < $1.date }) {
            for set in workout.exerciseSets {
                guard let weight = set.weightKg,
                      set.exerciseName.lowercased() == nameLower else { continue }
                history.append((weight, workout.date))
            }
        }

        guard !history.isEmpty else { return [] }

        var runningMax = history[0].weightKg
        var events: [PRTimelineEvent] = []

        for i in 1..<history.count {
            if history[i].weightKg > runningMax {
                let delta = history[i].weightKg - runningMax
                events.append(PRTimelineEvent(date: history[i].date, weightKg: history[i].weightKg, deltaKg: delta))
                runningMax = history[i].weightKg
            }
        }

        guard !events.isEmpty else { return [] }
        let baseline = PRTimelineEvent(date: history[0].date, weightKg: history[0].weightKg, deltaKg: history[0].weightKg)
        return [baseline] + events
    }

    // MARK: - Type Breakdown Percentages

    static func breakdownPercentages(range: DetailTimeRange, context: ModelContext) -> [WorkoutTypeBreakdownRow] {
        let allWorkouts = WorkoutService.fetchAll(context: context)
        let filtered: [Workout]
        if let days = range.days {
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            filtered = allWorkouts.filter { $0.date >= cutoff }
        } else {
            filtered = allWorkouts
        }

        guard !filtered.isEmpty else { return [] }

        var counts: [String: Int] = [:]
        var durations: [String: [Int]] = [:]

        for workout in filtered {
            counts[workout.workoutType, default: 0] += 1
            if let dur = workout.durationMinutes {
                durations[workout.workoutType, default: []].append(dur)
            }
        }

        let total = filtered.count
        return counts
            .map { type, count in
                let percent = (Double(count) / Double(total)) * 100.0
                let durs = durations[type] ?? []
                let avgDur: Int? = durs.isEmpty ? nil : Int((Double(durs.reduce(0, +)) / Double(durs.count)).rounded())
                return WorkoutTypeBreakdownRow(type: type, count: count, percent: percent, avgDurationMinutes: avgDur)
            }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Per-Chart Delta Helpers

    private static func strengthTrackerDelta(exerciseName: String?, range: DetailTimeRange, workouts: [Workout], calendar: Calendar, now: Date, useLbs: Bool, summary: ChartSummary) -> ChartDelta {
        guard let name = exerciseName, !name.isEmpty else {
            return ChartDelta(hero: summary.hero, caption: summary.caption, delta: nil, direction: .flat)
        }

        let nameLower = name.lowercased()
        let rangeDays = range.days ?? Int(now.timeIntervalSince(workouts.last?.date ?? now) / 86400) + 1
        let currentStart = calendar.date(byAdding: .day, value: -rangeDays, to: now) ?? now
        let priorEnd = calendar.date(byAdding: .day, value: -1, to: currentStart) ?? currentStart
        let priorStart = calendar.date(byAdding: .day, value: -rangeDays, to: priorEnd) ?? priorEnd

        func latestWeight(in workouts: [Workout], from: Date, to: Date) -> Double? {
            workouts
                .filter { $0.date >= from && $0.date <= to }
                .sorted { $0.date > $1.date }
                .compactMap { workout in
                    workout.exerciseSets
                        .filter { $0.exerciseName.lowercased() == nameLower && $0.weightKg != nil }
                        .compactMap(\.weightKg)
                        .max()
                }
                .first
        }

        let currentWeight = latestWeight(in: workouts, from: currentStart, to: now)
        let priorWeight = latestWeight(in: workouts, from: priorStart, to: priorEnd)

        guard let curr = currentWeight, let prior = priorWeight else {
            return ChartDelta(hero: summary.hero, caption: summary.caption, delta: nil, direction: .flat)
        }

        let diffKg = curr - prior
        let direction: DeltaDirection = diffKg > 0 ? .up : (diffKg < 0 ? .down : .flat)
        let displayDiff = useLbs ? diffKg * UnitConversion.kgToLbsFactor : diffKg
        let unit = useLbs ? "lbs" : "kg"
        let sign = diffKg > 0 ? "+" : ""
        let delta = AppConstants.Trends.deltaString(magnitude: "\(sign)\(Int(displayDiff.rounded())) \(unit)", rangeLabel: range.displayLabel)

        return ChartDelta(hero: summary.hero, caption: summary.caption, delta: delta, direction: direction)
    }

    private static func trainingFrequencyDelta(range: DetailTimeRange, workouts: [Workout], calendar: Calendar, now: Date, summary: ChartSummary) -> ChartDelta {
        let rangeDays = range.days ?? 56
        let weeksCount = rangeDays / 7
        let currentStart = calendar.date(byAdding: .day, value: -rangeDays, to: now) ?? now
        let priorEnd = calendar.date(byAdding: .day, value: -1, to: currentStart) ?? currentStart
        let priorStart = calendar.date(byAdding: .day, value: -rangeDays, to: priorEnd) ?? priorEnd

        func meanPerWeek(from: Date, to: Date) -> Double? {
            let count = workouts.filter { $0.date >= from && $0.date <= to }.count
            return weeksCount > 0 ? Double(count) / Double(weeksCount) : nil
        }

        guard let currMean = meanPerWeek(from: currentStart, to: now),
              let priorMean = meanPerWeek(from: priorStart, to: priorEnd) else {
            return ChartDelta(hero: summary.hero, caption: summary.caption, delta: nil, direction: .flat)
        }

        let diff = currMean - priorMean
        let direction: DeltaDirection = diff > 0.05 ? .up : (diff < -0.05 ? .down : .flat)
        let sign = diff > 0 ? "+" : ""
        let delta = AppConstants.Trends.deltaString(magnitude: "\(sign)\(String(format: "%.1f", diff))", rangeLabel: range.displayLabel)
        return ChartDelta(hero: summary.hero, caption: summary.caption, delta: delta, direction: direction)
    }

    private static func personalRecordsDelta(exerciseName: String?, workouts: [Workout], useLbs: Bool, summary: ChartSummary) -> ChartDelta {
        guard let name = exerciseName, !name.isEmpty else {
            return ChartDelta(hero: summary.hero, caption: summary.caption, delta: nil, direction: .flat)
        }

        let nameLower = name.lowercased()
        var history: [(weightKg: Double, date: Date)] = []
        for workout in workouts.sorted(by: { $0.date < $1.date }) {
            for set in workout.exerciseSets {
                guard let weight = set.weightKg,
                      set.exerciseName.lowercased() == nameLower else { continue }
                history.append((weight, workout.date))
            }
        }

        var runningMax = history.first?.weightKg ?? 0
        var prEvents: [(record: Double, previous: Double)] = []
        for i in 1..<history.count {
            if history[i].weightKg > runningMax {
                prEvents.append((record: history[i].weightKg, previous: runningMax))
                runningMax = history[i].weightKg
            }
        }

        guard let latest = prEvents.last else {
            return ChartDelta(hero: summary.hero, caption: summary.caption, delta: nil, direction: .flat)
        }

        let diffKg = latest.record - latest.previous
        let displayDiff = useLbs ? diffKg * UnitConversion.kgToLbsFactor : diffKg
        let unit = useLbs ? "lbs" : "kg"
        let delta = AppConstants.Trends.deltaString(magnitude: "+\(Int(displayDiff.rounded())) \(unit)", rangeLabel: "PR")
        return ChartDelta(hero: summary.hero, caption: summary.caption, delta: delta, direction: .up)
    }

    private static func trainingLoadDelta(workouts: [Workout], calendar: Calendar, now: Date, summary: ChartSummary, context: ModelContext) -> ChartDelta {
        let settings = UserSettings.shared

        func loadScore(at date: Date) -> Double {
            let windowStart = calendar.date(byAdding: .day, value: -10, to: date) ?? date
            let dayWorkouts = workouts.filter { $0.date >= windowStart && $0.date <= date }
            return ExerciseLoadService.calculateLoad(
                workouts: dayWorkouts,
                experienceLevel: settings.experienceLevel,
                targetMinutesPerWorkout: settings.targetMinutesPerWorkout,
                now: date
            ).score
        }

        let todayScore = loadScore(at: now)
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
            return ChartDelta(hero: summary.hero, caption: summary.caption, delta: nil, direction: .flat)
        }
        let priorScore = loadScore(at: calendar.date(bySettingHour: 23, minute: 59, second: 59, of: sevenDaysAgo) ?? sevenDaysAgo)

        let diff = todayScore - priorScore
        let direction: DeltaDirection = diff > 0.5 ? .up : (diff < -0.5 ? .down : .flat)
        let sign = diff > 0 ? "+" : ""
        let delta = AppConstants.Trends.deltaString(magnitude: "\(sign)\(Int(diff.rounded()))", rangeLabel: "7D")
        return ChartDelta(hero: summary.hero, caption: summary.caption, delta: delta, direction: direction)
    }

    private static func workoutVolumeDelta(range: DetailTimeRange, workouts: [Workout], calendar: Calendar, now: Date, useLbs: Bool, summary: ChartSummary) -> ChartDelta {
        let rangeDays = range.days ?? Int(now.timeIntervalSince(workouts.last?.date ?? now) / 86400) + 1
        let currentStart = calendar.date(byAdding: .day, value: -rangeDays, to: now) ?? now
        let priorEnd = calendar.date(byAdding: .day, value: -1, to: currentStart) ?? currentStart
        let priorStart = calendar.date(byAdding: .day, value: -rangeDays, to: priorEnd) ?? priorEnd

        func meanVolume(from: Date, to: Date) -> Double? {
            let qualifying = workouts.filter {
                $0.date >= from && $0.date <= to &&
                ($0.workoutType == "Strength Training" || $0.workoutType == "HIIT") &&
                !$0.exerciseSets.isEmpty
            }
            guard !qualifying.isEmpty else { return nil }
            let volumes = qualifying.map { PowerLevelService.workoutVolume(for: $0) }
            return volumes.reduce(0, +) / Double(volumes.count)
        }

        guard let currMean = meanVolume(from: currentStart, to: now),
              let priorMean = meanVolume(from: priorStart, to: priorEnd) else {
            return ChartDelta(hero: summary.hero, caption: summary.caption, delta: nil, direction: .flat)
        }

        var diff = currMean - priorMean
        if useLbs { diff *= UnitConversion.kgToLbsFactor }
        let direction: DeltaDirection = diff > 0.5 ? .up : (diff < -0.5 ? .down : .flat)
        let unit = useLbs ? "lbs" : "kg"
        let sign = diff > 0 ? "+" : ""

        let magnitude: String
        let absDiff = abs(diff)
        if absDiff >= 1_000_000 {
            magnitude = "\(sign)\(String(format: "%.1fM", diff / 1_000_000)) \(unit)"
        } else if absDiff >= 1_000 {
            magnitude = "\(sign)\(String(format: "%.1fK", diff / 1_000)) \(unit)"
        } else {
            magnitude = "\(sign)\(Int(diff.rounded())) \(unit)"
        }

        let delta = AppConstants.Trends.deltaString(magnitude: magnitude, rangeLabel: range.displayLabel)
        return ChartDelta(hero: summary.hero, caption: summary.caption, delta: delta, direction: direction)
    }

    private static func rpeTrendDelta(range: DetailTimeRange, workouts: [Workout], calendar: Calendar, now: Date, summary: ChartSummary) -> ChartDelta {
        let rangeDays = range.days ?? 56
        let currentStart = calendar.date(byAdding: .day, value: -rangeDays, to: now) ?? now
        let priorEnd = calendar.date(byAdding: .day, value: -1, to: currentStart) ?? currentStart
        let priorStart = calendar.date(byAdding: .day, value: -rangeDays, to: priorEnd) ?? priorEnd

        func meanRPE(from: Date, to: Date) -> Double? {
            let rpes = workouts.filter { $0.date >= from && $0.date <= to && $0.rpe != nil }.compactMap(\.rpe)
            guard !rpes.isEmpty else { return nil }
            return Double(rpes.reduce(0, +)) / Double(rpes.count)
        }

        guard let currMean = meanRPE(from: currentStart, to: now),
              let priorMean = meanRPE(from: priorStart, to: priorEnd) else {
            return ChartDelta(hero: summary.hero, caption: summary.caption, delta: nil, direction: .flat)
        }

        let diff = currMean - priorMean
        let direction: DeltaDirection = diff > 0.05 ? .up : (diff < -0.05 ? .down : .flat)
        let sign = diff > 0 ? "+" : ""
        let delta = AppConstants.Trends.deltaString(magnitude: "\(sign)\(String(format: "%.1f", diff))", rangeLabel: range.displayLabel)
        return ChartDelta(hero: summary.hero, caption: summary.caption, delta: delta, direction: direction)
    }

    private static func workoutTypeBreakdownDelta(range: DetailTimeRange, workouts: [Workout], calendar: Calendar, now: Date, summary: ChartSummary) -> ChartDelta {
        let rangeDays = range.days ?? Int(now.timeIntervalSince(workouts.last?.date ?? now) / 86400) + 1
        let currentStart = calendar.date(byAdding: .day, value: -rangeDays, to: now) ?? now
        let priorEnd = calendar.date(byAdding: .day, value: -1, to: currentStart) ?? currentStart
        let priorStart = calendar.date(byAdding: .day, value: -rangeDays, to: priorEnd) ?? priorEnd

        let currCount = workouts.filter { $0.date >= currentStart && $0.date <= now }.count
        let priorCount = workouts.filter { $0.date >= priorStart && $0.date <= priorEnd }.count

        let diff = currCount - priorCount
        let direction: DeltaDirection = diff > 0 ? .up : (diff < 0 ? .down : .flat)
        let sign = diff > 0 ? "+" : ""
        let delta = AppConstants.Trends.deltaString(magnitude: "\(sign)\(diff)", rangeLabel: range.displayLabel)
        return ChartDelta(hero: summary.hero, caption: summary.caption, delta: delta, direction: direction)
    }

    private static func sessionDurationDelta(range: DetailTimeRange, workouts: [Workout], calendar: Calendar, now: Date, summary: ChartSummary) -> ChartDelta {
        let rangeDays = range.days ?? 56
        let currentStart = calendar.date(byAdding: .day, value: -rangeDays, to: now) ?? now
        let priorEnd = calendar.date(byAdding: .day, value: -1, to: currentStart) ?? currentStart
        let priorStart = calendar.date(byAdding: .day, value: -rangeDays, to: priorEnd) ?? priorEnd

        func meanDuration(from: Date, to: Date) -> Double? {
            let durs = workouts.filter { $0.date >= from && $0.date <= to && $0.durationMinutes != nil }.compactMap(\.durationMinutes)
            guard !durs.isEmpty else { return nil }
            return Double(durs.reduce(0, +)) / Double(durs.count)
        }

        guard let currMean = meanDuration(from: currentStart, to: now),
              let priorMean = meanDuration(from: priorStart, to: priorEnd) else {
            return ChartDelta(hero: summary.hero, caption: summary.caption, delta: nil, direction: .flat)
        }

        let diff = currMean - priorMean
        let direction: DeltaDirection = diff > 0.5 ? .up : (diff < -0.5 ? .down : .flat)
        let sign = diff > 0 ? "+" : ""
        let delta = AppConstants.Trends.deltaString(magnitude: "\(sign)\(Int(diff.rounded())) min", rangeLabel: range.displayLabel)
        return ChartDelta(hero: summary.hero, caption: summary.caption, delta: delta, direction: direction)
    }

    // MARK: - Data Point Helpers

    private static func strengthTrackerPoints(exerciseName: String?, range: DetailTimeRange, workouts: [Workout], calendar: Calendar, now: Date, useLbs: Bool) -> [ChartDataPoint] {
        guard let name = exerciseName, !name.isEmpty else { return [] }
        let nameLower = name.lowercased()
        let cutoff: Date? = range.days.map { calendar.date(byAdding: .day, value: -$0, to: now) ?? now }

        var points: [ChartDataPoint] = []
        for workout in workouts.sorted(by: { $0.date < $1.date }) {
            if let cutoff, workout.date < cutoff { continue }
            let matchingSets = workout.exerciseSets.filter { $0.exerciseName.lowercased() == nameLower && $0.weightKg != nil }
            guard let maxWeight = matchingSets.compactMap(\.weightKg).max() else { continue }
            let displayWeight = useLbs ? maxWeight * UnitConversion.kgToLbsFactor : maxWeight
            let unit = useLbs ? "lbs" : "kg"
            points.append(ChartDataPoint(x: calendar.startOfDay(for: workout.date), y: displayWeight, label: "\(Int(displayWeight.rounded())) \(unit)"))
        }
        return points
    }

    private static func trainingFrequencyPoints(range: DetailTimeRange, workouts: [Workout], calendar: Calendar, now: Date) -> [ChartDataPoint] {
        let rangeDays = range.days ?? 365 * 10
        let cutoff = calendar.date(byAdding: .day, value: -rangeDays, to: now) ?? now

        var isoCalendar = Calendar(identifier: .iso8601)
        isoCalendar.firstWeekday = 2

        var weekCounts: [(weekStart: Date, count: Int)] = []
        var weekStart = cutoff.startOfWeek
        while weekStart <= now {
            guard let weekEnd = isoCalendar.date(byAdding: .day, value: 6, to: weekStart) else { break }
            let endOfWeek = isoCalendar.date(bySettingHour: 23, minute: 59, second: 59, of: weekEnd) ?? weekEnd
            let count = workouts.filter { $0.date >= weekStart && $0.date <= endOfWeek }.count
            weekCounts.append((weekStart, count))
            guard let next = isoCalendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { break }
            weekStart = next
        }

        return weekCounts.map { entry in
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return ChartDataPoint(x: entry.weekStart, y: Double(entry.count), label: "\(entry.count) sessions")
        }
    }

    private static func trainingLoadPoints(range: DetailTimeRange, workouts: [Workout], calendar: Calendar, now: Date, context: ModelContext) -> [ChartDataPoint] {
        let rangeDays = range.days ?? 30
        let settings = UserSettings.shared
        var points: [ChartDataPoint] = []

        for daysAgo in (0..<rangeDays).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now)) else { continue }
            let dayNow = daysAgo == 0 ? now : (calendar.date(bySettingHour: 23, minute: 59, second: 59, of: day) ?? day)
            let windowStart = calendar.date(byAdding: .day, value: -10, to: dayNow) ?? dayNow
            let dayWorkouts = workouts.filter { $0.date >= windowStart && $0.date <= dayNow }
            let result = ExerciseLoadService.calculateLoad(
                workouts: dayWorkouts,
                experienceLevel: settings.experienceLevel,
                targetMinutesPerWorkout: settings.targetMinutesPerWorkout,
                now: dayNow
            )
            let zone = ExerciseLoadService.classifyZone(score: result.score)
            points.append(ChartDataPoint(x: day, y: result.score, label: "\(Int(result.score.rounded())) — \(zone.zone)"))
        }
        return points
    }

    private static func workoutVolumePoints(range: DetailTimeRange, workouts: [Workout], calendar: Calendar, now: Date, useLbs: Bool) -> [ChartDataPoint] {
        let cutoff: Date? = range.days.map { calendar.date(byAdding: .day, value: -$0, to: now) ?? now }
        let unit = useLbs ? "lbs" : "kg"

        var points: [ChartDataPoint] = []
        for workout in workouts.sorted(by: { $0.date < $1.date }) {
            if let cutoff, workout.date < cutoff { continue }
            guard workout.workoutType == "Strength Training" || workout.workoutType == "HIIT",
                  !workout.exerciseSets.isEmpty else { continue }
            var volume = PowerLevelService.workoutVolume(for: workout)
            if useLbs { volume *= UnitConversion.kgToLbsFactor }
            points.append(ChartDataPoint(x: workout.date, y: volume, label: "\(Int(volume.rounded())) \(unit)"))
        }
        return points
    }

    private static func rpeTrendPoints(range: DetailTimeRange, workouts: [Workout], calendar: Calendar, now: Date) -> [ChartDataPoint] {
        let rangeDays = range.days ?? 365 * 10
        let cutoff = calendar.date(byAdding: .day, value: -rangeDays, to: now) ?? now

        var isoCalendar = Calendar(identifier: .iso8601)
        isoCalendar.firstWeekday = 2

        var weekData: [ChartDataPoint] = []
        var weekStart = cutoff.startOfWeek
        while weekStart <= now {
            guard let weekEnd = isoCalendar.date(byAdding: .day, value: 6, to: weekStart) else { break }
            let endOfWeek = isoCalendar.date(bySettingHour: 23, minute: 59, second: 59, of: weekEnd) ?? weekEnd
            let rpes = workouts.filter { $0.date >= weekStart && $0.date <= endOfWeek && $0.rpe != nil }.compactMap(\.rpe)
            if !rpes.isEmpty {
                let avg = Double(rpes.reduce(0, +)) / Double(rpes.count)
                weekData.append(ChartDataPoint(x: weekStart, y: avg, label: String(format: "%.1f RPE", avg)))
            }
            guard let next = isoCalendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { break }
            weekStart = next
        }
        return weekData
    }

    private static func sessionDurationPoints(range: DetailTimeRange, workouts: [Workout], calendar: Calendar, now: Date) -> [ChartDataPoint] {
        let rangeDays = range.days ?? 365 * 10
        let cutoff = calendar.date(byAdding: .day, value: -rangeDays, to: now) ?? now

        var isoCalendar = Calendar(identifier: .iso8601)
        isoCalendar.firstWeekday = 2

        var weekData: [ChartDataPoint] = []
        var weekStart = cutoff.startOfWeek
        while weekStart <= now {
            guard let weekEnd = isoCalendar.date(byAdding: .day, value: 6, to: weekStart) else { break }
            let endOfWeek = isoCalendar.date(bySettingHour: 23, minute: 59, second: 59, of: weekEnd) ?? weekEnd
            let durs = workouts.filter { $0.date >= weekStart && $0.date <= endOfWeek && $0.durationMinutes != nil }.compactMap(\.durationMinutes)
            if !durs.isEmpty {
                let avg = Double(durs.reduce(0, +)) / Double(durs.count)
                weekData.append(ChartDataPoint(x: weekStart, y: avg, label: "\(Int(avg.rounded())) min"))
            }
            guard let next = isoCalendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { break }
            weekStart = next
        }
        return weekData
    }

    // MARK: - Private

    private static func forEachCompletedWeek(_ body: (_ weekStart: Date, _ endOfWeek: Date) -> Void) {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        let currentWeekStart = Date().startOfWeek

        for weeksAgo in (0..<8).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: currentWeekStart),
                  let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else { continue }
            let endOfWeek = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: weekEnd) ?? weekEnd
            guard endOfWeek < currentWeekStart else { continue }
            body(weekStart, endOfWeek)
        }
    }

    /// Re-indexes sortOrder values to close gaps after a deletion.
    private static func reindexSortOrder(context: ModelContext) {
        let allCharts = fetchAll(context: context)
        for (index, chart) in allCharts.enumerated() {
            chart.sortOrder = index
        }
        try? context.save()
    }
}
