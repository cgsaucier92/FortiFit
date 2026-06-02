//
//  TestFixtures.swift
//  FortiFitIntegrationTests
//
//  Shared helpers for integration tests. Builds an isolated in-memory
//  SwiftData stack per test, plus factories for the most common entities.
//
//  Usage: import this file's symbols via `@testable import FortiFit`.
//
//  Service call sites (e.g., WorkoutService.log) reflect best-guess
//  signatures based on SERVICES.md. If your actual service APIs differ,
//  adjust the factories here in one place and every test gets the fix.
//

import Foundation
import SwiftData
@testable import FortiFit

enum TestFixtures {

    // MARK: - In-Memory Container

    /// Returns an isolated in-memory SwiftData container with all models registered.
    /// Each test should call this for itself — do NOT share a container across tests.
    static func inMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for:
                Workout.self,
                ExerciseSet.self,
                Goal.self,
                GoalSnapshot.self,
                WorkoutTypeOrder.self,
                WorkoutTemplate.self,
                TemplateExerciseSet.self,
                ScheduledWorkout.self,
                HomeWidget.self,
                TrendsChart.self,
                WorkoutMatchRejection.self,
                DailySleepSnapshot.self,
                DailyTrainingLoadSnapshot.self,
            configurations: config
        )
    }

    /// Convenience: container + main context in one call.
    static func inMemoryContext() throws -> (ModelContainer, ModelContext) {
        let container = try inMemoryContainer()
        return (container, ModelContext(container))
    }

    // MARK: - Date Helpers

    /// A `Date` exactly N calendar days before `.now`. Negative N = future.
    static func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: .now)!
    }

    /// A `Date` for the given calendar day with the time component zeroed.
    /// Useful when tests need to assert on GoalSnapshot.date equality.
    static func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    // MARK: - Exercise Set Factory

    /// Lightweight struct mirroring ExerciseSet for factory calls.
    /// Makes test setup more readable than manually instantiating ExerciseSet.
    struct SetSpec {
        let exerciseName: String
        let sets: Int
        let reps: Int
        let weightKg: Double?

        init(_ exerciseName: String, sets: Int, reps: Int, weightKg: Double? = nil) {
            self.exerciseName = exerciseName
            self.sets = sets
            self.reps = reps
            self.weightKg = weightKg
        }
    }

    // MARK: - Workout Factory

    /// Inserts a Workout + its ExerciseSets directly into the context.
    /// Bypasses WorkoutService so you can construct arbitrary starting state
    /// WITHOUT triggering the cascade. Use this in `Given:` blocks.
    ///
    /// For `When:` blocks that are supposed to trigger the cascade, call
    /// your real WorkoutService methods instead.
    @discardableResult
    static func makeWorkout(
        name: String = "Test Workout",
        date: Date = .now,
        workoutType: String = "Strength Training",
        rpe: Int? = nil,
        durationMinutes: Int? = nil,
        distanceKm: Double? = nil,
        exercises: [SetSpec] = [],
        in context: ModelContext
    ) -> Workout {
        let workout = Workout(
            name: name,
            date: date,
            workoutType: workoutType,
            rpe: rpe,
            durationMinutes: durationMinutes,
            distanceKm: distanceKm
        )
        context.insert(workout)

        for (index, spec) in exercises.enumerated() {
            let set = ExerciseSet(
                exerciseName: spec.exerciseName,
                sets: spec.sets,
                reps: spec.reps,
                weightKg: spec.weightKg,
                sortOrder: index,
                workout: workout
            )
            context.insert(set)
        }

        try? context.save()
        return workout
    }

    // MARK: - Goal Factories

    @discardableResult
    static func makeStrengthPRGoal(
        title: String,
        targetKg: Double,
        currentKg: Double = 0,
        resetDate: Date? = nil,
        in context: ModelContext
    ) -> Goal {
        let goal = Goal(
            title: title,
            goalType: "Strength PR",
            targetValueKg: targetKg,
            currentValueKg: currentKg,
            colorIndex: 0,
            sortOrder: 0
        )
        goal.resetDate = resetDate
        context.insert(goal)
        try? context.save()
        return goal
    }

    @discardableResult
    static func makeRepsPRGoal(
        title: String,
        targetReps: Int,
        currentReps: Int = 0,
        in context: ModelContext
    ) -> Goal {
        let goal = Goal(
            title: title,
            goalType: "Repetitions PR",
            targetReps: targetReps,
            currentReps: currentReps,
            colorIndex: 1,
            sortOrder: 0
        )
        context.insert(goal)
        try? context.save()
        return goal
    }

    @discardableResult
    static func makeSpeedDistanceGoal(
        title: String,
        workoutType: String = "Cardio",
        targetDistanceKm: Double? = nil,
        targetDurationMinutes: Double? = nil,
        in context: ModelContext
    ) -> Goal {
        let goal = Goal(
            title: title,
            goalType: "Speed and Distance",
            targetDistanceKm: targetDistanceKm,
            targetDurationMinutes: targetDurationMinutes,
            linkedWorkoutType: workoutType,
            colorIndex: 2,
            sortOrder: 0
        )
        context.insert(goal)
        try? context.save()
        return goal
    }

    // MARK: - Template Factory

    @discardableResult
    static func makeTemplate(
        name: String,
        workoutType: String = "Strength Training",
        durationMinutes: Int? = nil,
        exercises: [SetSpec] = [],
        in context: ModelContext
    ) -> WorkoutTemplate {
        let template = WorkoutTemplate(
            name: name,
            workoutType: workoutType,
            durationMinutes: durationMinutes,
            dateCreated: .now
        )
        context.insert(template)

        for (index, spec) in exercises.enumerated() {
            let set = TemplateExerciseSet(
                exerciseName: spec.exerciseName,
                sets: spec.sets,
                reps: spec.reps,
                weightKg: spec.weightKg,
                sortOrder: index
            )
            context.insert(set)
            set.template = template
        }

        try? context.save()
        return template
    }

    // MARK: - Scheduled Workout Factory

    @discardableResult
    static func makeScheduledWorkout(
        from template: WorkoutTemplate,
        on date: Date,
        status: String = "planned",
        in context: ModelContext
    ) -> ScheduledWorkout {
        let scheduled = ScheduledWorkout(
            templateId: template.id,
            scheduledDate: date,
            workoutType: template.workoutType,
            workoutName: template.name,
            durationMinutes: template.durationMinutes,
            status: status,
            dateCreated: .now
        )
        context.insert(scheduled)
        try? context.save()
        return scheduled
    }

    // MARK: - Cascade Helpers

    /// Logs a workout and triggers the full cascade (type order, goal recalc, snapshots).
    /// Mirrors the cascade sequence in WorkoutViewModel.saveWorkout.
    @discardableResult
    static func logWorkoutWithCascade(
        name: String = "Test Workout",
        date: Date = Date(),
        workoutType: String = "Strength Training",
        rpe: Int? = nil,
        durationMinutes: Int? = nil,
        distanceKm: Double? = nil,
        exercises: [SetSpec] = [],
        in context: ModelContext
    ) -> Workout {
        let workout = Workout(
            name: name,
            date: date,
            workoutType: workoutType,
            rpe: rpe,
            durationMinutes: durationMinutes,
            distanceKm: distanceKm
        )
        for (index, spec) in exercises.enumerated() {
            let set = ExerciseSet(
                exerciseName: spec.exerciseName,
                sets: spec.sets,
                reps: spec.reps,
                weightKg: spec.weightKg,
                sortOrder: index
            )
            workout.exerciseSets.append(set)
        }
        WorkoutService.logWorkout(workout, context: context)
        WorkoutTypeOrderService.ensureOrderExists(for: workout.workoutType, context: context)
        GoalService.recalculateGoals(
            affectedExerciseNames: workout.exerciseSets.map { $0.exerciseName },
            affectedWorkoutTypes: [workout.workoutType],
            workout: workout,
            context: context
        )
        return workout
    }

    /// Deletes a workout and triggers the full cascade.
    /// Mirrors the cascade sequence in WorkoutViewModel.deleteWorkout.
    static func deleteWorkoutWithCascade(
        _ workout: Workout,
        in context: ModelContext
    ) {
        let workoutType = workout.workoutType
        let deletedDate = workout.date
        let exerciseNames = workout.exerciseSets.map { $0.exerciseName }

        let allGoals = GoalService.fetchAll(context: context)
        let affectedLower = Set(exerciseNames.map { $0.lowercased() })
        let affectedGoals = allGoals.filter {
            (($0.goalType == "Strength PR" || $0.goalType == "Repetitions PR") &&
             affectedLower.contains($0.title.lowercased())) ||
            ($0.goalType == "Speed and Distance" &&
             $0.linkedWorkoutType == workoutType)
        }

        _ = WorkoutService.deleteWorkout(workout, context: context)
        WorkoutTypeOrderService.removeOrderIfEmpty(for: workoutType, context: context)
        GoalService.recalculateGoals(
            affectedExerciseNames: exerciseNames,
            affectedWorkoutTypes: [workoutType],
            context: context
        )
        for goal in affectedGoals {
            GoalSnapshotService.recomputeSnapshot(goal: goal, date: deletedDate, context: context)
        }
    }

    /// Deletes all workouts for a type and triggers the full cascade.
    /// Mirrors the cascade sequence in WorkoutViewModel.deleteWorkoutType.
    static func deleteAllForTypeWithCascade(
        _ workoutType: String,
        in context: ModelContext
    ) {
        let allWorkouts = WorkoutService.fetchAll(context: context)
        let typeWorkouts = allWorkouts.filter { $0.workoutType == workoutType }
        let deletedDates = Set(typeWorkouts.map { Calendar.current.startOfDay(for: $0.date) })
        let exerciseNames = Array(Set(typeWorkouts.flatMap { $0.exerciseSets.map { $0.exerciseName } }))

        let allGoals = GoalService.fetchAll(context: context)
        let affectedLower = Set(exerciseNames.map { $0.lowercased() })
        let affectedGoals = allGoals.filter {
            (($0.goalType == "Strength PR" || $0.goalType == "Repetitions PR") &&
             affectedLower.contains($0.title.lowercased())) ||
            ($0.goalType == "Speed and Distance" &&
             $0.linkedWorkoutType == workoutType)
        }

        _ = WorkoutService.deleteAllForType(workoutType, context: context)
        WorkoutTypeOrderService.removeOrderIfEmpty(for: workoutType, context: context)
        GoalService.recalculateGoals(
            affectedExerciseNames: exerciseNames,
            affectedWorkoutTypes: [workoutType],
            context: context
        )
        for goal in affectedGoals {
            for date in deletedDates {
                GoalSnapshotService.recomputeSnapshot(goal: goal, date: date, context: context)
            }
        }
    }

    /// Updates a workout's date and triggers the full cascade (with priorDate handling).
    /// Mirrors the cascade in WorkoutViewModel.saveEditedWorkout.
    static func updateWorkoutDate(
        _ workout: Workout,
        newDate: Date,
        in context: ModelContext
    ) {
        let newSets = workout.exerciseSets.map { set in
            ExerciseSet(
                exerciseName: set.exerciseName,
                sets: set.sets,
                reps: set.reps,
                weightKg: set.weightKg,
                sortOrder: set.sortOrder
            )
        }
        let result = WorkoutService.updateWorkout(
            workout,
            name: workout.name,
            date: newDate,
            time: workout.time,
            rpe: workout.rpe,
            durationMinutes: workout.durationMinutes,
            distanceKm: workout.distanceKm,
            newExerciseSets: newSets
        )
        GoalService.recalculateGoals(
            affectedExerciseNames: result.affectedNames,
            affectedWorkoutTypes: [workout.workoutType],
            workout: workout,
            priorDate: result.priorDate,
            context: context
        )
    }

    /// Updates a workout's name (cosmetic edit) and triggers the full cascade.
    /// Mirrors the cascade in WorkoutViewModel.saveEditedWorkout.
    static func updateWorkoutName(
        _ workout: Workout,
        newName: String,
        in context: ModelContext
    ) {
        let newSets = workout.exerciseSets.map { set in
            ExerciseSet(
                exerciseName: set.exerciseName,
                sets: set.sets,
                reps: set.reps,
                weightKg: set.weightKg,
                sortOrder: set.sortOrder
            )
        }
        let result = WorkoutService.updateWorkout(
            workout,
            name: newName,
            date: workout.date,
            time: workout.time,
            rpe: workout.rpe,
            durationMinutes: workout.durationMinutes,
            distanceKm: workout.distanceKm,
            newExerciseSets: newSets
        )
        GoalService.recalculateGoals(
            affectedExerciseNames: result.affectedNames,
            affectedWorkoutTypes: [workout.workoutType],
            workout: workout,
            priorDate: result.priorDate,
            context: context
        )
    }

    // MARK: - HealthKit Factories

    static func makeHKWorkoutFixture(
        uuid: UUID = UUID(),
        activityTypeRawValue: UInt = 50,
        startDate: Date = Date(),
        durationMinutes: Int = 45,
        distanceKm: Double? = nil,
        avgHeartRate: Int? = 142,
        maxHeartRate: Int? = 168,
        activeEnergyKcal: Double? = 487,
        indoor: Bool? = false,
        workoutPlanId: UUID? = nil
    ) -> HealthKitWorkoutSnapshot {
        HealthKitWorkoutSnapshot(
            uuid: uuid,
            activityTypeRawValue: activityTypeRawValue,
            sourceBundleID: "com.apple.health.workout-builder",
            startDate: startDate,
            endDate: startDate.addingTimeInterval(TimeInterval(durationMinutes * 60)),
            durationMinutes: durationMinutes,
            distanceKm: distanceKm,
            avgHeartRate: avgHeartRate,
            maxHeartRate: maxHeartRate,
            activeEnergyKcal: activeEnergyKcal,
            totalEnergyBurnedKcal: nil,
            elevationAscendedMeters: nil,
            exerciseMinutes: nil,
            indoor: indoor,
            workoutPlanId: workoutPlanId
        )
    }

    @discardableResult
    static func makeLinkedWorkout(
        name: String = "HK Workout",
        date: Date = .now,
        workoutType: String = "Strength Training",
        rpe: Int? = nil,
        rpeFromHK: Bool = false,
        healthKitUUID: UUID = UUID(),
        durationMinutes: Int? = 45,
        distanceKm: Double? = nil,
        time: Date? = nil,
        note: String? = nil,
        avgHeartRate: Int? = 142,
        maxHeartRate: Int? = nil,
        activeEnergyKcal: Double? = nil,
        totalEnergyBurnedKcal: Double? = nil,
        elevationAscendedMeters: Double? = nil,
        exerciseMinutes: Int? = nil,
        indoor: Bool? = nil,
        exercises: [SetSpec] = [],
        in context: ModelContext
    ) -> Workout {
        let workout = Workout(
            name: name,
            date: date,
            workoutType: workoutType,
            rpe: rpe,
            note: note,
            durationMinutes: durationMinutes,
            distanceKm: distanceKm,
            time: time,
            healthKitUUID: healthKitUUID,
            healthKitSourceBundleID: "com.apple.health.workout-builder",
            healthKitActivityType: "Traditional Strength Training",
            avgHeartRate: avgHeartRate,
            maxHeartRate: maxHeartRate,
            activeEnergyKcal: activeEnergyKcal,
            totalEnergyBurnedKcal: totalEnergyBurnedKcal,
            elevationAscendedMeters: elevationAscendedMeters,
            exerciseMinutes: exerciseMinutes,
            indoor: indoor
        )
        workout.rpeFromHK = rpeFromHK

        for (index, spec) in exercises.enumerated() {
            let set = ExerciseSet(
                exerciseName: spec.exerciseName,
                sets: spec.sets,
                reps: spec.reps,
                weightKg: spec.weightKg,
                sortOrder: index,
                workout: workout
            )
            context.insert(set)
        }

        context.insert(workout)
        try? context.save()
        return workout
    }
}

// MARK: - StubHealthKitClient

final class StubHealthKitClient: HealthKitClient, @unchecked Sendable {
    var authStatus: HealthKitAuthorizationStatus = .granted
    var workoutsToReturn: [HealthKitWorkoutSnapshot] = []
    var deletedUUIDsToReturn: [UUID] = []
    var anchorToReturn: Data? = nil
    var effortScoreToReturn: Int? = nil
    var sourceNameToReturn: String = "Apple Workout"
    var authorizationRequested = false

    // Activity Rings stubs
    var activitySummaryToReturn: ActivitySummarySnapshot? = nil
    var activitySummariesToReturn: [ActivitySummarySnapshot] = []
    var hasAppleWatchDataToReturn: Bool = false

    // Sleep stubs (Phase 11)
    var sleepSamplesToReturn: [HKSleepSampleSnapshot] = []
    var sleepDurationGoalToReturn: TimeInterval? = nil
    var hasRecentSleepDataToReturn: Bool = false
    var sleepObserverHandler: (@Sendable () -> Void)?

    func requestAuthorization() async throws {
        authorizationRequested = true
    }

    func authorizationStatus() -> HealthKitAuthorizationStatus {
        authStatus
    }

    func fetchWorkouts(since anchor: Data?) async throws -> (workouts: [HealthKitWorkoutSnapshot], deletedUUIDs: [UUID], newAnchor: Data?) {
        (workoutsToReturn, deletedUUIDsToReturn, anchorToReturn)
    }

    func observeWorkoutChanges(handler: @escaping @Sendable () -> Void) {}

    func observeEffortScoreChanges(handler: @escaping @Sendable () -> Void) {}

    func fetchEffortScore(for hkWorkoutUUID: UUID) async throws -> Int? {
        effortScoreToReturn
    }

    func sourceName(for bundleID: String) -> String {
        sourceNameToReturn
    }

    // Activity Rings methods
    func fetchActivitySummary(for date: Date) async throws -> ActivitySummarySnapshot? {
        activitySummaryToReturn
    }

    func fetchActivitySummaries(from start: Date, to end: Date) async throws -> [ActivitySummarySnapshot] {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: end) ?? end)
        return activitySummariesToReturn.filter { summary in
            let day = calendar.startOfDay(for: summary.date)
            return day >= startDay && day < endDay
        }
    }

    func observeActivitySummaryChanges(handler: @escaping @Sendable () -> Void) {}

    func hasAppleWatchData(within days: Int) async throws -> Bool {
        hasAppleWatchDataToReturn
    }

    // Sleep methods (Phase 11)
    func fetchSleepSamples(from start: Date, to end: Date) async throws -> [HKSleepSampleSnapshot] {
        sleepSamplesToReturn.filter { $0.endDate > start && $0.endDate <= end }
    }

    func observeSleepChanges(handler: @escaping @Sendable () -> Void) {
        sleepObserverHandler = handler
    }

    func fetchSleepDurationGoal() async throws -> TimeInterval? {
        sleepDurationGoalToReturn
    }

    func hasRecentSleepData(within days: Int) async throws -> Bool {
        hasRecentSleepDataToReturn
    }

    /// Convenience for tests — synchronously fires the captured sleep observer handler.
    func fireSleepObserver() {
        sleepObserverHandler?()
    }
}
