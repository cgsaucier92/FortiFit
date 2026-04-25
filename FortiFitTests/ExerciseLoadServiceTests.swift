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

struct ExerciseLoadServiceTests {

    // MARK: - Zone Classification (thresholds: 0 / 1–30 / 31–55 / 56–80 / 81–100)

    @Test func score0MapsToResting() {
        #expect(ExerciseLoadService.classifyZone(score: 0).zone == "Resting")
    }

    @Test func score1MapsToLow() {
        #expect(ExerciseLoadService.classifyZone(score: 1).zone == "Low")
    }

    @Test func score30MapsToLow() {
        #expect(ExerciseLoadService.classifyZone(score: 30).zone == "Low")
    }

    @Test func score31MapsToModerate() {
        #expect(ExerciseLoadService.classifyZone(score: 31).zone == "Moderate")
    }

    @Test func score55MapsToModerate() {
        #expect(ExerciseLoadService.classifyZone(score: 55).zone == "Moderate")
    }

    @Test func score56MapsToHigh() {
        #expect(ExerciseLoadService.classifyZone(score: 56).zone == "High")
    }

    @Test func score80MapsToHigh() {
        #expect(ExerciseLoadService.classifyZone(score: 80).zone == "High")
    }

    @Test func score81MapsToPeak() {
        #expect(ExerciseLoadService.classifyZone(score: 81).zone == "Peak")
    }

    @Test func score100MapsToPeak() {
        #expect(ExerciseLoadService.classifyZone(score: 100).zone == "Peak")
    }

    // MARK: - Volume Modifier

    @Test func volumeModifierZeroSetsReturnsHalf() throws {
        // Strength Training, 0 sets → clamp(0.5 + 0/20, 0.5, 1.5) = 0.5
        let context = try makeTestContext()
        let workout = Workout(name: "W", workoutType: "Strength Training")
        context.insert(workout)
        try context.save()
        #expect(ExerciseLoadService.volumeModifier(for: workout) == 0.5)
    }

    @Test func volumeModifier10SetsReturnsBaseline() throws {
        // 2 exercise records × 5 sets = 10 total → clamp(0.5 + 10/20, 0.5, 1.5) = 1.0
        let context = try makeTestContext()
        let workout = Workout(name: "W", workoutType: "Strength Training")
        context.insert(workout)
        let s1 = ExerciseSet(exerciseName: "Bench", sets: 5, reps: 8, weightKg: 80, sortOrder: 0)
        let s2 = ExerciseSet(exerciseName: "Squat", sets: 5, reps: 8, weightKg: 100, sortOrder: 1)
        context.insert(s1)
        context.insert(s2)
        workout.exerciseSets.append(s1)
        workout.exerciseSets.append(s2)
        try context.save()
        #expect(ExerciseLoadService.volumeModifier(for: workout) == 1.0)
    }

    @Test func volumeModifier20PlusSetsCapAt1Point5() throws {
        // 4 exercise records × 5 sets = 20 total → clamp(0.5 + 20/20, 0.5, 1.5) = 1.5
        let context = try makeTestContext()
        let workout = Workout(name: "W", workoutType: "Strength Training")
        context.insert(workout)
        for i in 0..<4 {
            let s = ExerciseSet(exerciseName: "Ex\(i)", sets: 5, reps: 8, weightKg: 80, sortOrder: i)
            context.insert(s)
            workout.exerciseSets.append(s)
        }
        try context.save()
        #expect(ExerciseLoadService.volumeModifier(for: workout) == 1.5)
    }

    @Test func volumeModifierCardioAlwaysReturns1() throws {
        let context = try makeTestContext()
        let workout = Workout(name: "W", workoutType: "Cardio")
        context.insert(workout)
        try context.save()
        #expect(ExerciseLoadService.volumeModifier(for: workout) == 1.0)
    }

    @Test func volumeModifierYogaAlwaysReturns1() throws {
        let context = try makeTestContext()
        let workout = Workout(name: "W", workoutType: "Yoga")
        context.insert(workout)
        try context.save()
        #expect(ExerciseLoadService.volumeModifier(for: workout) == 1.0)
    }

    @Test func volumeModifierHIITUsesFormula() throws {
        // HIIT with 12 sets → clamp(0.5 + 12/20, 0.5, 1.5) = 1.1
        let context = try makeTestContext()
        let workout = Workout(name: "W", workoutType: "HIIT")
        context.insert(workout)
        for i in 0..<2 {
            let s = ExerciseSet(exerciseName: "Burpee", sets: 6, reps: 10, weightKg: nil, sortOrder: i)
            context.insert(s)
            workout.exerciseSets.append(s)
        }
        try context.save()
        #expect(abs(ExerciseLoadService.volumeModifier(for: workout) - 1.1) < 0.001)
    }

    // MARK: - Session Stress

    @Test func sessionStressNilRPEDefaultsTo5() throws {
        // nil RPE → 5, 60 min, Yoga (0.3), vol = 1.0 → 5 × 1.0 × 0.3 × 1.0 = 1.5
        let context = try makeTestContext()
        let workout = Workout(name: "W", workoutType: "Yoga", durationMinutes: 60)
        context.insert(workout)
        try context.save()
        let stress = ExerciseLoadService.sessionStress(for: workout, targetMinutesPerWorkout: 52)
        #expect(abs(stress - 1.5) < 0.001)
    }

    @Test func sessionStressNilDurationUsesTargetMinutes() throws {
        // RPE 6, nil duration → uses targetMinutesPerWorkout (60), Cardio (0.7), vol = 1.0
        // 6 × (60/60) × 0.7 × 1.0 = 4.2
        let context = try makeTestContext()
        let workout = Workout(name: "W", workoutType: "Cardio", rpe: 6)
        context.insert(workout)
        try context.save()
        let stress = ExerciseLoadService.sessionStress(for: workout, targetMinutesPerWorkout: 60)
        #expect(abs(stress - 4.2) < 0.001)
    }

    // MARK: - Consecutive Days Multiplier

    @Test func consecutiveDaysMultiplierOneDayIs1Point0() throws {
        let context = try makeTestContext()
        let now = Date()
        let w = Workout(name: "W", date: now, workoutType: "Strength Training")
        context.insert(w)
        try context.save()
        let mult = ExerciseLoadService.consecutiveDaysMultiplier(workouts: [w], now: now)
        #expect(mult == 1.0)
    }

    @Test func consecutiveDaysMultiplierTwoDaysIs1Point08() throws {
        let context = try makeTestContext()
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let w1 = Workout(name: "W1", date: yesterday, workoutType: "Strength Training")
        let w2 = Workout(name: "W2", date: now, workoutType: "Strength Training")
        context.insert(w1)
        context.insert(w2)
        try context.save()
        let mult = ExerciseLoadService.consecutiveDaysMultiplier(workouts: [w1, w2], now: now)
        #expect(abs(mult - 1.08) < 0.001)
    }

    @Test func consecutiveDaysMultiplierFivePlusDaysCapAt1Point32() throws {
        let context = try makeTestContext()
        let now = Date()
        var workouts: [Workout] = []
        for i in 0...4 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: now)!
            let w = Workout(name: "W\(i)", date: date, workoutType: "Strength Training")
            context.insert(w)
            workouts.append(w)
        }
        try context.save()
        let mult = ExerciseLoadService.consecutiveDaysMultiplier(workouts: workouts, now: now)
        #expect(abs(mult - 1.32) < 0.001)
    }

    @Test func consecutiveDaysMultiplierReturns1WhenGapExists() throws {
        // Most recent workout was 3 days ago → consecutive = 0 → multiplier = 1.0
        let context = try makeTestContext()
        let now = Date()
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: now)!
        let w = Workout(name: "W", date: threeDaysAgo, workoutType: "Strength Training")
        context.insert(w)
        try context.save()
        let mult = ExerciseLoadService.consecutiveDaysMultiplier(workouts: [w], now: now)
        #expect(mult == 1.0)
    }

    // MARK: - Empty Input

    @Test func emptyWorkoutsReturnsResting() {
        let result = ExerciseLoadService.calculateLoad(
            workouts: [],
            experienceLevel: 1,
            targetMinutesPerWorkout: 60
        )
        #expect(result.score == 0)
        #expect(result.zone == "Resting")
    }

    // MARK: - Empty Workout Pre-Filter

    @Test func emptyWorkoutExcludedFromTrainingLoad() throws {
        // Workout with no exercises, nil RPE, nil duration → excluded entirely
        let context = try makeTestContext()
        let now = Date()
        let empty = Workout(name: "Empty", date: now, workoutType: "Strength Training")
        context.insert(empty)
        try context.save()
        let result = ExerciseLoadService.calculateLoad(
            workouts: [empty],
            experienceLevel: 1,
            targetMinutesPerWorkout: 60,
            now: now
        )
        #expect(result.score == 0)
        #expect(result.zone == "Resting")
    }

    @Test func partialDataWithRPEPassesFilter() throws {
        // No exercises, RPE = 7, nil duration → passes filter (RPE present)
        let context = try makeTestContext()
        let now = Date()
        let workout = Workout(name: "Yoga", date: now, workoutType: "Yoga", rpe: 7)
        context.insert(workout)
        try context.save()
        let result = ExerciseLoadService.calculateLoad(
            workouts: [workout],
            experienceLevel: 1,
            targetMinutesPerWorkout: 60,
            now: now
        )
        // Should contribute: RPE 7, duration fallback 60, Yoga modifier 0.3, vol 1.0
        // session_stress = 7 × (60/60) × 0.3 × 1.0 = 2.1
        #expect(result.score > 0)
    }

    @Test func partialDataWithDurationOnlyPassesFilter() throws {
        // No exercises, nil RPE, duration = 45 → passes filter (duration present)
        let context = try makeTestContext()
        let now = Date()
        let workout = Workout(name: "Cardio", date: now, workoutType: "Cardio", durationMinutes: 45)
        context.insert(workout)
        try context.save()
        let result = ExerciseLoadService.calculateLoad(
            workouts: [workout],
            experienceLevel: 1,
            targetMinutesPerWorkout: 60,
            now: now
        )
        // Should contribute: RPE defaults to 5, duration 45, Cardio modifier 0.7, vol 1.0
        #expect(result.score > 0)
    }

    @Test func emptyWorkoutDoesNotInflateConsecutiveDays() throws {
        // Day 1: real workout, Day 2: empty workout, Day 3: real workout
        // consecutive_days should be 2 (Day 2-3 skipped), not 3
        let context = try makeTestContext()
        let now = Date()
        let day1 = Calendar.current.date(byAdding: .day, value: -2, to: now)!
        let day2 = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let day3 = now

        let real1 = Workout(name: "ST1", date: day1, workoutType: "Strength Training", rpe: 7, durationMinutes: 60)
        let empty = Workout(name: "Empty", date: day2, workoutType: "Strength Training")
        let real2 = Workout(name: "ST2", date: day3, workoutType: "Strength Training", rpe: 7, durationMinutes: 60)
        context.insert(real1)
        context.insert(empty)
        context.insert(real2)
        try context.save()

        let allWorkouts = [real1, empty, real2]
        // Filter as calculateLoad would
        let qualifying = allWorkouts.filter { !ExerciseLoadService.isEmptyWorkout($0) }
        let consecutive = ExerciseLoadService.consecutiveDays(workouts: qualifying, now: now)
        // Day 3 has a workout, Day 2 does not (empty filtered out) → streak breaks → consecutive = 1
        #expect(consecutive == 1)
    }

    @Test func emptyWorkoutTodayDoesNotInflateSameDayFloor() throws {
        // Only an empty workout today → today_stress = 0, floor = 0
        let context = try makeTestContext()
        let now = Date()
        let empty = Workout(name: "Empty", date: now, workoutType: "Strength Training")
        context.insert(empty)
        try context.save()
        let result = ExerciseLoadService.calculateLoad(
            workouts: [empty],
            experienceLevel: 1,
            targetMinutesPerWorkout: 60,
            now: now
        )
        #expect(result.score == 0)
        #expect(result.zone == "Resting")
    }

    @Test func scoreIsCappedAtMaximum100() throws {
        // Extreme session right now should not exceed 100
        let context = try makeTestContext()
        let now = Date()
        let workout = Workout(name: "W", date: now, workoutType: "HIIT", rpe: 10, durationMinutes: 300)
        context.insert(workout)
        for i in 0..<10 {
            let s = ExerciseSet(exerciseName: "Ex\(i)", sets: 5, reps: 10, weightKg: nil, sortOrder: i)
            context.insert(s)
            workout.exerciseSets.append(s)
        }
        try context.save()
        let result = ExerciseLoadService.calculateLoad(
            workouts: [workout],
            experienceLevel: 0,
            targetMinutesPerWorkout: 60,
            now: now
        )
        #expect(result.score <= 100)
    }

    // MARK: - Advisory Text

    @Test func readinessAdvisoryLow() {
        #expect(ExerciseLoadService.classifyZone(score: 20, trainedToday: false).advisory == "Well recovered. Ready to train.")
    }

    @Test func postTrainingAdvisoryLow() {
        #expect(ExerciseLoadService.classifyZone(score: 20, trainedToday: true).advisory == "Session logged. You have more capacity to train again if you choose.")
    }

    @Test func readinessAdvisoryModerate() {
        #expect(ExerciseLoadService.classifyZone(score: 40, trainedToday: false).advisory == "Some muscle fatigue. A moderate session would be ideal.")
    }

    @Test func postTrainingAdvisoryModerate() {
        #expect(ExerciseLoadService.classifyZone(score: 40, trainedToday: true).advisory == "Good work today. Rest up.")
    }

    @Test func readinessAdvisoryHigh() {
        #expect(ExerciseLoadService.classifyZone(score: 70, trainedToday: false).advisory == "Significant muscle fatigue. Consider a lighter session or active recovery.")
    }

    @Test func postTrainingAdvisoryHigh() {
        #expect(ExerciseLoadService.classifyZone(score: 70, trainedToday: true).advisory == "Heavy day. Recovery is the priority.")
    }

    @Test func readinessAdvisoryPeak() {
        #expect(ExerciseLoadService.classifyZone(score: 90, trainedToday: false).advisory == "High physical stress. Rest or very light activity recommended.")
    }

    @Test func postTrainingAdvisoryPeak() {
        #expect(ExerciseLoadService.classifyZone(score: 90, trainedToday: true).advisory == "You've been pushing hard. Time to rest.")
    }

    /// calculateLoad uses post-training advisory when today's workout exists (PRD Example 4).
    @Test func calculateLoadPostTrainingAdvisoryWhenTrainedToday() throws {
        let context = try makeTestContext()
        let now = Date()
        let workout = Workout(name: "ST", date: now, workoutType: "Strength Training", rpe: 6, durationMinutes: 45)
        context.insert(workout)
        let s1 = ExerciseSet(exerciseName: "Bench", sets: 5, reps: 8, weightKg: 80, sortOrder: 0)
        let s2 = ExerciseSet(exerciseName: "Squat", sets: 5, reps: 8, weightKg: 100, sortOrder: 1)
        context.insert(s1)
        context.insert(s2)
        workout.exerciseSets.append(s1)
        workout.exerciseSets.append(s2)
        try context.save()
        let result = ExerciseLoadService.calculateLoad(
            workouts: [workout],
            experienceLevel: 1,
            targetMinutesPerWorkout: 60,
            now: now
        )
        // Score = 34 → Moderate, trained today → post-training variant
        #expect(result.advisory == "Good work today. Rest up.")
    }

    /// calculateLoad uses readiness advisory when no workouts exist for today.
    @Test func calculateLoadReadinessAdvisoryWhenNoWorkoutToday() throws {
        let context = try makeTestContext()
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let workout = Workout(name: "Yoga", date: yesterday, workoutType: "Yoga", rpe: 3, durationMinutes: 60)
        context.insert(workout)
        try context.save()
        let result = ExerciseLoadService.calculateLoad(
            workouts: [workout],
            experienceLevel: 1,
            targetMinutesPerWorkout: 60,
            now: now
        )
        // Yesterday's workout → floor = 0 → no trainedToday flag → readiness variant
        #expect(result.zone == "Low")
        #expect(result.advisory == "Well recovered. Ready to train.")
    }

    // MARK: - Same-Day Training Floor

    /// PRD Example 4: Intermediate (capacity=20), no prior workouts.
    /// Logs today: RPE 6, 45 min, Strength Training, 10 sets.
    /// Step 8 score = 22 (Low without floor) → floor = 34 → final = 34 → Moderate.
    @Test func prdExample4SameDayFloorIntermediate() throws {
        let context = try makeTestContext()
        let now = Date()
        let workout = Workout(name: "ST", date: now, workoutType: "Strength Training", rpe: 6, durationMinutes: 45)
        context.insert(workout)
        // 10 sets: 2 exercises × 5 sets each
        let s1 = ExerciseSet(exerciseName: "Bench", sets: 5, reps: 8, weightKg: 80, sortOrder: 0)
        let s2 = ExerciseSet(exerciseName: "Squat", sets: 5, reps: 8, weightKg: 100, sortOrder: 1)
        context.insert(s1)
        context.insert(s2)
        workout.exerciseSets.append(s1)
        workout.exerciseSets.append(s2)
        try context.save()
        let result = ExerciseLoadService.calculateLoad(
            workouts: [workout],
            experienceLevel: 1,
            targetMinutesPerWorkout: 60,
            now: now
        )
        // session_stress = 6 × (45/60) × 1.0 × 1.0 = 4.5
        // floor = clamp((4.5 / 20) × 150, 0, 80) = 33.75 → rounds to 34
        #expect(result.score.rounded() == 34)
        #expect(result.zone == "Moderate")
    }

    /// Floor caps at 80 — single day cannot reach Peak through the floor alone.
    /// Beginner (capacity=15), RPE 10, 60 min, Strength Training, 10 sets:
    ///   stress = 10 × 1.0 × 1.0 × 1.0 = 10
    ///   Step 8 score = (10/15) × 100 = 66.7 (High, but < 80)
    ///   Uncapped floor = (10/15) × 150 = 100 → capped to 80
    ///   Final = max(66.7, 80) = 80 → High (not Peak)
    @Test func sameDayFloorCapsAt80NeverReachesPeak() throws {
        let context = try makeTestContext()
        let now = Date()
        let workout = Workout(name: "Hard", date: now, workoutType: "Strength Training", rpe: 10, durationMinutes: 60)
        context.insert(workout)
        // 10 sets: 2 exercises × 5 sets each → volumeModifier = 1.0
        let s1 = ExerciseSet(exerciseName: "Squat", sets: 5, reps: 5, weightKg: 140, sortOrder: 0)
        let s2 = ExerciseSet(exerciseName: "Deadlift", sets: 5, reps: 5, weightKg: 160, sortOrder: 1)
        context.insert(s1)
        context.insert(s2)
        workout.exerciseSets.append(s1)
        workout.exerciseSets.append(s2)
        try context.save()
        let result = ExerciseLoadService.calculateLoad(
            workouts: [workout],
            experienceLevel: 0, // Beginner, capacity = 15
            targetMinutesPerWorkout: 60,
            now: now
        )
        #expect(result.score == 80)
        #expect(result.zone == "High")
    }

    /// Floor is zero when there are no workouts logged today — previous day's workout does not trigger the floor.
    @Test func sameDayFloorZeroForYesterdayWorkout() throws {
        let context = try makeTestContext()
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        // Intermediate, RPE 6, 45 min Strength Training, 10 sets — same params as Example 4 but yesterday
        let workout = Workout(name: "ST", date: yesterday, workoutType: "Strength Training", rpe: 6, durationMinutes: 45)
        context.insert(workout)
        let s1 = ExerciseSet(exerciseName: "Bench", sets: 5, reps: 8, weightKg: 80, sortOrder: 0)
        let s2 = ExerciseSet(exerciseName: "Squat", sets: 5, reps: 8, weightKg: 100, sortOrder: 1)
        context.insert(s1)
        context.insert(s2)
        workout.exerciseSets.append(s1)
        workout.exerciseSets.append(s2)
        try context.save()
        let result = ExerciseLoadService.calculateLoad(
            workouts: [workout],
            experienceLevel: 1,
            targetMinutesPerWorkout: 60,
            now: now
        )
        // No same-day workouts → floor = 0; score driven purely by decay
        // session_stress = 4.5, decayed 1 day: 4.5 × e^(-1/2.0) ≈ 2.73 → score ≈ 14 → Low (not lifted to 34)
        #expect(result.zone == "Low")
    }

    // MARK: - PRD Example Calculations

    /// PRD Example 1: Intermediate (τ=2.0, capacity=20)
    /// Mon/Wed/Fri Strength Training, RPE 6, 45 min, 12 sets each.
    /// Calculating on Friday evening. Expected score ≈ 37 → Moderate.
    @Test func prdExample1IntermediateWellSpacedWeek() throws {
        let context = try makeTestContext()
        let now = Date()
        let friday = now
        let wednesday = Calendar.current.date(byAdding: .day, value: -2, to: now)!
        let monday = Calendar.current.date(byAdding: .day, value: -4, to: now)!

        func makeSession(date: Date) -> Workout {
            let w = Workout(name: "ST", date: date, workoutType: "Strength Training", rpe: 6, durationMinutes: 45)
            context.insert(w)
            // 12 total sets: 2 exercises × 6 sets each
            let s1 = ExerciseSet(exerciseName: "Bench", sets: 6, reps: 8, weightKg: 80, sortOrder: 0)
            let s2 = ExerciseSet(exerciseName: "Squat", sets: 6, reps: 8, weightKg: 100, sortOrder: 1)
            context.insert(s1)
            context.insert(s2)
            w.exerciseSets.append(s1)
            w.exerciseSets.append(s2)
            return w
        }

        let workouts = [makeSession(date: friday), makeSession(date: wednesday), makeSession(date: monday)]
        try context.save()
        let result = ExerciseLoadService.calculateLoad(
            workouts: workouts,
            experienceLevel: 1,
            targetMinutesPerWorkout: 60,
            now: now
        )
        // PRD: score = 37 → Moderate
        #expect(result.score.rounded() == 37)
        #expect(result.zone == "Moderate")
    }

    /// PRD Example 2: Beginner (τ=3.0, capacity=15)
    /// Tue + Wed Strength Training, RPE 9, 60 min, 16 sets each.
    /// Calculating on Thursday. Expected score = 100 (capped) → Peak.
    @Test func prdExample2BeginnerConsecutiveHardSessions() throws {
        let context = try makeTestContext()
        let now = Date()
        let wednesday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let tuesday = Calendar.current.date(byAdding: .day, value: -2, to: now)!

        func makeSession(date: Date) -> Workout {
            let w = Workout(name: "ST", date: date, workoutType: "Strength Training", rpe: 9, durationMinutes: 60)
            context.insert(w)
            // 16 total sets: 2 exercises × 8 sets each
            let s1 = ExerciseSet(exerciseName: "Squat", sets: 8, reps: 5, weightKg: 120, sortOrder: 0)
            let s2 = ExerciseSet(exerciseName: "Deadlift", sets: 8, reps: 5, weightKg: 140, sortOrder: 1)
            context.insert(s1)
            context.insert(s2)
            w.exerciseSets.append(s1)
            w.exerciseSets.append(s2)
            return w
        }

        let workouts = [makeSession(date: wednesday), makeSession(date: tuesday)]
        try context.save()
        let result = ExerciseLoadService.calculateLoad(
            workouts: workouts,
            experienceLevel: 0,
            targetMinutesPerWorkout: 60,
            now: now
        )
        // PRD: score = 100 (capped) → Peak
        #expect(result.score == 100)
        #expect(result.zone == "Peak")
    }

    /// PRD Example 3: Advanced (τ=1.5, capacity=25)
    /// Monday HIIT: RPE 8, 30 min, 8 sets. Tuesday Yoga: RPE 4, 60 min.
    /// Calculating Tuesday evening. Expected score ≈ 14 → Low.
    @Test func prdExample3AdvancedMixedSessionTypes() throws {
        let context = try makeTestContext()
        let now = Date()
        let tuesday = now
        let monday = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        let hiit = Workout(name: "HIIT", date: monday, workoutType: "HIIT", rpe: 8, durationMinutes: 30)
        context.insert(hiit)
        // 8 total sets: 2 exercises × 4 sets each
        let s1 = ExerciseSet(exerciseName: "Burpees", sets: 4, reps: 10, weightKg: nil, sortOrder: 0)
        let s2 = ExerciseSet(exerciseName: "Sprints", sets: 4, reps: 10, weightKg: nil, sortOrder: 1)
        context.insert(s1)
        context.insert(s2)
        hiit.exerciseSets.append(s1)
        hiit.exerciseSets.append(s2)

        let yoga = Workout(name: "Yoga", date: tuesday, workoutType: "Yoga", rpe: 4, durationMinutes: 60)
        context.insert(yoga)
        try context.save()

        let result = ExerciseLoadService.calculateLoad(
            workouts: [hiit, yoga],
            experienceLevel: 2,
            targetMinutesPerWorkout: 60,
            now: now
        )
        // PRD: score ≈ 14 → Low
        #expect(result.score.rounded() == 14)
        #expect(result.zone == "Low")
    }
}
