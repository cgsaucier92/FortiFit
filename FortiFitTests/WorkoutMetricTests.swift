import Testing
import Foundation
import SwiftData
@testable import FortiFit

private func makeTestContext() throws -> ModelContext {
    let schema = Schema([
        Workout.self, ExerciseSet.self, Goal.self, GoalSnapshot.self,
        WorkoutTypeOrder.self, WorkoutMatchRejection.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

// MARK: - Effort Label Mapping Tests

struct EffortLabelTests {

    @Test func effortLabelMapping_returnsCorrectBandForEveryInteger() {
        #expect(AppConstants.effortLabel(for: 1) == "Easy")
        #expect(AppConstants.effortLabel(for: 2) == "Easy")
        #expect(AppConstants.effortLabel(for: 3) == "Light")
        #expect(AppConstants.effortLabel(for: 4) == "Light")
        #expect(AppConstants.effortLabel(for: 5) == "Moderate")
        #expect(AppConstants.effortLabel(for: 6) == "Moderate")
        #expect(AppConstants.effortLabel(for: 7) == "Hard")
        #expect(AppConstants.effortLabel(for: 8) == "Hard")
        #expect(AppConstants.effortLabel(for: 9) == "All Out")
        #expect(AppConstants.effortLabel(for: 10) == "All Out")
    }

    @Test func effortLabelMapping_outOfRange_returnsUnknown() {
        #expect(AppConstants.effortLabel(for: 0) == "Unknown")
        #expect(AppConstants.effortLabel(for: 11) == "Unknown")
        #expect(AppConstants.effortLabel(for: -1) == "Unknown")
    }
}

// MARK: - WorkoutMetricService Tests

@MainActor
struct WorkoutMetricServiceTests {

    @Test func comparativeAverage_excludesCurrentWorkout() throws {
        let context = try makeTestContext()

        let durations = [30, 40, 50, 60, 70]
        for dur in durations {
            let w = Workout(name: "Strength \(dur)", workoutType: "Strength Training", durationMinutes: dur)
            context.insert(w)
        }

        let current = Workout(name: "Current", workoutType: "Strength Training", durationMinutes: 100)
        context.insert(current)
        try context.save()

        let avg = WorkoutMetricService.comparativeAverage(for: .duration, workout: current, context: context)
        let expectedAvg = Double(durations.reduce(0, +)) / Double(durations.count)
        #expect(avg != nil)
        #expect(abs(avg! - expectedAvg) < 0.001, "Average should be mean of the other 5, not 6")
    }

    @Test func comparativeAverage_returnsNilWhenInsufficientData() throws {
        let context = try makeTestContext()

        let w1 = Workout(name: "W1", workoutType: "Cardio", durationMinutes: 30)
        let w2 = Workout(name: "W2", workoutType: "Cardio", durationMinutes: 40)
        context.insert(w1)
        context.insert(w2)

        let current = Workout(name: "Current", workoutType: "Cardio", durationMinutes: 50)
        context.insert(current)
        try context.save()

        let avg = WorkoutMetricService.comparativeAverage(for: .duration, workout: current, context: context)
        #expect(avg == nil, "Fewer than 3 same-type workouts (excluding current) should return nil")
    }

    @Test func isPersonalBest_falseForIneligibleMetrics() throws {
        let context = try makeTestContext()

        let w1 = Workout(name: "W1", workoutType: "Strength Training", rpe: 5, durationMinutes: 30, avgHeartRate: 120, maxHeartRate: 150, exerciseMinutes: 25)
        let w2 = Workout(name: "W2", workoutType: "Strength Training", rpe: 7, durationMinutes: 60, avgHeartRate: 140, maxHeartRate: 170, exerciseMinutes: 55)
        context.insert(w1)
        context.insert(w2)
        try context.save()

        #expect(WorkoutMetricService.isPersonalBest(for: .effort, workout: w2, context: context) == false)
        #expect(WorkoutMetricService.isPersonalBest(for: .avgHR, workout: w2, context: context) == false)
        #expect(WorkoutMetricService.isPersonalBest(for: .maxHR, workout: w2, context: context) == false)
        #expect(WorkoutMetricService.isPersonalBest(for: .duration, workout: w2, context: context) == false)
        #expect(WorkoutMetricService.isPersonalBest(for: .exerciseMinutes, workout: w2, context: context) == false)
    }

    @Test func isPersonalBest_trueWhenWorkoutHoldsMaxValue() throws {
        let context = try makeTestContext()

        let w1 = Workout(name: "Run 1", workoutType: "Cardio", distanceKm: 5.0)
        let w2 = Workout(name: "Run 2", workoutType: "Cardio", distanceKm: 8.0)
        let best = Workout(name: "Best Run", workoutType: "Cardio", distanceKm: 12.0)
        context.insert(w1)
        context.insert(w2)
        context.insert(best)
        try context.save()

        #expect(WorkoutMetricService.isPersonalBest(for: .distance, workout: best, context: context) == true)
        #expect(WorkoutMetricService.isPersonalBest(for: .distance, workout: w1, context: context) == false)
    }
}

// MARK: - Source Name Tests

struct SourceNameTests {

    @Test func sourceName_appleWatchBundle_returnsAppleWorkout() {
        let client = DefaultHealthKitClient()
        #expect(client.sourceName(for: "com.apple.health.workout-builder") == "Apple Workout")
        #expect(client.sourceName(for: "com.apple.health") == "Apple Workout")
    }

    @Test func sourceName_unrecognizedBundle_returnsAnotherApp() {
        let client = DefaultHealthKitClient()
        #expect(client.sourceName(for: "com.unknowndev.randomapp") == "another app")
        #expect(client.sourceName(for: "org.example.fitness") == "another app")
    }

    @Test func sourceName_knownThirdParty_returnsCleanName() {
        let client = DefaultHealthKitClient()
        #expect(client.sourceName(for: "com.strava.run") == "Strava")
        #expect(client.sourceName(for: "com.onepeloton.peloton") == "Peloton")
        #expect(client.sourceName(for: "com.fiit.fiit") == "Fiit")
    }
}

// MARK: - WorkoutMetric Enum Tests

struct WorkoutMetricEnumTests {

    @Test func prEligibility_onlyDistanceActiveKcalTotalKcalElevation() {
        let eligible: Set<WorkoutMetric> = [.distance, .activeKcal, .totalKcal, .elevation]
        for metric in WorkoutMetric.allCases {
            #expect(metric.isPReligible == eligible.contains(metric), "\(metric.displayLabel) PR eligibility mismatch")
        }
    }

    @Test func value_extractsCorrectFieldFromWorkout() {
        let workout = Workout(
            name: "Test",
            workoutType: "Cardio",
            rpe: 7,
            durationMinutes: 45,
            distanceKm: 10.5,
            avgHeartRate: 155,
            maxHeartRate: 178,
            activeEnergyKcal: 420,
            totalEnergyBurnedKcal: 612,
            elevationAscendedMeters: 73,
            exerciseMinutes: 43
        )
        #expect(WorkoutMetric.effort.value(from: workout) == 7)
        #expect(WorkoutMetric.duration.value(from: workout) == 45)
        #expect(WorkoutMetric.distance.value(from: workout) == 10.5)
        #expect(WorkoutMetric.avgHR.value(from: workout) == 155)
        #expect(WorkoutMetric.maxHR.value(from: workout) == 178)
        #expect(WorkoutMetric.activeKcal.value(from: workout) == 420)
        #expect(WorkoutMetric.totalKcal.value(from: workout) == 612)
        #expect(WorkoutMetric.elevation.value(from: workout) == 73)
        #expect(WorkoutMetric.exerciseMinutes.value(from: workout) == 43)
    }

    @Test func value_returnsNilForMissingFields() {
        let workout = Workout(name: "Minimal", workoutType: "Strength Training")
        for metric in WorkoutMetric.allCases {
            #expect(metric.value(from: workout) == nil, "\(metric.displayLabel) should be nil for minimal workout")
        }
    }
}
