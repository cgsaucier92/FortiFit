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

// MARK: - BUG-073: hasEnoughData Threshold Alignment

/// Regression suite for BUG-073. Each chart type asserts that the new
/// `TrendsChartService.hasEnoughData(...)` returns false at the just-below-threshold
/// fixture (the card-empty case the detail view was previously ignoring) and true at
/// the at-threshold fixture. The detail view's per-renderer empty-state gate now calls
/// this function, so a passing card → passing detail and an empty card → empty detail.
@Suite(.serialized)
struct HasEnoughDataThresholdTests {

    // MARK: Strength Tracker — ≥ 2 weighted points for the selected exercise

    @Test func strengthTracker_singlePoint_isEmpty() throws {
        let context = try makeTestContext()
        let workout = Workout(name: "W1", date: Date().addingTimeInterval(-86400 * 3), workoutType: "Strength Training")
        context.insert(workout)
        let set = ExerciseSet(exerciseName: "Arnold Press", sets: 1, reps: 5, weightKg: 22.5, workout: workout)
        context.insert(set)
        try context.save()

        let result = TrendsChartService.hasEnoughData(
            for: "strengthTracker",
            exerciseName: "Arnold Press",
            range: .ninetyDays,
            context: context
        )
        #expect(result == false)
    }

    @Test func strengthTracker_twoPoints_hasEnough() throws {
        let context = try makeTestContext()
        let w1 = Workout(name: "W1", date: Date().addingTimeInterval(-86400 * 10), workoutType: "Strength Training")
        let w2 = Workout(name: "W2", date: Date().addingTimeInterval(-86400 * 3), workoutType: "Strength Training")
        context.insert(w1)
        context.insert(w2)
        context.insert(ExerciseSet(exerciseName: "Arnold Press", sets: 1, reps: 5, weightKg: 22.5, workout: w1))
        context.insert(ExerciseSet(exerciseName: "Arnold Press", sets: 1, reps: 5, weightKg: 25.0, workout: w2))
        try context.save()

        let result = TrendsChartService.hasEnoughData(
            for: "strengthTracker",
            exerciseName: "Arnold Press",
            range: .ninetyDays,
            context: context
        )
        #expect(result == true)
    }

    // MARK: Workout Volume — ≥ 2 qualifying workouts (Strength or HIIT with sets) in range

    @Test func workoutVolume_singleWorkout_isEmpty() throws {
        let context = try makeTestContext()
        let w = Workout(name: "W1", date: Date().addingTimeInterval(-86400 * 3), workoutType: "Strength Training")
        context.insert(w)
        context.insert(ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 80, workout: w))
        try context.save()

        let result = TrendsChartService.hasEnoughData(for: "workoutVolume", range: .ninetyDays, context: context)
        #expect(result == false)
    }

    @Test func workoutVolume_twoWorkouts_hasEnough() throws {
        let context = try makeTestContext()
        let w1 = Workout(name: "W1", date: Date().addingTimeInterval(-86400 * 10), workoutType: "Strength Training")
        let w2 = Workout(name: "W2", date: Date().addingTimeInterval(-86400 * 3), workoutType: "Strength Training")
        context.insert(w1)
        context.insert(w2)
        context.insert(ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 80, workout: w1))
        context.insert(ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 82.5, workout: w2))
        try context.save()

        let result = TrendsChartService.hasEnoughData(for: "workoutVolume", range: .ninetyDays, context: context)
        #expect(result == true)
    }

    // MARK: Personal Records — ≥ 1 exercise with a PR event

    @Test func personalRecords_singleLogNoIncrease_isEmpty() throws {
        let context = try makeTestContext()
        let w = Workout(name: "W1", date: Date().addingTimeInterval(-86400 * 5), workoutType: "Strength Training")
        context.insert(w)
        context.insert(ExerciseSet(exerciseName: "Deadlifts", sets: 1, reps: 1, weightKg: 100, workout: w))
        try context.save()

        let result = TrendsChartService.hasEnoughData(for: "personalRecords", range: .allTime, context: context)
        #expect(result == false)
    }

    @Test func personalRecords_oneWeightIncrease_hasEnough() throws {
        let context = try makeTestContext()
        let w1 = Workout(name: "W1", date: Date().addingTimeInterval(-86400 * 10), workoutType: "Strength Training")
        let w2 = Workout(name: "W2", date: Date().addingTimeInterval(-86400 * 3), workoutType: "Strength Training")
        context.insert(w1)
        context.insert(w2)
        context.insert(ExerciseSet(exerciseName: "Deadlifts", sets: 1, reps: 1, weightKg: 100, workout: w1))
        context.insert(ExerciseSet(exerciseName: "Deadlifts", sets: 1, reps: 1, weightKg: 110, workout: w2))
        try context.save()

        let result = TrendsChartService.hasEnoughData(for: "personalRecords", range: .allTime, context: context)
        #expect(result == true)
    }

    // MARK: Training Load Trend — ≥ 3 days with workouts in last 14 days

    @Test func trainingLoadTrend_twoDaysWithWorkouts_isEmpty() throws {
        let context = try makeTestContext()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for daysAgo in [1, 4] {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            let w = Workout(name: "W\(daysAgo)", date: date, workoutType: "Strength Training", durationMinutes: 45)
            context.insert(w)
        }
        try context.save()

        let result = TrendsChartService.hasEnoughData(for: "trainingLoadTrend", range: .thirtyDays, context: context)
        #expect(result == false)
    }

    @Test func trainingLoadTrend_threeDaysWithWorkouts_hasEnough() throws {
        let context = try makeTestContext()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for daysAgo in [1, 4, 7] {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            let w = Workout(name: "W\(daysAgo)", date: date, workoutType: "Strength Training", durationMinutes: 45)
            context.insert(w)
        }
        try context.save()

        let result = TrendsChartService.hasEnoughData(for: "trainingLoadTrend", range: .thirtyDays, context: context)
        #expect(result == true)
    }

    // MARK: Workout Type Breakdown — total ≥ 2 in range

    @Test func workoutTypeBreakdown_singleWorkout_isEmpty() throws {
        let context = try makeTestContext()
        let w = Workout(name: "W1", date: Date().addingTimeInterval(-86400 * 3), workoutType: "Cardio")
        context.insert(w)
        try context.save()

        let result = TrendsChartService.hasEnoughData(for: "workoutTypeBreakdown", range: .ninetyDays, context: context)
        #expect(result == false)
    }

    @Test func workoutTypeBreakdown_twoWorkouts_hasEnough() throws {
        let context = try makeTestContext()
        let w1 = Workout(name: "W1", date: Date().addingTimeInterval(-86400 * 10), workoutType: "Cardio")
        let w2 = Workout(name: "W2", date: Date().addingTimeInterval(-86400 * 3), workoutType: "Strength Training")
        context.insert(w1)
        context.insert(w2)
        try context.save()

        let result = TrendsChartService.hasEnoughData(for: "workoutTypeBreakdown", range: .ninetyDays, context: context)
        #expect(result == true)
    }

    // MARK: Training Frequency — ≥ 1 *completed* prior week with count > 0

    @Test func trainingFrequency_onlyCurrentWeekHasWorkouts_isEmpty() throws {
        let context = try makeTestContext()
        // A workout earlier in the current ISO week shouldn't satisfy the threshold,
        // because the current week is still in progress.
        let now = Date()
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        let currentWeekStart = now.startOfWeek
        // Place the workout just after the week start (which is guaranteed in-progress).
        let inWeek = calendar.date(byAdding: .hour, value: 6, to: currentWeekStart) ?? currentWeekStart
        let w = Workout(name: "W1", date: inWeek, workoutType: "Strength Training", durationMinutes: 40)
        context.insert(w)
        try context.save()

        let result = TrendsChartService.hasEnoughData(for: "trainingFrequency", range: .eightWeeks, context: context)
        #expect(result == false)
    }

    @Test func trainingFrequency_oneCompletedPriorWeek_hasEnough() throws {
        let context = try makeTestContext()
        let now = Date()
        // Two weeks back guarantees a completed prior week regardless of weekday.
        let priorWeekDate = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now
        let w = Workout(name: "W1", date: priorWeekDate, workoutType: "Strength Training", durationMinutes: 40)
        context.insert(w)
        try context.save()

        let result = TrendsChartService.hasEnoughData(for: "trainingFrequency", range: .eightWeeks, context: context)
        #expect(result == true)
    }

    // MARK: RPE Trend & Session Duration — ≥ 1 completed prior week with data

    @Test func rpeTrend_onlyCurrentWeekRPE_isEmpty() throws {
        let context = try makeTestContext()
        let now = Date()
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        let currentWeekStart = now.startOfWeek
        let inWeek = calendar.date(byAdding: .hour, value: 6, to: currentWeekStart) ?? currentWeekStart
        let w = Workout(name: "W1", date: inWeek, workoutType: "Strength Training", rpe: 7)
        context.insert(w)
        try context.save()

        let result = TrendsChartService.hasEnoughData(for: "rpeTrend", range: .eightWeeks, context: context)
        #expect(result == false)
    }

    @Test func rpeTrend_oneCompletedPriorWeekWithRPE_hasEnough() throws {
        let context = try makeTestContext()
        let priorWeekDate = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let w = Workout(name: "W1", date: priorWeekDate, workoutType: "Strength Training", rpe: 7)
        context.insert(w)
        try context.save()

        let result = TrendsChartService.hasEnoughData(for: "rpeTrend", range: .eightWeeks, context: context)
        #expect(result == true)
    }

    @Test func sessionDuration_oneCompletedPriorWeekWithDuration_hasEnough() throws {
        let context = try makeTestContext()
        let priorWeekDate = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let w = Workout(name: "W1", date: priorWeekDate, workoutType: "Strength Training", durationMinutes: 55)
        context.insert(w)
        try context.save()

        let result = TrendsChartService.hasEnoughData(for: "sessionDuration", range: .eightWeeks, context: context)
        #expect(result == true)
    }

    // MARK: Card-vs-Detail Parity — the exact screenshot scenario from BUG-073

    @Test func cardAndDetailAgreeWhenStrengthHasOnlyOnePoint() throws {
        let context = try makeTestContext()
        // Exactly the screenshot fixture: Arnold Press logged once.
        let workout = Workout(name: "W1", date: Date().addingTimeInterval(-86400 * 3), workoutType: "Strength Training")
        context.insert(workout)
        context.insert(ExerciseSet(exerciseName: "Arnold Press", sets: 1, reps: 5, weightKg: 22.5, workout: workout))
        try context.save()

        // Detail view at each eligible range — all must report empty, mirroring the card.
        for range in DetailTimeRange.eligibleRanges(for: "strengthTracker") {
            let detailEmpty = !TrendsChartService.hasEnoughData(
                for: "strengthTracker",
                exerciseName: "Arnold Press",
                range: range,
                context: context
            )
            #expect(detailEmpty == true, "Detail view should be empty for range \(range.rawValue)")
        }
    }
}

// MARK: - BUG-079: Effort Trend Card Empty-State Parity

/// Regression suite for BUG-079. The compact Effort Trend card on the Trends
/// list was rendering an axes-only chart instead of the empty-state caption when
/// no workouts had `rpe` recorded — diverging from the detail view's behavior.
/// Root cause: `ProgressViewModel.computeRPETrend()` appended a zero-RPE
/// placeholder entry for every week iterated by `forEachRecentWeek`, so
/// `hasRPEData` (which checks "any completed past week exists in cached array")
/// returned true even when no week actually had RPE data. Fix mirrors
/// `computeDurationTrend`'s `guard !weekWorkouts.isEmpty else { return }`.
@Suite(.serialized)
struct EffortTrendCardEmptyStateTests {

    @Test func test_workoutsWithoutRPE_hasRPEDataReturnsFalse() throws {
        let context = try makeTestContext()
        // A workout in a prior completed week, but no RPE recorded.
        let priorWeekDate = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let w = Workout(name: "W1", date: priorWeekDate, workoutType: "Strength Training")
        context.insert(w)
        try context.save()

        let vm = ProgressViewModel()
        vm.loadData(context: context)

        #expect(vm.hasRPEData == false)
        #expect(vm.rpeWeeklyData.isEmpty, "Empty weeks must not be appended as zero-RPE placeholders")
    }

    @Test func test_oneCompletedWeekWithRPE_hasRPEDataReturnsTrue() throws {
        let context = try makeTestContext()
        let priorWeekDate = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let w = Workout(name: "W1", date: priorWeekDate, workoutType: "Strength Training", rpe: 7)
        context.insert(w)
        try context.save()

        let vm = ProgressViewModel()
        vm.loadData(context: context)

        #expect(vm.hasRPEData == true)
        #expect(vm.rpeWeeklyData.contains { $0.averageRPE == 7 })
    }

    @Test func test_cardAndDetailAgreeWhenNoRPEData() throws {
        let context = try makeTestContext()
        // Workouts exist but none have RPE — card and detail must both report empty.
        let priorWeekDate = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let w = Workout(name: "W1", date: priorWeekDate, workoutType: "Strength Training")
        context.insert(w)
        try context.save()

        let vm = ProgressViewModel()
        vm.loadData(context: context)
        let cardEmpty = !vm.hasRPEData

        let detailEmpty = !TrendsChartService.hasEnoughData(
            for: "rpeTrend",
            range: .eightWeeks,
            context: context
        )

        #expect(cardEmpty == true)
        #expect(detailEmpty == true)
        #expect(cardEmpty == detailEmpty, "Card and detail must agree on emptiness")
    }
}

// MARK: - BUG-076 Padded Y-Axis Domain

/// Covers `TrendsChartService.paddedYDomain` — the helper that gives every
/// non-domain-pinned Trends chart top-edge headroom so a steep data jump
/// (e.g. Strength Tracker 20 → 80 lb) plus `.monotone`/`.catmullRom`
/// smoothing can't clip through the plot-frame stroke.
struct PaddedYDomainTests {

    @Test func test_emptyValues_returnsSafeFallback() {
        let domain = TrendsChartService.paddedYDomain(for: [])
        #expect(domain.lowerBound == 0)
        #expect(domain.upperBound > 0, "Empty array must still produce a renderable domain")
    }

    @Test func test_allZeroValues_returnsSafeFallback() {
        let domain = TrendsChartService.paddedYDomain(for: [0, 0, 0])
        #expect(domain.lowerBound == 0)
        #expect(domain.upperBound > 0, "All-zero series must still produce a renderable domain")
    }

    @Test func test_singleValue_givesHeadroomAboveMax() {
        let domain = TrendsChartService.paddedYDomain(for: [80])
        #expect(domain.lowerBound == 0)
        #expect(domain.upperBound > 80, "Single value 80 must leave room above (got \(domain.upperBound))")
    }

    @Test func test_mixedValues_topAtLeastTenPercentAboveMax() {
        // Strength Tracker reproducer: 20 → 80 lb jump.
        let domain = TrendsChartService.paddedYDomain(for: [20, 22, 25, 30, 80])
        let max = 80.0
        #expect(domain.upperBound >= max * 1.10, "Top should be ≥ 10% above max (got \(domain.upperBound))")
        #expect(domain.lowerBound == 0)
    }

    @Test func test_smallValues_topNeverEqualToMax() {
        // Training Frequency reproducer: small integer counts like 1, 2, 3.
        let domain = TrendsChartService.paddedYDomain(for: [1, 2, 3])
        #expect(domain.upperBound > 3.0, "Top must exceed max even for small int-like series")
    }

    @Test func test_customHeadroom_isHonored() {
        let small = TrendsChartService.paddedYDomain(for: [100], headroomFraction: 0.0)
        let large = TrendsChartService.paddedYDomain(for: [100], headroomFraction: 0.5)
        #expect(large.upperBound > small.upperBound, "Larger headroom must yield larger upper bound")
    }
}
