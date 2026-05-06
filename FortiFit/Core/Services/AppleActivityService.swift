import Foundation
import SwiftData
import UIKit

@MainActor
@Observable
final class AppleActivityService {
    private let client: HealthKitClient
    private let settings = UserSettings.shared

    // From HKActivitySummary (today)
    var moveCalories: Int = 0
    var exerciseMinutes: Int = 0
    var standHours: Int = 0

    // Derived goals (from UserSettings, falling back to defaults)
    var moveGoal: Int { settings.targetMoveCalories ?? AppConstants.ActivityRings.moveDefault }
    var exerciseGoal: Int { settings.targetExerciseMinutes ?? AppConstants.ActivityRings.exerciseDefault }
    var standGoal: Int { settings.targetStandHours ?? AppConstants.ActivityRings.standDefault }

    // Progress (uncapped — can exceed 1.0)
    var moveProgress: Double { moveGoal > 0 ? Double(moveCalories) / Double(moveGoal) : 0 }
    var exerciseProgress: Double { exerciseGoal > 0 ? Double(exerciseMinutes) / Double(exerciseGoal) : 0 }
    var standProgress: Double { standGoal > 0 ? Double(standHours) / Double(standGoal) : 0 }
    var allRingsClosedToday: Bool { moveProgress >= 1.0 && exerciseProgress >= 1.0 && standProgress >= 1.0 }

    // Weekly closure rate (current calendar week)
    var closedAllRingsDayCount: Int = 0
    var weekElapsedDays: Int = 1

    // Workout-side contributions (today's HK-linked workouts)
    var todayMoveContributionFromWorkouts: Int = 0
    var todayExerciseContributionFromWorkouts: Int = 0
    var todayContributingWorkoutNames: [String] = []

    // Watch detection
    var appleWatchDetected: Bool = false

    // Summaries cache for detail sheet
    var cachedSummaries: [ActivitySummarySnapshot] = []

    init(client: HealthKitClient) {
        self.client = client
        setupForegroundObserver()
    }

    // MARK: - Lifecycle

    func startObserving() {
        guard settings.healthKitEnabled else { return }
        client.observeActivitySummaryChanges { [weak self] in
            Task { @MainActor in
                self?.refreshTodaySummary()
            }
        }
    }

    func refresh() {
        refreshTodaySummary()
        Task {
            await refreshWeeklyClosure()
            await refreshWatchDetection()
        }
    }

    func refreshTodaySummary() {
        Task {
            do {
                if let summary = try await client.fetchActivitySummary(for: Date()) {
                    moveCalories = Int(summary.moveCalories.rounded())
                    exerciseMinutes = Int(summary.exerciseMinutes.rounded())
                    standHours = summary.standHours
                } else {
                    moveCalories = 0
                    exerciseMinutes = 0
                    standHours = 0
                }
            } catch {
                moveCalories = 0
                exerciseMinutes = 0
                standHours = 0
            }
        }
    }

    func refreshWorkoutContributions(context: ModelContext) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? Date()

        let predicate = #Predicate<Workout> { workout in
            workout.date >= startOfToday && workout.date < endOfToday && workout.healthKitUUID != nil
        }
        let descriptor = FetchDescriptor<Workout>(predicate: predicate)
        let workouts = (try? context.fetch(descriptor)) ?? []

        var totalMove = 0.0
        var totalExercise = 0
        var names: [String] = []

        for workout in workouts {
            totalMove += workout.activeEnergyKcal ?? 0
            totalExercise += workout.exerciseMinutes ?? 0
            names.append(workout.name)
        }

        todayMoveContributionFromWorkouts = Int(totalMove.rounded())
        todayExerciseContributionFromWorkouts = totalExercise
        todayContributingWorkoutNames = names
    }

    // MARK: - Weekly Closure

    func refreshWeeklyClosure() async {
        let calendar = Calendar.current
        let today = Date()
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else { return }
        let weekStart = weekInterval.start
        weekElapsedDays = calendar.dateComponents([.day], from: weekStart, to: calendar.startOfDay(for: today)).day! + 1

        do {
            let summaries = try await client.fetchActivitySummaries(from: weekStart, to: today)
            cachedSummaries = summaries
            closedAllRingsDayCount = summaries.filter { summary in
                let moveGoalVal = Double(moveGoal)
                let exerciseGoalVal = Double(exerciseGoal)
                let standGoalVal = standGoal
                return summary.moveCalories >= moveGoalVal
                    && summary.exerciseMinutes >= exerciseGoalVal
                    && summary.standHours >= standGoalVal
            }.count
        } catch {
            closedAllRingsDayCount = 0
        }
    }

    // MARK: - Summaries for Detail Sheet

    func fetchSummaries(days: Int) async -> [ActivitySummarySnapshot] {
        let calendar = Calendar.current
        let today = Date()
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }

        do {
            return try await client.fetchActivitySummaries(from: start, to: today)
        } catch {
            return []
        }
    }

    // MARK: - Watch Detection

    func refreshWatchDetection() async {
        do {
            appleWatchDetected = try await client.hasAppleWatchData(within: 7)
        } catch {
            appleWatchDetected = false
        }
    }

    // MARK: - Goal Import

    func importGoalsFromAppleHealth() async {
        do {
            if let summary = try await client.fetchActivitySummary(for: Date()) {
                let moveGoalHK = summary.moveGoal
                let exerciseGoalHK = summary.exerciseGoal
                let standGoalHK = summary.standGoal

                if moveGoalHK > 0 || exerciseGoalHK > 0 || standGoalHK > 0 {
                    settings.targetMoveCalories = moveGoalHK > 0
                        ? snapToIncrement(Int(moveGoalHK.rounded()), increment: Int(AppConstants.ActivityRings.moveIncrement))
                        : AppConstants.ActivityRings.moveDefault
                    settings.targetExerciseMinutes = exerciseGoalHK > 0
                        ? snapToIncrement(Int(exerciseGoalHK.rounded()), increment: Int(AppConstants.ActivityRings.exerciseIncrement))
                        : AppConstants.ActivityRings.exerciseDefault
                    settings.targetStandHours = standGoalHK > 0
                        ? standGoalHK
                        : AppConstants.ActivityRings.standDefault
                } else {
                    setDefaults()
                }
            } else {
                setDefaults()
            }
        } catch {
            setDefaults()
        }
    }

    // MARK: - Widget State

    nonisolated enum WidgetState {
        case connectAppleHealth
        case pairAppleWatch
        case liveRings
    }

    var widgetState: WidgetState {
        if !settings.healthKitEnabled { return .connectAppleHealth }
        if !appleWatchDetected { return .pairAppleWatch }
        return .liveRings
    }

    // MARK: - Private

    private func setDefaults() {
        settings.targetMoveCalories = AppConstants.ActivityRings.moveDefault
        settings.targetExerciseMinutes = AppConstants.ActivityRings.exerciseDefault
        settings.targetStandHours = AppConstants.ActivityRings.standDefault
    }

    private func snapToIncrement(_ value: Int, increment: Int) -> Int {
        guard increment > 0 else { return value }
        return Int((Double(value) / Double(increment)).rounded()) * increment
    }

    private func setupForegroundObserver() {
        guard !CommandLine.arguments.contains("--uitesting") else { return }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }
}
