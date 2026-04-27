import XCTest
import SwiftData
@testable import FortiFit

@MainActor
final class HealthKitIntegrationTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        let result = try TestFixtures.inMemoryContext()
        container = result.0
        context = result.1
    }

    // MARK: - Auto-Create Cascade

    func test_autoCreateFromHK_triggersWorkoutCascade() async throws {
        let stubClient = StubHealthKitClient()
        let matcher = WorkoutMatcher()
        let syncService = HealthKitSyncService(client: stubClient, matcher: matcher)
        syncService.setContext(context)

        UserSettings.shared.healthKitEnabled = true

        let snapshot = TestFixtures.makeHKWorkoutFixture(
            activityTypeRawValue: 50,
            startDate: TestFixtures.daysAgo(1),
            durationMinutes: 60
        )
        stubClient.workoutsToReturn = [snapshot]

        await syncService.importPendingWorkouts(context: context)

        let workouts = WorkoutService.fetchAll(context: context)
        XCTAssertEqual(workouts.count, 1)
        let workout = workouts.first!
        XCTAssertEqual(workout.healthKitUUID, snapshot.uuid)
        XCTAssertEqual(workout.workoutType, "Strength Training")
        XCTAssertEqual(workout.durationMinutes, 60)
        XCTAssertTrue(workout.isHealthKitLinked)
    }

    func test_autoCreate_2MinFloor_filtersShortWorkouts() async throws {
        let stubClient = StubHealthKitClient()
        let matcher = WorkoutMatcher()
        let syncService = HealthKitSyncService(client: stubClient, matcher: matcher)
        syncService.setContext(context)

        UserSettings.shared.healthKitEnabled = true

        let shortSnapshot = TestFixtures.makeHKWorkoutFixture(durationMinutes: 1)
        let normalSnapshot = TestFixtures.makeHKWorkoutFixture(durationMinutes: 10)
        stubClient.workoutsToReturn = [shortSnapshot, normalSnapshot]

        await syncService.importPendingWorkouts(context: context)

        let workouts = WorkoutService.fetchAll(context: context)
        XCTAssertEqual(workouts.count, 1, "Only the 10-min workout should be auto-created; 1-min filtered")
    }

    // MARK: - Link Flow (HK-side)

    func test_highConfidenceMatch_autoLinks() async throws {
        let now = Date()
        let manualWorkout = TestFixtures.makeWorkout(
            name: "Push Day",
            date: now,
            workoutType: "Strength Training",
            durationMinutes: 45,
            in: context
        )

        let stubClient = StubHealthKitClient()
        let matcher = WorkoutMatcher()
        let syncService = HealthKitSyncService(client: stubClient, matcher: matcher)
        syncService.setContext(context)

        UserSettings.shared.healthKitEnabled = true

        let snapshot = TestFixtures.makeHKWorkoutFixture(startDate: now, durationMinutes: 45)
        stubClient.workoutsToReturn = [snapshot]

        await syncService.importPendingWorkouts(context: context)

        let workouts = WorkoutService.fetchAll(context: context)
        XCTAssertEqual(workouts.count, 1, "Should link, not create a second workout")
        XCTAssertEqual(workouts.first?.healthKitUUID, snapshot.uuid)
        XCTAssertEqual(workouts.first?.name, "Push Day", "User-owned name preserved")
    }

    func test_lowerConfidenceMatch_queuesPending() async throws {
        let cal = Calendar.current
        let morning = cal.startOfDay(for: Date()).addingTimeInterval(3600 * 8)
        TestFixtures.makeWorkout(
            name: "Push Day",
            date: morning,
            workoutType: "Strength Training",
            durationMinutes: 45,
            in: context
        )

        let stubClient = StubHealthKitClient()
        let matcher = WorkoutMatcher()
        let syncService = HealthKitSyncService(client: stubClient, matcher: matcher)
        syncService.setContext(context)

        UserSettings.shared.healthKitEnabled = true

        let snapshot = TestFixtures.makeHKWorkoutFixture(
            startDate: morning.addingTimeInterval(3600 * 2),
            durationMinutes: 45
        )
        stubClient.workoutsToReturn = [snapshot]

        await syncService.importPendingWorkouts(context: context)

        XCTAssertEqual(matcher.pendingMatches().count, 1)
        let workouts = WorkoutService.fetchAll(context: context)
        XCTAssertEqual(workouts.count, 1, "No auto-create for lower confidence — queued instead")
    }

    // MARK: - Upstream Delete

    func test_upstreamDelete_nullsOutHKFieldsButKeepsWorkout() async throws {
        let hkUUID = UUID()
        TestFixtures.makeLinkedWorkout(
            name: "HK Run",
            workoutType: "Cardio",
            healthKitUUID: hkUUID,
            in: context
        )

        let stubClient = StubHealthKitClient()
        let matcher = WorkoutMatcher()
        let syncService = HealthKitSyncService(client: stubClient, matcher: matcher)
        syncService.setContext(context)

        UserSettings.shared.healthKitEnabled = true

        stubClient.deletedUUIDsToReturn = [hkUUID]
        stubClient.workoutsToReturn = []

        await syncService.importPendingWorkouts(context: context)

        let workouts = WorkoutService.fetchAll(context: context)
        XCTAssertEqual(workouts.count, 1, "Workout should be preserved")
        XCTAssertNil(workouts.first?.healthKitUUID, "HK UUID should be nulled out")
        XCTAssertFalse(workouts.first?.isHealthKitLinked ?? true)
        XCTAssertEqual(workouts.first?.name, "HK Run", "Name preserved")
    }

    // MARK: - Rejection Blocks Re-proposal

    func test_rejectedPair_blocksReMatching() async throws {
        let now = Date()
        let workout = TestFixtures.makeWorkout(
            name: "My Workout",
            date: now,
            workoutType: "Strength Training",
            durationMinutes: 45,
            in: context
        )

        let hkUUID = UUID()
        let rejection = WorkoutMatchRejection(healthKitUUID: hkUUID, workoutId: workout.id)
        context.insert(rejection)
        try context.save()

        let stubClient = StubHealthKitClient()
        let matcher = WorkoutMatcher()
        let syncService = HealthKitSyncService(client: stubClient, matcher: matcher)
        syncService.setContext(context)

        UserSettings.shared.healthKitEnabled = true

        let snapshot = TestFixtures.makeHKWorkoutFixture(uuid: hkUUID, startDate: now, durationMinutes: 45)
        stubClient.workoutsToReturn = [snapshot]

        await syncService.importPendingWorkouts(context: context)

        XCTAssertTrue(matcher.pendingMatches().isEmpty, "Rejected pair should not be queued")
    }

    // MARK: - Effort Score Nil-Fill

    func test_effortScore_nilFillOnAutoCreate() async throws {
        let stubClient = StubHealthKitClient()
        stubClient.effortScoreToReturn = 7
        let matcher = WorkoutMatcher()
        let syncService = HealthKitSyncService(client: stubClient, matcher: matcher)
        syncService.setContext(context)

        UserSettings.shared.healthKitEnabled = true

        let snapshot = TestFixtures.makeHKWorkoutFixture(durationMinutes: 30)
        stubClient.workoutsToReturn = [snapshot]

        await syncService.importPendingWorkouts(context: context)

        let workouts = WorkoutService.fetchAll(context: context)
        XCTAssertEqual(workouts.first?.rpe, 7, "Effort score should nil-fill into rpe")
    }

    func test_effortScore_doesNotOverwriteExistingRPE() async throws {
        let now = Date()
        let workout = TestFixtures.makeWorkout(
            name: "Push Day",
            date: now,
            workoutType: "Strength Training",
            rpe: 8,
            durationMinutes: 45,
            in: context
        )

        let stubClient = StubHealthKitClient()
        stubClient.effortScoreToReturn = 5
        let matcher = WorkoutMatcher()
        let syncService = HealthKitSyncService(client: stubClient, matcher: matcher)
        syncService.setContext(context)

        UserSettings.shared.healthKitEnabled = true

        let snapshot = TestFixtures.makeHKWorkoutFixture(startDate: now, durationMinutes: 45)
        stubClient.workoutsToReturn = [snapshot]

        await syncService.importPendingWorkouts(context: context)

        XCTAssertEqual(workout.rpe, 8, "Existing RPE should NOT be overwritten")
    }

    // MARK: - Sprints Migration

    func test_sprintsMigration_isIdempotent() throws {
        UserSettings.shared.hasMigratedSprintsToCardio = false

        let sprintsWorkout = Workout(name: "Sprint Session", workoutType: "Sprints")
        context.insert(sprintsWorkout)
        try context.save()

        WorkoutService.migrateSprintsToCardioIfNeeded(context: context)

        let workouts = WorkoutService.fetchAll(context: context)
        XCTAssertEqual(workouts.first?.workoutType, "Cardio")

        WorkoutService.migrateSprintsToCardioIfNeeded(context: context)

        let workoutsAfter = WorkoutService.fetchAll(context: context)
        XCTAssertEqual(workoutsAfter.count, 1)
        XCTAssertEqual(workoutsAfter.first?.workoutType, "Cardio")
    }

    // MARK: - Unlink Behavior

    func test_unlink_clearsHKFieldsPreservesWorkout() throws {
        let hkUUID = UUID()
        let workout = TestFixtures.makeLinkedWorkout(
            name: "HK Strength",
            healthKitUUID: hkUUID,
            durationMinutes: 60,
            in: context
        )

        XCTAssertTrue(workout.isHealthKitLinked)

        WorkoutService.unlink(workout, context: context)

        XCTAssertFalse(workout.isHealthKitLinked)
        XCTAssertNil(workout.healthKitUUID)
        XCTAssertNil(workout.healthKitSourceBundleID)
        XCTAssertNil(workout.healthKitActivityType)
        XCTAssertEqual(workout.name, "HK Strength")
        XCTAssertEqual(workout.durationMinutes, 60)
    }

    // MARK: - Effort Score Backfill (BUG-023)

    /// Regression test for BUG-023:
    /// Upstream update on a linked workout with nil rpe now nil-fills the effort score.
    func test_upstreamUpdate_nilFillsEffortScoreWhenRPEIsNil() async throws {
        let hkUUID = UUID()
        let workout = TestFixtures.makeLinkedWorkout(
            name: "Morning Run",
            workoutType: "Cardio",
            healthKitUUID: hkUUID,
            durationMinutes: 30,
            in: context
        )
        XCTAssertNil(workout.rpe)

        let stubClient = StubHealthKitClient()
        stubClient.effortScoreToReturn = 6
        let matcher = WorkoutMatcher()
        let syncService = HealthKitSyncService(client: stubClient, matcher: matcher)
        syncService.setContext(context)

        UserSettings.shared.healthKitEnabled = true

        let updatedSnapshot = TestFixtures.makeHKWorkoutFixture(
            uuid: hkUUID,
            activityTypeRawValue: 37,
            durationMinutes: 35
        )
        stubClient.workoutsToReturn = [updatedSnapshot]

        await syncService.importPendingWorkouts(context: context)

        XCTAssertEqual(workout.rpe, 6, "Effort score should nil-fill into rpe during upstream update")
    }

    /// Regression test for BUG-023:
    /// Upstream update must NOT overwrite a user-set rpe value.
    func test_upstreamUpdate_preservesExistingRPEDuringUpdate() async throws {
        let hkUUID = UUID()
        let workout = TestFixtures.makeLinkedWorkout(
            name: "Morning Run",
            workoutType: "Cardio",
            healthKitUUID: hkUUID,
            durationMinutes: 30,
            in: context
        )
        workout.rpe = 9
        try context.save()

        let stubClient = StubHealthKitClient()
        stubClient.effortScoreToReturn = 4
        let matcher = WorkoutMatcher()
        let syncService = HealthKitSyncService(client: stubClient, matcher: matcher)
        syncService.setContext(context)

        UserSettings.shared.healthKitEnabled = true

        let updatedSnapshot = TestFixtures.makeHKWorkoutFixture(
            uuid: hkUUID,
            activityTypeRawValue: 37,
            durationMinutes: 35
        )
        stubClient.workoutsToReturn = [updatedSnapshot]

        await syncService.importPendingWorkouts(context: context)

        XCTAssertEqual(workout.rpe, 9, "User-set RPE must NOT be overwritten by effort score")
    }

    /// Regression test for BUG-023:
    /// backfillMissingEffortScores finds linked workouts with nil rpe and fills them.
    func test_backfillEffortScores_fillsMissingRPEOnLinkedWorkouts() async throws {
        let hkUUID1 = UUID()
        let hkUUID2 = UUID()
        let workoutNilRPE = TestFixtures.makeLinkedWorkout(
            name: "HK Workout A",
            healthKitUUID: hkUUID1,
            in: context
        )
        let workoutWithRPE = TestFixtures.makeLinkedWorkout(
            name: "HK Workout B",
            healthKitUUID: hkUUID2,
            in: context
        )
        workoutWithRPE.rpe = 8
        try context.save()

        let stubClient = StubHealthKitClient()
        stubClient.effortScoreToReturn = 5
        let matcher = WorkoutMatcher()
        let syncService = HealthKitSyncService(client: stubClient, matcher: matcher)
        syncService.setContext(context)

        await syncService.backfillMissingEffortScores(context: context)

        XCTAssertEqual(workoutNilRPE.rpe, 5, "Nil rpe should be backfilled with effort score")
        XCTAssertEqual(workoutWithRPE.rpe, 8, "Existing rpe should not be overwritten by backfill")
    }

    // MARK: - Upstream Update

    func test_upstreamUpdate_HKWinsOnOwnedFields() async throws {
        let hkUUID = UUID()
        let workout = TestFixtures.makeLinkedWorkout(
            name: "Morning Run",
            workoutType: "Cardio",
            healthKitUUID: hkUUID,
            durationMinutes: 30,
            avgHeartRate: 130,
            in: context
        )

        let stubClient = StubHealthKitClient()
        let matcher = WorkoutMatcher()
        let syncService = HealthKitSyncService(client: stubClient, matcher: matcher)
        syncService.setContext(context)

        UserSettings.shared.healthKitEnabled = true

        let updatedSnapshot = TestFixtures.makeHKWorkoutFixture(
            uuid: hkUUID,
            activityTypeRawValue: 37,
            durationMinutes: 35,
            avgHeartRate: 145
        )
        stubClient.workoutsToReturn = [updatedSnapshot]

        await syncService.importPendingWorkouts(context: context)

        XCTAssertEqual(workout.durationMinutes, 35, "Duration updated by HK")
        XCTAssertEqual(workout.avgHeartRate, 145, "HR updated by HK")
        XCTAssertEqual(workout.name, "Morning Run", "User-owned name preserved")
    }
}
