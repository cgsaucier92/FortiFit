import Foundation
import SwiftData

struct WorkoutTemplateService {

    // MARK: - Data Types

    struct ExerciseData {
        let name: String
        let sets: Int
        let reps: Int
        let weightKg: Double?
        let sortOrder: Int
    }

    struct TemplateSnapshot {
        let name: String
        let workoutType: String
        let durationMinutes: Int?
        let exercises: [ExerciseData]
    }

    // MARK: - Fetch

    static func fetchAll(context: ModelContext) -> [WorkoutTemplate] {
        let descriptor = FetchDescriptor<WorkoutTemplate>(
            sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func templates(matching workoutType: String, context: ModelContext) -> [WorkoutTemplate] {
        let descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate<WorkoutTemplate> { template in
                template.workoutType == workoutType
            },
            sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Create

    @discardableResult
    static func create(
        name: String,
        workoutType: String,
        durationMinutes: Int?,
        exercises: [ExerciseData],
        context: ModelContext
    ) -> WorkoutTemplate {
        let template = WorkoutTemplate(
            name: name,
            workoutType: workoutType,
            durationMinutes: durationMinutes
        )
        context.insert(template)
        for exercise in exercises {
            let set = TemplateExerciseSet(
                exerciseName: exercise.name,
                sets: exercise.sets,
                reps: exercise.reps,
                weightKg: exercise.weightKg,
                sortOrder: exercise.sortOrder
            )
            template.exerciseSets.append(set)
        }
        try? context.save()
        return template
    }

    // MARK: - Update

    static func update(
        _ template: WorkoutTemplate,
        name: String,
        durationMinutes: Int?,
        exercises: [ExerciseData],
        context: ModelContext
    ) {
        let oldName = template.name
        template.name = name
        template.durationMinutes = durationMinutes

        for set in template.exerciseSets {
            context.delete(set)
        }
        template.exerciseSets = []

        for exercise in exercises {
            let set = TemplateExerciseSet(
                exerciseName: exercise.name,
                sets: exercise.sets,
                reps: exercise.reps,
                weightKg: exercise.weightKg,
                sortOrder: exercise.sortOrder
            )
            template.exerciseSets.append(set)
        }

        // Propagate name change to planned scheduled workouts
        if name != oldName {
            propagateNameChange(templateId: template.id, newName: name, context: context)
        }

        try? context.save()
    }

    /// Updates `workoutName` on all planned (not completed/skipped) scheduled workouts
    /// linked to the given template.
    private static func propagateNameChange(templateId: UUID, newName: String, context: ModelContext) {
        let planned = "planned"
        var descriptor = FetchDescriptor<ScheduledWorkout>(
            predicate: #Predicate<ScheduledWorkout> { sw in
                sw.templateId == templateId && sw.status == planned
            }
        )
        descriptor.fetchLimit = 500
        guard let scheduled = try? context.fetch(descriptor) else { return }
        for sw in scheduled {
            sw.workoutName = newName
        }
    }

    // MARK: - Delete

    static func delete(_ template: WorkoutTemplate, context: ModelContext) {
        context.delete(template)
        try? context.save()
    }

    // MARK: - Snapshot (data copy for pre-populating Log Workout form)

    // MARK: - Apply to Existing Workout (Edit Mode)

    static func applyToExistingWorkout(template: WorkoutTemplate, workout: Workout) {
        let baseSortOrder = (workout.exerciseSets.map(\.sortOrder).max() ?? -1) + 1
        for (offset, templateSet) in template.exerciseSets.sorted(by: { $0.sortOrder < $1.sortOrder }).enumerated() {
            let new = ExerciseSet(
                exerciseName: templateSet.exerciseName,
                sets: templateSet.sets,
                reps: templateSet.reps,
                weightKg: templateSet.weightKg,
                sortOrder: baseSortOrder + offset
            )
            workout.exerciseSets.append(new)
        }

        if workout.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            workout.name = template.name
        }

        if workout.healthKitUUID == nil && workout.durationMinutes == nil {
            workout.durationMinutes = template.durationMinutes
        }
    }

    // MARK: - Snapshot (data copy for pre-populating Log Workout form)

    static func snapshot(from template: WorkoutTemplate) -> TemplateSnapshot {
        let exercises = template.exerciseSets
            .sorted { $0.sortOrder < $1.sortOrder }
            .map {
                ExerciseData(
                    name: $0.exerciseName,
                    sets: $0.sets,
                    reps: $0.reps,
                    weightKg: $0.weightKg,
                    sortOrder: $0.sortOrder
                )
            }
        return TemplateSnapshot(
            name: template.name,
            workoutType: template.workoutType,
            durationMinutes: template.durationMinutes,
            exercises: exercises
        )
    }
}
