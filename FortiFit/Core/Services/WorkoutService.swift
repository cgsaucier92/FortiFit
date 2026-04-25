import Foundation
import SwiftData

struct WorkoutService {

    // MARK: - Create

    /// Logs a new workout with optional exercise sets.
    static func logWorkout(
        _ workout: Workout,
        context: ModelContext
    ) {
        workout.lastModifiedDate = .now
        context.insert(workout)
        try? context.save()
    }

    // MARK: - Read

    /// Fetches all workouts sorted newest-first by date.
    static func fetchAll(context: ModelContext) -> [Workout] {
        let descriptor = FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Fetches workouts within a date range, sorted newest-first.
    static func fetchWorkouts(
        from startDate: Date,
        to endDate: Date,
        context: ModelContext
    ) -> [Workout] {
        let predicate = #Predicate<Workout> { workout in
            workout.date >= startDate && workout.date <= endDate
        }
        let descriptor = FetchDescriptor<Workout>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Fetches workouts for the current ISO week (Monday–Sunday).
    static func fetchCurrentWeekWorkouts(context: ModelContext) -> [Workout] {
        let now = Date()
        return fetchWorkouts(from: now.startOfWeek, to: now.endOfWeek, context: context)
    }

    /// Fetches workouts within the last 10 days (inclusive), sorted newest-first.
    /// Used as the lookback window for the Training Load algorithm.
    static func fetchLast10DaysWorkouts(context: ModelContext, now: Date = Date()) -> [Workout] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -10, to: now) ?? now
        return fetchWorkouts(from: cutoff, to: now, context: context)
    }

    // MARK: - Update

    /// Updates the note on a workout.
    static func updateNote(
        _ workout: Workout,
        note: String?,
        context: ModelContext
    ) {
        workout.note = note
        workout.lastModifiedDate = .now
        try? context.save()
    }

    // MARK: - Update (Full Edit)

    /// Updates an existing workout with new field values and exercise sets.
    /// Deletes removed ExerciseSets, updates modified ones, and adds new ones.
    /// Returns the union of old and new exercise names for goal recalculation.
    @discardableResult
    static func updateWorkout(
        _ workout: Workout,
        name: String,
        date: Date,
        time: Date?,
        rpe: Int?,
        durationMinutes: Int?,
        distanceKm: Double?,
        newExerciseSets: [ExerciseSet]
    ) -> (affectedNames: [String], priorDate: Date?) {
        // Collect exercise names from both old and new data for goal recalculation
        let oldNames = workout.exerciseSets.map { $0.exerciseName }
        let newNames = newExerciseSets.map { $0.exerciseName }
        let allAffectedNames = Array(Set(oldNames + newNames))

        // Capture prior date if the date changed (for snapshot recompute on both dates)
        let calendar = Calendar.current
        let priorDate = calendar.isDate(workout.date, inSameDayAs: date) ? nil : workout.date

        // Update scalar fields
        workout.name = name
        workout.date = date
        workout.time = time
        workout.rpe = rpe
        workout.durationMinutes = durationMinutes
        workout.distanceKm = distanceKm
        workout.lastModifiedDate = .now

        // Replace exercise sets: remove old, add new
        let context = workout.modelContext
        for oldSet in workout.exerciseSets {
            context?.delete(oldSet)
        }
        workout.exerciseSets = []

        for newSet in newExerciseSets {
            workout.exerciseSets.append(newSet)
        }

        try? context?.save()
        return (allAffectedNames, priorDate)
    }

    // MARK: - Delete

    /// Deletes a workout and all its exercise sets (cascade).
    /// Returns the exercise names from the deleted workout for goal recalculation.
    @discardableResult
    static func deleteWorkout(
        _ workout: Workout,
        context: ModelContext
    ) -> [String] {
        let exerciseNames = workout.exerciseSets.map { $0.exerciseName }
        let workoutId = workout.id
        context.delete(workout)
        try? context.save()
        // Revert any ScheduledWorkout linked to this workout
        PlanService.revertScheduledWorkoutsForDeletedWorkout(workoutId: workoutId, context: context)
        return exerciseNames
    }

    /// Deletes all workouts of a given type and their exercise sets (cascade).
    /// Returns the deduplicated exercise names from all deleted workouts for goal recalculation.
    @discardableResult
    static func deleteAllForType(
        _ workoutType: String,
        context: ModelContext
    ) -> [String] {
        let predicate = #Predicate<Workout> { workout in
            workout.workoutType == workoutType
        }
        let descriptor = FetchDescriptor<Workout>(predicate: predicate)
        let workouts = (try? context.fetch(descriptor)) ?? []

        var allExerciseNames: [String] = []
        var workoutIds: [UUID] = []
        for workout in workouts {
            allExerciseNames.append(contentsOf: workout.exerciseSets.map { $0.exerciseName })
            workoutIds.append(workout.id)
        }

        for workout in workouts {
            context.delete(workout)
        }
        try? context.save()
        // Revert any ScheduledWorkouts linked to deleted workouts
        for workoutId in workoutIds {
            PlanService.revertScheduledWorkoutsForDeletedWorkout(workoutId: workoutId, context: context)
        }
        return Array(Set(allExerciseNames))
    }

    // MARK: - Sprints → Cardio Migration

    static func migrateSprintsToCardioIfNeeded(context: ModelContext) {
        let settings = UserSettings.shared
        guard !settings.hasMigratedSprintsToCardio else { return }

        let predicate = #Predicate<Workout> { workout in
            workout.workoutType == "Sprints"
        }
        let descriptor = FetchDescriptor<Workout>(predicate: predicate)
        let sprintsWorkouts = (try? context.fetch(descriptor)) ?? []

        for workout in sprintsWorkouts {
            workout.workoutType = "Cardio"
            workout.lastModifiedDate = .now
        }

        let sprintsOrder = WorkoutTypeOrderService.fetch(for: "Sprints", context: context)
        let cardioOrder = WorkoutTypeOrderService.fetch(for: "Cardio", context: context)

        if let sprintsOrder {
            if cardioOrder != nil {
                context.delete(sprintsOrder)
            } else {
                sprintsOrder.workoutType = "Cardio"
            }
        }

        try? context.save()
        settings.hasMigratedSprintsToCardio = true
    }

    // MARK: - PR Calculation

    /// Computes personal records from all workouts. Returns a dictionary of
    /// exerciseName → (weight in kg, date achieved).
    /// A PR is the highest weightKg ever recorded for a given exercise.
    static func computePersonalRecords(context: ModelContext) -> [String: (weight: Double, date: Date)] {
        let allWorkouts = fetchAll(context: context)
        var prs: [String: (weight: Double, date: Date)] = [:]

        // Process oldest-first so the earliest achievement wins ties
        for workout in allWorkouts.reversed() {
            for exerciseSet in workout.exerciseSets {
                guard let weight = exerciseSet.weightKg else { continue }
                let name = exerciseSet.exerciseName.lowercased()
                if let existing = prs[name] {
                    if weight > existing.weight {
                        prs[name] = (weight, workout.date)
                    }
                } else {
                    prs[name] = (weight, workout.date)
                }
            }
        }
        return prs
    }

    /// Computes a chronological PR timeline: each entry is a new high for an exercise.
    /// Sorted oldest-first.
    static func computePRTimeline(context: ModelContext) -> [PREntry] {
        let allWorkouts = fetchAll(context: context).reversed() // oldest-first
        var bestByExercise: [String: Double] = [:]
        var timeline: [PREntry] = []

        for workout in allWorkouts {
            for exerciseSet in workout.exerciseSets.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                guard let weight = exerciseSet.weightKg else { continue }
                let key = exerciseSet.exerciseName.lowercased()
                if let currentBest = bestByExercise[key] {
                    if weight > currentBest {
                        timeline.append(PREntry(
                            exerciseName: exerciseSet.exerciseName,
                            date: workout.date,
                            newValue: weight,
                            previousValue: currentBest
                        ))
                        bestByExercise[key] = weight
                    }
                } else {
                    // First time logging this exercise — record as initial, not a PR
                    bestByExercise[key] = weight
                }
            }
        }
        return timeline
    }
}

struct PREntry: Identifiable {
    let id = UUID()
    let exerciseName: String
    let date: Date
    let newValue: Double
    let previousValue: Double
}
