import Foundation
import SwiftData
@testable import FortiFit

/// Phase 11 Step 7 — end-to-end scenario builder for integration tests that need
/// realistic multi-week histories of sleep + workouts. Composes `Workout`,
/// `DailySleepSnapshot`, and `DailyTrainingLoadSnapshot` records into a SwiftData
/// context in a way that lets a single test exercise the full Phase 11 surface
/// (gating, sleep-adjusted decay, correlation, personal insights) without manually
/// hand-crafting dozens of fixtures.
///
/// All times anchor to 8 AM today so the wake-up-date attribution is deterministic
/// regardless of when the test runs.
@MainActor
enum RealisticUserScenarioBuilder {

    /// A single day in a scenario — what the user slept and (optionally) trained.
    struct Day {
        let dayOffset: Int            // 0 = today, -1 = yesterday, -2 = day before, etc.
        let sleepMinutes: Int         // total asleep minutes (0 = no sleep recorded)
        let workoutType: String?      // nil = rest day
        let workoutRPE: Int?
        let workoutDurationMinutes: Int?

        static func sleep(_ minutes: Int, offset: Int) -> Day {
            Day(dayOffset: offset, sleepMinutes: minutes, workoutType: nil, workoutRPE: nil, workoutDurationMinutes: nil)
        }

        static func sleepAndWorkout(_ minutes: Int, type: String, rpe: Int, durationMinutes: Int, offset: Int) -> Day {
            Day(dayOffset: offset, sleepMinutes: minutes, workoutType: type, workoutRPE: rpe, workoutDurationMinutes: durationMinutes)
        }

        static func rest(offset: Int) -> Day {
            Day(dayOffset: offset, sleepMinutes: 0, workoutType: nil, workoutRPE: nil, workoutDurationMinutes: nil)
        }
    }

    /// Builds a scenario into the given context. Inserts one `DailySleepSnapshot`
    /// per day (where `sleepMinutes > 0`) and one `Workout` per day with a workout.
    /// Returns the inserted entities for test introspection.
    @discardableResult
    static func build(days: [Day], context: ModelContext) throws -> (workouts: [Workout], sleepSnapshots: [DailySleepSnapshot]) {
        let calendar = Calendar.current
        let anchor = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()

        var workouts: [Workout] = []
        var sleepSnapshots: [DailySleepSnapshot] = []

        for day in days {
            let wakeUpDay = calendar.startOfDay(for: calendar.date(byAdding: .day, value: day.dayOffset, to: anchor) ?? anchor)

            if day.sleepMinutes > 0 {
                // Split sleep into the three asleep stages so aggregates look realistic:
                // ~20% deep, ~25% REM, ~55% core.
                let deep = day.sleepMinutes * 20 / 100
                let rem = day.sleepMinutes * 25 / 100
                let core = day.sleepMinutes - deep - rem
                let snap = DailySleepSnapshot(
                    wakeUpDate: wakeUpDay,
                    totalSleepMinutes: day.sleepMinutes,
                    deepSleepMinutes: deep,
                    remSleepMinutes: rem,
                    coreSleepMinutes: core,
                    awakeMinutes: 5,
                    inBedMinutes: day.sleepMinutes + 30,
                    sleepEfficiencyPercent: Int((Double(day.sleepMinutes) / Double(day.sleepMinutes + 30) * 100).rounded()),
                    sourceBundleID: "com.apple.health"
                )
                context.insert(snap)
                sleepSnapshots.append(snap)
            }

            if let type = day.workoutType,
               let rpe = day.workoutRPE,
               let duration = day.workoutDurationMinutes {
                // Workout at noon on the offset day so it isn't filtered out as empty.
                let workoutDate = calendar.date(byAdding: .hour, value: 4, to: wakeUpDay) ?? wakeUpDay // 8 AM + 4h = noon
                let workout = Workout(
                    name: "\(type) Session",
                    date: workoutDate,
                    workoutType: type,
                    rpe: rpe,
                    durationMinutes: duration
                )
                workout.exerciseSets.append(ExerciseSet(
                    exerciseName: "Bench",
                    sets: 4,
                    reps: 5,
                    weightKg: 80
                ))
                context.insert(workout)
                workouts.append(workout)
            }
        }
        try context.save()
        return (workouts, sleepSnapshots)
    }

    // MARK: - Canned scenarios

    /// Two weeks of consistent sleep + workouts. Used to verify the linked composite
    /// produces a meaningful sleep-load correlation reading and personal insights.
    static func twoWeeksConsistentTraining() -> [Day] {
        var days: [Day] = []
        for offset in (1..<14).reversed() {
            let trains = offset % 2 == 0
            if trains {
                days.append(.sleepAndWorkout(7 * 60, type: "Strength Training", rpe: 7, durationMinutes: 60, offset: -offset))
            } else {
                days.append(.sleep(7 * 60, offset: -offset))
            }
        }
        return days
    }

    /// Three weeks of sleep where half the nights fall below target and the score
    /// the user saw on the *following* day was meaningfully higher on short-sleep days.
    /// Exercises `computeSleepLoadCorrelation` → `lowSleepWorse` variant.
    static func threeWeeksLowSleepDrivesScoreHigher() -> [Day] {
        var days: [Day] = []
        for offset in (1..<22).reversed() {
            let goodSleep = offset.isMultiple(of: 2)
            let sleepMin = goodSleep ? 8 * 60 : 5 * 60
            days.append(.sleep(sleepMin, offset: -offset))
        }
        return days
    }
}
