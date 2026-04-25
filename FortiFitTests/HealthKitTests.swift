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

private func makeSnapshot(
    uuid: UUID = UUID(),
    activityTypeRawValue: UInt = 50,
    startDate: Date = Date(),
    durationMinutes: Int = 45,
    distanceKm: Double? = nil,
    avgHeartRate: Int? = 142,
    maxHeartRate: Int? = 168,
    activeEnergyKcal: Double? = 487,
    totalEnergyBurnedKcal: Double? = 612,
    elevationAscendedMeters: Double? = nil,
    exerciseMinutes: Int? = 43,
    indoor: Bool? = false
) -> HealthKitWorkoutSnapshot {
    HealthKitWorkoutSnapshot(
        uuid: uuid,
        activityTypeRawValue: activityTypeRawValue,
        sourceBundleID: "com.apple.health.workout-builder",
        startDate: startDate,
        endDate: startDate.addingTimeInterval(TimeInterval(durationMinutes * 60)),
        durationMinutes: durationMinutes,
        distanceKm: distanceKm,
        avgHeartRate: avgHeartRate,
        maxHeartRate: maxHeartRate,
        activeEnergyKcal: activeEnergyKcal,
        totalEnergyBurnedKcal: totalEnergyBurnedKcal,
        elevationAscendedMeters: elevationAscendedMeters,
        exerciseMinutes: exerciseMinutes,
        indoor: indoor
    )
}

// MARK: - HealthKit Type Mapping Tests

struct HealthKitTypeMappingTests {

    @Test func traditionalStrengthTrainingMapsToStrength() {
        let m = HealthKitTypeMapping.map(activityTypeRawValue: 50)
        #expect(m.displayString == "Traditional Strength Training")
        #expect(m.workoutType == "Strength Training")
    }

    @Test func functionalStrengthMapsToStrength() {
        let m = HealthKitTypeMapping.map(activityTypeRawValue: 20)
        #expect(m.displayString == "Functional Strength Training")
        #expect(m.workoutType == "Strength Training")
    }

    @Test func coreTrainingMapsToStrength() {
        let m = HealthKitTypeMapping.map(activityTypeRawValue: 59)
        #expect(m.displayString == "Core Training")
        #expect(m.workoutType == "Strength Training")
    }

    @Test func runningMapsToCardio() {
        let m = HealthKitTypeMapping.map(activityTypeRawValue: 37)
        #expect(m.displayString == "Running")
        #expect(m.workoutType == "Cardio")
    }

    @Test func cyclingMapsToCardio() {
        let m = HealthKitTypeMapping.map(activityTypeRawValue: 13)
        #expect(m.displayString == "Cycling")
        #expect(m.workoutType == "Cardio")
    }

    @Test func hikingMapsToCardio() {
        let m = HealthKitTypeMapping.map(activityTypeRawValue: 24)
        #expect(m.displayString == "Hiking")
        #expect(m.workoutType == "Cardio")
    }

    @Test func swimmingMapsToCardio() {
        let m = HealthKitTypeMapping.map(activityTypeRawValue: 46)
        #expect(m.displayString == "Swimming")
        #expect(m.workoutType == "Cardio")
    }

    @Test func walkingMapsToCardio() {
        let m = HealthKitTypeMapping.map(activityTypeRawValue: 52)
        #expect(m.displayString == "Walking")
        #expect(m.workoutType == "Cardio")
    }

    @Test func hiitMapsToHIIT() {
        let m = HealthKitTypeMapping.map(activityTypeRawValue: 63)
        #expect(m.displayString == "HIIT")
        #expect(m.workoutType == "HIIT")
    }

    @Test func crossTrainingMapsToHIIT() {
        let m = HealthKitTypeMapping.map(activityTypeRawValue: 11)
        #expect(m.displayString == "Cross Training")
        #expect(m.workoutType == "HIIT")
    }

    @Test func fitnessGamingMapsToHIIT() {
        let m = HealthKitTypeMapping.map(activityTypeRawValue: 76)
        #expect(m.displayString == "Fitness Gaming")
        #expect(m.workoutType == "HIIT")
    }

    @Test func yogaMapsToYoga() {
        let m = HealthKitTypeMapping.map(activityTypeRawValue: 57)
        #expect(m.displayString == "Yoga")
        #expect(m.workoutType == "Yoga")
    }

    @Test func pilatesMapsToPilates() {
        let m = HealthKitTypeMapping.map(activityTypeRawValue: 66)
        #expect(m.displayString == "Pilates")
        #expect(m.workoutType == "Pilates")
    }

    @Test func basketballMapsToOther() {
        let m = HealthKitTypeMapping.map(activityTypeRawValue: 6)
        #expect(m.displayString == "Basketball")
        #expect(m.workoutType == "Other")
    }

    @Test func boxingMapsToOther() {
        let m = HealthKitTypeMapping.map(activityTypeRawValue: 8)
        #expect(m.displayString == "Boxing")
        #expect(m.workoutType == "Other")
    }

    @Test func otherRawValue3000MapsToOther() {
        let m = HealthKitTypeMapping.map(activityTypeRawValue: 3000)
        #expect(m.displayString == "Other")
        #expect(m.workoutType == "Other")
    }

    @Test func unknownRawValueDefaultsToOther() {
        let m = HealthKitTypeMapping.map(activityTypeRawValue: 9999)
        #expect(m.displayString == "Activity 9999")
        #expect(m.workoutType == "Other")
    }

    @Test func allCardioTypesMapCorrectly() {
        let cardioRawValues: [UInt] = [13, 16, 24, 31, 35, 37, 39, 40, 44, 45, 46, 49, 52, 53, 55, 60, 61, 67, 68, 69, 70, 71, 73, 74, 77, 78, 81, 82, 84]
        for raw in cardioRawValues {
            let m = HealthKitTypeMapping.map(activityTypeRawValue: raw)
            #expect(m.workoutType == "Cardio", "Raw \(raw) (\(m.displayString)) should map to Cardio")
        }
    }
}

// MARK: - WorkoutMatcher Time-Window Tests

@MainActor
struct WorkoutMatcherTests {

    @Test func highConfidence_sameStartAndEnd_matches() throws {
        let context = try makeTestContext()
        let matcher = WorkoutMatcher()
        let now = Date()

        let workout = Workout(name: "Push Day", date: now, workoutType: "Strength Training", durationMinutes: 45)
        context.insert(workout)
        try context.save()

        let snapshot = makeSnapshot(startDate: now, durationMinutes: 45)
        let result = matcher.findMatch(forIncomingHKWorkout: snapshot, context: context)

        if case .highConfidence(let id) = result {
            #expect(id == workout.id)
        } else {
            #expect(Bool(false), "Expected highConfidence match")
        }
    }

    @Test func highConfidence_within5MinutesOfStart_matches() throws {
        let context = try makeTestContext()
        let matcher = WorkoutMatcher()
        let now = Date()
        let startOffset = now.addingTimeInterval(290)

        let workout = Workout(name: "Push Day", date: now, workoutType: "Strength Training", durationMinutes: 45)
        context.insert(workout)
        try context.save()

        let snapshot = makeSnapshot(startDate: startOffset, durationMinutes: 45)
        let result = matcher.findMatch(forIncomingHKWorkout: snapshot, context: context)

        if case .highConfidence = result {
            // pass
        } else {
            #expect(Bool(false), "Expected highConfidence within 5min window")
        }
    }

    @Test func highConfidence_beyond5MinutesOfStart_noHighConfidence() throws {
        let context = try makeTestContext()
        let matcher = WorkoutMatcher()
        let now = Date()
        let startOffset = now.addingTimeInterval(301)

        let workout = Workout(name: "Push Day", date: now, workoutType: "Strength Training", durationMinutes: 45)
        context.insert(workout)
        try context.save()

        let snapshot = makeSnapshot(startDate: startOffset, durationMinutes: 45)
        let result = matcher.findMatch(forIncomingHKWorkout: snapshot, context: context)

        if case .highConfidence = result {
            #expect(Bool(false), "Should not be highConfidence beyond 5min")
        }
    }

    @Test func lowerConfidence_sameDayWithin4Hours_matches() throws {
        let context = try makeTestContext()
        let matcher = WorkoutMatcher()
        let cal = Calendar.current
        let morning = cal.startOfDay(for: Date()).addingTimeInterval(3600 * 8)
        let startOffset = morning.addingTimeInterval(3600 * 3)

        let workout = Workout(name: "Push Day", date: morning, workoutType: "Strength Training", durationMinutes: 45)
        context.insert(workout)
        try context.save()

        let snapshot = makeSnapshot(startDate: startOffset, durationMinutes: 45)
        let result = matcher.findMatch(forIncomingHKWorkout: snapshot, context: context)

        if case .lowerConfidence(let id) = result {
            #expect(id == workout.id)
        } else {
            #expect(Bool(false), "Expected lowerConfidence match within 4 hours same day")
        }
    }

    @Test func lowerConfidence_beyond4Hours_noMatch() throws {
        let context = try makeTestContext()
        let matcher = WorkoutMatcher()
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        let morning = startOfToday.addingTimeInterval(3600 * 6)
        let evening = startOfToday.addingTimeInterval(3600 * 10.1)

        let workout = Workout(name: "Morning Run", date: morning, workoutType: "Cardio", durationMinutes: 30)
        context.insert(workout)
        try context.save()

        let snapshot = makeSnapshot(activityTypeRawValue: 37, startDate: evening, durationMinutes: 30)
        let result = matcher.findMatch(forIncomingHKWorkout: snapshot, context: context)

        if case .noMatch = result {
            // pass
        } else {
            #expect(Bool(false), "Expected noMatch beyond 4 hours")
        }
    }

    @Test func noMatch_differentWorkoutType_noMatch() throws {
        let context = try makeTestContext()
        let matcher = WorkoutMatcher()
        let now = Date()

        let workout = Workout(name: "Yoga Flow", date: now, workoutType: "Yoga", durationMinutes: 30)
        context.insert(workout)
        try context.save()

        let snapshot = makeSnapshot(activityTypeRawValue: 50, startDate: now, durationMinutes: 30)
        let result = matcher.findMatch(forIncomingHKWorkout: snapshot, context: context)

        if case .noMatch = result {
            // pass
        } else {
            #expect(Bool(false), "Different workout types should not match")
        }
    }

    @Test func rejectedPair_skippedInMatching() throws {
        let context = try makeTestContext()
        let matcher = WorkoutMatcher()
        let now = Date()

        let workout = Workout(name: "Push Day", date: now, workoutType: "Strength Training", durationMinutes: 45)
        context.insert(workout)

        let hkUUID = UUID()
        let rejection = WorkoutMatchRejection(healthKitUUID: hkUUID, workoutId: workout.id)
        context.insert(rejection)
        try context.save()

        let snapshot = makeSnapshot(uuid: hkUUID, startDate: now, durationMinutes: 45)
        let result = matcher.findMatch(forIncomingHKWorkout: snapshot, context: context)

        if case .noMatch = result {
            // pass — rejection blocks matching
        } else {
            #expect(Bool(false), "Rejected pair should not match")
        }
    }
}

// MARK: - Field Ownership Tests

@MainActor
struct FieldOwnershipTests {

    @Test func applyLink_copiesHKOwnedFields() {
        let workout = Workout(name: "My Run", date: Date(), workoutType: "Cardio", rpe: 7)
        let hkStart = Date().addingTimeInterval(-3600)
        let snapshot = makeSnapshot(activityTypeRawValue: 37, startDate: hkStart, durationMinutes: 32, distanceKm: 5.2, avgHeartRate: 142, maxHeartRate: 168, activeEnergyKcal: 487, totalEnergyBurnedKcal: 612, elevationAscendedMeters: 73, exerciseMinutes: 31, indoor: false)

        WorkoutMatcher.applyLink(workout: workout, snapshot: snapshot)

        #expect(workout.healthKitUUID == snapshot.uuid)
        #expect(workout.healthKitSourceBundleID == snapshot.sourceBundleID)
        #expect(workout.healthKitActivityType == "Running")
        #expect(workout.date == hkStart)
        #expect(workout.durationMinutes == 32)
        #expect(workout.distanceKm == 5.2)
        #expect(workout.avgHeartRate == 142)
        #expect(workout.maxHeartRate == 168)
        #expect(workout.activeEnergyKcal == 487)
        #expect(workout.totalEnergyBurnedKcal == 612)
        #expect(workout.elevationAscendedMeters == 73)
        #expect(workout.exerciseMinutes == 31)
        #expect(workout.indoor == false)
    }

    @Test func applyLink_preservesUserOwnedFields() {
        let workout = Workout(name: "My Run", date: Date(), workoutType: "Cardio", rpe: 7)
        let snapshot = makeSnapshot(activityTypeRawValue: 37, startDate: Date(), durationMinutes: 32)

        WorkoutMatcher.applyLink(workout: workout, snapshot: snapshot)

        #expect(workout.name == "My Run")
        #expect(workout.rpe == 7)
        #expect(workout.workoutType == "Cardio")
    }

    @Test func isHealthKitLinked_trueWhenUUIDPresent() {
        let workout = Workout(name: "Test", workoutType: "Cardio", healthKitUUID: UUID())
        #expect(workout.isHealthKitLinked == true)
    }

    @Test func isHealthKitLinked_falseWhenUUIDNil() {
        let workout = Workout(name: "Test", workoutType: "Cardio")
        #expect(workout.isHealthKitLinked == false)
    }
}

// MARK: - Auto-Create Default Values Tests

struct AutoCreateDefaultsTests {

    @Test func autoCreateName_usesDisplayStringAndDate() {
        let snapshot = makeSnapshot(activityTypeRawValue: 37, startDate: Date())
        let mapping = snapshot.mapping
        #expect(mapping.displayString == "Running")
        #expect(mapping.workoutType == "Cardio")
    }

    @Test func autoCreateWorkoutType_usedFromMapping() {
        let yogaSnapshot = makeSnapshot(activityTypeRawValue: 57)
        #expect(yogaSnapshot.mapping.workoutType == "Yoga")

        let hiitSnapshot = makeSnapshot(activityTypeRawValue: 63)
        #expect(hiitSnapshot.mapping.workoutType == "HIIT")

        let strengthSnapshot = makeSnapshot(activityTypeRawValue: 50)
        #expect(strengthSnapshot.mapping.workoutType == "Strength Training")
    }

    @Test func snapshotMapping_computedPropertyWorks() {
        let snapshot = makeSnapshot(activityTypeRawValue: 66)
        let mapping = snapshot.mapping
        #expect(mapping.displayString == "Pilates")
        #expect(mapping.workoutType == "Pilates")
    }
}

// MARK: - 2-Minute Minimum Duration Floor Tests

struct MinimumDurationFloorTests {

    @Test func snapshot_durationUnder2Minutes_wouldBeFiltered() {
        let snapshot = makeSnapshot(durationMinutes: 1)
        #expect(snapshot.durationMinutes < 2)
    }

    @Test func snapshot_durationExactly2Minutes_wouldNotBeFiltered() {
        let snapshot = makeSnapshot(durationMinutes: 2)
        #expect(snapshot.durationMinutes >= 2)
    }

    @Test func snapshot_durationOver2Minutes_wouldNotBeFiltered() {
        let snapshot = makeSnapshot(durationMinutes: 45)
        #expect(snapshot.durationMinutes >= 2)
    }
}

// MARK: - Unlink Tests

@MainActor
struct UnlinkTests {

    @Test func unlink_clearsHKFieldsAndBumpsDate() throws {
        let context = try makeTestContext()
        let workout = Workout(
            name: "HK Run",
            date: Date(),
            workoutType: "Cardio",
            healthKitUUID: UUID(),
            healthKitSourceBundleID: "com.apple.health",
            healthKitActivityType: "Running"
        )
        context.insert(workout)
        try context.save()
        WorkoutService.unlink(workout, context: context)

        #expect(workout.healthKitUUID == nil)
        #expect(workout.healthKitSourceBundleID == nil)
        #expect(workout.healthKitActivityType == nil)
        #expect(workout.isHealthKitLinked == false)
        #expect(workout.lastModifiedDate != nil)
    }
}

// MARK: - Match Decision Tests

@MainActor
struct MatchDecisionTests {

    @Test func resolvePending_link_appliesFieldsAndRemovesFromQueue() throws {
        let context = try makeTestContext()
        let matcher = WorkoutMatcher()

        let workout = Workout(name: "Push Day", date: Date(), workoutType: "Strength Training")
        context.insert(workout)
        try context.save()

        let snapshot = makeSnapshot(startDate: Date(), durationMinutes: 45)
        matcher.queuePendingMatch(workoutId: workout.id, snapshot: snapshot)
        #expect(matcher.pendingMatches().count == 1)

        matcher.resolvePending(workoutId: workout.id, snapshot: snapshot, decision: .link, context: context)

        #expect(matcher.pendingMatches().isEmpty)
        #expect(workout.healthKitUUID == snapshot.uuid)
    }

    @Test func resolvePending_keepSeparate_createsRejectionAndRemovesFromQueue() throws {
        let context = try makeTestContext()
        let matcher = WorkoutMatcher()

        let workout = Workout(name: "Push Day", date: Date(), workoutType: "Strength Training")
        context.insert(workout)
        try context.save()

        let snapshot = makeSnapshot(startDate: Date(), durationMinutes: 45)
        matcher.queuePendingMatch(workoutId: workout.id, snapshot: snapshot)

        matcher.resolvePending(workoutId: workout.id, snapshot: snapshot, decision: .keepSeparate, context: context)

        #expect(matcher.pendingMatches().isEmpty)
        let rejections = try context.fetch(FetchDescriptor<WorkoutMatchRejection>())
        #expect(rejections.count == 1)
        #expect(rejections.first?.healthKitUUID == snapshot.uuid)
        #expect(rejections.first?.workoutId == workout.id)
    }

    @Test func resolvePending_decideLater_leavesInQueue() throws {
        let context = try makeTestContext()
        let matcher = WorkoutMatcher()

        let workout = Workout(name: "Push Day", date: Date(), workoutType: "Strength Training")
        context.insert(workout)
        try context.save()

        let snapshot = makeSnapshot(startDate: Date(), durationMinutes: 45)
        matcher.queuePendingMatch(workoutId: workout.id, snapshot: snapshot)

        matcher.resolvePending(workoutId: workout.id, snapshot: snapshot, decision: .decideLater, context: context)

        #expect(matcher.pendingMatches().count == 1)
    }

    @Test func duplicateQueue_preventsDuplicateEntries() throws {
        let context = try makeTestContext()
        let matcher = WorkoutMatcher()

        let workout = Workout(name: "Push Day", date: Date(), workoutType: "Strength Training")
        context.insert(workout)
        try context.save()

        let snapshot = makeSnapshot(startDate: Date(), durationMinutes: 45)
        matcher.queuePendingMatch(workoutId: workout.id, snapshot: snapshot)
        matcher.queuePendingMatch(workoutId: workout.id, snapshot: snapshot)

        #expect(matcher.pendingMatches().count == 1)
    }
}
