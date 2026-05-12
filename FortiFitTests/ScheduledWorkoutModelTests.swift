import Testing
import Foundation
import SwiftData
@testable import FortiFit

// MARK: - ScheduledWorkout Model Tests

@Suite("ScheduledWorkout Model")
struct ScheduledWorkoutModelTests {

    // MARK: - Creation & Defaults

    @Test("Creation sets default values")
    func creation_setsDefaultValues() throws {
        let context = try makePlanTestContext()
        let sw = ScheduledWorkout(
            scheduledDate: PlanTestFactory.today,
            workoutType: "Strength Training",
            workoutName: "Push Day"
        )
        context.insert(sw)

        #expect(sw.id != UUID())
        #expect(sw.status == "planned")
        #expect(sw.templateId == nil)
        #expect(sw.scheduledWorkoutSnapshot == nil)
        #expect(sw.scheduledTime == nil)
        #expect(sw.durationMinutes == nil)
        #expect(sw.completedWorkoutId == nil)
        #expect(sw.recurrenceRule == nil)
        #expect(sw.recurrenceGroupId == nil)
        // dateCreated is non-optional Date, always set
    }

    @Test("Creation with all properties")
    func creation_withAllProperties() throws {
        let context = try makePlanTestContext()
        let templateId = UUID()
        let groupId = UUID()
        let snapshot = "[]".data(using: .utf8)!

        let sw = ScheduledWorkout(
            templateId: templateId,
            scheduledWorkoutSnapshot: snapshot,
            scheduledDate: PlanTestFactory.tomorrow,
            scheduledTime: Date(),
            workoutType: "HIIT",
            workoutName: "Tabata Blast",
            durationMinutes: 30,
            status: "planned",
            recurrenceRule: "weekly",
            recurrenceGroupId: groupId
        )
        context.insert(sw)

        #expect(sw.templateId == templateId)
        #expect(sw.scheduledWorkoutSnapshot == snapshot)
        #expect(sw.workoutType == "HIIT")
        #expect(sw.workoutName == "Tabata Blast")
        #expect(sw.durationMinutes == 30)
        #expect(sw.recurrenceRule == "weekly")
        #expect(sw.recurrenceGroupId == groupId)
    }

    @Test("Persistence round trip")
    func persistence_roundTrip() throws {
        let context = try makePlanTestContext()
        let sw = ScheduledWorkout(
            scheduledDate: PlanTestFactory.today,
            workoutType: "Cardio",
            workoutName: "Morning Run"
        )
        context.insert(sw)
        try context.save()

        let descriptor = FetchDescriptor<ScheduledWorkout>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        #expect(fetched.first?.workoutName == "Morning Run")
        #expect(fetched.first?.workoutType == "Cardio")
        #expect(fetched.first?.status == "planned")
    }

    @Test("Status mutation updates correctly")
    func statusMutation_updatesCorrectly() throws {
        let context = try makePlanTestContext()
        let sw = ScheduledWorkout(
            scheduledDate: PlanTestFactory.today,
            workoutType: "Yoga",
            workoutName: "Morning Flow"
        )
        context.insert(sw)
        #expect(sw.status == "planned")

        sw.status = "skipped"
        #expect(sw.status == "skipped")

        sw.status = "completed"
        sw.completedWorkoutId = UUID()
        #expect(sw.status == "completed")
        #expect(sw.completedWorkoutId != nil)
    }

    // MARK: - Standalone Relationship Behavior

    @Test("Deleting template does not delete scheduled workout")
    @MainActor
    func deletingTemplate_doesNotDeleteScheduledWorkout() throws {
        let context = try makePlanTestContext()
        let template = PlanTestFactory.makeTemplate(context: context)
        let sw = ScheduledWorkout(
            templateId: template.id,
            scheduledWorkoutSnapshot: "[]".data(using: .utf8),
            scheduledDate: PlanTestFactory.tomorrow,
            workoutType: template.workoutType,
            workoutName: template.name
        )
        context.insert(sw)
        try context.save()

        context.delete(template)
        try context.save()

        let descriptor = FetchDescriptor<ScheduledWorkout>()
        let remaining = try context.fetch(descriptor)
        #expect(remaining.count == 1, "ScheduledWorkout should survive template deletion")
        #expect(remaining.first?.workoutName == "Push Day")
    }
}
