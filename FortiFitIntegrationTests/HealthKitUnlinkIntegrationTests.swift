import XCTest
import SwiftData
@testable import FortiFit

@MainActor
final class HealthKitUnlinkIntegrationTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        let result = try TestFixtures.inMemoryContext()
        container = result.0
        context = result.1
    }

    // MARK: - Effort Score Provenance (from § 6.1)

    func test_hkAutoCreateWithEffortScore_rpeFromHKTrue() async throws {
        let stubClient = StubHealthKitClient()
        stubClient.effortScoreToReturn = 5
        let matcher = WorkoutMatcher()
        let syncService = HealthKitSyncService(client: stubClient, matcher: matcher)
        syncService.setContext(context)

        UserSettings.shared.healthKitEnabled = true

        let snapshot = TestFixtures.makeHKWorkoutFixture(durationMinutes: 30)
        stubClient.workoutsToReturn = [snapshot]

        await syncService.importPendingWorkouts(context: context)

        let workouts = WorkoutService.fetchAll(context: context)
        XCTAssertEqual(workouts.count, 1)
        let workout = workouts.first!
        XCTAssertEqual(workout.rpe, 5)
        XCTAssertTrue(workout.rpeFromHK)
    }

    func test_hkAutoCreateWithoutEffortScore_rpeFromHKFalse() async throws {
        let stubClient = StubHealthKitClient()
        stubClient.effortScoreToReturn = nil
        let matcher = WorkoutMatcher()
        let syncService = HealthKitSyncService(client: stubClient, matcher: matcher)
        syncService.setContext(context)

        UserSettings.shared.healthKitEnabled = true

        let snapshot = TestFixtures.makeHKWorkoutFixture(durationMinutes: 30)
        stubClient.workoutsToReturn = [snapshot]

        await syncService.importPendingWorkouts(context: context)

        let workouts = WorkoutService.fetchAll(context: context)
        XCTAssertEqual(workouts.count, 1)
        let workout = workouts.first!
        XCTAssertNil(workout.rpe)
        XCTAssertFalse(workout.rpeFromHK)
    }

    // MARK: - Unlink: HK Pointer Fields

    func test_unlink_clearsThreeHKPointerFields_expectAllNil() throws {
        let hkUUID = UUID()
        let workout = TestFixtures.makeLinkedWorkout(
            name: "HK Run",
            workoutType: "Cardio",
            healthKitUUID: hkUUID,
            in: context
        )

        XCTAssertNotNil(workout.healthKitUUID)
        XCTAssertNotNil(workout.healthKitSourceBundleID)
        XCTAssertNotNil(workout.healthKitActivityType)

        WorkoutService.unlink(workout, context: context)

        XCTAssertNil(workout.healthKitUUID)
        XCTAssertNil(workout.healthKitSourceBundleID)
        XCTAssertNil(workout.healthKitActivityType)
    }

    // MARK: - Unlink: HK-Only Summary Fields

    func test_unlink_clearsSixHKOnlySummaryFields_expectAllNil() throws {
        let workout = TestFixtures.makeLinkedWorkout(
            name: "Full HK Run",
            workoutType: "Cardio",
            avgHeartRate: 142,
            maxHeartRate: 168,
            activeEnergyKcal: 487,
            totalEnergyBurnedKcal: 612,
            elevationAscendedMeters: 73,
            exerciseMinutes: 32,
            in: context
        )

        WorkoutService.unlink(workout, context: context)

        XCTAssertNil(workout.avgHeartRate)
        XCTAssertNil(workout.maxHeartRate)
        XCTAssertNil(workout.activeEnergyKcal)
        XCTAssertNil(workout.totalEnergyBurnedKcal)
        XCTAssertNil(workout.elevationAscendedMeters)
        XCTAssertNil(workout.exerciseMinutes)
    }

    // MARK: - Unlink: Retained Fields

    func test_unlink_retainsDurationDistanceDateAndUserOwnedFields_expectUnchanged() throws {
        let now = Date()
        let timeValue = now
        let workout = TestFixtures.makeLinkedWorkout(
            name: "Morning Run",
            date: now,
            workoutType: "Cardio",
            durationMinutes: 45,
            distanceKm: 5.2,
            time: timeValue,
            note: "Felt great",
            indoor: true,
            exercises: [TestFixtures.SetSpec("Burpees", sets: 3, reps: 10)],
            in: context
        )

        let preName = workout.name
        let preDate = workout.date
        let preTime = workout.time
        let preDuration = workout.durationMinutes
        let preDistance = workout.distanceKm
        let preNote = workout.note
        let preIndoor = workout.indoor
        let preSetCount = workout.exerciseSets.count

        WorkoutService.unlink(workout, context: context)

        XCTAssertEqual(workout.name, preName)
        XCTAssertEqual(workout.date, preDate)
        XCTAssertEqual(workout.time, preTime)
        XCTAssertEqual(workout.durationMinutes, preDuration)
        XCTAssertEqual(workout.distanceKm, preDistance)
        XCTAssertEqual(workout.note, preNote)
        XCTAssertEqual(workout.indoor, preIndoor)
        XCTAssertEqual(workout.exerciseSets.count, preSetCount)
    }

    // MARK: - Unlink: RPE with rpeFromHK = true

    func test_unlink_rpeFromHKTrue_clearsRPEAndFlag_expectBothCleared() throws {
        let workout = TestFixtures.makeLinkedWorkout(
            name: "HK Effort",
            rpe: 5,
            rpeFromHK: true,
            in: context
        )

        WorkoutService.unlink(workout, context: context)

        XCTAssertNil(workout.rpe)
        XCTAssertFalse(workout.rpeFromHK)
    }

    // MARK: - Unlink: RPE with rpeFromHK = false

    func test_unlink_rpeFromHKFalse_retainsRPEClearsFlag_expectRPEUnchanged() throws {
        let workout = TestFixtures.makeLinkedWorkout(
            name: "User Effort",
            rpe: 7,
            rpeFromHK: false,
            in: context
        )

        WorkoutService.unlink(workout, context: context)

        XCTAssertEqual(workout.rpe, 7)
        XCTAssertFalse(workout.rpeFromHK)
    }

    // MARK: - Unlink: lastModifiedDate

    func test_unlink_bumpsLastModifiedDate_expectFreshTimestamp() throws {
        let oneHourAgo = Date.now.addingTimeInterval(-3600)
        let workout = TestFixtures.makeLinkedWorkout(name: "Timestamp Test", in: context)
        workout.lastModifiedDate = oneHourAgo
        try context.save()

        let t0 = Date.now
        WorkoutService.unlink(workout, context: context)

        XCTAssertNotNil(workout.lastModifiedDate)
        XCTAssertGreaterThanOrEqual(workout.lastModifiedDate!, t0.addingTimeInterval(-1))
    }

    // MARK: - Unlink: WorkoutMatchRejection

    func test_unlink_writesWorkoutMatchRejection_expectRejectionPersistedWithUnlinkedReason() throws {
        let hkUUID = UUID()
        let workout = TestFixtures.makeLinkedWorkout(
            name: "Rejection Test",
            healthKitUUID: hkUUID,
            in: context
        )
        let workoutId = workout.id

        WorkoutService.unlink(workout, context: context)

        let rejections = try context.fetch(FetchDescriptor<WorkoutMatchRejection>())
        XCTAssertEqual(rejections.count, 1)
        XCTAssertEqual(rejections.first?.healthKitUUID, hkUUID)
        XCTAssertEqual(rejections.first?.workoutId, workoutId)
        XCTAssertEqual(rejections.first?.rejectionReason, .unlinked)
    }

    // MARK: - Unlink then reimport

    func test_unlinkThenReimportSameHKUUID_expectAutoCreateAsNewWorkout() async throws {
        let hkUUID = UUID()
        let originalWorkout = TestFixtures.makeLinkedWorkout(
            name: "Original HK Workout",
            healthKitUUID: hkUUID,
            in: context
        )
        let originalId = originalWorkout.id

        WorkoutService.unlink(originalWorkout, context: context)

        let stubClient = StubHealthKitClient()
        let matcher = WorkoutMatcher()
        let syncService = HealthKitSyncService(client: stubClient, matcher: matcher)
        syncService.setContext(context)

        UserSettings.shared.healthKitEnabled = true

        let snapshot = TestFixtures.makeHKWorkoutFixture(uuid: hkUUID, durationMinutes: 45)
        stubClient.workoutsToReturn = [snapshot]

        await syncService.importPendingWorkouts(context: context)

        let workouts = WorkoutService.fetchAll(context: context)
        XCTAssertEqual(workouts.count, 2, "Should create a new workout, not link to the original")
        let newWorkout = workouts.first { $0.id != originalId }
        XCTAssertNotNil(newWorkout)
        XCTAssertEqual(newWorkout?.healthKitUUID, hkUUID)
        XCTAssertNil(originalWorkout.healthKitUUID, "Original should stay unlinked")
    }

    // MARK: - Unlink: User-owned fields unchanged

    func test_unlink_doesNotMutateUserOwnedFields_expectNameNoteTimeExerciseSetsUnchanged() throws {
        let timeValue = Date()
        let workout = TestFixtures.makeLinkedWorkout(
            name: "Full Workout",
            time: timeValue,
            note: "Good session",
            exercises: [
                TestFixtures.SetSpec("Bench Press", sets: 3, reps: 8, weightKg: 80),
                TestFixtures.SetSpec("Squats", sets: 4, reps: 6, weightKg: 100)
            ],
            in: context
        )

        let preName = workout.name
        let preNote = workout.note
        let preTime = workout.time
        let preSetCount = workout.exerciseSets.count

        WorkoutService.unlink(workout, context: context)

        XCTAssertEqual(workout.name, preName)
        XCTAssertEqual(workout.note, preNote)
        XCTAssertEqual(workout.time, preTime)
        XCTAssertEqual(workout.exerciseSets.count, preSetCount)
    }

    // MARK: - Upstream Delete contrast

    func test_upstreamDelete_stillRetainsMeasurementValues_expectNoFieldClear() async throws {
        let hkUUID = UUID()
        let workout = TestFixtures.makeLinkedWorkout(
            name: "HK to Delete",
            workoutType: "Cardio",
            healthKitUUID: hkUUID,
            avgHeartRate: 142,
            maxHeartRate: 168,
            activeEnergyKcal: 487,
            totalEnergyBurnedKcal: 612,
            elevationAscendedMeters: 73,
            exerciseMinutes: 32,
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

        XCTAssertNil(workout.healthKitUUID, "HK pointer cleared")
        XCTAssertEqual(workout.avgHeartRate, 142, "avgHeartRate retained on upstream delete")
        XCTAssertEqual(workout.maxHeartRate, 168, "maxHeartRate retained on upstream delete")
        XCTAssertEqual(workout.activeEnergyKcal, 487, "activeEnergyKcal retained on upstream delete")
        XCTAssertEqual(workout.totalEnergyBurnedKcal, 612, "totalEnergyBurnedKcal retained on upstream delete")
        XCTAssertEqual(workout.elevationAscendedMeters, 73, "elevationAscendedMeters retained on upstream delete")
        XCTAssertEqual(workout.exerciseMinutes, 32, "exerciseMinutes retained on upstream delete")
    }
}
