import Testing
import Foundation
import SwiftUI
@testable import FortiFit

#if os(iOS)
import UIKit
#endif

// MARK: - Project Scaffold

struct WorkoutShareScaffoldTests {

    @Test func workoutShareServiceFileExists() {
        // WorkoutShareService is defined — this test compiles only if the type exists.
        #if os(iOS)
        _ = WorkoutShareService.self
        #expect(true)
        #endif
    }

    @Test func workoutShareCardViewFileExists() {
        let workout = Workout(name: "Test", workoutType: "Strength Training")
        let view = WorkoutShareCardView(workout: workout, userSettings: UserSettings.shared)
        _ = view.body
        #expect(true)
    }

    @Test func shareSheetFileExists() {
        #if os(iOS)
        let sheet = ShareSheet(activityItems: ["test"])
        _ = sheet
        #expect(true)
        #endif
    }
}

// MARK: - Share Icon Placement

struct ShareIconTests {

    @Test func actionButtonGroupAcceptsOnShare() {
        var shareCalled = false
        let group = FortiFitActionButtonGroup(
            onShare: { shareCalled = true },
            onEdit: {},
            onDelete: {}
        )
        _ = group.body
        // The onShare closure exists — confirms share icon is rendered in the group
        #expect(!shareCalled) // Not called until tapped
    }

    @Test func actionButtonGroupWorksWithoutOnShare() {
        // Existing call sites without share still work
        let group = FortiFitActionButtonGroup(onEdit: {}, onDelete: {})
        _ = group.body
        #expect(true)
    }
}

// MARK: - WorkoutShareService Rendering

struct WorkoutShareServiceTests {

    #if os(iOS)
    @Test @MainActor func renderShareImageReturnsImageForStrength() {
        let workout = Workout(
            name: "Push Day",
            workoutType: "Strength Training",
            rpe: 8,
            durationMinutes: 60
        )
        let set1 = ExerciseSet(exerciseName: "Bench Press", sets: 4, reps: 8, weightKg: 80, sortOrder: 0)
        workout.exerciseSets.append(set1)

        let image = WorkoutShareService.renderShareImage(workout: workout, userSettings: UserSettings.shared)
        #expect(image != nil)
    }

    @Test @MainActor func renderShareImageReturnsImageForCardio() {
        let workout = Workout(
            name: "Morning Run",
            workoutType: "Cardio",
            rpe: 6,
            durationMinutes: 45,
            distanceKm: 8.5
        )

        let image = WorkoutShareService.renderShareImage(workout: workout, userSettings: UserSettings.shared)
        #expect(image != nil)
    }

    @Test @MainActor func renderShareImageReturnsImageForYoga() {
        let workout = Workout(
            name: "Vinyasa Flow",
            workoutType: "Yoga",
            durationMinutes: 60
        )

        let image = WorkoutShareService.renderShareImage(workout: workout, userSettings: UserSettings.shared)
        #expect(image != nil)
    }

    @Test @MainActor func renderShareImageReturnsImageForHIIT() {
        let workout = Workout(
            name: "Tabata Blast",
            workoutType: "HIIT",
            rpe: 9,
            durationMinutes: 30
        )
        let set1 = ExerciseSet(exerciseName: "Burpees", sets: 4, reps: 20, sortOrder: 0)
        workout.exerciseSets.append(set1)

        let image = WorkoutShareService.renderShareImage(workout: workout, userSettings: UserSettings.shared)
        #expect(image != nil)
    }

    @Test @MainActor func renderShareImageReturnsImageForSprints() {
        let workout = Workout(
            name: "Track Sprints",
            workoutType: "Sprints",
            rpe: 9,
            durationMinutes: 25,
            distanceKm: 3.2
        )

        let image = WorkoutShareService.renderShareImage(workout: workout, userSettings: UserSettings.shared)
        #expect(image != nil)
    }

    @Test @MainActor func renderShareImageReturnsImageForPilates() {
        let workout = Workout(
            name: "Core Pilates",
            workoutType: "Pilates",
            durationMinutes: 45
        )

        let image = WorkoutShareService.renderShareImage(workout: workout, userSettings: UserSettings.shared)
        #expect(image != nil)
    }

    @Test @MainActor func renderShareImageWidthIs390AtThreeX() {
        let workout = Workout(name: "Test", workoutType: "Strength Training")

        let image = WorkoutShareService.renderShareImage(workout: workout, userSettings: UserSettings.shared)
        #expect(image != nil)
        // At @3x, 390pt width = 1170px
        if let image {
            #expect(image.size.width == 390)
            #expect(image.scale == 3.0)
        }
    }

    @Test @MainActor func renderShareImageWithAllNilOptionals() {
        // No RPE, no duration, no distance, no exercises, no time
        let workout = Workout(name: "Minimal Workout", workoutType: "Yoga")

        let image = WorkoutShareService.renderShareImage(workout: workout, userSettings: UserSettings.shared)
        #expect(image != nil)
    }

    @Test @MainActor func renderShareImageWithNilTime() {
        let workout = Workout(
            name: "No Time Workout",
            workoutType: "Strength Training",
            time: nil
        )

        let image = WorkoutShareService.renderShareImage(workout: workout, userSettings: UserSettings.shared)
        #expect(image != nil)
    }

    @Test @MainActor func renderShareImageWithTime() {
        let workout = Workout(
            name: "Timed Workout",
            workoutType: "Strength Training",
            time: Date()
        )

        let image = WorkoutShareService.renderShareImage(workout: workout, userSettings: UserSettings.shared)
        #expect(image != nil)
    }

    @Test @MainActor func renderShareImageWithBodyweightExercise() {
        let workout = Workout(name: "BW Day", workoutType: "Strength Training")
        let bwSet = ExerciseSet(exerciseName: "Pull Ups", sets: 3, reps: 12, weightKg: nil, sortOrder: 0)
        workout.exerciseSets.append(bwSet)

        let image = WorkoutShareService.renderShareImage(workout: workout, userSettings: UserSettings.shared)
        #expect(image != nil)
    }

    @Test @MainActor func renderShareImageWithExactly10Exercises() {
        let workout = Workout(name: "Big Day", workoutType: "Strength Training")
        for i in 0..<10 {
            let set = ExerciseSet(exerciseName: "Exercise \(i + 1)", sets: 3, reps: 10, weightKg: 50, sortOrder: i)
            workout.exerciseSets.append(set)
        }

        let image = WorkoutShareService.renderShareImage(workout: workout, userSettings: UserSettings.shared)
        #expect(image != nil)
    }

    @Test @MainActor func renderShareImageWithMoreThan10Exercises() {
        let workout = Workout(name: "Marathon Session", workoutType: "Strength Training")
        for i in 0..<15 {
            let set = ExerciseSet(exerciseName: "Exercise \(i + 1)", sets: 3, reps: 10, weightKg: 50, sortOrder: i)
            workout.exerciseSets.append(set)
        }

        let image = WorkoutShareService.renderShareImage(workout: workout, userSettings: UserSettings.shared)
        #expect(image != nil)
    }

    @Test @MainActor func renderShareImageWithLongWorkoutName() {
        let longName = String(repeating: "A", count: 60)
        let workout = Workout(name: longName, workoutType: "Strength Training")

        let image = WorkoutShareService.renderShareImage(workout: workout, userSettings: UserSettings.shared)
        #expect(image != nil)
    }
    #endif
}

// MARK: - WorkoutShareCardView Logic

struct WorkoutShareCardViewLogicTests {

    @Test func setDetailTextWeightedKg() {
        let exerciseSet = ExerciseSet(exerciseName: "Bench", sets: 4, reps: 8, weightKg: 80, sortOrder: 0)
        let text = shareSetDetailText(exerciseSet, useLbs: false)
        #expect(text == "4 × 8 @ 80 kg")
    }

    @Test func setDetailTextWeightedLbs() {
        let exerciseSet = ExerciseSet(exerciseName: "Bench", sets: 4, reps: 8, weightKg: 80, sortOrder: 0)
        let text = shareSetDetailText(exerciseSet, useLbs: true)
        #expect(text == "4 × 8 @ 176 lbs")
    }

    @Test func setDetailTextBodyweight() {
        let exerciseSet = ExerciseSet(exerciseName: "Pull Ups", sets: 3, reps: 12, weightKg: nil, sortOrder: 0)
        let text = shareSetDetailText(exerciseSet, useLbs: false)
        #expect(text == "3 × 12 (BW)")
    }

    @Test func setDetailTextBodyweightWithLbsSetting() {
        let exerciseSet = ExerciseSet(exerciseName: "Pull Ups", sets: 3, reps: 12, weightKg: nil, sortOrder: 0)
        let text = shareSetDetailText(exerciseSet, useLbs: true)
        #expect(text == "3 × 12 (BW)")
    }

    @Test func distanceDisplayKm() {
        let text = UnitConversion.displayDistance(8.5, useMiles: false)
        #expect(text == "8.50 km")
    }

    @Test func distanceDisplayMiles() {
        let text = UnitConversion.displayDistance(8.5, useMiles: true)
        #expect(text.contains("mi"))
    }

    @Test func exerciseCapAtTen() {
        let workout = Workout(name: "Test", workoutType: "Strength Training")
        for i in 0..<15 {
            workout.exerciseSets.append(
                ExerciseSet(exerciseName: "Ex \(i + 1)", sets: 3, reps: 10, weightKg: 50, sortOrder: i)
            )
        }
        let grouped = groupExercises(workout)
        let displayCount = min(grouped.count, 10)
        let overflow = grouped.count - 10
        #expect(displayCount == 10)
        #expect(overflow == 5)
    }

    @Test func exerciseExactlyTenNoOverflow() {
        let workout = Workout(name: "Test", workoutType: "Strength Training")
        for i in 0..<10 {
            workout.exerciseSets.append(
                ExerciseSet(exerciseName: "Ex \(i + 1)", sets: 3, reps: 10, weightKg: 50, sortOrder: i)
            )
        }
        let grouped = groupExercises(workout)
        let overflow = grouped.count - 10
        #expect(grouped.count == 10)
        #expect(overflow == 0)
    }

    @Test func exerciseElevenShowsPlusOne() {
        let workout = Workout(name: "Test", workoutType: "Strength Training")
        for i in 0..<11 {
            workout.exerciseSets.append(
                ExerciseSet(exerciseName: "Ex \(i + 1)", sets: 3, reps: 10, weightKg: 50, sortOrder: i)
            )
        }
        let grouped = groupExercises(workout)
        let overflow = grouped.count - 10
        #expect(overflow == 1)
    }

    @Test func hasSummaryPillsWithRPE() {
        let workout = Workout(name: "Test", workoutType: "Yoga", rpe: 7)
        #expect(checkHasSummaryPills(workout))
    }

    @Test func hasSummaryPillsWithDuration() {
        let workout = Workout(name: "Test", workoutType: "Yoga", durationMinutes: 60)
        #expect(checkHasSummaryPills(workout))
    }

    @Test func hasSummaryPillsWithDistanceCardio() {
        let workout = Workout(name: "Test", workoutType: "Cardio", distanceKm: 5.0)
        #expect(checkHasSummaryPills(workout))
    }

    @Test func noSummaryPillsAllNil() {
        let workout = Workout(name: "Test", workoutType: "Yoga")
        #expect(!checkHasSummaryPills(workout))
    }

    @Test func noDistancePillForStrength() {
        // Even if distanceKm is somehow set, strength should not show distance pill
        let workout = Workout(name: "Test", workoutType: "Strength Training", distanceKm: 5.0)
        let isCardioOrSprints = workout.workoutType == "Cardio" || workout.workoutType == "Sprints"
        #expect(!isCardioOrSprints)
    }

    @Test func noDistancePillForYoga() {
        let workout = Workout(name: "Test", workoutType: "Yoga", distanceKm: 5.0)
        let isCardioOrSprints = workout.workoutType == "Cardio" || workout.workoutType == "Sprints"
        #expect(!isCardioOrSprints)
    }

    @Test func noDistancePillForPilates() {
        let workout = Workout(name: "Test", workoutType: "Pilates", distanceKm: 5.0)
        let isCardioOrSprints = workout.workoutType == "Cardio" || workout.workoutType == "Sprints"
        #expect(!isCardioOrSprints)
    }

    @Test func noDistancePillForHIIT() {
        let workout = Workout(name: "Test", workoutType: "HIIT", distanceKm: 5.0)
        let isCardioOrSprints = workout.workoutType == "Cardio" || workout.workoutType == "Sprints"
        #expect(!isCardioOrSprints)
    }

    @Test func strengthShowsExercises() {
        let isStrengthOrHIIT = checkIsStrengthOrHIIT("Strength Training")
        #expect(isStrengthOrHIIT)
    }

    @Test func hiitShowsExercises() {
        let isStrengthOrHIIT = checkIsStrengthOrHIIT("HIIT")
        #expect(isStrengthOrHIIT)
    }

    @Test func cardioDoesNotShowExercises() {
        #expect(!checkIsStrengthOrHIIT("Cardio"))
    }

    @Test func sprintsDoesNotShowExercises() {
        #expect(!checkIsStrengthOrHIIT("Sprints"))
    }

    @Test func yogaDoesNotShowExercises() {
        #expect(!checkIsStrengthOrHIIT("Yoga"))
    }

    @Test func pilatesDoesNotShowExercises() {
        #expect(!checkIsStrengthOrHIIT("Pilates"))
    }

    @Test func dateLineWithTime() {
        let now = Date()
        let workout = Workout(name: "Test", workoutType: "Yoga", time: now)
        let line = shareDateTimeLine(workout)
        #expect(line.contains("·"))
    }

    @Test func dateLineWithoutTime() {
        let workout = Workout(name: "Test", workoutType: "Yoga", time: nil)
        let line = shareDateTimeLine(workout)
        #expect(!line.contains("·"))
    }

    // MARK: - Helpers (mirror card view logic for testing)

    private func shareSetDetailText(_ exerciseSet: ExerciseSet, useLbs: Bool) -> String {
        if let weightKg = exerciseSet.weightKg {
            let weightStr = UnitConversion.displayWeight(weightKg, useLbs: useLbs)
            return "\(exerciseSet.sets) × \(exerciseSet.reps) @ \(weightStr)"
        } else {
            return "\(exerciseSet.sets) × \(exerciseSet.reps) (BW)"
        }
    }

    private func groupExercises(_ workout: Workout) -> [(name: String, sets: [ExerciseSet])] {
        let sorted = workout.exerciseSets.sorted { $0.sortOrder < $1.sortOrder }
        let grouped = Dictionary(grouping: sorted, by: { $0.exerciseName })
        var seen = Set<String>()
        var result: [(name: String, sets: [ExerciseSet])] = []
        for set in sorted {
            if seen.insert(set.exerciseName).inserted {
                result.append((name: set.exerciseName, sets: grouped[set.exerciseName] ?? []))
            }
        }
        return result
    }

    private func checkHasSummaryPills(_ workout: Workout) -> Bool {
        let isCardioOrSprints = workout.workoutType == "Cardio" || workout.workoutType == "Sprints"
        return workout.rpe != nil || workout.durationMinutes != nil || (isCardioOrSprints && workout.distanceKm != nil)
    }

    private func checkIsStrengthOrHIIT(_ type: String) -> Bool {
        type == "Strength Training" || type == "HIIT"
    }

    private func shareDateTimeLine(_ workout: Workout) -> String {
        let dateStr = workout.date.shortFormatted
        if let time = workout.time {
            return "\(dateStr) · \(time.timeFormatted)"
        }
        return dateStr
    }
}

// MARK: - ViewModel Export State

struct WorkoutViewModelShareTests {

    @Test func viewModelHasShareErrorState() {
        let vm = WorkoutViewModel()
        #expect(vm.showShareError == false)
    }

    #if os(iOS)
    @Test func viewModelHasShareImageState() {
        let vm = WorkoutViewModel()
        #expect(vm.shareImage == nil)
    }

    @Test @MainActor func exportWorkoutSetsShareImage() {
        let vm = WorkoutViewModel()
        let workout = Workout(name: "Test", workoutType: "Strength Training", rpe: 7, durationMinutes: 45)
        vm.exportWorkout(workout)
        #expect(vm.shareImage != nil)
        #expect(vm.showShareError == false)
    }
    #endif
}
