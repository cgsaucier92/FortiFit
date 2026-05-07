import Foundation
import Observation
import SwiftData

@Observable
final class HomeViewModel {
    // MARK: - Widget Data
    var activeWidgets: [HomeWidget] = []
    var isEditMode: Bool = false
    var showAddWidgetMenu: Bool = false

    // MARK: - Widget Content Data
    var loadResult = ExerciseLoadService.LoadResult(
        score: 0, zone: "Resting", zoneColor: "737373",
        advisory: "No workouts yet this week. Time to begin."
    )
    var streakResult = StreakService.StreakResult(streak: 0, tier: .dormant, message: StreakService.message(for: 0))
    var recentWorkouts: [Workout] = []
    var powerLevelResult = PowerLevelService.PowerLevelResult(
        status: .noData, statusLabel: "", indicator: "",
        indicatorColor: "737373",
        message: "Log Strength Training or HIIT workouts to track your power level."
    )

    // MARK: - Today's Plan Data
    var todaysScheduledWorkouts: [ScheduledWorkout] = []
    /// Plan surface items for today (includes logged-only workouts) — used for green dot logic.
    var todaysPlanSurfaceItems: [PlanCardItem] = []
    private var plannedWorkouts: [ScheduledWorkout] { todaysScheduledWorkouts.filter { $0.status == "planned" } }
    var currentPlannedWorkout: ScheduledWorkout? { plannedWorkouts.first }
    var additionalPlannedCount: Int { max(plannedWorkouts.count - 1, 0) }
    var todaysPlannedDotCount: Int { plannedWorkouts.count }
    /// Green dots: completed scheduled workouts + logged-only workouts (via Plan surface dedup).
    var todaysCompletedDotCount: Int {
        todaysPlanSurfaceItems.filter { item in
            switch item {
            case .scheduled(let sw): return sw.status == "completed"
            case .loggedOnly: return true
            }
        }.count
    }
    var todaysPlanAllCompleted: Bool { !todaysScheduledWorkouts.isEmpty && todaysScheduledWorkouts.allSatisfy { $0.status == "completed" } }

    /// Set of widget types currently active on the Home screen.
    var activeWidgetTypes: Set<String> {
        Set(activeWidgets.map(\.widgetType))
    }

    // MARK: - Load Data

    func loadData(context: ModelContext) {
        // Seed default widgets on first launch (idempotent)
        HomeWidgetService.seedDefaultWidgets(context: context)

        // Fetch active widgets
        activeWidgets = HomeWidgetService.fetchAll(context: context)

        let settings = UserSettings.shared
        let now = Date()

        // Training Load
        let recentWorkouts10 = WorkoutService.fetchLast10DaysWorkouts(context: context, now: now)
        loadResult = ExerciseLoadService.calculateLoad(
            workouts: recentWorkouts10,
            experienceLevel: settings.experienceLevel,
            targetMinutesPerWorkout: settings.targetMinutesPerWorkout,
            now: now
        )

        // Streak
        streakResult = StreakService.calculateStreak(context: context)

        // Recent 5
        let allWorkouts = WorkoutService.fetchAll(context: context)
        recentWorkouts = Array(allWorkouts.prefix(5))

        // Power Level
        powerLevelResult = PowerLevelService.calculatePowerLevel(context: context, now: now)

        // Today's Plan
        todaysScheduledWorkouts = PlanService.fetchTodaysScheduledWorkouts(context: context)
        todaysPlanSurfaceItems = PlanService.fetchPlanSurface(for: Date(), context: context)
    }

    // MARK: - Widget Management

    func addWidget(widgetType: String, context: ModelContext) {
        if isEditMode { exitEditMode() }
        HomeWidgetService.addWidget(widgetType: widgetType, context: context)
        activeWidgets = HomeWidgetService.fetchAll(context: context)
    }

    func deleteWidget(_ widget: HomeWidget, context: ModelContext) {
        HomeWidgetService.deleteWidget(widget, context: context)
        activeWidgets = HomeWidgetService.fetchAll(context: context)
    }

    func reorderWidgets(orderedTypes: [String], context: ModelContext) {
        HomeWidgetService.reorder(orderedTypes: orderedTypes, context: context)
        activeWidgets = HomeWidgetService.fetchAll(context: context)
    }

    func exitEditMode() {
        isEditMode = false
    }
}
