import Foundation
import SwiftData

struct ExerciseSuggestionService {

    // MARK: - Suggestion Result

    struct Suggestion: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let isFromHistory: Bool

        static func == (lhs: Suggestion, rhs: Suggestion) -> Bool {
            lhs.name == rhs.name && lhs.isFromHistory == rhs.isFromHistory
        }
    }

    // MARK: - History Extraction

    /// Fetches all unique exercise names from persisted workouts, ordered by
    /// frequency (most used first). Called by ViewModels after save/delete.
    static func fetchExerciseHistory(context: ModelContext) -> [String] {
        let workouts = WorkoutService.fetchAll(context: context)
        var frequency: [String: Int] = [:]
        for workout in workouts {
            for exerciseSet in workout.exerciseSets {
                let name = exerciseSet.exerciseName
                frequency[name, default: 0] += 1
            }
        }
        return frequency.sorted { $0.value > $1.value }.map { $0.key }
    }

    // MARK: - Suggestion Engine

    /// Returns up to 5 ranked suggestions for the given query.
    ///
    /// Ranking: prefix match > contains match; within each tier, history > dictionary.
    /// Also resolves aliases and applies closest-match nudge (edit distance <= 2).
    static func suggest(
        query: String,
        history: [String],
        dictionary: [String] = AppConstants.exerciseDictionary,
        aliasMap: [String: String] = AppConstants.exerciseAliasMap
    ) -> [Suggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        let lowerQuery = trimmed.lowercased()

        // 1. Collect candidates from history and dictionary
        var prefixHistory: [String] = []
        var containsHistory: [String] = []
        var prefixDict: [String] = []
        var containsDict: [String] = []
        var seen = Set<String>() // lowercase names for dedup

        // History first (wins dedup)
        for name in history {
            let lower = name.lowercased()
            if lower.hasPrefix(lowerQuery) {
                guard seen.insert(lower).inserted else { continue }
                prefixHistory.append(name)
            } else if lower.contains(lowerQuery) {
                guard seen.insert(lower).inserted else { continue }
                containsHistory.append(name)
            }
        }

        // Dictionary (dedup against matched history entries)
        for name in dictionary {
            let lower = name.lowercased()
            if lower.hasPrefix(lowerQuery) {
                guard seen.insert(lower).inserted else { continue }
                prefixDict.append(name)
            } else if lower.contains(lowerQuery) {
                guard seen.insert(lower).inserted else { continue }
                containsDict.append(name)
            }
        }

        // 2. Check aliases (case-insensitive)
        var aliasResolved: [String] = []
        for (alias, canonical) in aliasMap {
            if alias.lowercased().hasPrefix(lowerQuery) || alias.lowercased() == lowerQuery {
                let canonLower = canonical.lowercased()
                if !seen.contains(canonLower) {
                    seen.insert(canonLower)
                    aliasResolved.append(canonical)
                }
            }
        }

        // 3. Build ranked list: prefix-history > prefix-dict > prefix-alias > contains-history > contains-dict
        var results: [Suggestion] = []

        for name in prefixHistory {
            results.append(Suggestion(name: name, isFromHistory: true))
        }
        for name in prefixDict {
            results.append(Suggestion(name: name, isFromHistory: false))
        }
        for name in aliasResolved {
            let fromHistory = history.contains { $0.lowercased() == name.lowercased() }
            results.append(Suggestion(name: name, isFromHistory: fromHistory))
        }
        for name in containsHistory {
            results.append(Suggestion(name: name, isFromHistory: true))
        }
        for name in containsDict {
            results.append(Suggestion(name: name, isFromHistory: false))
        }

        // 4. If no results, try closest-match nudge (Levenshtein distance <= 2)
        if results.isEmpty {
            let allCandidates: [(name: String, fromHistory: Bool)] =
                history.map { ($0, true) } +
                dictionary.filter { name in
                    !history.contains { $0.lowercased() == name.lowercased() }
                }.map { ($0, false) }

            var bestMatch: (name: String, distance: Int, fromHistory: Bool)?
            for candidate in allCandidates {
                let dist = levenshteinDistance(lowerQuery, candidate.name.lowercased())
                if dist <= 2 {
                    if bestMatch == nil || dist < bestMatch!.distance {
                        bestMatch = (candidate.name, dist, candidate.fromHistory)
                    }
                }
            }
            if let match = bestMatch {
                results.append(Suggestion(name: match.name, isFromHistory: match.fromHistory))
            }
        }

        // 5. Cap at 5 results
        return Array(results.prefix(5))
    }

    // MARK: - Isometric Lookup

    static func isIsometric(
        _ exerciseName: String,
        aliasMap: [String: String] = AppConstants.exerciseAliasMap,
        isometricNames: Set<String> = AppConstants.isometricExerciseNames,
        ambiguousDefaults: [String: Bool] = AppConstants.ambiguousExerciseDefaultModes
    ) -> Bool {
        let resolved = aliasMap[exerciseName] ?? exerciseName

        if isometricNames.contains(resolved) { return true }

        if let isTime = ambiguousDefaults[resolved] { return isTime }

        return false
    }

    // MARK: - Levenshtein Distance

    static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let m = s1.count
        let n = s2.count
        if m == 0 { return n }
        if n == 0 { return m }

        let s1Array = Array(s1)
        let s2Array = Array(s2)
        var dp = Array(0...n)

        for i in 1...m {
            var prev = dp[0]
            dp[0] = i
            for j in 1...n {
                let temp = dp[j]
                if s1Array[i - 1] == s2Array[j - 1] {
                    dp[j] = prev
                } else {
                    dp[j] = 1 + min(prev, dp[j], dp[j - 1])
                }
                prev = temp
            }
        }
        return dp[n]
    }
}
