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
            Keys.hasSeededDefaultTrendsCharts: false
        ])

        self.useLbs = defaults.bool(forKey: Keys.useLbs)
        self.useMiles = defaults.bool(forKey: Keys.useMiles)
        self.targetWorkoutsPerWeek = defaults.integer(forKey: Keys.targetWorkoutsPerWeek)
        self.targetMinutesPerWorkout = defaults.integer(forKey: Keys.targetMinutesPerWorkout)
        self.experienceLevel = defaults.integer(forKey: Keys.experienceLevel)
        self.currentStreak = defaults.integer(forKey: Keys.currentStreak)
        self.longestStreak = defaults.integer(forKey: Keys.longestStreak)
        self.hasSeededDefaultTrendsCharts = defaults.bool(forKey: Keys.hasSeededDefaultTrendsCharts)
    }
}
