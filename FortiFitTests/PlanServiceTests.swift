import Testing
import Foundation
import SwiftData
@testable import FortiFit

// MARK: - PlanService Tests

@Suite("PlanService")
struct PlanServiceTests {

    // =========================================================================
    // MARK: - Snapshot Encoding / Decoding
    // =========================================================================

    @Test("encodeSnapshot serializes all exercises")
    @MainActor
    func encodeSnapshot_serializesAllExercises() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(
            exercises: [
                ("Bench Press", 4, 8, 80.0),
                ("Overhead Press", 3, 10, 40.0),
                ("Push-Ups", 3, 15, nil)
            ],
            context: context
        )

        let data = PlanService.encodeSnapshot(template: template)
        #expect(data != nil)

        let decoded = PlanService.decodeSnapshot(data: data!)
        #expect(decoded.count == 3)
        #expect(decoded[0].exerciseName == "Bench Press")
        #expect(decoded[0].sets == 4)
        #expect(decoded[0].reps == 8)
        #expect(decoded[0].weightKg == 80.0)
        #expect(decoded[0].sortOrder == 0)
    }

    @Test("encodeSnapshot preserves nil weight")
    @MainActor
    func encodeSnapshot_preservesNilWeight() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(
            exercises: [("Push-Ups", 3, 15, nil)],
            context: context
        )

        let data = PlanService.encodeSnapshot(template: template)!
        let decoded = PlanService.decodeSnapshot(data: data)

        #expect(decoded.count == 1)
        #expect(decoded[0].weightKg == nil, "Bodyweight exercises should have nil weightKg")
    }

    @Test("encodeSnapshot preserves sort order")
    @MainActor
    func encodeSnapshot_preservesSortOrder() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(
            exercises: [
                ("Exercise A", 3, 10, 50.0),
                ("Exercise B", 4, 8, 60.0),
                ("Exercise C", 2, 12, 70.0)
            ],
            context: context
        )

        let data = PlanService.encodeSnapshot(template: template)!
        let decoded = PlanService.decodeSnapshot(data: data)

        #expect(decoded[0].sortOrder == 0)
        #expect(decoded[1].sortOrder == 1)
        #expect(decoded[2].sortOrder == 2)
    }

    @Test("decodeSnapshot returns empty for corrupt data")
    func decodeSnapshot_returnsEmptyForCorruptData() {
        let corrupt = "not json".data(using: .utf8)!
        let decoded = PlanService.decodeSnapshot(data: corrupt)
        #expect(decoded.isEmpty, "Corrupt data should return empty array, not crash")
    }

    @Test("decodeSnapshot returns empty for empty data")
    func decodeSnapshot_returnsEmptyForEmptyData() {
        let decoded = PlanService.decodeSnapshot(data: Data())
        #expect(decoded.isEmpty)
    }

    @Test("Snapshot round trip matches original")
    @MainActor
    func snapshotRoundTrip_matchesOriginal() throws {
        let context = try makePlanTestContext()
        let exercises: [(String, Int, Int, Double?)] = [
            ("Bench Press", 4, 8, 84.0),
            ("Incline Dumbbell Press", 3, 10, 30.0),
            ("Cable Crossovers", 3, 12, nil)
        ]
        let template = PlanTestFactory.makeTemplate(exercises: exercises, context: context)

        let data = PlanService.encodeSnapshot(template: template)!
        let decoded = PlanService.decodeSnapshot(data: data)

        for (i, ex) in exercises.enumerated() {
            #expect(decoded[i].exerciseName == ex.0)
            #expect(decoded[i].sets == ex.1)
            #expect(decoded[i].reps == ex.2)
            #expect(decoded[i].weightKg == ex.3)
        }
    }

    // =========================================================================
    // MARK: - Scheduling — Single Workout
    // =========================================================================

    @Test("Schedule creates planned workout")
    @MainActor
    func schedule_createsPlannedWorkout() throws {
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
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)

        let sw = results[0]
        #expect(sw.workoutName == "Push Day")
        #expect(sw.workoutType == "Strength Training")
        #expect(sw.durationMinutes == 60)
        #expect(sw.status == "planned")
        #expect(sw.templateId == template.id)
        #expect(sw.templateSnapshot != nil)
        #expect(sw.recurrenceRule == nil)
        #expect(sw.recurrenceGroupId == nil)
    }

    @Test("Schedule copies template data at scheduling time")
    @MainActor
    func schedule_copiesTemplateDataAtSchedulingTime() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(name: "Leg Day", durationMinutes: 45, context: context)

        PlanService.scheduleWorkout(
            template: template,
            date: PlanTestFactory.tomorrow,
            time: nil,
            recurrenceRule: nil,
            context: context
        )

        let descriptor = FetchDescriptor<ScheduledWorkout>()
        let sw = try context.fetch(descriptor).first!

        #expect(sw.workoutName == "Leg Day")
        #expect(sw.durationMinutes == 45)
    }

    @Test("Schedule zeros time component of date")
    @MainActor
    func schedule_zerosTimeComponentOfDate() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)
        let dateWithTime = Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: PlanTestFactory.tomorrow)!

        PlanService.scheduleWorkout(
            template: template,
            date: dateWithTime,
            time: nil,
            recurrenceRule: nil,
            context: context
        )

        let descriptor = FetchDescriptor<ScheduledWorkout>()
        let sw = try context.fetch(descriptor).first!
        let startOfDay = Calendar.current.startOfDay(for: PlanTestFactory.tomorrow)
        #expect(sw.scheduledDate == startOfDay, "scheduledDate should have time zeroed")
    }

    @Test("Schedule rejects past date (silently creates nothing)")
    @MainActor
    func schedule_rejectsPastDate() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(
            template: template,
            date: PlanTestFactory.yesterday,
            time: nil,
            recurrenceRule: nil,
            context: context
        )

        let descriptor = FetchDescriptor<ScheduledWorkout>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 0, "Scheduling for a past date should create no records")
    }

    @Test("Schedule accepts today")
    @MainActor
    func schedule_acceptsToday() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(
            template: template,
            date: PlanTestFactory.today,
            time: nil,
            recurrenceRule: nil,
            context: context
        )

        let descriptor = FetchDescriptor<ScheduledWorkout>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
    }

    @Test("Schedule stores optional time")
    @MainActor
    func schedule_storesOptionalTime() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)
        let scheduledTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: PlanTestFactory.tomorrow)!

        PlanService.scheduleWorkout(
            template: template,
            date: PlanTestFactory.tomorrow,
            time: scheduledTime,
            recurrenceRule: nil,
            context: context
        )

        let descriptor = FetchDescriptor<ScheduledWorkout>()
        let sw = try context.fetch(descriptor).first!
        #expect(sw.scheduledTime != nil)
    }

    @Test("Schedule allows multiple on same day")
    @MainActor
    func schedule_allowsMultipleOnSameDay() throws {
        let context = try makePlanTestContext()
        let templateA = PlanTestFactory.makeTemplate(name: "Push Day", context: context)
        let templateB = PlanTestFactory.makeTemplate(name: "Cardio", workoutType: "Cardio", exercises: [], context: context)

        PlanService.scheduleWorkout(template: templateA, date: PlanTestFactory.tomorrow, time: nil, recurrenceRule: nil, context: context)
        PlanService.scheduleWorkout(template: templateB, date: PlanTestFactory.tomorrow, time: nil, recurrenceRule: nil, context: context)

        let descriptor = FetchDescriptor<ScheduledWorkout>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 2, "Multiple workouts on the same day should be allowed")
    }

    // =========================================================================
    // MARK: - Scheduling — Recurrence
    // =========================================================================

    @Test("Recurring weekly generates 12 instances")
    @MainActor
    func scheduleRecurring_weekly_generates12Instances() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(
            template: template,
            date: PlanTestFactory.today,
            time: nil,
            recurrenceRule: "weekly",
            context: context
        )

        let descriptor = FetchDescriptor<ScheduledWorkout>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 12)
    }

    @Test("Recurring weekly has correct 7-day spacing")
    @MainActor
    func scheduleRecurring_weekly_correctDaySpacing() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(
            template: template,
            date: PlanTestFactory.today,
            time: nil,
            recurrenceRule: "weekly",
            context: context
        )

        let descriptor = FetchDescriptor<ScheduledWorkout>(
            sortBy: [SortDescriptor(\.scheduledDate)]
        )
        let results = try context.fetch(descriptor)

        for i in 1..<results.count {
            let daysBetween = Calendar.current.dateComponents(
                [.day],
                from: results[i - 1].scheduledDate,
                to: results[i].scheduledDate
            ).day!
            #expect(daysBetween == 7, "Weekly instances should be 7 days apart")
        }
    }

    @Test("Recurring biweekly has correct 14-day spacing")
    @MainActor
    func scheduleRecurring_biweekly_correctDaySpacing() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(
            template: template,
            date: PlanTestFactory.today,
            time: nil,
            recurrenceRule: "biweekly",
            context: context
        )

        let descriptor = FetchDescriptor<ScheduledWorkout>(
            sortBy: [SortDescriptor(\.scheduledDate)]
        )
        let results = try context.fetch(descriptor)

        for i in 1..<results.count {
            let daysBetween = Calendar.current.dateComponents(
                [.day],
                from: results[i - 1].scheduledDate,
                to: results[i].scheduledDate
            ).day!
            #expect(daysBetween == 14, "Biweekly instances should be 14 days apart")
        }
    }

    @Test("Recurring instances share same groupId")
    @MainActor
    func scheduleRecurring_allShareSameGroupId() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(
            template: template,
            date: PlanTestFactory.today,
            time: nil,
            recurrenceRule: "weekly",
            context: context
        )

        let descriptor = FetchDescriptor<ScheduledWorkout>()
        let results = try context.fetch(descriptor)
        let groupIds = Set(results.compactMap(\.recurrenceGroupId))

        #expect(groupIds.count == 1, "All recurring instances should share one groupId")
        #expect(results.allSatisfy { $0.recurrenceRule == "weekly" })
    }

    @Test("Each recurring instance has own snapshot")
    @MainActor
    func scheduleRecurring_eachHasOwnSnapshot() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(
            template: template,
            date: PlanTestFactory.today,
            time: nil,
            recurrenceRule: "weekly",
            context: context
        )

        let descriptor = FetchDescriptor<ScheduledWorkout>()
        let results = try context.fetch(descriptor)

        for sw in results {
            #expect(sw.templateSnapshot != nil, "Each recurring instance should have its own snapshot")
        }
    }

    @Test("First recurring instance is start date")
    @MainActor
    func scheduleRecurring_firstInstanceIsStartDate() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)
        let startDate = PlanTestFactory.date(daysFromToday: 3)

        PlanService.scheduleWorkout(
            template: template,
            date: startDate,
            time: nil,
            recurrenceRule: "weekly",
            context: context
        )

        let descriptor = FetchDescriptor<ScheduledWorkout>(
            sortBy: [SortDescriptor(\.scheduledDate)]
        )
        let results = try context.fetch(descriptor)
        #expect(results.first?.scheduledDate == startDate)
    }

    // =========================================================================
    // MARK: - Recurrence Regeneration
    // =========================================================================

    @Test("Regeneration triggers when below threshold")
    @MainActor
    func regeneration_triggersWhenBelowThreshold() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(
            template: template,
            date: PlanTestFactory.today,
            time: nil,
            recurrenceRule: "weekly",
            context: context
        )

        let descriptor = FetchDescriptor<ScheduledWorkout>(
            sortBy: [SortDescriptor(\.scheduledDate)]
        )
        var results = try context.fetch(descriptor)
        let groupId = results.first!.recurrenceGroupId!

        // Delete all but 2 future instances
        let toKeep = 2
        for sw in results.dropFirst(toKeep) {
            context.delete(sw)
        }
        try context.save()

        // Trigger regeneration
        PlanService.regenerateRecurrenceIfNeeded(groupId: groupId, context: context)
        try context.save()

        results = try context.fetch(descriptor)
        let futureCount = results.filter { $0.scheduledDate >= PlanTestFactory.today }.count
        #expect(futureCount >= 12, "Regeneration should restore 12-week lookahead")
    }

    @Test("Regeneration does not trigger when above threshold")
    @MainActor
    func regeneration_doesNotTriggerWhenAboveThreshold() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(
            template: template,
            date: PlanTestFactory.today,
            time: nil,
            recurrenceRule: "weekly",
            context: context
        )

        let groupId = try context.fetch(FetchDescriptor<ScheduledWorkout>()).first!.recurrenceGroupId!
        let countBefore = try context.fetch(FetchDescriptor<ScheduledWorkout>()).count

        PlanService.regenerateRecurrenceIfNeeded(groupId: groupId, context: context)

        let countAfter = try context.fetch(FetchDescriptor<ScheduledWorkout>()).count
        #expect(countBefore == countAfter, "Should not regenerate when enough future instances exist")
    }

    // =========================================================================
    // MARK: - Retrieval
    // =========================================================================

    @Test("fetchForDate returns only matching day")
    @MainActor
    func fetchForDate_returnsOnlyMatchingDay() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)
        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.tomorrow, time: nil, recurrenceRule: nil, context: context)

        let todayResults = PlanService.fetchForDate(date: PlanTestFactory.today, context: context)
        #expect(todayResults.count == 1)
        #expect(todayResults[0].scheduledDate == PlanTestFactory.today)
    }

    @Test("fetchForDateRange returns workouts in range")
    @MainActor
    func fetchForDateRange_returnsWorkoutsInRange() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)
        let weekFromNow = PlanTestFactory.date(daysFromToday: 7)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)
        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.tomorrow, time: nil, recurrenceRule: nil, context: context)
        PlanService.scheduleWorkout(template: template, date: weekFromNow, time: nil, recurrenceRule: nil, context: context)

        let results = PlanService.fetchForDateRange(
            start: PlanTestFactory.today,
            end: PlanTestFactory.date(daysFromToday: 2),
            context: context
        )
        #expect(results.count == 2, "Should only return workouts within the date range")
    }

    @Test("fetchForDateRange sorted by date then time")
    @MainActor
    func fetchForDateRange_sortedByDateThenTime() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)
        let morning = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: PlanTestFactory.today)
        let evening = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: PlanTestFactory.today)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: evening, recurrenceRule: nil, context: context)
        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: morning, recurrenceRule: nil, context: context)
        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.tomorrow, time: nil, recurrenceRule: nil, context: context)

        let results = PlanService.fetchForDateRange(
            start: PlanTestFactory.today,
            end: PlanTestFactory.tomorrow,
            context: context
        )
        #expect(results.count == 3)
        // First two should be today, third should be tomorrow
        #expect(results[0].scheduledDate == PlanTestFactory.today)
        #expect(results[2].scheduledDate == PlanTestFactory.tomorrow)
    }

    @Test("fetchTodaysPlanned returns first planned only")
    @MainActor
    func fetchTodaysPlanned_returnsFirstPlannedOnly() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)
        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)

        // Complete the first one
        let all = PlanService.fetchForDate(date: PlanTestFactory.today, context: context)
        all[0].status = "completed"
        try context.save()

        let result = PlanService.fetchTodaysPlanned(context: context)
        #expect(result != nil)
        #expect(result?.status == "planned", "Should return the remaining planned workout, not the completed one")
    }

    @Test("fetchTodaysPlanned returns nil when all completed")
    @MainActor
    func fetchTodaysPlanned_returnsNilWhenAllCompleted() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)

        let all = PlanService.fetchForDate(date: PlanTestFactory.today, context: context)
        all[0].status = "completed"
        try context.save()

        let result = PlanService.fetchTodaysPlanned(context: context)
        #expect(result == nil)
    }

    @Test("fetchTodaysPlanned returns nil when none scheduled")
    func fetchTodaysPlanned_returnsNilWhenNoneScheduled() throws {
        let context = try makePlanTestContext()
        let result = PlanService.fetchTodaysPlanned(context: context)
        #expect(result == nil)
    }

    @Test("fetchTodaysPlanned ignores skipped")
    @MainActor
    func fetchTodaysPlanned_ignoresSkipped() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)

        let all = PlanService.fetchForDate(date: PlanTestFactory.today, context: context)
        all[0].status = "skipped"
        try context.save()

        let result = PlanService.fetchTodaysPlanned(context: context)
        #expect(result == nil, "Skipped workouts should not be returned as today's planned")
    }

    // =========================================================================
    // MARK: - Date Resolution
    // =========================================================================

    @Test("Date resolution: today returns .today")
    func dateResolution_todayReturnsToday() {
        let sw = ScheduledWorkout(
            scheduledDate: PlanTestFactory.today,
            workoutType: "Strength Training",
            workoutName: "Push Day"
        )

        let resolution = PlanService.resolveDateForCompletion(scheduledWorkout: sw)

        if case .today = resolution {
            // Pass
        } else {
            Issue.record("Expected .today, got \(resolution)")
        }
    }

    @Test("Date resolution: past date returns .pastDate")
    func dateResolution_pastDateReturnsPastDate() {
        let sw = ScheduledWorkout(
            scheduledDate: PlanTestFactory.yesterday,
            workoutType: "Strength Training",
            workoutName: "Push Day"
        )

        let resolution = PlanService.resolveDateForCompletion(scheduledWorkout: sw)

        if case .pastDate(let scheduled) = resolution {
            #expect(scheduled == PlanTestFactory.yesterday)
        } else {
            Issue.record("Expected .pastDate, got \(resolution)")
        }
    }

    @Test("Date resolution: future date returns .futureDate")
    func dateResolution_futureDateReturnsFutureDate() {
        let sw = ScheduledWorkout(
            scheduledDate: PlanTestFactory.tomorrow,
            workoutType: "Strength Training",
            workoutName: "Push Day"
        )

        let resolution = PlanService.resolveDateForCompletion(scheduledWorkout: sw)

        if case .futureDate(let scheduled) = resolution {
            #expect(scheduled == PlanTestFactory.tomorrow)
        } else {
            Issue.record("Expected .futureDate, got \(resolution)")
        }
    }

    @Test("Date resolution: far past still returns .pastDate")
    func dateResolution_farPastStillReturnsPastDate() {
        let sw = ScheduledWorkout(
            scheduledDate: PlanTestFactory.date(daysFromToday: -30),
            workoutType: "Strength Training",
            workoutName: "Push Day"
        )

        let resolution = PlanService.resolveDateForCompletion(scheduledWorkout: sw)

        if case .pastDate = resolution {
            // Pass
        } else {
            Issue.record("Expected .pastDate for a workout 30 days ago")
        }
    }

    // =========================================================================
    // MARK: - Completion
    // =========================================================================

    @Test("Complete creates workout from snapshot")
    @MainActor
    func complete_createsWorkoutFromSnapshot() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(
            exercises: [
                ("Bench Press", 4, 8, 80.0),
                ("Overhead Press", 3, 10, 40.0)
            ],
            context: context
        )

        PlanService.scheduleWorkout(
            template: template,
            date: PlanTestFactory.today,
            time: nil,
            recurrenceRule: nil,
            context: context
        )

        let sw = PlanService.fetchForDate(date: PlanTestFactory.today, context: context).first!

        PlanService.completeWorkout(
            scheduledWorkout: sw,
            date: PlanTestFactory.today,
            rpe: 7,
            durationMinutes: 55,
            context: context
        )

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        #expect(workouts.count == 1)

        let workout = workouts[0]
        #expect(workout.name == "Push Day")
        #expect(workout.workoutType == "Strength Training")
        #expect(workout.rpe == 7)
        #expect(workout.durationMinutes == 55)
    }

    @Test("Complete creates exercise sets")
    @MainActor
    func complete_createsExerciseSets() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(
            exercises: [
                ("Bench Press", 4, 8, 80.0),
                ("Overhead Press", 3, 10, 40.0)
            ],
            context: context
        )

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)
        let sw = PlanService.fetchForDate(date: PlanTestFactory.today, context: context).first!

        PlanService.completeWorkout(scheduledWorkout: sw, date: PlanTestFactory.today, rpe: nil, durationMinutes: nil, context: context)

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        let exerciseSets = workouts.first?.exerciseSets ?? []
        #expect(exerciseSets.count == 2)

        let benchSets = exerciseSets.filter { $0.exerciseName == "Bench Press" }
        #expect(benchSets.count == 1)
        #expect(benchSets[0].sets == 4)
        #expect(benchSets[0].reps == 8)
        #expect(benchSets[0].weightKg == 80.0)
    }

    @Test("Complete marks slot completed")
    @MainActor
    func complete_marksSlotCompleted() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)
        let sw = PlanService.fetchForDate(date: PlanTestFactory.today, context: context).first!

        PlanService.completeWorkout(scheduledWorkout: sw, date: PlanTestFactory.today, rpe: nil, durationMinutes: nil, context: context)

        #expect(sw.status == "completed")
        #expect(sw.completedWorkoutId != nil)
    }

    @Test("Complete links workout ID")
    @MainActor
    func complete_linksWorkoutId() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)
        let sw = PlanService.fetchForDate(date: PlanTestFactory.today, context: context).first!

        PlanService.completeWorkout(scheduledWorkout: sw, date: PlanTestFactory.today, rpe: nil, durationMinutes: nil, context: context)

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        #expect(sw.completedWorkoutId == workouts[0].id)
    }

    @Test("Complete uses resolved date, not scheduled date")
    @MainActor
    func complete_usesResolvedDate_notScheduledDate() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        // Schedule for tomorrow, but complete for today
        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.tomorrow, time: nil, recurrenceRule: nil, context: context)
        let sw = PlanService.fetchForDate(date: PlanTestFactory.tomorrow, context: context).first!

        PlanService.completeWorkout(scheduledWorkout: sw, date: PlanTestFactory.today, rpe: nil, durationMinutes: nil, context: context)

        let workout = try context.fetch(FetchDescriptor<Workout>()).first!
        let workoutDay = Calendar.current.startOfDay(for: workout.date)
        #expect(workoutDay == PlanTestFactory.today, "Workout should use the resolved date, not the scheduled date")
    }

    @Test("Complete with nil RPE and duration")
    @MainActor
    func complete_withNilRpeAndDuration() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)
        let sw = PlanService.fetchForDate(date: PlanTestFactory.today, context: context).first!

        PlanService.completeWorkout(scheduledWorkout: sw, date: PlanTestFactory.today, rpe: nil, durationMinutes: nil, context: context)

        let workout = try context.fetch(FetchDescriptor<Workout>()).first!
        #expect(workout.rpe == nil)
        #expect(workout.durationMinutes == nil)
    }

    @Test("markCompletedFromLogWorkout links and updates status")
    @MainActor
    func markCompletedFromLogWorkout_linksAndUpdatesStatus() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)
        let sw = PlanService.fetchForDate(date: PlanTestFactory.today, context: context).first!
        let workoutId = UUID()

        PlanService.markCompletedFromLogWorkout(
            scheduledWorkoutId: sw.id,
            workoutId: workoutId,
            context: context
        )

        #expect(sw.status == "completed")
        #expect(sw.completedWorkoutId == workoutId)
    }

    // =========================================================================
    // MARK: - Snapshot Isolation
    // =========================================================================

    @Test("Template edit does not affect scheduled snapshot")
    @MainActor
    func snapshotIsolation_templateEditDoesNotAffectScheduled() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(
            exercises: [("Bench Press", 4, 8, 80.0)],
            context: context
        )

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.tomorrow, time: nil, recurrenceRule: nil, context: context)

        // Edit the template after scheduling
        let templateSets = template.exerciseSets.sorted { $0.sortOrder < $1.sortOrder }
        templateSets[0].weightKg = 100.0
        templateSets[0].reps = 5
        try context.save()

        // The scheduled workout's snapshot should be unchanged
        let sw = PlanService.fetchForDate(date: PlanTestFactory.tomorrow, context: context).first!
        let decoded = PlanService.decodeSnapshot(data: sw.templateSnapshot!)

        #expect(decoded[0].weightKg == 80.0, "Snapshot should reflect scheduling-time data, not edited template")
        #expect(decoded[0].reps == 8)
    }

    @Test("Template deletion does not break completion")
    @MainActor
    func snapshotIsolation_templateDeletionDoesNotBreakCompletion() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)

        // Delete the template
        context.delete(template)
        try context.save()

        // Should still be able to complete
        let sw = PlanService.fetchForDate(date: PlanTestFactory.today, context: context).first!
        #expect(sw.templateSnapshot != nil, "Snapshot should survive template deletion")

        PlanService.completeWorkout(scheduledWorkout: sw, date: PlanTestFactory.today, rpe: 7, durationMinutes: 60, context: context)

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        #expect(workouts.count == 1, "Completion should work even after template is deleted")
    }

    // =========================================================================
    // MARK: - Skip / Restore
    // =========================================================================

    @Test("Skip sets status to skipped")
    @MainActor
    func skip_setsStatusToSkipped() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)
        let sw = PlanService.fetchForDate(date: PlanTestFactory.today, context: context).first!

        PlanService.skipWorkout(scheduledWorkout: sw, context: context)
        #expect(sw.status == "skipped")
    }

    @Test("Skip does not create workout")
    @MainActor
    func skip_doesNotCreateWorkout() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)
        let sw = PlanService.fetchForDate(date: PlanTestFactory.today, context: context).first!

        PlanService.skipWorkout(scheduledWorkout: sw, context: context)

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        #expect(workouts.count == 0)
    }

    @Test("Restore reverts to planned")
    @MainActor
    func restore_revertsToPlanned() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)
        let sw = PlanService.fetchForDate(date: PlanTestFactory.today, context: context).first!

        PlanService.skipWorkout(scheduledWorkout: sw, context: context)
        #expect(sw.status == "skipped")

        PlanService.restoreWorkout(scheduledWorkout: sw, context: context)
        #expect(sw.status == "planned")
    }

    @Test("Restore only works from skipped status")
    @MainActor
    func restore_onlyWorksFromSkipped() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)
        let sw = PlanService.fetchForDate(date: PlanTestFactory.today, context: context).first!

        // Try restoring from "completed" — should not change
        sw.status = "completed"
        PlanService.restoreWorkout(scheduledWorkout: sw, context: context)
        #expect(sw.status == "completed", "Restore should only work from skipped status")
    }

    // =========================================================================
    // MARK: - Delete
    // =========================================================================

    @Test("Delete single removes record")
    @MainActor
    func deleteSingle_removesRecord() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)
        let sw = PlanService.fetchForDate(date: PlanTestFactory.today, context: context).first!

        PlanService.deleteWorkout(scheduledWorkout: sw, context: context)
        try context.save()

        let results = try context.fetch(FetchDescriptor<ScheduledWorkout>())
        #expect(results.count == 0)
    }

    @Test("Delete this and future removes correct instances")
    @MainActor
    func deleteThisAndFuture_removesCorrectInstances() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(
            template: template,
            date: PlanTestFactory.today,
            time: nil,
            recurrenceRule: "weekly",
            context: context
        )

        let descriptor = FetchDescriptor<ScheduledWorkout>(
            sortBy: [SortDescriptor(\.scheduledDate)]
        )
        let all = try context.fetch(descriptor)
        #expect(all.count == 12)

        // Complete the first 2, then delete from the 4th onward
        all[0].status = "completed"
        all[1].status = "completed"
        try context.save()

        let fourthInstance = all[3]
        PlanService.deleteThisAndFuture(scheduledWorkout: fourthInstance, context: context)
        try context.save()

        let remaining = try context.fetch(descriptor)

        // Should keep: instances 0 (completed), 1 (completed), 2 (planned)
        #expect(remaining.count == 3)
        #expect(remaining.filter { $0.status == "completed" }.count == 2)
    }

    @Test("Delete this and future preserves past completed and skipped")
    @MainActor
    func deleteThisAndFuture_preservesPastCompletedAndSkipped() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(
            template: template,
            date: PlanTestFactory.today,
            time: nil,
            recurrenceRule: "weekly",
            context: context
        )

        let descriptor = FetchDescriptor<ScheduledWorkout>(
            sortBy: [SortDescriptor(\.scheduledDate)]
        )
        let all = try context.fetch(descriptor)

        // Mark first as completed, second as skipped
        all[0].status = "completed"
        all[1].status = "skipped"
        try context.save()

        // Delete from the 3rd instance onward
        PlanService.deleteThisAndFuture(scheduledWorkout: all[2], context: context)
        try context.save()

        let remaining = try context.fetch(descriptor)
        #expect(remaining.count == 2)
        #expect(remaining[0].status == "completed")
        #expect(remaining[1].status == "skipped")
    }

    // =========================================================================
    // MARK: - Workout Deletion Linkage
    // =========================================================================

    @Test("Workout deletion reverts scheduled slot to planned")
    @MainActor
    func workoutDeletion_revertsScheduledSlotToPlanned() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)
        let sw = PlanService.fetchForDate(date: PlanTestFactory.today, context: context).first!

        // Complete the workout
        PlanService.completeWorkout(scheduledWorkout: sw, date: PlanTestFactory.today, rpe: 7, durationMinutes: 60, context: context)
        #expect(sw.status == "completed")
        let workoutId = sw.completedWorkoutId!

        // Now delete the workout (simulating WorkoutService deletion cascade)
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        let workout = workouts.first { $0.id == workoutId }!
        context.delete(workout)

        // PlanService should revert the slot
        PlanService.revertScheduledWorkoutsForDeletedWorkout(workoutId: workoutId, context: context)
        try context.save()

        #expect(sw.status == "planned")
        #expect(sw.completedWorkoutId == nil)
    }

    @Test("Workout deletion no-op when no linked schedule")
    func workoutDeletion_noOpWhenNoLinkedSchedule() throws {
        let context = try makePlanTestContext()

        let workout = Workout(
            name: "Freeform Workout",
            date: Date(),
            workoutType: "Strength Training"
        )
        context.insert(workout)
        try context.save()

        let workoutId = workout.id
        context.delete(workout)

        // Should not crash or error
        PlanService.revertScheduledWorkoutsForDeletedWorkout(workoutId: workoutId, context: context)
        try context.save()
    }

    @Test("Workout deletion allows re-completion")
    @MainActor
    func workoutDeletion_allowsReCompletion() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)
        let sw = PlanService.fetchForDate(date: PlanTestFactory.today, context: context).first!

        // Complete, then delete, then re-complete
        PlanService.completeWorkout(scheduledWorkout: sw, date: PlanTestFactory.today, rpe: 7, durationMinutes: 60, context: context)
        let firstWorkoutId = sw.completedWorkoutId!

        let workout = try context.fetch(FetchDescriptor<Workout>()).first { $0.id == firstWorkoutId }!
        context.delete(workout)
        PlanService.revertScheduledWorkoutsForDeletedWorkout(workoutId: firstWorkoutId, context: context)
        try context.save()

        #expect(sw.status == "planned")

        // Re-complete
        PlanService.completeWorkout(scheduledWorkout: sw, date: PlanTestFactory.today, rpe: 8, durationMinutes: 50, context: context)

        #expect(sw.status == "completed")
        #expect(sw.completedWorkoutId != firstWorkoutId, "Should link to a new workout")
    }

    // =========================================================================
    // MARK: - Plan Surface (fetchPlanSurface) & hiddenFromPlan
    // =========================================================================

    @Test("fetchPlanSurface excludes workout linked to scheduled workout to avoid duplication")
    @MainActor
    func test_fetchPlanSurface_excludesWorkoutLinkedToScheduledWorkout_toAvoidDuplication() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        // Schedule and complete a workout for today
        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)
        let sw = PlanService.fetchForDate(date: PlanTestFactory.today, context: context).first!
        PlanService.completeWorkout(scheduledWorkout: sw, date: PlanTestFactory.today, rpe: 7, durationMinutes: 45, context: context)

        // Fetch plan surface — should only contain the scheduled card, not a duplicate logged-only card
        let items = PlanService.fetchPlanSurface(for: PlanTestFactory.today, context: context)
        let scheduledItems = items.filter { if case .scheduled = $0 { return true }; return false }
        let loggedItems = items.filter { if case .loggedOnly = $0 { return true }; return false }

        #expect(scheduledItems.count == 1, "Should contain the completed scheduled card")
        #expect(loggedItems.count == 0, "Workout linked to a scheduled card should NOT appear as logged-only")
    }

    @Test("fetchPlanSurface excludes workout with hiddenFromPlan true")
    @MainActor
    func test_fetchPlanSurface_excludesWorkoutWithHiddenFromPlanTrue() throws {
        let context = try makePlanTestContext()

        // Create a logged-only workout with hiddenFromPlan = true
        let workout = Workout(name: "Morning Run", date: PlanTestFactory.today, workoutType: "Cardio")
        workout.hiddenFromPlan = true
        context.insert(workout)
        try context.save()

        let items = PlanService.fetchPlanSurface(for: PlanTestFactory.today, context: context)
        #expect(items.isEmpty, "Workouts with hiddenFromPlan=true should not appear on Plan surface")
    }

    @Test("fetchPlanSurface includes logged-only workout when no scheduled workout links to it")
    @MainActor
    func test_fetchPlanSurface_includesLoggedOnlyWorkoutWhenNoScheduledWorkoutLinks() throws {
        let context = try makePlanTestContext()

        // Create a standalone logged workout (no scheduled link)
        let workout = Workout(name: "Evening Yoga", date: PlanTestFactory.today, workoutType: "Yoga")
        context.insert(workout)
        try context.save()

        let items = PlanService.fetchPlanSurface(for: PlanTestFactory.today, context: context)
        let loggedItems = items.filter { if case .loggedOnly = $0 { return true }; return false }

        #expect(loggedItems.count == 1, "Standalone logged workout should appear as logged-only card")
    }

    @Test("fetchPlanSurface returns combined date-sorted results for mixed day")
    @MainActor
    func test_fetchPlanSurface_returnsCombinedDateSortedResults_forMixedDay() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)

        // Schedule a workout for today
        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)

        // Also log a standalone workout for today
        let loggedWorkout = Workout(name: "Quick Run", date: PlanTestFactory.today, workoutType: "Cardio")
        context.insert(loggedWorkout)
        try context.save()

        let items = PlanService.fetchPlanSurface(for: PlanTestFactory.today, context: context)

        #expect(items.count == 2, "Should have both a scheduled card and a logged-only card")

        let hasScheduled = items.contains { if case .scheduled = $0 { return true }; return false }
        let hasLoggedOnly = items.contains { if case .loggedOnly = $0 { return true }; return false }
        #expect(hasScheduled, "Should include the scheduled item")
        #expect(hasLoggedOnly, "Should include the logged-only item")
    }

    @Test("setHiddenFromPlan flips flag only, does not touch other fields")
    @MainActor
    func test_setHiddenFromPlan_flipsFlagOnly_doesNotTouchOtherFields() throws {
        let context = try makePlanTestContext()

        let workout = Workout(name: "Leg Day", date: PlanTestFactory.today, workoutType: "Strength Training", rpe: 8)
        workout.durationMinutes = 60
        context.insert(workout)
        try context.save()

        let originalName = workout.name
        let originalType = workout.workoutType
        let originalDate = workout.date
        let originalRPE = workout.rpe
        let originalDuration = workout.durationMinutes

        PlanService.setHiddenFromPlan(workout: workout, hidden: true, context: context)

        #expect(workout.hiddenFromPlan == true, "Flag should be flipped to true")
        #expect(workout.name == originalName, "Name should be unchanged")
        #expect(workout.workoutType == originalType, "Type should be unchanged")
        #expect(workout.date == originalDate, "Date should be unchanged")
        #expect(workout.rpe == originalRPE, "RPE should be unchanged")
        #expect(workout.durationMinutes == originalDuration, "Duration should be unchanged")

        // Flip back
        PlanService.setHiddenFromPlan(workout: workout, hidden: false, context: context)
        #expect(workout.hiddenFromPlan == false, "Flag should be flipped back to false")
    }
}
