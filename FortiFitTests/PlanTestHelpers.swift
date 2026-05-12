import Foundation
import SwiftData
@testable import FortiFit

/// Creates an in-memory SwiftData context for Plan test isolation.
/// Includes all model types needed by PlanService and its dependencies.
func makePlanTestContext() throws -> ModelContext {
    let schema = Schema([
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
        WorkoutMatchRejection.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

/// Factory methods for creating test entities with sensible defaults.
enum PlanTestFactory {

    @MainActor
    static func makeTemplate(
        name: String = "Push Day",
        workoutType: String = "Strength Training",
        durationMinutes: Int? = 60,
        exercises: [(name: String, sets: Int, reps: Int, weight: Double?)] = [
            ("Bench Press", 4, 8, 80.0),
            ("Overhead Press", 3, 10, 40.0),
            ("Tricep Pushdowns", 3, 12, nil)
        ],
        context: ModelContext
    ) -> WorkoutTemplate {
        let template = WorkoutTemplate(
            name: name,
            workoutType: workoutType,
            durationMinutes: durationMinutes
        )
        context.insert(template)
        for (index, ex) in exercises.enumerated() {
            let set = TemplateExerciseSet(
                exerciseName: ex.name,
                sets: ex.sets,
                reps: ex.reps,
                weightKg: ex.weight,
                sortOrder: index
            )
            template.exerciseSets.append(set)
            context.insert(set)
        }
        try? context.save()
        return template
    }

    /// Returns a Date with time zeroed to start of day, offset by the given number of days from today.
    static func date(daysFromToday offset: Int) -> Date {
        Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: offset, to: Date())!)
    }

    static var today: Date { date(daysFromToday: 0) }
    static var yesterday: Date { date(daysFromToday: -1) }
    static var tomorrow: Date { date(daysFromToday: 1) }
}
