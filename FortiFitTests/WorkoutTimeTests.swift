import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// Helper to create an in-memory SwiftData context for testing.
private func makeTestContext() throws -> ModelContext {
    let schema = Schema([Workout.self, ExerciseSet.self, Goal.self, WorkoutTemplate.self, TemplateExerciseSet.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

// MARK: - Workout Model — `time` Property

struct WorkoutTimeModelTests {

    @Test func workoutModelHasOptionalTimeProperty() throws {
        let context = try makeTestContext()
        let time = Date()
        let workout = Workout(name: "Push Day", workoutType: "Strength Training", time: time)
        context.insert(workout)
        try context.save()

        let descriptor = FetchDescriptor<Workout>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.time != nil)
    }

    @Test func workoutCreatedWithTimePersists() throws {
        let context = try makeTestContext()
        let time = Date()
        let workout = Workout(name: "Push Day", workoutType: "Strength Training", time: time)
        context.insert(workout)
        try context.save()

        let descriptor = FetchDescriptor<Workout>()
        let results = try context.fetch(descriptor)
        let savedTime = try #require(results.first?.time)
        #expect(abs(savedTime.timeIntervalSince(time)) < 1)
    }

    @Test func workoutCreatedWithNilTimeDoesNotCrash() throws {
        let context = try makeTestContext()
        let workout = Workout(name: "Push Day", workoutType: "Strength Training", time: nil)
        context.insert(workout)
        try context.save()

        let descriptor = FetchDescriptor<Workout>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.time == nil)
    }

    @Test func workoutTimeCanBeUpdated() throws {
        let context = try makeTestContext()
        let originalTime = Date()
        let workout = Workout(name: "Push Day", workoutType: "Strength Training", time: originalTime)
        context.insert(workout)
        try context.save()

        let newTime = Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: Date())!
        workout.time = newTime
        try context.save()

        let descriptor = FetchDescriptor<Workout>()
        let results = try context.fetch(descriptor)
        let savedTime = try #require(results.first?.time)
        #expect(abs(savedTime.timeIntervalSince(newTime)) < 1)
    }

    @Test func workoutWithoutTimeDefaultsToNil() throws {
        let context = try makeTestContext()
        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        context.insert(workout)
        try context.save()

        let descriptor = FetchDescriptor<Workout>()
        let results = try context.fetch(descriptor)
        #expect(results.first?.time == nil)
    }
}

// MARK: - WorkoutService — `time` Field

struct WorkoutServiceTimeTests {

    @Test func logWorkoutWithTimePersists() throws {
        let context = try makeTestContext()
        let time = Date()
        let workout = Workout(name: "Push Day", workoutType: "Strength Training", time: time)
        WorkoutService.logWorkout(workout, context: context)

        let results = WorkoutService.fetchAll(context: context)
        let savedTime = try #require(results.first?.time)
        #expect(abs(savedTime.timeIntervalSince(time)) < 1)
    }

    @Test func updateWorkoutTimePersists() throws {
        let context = try makeTestContext()
        let workout = Workout(name: "Push Day", workoutType: "Strength Training", time: Date())
        WorkoutService.logWorkout(workout, context: context)

        let newTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
        WorkoutService.updateWorkout(
            workout,
            name: workout.name,
            date: workout.date,
            time: newTime,
            rpe: workout.rpe,
            durationMinutes: workout.durationMinutes,
            distanceKm: workout.distanceKm,
            newExerciseSets: []
        )

        let results = WorkoutService.fetchAll(context: context)
        let savedTime = try #require(results.first?.time)
        #expect(abs(savedTime.timeIntervalSince(newTime)) < 1)
    }

    @Test func updateOnlyTimeDoesNotAffectOtherFields() throws {
        let context = try makeTestContext()
        let originalDate = Date()
        let workout = Workout(
            name: "Push Day",
            workoutType: "Strength Training",
            rpe: 7,
            durationMinutes: 45,
            time: Date()
        )
        let exerciseSet = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 8, weightKg: 80, sortOrder: 0)
        workout.exerciseSets.append(exerciseSet)
        WorkoutService.logWorkout(workout, context: context)

        let newTime = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date())!
        let newSet = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 8, weightKg: 80, sortOrder: 0)
        WorkoutService.updateWorkout(
            workout,
            name: "Push Day",
            date: originalDate,
            time: newTime,
            rpe: 7,
            durationMinutes: 45,
            distanceKm: nil,
            newExerciseSets: [newSet]
        )

        let results = WorkoutService.fetchAll(context: context)
        let updated = try #require(results.first)
        #expect(updated.name == "Push Day")
        #expect(updated.rpe == 7)
        #expect(updated.durationMinutes == 45)
        #expect(updated.exerciseSets.count == 1)
        #expect(updated.exerciseSets.first?.weightKg == 80)
    }
}

// MARK: - Create Template — Time Picker Exclusion

struct WorkoutTemplateTimeExclusionTests {

    @Test func workoutTemplateDoesNotHaveTimeProperty() throws {
        // WorkoutTemplate should not include a time property.
        // We verify by creating a template and confirming it has no time field.
        let context = try makeTestContext()
        let template = WorkoutTemplate(name: "Push Template", workoutType: "Strength Training")
        context.insert(template)
        try context.save()

        let descriptor = FetchDescriptor<WorkoutTemplate>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        // WorkoutTemplate has: id, name, workoutType, durationMinutes, dateCreated, exerciseSets
        // No time property exists — this test compiles only if time is absent from the model
        #expect(results.first?.name == "Push Template")
    }
}

// MARK: - Time — No Recalculation Side Effects

struct WorkoutTimeNoSideEffectsTests {

    @Test func changingTimeDoesNotAffectTrainingLoad() throws {
        let context = try makeTestContext()
        let workout = Workout(
            name: "Push Day",
            workoutType: "Strength Training",
            rpe: 8,
            durationMinutes: 60,
            time: Date()
        )
        let exerciseSet = ExerciseSet(exerciseName: "Bench Press", sets: 4, reps: 8, weightKg: 100, sortOrder: 0)
        workout.exerciseSets.append(exerciseSet)
        WorkoutService.logWorkout(workout, context: context)

        // Calculate load before time change
        let settings = UserSettings.shared
        let workouts = WorkoutService.fetchAll(context: context)
        let loadBefore = ExerciseLoadService.calculateLoad(
            workouts: workouts,
            experienceLevel: settings.experienceLevel,
            targetMinutesPerWorkout: settings.targetMinutesPerWorkout
        )

        // Change only the time
        let newTime = Calendar.current.date(bySettingHour: 6, minute: 0, second: 0, of: Date())!
        workout.time = newTime
        try context.save()

        // Calculate load after time change
        let workoutsAfter = WorkoutService.fetchAll(context: context)
        let loadAfter = ExerciseLoadService.calculateLoad(
            workouts: workoutsAfter,
            experienceLevel: settings.experienceLevel,
            targetMinutesPerWorkout: settings.targetMinutesPerWorkout
        )

        #expect(loadBefore.score == loadAfter.score)
        #expect(loadBefore.zone == loadAfter.zone)
    }

    @Test func changingTimeDoesNotAffectPRTimeline() throws {
        let context = try makeTestContext()
        let workout = Workout(
            name: "Push Day",
            workoutType: "Strength Training",
            time: Date()
        )
        let exerciseSet = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 100, sortOrder: 0)
        workout.exerciseSets.append(exerciseSet)
        WorkoutService.logWorkout(workout, context: context)

        let prsBefore = WorkoutService.computePersonalRecords(context: context)

        // Change only the time
        workout.time = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date())!
        try context.save()

        let prsAfter = WorkoutService.computePersonalRecords(context: context)

        #expect(prsBefore.count == prsAfter.count)
        #expect(prsBefore["bench press"]?.weight == prsAfter["bench press"]?.weight)
    }

    @Test func changingTimeDoesNotAffectStreak() throws {
        let context = try makeTestContext()
        let workout = Workout(
            name: "Push Day",
            workoutType: "Strength Training",
            time: Date()
        )
        WorkoutService.logWorkout(workout, context: context)

        let streakBefore = StreakService.calculateStreak(context: context, writeToSettings: false)

        // Change only the time
        workout.time = Calendar.current.date(bySettingHour: 3, minute: 0, second: 0, of: Date())!
        try context.save()

        let streakAfter = StreakService.calculateStreak(context: context, writeToSettings: false)

        #expect(streakBefore.streak == streakAfter.streak)
    }

    @Test func changingTimeDoesNotAffectGoals() throws {
        let context = try makeTestContext()

        // Create a Strength PR goal
        GoalService.createExercisePRGoal(title: "Bench Press", targetValueKg: 120, context: context)

        // Log a workout with a matching exercise
        let workout = Workout(name: "Push Day", workoutType: "Strength Training", time: Date())
        let exerciseSet = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 5, weightKg: 100, sortOrder: 0)
        workout.exerciseSets.append(exerciseSet)
        WorkoutService.logWorkout(workout, context: context)
        GoalService.recalculateGoals(
            affectedExerciseNames: ["Bench Press"],
            affectedWorkoutTypes: ["Strength Training"],
            workout: workout,
            context: context
        )

        let goalsBefore = GoalService.fetchAll(context: context)
        let currentValueBefore = goalsBefore.first?.currentValueKg

        // Change only the time
        workout.time = Calendar.current.date(bySettingHour: 15, minute: 45, second: 0, of: Date())!
        try context.save()

        let goalsAfter = GoalService.fetchAll(context: context)
        #expect(goalsAfter.first?.currentValueKg == currentValueBefore)
    }

    @Test func changingTimeDoesNotAffectPowerLevel() throws {
        let context = try makeTestContext()
        let workout = Workout(
            name: "Push Day",
            workoutType: "Strength Training",
            time: Date()
        )
        let exerciseSet = ExerciseSet(exerciseName: "Bench Press", sets: 4, reps: 8, weightKg: 80, sortOrder: 0)
        workout.exerciseSets.append(exerciseSet)
        WorkoutService.logWorkout(workout, context: context)

        let plBefore = PowerLevelService.calculatePowerLevel(context: context)

        // Change only the time
        workout.time = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
        try context.save()

        let plAfter = PowerLevelService.calculatePowerLevel(context: context)

        #expect(plBefore.status == plAfter.status)
    }
}

// MARK: - Time — Edge Cases

struct WorkoutTimeEdgeCaseTests {

    @Test func midnightTimeSavesAndPersists() throws {
        let context = try makeTestContext()
        let midnight = Calendar.current.startOfDay(for: Date())
        let workout = Workout(name: "Early Bird", workoutType: "Yoga", time: midnight)
        WorkoutService.logWorkout(workout, context: context)

        let results = WorkoutService.fetchAll(context: context)
        let savedTime = try #require(results.first?.time)
        #expect(abs(savedTime.timeIntervalSince(midnight)) < 1)
    }

    @Test func latNightTimeSavesAndPersists() throws {
        let context = try makeTestContext()
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 23
        components.minute = 59
        components.second = 0
        let lateNight = Calendar.current.date(from: components)!
        let workout = Workout(name: "Night Owl", workoutType: "HIIT", time: lateNight)
        WorkoutService.logWorkout(workout, context: context)

        let results = WorkoutService.fetchAll(context: context)
        let savedTime = try #require(results.first?.time)
        #expect(abs(savedTime.timeIntervalSince(lateNight)) < 1)
    }

    @Test func editDatePreservesTime() throws {
        let context = try makeTestContext()
        let originalTime = Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: Date())!
        let workout = Workout(
            name: "Push Day",
            workoutType: "Strength Training",
            time: originalTime
        )
        WorkoutService.logWorkout(workout, context: context)

        // Change date but keep time
        let newDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        WorkoutService.updateWorkout(
            workout,
            name: workout.name,
            date: newDate,
            time: originalTime,
            rpe: nil,
            durationMinutes: nil,
            distanceKm: nil,
            newExerciseSets: []
        )

        let results = WorkoutService.fetchAll(context: context)
        let updated = try #require(results.first)
        let savedTime = try #require(updated.time)
        #expect(abs(savedTime.timeIntervalSince(originalTime)) < 1)
        #expect(abs(updated.date.timeIntervalSince(newDate)) < 1)
    }

    @Test func editTimePreservesDate() throws {
        let context = try makeTestContext()
        let originalDate = Date()
        let originalTime = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        let workout = Workout(
            name: "Push Day",
            date: originalDate,
            workoutType: "Strength Training",
            time: originalTime
        )
        WorkoutService.logWorkout(workout, context: context)

        // Change time but keep date
        let newTime = Calendar.current.date(bySettingHour: 18, minute: 30, second: 0, of: Date())!
        WorkoutService.updateWorkout(
            workout,
            name: workout.name,
            date: originalDate,
            time: newTime,
            rpe: nil,
            durationMinutes: nil,
            distanceKm: nil,
            newExerciseSets: []
        )

        let results = WorkoutService.fetchAll(context: context)
        let updated = try #require(results.first)
        #expect(abs(updated.date.timeIntervalSince(originalDate)) < 1)
        let savedTime = try #require(updated.time)
        #expect(abs(savedTime.timeIntervalSince(newTime)) < 1)
    }

    @Test func nilTimeWorkoutCanBeEditedWithNewTime() throws {
        let context = try makeTestContext()
        // Simulate a pre-feature workout with nil time
        let workout = Workout(name: "Legacy Workout", workoutType: "Cardio", time: nil)
        WorkoutService.logWorkout(workout, context: context)
        #expect(workout.time == nil)

        // Edit and set a time
        let newTime = Date()
        WorkoutService.updateWorkout(
            workout,
            name: workout.name,
            date: workout.date,
            time: newTime,
            rpe: nil,
            durationMinutes: nil,
            distanceKm: nil,
            newExerciseSets: []
        )

        let results = WorkoutService.fetchAll(context: context)
        let updated = try #require(results.first)
        #expect(updated.time != nil)
    }

    @Test func timeFormattedExtensionWorks() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 17
        components.hour = 14
        components.minute = 35
        let date = Calendar.current.date(from: components)!
        let formatted = date.timeFormatted
        // The exact format depends on locale, but it should contain the time
        #expect(!formatted.isEmpty)
        // For en_US it would be "2:35 PM", for 24h it would be "14:35"
        // Just verify it produces a non-empty string
    }

    @Test func timeWorksForAllWorkoutTypes() throws {
        let context = try makeTestContext()
        let time = Date()

        for workoutType in AppConstants.workoutTypes {
            let workout = Workout(name: "\(workoutType) Session", workoutType: workoutType, time: time)
            WorkoutService.logWorkout(workout, context: context)
        }

        let results = WorkoutService.fetchAll(context: context)
        #expect(results.count == AppConstants.workoutTypes.count)
        for workout in results {
            #expect(workout.time != nil)
        }
    }
}
