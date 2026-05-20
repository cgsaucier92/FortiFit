import Testing
import Foundation
import SwiftData
@testable import FortiFit

// MARK: - Outbound HK Mapping Tests

@Suite("OutboundHKMapping")
struct OutboundHKMappingTests {

    @Test("Strength Training maps to Traditional Strength Training")
    func strengthTraining_mapsToTraditional() {
        let result = OutboundHKMapping.activityTypeDisplayString(for: "Strength Training")
        #expect(result == "Traditional Strength Training")
    }

    @Test("HIIT maps to HIIT")
    func hiit_mapsToHIIT() {
        let result = OutboundHKMapping.activityTypeDisplayString(for: "HIIT")
        #expect(result == "HIIT")
    }

    @Test("Unknown workout type returns nil")
    func unknownType_returnsNil() {
        let result = OutboundHKMapping.activityTypeDisplayString(for: "Yoga")
        #expect(result == nil)
    }

    @Test("Cardio returns nil (not schedulable)")
    func cardio_returnsNil() {
        let result = OutboundHKMapping.activityTypeDisplayString(for: "Cardio")
        #expect(result == nil)
    }
}

// MARK: - Isometric Exercise Lookup Tests

@Suite("IsometricExerciseLookup")
struct IsometricExerciseLookupTests {

    @Test("Planks is isometric by dictionary default")
    func planks_isIsometric() {
        let result = ExerciseSuggestionService.isIsometric("Planks")
        #expect(result == true)
    }

    @Test("Wall Sit is isometric by dictionary default")
    func wallSit_isIsometric() {
        let result = ExerciseSuggestionService.isIsometric("Wall Sit")
        #expect(result == true)
    }

    @Test("Dead Hang is isometric by dictionary default")
    func deadHang_isIsometric() {
        let result = ExerciseSuggestionService.isIsometric("Dead Hang")
        #expect(result == true)
    }

    @Test("Hollow Hold is isometric by dictionary default")
    func hollowHold_isIsometric() {
        let result = ExerciseSuggestionService.isIsometric("Hollow Hold")
        #expect(result == true)
    }

    @Test("L-Sit is isometric by dictionary default")
    func lSit_isIsometric() {
        let result = ExerciseSuggestionService.isIsometric("L-Sit")
        #expect(result == true)
    }

    @Test("Alias 'Plank' resolves to Planks and returns isometric")
    func plankAlias_resolvesToPlanks() {
        let result = ExerciseSuggestionService.isIsometric("Plank")
        #expect(result == true)
    }

    @Test("Alias 'Hollow Body Hold' resolves to Hollow Hold")
    func hollowBodyHoldAlias_resolvesToHollowHold() {
        let result = ExerciseSuggestionService.isIsometric("Hollow Body Hold")
        #expect(result == true)
    }

    @Test("Bench Press is not isometric")
    func benchPress_isNotIsometric() {
        let result = ExerciseSuggestionService.isIsometric("Bench Press")
        #expect(result == false)
    }

    @Test("Squats is not isometric")
    func squats_isNotIsometric() {
        let result = ExerciseSuggestionService.isIsometric("Squats")
        #expect(result == false)
    }

    @Test("Battle Ropes uses ambiguous default (time-based)")
    func battleRopes_ambiguousDefaultIsTime() {
        let result = ExerciseSuggestionService.isIsometric("Battle Ropes")
        #expect(result == true)
    }

    @Test("Burpees uses ambiguous default (reps-based)")
    func burpees_ambiguousDefaultIsReps() {
        let result = ExerciseSuggestionService.isIsometric("Burpees")
        #expect(result == false)
    }
}

// MARK: - displayAsTime Resolution Tests

@Suite("DisplayAsTimeResolution")
struct DisplayAsTimeResolutionTests {

    @Test("displayAsTime true overrides non-isometric exercise to time-based")
    func displayAsTrue_overridesNonIsometric() {
        let exercise = SnapshotExercise(
            exerciseName: "Bench Press",
            sets: 3,
            reps: 30,
            weightKg: nil,
            sortOrder: 0,
            restSeconds: nil,
            displayAsTime: true
        )
        let isTime = exercise.displayAsTime ?? ExerciseSuggestionService.isIsometric(exercise.exerciseName)
        #expect(isTime == true)
    }

    @Test("displayAsTime false overrides isometric exercise to reps-based")
    func displayAsFalse_overridesIsometric() {
        let exercise = SnapshotExercise(
            exerciseName: "Planks",
            sets: 3,
            reps: 60,
            weightKg: nil,
            sortOrder: 0,
            restSeconds: nil,
            displayAsTime: false
        )
        let isTime = exercise.displayAsTime ?? ExerciseSuggestionService.isIsometric(exercise.exerciseName)
        #expect(isTime == false)
    }

    @Test("displayAsTime nil falls back to dictionary for isometric exercise")
    func displayAsNil_fallsToDictionaryForIsometric() {
        let exercise = SnapshotExercise(
            exerciseName: "Planks",
            sets: 3,
            reps: 60,
            weightKg: nil,
            sortOrder: 0,
            restSeconds: nil,
            displayAsTime: nil
        )
        let isTime = exercise.displayAsTime ?? ExerciseSuggestionService.isIsometric(exercise.exerciseName)
        #expect(isTime == true)
    }

    @Test("displayAsTime nil falls back to dictionary for reps exercise")
    func displayAsNil_fallsToDictionaryForReps() {
        let exercise = SnapshotExercise(
            exerciseName: "Squats",
            sets: 3,
            reps: 10,
            weightKg: 100.0,
            sortOrder: 0,
            restSeconds: nil,
            displayAsTime: nil
        )
        let isTime = exercise.displayAsTime ?? ExerciseSuggestionService.isIsometric(exercise.exerciseName)
        #expect(isTime == false)
    }
}

// MARK: - Sync Gate Tests

@Suite("WatchScheduleServiceGates")
struct WatchScheduleServiceGateTests {

    @MainActor
    private func makeServiceAndContext() throws -> (WatchScheduleService, ModelContext) {
        let context = try makePlanTestContext()
        let service = WatchScheduleService(scheduler: NoOpWorkoutScheduler())
        return (service, context)
    }

    @MainActor
    private func makeScheduledWorkout(
        syncToAppleWatch: Bool = true,
        scheduledTime: Date? = Date(),
        scheduledDate: Date = PlanTestFactory.tomorrow,
        snapshotData: Data? = nil,
        context: ModelContext
    ) -> ScheduledWorkout {
        let sw = ScheduledWorkout(
            scheduledDate: scheduledDate,
            workoutType: "Strength Training",
            workoutName: "Test Workout"
        )
        sw.syncToAppleWatch = syncToAppleWatch
        sw.scheduledTime = scheduledTime
        if let data = snapshotData {
            sw.scheduledWorkoutSnapshot = data
        } else {
            let exercises = [
                SnapshotExercise(exerciseName: "Bench Press", sets: 3, reps: 10, weightKg: 80.0, sortOrder: 0, restSeconds: nil, displayAsTime: nil)
            ]
            sw.scheduledWorkoutSnapshot = try? JSONEncoder().encode(exercises)
        }
        context.insert(sw)
        try? context.save()
        return sw
    }

    @Test("All gates pass when conditions met")
    @MainActor
    func allGatesPass_whenConditionsMet() throws {
        let (service, context) = try makeServiceAndContext()
        service.authState = .granted
        UserSettings.shared.syncPlanToAppleWatchEnabled = true

        let sw = makeScheduledWorkout(context: context)
        #expect(service.gatesPass(for: sw) == true)
    }

    @Test("Gate fails when master toggle off")
    @MainActor
    func gateFails_masterToggleOff() throws {
        let (service, context) = try makeServiceAndContext()
        service.authState = .granted
        UserSettings.shared.syncPlanToAppleWatchEnabled = false

        let sw = makeScheduledWorkout(context: context)
        #expect(service.gatesPass(for: sw) == false)
        #expect(service.gateFailureReason(for: sw) == .masterOff)
    }

    @Test("Gate fails when auth denied")
    @MainActor
    func gateFails_authDenied() throws {
        let (service, context) = try makeServiceAndContext()
        service.authState = .denied
        UserSettings.shared.syncPlanToAppleWatchEnabled = true

        let sw = makeScheduledWorkout(context: context)
        #expect(service.gatesPass(for: sw) == false)
        #expect(service.gateFailureReason(for: sw) == .authDenied)
    }

    @Test("Gate passes when no scheduled time (noon fallback)")
    @MainActor
    func gatePasses_noScheduledTime() throws {
        let (service, context) = try makeServiceAndContext()
        service.authState = .granted
        UserSettings.shared.syncPlanToAppleWatchEnabled = true

        let sw = makeScheduledWorkout(scheduledTime: nil, context: context)
        #expect(service.gatesPass(for: sw) == true)
    }

    @Test("Gate fails when date is in the past")
    @MainActor
    func gateFails_pastDate() throws {
        let (service, context) = try makeServiceAndContext()
        service.authState = .granted
        UserSettings.shared.syncPlanToAppleWatchEnabled = true

        let sw = makeScheduledWorkout(scheduledDate: PlanTestFactory.yesterday, context: context)
        #expect(service.gatesPass(for: sw) == false)
        #expect(service.gateFailureReason(for: sw) == .pastDate)
    }

    @Test("Gate fails when no exercises in snapshot")
    @MainActor
    func gateFails_noExercises() throws {
        let (service, context) = try makeServiceAndContext()
        service.authState = .granted
        UserSettings.shared.syncPlanToAppleWatchEnabled = true

        let emptySnapshot = try JSONEncoder().encode([SnapshotExercise]())
        let sw = makeScheduledWorkout(snapshotData: emptySnapshot, context: context)
        #expect(service.gatesPass(for: sw) == false)
        #expect(service.gateFailureReason(for: sw) == .noExercises)
    }
}

// MARK: - SnapshotExercise restSeconds / displayAsTime Encoding Tests

@Suite("SnapshotExerciseEncoding")
struct SnapshotExerciseEncodingTests {

    @Test("restSeconds and displayAsTime round-trip through JSON")
    func restSecondsAndDisplayAsTime_roundTrip() throws {
        let exercises = [
            SnapshotExercise(exerciseName: "Planks", sets: 3, reps: 60, weightKg: nil, sortOrder: 0, restSeconds: 30, displayAsTime: true),
            SnapshotExercise(exerciseName: "Bench Press", sets: 4, reps: 8, weightKg: 100.0, sortOrder: 1, restSeconds: 90, displayAsTime: false)
        ]
        let data = try JSONEncoder().encode(exercises)
        let decoded = try JSONDecoder().decode([SnapshotExercise].self, from: data)

        #expect(decoded.count == 2)
        #expect(decoded[0].restSeconds == 30)
        #expect(decoded[0].displayAsTime == true)
        #expect(decoded[1].restSeconds == 90)
        #expect(decoded[1].displayAsTime == false)
    }

    @Test("Nil restSeconds and displayAsTime decode correctly from legacy data")
    func nilFields_decodeFromLegacyData() throws {
        let exercises = [
            SnapshotExercise(exerciseName: "Squats", sets: 3, reps: 10, weightKg: 80.0, sortOrder: 0)
        ]
        let data = try JSONEncoder().encode(exercises)
        let decoded = try JSONDecoder().decode([SnapshotExercise].self, from: data)

        #expect(decoded[0].restSeconds == nil)
        #expect(decoded[0].displayAsTime == nil)
    }
}

// MARK: - PlanService.completeFromWatch Tests

@Suite("PlanServiceCompleteFromWatch")
struct PlanServiceCompleteFromWatchTests {

    @Test("completeFromWatch creates workout and marks scheduled as completed")
    @MainActor
    func completeFromWatch_createsWorkoutAndMarksCompleted() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(
            template: template,
            date: PlanTestFactory.tomorrow,
            time: Date(),
            recurrenceRule: nil,
            context: context
        )

        let scheduledDescriptor = FetchDescriptor<ScheduledWorkout>()
        let scheduled = try context.fetch(scheduledDescriptor)
        #expect(scheduled.count == 1)

        let sw = scheduled[0]
        sw.appleWorkoutPlanId = UUID()
        try context.save()

        let hkSnapshot = HealthKitWorkoutSnapshot(
            uuid: UUID(),
            activityTypeRawValue: 50,
            sourceBundleID: "com.apple.health.workout-builder",
            startDate: Date().addingTimeInterval(-3600),
            endDate: Date(),
            durationMinutes: 60,
            distanceKm: nil,
            avgHeartRate: 145,
            maxHeartRate: 170,
            activeEnergyKcal: 500,
            totalEnergyBurnedKcal: nil,
            elevationAscendedMeters: nil,
            exerciseMinutes: nil,
            indoor: false,
            workoutPlanId: sw.appleWorkoutPlanId
        )

        PlanService.completeFromWatch(
            scheduledWorkout: sw,
            hkSnapshot: hkSnapshot,
            context: context
        )

        #expect(sw.status == "completed")
        #expect(sw.completedWorkoutId != nil)

        let workoutDescriptor = FetchDescriptor<Workout>()
        let workouts = try context.fetch(workoutDescriptor)
        #expect(workouts.count == 1)

        let workout = workouts[0]
        #expect(workout.healthKitUUID == hkSnapshot.uuid)
        #expect(workout.avgHeartRate == 145)
        #expect(workout.activeEnergyKcal == 500)
        #expect(workout.name == sw.workoutName)
    }
}

// MARK: - PlanService.findByPlanId Tests

@Suite("PlanServiceFindByPlanId")
struct PlanServiceFindByPlanIdTests {

    @Test("findByPlanId returns matching scheduled workout")
    @MainActor
    func findByPlanId_returnsMatch() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(
            template: template,
            date: PlanTestFactory.tomorrow,
            time: nil,
            recurrenceRule: nil,
            context: context
        )

        let descriptor = FetchDescriptor<ScheduledWorkout>()
        let sw = try context.fetch(descriptor).first!
        let planId = UUID()
        sw.appleWorkoutPlanId = planId
        try context.save()

        let found = PlanService.findByPlanId(planId, context: context)
        #expect(found != nil)
        #expect(found?.id == sw.id)
    }

    @Test("findByPlanId returns nil for unmatched UUID")
    @MainActor
    func findByPlanId_returnsNilForUnmatched() throws {
        let context = try makePlanTestContext()
        let found = PlanService.findByPlanId(UUID(), context: context)
        #expect(found == nil)
    }
}

// MARK: - PlanService.editScheduledWorkout Tests

@Suite("PlanServiceEditScheduledWorkout")
struct PlanServiceEditScheduledWorkoutTests {

    @Test("editScheduledWorkout applies edits to this-only for non-recurring")
    @MainActor
    func editScheduledWorkout_thisOnly_appliesEdits() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(
            template: template,
            date: PlanTestFactory.tomorrow,
            time: nil,
            recurrenceRule: nil,
            context: context
        )

        let descriptor = FetchDescriptor<ScheduledWorkout>()
        let sw = try context.fetch(descriptor).first!

        let newExercises = [
            SnapshotExercise(exerciseName: "Deadlift", sets: 5, reps: 5, weightKg: 120.0, sortOrder: 0)
        ]

        let edits = PlanService.ScheduledWorkoutEdits(
            workoutName: "Updated Push Day",
            scheduledDate: PlanTestFactory.tomorrow,
            scheduledTime: Date(),
            durationMinutes: 90,
            exercises: newExercises,
            syncToAppleWatch: true,
            workoutType: "Strength Training"
        )

        let affected = PlanService.editScheduledWorkout(sw, edits: edits, applyTo: .thisOnly, context: context)

        #expect(affected.count == 1)
        #expect(sw.workoutName == "Updated Push Day")
        #expect(sw.durationMinutes == 90)
        #expect(sw.syncToAppleWatch == true)
    }
}

// MARK: - Phase 8.7.1: Schedule Workout Push Default Tests

@Suite("ScheduleWorkoutPushDefault")
struct ScheduleWorkoutPushDefaultTests {

    @Test("scheduleWorkout with syncToAppleWatch=true sets flag on created workout")
    @MainActor
    func scheduleWorkout_syncTrue_setsFlagOnCreatedWorkout() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        let created = PlanService.scheduleWorkout(
            template: template,
            date: PlanTestFactory.tomorrow,
            time: Date(),
            recurrenceRule: nil,
            syncToAppleWatch: true,
            context: context
        )

        #expect(created.count == 1)
        #expect(created[0].syncToAppleWatch == true)
    }

    @Test("scheduleWorkout with syncToAppleWatch=false (default) keeps flag false")
    @MainActor
    func scheduleWorkout_syncDefault_flagIsFalse() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        let created = PlanService.scheduleWorkout(
            template: template,
            date: PlanTestFactory.tomorrow,
            time: nil,
            recurrenceRule: nil,
            context: context
        )

        #expect(created.count == 1)
        #expect(created[0].syncToAppleWatch == false)
    }

    @Test("scheduleWorkout returns created ScheduledWorkouts")
    @MainActor
    func scheduleWorkout_returnsCreatedWorkouts() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        let created = PlanService.scheduleWorkout(
            template: template,
            date: PlanTestFactory.tomorrow,
            time: nil,
            recurrenceRule: nil,
            context: context
        )

        #expect(created.count == 1)
        #expect(created[0].workoutName == template.name)
    }

    @Test("recurring schedule with syncToAppleWatch=true sets flag on all instances")
    @MainActor
    func recurringSchedule_syncTrue_allInstancesHaveFlag() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        let created = PlanService.scheduleWorkout(
            template: template,
            date: PlanTestFactory.tomorrow,
            time: Date(),
            recurrenceRule: "weekly",
            syncToAppleWatch: true,
            context: context
        )

        #expect(created.count == 12)
        for sw in created {
            #expect(sw.syncToAppleWatch == true, "Every recurring instance should inherit syncToAppleWatch")
        }
    }

    @Test("recurring schedule with time propagates scheduledTime to all instances")
    @MainActor
    func recurringSchedule_withTime_allInstancesHaveTime() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)
        let time = Date()

        let created = PlanService.scheduleWorkout(
            template: template,
            date: PlanTestFactory.tomorrow,
            time: time,
            recurrenceRule: "weekly",
            syncToAppleWatch: true,
            context: context
        )

        for sw in created {
            #expect(sw.scheduledTime != nil, "Every recurring instance should inherit scheduledTime when time is provided")
        }
    }
}

// MARK: - Phase 8.7.1: Recurrence Regeneration Inherits syncToAppleWatch

@Suite("RecurrenceRegenerationSyncInheritance")
struct RecurrenceRegenerationSyncInheritanceTests {

    @Test("regenerateRecurrenceIfNeeded inherits syncToAppleWatch from latest instance")
    @MainActor
    func regenerateRecurrence_inheritsSyncFlag() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        let created = PlanService.scheduleWorkout(
            template: template,
            date: PlanTestFactory.tomorrow,
            time: Date(),
            recurrenceRule: "weekly",
            syncToAppleWatch: true,
            context: context
        )

        let groupId = created.first!.recurrenceGroupId!

        // Delete most future instances to trigger regeneration
        let sorted = created.sorted { $0.scheduledDate < $1.scheduledDate }
        for sw in sorted.dropFirst(2) {
            context.delete(sw)
        }
        try context.save()

        PlanService.regenerateRecurrenceIfNeeded(groupId: groupId, context: context)

        let allInstances = try context.fetch(FetchDescriptor<ScheduledWorkout>())
        for sw in allInstances {
            #expect(sw.syncToAppleWatch == true, "Regenerated instances should inherit syncToAppleWatch")
        }
    }
}

// MARK: - Phase 8.7.1: Copy Rename Verification

@Suite("Phase871CopyRename")
struct Phase871CopyRenameTests {

    @Test("Settings toggle label uses 'Sync to Apple Watch'")
    func settingsToggleLabel_usesPush() {
        #expect(AppConstants.AppleWatch.settingsToggleLabel == "Sync to Apple Watch")
    }

    @Test("Edit Planned Workout toggle label uses 'Push' not 'Sync'")
    func editToggleLabel_usesPush() {
        #expect(AppConstants.AppleWatch.watchSyncToggleLabel.contains("Push"))
        #expect(!AppConstants.AppleWatch.watchSyncToggleLabel.contains("Sync"))
    }

    @Test("Master off popover title uses 'Push' not 'sync'")
    func masterOffTitle_usesPush() {
        #expect(AppConstants.AppleWatch.masterOffTitle.contains("Push"))
        #expect(!AppConstants.AppleWatch.masterOffTitle.lowercased().contains("sync"))
    }

    @Test("Schedule Workout toggle label exists and uses 'Push'")
    func scheduleWorkoutToggleLabel_usesPush() {
        #expect(AppConstants.AppleWatch.scheduleWorkoutToggleLabel == "Push to Apple Watch")
    }

    @Test("settingsTurnOffConfirmTitle uses 'Push' not 'Sync'")
    func settingsTurnOffConfirmTitle_usesPush() {
        #expect(AppConstants.AppleWatch.settingsTurnOffConfirmTitle.contains("Push"))
    }
}
