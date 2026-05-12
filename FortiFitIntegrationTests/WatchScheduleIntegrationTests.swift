import XCTest
import SwiftData
@testable import FortiFit

@MainActor
final class WatchScheduleIntegrationTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        let result = try TestFixtures.inMemoryContext()
        container = result.0
        context = result.1
    }

    // MARK: - Plan-ID Fast-Path

    func test_planIdFastPath_completesScheduledWorkoutViaPlanService() async throws {
        let template = TestFixtures.makeTemplate(
            name: "Push Day",
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 80)],
            in: context
        )

        PlanService.scheduleWorkout(
            template: template,
            date: TestFixtures.startOfDay(.now),
            time: nil,
            recurrenceRule: nil,
            context: context
        )

        let sw = try context.fetch(FetchDescriptor<ScheduledWorkout>()).first!
        let planId = UUID()
        sw.appleWorkoutPlanId = planId
        try context.save()

        let stubClient = StubHealthKitClient()
        let matcher = WorkoutMatcher()
        let syncService = HealthKitSyncService(client: stubClient, matcher: matcher)
        syncService.setContext(context)
        UserSettings.shared.healthKitEnabled = true

        let hkSnapshot = TestFixtures.makeHKWorkoutFixture(
            activityTypeRawValue: 50,
            startDate: TestFixtures.daysAgo(0),
            durationMinutes: 60,
            workoutPlanId: planId
        )
        stubClient.workoutsToReturn = [hkSnapshot]

        await syncService.importPendingWorkouts(context: context)

        XCTAssertEqual(sw.status, "completed", "ScheduledWorkout should be marked completed via plan-ID fast-path")
        XCTAssertNotNil(sw.completedWorkoutId, "Should have a linked completed workout ID")

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(workouts.count, 1, "Exactly one workout should be created")
        XCTAssertEqual(workouts.first?.healthKitUUID, hkSnapshot.uuid)
    }

    func test_planIdFastPath_doesNotDuplicateIfAlreadyImported() async throws {
        let template = TestFixtures.makeTemplate(name: "Leg Day", in: context)

        PlanService.scheduleWorkout(
            template: template,
            date: TestFixtures.startOfDay(.now),
            time: nil,
            recurrenceRule: nil,
            context: context
        )

        let sw = try context.fetch(FetchDescriptor<ScheduledWorkout>()).first!
        let planId = UUID()
        sw.appleWorkoutPlanId = planId
        try context.save()

        let hkUUID = UUID()
        let stubClient = StubHealthKitClient()
        let matcher = WorkoutMatcher()
        let syncService = HealthKitSyncService(client: stubClient, matcher: matcher)
        syncService.setContext(context)
        UserSettings.shared.healthKitEnabled = true

        let hkSnapshot = TestFixtures.makeHKWorkoutFixture(
            uuid: hkUUID,
            activityTypeRawValue: 50,
            durationMinutes: 60,
            workoutPlanId: planId
        )
        stubClient.workoutsToReturn = [hkSnapshot]

        await syncService.importPendingWorkouts(context: context)

        let firstCount = try context.fetch(FetchDescriptor<Workout>()).count
        XCTAssertEqual(firstCount, 1)

        stubClient.workoutsToReturn = [hkSnapshot]
        await syncService.importPendingWorkouts(context: context)

        let secondCount = try context.fetch(FetchDescriptor<Workout>()).count
        XCTAssertEqual(secondCount, 1, "Should not duplicate workout on repeated import")
    }

    // MARK: - Master Toggle Off/On

    func test_masterToggleOff_removesAllPlansButRetainsFlags() async throws {
        let service = WatchScheduleService(scheduler: NoOpWorkoutScheduler())
        service.authState = .granted
        UserSettings.shared.syncPlanToAppleWatchEnabled = true

        let template = TestFixtures.makeTemplate(
            name: "Push Day",
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 80)],
            in: context
        )

        PlanService.scheduleWorkout(
            template: template,
            date: TestFixtures.startOfDay(TestFixtures.daysAgo(-1)),
            time: Date(),
            recurrenceRule: nil,
            context: context
        )

        let sw = try context.fetch(FetchDescriptor<ScheduledWorkout>()).first!
        sw.syncToAppleWatch = true
        sw.appleWorkoutPlanId = UUID()
        try context.save()

        await service.handleMasterToggleOff(context: context)

        XCTAssertTrue(sw.syncToAppleWatch, "Per-card intent flag should be retained after master toggle off")
    }

    func test_masterToggleOn_reconcilesSyncedWorkouts() async throws {
        let service = WatchScheduleService(scheduler: NoOpWorkoutScheduler())
        service.authState = .granted
        UserSettings.shared.syncPlanToAppleWatchEnabled = true

        let template = TestFixtures.makeTemplate(
            name: "Push Day",
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 80)],
            in: context
        )

        PlanService.scheduleWorkout(
            template: template,
            date: TestFixtures.startOfDay(TestFixtures.daysAgo(-1)),
            time: Date(),
            recurrenceRule: nil,
            context: context
        )

        let sw = try context.fetch(FetchDescriptor<ScheduledWorkout>()).first!
        sw.syncToAppleWatch = true
        try context.save()

        await service.handleMasterToggleOn(context: context)

        XCTAssertNotNil(sw.appleWorkoutPlanId, "Reconciliation should stamp a plan ID on synced workouts")
    }

    // MARK: - Edit Scheduled Workout → Resync

    func test_editScheduledWorkout_resyncCalledWithSameUUID() async throws {
        let service = WatchScheduleService(scheduler: NoOpWorkoutScheduler())
        service.authState = .granted
        UserSettings.shared.syncPlanToAppleWatchEnabled = true

        let template = TestFixtures.makeTemplate(
            name: "Push Day",
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 80)],
            in: context
        )

        PlanService.scheduleWorkout(
            template: template,
            date: TestFixtures.startOfDay(TestFixtures.daysAgo(-1)),
            time: Date(),
            recurrenceRule: nil,
            context: context
        )

        let sw = try context.fetch(FetchDescriptor<ScheduledWorkout>()).first!
        sw.syncToAppleWatch = true
        await service.schedule(sw, context: context)
        let originalPlanId = sw.appleWorkoutPlanId

        let edits = PlanService.ScheduledWorkoutEdits(
            workoutName: "Updated Push Day",
            scheduledDate: sw.scheduledDate,
            scheduledTime: sw.scheduledTime,
            durationMinutes: 90,
            exercises: [
                SnapshotExercise(exerciseName: "Deadlift", sets: 5, reps: 5, weightKg: 120, sortOrder: 0)
            ],
            syncToAppleWatch: true,
            workoutType: "Strength Training"
        )

        let affected = PlanService.editScheduledWorkout(sw, edits: edits, applyTo: .thisOnly, context: context)

        for instance in affected where instance.syncToAppleWatch {
            await service.resync(instance, context: context)
        }

        XCTAssertEqual(sw.workoutName, "Updated Push Day")
        XCTAssertEqual(sw.appleWorkoutPlanId, originalPlanId, "Plan UUID should remain stable across edits")
    }

    // MARK: - Recurring Workout Scheduling

    func test_recurringSchedule_inheritsSyncIntent() throws {
        let template = TestFixtures.makeTemplate(
            name: "Push Day",
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 80)],
            in: context
        )

        PlanService.scheduleWorkout(
            template: template,
            date: TestFixtures.startOfDay(TestFixtures.daysAgo(-1)),
            time: Date(),
            recurrenceRule: "weekly",
            context: context
        )

        let allScheduled = try context.fetch(FetchDescriptor<ScheduledWorkout>())
        XCTAssertEqual(allScheduled.count, 12, "Weekly recurrence should generate 12 instances")

        let first = allScheduled.sorted { $0.scheduledDate < $1.scheduledDate }.first!
        first.syncToAppleWatch = true
        try context.save()

        XCTAssertTrue(first.syncToAppleWatch, "First instance should have sync flag set")
    }

    // MARK: - Phase 8.7.1: Save Flow with syncToAppleWatch

    func test_scheduleWorkout_syncTrue_reflectsToggleState() throws {
        let template = TestFixtures.makeTemplate(
            name: "Push Day",
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 80)],
            in: context
        )

        let created = PlanService.scheduleWorkout(
            template: template,
            date: TestFixtures.startOfDay(TestFixtures.daysAgo(-1)),
            time: Date(),
            recurrenceRule: nil,
            syncToAppleWatch: true,
            context: context
        )

        XCTAssertEqual(created.count, 1)
        XCTAssertTrue(created[0].syncToAppleWatch, "syncToAppleWatch should reflect toggle state at save time")
    }

    func test_scheduleWorkout_syncFalse_reflectsToggleState() throws {
        let template = TestFixtures.makeTemplate(
            name: "Push Day",
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 80)],
            in: context
        )

        let created = PlanService.scheduleWorkout(
            template: template,
            date: TestFixtures.startOfDay(TestFixtures.daysAgo(-1)),
            time: nil,
            recurrenceRule: nil,
            syncToAppleWatch: false,
            context: context
        )

        XCTAssertEqual(created.count, 1)
        XCTAssertFalse(created[0].syncToAppleWatch, "syncToAppleWatch should be false when Push is off")
    }

    func test_recurringSchedule_pushOn_allInstancesInheritPushAndTime() throws {
        let template = TestFixtures.makeTemplate(
            name: "Push Day",
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 80)],
            in: context
        )
        let time = Date()

        let created = PlanService.scheduleWorkout(
            template: template,
            date: TestFixtures.startOfDay(TestFixtures.daysAgo(-1)),
            time: time,
            recurrenceRule: "weekly",
            syncToAppleWatch: true,
            context: context
        )

        XCTAssertEqual(created.count, 12, "Weekly recurrence should generate 12 instances")

        for (index, sw) in created.enumerated() {
            XCTAssertTrue(sw.syncToAppleWatch, "Instance \(index) should inherit syncToAppleWatch=true")
            XCTAssertNotNil(sw.scheduledTime, "Instance \(index) should have scheduledTime")
        }
    }

    func test_scheduleWorkout_syncTrue_watchServiceSchedulesCalled() async throws {
        let service = WatchScheduleService(scheduler: NoOpWorkoutScheduler())
        service.authState = .granted
        UserSettings.shared.syncPlanToAppleWatchEnabled = true

        let template = TestFixtures.makeTemplate(
            name: "Push Day",
            exercises: [.init("Bench Press", sets: 3, reps: 8, weightKg: 80)],
            in: context
        )

        let created = PlanService.scheduleWorkout(
            template: template,
            date: TestFixtures.startOfDay(TestFixtures.daysAgo(-1)),
            time: Date(),
            recurrenceRule: nil,
            syncToAppleWatch: true,
            context: context
        )

        let sw = created[0]
        await service.schedule(sw, context: context)

        XCTAssertNotNil(sw.appleWorkoutPlanId, "appleWorkoutPlanId should be stamped after scheduling")
    }
}
