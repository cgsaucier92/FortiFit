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
    static func calculateStreak(context: ModelContext, referenceDate: Date = Date(), target: Int? = nil) -> StreakResult {
        let target = target ?? UserSettings.shared.targetWorkoutsPerWeek

        // Target of 0 = no streak
        guard target > 0 else {
            updateSettings(streak: 0)
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

        updateSettings(streak: streak)
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
}
