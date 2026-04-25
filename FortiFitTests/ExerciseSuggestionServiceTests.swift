import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// Helper to create an in-memory SwiftData context for testing.
private func makeTestContext() throws -> ModelContext {
    let schema = Schema([Workout.self, ExerciseSet.self, Goal.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

struct ExerciseSuggestionServiceTests {

    // MARK: - Ranking Tests

    @Test func prefixMatchRanksAboveContainsMatch() {
        let results = ExerciseSuggestionService.suggest(
            query: "Bench",
            history: [],
            dictionary: ["Incline Bench Press", "Bench Press", "Dumbbell Bench Press"],
            aliasMap: [:]
        )
        // "Bench Press" is a prefix match; the others are contains matches
        #expect(results.first?.name == "Bench Press")
    }

    @Test func historyRanksAboveDictionaryWithinSameTier() {
        let results = ExerciseSuggestionService.suggest(
            query: "Bench",
            history: ["Bench Press"],
            dictionary: ["Bench Press", "Bench Dips"],
            aliasMap: [:]
        )
        #expect(results[0].name == "Bench Press")
        #expect(results[0].isFromHistory == true)
        // Dictionary entry "Bench Dips" should follow
        #expect(results[1].name == "Bench Dips")
        #expect(results[1].isFromHistory == false)
    }

    // MARK: - Alias Tests

    @Test func aliasOHPResolvesToOverheadPress() {
        let results = ExerciseSuggestionService.suggest(
            query: "OHP",
            history: [],
            dictionary: AppConstants.exerciseDictionary,
            aliasMap: AppConstants.exerciseAliasMap
        )
        #expect(results.contains { $0.name == "Overhead Press" })
    }

    @Test func aliasMatchIsCaseInsensitive() {
        let results = ExerciseSuggestionService.suggest(
            query: "ohp",
            history: [],
            dictionary: AppConstants.exerciseDictionary,
            aliasMap: AppConstants.exerciseAliasMap
        )
        #expect(results.contains { $0.name == "Overhead Press" })
    }

    // MARK: - Deduplication Tests

    @Test func deduplicationHistoryWinsOverDictionary() {
        let results = ExerciseSuggestionService.suggest(
            query: "Bench",
            history: ["Bench Press"],
            dictionary: ["Bench Press", "Bench Dips"],
            aliasMap: [:]
        )
        let benchEntries = results.filter { $0.name == "Bench Press" }
        #expect(benchEntries.count == 1)
        #expect(benchEntries.first?.isFromHistory == true)
    }

    // MARK: - Edge Cases

    @Test func emptyQueryReturnsEmptyList() {
        let results = ExerciseSuggestionService.suggest(
            query: "",
            history: ["Bench Press"],
            dictionary: AppConstants.exerciseDictionary,
            aliasMap: AppConstants.exerciseAliasMap
        )
        #expect(results.isEmpty)
    }

    @Test func whitespaceOnlyQueryReturnsEmptyList() {
        let results = ExerciseSuggestionService.suggest(
            query: "   ",
            history: ["Bench Press"],
            dictionary: AppConstants.exerciseDictionary,
            aliasMap: AppConstants.exerciseAliasMap
        )
        #expect(results.isEmpty)
    }

    @Test func noMatchQueryReturnsEmptyList() {
        let results = ExerciseSuggestionService.suggest(
            query: "Zzzzzflurble",
            history: [],
            dictionary: AppConstants.exerciseDictionary,
            aliasMap: AppConstants.exerciseAliasMap
        )
        #expect(results.isEmpty)
    }

    // MARK: - Closest-Match Nudge (Levenshtein)

    @Test func closestMatchNudgeEditDistance1() {
        let results = ExerciseSuggestionService.suggest(
            query: "Bech Press",
            history: [],
            dictionary: ["Bench Press"],
            aliasMap: [:]
        )
        #expect(results.count == 1)
        #expect(results[0].name == "Bench Press")
    }

    @Test func closestMatchNudgeEditDistance2() {
        let results = ExerciseSuggestionService.suggest(
            query: "Bnch Pres",
            history: [],
            dictionary: ["Bench Press"],
            aliasMap: [:]
        )
        // "bnch pres" vs "bench press" — edit distance 2
        #expect(results.count == 1)
        #expect(results[0].name == "Bench Press")
    }

    // MARK: - Max Results Cap

    @Test func maximumFiveResults() {
        let results = ExerciseSuggestionService.suggest(
            query: "B",
            history: [],
            dictionary: AppConstants.exerciseDictionary,
            aliasMap: AppConstants.exerciseAliasMap
        )
        #expect(results.count <= 5)
    }

    // MARK: - History Integration

    @Test func fetchExerciseHistoryReturnsNamesFromSavedWorkouts() throws {
        let context = try makeTestContext()
        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let set1 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 8, weightKg: 80, sortOrder: 0)
        let set2 = ExerciseSet(exerciseName: "Overhead Press", sets: 3, reps: 8, weightKg: 40, sortOrder: 1)
        workout.exerciseSets.append(set1)
        workout.exerciseSets.append(set2)
        WorkoutService.logWorkout(workout, context: context)

        let history = ExerciseSuggestionService.fetchExerciseHistory(context: context)
        #expect(history.contains("Bench Press"))
        #expect(history.contains("Overhead Press"))
    }

    @Test func historyOrderedByFrequency() throws {
        let context = try makeTestContext()

        // Log "Bench Press" twice, "Overhead Press" once
        let workout1 = Workout(name: "Day 1", workoutType: "Strength Training")
        workout1.exerciseSets.append(ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 8, weightKg: 80, sortOrder: 0))
        WorkoutService.logWorkout(workout1, context: context)

        let workout2 = Workout(name: "Day 2", workoutType: "Strength Training")
        workout2.exerciseSets.append(ExerciseSet(exerciseName: "Bench Press", sets: 4, reps: 6, weightKg: 85, sortOrder: 0))
        workout2.exerciseSets.append(ExerciseSet(exerciseName: "Overhead Press", sets: 3, reps: 8, weightKg: 40, sortOrder: 1))
        WorkoutService.logWorkout(workout2, context: context)

        let history = ExerciseSuggestionService.fetchExerciseHistory(context: context)
        guard let benchIndex = history.firstIndex(of: "Bench Press"),
              let ohpIndex = history.firstIndex(of: "Overhead Press") else {
            #expect(Bool(false), "Expected both exercises in history")
            return
        }
        #expect(benchIndex < ohpIndex, "Bench Press (frequency 2) should rank before Overhead Press (frequency 1)")
    }

    // MARK: - Levenshtein Distance

    @Test func levenshteinDistanceCorrectness() {
        #expect(ExerciseSuggestionService.levenshteinDistance("kitten", "sitting") == 3)
        #expect(ExerciseSuggestionService.levenshteinDistance("", "abc") == 3)
        #expect(ExerciseSuggestionService.levenshteinDistance("abc", "") == 3)
        #expect(ExerciseSuggestionService.levenshteinDistance("bench", "bench") == 0)
        #expect(ExerciseSuggestionService.levenshteinDistance("bech", "bench") == 1)
    }
}
