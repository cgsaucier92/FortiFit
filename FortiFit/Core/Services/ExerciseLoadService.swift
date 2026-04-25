import Foundation

struct ExerciseLoadService {

    /// The result of a load calculation.
    struct LoadResult {
        let score: Double
        let zone: String
        let zoneColor: String  // hex color
        let advisory: String
    }

    // MARK: - Experience-Based Constants

    /// τ (tau): Exponential decay constant in days.
    /// Beginner (0) = 3.0, Intermediate (1) = 2.0, Advanced (2) = 1.5.
    static func decayConstant(for experienceLevel: Int) -> Double {
        switch experienceLevel {
        case 0: return 3.0   // Beginner: stress lingers longest
        case 1: return 2.0   // Intermediate: moderate recovery
        case 2: return 1.5   // Advanced: fastest recovery
        default: return 2.0
        }
    }

    /// Stress capacity: the accumulated stress that represents a fully fatigued state.
    /// Beginner (0) = 15, Intermediate (1) = 20, Advanced (2) = 25.
    static func stressCapacity(for experienceLevel: Int) -> Double {
        switch experienceLevel {
        case 0: return 15.0
        case 1: return 20.0
        case 2: return 25.0
        default: return 20.0
        }
    }

    // MARK: - Per-Session Factors

    /// Returns the workout type modifier for a given workout type string.
    static func typeModifier(for workoutType: String) -> Double {
        return AppConstants.workoutTypeModifiers[workoutType] ?? 1.0
    }

    /// Returns the volume modifier for a workout.
    /// Strength Training / HIIT: clamp(0.5 + totalSets/20, 0.5, 1.5).
    /// All other types: 1.0.
    static func volumeModifier(for workout: Workout) -> Double {
        let strengthTypes = ["Strength Training", "HIIT"]
        guard strengthTypes.contains(workout.workoutType) else { return 1.0 }
        let totalSets = workout.exerciseSets.reduce(0) { $0 + $1.sets }
        let raw = 0.5 + Double(totalSets) / 20.0
        return min(max(raw, 0.5), 1.5)
    }

    /// Calculates the per-session stress for a single workout.
    /// session_stress = RPE × (duration_minutes / 60) × type_modifier × volume_modifier
    static func sessionStress(for workout: Workout, targetMinutesPerWorkout: Int) -> Double {
        let rpe = Double(workout.rpe ?? 5)
        let duration = Double(workout.durationMinutes ?? targetMinutesPerWorkout)
        let typeMod = typeModifier(for: workout.workoutType)
        let volMod = volumeModifier(for: workout)
        return rpe * (duration / 60.0) * typeMod * volMod
    }

    // MARK: - Consecutive Training Days

    /// Counts consecutive calendar days ending on today or yesterday that each have ≥1 workout.
    /// If the most recent workout was 2 or more days ago, returns 0.
    static func consecutiveDays(workouts: [Workout], now: Date) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let workoutDates = Set(workouts.map { calendar.startOfDay(for: $0.date) })

        // The streak must end on today or yesterday
        guard workoutDates.contains(today) || workoutDates.contains(yesterday) else {
            return 0
        }

        var day = workoutDates.contains(today) ? today : yesterday
        var count = 0
        while workoutDates.contains(day) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    /// Returns the consecutive training days multiplier.
    /// 1.0 + max(consecutiveDays - 1, 0) × 0.08, capped at 1.32 (5+ days).
    static func consecutiveDaysMultiplier(workouts: [Workout], now: Date) -> Double {
        let days = consecutiveDays(workouts: workouts, now: now)
        let raw = 1.0 + Double(max(days - 1, 0)) * 0.08
        return min(raw, 1.32)
    }

    // MARK: - Main Calculation

    /// Calculates the daily training load score (0–100) using a 10-day exponential decay model.
    ///
    /// - Parameters:
    ///   - workouts: All workouts within the 10-day lookback window
    ///   - experienceLevel: 0=Beginner, 1=Intermediate, 2=Advanced
    ///   - targetMinutesPerWorkout: Fallback duration when workout.durationMinutes is nil
    ///   - now: Reference date for decay calculation (defaults to current time)
    /// Returns true if the workout is an empty shell (no exercises, no RPE, no duration)
    /// and should be excluded from Training Load calculations.
    static func isEmptyWorkout(_ workout: Workout) -> Bool {
        return workout.exerciseSets.isEmpty && workout.rpe == nil && workout.durationMinutes == nil
    }

    static func calculateLoad(
        workouts: [Workout],
        experienceLevel: Int,
        targetMinutesPerWorkout: Int,
        now: Date = Date()
    ) -> LoadResult {
        // Pre-Filter: exclude empty workouts (no exercises, no RPE, no duration)
        let qualifyingWorkouts = workouts.filter { !isEmptyWorkout($0) }

        guard !qualifyingWorkouts.isEmpty else {
            return classifyZone(score: 0)
        }

        let tau = decayConstant(for: experienceLevel)
        let capacity = stressCapacity(for: experienceLevel)

        // Sum time-decayed stress for all workouts in the window
        let rawStress = qualifyingWorkouts.reduce(0.0) { sum, workout in
            let stress = sessionStress(for: workout, targetMinutesPerWorkout: targetMinutesPerWorkout)
            let daysAgo = now.timeIntervalSince(workout.date) / 86400.0
            let decayed = stress * exp(-daysAgo / tau)
            return sum + decayed
        }

        // Apply consecutive training days multiplier
        let consecutiveMultiplier = consecutiveDaysMultiplier(workouts: qualifyingWorkouts, now: now)
        let adjustedStress = rawStress * consecutiveMultiplier

        // Step 8 — Normalize to 0–100
        let score = min(max((adjustedStress / capacity) * 100.0, 0.0), 100.0)

        // Step 9 — Same-Day Training Floor
        // Prevents the score from understating fatigue on a day the user has already trained.
        // floor = clamp((today_stress / stress_capacity) × 150, 0, 80)
        // Cap at 80 so a single day's training can never push into Peak on its own.
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        let todayStress = qualifyingWorkouts
            .filter { calendar.startOfDay(for: $0.date) == todayStart }
            .reduce(0.0) { $0 + sessionStress(for: $1, targetMinutesPerWorkout: targetMinutesPerWorkout) }
        let floor = min(max((todayStress / capacity) * 150.0, 0.0), 80.0)
        let finalScore = max(score, floor)
        let trainedToday = todayStress > 0

        return classifyZone(score: finalScore, trainedToday: trainedToday)
    }

    // MARK: - Zone Classification

    /// Classifies a score (0–100) into a zone with color and advisory text.
    /// - Parameter trainedToday: Pass `true` if the user has logged at least one workout today.
    ///   Shows post-training advisory variants instead of readiness variants.
    static func classifyZone(score: Double, trainedToday: Bool = false) -> LoadResult {
        let rounded = score.rounded()

        if rounded <= 0 {
            return LoadResult(
                score: score,
                zone: "Resting",
                zoneColor: "737373",
                advisory: "No recent training stress. Ready for a full session."
            )
        } else if rounded <= 30 {
            return LoadResult(
                score: score,
                zone: "Low",
                zoneColor: "10b981",
                advisory: trainedToday
                    ? "Session logged. You have more capacity to train again if you choose."
                    : "Well recovered. Ready to train."
            )
        } else if rounded <= 55 {
            return LoadResult(
                score: score,
                zone: "Moderate",
                zoneColor: "C4F648",
                advisory: trainedToday
                    ? "Good work today. Rest up."
                    : "Some muscle fatigue. A moderate session would be ideal."
            )
        } else if rounded <= 80 {
            return LoadResult(
                score: score,
                zone: "High",
                zoneColor: "B7FF00",
                advisory: trainedToday
                    ? "Recovery is the priority."
                    : "Significant muscle fatigue. Consider a lighter session or active recovery."
            )
        } else {
            return LoadResult(
                score: score,
                zone: "Peak",
                zoneColor: "ef4444",
                advisory: trainedToday
                    ? "You've been pushing hard. Time to rest."
                    : "High physical stress. Rest or very light activity recommended."
            )
        }
    }
}
