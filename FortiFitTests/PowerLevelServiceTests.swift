import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// Helper to create an in-memory SwiftData context for Power Level tests.
private func makeTestContext() throws -> ModelContext {
    let schema = Schema([Workout.self, ExerciseSet.self, Goal.self, WorkoutTypeOrder.self, HomeWidget.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

/// Helper to create a workout with exercise sets at a specific date offset from `now`.
private func createWorkout(
    name: String = "Workout",
    type: String = "Strength Training",
    daysAgo: Int,
    exercises: [(name: String, sets: Int, reps: Int, weight: Double?)],
    now: Date,
    context: ModelContext
) {
    let calendar = Calendar.current
    let date = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!

    let workout = Workout(name: name, workoutType: type)
    workout.date = date
    context.insert(workout)

    for (index, ex) in exercises.enumerated() {
        let exerciseSet = ExerciseSet(
            exerciseName: ex.name,
            sets: ex.sets,
            reps: ex.reps,
            weightKg: ex.weight,
            sortOrder: index,
            workout: workout
        )
        context.insert(exerciseSet)
    }
    try? context.save()
}

// MARK: - PowerLevelService Tests

struct PowerLevelServiceTests {

    @Test func risingWith15PercentIncrease() throws {
        let context = try makeTestContext()
        let now = Date()

        // Baseline period (31-60 days ago): avg volume = 1000
        // 2 workouts, each with volume 1000 (4 sets x 5 reps x 50kg = 1000)
        createWorkout(daysAgo: 40, exercises: [("Bench", 4, 5, 50.0)], now: now, context: context)
        createWorkout(daysAgo: 50, exercises: [("Bench", 4, 5, 50.0)], now: now, context: context)

        // Current period (0-30 days ago): avg volume = 1150 (15% increase)
        // 2 workouts, each with volume 1150 (4 sets x 5 reps x 57.5kg = 1150)
        createWorkout(daysAgo: 5, exercises: [("Bench", 4, 5, 57.5)], now: now, context: context)
        createWorkout(daysAgo: 15, exercises: [("Bench", 4, 5, 57.5)], now: now, context: context)

        let result = PowerLevelService.calculatePowerLevel(context: context, now: now)
        #expect(result.status == .rising)
        #expect(result.indicator == "↑")
    }

    @Test func steadyWith5PercentDecrease() throws {
        let context = try makeTestContext()
        let now = Date()

        // Baseline: avg volume = 1000
        createWorkout(daysAgo: 40, exercises: [("Squat", 4, 5, 50.0)], now: now, context: context)
        createWorkout(daysAgo: 50, exercises: [("Squat", 4, 5, 50.0)], now: now, context: context)

        // Current: avg volume = 950 (5% decrease, within ±10%)
        createWorkout(daysAgo: 5, exercises: [("Squat", 4, 5, 47.5)], now: now, context: context)
        createWorkout(daysAgo: 15, exercises: [("Squat", 4, 5, 47.5)], now: now, context: context)

        let result = PowerLevelService.calculatePowerLevel(context: context, now: now)
        #expect(result.status == .steady)
        #expect(result.indicator == "—")
    }

    @Test func deloadingWith20PercentDecrease() throws {
        let context = try makeTestContext()
        let now = Date()

        // Baseline: avg volume = 1000
        createWorkout(daysAgo: 40, exercises: [("Deadlift", 4, 5, 50.0)], now: now, context: context)
        createWorkout(daysAgo: 50, exercises: [("Deadlift", 4, 5, 50.0)], now: now, context: context)

        // Current: avg volume = 800 (20% decrease)
        createWorkout(daysAgo: 5, exercises: [("Deadlift", 4, 5, 40.0)], now: now, context: context)
        createWorkout(daysAgo: 15, exercises: [("Deadlift", 4, 5, 40.0)], now: now, context: context)

        let result = PowerLevelService.calculatePowerLevel(context: context, now: now)
        #expect(result.status == .deloading)
        #expect(result.indicator == "↓")
    }

    @Test func noBaselineDefaultsToSteady() throws {
        let context = try makeTestContext()
        let now = Date()

        // Only current-period workouts (no baseline)
        createWorkout(daysAgo: 5, exercises: [("Bench", 4, 5, 60.0)], now: now, context: context)
        createWorkout(daysAgo: 10, exercises: [("Bench", 4, 5, 60.0)], now: now, context: context)

        let result = PowerLevelService.calculatePowerLevel(context: context, now: now)
        #expect(result.status == .steady)
    }

    @Test func noDataInBothPeriods() throws {
        let context = try makeTestContext()
        let now = Date()

        // No workouts at all
        let result = PowerLevelService.calculatePowerLevel(context: context, now: now)
        #expect(result.status == .noData)
        #expect(result.message == "Log Strength Training or HIIT workouts to track your power level.")
    }

    @Test func currentEmptyWithBaselineIsDeloading() throws {
        let context = try makeTestContext()
        let now = Date()

        // Only baseline workouts, none in current period
        createWorkout(daysAgo: 40, exercises: [("Bench", 4, 5, 50.0)], now: now, context: context)
        createWorkout(daysAgo: 50, exercises: [("Bench", 4, 5, 50.0)], now: now, context: context)

        let result = PowerLevelService.calculatePowerLevel(context: context, now: now)
        #expect(result.status == .deloading)
    }

    @Test func bodyweightExercisesUseEffectiveWeight1() throws {
        let context = try makeTestContext()
        let now = Date()

        // Create a workout with bodyweight exercise (nil weight)
        let workout = Workout(name: "BW Workout", workoutType: "Strength Training")
        let calendar = Calendar.current
        workout.date = calendar.date(byAdding: .day, value: -5, to: calendar.startOfDay(for: now))!
        context.insert(workout)

        let exerciseSet = ExerciseSet(
            exerciseName: "Pull-ups",
            sets: 3,
            reps: 10,
            weightKg: nil,
            sortOrder: 0,
            workout: workout
        )
        context.insert(exerciseSet)
        try context.save()

        // Volume should be 3 * 10 * 1.0 = 30
        let volume = PowerLevelService.workoutVolume(for: workout)
        #expect(abs(volume - 30.0) < 0.001)
    }

    @Test func onlyStrengthAndHIITQualify() throws {
        let context = try makeTestContext()
        let now = Date()

        // Add non-qualifying workouts in current period
        createWorkout(name: "Yoga", type: "Yoga", daysAgo: 5,
                      exercises: [("Flow", 3, 10, 0.0)], now: now, context: context)
        createWorkout(name: "Run", type: "Cardio", daysAgo: 10,
                      exercises: [("Running", 1, 1, 0.0)], now: now, context: context)

        // No qualifying workouts → should be noData
        let result = PowerLevelService.calculatePowerLevel(context: context, now: now)
        #expect(result.status == .noData)
    }

    @Test func workoutVolumeCalculation() throws {
        let context = try makeTestContext()

        let workout = Workout(name: "Test", workoutType: "Strength Training")
        context.insert(workout)

        // 4 sets x 8 reps x 80kg = 2560
        let set1 = ExerciseSet(exerciseName: "Bench", sets: 4, reps: 8, weightKg: 80.0, sortOrder: 0, workout: workout)
        // 3 sets x 10 reps x nil (BW = 1.0) = 30
        let set2 = ExerciseSet(exerciseName: "Push-ups", sets: 3, reps: 10, weightKg: nil, sortOrder: 1, workout: workout)
        context.insert(set1)
        context.insert(set2)
        try context.save()

        let volume = PowerLevelService.workoutVolume(for: workout)
        #expect(abs(volume - 2590.0) < 0.001)
    }

    @Test func hiitWorkoutsAlsoQualify() throws {
        let context = try makeTestContext()
        let now = Date()

        // HIIT workouts in current period
        createWorkout(name: "HIIT", type: "HIIT", daysAgo: 5,
                      exercises: [("KB Swings", 5, 15, 24.0)], now: now, context: context)

        // HIIT workouts in baseline period
        createWorkout(name: "HIIT", type: "HIIT", daysAgo: 40,
                      exercises: [("KB Swings", 5, 15, 20.0)], now: now, context: context)

        // Current: 5*15*24 = 1800, Baseline: 5*15*20 = 1500
        // pct_change = ((1800-1500)/1500)*100 = 20% → Rising
        let result = PowerLevelService.calculatePowerLevel(context: context, now: now)
        #expect(result.status == .rising)
    }
}
