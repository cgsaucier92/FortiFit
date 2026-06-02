import Foundation

@Observable
final class UserSettings {
    static let shared = UserSettings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let useLbs = "useLbs"
        static let useMiles = "useMiles"
        static let targetWorkoutsPerWeek = "targetWorkoutsPerWeek"
        static let targetMinutesPerWorkout = "targetMinutesPerWorkout"
        static let experienceLevel = "experienceLevel"
        static let currentStreak = "currentStreak"
        static let longestStreak = "longestStreak"
        static let hasSeededDefaultTrendsCharts = "hasSeededDefaultTrendsCharts"
        static let healthKitEnabled = "healthKitEnabled"
        static let healthKitAnchor = "healthKitAnchor"
        static let healthKitLastSyncDate = "healthKitLastSyncDate"
        static let hasMigratedSprintsToCardio = "hasMigratedSprintsToCardio"
        static let healthKitAuthorizationRequested = "healthKitAuthorizationRequested"
        static let hasMigratedWorkoutInfoRemoval = "hasMigratedWorkoutInfoRemoval"
        static let hasSeededDefaultHomeWidgets = "hasSeededDefaultHomeWidgets"
        static let targetMoveCalories = "targetMoveCalories"
        static let targetExerciseMinutes = "targetExerciseMinutes"
        static let targetStandHours = "targetStandHours"
        static let syncPlanToAppleWatchEnabled = "syncPlanToAppleWatchEnabled"
        static let hasResetAnchorForPhase87 = "hasResetAnchorForPhase87"
        static let targetSleepHours = "targetSleepHours"
        static let recoveryLoadManuallyUnlinked = "recoveryLoadManuallyUnlinked"
        static let lastSleepCatchUpDate = "lastSleepCatchUpDate"
        static let recoverySheetStressLoadExpanded = "recoverySheetStressLoadExpanded"
        static let recoverySheetPersonalInsightsExpanded = "recoverySheetPersonalInsightsExpanded"
        static let recoverySheetLast3NightsExpanded = "recoverySheetLast3NightsExpanded"
        static let recoverySheetContributingExpanded = "recoverySheetContributingExpanded"
        static let recoverySheetTimeSinceWorkoutExpanded = "recoverySheetTimeSinceWorkoutExpanded"
    }

    var useLbs: Bool {
        didSet { defaults.set(useLbs, forKey: Keys.useLbs) }
    }

    var useMiles: Bool {
        didSet { defaults.set(useMiles, forKey: Keys.useMiles) }
    }

    var targetWorkoutsPerWeek: Int {
        didSet { defaults.set(targetWorkoutsPerWeek, forKey: Keys.targetWorkoutsPerWeek) }
    }

    var targetMinutesPerWorkout: Int {
        didSet { defaults.set(targetMinutesPerWorkout, forKey: Keys.targetMinutesPerWorkout) }
    }

    var experienceLevel: Int {
        didSet { defaults.set(experienceLevel, forKey: Keys.experienceLevel) }
    }

    var currentStreak: Int {
        didSet { defaults.set(currentStreak, forKey: Keys.currentStreak) }
    }

    var longestStreak: Int {
        didSet { defaults.set(longestStreak, forKey: Keys.longestStreak) }
    }

    var hasSeededDefaultTrendsCharts: Bool {
        didSet { defaults.set(hasSeededDefaultTrendsCharts, forKey: Keys.hasSeededDefaultTrendsCharts) }
    }

    var healthKitEnabled: Bool {
        didSet { defaults.set(healthKitEnabled, forKey: Keys.healthKitEnabled) }
    }

    var healthKitAnchor: Data? {
        didSet { defaults.set(healthKitAnchor, forKey: Keys.healthKitAnchor) }
    }

    var healthKitLastSyncDate: Date? {
        didSet { defaults.set(healthKitLastSyncDate, forKey: Keys.healthKitLastSyncDate) }
    }

    var hasMigratedSprintsToCardio: Bool {
        didSet { defaults.set(hasMigratedSprintsToCardio, forKey: Keys.hasMigratedSprintsToCardio) }
    }

    var healthKitAuthorizationRequested: Bool {
        didSet { defaults.set(healthKitAuthorizationRequested, forKey: Keys.healthKitAuthorizationRequested) }
    }

    var hasMigratedWorkoutInfoRemoval: Bool {
        didSet { defaults.set(hasMigratedWorkoutInfoRemoval, forKey: Keys.hasMigratedWorkoutInfoRemoval) }
    }

    var hasSeededDefaultHomeWidgets: Bool {
        didSet { defaults.set(hasSeededDefaultHomeWidgets, forKey: Keys.hasSeededDefaultHomeWidgets) }
    }

    var targetMoveCalories: Int? {
        didSet {
            if let value = targetMoveCalories {
                defaults.set(value, forKey: Keys.targetMoveCalories)
            } else {
                defaults.removeObject(forKey: Keys.targetMoveCalories)
            }
        }
    }

    var targetExerciseMinutes: Int? {
        didSet {
            if let value = targetExerciseMinutes {
                defaults.set(value, forKey: Keys.targetExerciseMinutes)
            } else {
                defaults.removeObject(forKey: Keys.targetExerciseMinutes)
            }
        }
    }

    var targetStandHours: Int? {
        didSet {
            if let value = targetStandHours {
                defaults.set(value, forKey: Keys.targetStandHours)
            } else {
                defaults.removeObject(forKey: Keys.targetStandHours)
            }
        }
    }

    var syncPlanToAppleWatchEnabled: Bool {
        didSet { defaults.set(syncPlanToAppleWatchEnabled, forKey: Keys.syncPlanToAppleWatchEnabled) }
    }

    var hasResetAnchorForPhase87: Bool {
        didSet { defaults.set(hasResetAnchorForPhase87, forKey: Keys.hasResetAnchorForPhase87) }
    }

    var targetSleepHours: Double {
        didSet { defaults.set(targetSleepHours, forKey: Keys.targetSleepHours) }
    }

    var recoveryLoadManuallyUnlinked: Bool {
        didSet { defaults.set(recoveryLoadManuallyUnlinked, forKey: Keys.recoveryLoadManuallyUnlinked) }
    }

    /// Wall-clock timestamp of the last 6pm-cutoff sleep catch-up. Guards the
    /// catch-up trigger so it doesn't fire twice within the same 6pm window.
    /// See HEALTHKIT.md § 21 → Refresh Triggers and SERVICES.md § HealthKitSyncService.
    var lastSleepCatchUpDate: Date? {
        didSet {
            if let value = lastSleepCatchUpDate {
                defaults.set(value, forKey: Keys.lastSleepCatchUpDate)
            } else {
                defaults.removeObject(forKey: Keys.lastSleepCatchUpDate)
            }
        }
    }

    var recoverySheetStressLoadExpanded: Bool {
        didSet { defaults.set(recoverySheetStressLoadExpanded, forKey: Keys.recoverySheetStressLoadExpanded) }
    }

    var recoverySheetPersonalInsightsExpanded: Bool {
        didSet { defaults.set(recoverySheetPersonalInsightsExpanded, forKey: Keys.recoverySheetPersonalInsightsExpanded) }
    }

    var recoverySheetLast3NightsExpanded: Bool {
        didSet { defaults.set(recoverySheetLast3NightsExpanded, forKey: Keys.recoverySheetLast3NightsExpanded) }
    }

    var recoverySheetContributingExpanded: Bool {
        didSet { defaults.set(recoverySheetContributingExpanded, forKey: Keys.recoverySheetContributingExpanded) }
    }

    var recoverySheetTimeSinceWorkoutExpanded: Bool {
        didSet { defaults.set(recoverySheetTimeSinceWorkoutExpanded, forKey: Keys.recoverySheetTimeSinceWorkoutExpanded) }
    }

    private init() {
        // Register defaults for first launch
        defaults.register(defaults: [
            Keys.useLbs: true,
            Keys.useMiles: true,
            Keys.targetWorkoutsPerWeek: 5,
            Keys.targetMinutesPerWorkout: 45,
            Keys.experienceLevel: 0,
            Keys.currentStreak: 0,
            Keys.longestStreak: 0,
            Keys.hasSeededDefaultTrendsCharts: false,
            Keys.healthKitEnabled: false,
            Keys.hasMigratedSprintsToCardio: false,
            Keys.healthKitAuthorizationRequested: false,
            Keys.hasMigratedWorkoutInfoRemoval: false,
            Keys.hasSeededDefaultHomeWidgets: false,
            Keys.syncPlanToAppleWatchEnabled: false,
            Keys.targetSleepHours: 7.0,
            Keys.recoveryLoadManuallyUnlinked: false,
            Keys.recoverySheetStressLoadExpanded: false,
            Keys.recoverySheetPersonalInsightsExpanded: false,
            Keys.recoverySheetLast3NightsExpanded: false,
            Keys.recoverySheetContributingExpanded: false,
            Keys.recoverySheetTimeSinceWorkoutExpanded: false
        ])

        self.useLbs = defaults.bool(forKey: Keys.useLbs)
        self.useMiles = defaults.bool(forKey: Keys.useMiles)
        self.targetWorkoutsPerWeek = defaults.integer(forKey: Keys.targetWorkoutsPerWeek)
        self.targetMinutesPerWorkout = defaults.integer(forKey: Keys.targetMinutesPerWorkout)
        self.experienceLevel = defaults.integer(forKey: Keys.experienceLevel)
        self.currentStreak = defaults.integer(forKey: Keys.currentStreak)
        self.longestStreak = defaults.integer(forKey: Keys.longestStreak)
        self.hasSeededDefaultTrendsCharts = defaults.bool(forKey: Keys.hasSeededDefaultTrendsCharts)
        self.healthKitEnabled = defaults.bool(forKey: Keys.healthKitEnabled)
        self.healthKitAnchor = defaults.data(forKey: Keys.healthKitAnchor)
        self.healthKitLastSyncDate = defaults.object(forKey: Keys.healthKitLastSyncDate) as? Date
        self.hasMigratedSprintsToCardio = defaults.bool(forKey: Keys.hasMigratedSprintsToCardio)
        self.healthKitAuthorizationRequested = defaults.bool(forKey: Keys.healthKitAuthorizationRequested)
        self.hasMigratedWorkoutInfoRemoval = defaults.bool(forKey: Keys.hasMigratedWorkoutInfoRemoval)
        self.hasSeededDefaultHomeWidgets = defaults.bool(forKey: Keys.hasSeededDefaultHomeWidgets)
        self.syncPlanToAppleWatchEnabled = defaults.bool(forKey: Keys.syncPlanToAppleWatchEnabled)
        self.hasResetAnchorForPhase87 = defaults.bool(forKey: Keys.hasResetAnchorForPhase87)
        self.targetMoveCalories = defaults.object(forKey: Keys.targetMoveCalories) as? Int
        self.targetExerciseMinutes = defaults.object(forKey: Keys.targetExerciseMinutes) as? Int
        self.targetStandHours = defaults.object(forKey: Keys.targetStandHours) as? Int
        self.targetSleepHours = defaults.double(forKey: Keys.targetSleepHours)
        self.recoveryLoadManuallyUnlinked = defaults.bool(forKey: Keys.recoveryLoadManuallyUnlinked)
        self.lastSleepCatchUpDate = defaults.object(forKey: Keys.lastSleepCatchUpDate) as? Date
        self.recoverySheetStressLoadExpanded = defaults.bool(forKey: Keys.recoverySheetStressLoadExpanded)
        self.recoverySheetPersonalInsightsExpanded = defaults.bool(forKey: Keys.recoverySheetPersonalInsightsExpanded)
        self.recoverySheetLast3NightsExpanded = defaults.bool(forKey: Keys.recoverySheetLast3NightsExpanded)
        self.recoverySheetContributingExpanded = defaults.bool(forKey: Keys.recoverySheetContributingExpanded)
        self.recoverySheetTimeSinceWorkoutExpanded = defaults.bool(forKey: Keys.recoverySheetTimeSinceWorkoutExpanded)
    }
}
