import Foundation
import Observation
import SwiftData

// MARK: - Widget Tap Routing (Phase 8.8)

/// Result of resolving a widget tap. Returned by `HomeViewModel.tapRoute(for:isEditMode:)`.
/// The view layer pattern-matches and presents the corresponding sheet or navigation.
enum WidgetDetailRoute: String, Equatable, Identifiable {
    case todaysPlan
    case trainingLoad
    case weeklyStreak
    case powerLevel
    case appleActivityLive
    case appleActivityConnectHK
    case appleActivityPairWatch
    // Phase 11
    case recoveryStatusLive
    case recoveryStatusConnectHK
    case recoveryStatusSleepDenied
    case recoveryStatusNoTracker
    case linkedRecoveryLoad
    case suppressed

    var id: String { rawValue }
}

/// Follow-up modal a detail sheet wants the host (HomeView) to open after the sheet dismisses.
/// Used to avoid stacked sheet-on-sheet by routing via the 0.2s sheet-dismiss-then-modal handoff.
enum WidgetFollowupModal: String, Equatable {
    case trainingLoadSeeInfo
    case trainingLoadSettings
    case weeklyStreakSettings
    case powerLevelSeeInfo
    case activityRingsSeeInfo
    case activityRingsSettings
}

@Observable
final class HomeViewModel {
    // MARK: - Widget Data
    var activeWidgets: [HomeWidget] = []
    var isEditMode: Bool = false
    var showAddWidgetMenu: Bool = false
    var presentedSheet: WidgetDetailRoute?

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
    /// Window comparison intermediates feeding the Power Level widget gauge (Phase 12).
    /// The widget's gauge thumb position derives from `deltaPct`; nil-equivalent
    /// (no-data) is represented by `previous30dAvg == 0`.
    var powerLevelWindowComparison = PowerLevelService.PowerLevelWindowComparison(
        current30dAvg: 0, previous30dAvg: 0, deltaPct: 0
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
        //
        // BUG-067 — route the unlinked-bar score through `computeCurrentScore` with an
        // empty sleep map (every day falls through to `sleepFactor = 1.0`) so the
        // discrete per-day decay shape matches the chip's baseline computation and the
        // linked path. This eliminates a continuous-vs-discrete decay discrepancy that
        // caused the chip's "+N from sleep" delta to disagree with the score change the
        // user actually saw when toggling linking. `linkedAwareLoadResult` in HomeView
        // still overrides this with the sleep-adjusted score when linked.
        let recentWorkouts10 = WorkoutService.fetchLast10DaysWorkouts(context: context, now: now)
        loadResult = ExerciseLoadService.computeCurrentScore(
            workouts: recentWorkouts10,
            sleepSnapshotsByDay: [:],
            targetSleepHours: settings.targetSleepHours,
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
        powerLevelWindowComparison = PowerLevelService.windowComparison(context: context, now: now)

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

    // MARK: - Widget Tap Routing (Phase 8.8)

    /// Resolves the route to take when a widget card is tapped. Returns `.suppressed` in edit mode.
    /// Activity Rings branches on its live/HK-off/Watch-missing state, decided by the caller.
    func tapRoute(
        for widget: HomeWidget,
        isEditMode: Bool,
        appleActivityLive: Bool = false,
        healthKitEnabled: Bool = false,
        recoveryStatusGating: RecoveryStatusGatingState? = nil,
        isLinkedActive: Bool = false
    ) -> WidgetDetailRoute {
        if isEditMode { return .suppressed }
        switch widget.widgetType {
        case "todaysPlan":
            return .todaysPlan
        case "trainingLoad":
            if isLinkedActive { return .linkedRecoveryLoad }
            return .trainingLoad
        case "weekStreak":
            return .weeklyStreak
        case "powerLevel":
            return .powerLevel
        case "appleActivity":
            if appleActivityLive { return .appleActivityLive }
            if !healthKitEnabled { return .appleActivityConnectHK }
            return .appleActivityPairWatch
        case "recoveryStatus":
            if isLinkedActive { return .linkedRecoveryLoad }
            switch recoveryStatusGating ?? .connectAppleHealth {
            case .live:               return .recoveryStatusLive
            case .connectAppleHealth: return .recoveryStatusConnectHK
            case .sleepAccessDenied:  return .recoveryStatusSleepDenied
            case .noSleepTracker:     return .recoveryStatusNoTracker
            }
        default:
            return .suppressed
        }
    }
}
