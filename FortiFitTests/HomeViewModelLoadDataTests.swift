import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// Regression coverage for BUG-056: the linked Recovery & Load Settings Modal's
/// `onDismiss` closure must trigger a Training Load recompute when the user
/// changes Training Experience (or Target Workout Duration). The fix wires
/// `viewModel.loadData(context:)` into that closure so the next render reflects
/// the just-mutated `UserSettings`. This test pins the contract `loadData`
/// must uphold: a subsequent call picks up `UserSettings.experienceLevel`
/// changes and produces a different `loadResult.score` against the same
/// workout history. If `loadData` ever caches or skips the recompute, the
/// dismiss closure becomes a no-op for the user and the bug returns.
@MainActor
struct HomeViewModelLoadDataTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Workout.self,
            ExerciseSet.self,
            Goal.self,
            WorkoutTypeOrder.self,
            WorkoutTemplate.self,
            TemplateExerciseSet.self,
            HomeWidget.self,
            TrendsChart.self,
            ScheduledWorkout.self,
            GoalSnapshot.self,
            WorkoutMatchRejection.self,
            DailySleepSnapshot.self,
            DailyTrainingLoadSnapshot.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    /// Insert a single Strength session yesterday with enough volume + RPE that
    /// experience-level differences move the resulting score meaningfully.
    private func insertHighEffortSession(context: ModelContext, now: Date) throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let workout = Workout(
            name: "Heavy Lower",
            date: yesterday,
            workoutType: "Strength Training",
            rpe: 9,
            durationMinutes: 75
        )
        context.insert(workout)
        let squat = ExerciseSet(exerciseName: "Squat", sets: 5, reps: 5, weightKg: 140, sortOrder: 0)
        let deadlift = ExerciseSet(exerciseName: "Deadlift", sets: 5, reps: 5, weightKg: 160, sortOrder: 1)
        context.insert(squat)
        context.insert(deadlift)
        workout.exerciseSets.append(squat)
        workout.exerciseSets.append(deadlift)
        try context.save()
    }

    /// BUG-056 regression: `HomeViewModel.loadData(context:)` must re-read
    /// `UserSettings.experienceLevel` and produce a fresh `loadResult` on every
    /// call. This is the contract the linked-modal dismiss closure now relies on.
    @Test func test_loadDataRecomputesLoadResult_whenExperienceLevelChangesBetweenCalls() throws {
        let context = try makeContext()
        let now = Date()
        try insertHighEffortSession(context: context, now: now)

        let settings = UserSettings.shared
        let originalExperience = settings.experienceLevel
        defer { settings.experienceLevel = originalExperience }

        let viewModel = HomeViewModel()

        settings.experienceLevel = 0 // Beginner — lowest capacity, highest score for same volume
        viewModel.loadData(context: context)
        let beginnerScore = viewModel.loadResult.score

        settings.experienceLevel = 2 // Advanced — highest capacity, lowest score for same volume
        viewModel.loadData(context: context)
        let advancedScore = viewModel.loadResult.score

        #expect(
            beginnerScore != advancedScore,
            "loadData must reflect UserSettings.experienceLevel on each call (BUG-056). Beginner=\(beginnerScore), Advanced=\(advancedScore)"
        )
        // Sanity check the directional relationship: same volume + RPE produces a
        // higher Training Load for a less-experienced athlete (smaller capacity).
        #expect(beginnerScore > advancedScore)
    }
}
