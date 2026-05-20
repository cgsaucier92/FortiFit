import Foundation
import SwiftData

struct StreakService {

    enum Tier: String {
        case dormant = "Dormant"
        case building = "Building"
        case committed = "Committed"
        case elite = "Elite"
    }

    struct StreakResult {
        let streak: Int
        let tier: Tier
        let message: String
    }

    /// Calculates the consecutive-week workout streak per the PRD algorithm.
    /// Called on app launch, after each workout save/edit/delete, and after Settings changes.
    static func calculateStreak(context: ModelContext, referenceDate: Date = Date(), target: Int? = nil, writeToSettings: Bool = true) -> StreakResult {
        let target = target ?? UserSettings.shared.targetWorkoutsPerWeek

        // Target of 0 = no streak
        guard target > 0 else {
            if writeToSettings { updateSettings(streak: 0) }
            return StreakResult(streak: 0, tier: .dormant, message: message(for: 0))
        }

        let allWorkouts = WorkoutService.fetchAll(context: context)
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2 // Monday

        let currentWeekStart = referenceDate.startOfWeek

        // Step 1: Walk backward from the most recently completed week
        var streak = 0
        var weekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart)!

        while true {
            let weekEnd = endOfWeek(from: weekStart, calendar: calendar)
            let count = allWorkouts.filter { $0.date >= weekStart && $0.date <= weekEnd }.count

            if count >= target {
                streak += 1
                // Move to prior week
                guard let priorWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) else { break }
                weekStart = priorWeek
            } else {
                break
            }
        }

        // Step 2: Provisional extension for current in-progress week
        let currentWeekEnd = endOfWeek(from: currentWeekStart, calendar: calendar)
        let currentWeekCount = allWorkouts.filter { $0.date >= currentWeekStart && $0.date <= currentWeekEnd }.count
        if currentWeekCount >= target {
            streak += 1
        }

        if writeToSettings { updateSettings(streak: streak) }
        return StreakResult(streak: streak, tier: tier(for: streak), message: message(for: streak))
    }

    // MARK: - Tier Classification

    static func tier(for streak: Int) -> Tier {
        switch streak {
        case 0: return .dormant
        case 1...3: return .building
        case 4...7: return .committed
        default: return .elite
        }
    }

    // MARK: - Motivational Messages

    static func message(for streak: Int) -> String {
        switch streak {
        case 0: return "Hit your weekly target to start a streak."
        case 1: return "One week down. Keep the flame alive."
        case 2: return "Two weeks strong. Building momentum."
        case 3: return "Three weeks in. Consistency is power."
        case 4: return "A full month of hitting your target. Keep it up."
        case 5: return "Five weeks. You're relentless."
        case 6: return "Six weeks. This is who you are now."
        case 7: return "Seven weeks. The flame burns brightly."
        case 8: return "Eight weeks. Entering beast mode."
        case 9: return "Nine weeks. Unstoppable."
        case 10: return "Ten weeks. Double digits. Legendary."
        case 11: return "Eleven weeks. Almost three months strong."
        default: return "Unstoppable."
        }
    }

    // MARK: - Helpers

    private static func endOfWeek(from weekStart: Date, calendar: Calendar) -> Date {
        let end = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
    }

    private static func updateSettings(streak: Int) {
        let settings = UserSettings.shared
        settings.currentStreak = streak
        if streak > settings.longestStreak {
            settings.longestStreak = streak
        }
    }

    // MARK: - Weekly Streak Insights Helpers (Phase 8.8)

    enum HeatmapCellStatus {
        case untracked
        case belowTarget
        case targetMet
        case inProgress
    }

    struct StreakHeatmapCell: Hashable {
        let weekStartDate: Date
        let workoutCount: Int
        let target: Int
        let isCurrentWeek: Bool
        let isUntracked: Bool

        var status: HeatmapCellStatus {
            if isUntracked { return .untracked }
            if isCurrentWeek { return .inProgress }
            return workoutCount >= target ? .targetMet : .belowTarget
        }
    }

    struct ThisWeekProgress {
        let currentCount: Int
        let target: Int
        let daysRemainingThisWeek: Int
    }

    struct StreakHistorySummary {
        let currentStreak: Int
        let longestStreakAllTime: Int
        let totalWeeksLogged: Int
        let unlockedMilestones: [Int]
        let nextUnlockedMilestone: Int?
    }

    /// Milestone marks (in weeks) for the Weekly Streak Insights Sheet milestone shelf.
    static let milestoneMarks: [Int] = [1, 4, 12, 26, 52]

    /// Returns `weeks` heatmap cells, oldest week last (index 0 = current/most-recent week).
    static func fetchHeatmap(context: ModelContext, weeks: Int = 26, referenceDate: Date = Date(), target: Int? = nil) -> [StreakHeatmapCell] {
        let target = target ?? UserSettings.shared.targetWorkoutsPerWeek
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2

        let allWorkouts = WorkoutService.fetchAll(context: context)
        let firstWorkoutDate = allWorkouts.map(\.date).min()

        let currentWeekStart = referenceDate.startOfWeek

        var cells: [StreakHeatmapCell] = []
        for index in 0..<weeks {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -index, to: currentWeekStart) else {
                continue
            }
            let weekEnd = endOfWeek(from: weekStart, calendar: calendar)
            let count = allWorkouts.filter { $0.date >= weekStart && $0.date <= weekEnd }.count
            let isCurrent = index == 0
            let isUntracked: Bool
            if let first = firstWorkoutDate {
                let firstWeekStart = first.startOfWeek
                isUntracked = weekStart < firstWeekStart
            } else {
                // No workouts logged ever — every cell is untracked except current week which renders in-progress
                isUntracked = !isCurrent
            }
            cells.append(StreakHeatmapCell(
                weekStartDate: weekStart,
                workoutCount: count,
                target: target,
                isCurrentWeek: isCurrent,
                isUntracked: isUntracked
            ))
        }
        return cells
    }

    /// Returns the in-progress current-week count, target, and days remaining (0–6).
    static func thisWeekProgress(context: ModelContext, referenceDate: Date = Date(), target: Int? = nil) -> ThisWeekProgress {
        let target = target ?? UserSettings.shared.targetWorkoutsPerWeek
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2

        let weekStart = referenceDate.startOfWeek
        let weekEnd = endOfWeek(from: weekStart, calendar: calendar)
        let workouts = WorkoutService.fetchAll(context: context)
        let count = workouts.filter { $0.date >= weekStart && $0.date <= weekEnd }.count

        let endOfToday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: referenceDate) ?? referenceDate
        let interval = weekEnd.timeIntervalSince(endOfToday)
        let daysRemaining: Int
        if interval <= 0 {
            daysRemaining = 0
        } else {
            daysRemaining = min(max(Int(round(interval / 86400.0)), 0), 6)
        }

        return ThisWeekProgress(currentCount: count, target: target, daysRemainingThisWeek: daysRemaining)
    }

    /// Aggregates current/longest streaks, total qualifying historical weeks, and milestone progress.
    static func historySummary(context: ModelContext, referenceDate: Date = Date(), target: Int? = nil) -> StreakHistorySummary {
        let settings = UserSettings.shared
        let target = target ?? settings.targetWorkoutsPerWeek
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2

        let allWorkouts = WorkoutService.fetchAll(context: context)
        let firstWorkoutDate = allWorkouts.map(\.date).min()
        let currentWeekStart = referenceDate.startOfWeek

        var totalWeeksLogged = 0
        if target > 0, let first = firstWorkoutDate {
            var weekStart = first.startOfWeek
            while weekStart < currentWeekStart {
                let weekEnd = endOfWeek(from: weekStart, calendar: calendar)
                let count = allWorkouts.filter { $0.date >= weekStart && $0.date <= weekEnd }.count
                if count >= target { totalWeeksLogged += 1 }
                guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { break }
                weekStart = next
            }
            // Include current in-progress week if it already meets target
            let currentEnd = endOfWeek(from: currentWeekStart, calendar: calendar)
            let currentCount = allWorkouts.filter { $0.date >= currentWeekStart && $0.date <= currentEnd }.count
            if currentCount >= target { totalWeeksLogged += 1 }
        }

        let current = settings.currentStreak
        let unlocked = milestoneMarks.filter { $0 <= current }
        let next = milestoneMarks.first { $0 > current }

        return StreakHistorySummary(
            currentStreak: current,
            longestStreakAllTime: settings.longestStreak,
            totalWeeksLogged: totalWeeksLogged,
            unlockedMilestones: unlocked,
            nextUnlockedMilestone: next
        )
    }
}
