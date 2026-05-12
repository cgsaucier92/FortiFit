import Testing
import Foundation
import SwiftData
@testable import FortiFit

/// In-memory SwiftData context including template models.
private func makeTemplateTestContext() throws -> ModelContext {
    let schema = Schema([
        Workout.self, ExerciseSet.self, Goal.self,
        WorkoutTemplate.self, TemplateExerciseSet.self,
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

// MARK: - WorkoutTemplate Model Tests

struct WorkoutTemplateModelTests {

    @Test func createAndRetrieveWorkoutTemplate() throws {
        let context = try makeTemplateTestContext()
        let template = WorkoutTemplate(name: "Push Day Template", workoutType: "Strength Training")
        context.insert(template)
        try context.save()

        let results = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        #expect(results.count == 1)
        #expect(results.first?.id == template.id)
        #expect(results.first?.name == "Push Day Template")
    }

    @Test func updateWorkoutTemplateName() throws {
        let context = try makeTemplateTestContext()
        let template = WorkoutTemplate(name: "Old Name", workoutType: "HIIT")
        context.insert(template)
        try context.save()

        template.name = "New Name"
        try context.save()

        let results = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        #expect(results.first?.name == "New Name")
    }

    @Test func deleteWorkoutTemplate() throws {
        let context = try makeTemplateTestContext()
        let template = WorkoutTemplate(name: "Push Day Template", workoutType: "Strength Training")
        context.insert(template)
        try context.save()

        context.delete(template)
        try context.save()

        let results = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        #expect(results.isEmpty)
    }

    @Test func deletedTemplateNotReturnedByFetch() throws {
        let context = try makeTemplateTestContext()
        let t1 = WorkoutTemplate(name: "Template A", workoutType: "Strength Training")
        let t2 = WorkoutTemplate(name: "Template B", workoutType: "HIIT")
        context.insert(t1)
        context.insert(t2)
        try context.save()

        context.delete(t1)
        try context.save()

        let results = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        #expect(results.count == 1)
        #expect(results.first?.name == "Template B")
    }

    @Test func createStrengthTrainingTemplate() throws {
        let context = try makeTemplateTestContext()
        let template = WorkoutTemplate(name: "Push Day", workoutType: "Strength Training")
        context.insert(template)
        try context.save()

        let results = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        #expect(results.first?.workoutType == "Strength Training")
    }

    @Test func createHIITTemplate() throws {
        let context = try makeTemplateTestContext()
        let template = WorkoutTemplate(name: "HIIT Blast", workoutType: "HIIT")
        context.insert(template)
        try context.save()

        let results = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        #expect(results.first?.workoutType == "HIIT")
    }

    @Test func dateCreatedAutoSetOnCreation() throws {
        let before = Date()
        let template = WorkoutTemplate(name: "Push Day", workoutType: "Strength Training")
        let after = Date()

        #expect(template.dateCreated >= before)
        #expect(template.dateCreated <= after)
    }
}

// MARK: - TemplateExerciseSet Model Tests

struct TemplateExerciseSetModelTests {

    @Test func createTemplateExerciseSetWithinTemplate() throws {
        let context = try makeTemplateTestContext()
        let template = WorkoutTemplate(name: "Push Day", workoutType: "Strength Training")
        let exerciseSet = TemplateExerciseSet(exerciseName: "Bench Press", sets: 4, reps: 8, weightKg: 80, sortOrder: 0)
        template.exerciseSets.append(exerciseSet)
        context.insert(template)
        try context.save()

        let results = try context.fetch(FetchDescriptor<TemplateExerciseSet>())
        #expect(results.count == 1)
        #expect(results.first?.exerciseName == "Bench Press")
        #expect(results.first?.template?.id == template.id)
    }

    @Test func fetchingTemplateReturnsExerciseSets() throws {
        let context = try makeTemplateTestContext()
        let template = WorkoutTemplate(name: "Push Day", workoutType: "Strength Training")
        let s1 = TemplateExerciseSet(exerciseName: "Bench Press", sets: 4, reps: 8, weightKg: 80, sortOrder: 0)
        let s2 = TemplateExerciseSet(exerciseName: "Overhead Press", sets: 3, reps: 10, weightKg: 50, sortOrder: 1)
        template.exerciseSets.append(s1)
        template.exerciseSets.append(s2)
        context.insert(template)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<WorkoutTemplate>()).first!
        #expect(fetched.exerciseSets.count == 2)
    }

    @Test func deleteIndividualExerciseSetKeepsTemplate() throws {
        let context = try makeTemplateTestContext()
        let template = WorkoutTemplate(name: "Push Day", workoutType: "Strength Training")
        let s1 = TemplateExerciseSet(exerciseName: "Bench Press", sets: 4, reps: 8, weightKg: 80, sortOrder: 0)
        let s2 = TemplateExerciseSet(exerciseName: "Flyes", sets: 3, reps: 12, weightKg: 20, sortOrder: 1)
        template.exerciseSets.append(s1)
        template.exerciseSets.append(s2)
        context.insert(template)
        try context.save()

        context.delete(s1)
        try context.save()

        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        #expect(templates.count == 1)

        let sets = try context.fetch(FetchDescriptor<TemplateExerciseSet>())
        #expect(sets.count == 1)
        #expect(sets.first?.exerciseName == "Flyes")
    }

    @Test func deletingTemplateCascadesExerciseSets() throws {
        let context = try makeTemplateTestContext()
        let template = WorkoutTemplate(name: "Push Day", workoutType: "Strength Training")
        let s1 = TemplateExerciseSet(exerciseName: "Bench Press", sets: 4, reps: 8, weightKg: 80, sortOrder: 0)
        let s2 = TemplateExerciseSet(exerciseName: "Overhead Press", sets: 3, reps: 10, weightKg: 50, sortOrder: 1)
        template.exerciseSets.append(s1)
        template.exerciseSets.append(s2)
        context.insert(template)
        try context.save()

        context.delete(template)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<TemplateExerciseSet>())
        #expect(remaining.isEmpty)
    }

    @Test func bodyweightExerciseSetNilWeight() throws {
        let context = try makeTemplateTestContext()
        let template = WorkoutTemplate(name: "Bodyweight Day", workoutType: "Strength Training")
        let s1 = TemplateExerciseSet(exerciseName: "Pull-ups", sets: 3, reps: 10, weightKg: nil, sortOrder: 0)
        template.exerciseSets.append(s1)
        context.insert(template)
        try context.save()

        let results = try context.fetch(FetchDescriptor<TemplateExerciseSet>())
        #expect(results.first?.weightKg == nil)
    }

    @Test func multipleSetsWithDifferentSortOrders() throws {
        let context = try makeTemplateTestContext()
        let template = WorkoutTemplate(name: "Push Day", workoutType: "Strength Training")
        let s1 = TemplateExerciseSet(exerciseName: "Bench Press", sets: 4, reps: 8, weightKg: 80, sortOrder: 0)
        let s2 = TemplateExerciseSet(exerciseName: "Flyes", sets: 3, reps: 12, weightKg: 20, sortOrder: 1)
        let s3 = TemplateExerciseSet(exerciseName: "Overhead Press", sets: 3, reps: 10, weightKg: 50, sortOrder: 2)
        template.exerciseSets.append(s1)
        template.exerciseSets.append(s2)
        template.exerciseSets.append(s3)
        context.insert(template)
        try context.save()

        let descriptor = FetchDescriptor<TemplateExerciseSet>(
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )
        let results = try context.fetch(descriptor)
        #expect(results.count == 3)
        #expect(results[0].exerciseName == "Bench Press")
        #expect(results[1].exerciseName == "Flyes")
        #expect(results[2].exerciseName == "Overhead Press")
    }
}

// MARK: - WorkoutTemplateService Tests

struct WorkoutTemplateServiceTests {

    @Test func createTemplateWithExercisesPersists() throws {
        let context = try makeTemplateTestContext()
        let exercises = [
            WorkoutTemplateService.ExerciseData(name: "Bench Press", sets: 4, reps: 8, weightKg: 80, sortOrder: 0),
            WorkoutTemplateService.ExerciseData(name: "Overhead Press", sets: 3, reps: 10, weightKg: 50, sortOrder: 1),
        ]
        WorkoutTemplateService.create(
            name: "Push Day",
            workoutType: "Strength Training",
            durationMinutes: 60,
            exercises: exercises,
            context: context
        )

        let templates = WorkoutTemplateService.fetchAll(context: context)
        #expect(templates.count == 1)
        #expect(templates.first?.name == "Push Day")
        #expect(templates.first?.exerciseSets.count == 2)
    }

    @Test func fetchAllReturnsNewestFirst() throws {
        let context = try makeTemplateTestContext()

        let older = WorkoutTemplate(
            name: "Older Template",
            workoutType: "Strength Training",
            dateCreated: Date().addingTimeInterval(-86400)
        )
        let newer = WorkoutTemplate(
            name: "Newer Template",
            workoutType: "HIIT",
            dateCreated: Date()
        )
        context.insert(older)
        context.insert(newer)
        try context.save()

        let results = WorkoutTemplateService.fetchAll(context: context)
        #expect(results.count == 2)
        #expect(results[0].name == "Newer Template")
        #expect(results[1].name == "Older Template")
    }

    @Test func updateTemplateName() throws {
        let context = try makeTemplateTestContext()
        let template = WorkoutTemplate(name: "Push Day", workoutType: "Strength Training")
        context.insert(template)
        try context.save()

        WorkoutTemplateService.update(
            template,
            name: "Chest Day",
            durationMinutes: nil,
            exercises: [],
            context: context
        )

        let results = WorkoutTemplateService.fetchAll(context: context)
        #expect(results.first?.name == "Chest Day")
    }

    @Test func updateTemplateDuration() throws {
        let context = try makeTemplateTestContext()
        let template = WorkoutTemplate(name: "Push Day", workoutType: "Strength Training", durationMinutes: 45)
        context.insert(template)
        try context.save()

        WorkoutTemplateService.update(
            template,
            name: "Push Day",
            durationMinutes: 60,
            exercises: [],
            context: context
        )

        let results = WorkoutTemplateService.fetchAll(context: context)
        #expect(results.first?.durationMinutes == 60)
    }

    @Test func updateAddsNewExerciseSet() throws {
        let context = try makeTemplateTestContext()
        let template = WorkoutTemplate(name: "Push Day", workoutType: "Strength Training")
        context.insert(template)
        try context.save()

        let exercises = [
            WorkoutTemplateService.ExerciseData(name: "Bench Press", sets: 4, reps: 8, weightKg: 80, sortOrder: 0),
        ]
        WorkoutTemplateService.update(
            template,
            name: "Push Day",
            durationMinutes: nil,
            exercises: exercises,
            context: context
        )

        let results = WorkoutTemplateService.fetchAll(context: context)
        #expect(results.first?.exerciseSets.count == 1)
        #expect(results.first?.exerciseSets.first?.exerciseName == "Bench Press")
    }

    @Test func updateReplacesExerciseSets() throws {
        let context = try makeTemplateTestContext()
        let exercises = [
            WorkoutTemplateService.ExerciseData(name: "Bench Press", sets: 4, reps: 8, weightKg: 80, sortOrder: 0),
        ]
        let template = WorkoutTemplateService.create(
            name: "Push Day",
            workoutType: "Strength Training",
            durationMinutes: nil,
            exercises: exercises,
            context: context
        )

        // Update with different sets/reps
        let updated = [
            WorkoutTemplateService.ExerciseData(name: "Bench Press", sets: 5, reps: 5, weightKg: 90, sortOrder: 0),
        ]
        WorkoutTemplateService.update(
            template,
            name: "Push Day",
            durationMinutes: nil,
            exercises: updated,
            context: context
        )

        let results = WorkoutTemplateService.fetchAll(context: context)
        #expect(results.first?.exerciseSets.first?.sets == 5)
        #expect(results.first?.exerciseSets.first?.reps == 5)
        #expect(results.first?.exerciseSets.first?.weightKg == 90)
    }

    @Test func updateRemovesExerciseSetWithoutDeletingTemplate() throws {
        let context = try makeTemplateTestContext()
        let exercises = [
            WorkoutTemplateService.ExerciseData(name: "Bench Press", sets: 4, reps: 8, weightKg: 80, sortOrder: 0),
            WorkoutTemplateService.ExerciseData(name: "Flyes", sets: 3, reps: 12, weightKg: 20, sortOrder: 1),
        ]
        let template = WorkoutTemplateService.create(
            name: "Push Day",
            workoutType: "Strength Training",
            durationMinutes: nil,
            exercises: exercises,
            context: context
        )

        // Update with only one exercise
        let reduced = [
            WorkoutTemplateService.ExerciseData(name: "Bench Press", sets: 4, reps: 8, weightKg: 80, sortOrder: 0),
        ]
        WorkoutTemplateService.update(
            template,
            name: "Push Day",
            durationMinutes: nil,
            exercises: reduced,
            context: context
        )

        let templates = WorkoutTemplateService.fetchAll(context: context)
        #expect(templates.count == 1)
        #expect(templates.first?.exerciseSets.count == 1)
    }

    @Test func deleteTemplateCascadesExerciseSets() throws {
        let context = try makeTemplateTestContext()
        let exercises = [
            WorkoutTemplateService.ExerciseData(name: "Bench Press", sets: 4, reps: 8, weightKg: 80, sortOrder: 0),
        ]
        let template = WorkoutTemplateService.create(
            name: "Push Day",
            workoutType: "Strength Training",
            durationMinutes: nil,
            exercises: exercises,
            context: context
        )

        WorkoutTemplateService.delete(template, context: context)

        let templates = WorkoutTemplateService.fetchAll(context: context)
        #expect(templates.isEmpty)

        let sets = try context.fetch(FetchDescriptor<TemplateExerciseSet>())
        #expect(sets.isEmpty)
    }

    @Test func snapshotReturnsCorrectData() throws {
        let context = try makeTemplateTestContext()
        let exercises = [
            WorkoutTemplateService.ExerciseData(name: "Bench Press", sets: 4, reps: 8, weightKg: 80, sortOrder: 0),
            WorkoutTemplateService.ExerciseData(name: "Overhead Press", sets: 3, reps: 10, weightKg: 50, sortOrder: 1),
        ]
        let template = WorkoutTemplateService.create(
            name: "Push Day",
            workoutType: "Strength Training",
            durationMinutes: 60,
            exercises: exercises,
            context: context
        )

        let snapshot = WorkoutTemplateService.snapshot(from: template)
        #expect(snapshot.name == "Push Day")
        #expect(snapshot.workoutType == "Strength Training")
        #expect(snapshot.durationMinutes == 60)
        #expect(snapshot.exercises.count == 2)
        #expect(snapshot.exercises[0].name == "Bench Press")
        #expect(snapshot.exercises[1].name == "Overhead Press")
    }

    @Test func snapshotDoesNotCreateWorkoutReference() throws {
        let context = try makeTemplateTestContext()
        let template = WorkoutTemplateService.create(
            name: "Push Day",
            workoutType: "Strength Training",
            durationMinutes: nil,
            exercises: [],
            context: context
        )

        _ = WorkoutTemplateService.snapshot(from: template)

        // No Workout entities should have been created
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        #expect(workouts.isEmpty)
    }

    @Test func deletingTemplateDoesNotAffectLoggedWorkouts() throws {
        let context = try makeTemplateTestContext()

        // Log a workout
        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        context.insert(workout)
        try context.save()

        // Create a template
        let template = WorkoutTemplateService.create(
            name: "Push Day Template",
            workoutType: "Strength Training",
            durationMinutes: nil,
            exercises: [],
            context: context
        )

        // Delete the template
        WorkoutTemplateService.delete(template, context: context)

        // Workout should still exist
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        #expect(workouts.count == 1)
        #expect(workouts.first?.name == "Push Day")
    }

    // MARK: - templates(matching:) Tests

    @Test func templatesMatchingReturnsOnlyMatchingType() throws {
        let context = try makeTemplateTestContext()
        let strength = WorkoutTemplate(name: "Push Day", workoutType: "Strength Training", dateCreated: Date())
        let hiit = WorkoutTemplate(name: "HIIT Blast", workoutType: "HIIT", dateCreated: Date())
        let yoga = WorkoutTemplate(name: "Flow", workoutType: "Yoga", dateCreated: Date())
        context.insert(strength)
        context.insert(hiit)
        context.insert(yoga)
        try context.save()

        let results = WorkoutTemplateService.templates(matching: "Strength Training", context: context)
        #expect(results.count == 1)
        #expect(results.first?.name == "Push Day")
    }

    @Test func templatesMatchingReturnsSortedNewestFirst() throws {
        let context = try makeTemplateTestContext()
        let older = WorkoutTemplate(name: "Old Template", workoutType: "Strength Training", dateCreated: Date().addingTimeInterval(-86400))
        let newer = WorkoutTemplate(name: "New Template", workoutType: "Strength Training", dateCreated: Date())
        context.insert(older)
        context.insert(newer)
        try context.save()

        let results = WorkoutTemplateService.templates(matching: "Strength Training", context: context)
        #expect(results.count == 2)
        #expect(results[0].name == "New Template")
        #expect(results[1].name == "Old Template")
    }

    // MARK: - applyToExistingWorkout Tests

    @Test func applyToExistingWorkoutAppendsExercisesWithCorrectSortOrder() throws {
        let context = try makeTemplateTestContext()

        let workout = Workout(name: "Push Day", workoutType: "Strength Training")
        let es1 = ExerciseSet(exerciseName: "Bench Press", sets: 3, reps: 8, weightKg: 80, sortOrder: 0)
        let es2 = ExerciseSet(exerciseName: "Flyes", sets: 3, reps: 12, weightKg: 20, sortOrder: 1)
        workout.exerciseSets.append(es1)
        workout.exerciseSets.append(es2)
        context.insert(workout)

        let template = WorkoutTemplate(name: "Template", workoutType: "Strength Training")
        let ts1 = TemplateExerciseSet(exerciseName: "OHP", sets: 4, reps: 6, weightKg: 50, sortOrder: 0)
        let ts2 = TemplateExerciseSet(exerciseName: "Lat Raise", sets: 3, reps: 15, weightKg: 10, sortOrder: 1)
        let ts3 = TemplateExerciseSet(exerciseName: "Tricep Dips", sets: 3, reps: 10, sortOrder: 2)
        template.exerciseSets.append(ts1)
        template.exerciseSets.append(ts2)
        template.exerciseSets.append(ts3)
        context.insert(template)
        try context.save()

        WorkoutTemplateService.applyToExistingWorkout(template: template, workout: workout)

        #expect(workout.exerciseSets.count == 5)
        let sorted = workout.exerciseSets.sorted { $0.sortOrder < $1.sortOrder }
        #expect(sorted[0].exerciseName == "Bench Press")
        #expect(sorted[1].exerciseName == "Flyes")
        #expect(sorted[2].exerciseName == "OHP")
        #expect(sorted[2].sortOrder == 2)
        #expect(sorted[3].exerciseName == "Lat Raise")
        #expect(sorted[3].sortOrder == 3)
        #expect(sorted[4].exerciseName == "Tricep Dips")
        #expect(sorted[4].sortOrder == 4)
    }

    @Test func applyToExistingWorkoutFillsNameWhenEmpty() throws {
        let context = try makeTemplateTestContext()
        let workout = Workout(name: "", workoutType: "Strength Training")
        context.insert(workout)
        let template = WorkoutTemplate(name: "Push Day Template", workoutType: "Strength Training")
        context.insert(template)
        try context.save()

        WorkoutTemplateService.applyToExistingWorkout(template: template, workout: workout)
        #expect(workout.name == "Push Day Template")
    }

    @Test func applyToExistingWorkoutLeavesNameWhenSet() throws {
        let context = try makeTemplateTestContext()
        let workout = Workout(name: "My Custom Name", workoutType: "Strength Training")
        context.insert(workout)
        let template = WorkoutTemplate(name: "Push Day Template", workoutType: "Strength Training")
        context.insert(template)
        try context.save()

        WorkoutTemplateService.applyToExistingWorkout(template: template, workout: workout)
        #expect(workout.name == "My Custom Name")
    }

    @Test func applyToExistingWorkoutFillsDurationWhenNilAndNotHKLinked() throws {
        let context = try makeTemplateTestContext()
        let workout = Workout(name: "Push Day", workoutType: "Strength Training", durationMinutes: nil)
        context.insert(workout)
        let template = WorkoutTemplate(name: "Template", workoutType: "Strength Training", durationMinutes: 60)
        context.insert(template)
        try context.save()

        WorkoutTemplateService.applyToExistingWorkout(template: template, workout: workout)
        #expect(workout.durationMinutes == 60)
    }

    @Test func applyToExistingWorkoutSkipsDurationWhenHKLinked() throws {
        let context = try makeTemplateTestContext()
        let workout = Workout(name: "Push Day", workoutType: "Strength Training", durationMinutes: nil, healthKitUUID: UUID())
        context.insert(workout)
        let template = WorkoutTemplate(name: "Template", workoutType: "Strength Training", durationMinutes: 60)
        context.insert(template)
        try context.save()

        WorkoutTemplateService.applyToExistingWorkout(template: template, workout: workout)
        #expect(workout.durationMinutes == nil)
    }

    @Test func applyToExistingWorkoutLeavesDurationWhenAlreadySet() throws {
        let context = try makeTemplateTestContext()
        let workout = Workout(name: "Push Day", workoutType: "Strength Training", durationMinutes: 45)
        context.insert(workout)
        let template = WorkoutTemplate(name: "Template", workoutType: "Strength Training", durationMinutes: 60)
        context.insert(template)
        try context.save()

        WorkoutTemplateService.applyToExistingWorkout(template: template, workout: workout)
        #expect(workout.durationMinutes == 45)
    }

    @Test func applyToExistingWorkoutNeverModifiesOtherFields() throws {
        let context = try makeTemplateTestContext()
        let originalDate = Date().addingTimeInterval(-3600)
        let hkUUID = UUID()
        let workout = Workout(
            name: "Existing",
            date: originalDate,
            workoutType: "Strength Training",
            rpe: 7,
            durationMinutes: 45,
            distanceKm: 5.0,
            time: originalDate,
            healthKitUUID: hkUUID,
            healthKitSourceBundleID: "com.apple.health"
        )
        context.insert(workout)
        let template = WorkoutTemplate(name: "Template", workoutType: "Strength Training", durationMinutes: 99)
        context.insert(template)
        try context.save()

        WorkoutTemplateService.applyToExistingWorkout(template: template, workout: workout)

        #expect(workout.workoutType == "Strength Training")
        #expect(workout.date == originalDate)
        #expect(workout.rpe == 7)
        #expect(workout.distanceKm == 5.0)
        #expect(workout.healthKitUUID == hkUUID)
        #expect(workout.healthKitSourceBundleID == "com.apple.health")
        #expect(workout.durationMinutes == 45)
    }

    // MARK: - BUG-039 Regression

    /// BUG-039: buildExerciseData used exercise index for sortOrder, so multiple
    /// rows within the same exercise all received the same sortOrder value.
    @Test func test_multiRowExercise_producesUniqueSortOrders() throws {
        let context = try makeTemplateTestContext()
        let vm = WorkoutTemplateViewModel()

        let entry = ExerciseFormEntry()
        entry.name = "Bench Press"
        let row1 = SetRow(); row1.sets = "1"; row1.reps = "8"; row1.weight = "60"
        let row2 = SetRow(); row2.sets = "1"; row2.reps = "6"; row2.weight = "70"
        let row3 = SetRow(); row3.sets = "1"; row3.reps = "4"; row3.weight = "80"
        entry.rows = [row1, row2, row3]

        vm.templateName = "Sort Order Test"
        vm.exercises = [entry]
        vm.saveTemplate(context: context)

        let templates = WorkoutTemplateService.fetchAll(context: context)
        #expect(templates.count == 1)
        let sets = templates.first!.exerciseSets.sorted { $0.sortOrder < $1.sortOrder }
        #expect(sets.count == 3)
        #expect(sets[0].sortOrder == 0)
        #expect(sets[1].sortOrder == 1)
        #expect(sets[2].sortOrder == 2)
    }

    // MARK: - Existing Tests (continued)

    @Test func deletingTemplateDoesNotAffectGoals() throws {
        let context = try makeTemplateTestContext()

        // Create a goal
        let goal = Goal(title: "Bench Press", targetValueKg: 100, currentValueKg: 80, sortOrder: 0)
        context.insert(goal)
        try context.save()

        // Create and delete a template
        let template = WorkoutTemplateService.create(
            name: "Push Day Template",
            workoutType: "Strength Training",
            durationMinutes: nil,
            exercises: [],
            context: context
        )
        WorkoutTemplateService.delete(template, context: context)

        // Goal should be unchanged
        let goals = try context.fetch(FetchDescriptor<Goal>())
        #expect(goals.count == 1)
        #expect(goals.first?.currentValueKg == 80)
    }
}
