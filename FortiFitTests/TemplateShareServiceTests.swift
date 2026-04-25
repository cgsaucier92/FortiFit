import Testing
import Foundation
import SwiftData
@testable import FortiFit

#if os(iOS)
import UIKit
#endif

/// In-memory SwiftData context for template share tests.
private func makeShareTestContext() throws -> ModelContext {
    let schema = Schema([
        Workout.self, ExerciseSet.self, Goal.self,
        WorkoutTemplate.self, TemplateExerciseSet.self,
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

/// Creates a sample template in the given context with exercises.
@discardableResult
private func makeSampleTemplate(
    name: String = "Push Day",
    workoutType: String = "Strength Training",
    durationMinutes: Int? = 60,
    context: ModelContext
) throws -> WorkoutTemplate {
    let template = WorkoutTemplate(
        name: name,
        workoutType: workoutType,
        durationMinutes: durationMinutes
    )
    let s1 = TemplateExerciseSet(exerciseName: "Bench Press", sets: 4, reps: 8, weightKg: 84.0, sortOrder: 0)
    let s2 = TemplateExerciseSet(exerciseName: "Push-Ups", sets: 3, reps: 15, weightKg: nil, sortOrder: 1)
    template.exerciseSets.append(s1)
    template.exerciseSets.append(s2)
    context.insert(template)
    try context.save()
    return template
}

// MARK: - Project Scaffold

struct TemplateShareScaffoldTests {

    @Test func templateShareServiceFileExists() {
        _ = TemplateShareService.self
        #expect(true)
    }

    @Test func templatePayloadStructExists() {
        let payload = TemplatePayload(v: 1, name: "Test", workoutType: "HIIT", durationMinutes: nil, exercises: [])
        #expect(payload.v == 1)
    }

    @Test func exercisePayloadStructExists() {
        let ep = ExercisePayload(exerciseName: "Bench", sets: 4, reps: 8, weightKg: 80, sortOrder: 0)
        #expect(ep.exerciseName == "Bench")
    }
}

// MARK: - Encoding

struct TemplateShareEncodingTests {

    @Test func encodeTemplateProducesCorrectSchemeAndHost() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(context: context)

        let url = TemplateShareService.encodeTemplate(template)
        #expect(url != nil)
        #expect(url?.scheme == "fitnavi")
        #expect(url?.host == "template")
    }

    @Test func encodedURLContainsVersionParameter() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(context: context)

        let url = TemplateShareService.encodeTemplate(template)!
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let vParam = components.queryItems?.first { $0.name == "v" }
        #expect(vParam?.value == "1")
    }

    @Test func encodedURLContainsDataParameter() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(context: context)

        let url = TemplateShareService.encodeTemplate(template)!
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let dataParam = components.queryItems?.first { $0.name == "data" }
        #expect(dataParam?.value != nil)
        #expect(!dataParam!.value!.isEmpty)
    }

    @Test func decodingDataParameterProducesCorrectName() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(name: "My Push Day", context: context)

        let url = TemplateShareService.encodeTemplate(template)!
        let payload = TemplateShareService.decodeTemplateURL(url: url)
        #expect(payload?.name == "My Push Day")
    }

    @Test func decodingDataParameterProducesCorrectWorkoutType() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(workoutType: "HIIT", context: context)

        let url = TemplateShareService.encodeTemplate(template)!
        let payload = TemplateShareService.decodeTemplateURL(url: url)
        #expect(payload?.workoutType == "HIIT")
    }

    @Test func decodingDataParameterProducesDurationMinutes() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(durationMinutes: 45, context: context)

        let url = TemplateShareService.encodeTemplate(template)!
        let payload = TemplateShareService.decodeTemplateURL(url: url)
        #expect(payload?.durationMinutes == 45)
    }

    @Test func decodingDataParameterProducesExerciseArray() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(context: context)

        let url = TemplateShareService.encodeTemplate(template)!
        let payload = TemplateShareService.decodeTemplateURL(url: url)!
        #expect(payload.exercises.count == 2)
    }

    @Test func eachExerciseIncludesAllFields() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(context: context)

        let url = TemplateShareService.encodeTemplate(template)!
        let payload = TemplateShareService.decodeTemplateURL(url: url)!
        let first = payload.exercises.first { $0.sortOrder == 0 }!
        #expect(first.exerciseName == "Bench Press")
        #expect(first.sets == 4)
        #expect(first.reps == 8)
        #expect(first.weightKg == 84.0)
        #expect(first.sortOrder == 0)
    }

    @Test func bodyweightExercisesEncodeWeightKgAsNull() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(context: context)

        let url = TemplateShareService.encodeTemplate(template)!
        let payload = TemplateShareService.decodeTemplateURL(url: url)!
        let pushups = payload.exercises.first { $0.exerciseName == "Push-Ups" }!
        #expect(pushups.weightKg == nil)
    }

    @Test func exercisesAreOrderedBySortOrder() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(context: context)

        let url = TemplateShareService.encodeTemplate(template)!
        let payload = TemplateShareService.decodeTemplateURL(url: url)!
        #expect(payload.exercises[0].sortOrder == 0)
        #expect(payload.exercises[1].sortOrder == 1)
    }

    @Test func nilDurationMinutesEncodesAsNull() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(durationMinutes: nil, context: context)

        let url = TemplateShareService.encodeTemplate(template)!
        let payload = TemplateShareService.decodeTemplateURL(url: url)!
        #expect(payload.durationMinutes == nil)
    }

    @Test func encodeTemplateReturnsNilForOversizedPayload() throws {
        let context = try makeShareTestContext()
        let template = WorkoutTemplate(name: "Huge Template", workoutType: "Strength Training")
        // Create enough exercises to exceed 2331 bytes
        for i in 0..<50 {
            let name = "Very Long Exercise Name Number \(i) That Takes Up Lots Of Space"
            let set = TemplateExerciseSet(exerciseName: name, sets: 10, reps: 10, weightKg: 999.99, sortOrder: i)
            template.exerciseSets.append(set)
        }
        context.insert(template)
        try context.save()

        let url = TemplateShareService.encodeTemplate(template)
        #expect(url == nil)
    }
}

// MARK: - QR Code Generation

#if os(iOS)
struct TemplateShareQRCodeTests {

    @Test func generateQRCodeReturnsImageForValidURL() {
        let url = URL(string: "fitnavi://template?v=1&data=dGVzdA")!
        let image = TemplateShareService.generateQRCode(from: url)
        #expect(image != nil)
    }

    @Test func generateQRCodeImageIsApproximately250pt() {
        let url = URL(string: "fitnavi://template?v=1&data=dGVzdA")!
        let image = TemplateShareService.generateQRCode(from: url)!
        // Allow some tolerance for QR scaling
        #expect(image.size.width >= 240)
        #expect(image.size.width <= 260)
    }
}
#endif

// MARK: - Decoding

struct TemplateShareDecodingTests {

    @Test func decodeValidURL() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(context: context)
        let url = TemplateShareService.encodeTemplate(template)!

        let payload = TemplateShareService.decodeTemplateURL(url: url)
        #expect(payload != nil)
        #expect(payload?.name == "Push Day")
    }

    @Test func decodedPayloadContainsOriginalName() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(name: "Leg Day", context: context)
        let url = TemplateShareService.encodeTemplate(template)!

        let payload = TemplateShareService.decodeTemplateURL(url: url)
        #expect(payload?.name == "Leg Day")
    }

    @Test func decodedPayloadContainsOriginalWorkoutType() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(workoutType: "HIIT", context: context)
        let url = TemplateShareService.encodeTemplate(template)!

        let payload = TemplateShareService.decodeTemplateURL(url: url)
        #expect(payload?.workoutType == "HIIT")
    }

    @Test func decodedPayloadContainsOriginalDuration() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(durationMinutes: 90, context: context)
        let url = TemplateShareService.encodeTemplate(template)!

        let payload = TemplateShareService.decodeTemplateURL(url: url)
        #expect(payload?.durationMinutes == 90)
    }

    @Test func decodedPayloadContainsNilDuration() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(durationMinutes: nil, context: context)
        let url = TemplateShareService.encodeTemplate(template)!

        let payload = TemplateShareService.decodeTemplateURL(url: url)
        #expect(payload?.durationMinutes == nil)
    }

    @Test func decodedPayloadContainsAllExercises() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(context: context)
        let url = TemplateShareService.encodeTemplate(template)!

        let payload = TemplateShareService.decodeTemplateURL(url: url)!
        #expect(payload.exercises.count == 2)
        let bench = payload.exercises.first { $0.exerciseName == "Bench Press" }!
        #expect(bench.sets == 4)
        #expect(bench.reps == 8)
        #expect(bench.weightKg == 84.0)
        #expect(bench.sortOrder == 0)
    }

    @Test func decodeReturnsNilForWrongScheme() {
        let url = URL(string: "https://template?v=1&data=dGVzdA")!
        #expect(TemplateShareService.decodeTemplateURL(url: url) == nil)
    }

    @Test func decodeReturnsNilForWrongHost() {
        let url = URL(string: "fitnavi://workout?v=1&data=dGVzdA")!
        #expect(TemplateShareService.decodeTemplateURL(url: url) == nil)
    }

    @Test func decodeReturnsNilForMissingDataParam() {
        let url = URL(string: "fitnavi://template?v=1")!
        #expect(TemplateShareService.decodeTemplateURL(url: url) == nil)
    }

    @Test func decodeReturnsNilForInvalidBase64() {
        let url = URL(string: "fitnavi://template?v=1&data=!!!invalid!!!")!
        #expect(TemplateShareService.decodeTemplateURL(url: url) == nil)
    }

    @Test func decodeReturnsNilForValidBase64ButInvalidJSON() {
        // "hello world" in base64url
        let url = URL(string: "fitnavi://template?v=1&data=aGVsbG8gd29ybGQ")!
        #expect(TemplateShareService.decodeTemplateURL(url: url) == nil)
    }

    @Test func decodeReturnsNilForMissingRequiredFields() {
        // JSON with no "name" field
        let json = #"{"v":1,"workoutType":"HIIT","exercises":[]}"#
        let base64 = Data(json.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let url = URL(string: "fitnavi://template?v=1&data=\(base64)")!
        #expect(TemplateShareService.decodeTemplateURL(url: url) == nil)
    }

    @Test func decodeReturnsNilForInvalidWorkoutType() {
        let json = #"{"v":1,"name":"Yoga Flow","workoutType":"Yoga","durationMinutes":60,"exercises":[]}"#
        let base64 = Data(json.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let url = URL(string: "fitnavi://template?v=1&data=\(base64)")!
        #expect(TemplateShareService.decodeTemplateURL(url: url) == nil)
    }

    @Test func decodeReturnsNilForWrongVersion() {
        let json = #"{"v":2,"name":"Push Day","workoutType":"Strength Training","durationMinutes":60,"exercises":[]}"#
        let base64 = Data(json.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let url = URL(string: "fitnavi://template?v=1&data=\(base64)")!
        #expect(TemplateShareService.decodeTemplateURL(url: url) == nil)
    }
}

// MARK: - Roundtrip

struct TemplateShareRoundtripTests {

    @Test func roundtripPreservesTemplateName() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(name: "Upper Body Blast", context: context)
        let url = TemplateShareService.encodeTemplate(template)!
        let payload = TemplateShareService.decodeTemplateURL(url: url)!
        #expect(payload.name == "Upper Body Blast")
    }

    @Test func roundtripPreservesWorkoutType() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(workoutType: "HIIT", context: context)
        let url = TemplateShareService.encodeTemplate(template)!
        let payload = TemplateShareService.decodeTemplateURL(url: url)!
        #expect(payload.workoutType == "HIIT")
    }

    @Test func roundtripPreservesDuration() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(durationMinutes: 75, context: context)
        let url = TemplateShareService.encodeTemplate(template)!
        let payload = TemplateShareService.decodeTemplateURL(url: url)!
        #expect(payload.durationMinutes == 75)
    }

    @Test func roundtripPreservesNilDuration() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(durationMinutes: nil, context: context)
        let url = TemplateShareService.encodeTemplate(template)!
        let payload = TemplateShareService.decodeTemplateURL(url: url)!
        #expect(payload.durationMinutes == nil)
    }

    @Test func roundtripPreservesAllExercises() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(context: context)
        let url = TemplateShareService.encodeTemplate(template)!
        let payload = TemplateShareService.decodeTemplateURL(url: url)!

        #expect(payload.exercises.count == 2)

        let bench = payload.exercises.first { $0.sortOrder == 0 }!
        #expect(bench.exerciseName == "Bench Press")
        #expect(bench.sets == 4)
        #expect(bench.reps == 8)
        #expect(bench.weightKg == 84.0)

        let pushups = payload.exercises.first { $0.sortOrder == 1 }!
        #expect(pushups.exerciseName == "Push-Ups")
        #expect(pushups.sets == 3)
        #expect(pushups.reps == 15)
    }

    @Test func roundtripPreservesBodyweightExercises() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(context: context)
        let url = TemplateShareService.encodeTemplate(template)!
        let payload = TemplateShareService.decodeTemplateURL(url: url)!

        let pushups = payload.exercises.first { $0.exerciseName == "Push-Ups" }!
        #expect(pushups.weightKg == nil)
    }
}

// MARK: - Duplicate Name Resolution

struct TemplateShareDuplicateNameTests {

    @Test func resolveNameReturnsAsIsWhenUnique() throws {
        let context = try makeShareTestContext()
        let resolved = TemplateShareService.resolveTemplateName(name: "Push Day", context: context)
        #expect(resolved == "Push Day")
    }

    @Test func resolveNameAppendsSuffix1WhenDuplicate() throws {
        let context = try makeShareTestContext()
        try makeSampleTemplate(name: "Push Day", context: context)

        let resolved = TemplateShareService.resolveTemplateName(name: "Push Day", context: context)
        #expect(resolved == "Push Day (1)")
    }

    @Test func resolveNameAppendsSuffix2WhenBothExist() throws {
        let context = try makeShareTestContext()
        try makeSampleTemplate(name: "Push Day", context: context)
        try makeSampleTemplate(name: "Push Day (1)", context: context)

        let resolved = TemplateShareService.resolveTemplateName(name: "Push Day", context: context)
        #expect(resolved == "Push Day (2)")
    }

    @Test func resolveNameAppendsSuffix3WhenAllExist() throws {
        let context = try makeShareTestContext()
        try makeSampleTemplate(name: "Push Day", context: context)
        try makeSampleTemplate(name: "Push Day (1)", context: context)
        try makeSampleTemplate(name: "Push Day (2)", context: context)

        let resolved = TemplateShareService.resolveTemplateName(name: "Push Day", context: context)
        #expect(resolved == "Push Day (3)")
    }

    @Test func resolveNameHandlesNamesEndingWithNumericSuffix() throws {
        let context = try makeShareTestContext()
        try makeSampleTemplate(name: "Plan 1", context: context)

        // "Plan 1" exists but "Plan 1 (1)" should be the duplicate resolution, not confused with "Plan 1"
        let resolved = TemplateShareService.resolveTemplateName(name: "Plan 1", context: context)
        #expect(resolved == "Plan 1 (1)")
    }
}

// MARK: - Import

struct TemplateShareImportTests {

    @Test func importCreatesNewTemplate() throws {
        let context = try makeShareTestContext()
        let payload = TemplatePayload(
            v: 1,
            name: "Push Day",
            workoutType: "Strength Training",
            durationMinutes: 60,
            exercises: [
                ExercisePayload(exerciseName: "Bench Press", sets: 4, reps: 8, weightKg: 80, sortOrder: 0),
            ]
        )

        TemplateShareService.importTemplate(payload: payload, context: context)

        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        #expect(templates.count == 1)
    }

    @Test func importedTemplateHasCorrectName() throws {
        let context = try makeShareTestContext()
        let payload = TemplatePayload(
            v: 1,
            name: "Leg Day",
            workoutType: "HIIT",
            durationMinutes: nil,
            exercises: []
        )

        let template = TemplateShareService.importTemplate(payload: payload, context: context)
        #expect(template.name == "Leg Day")
    }

    @Test func importedTemplateHasCorrectWorkoutType() throws {
        let context = try makeShareTestContext()
        let payload = TemplatePayload(
            v: 1,
            name: "HIIT Blast",
            workoutType: "HIIT",
            durationMinutes: 30,
            exercises: []
        )

        let template = TemplateShareService.importTemplate(payload: payload, context: context)
        #expect(template.workoutType == "HIIT")
    }

    @Test func importedTemplateHasCorrectDuration() throws {
        let context = try makeShareTestContext()
        let payload = TemplatePayload(
            v: 1,
            name: "Push Day",
            workoutType: "Strength Training",
            durationMinutes: 45,
            exercises: []
        )

        let template = TemplateShareService.importTemplate(payload: payload, context: context)
        #expect(template.durationMinutes == 45)
    }

    @Test func importedTemplateHasNilDuration() throws {
        let context = try makeShareTestContext()
        let payload = TemplatePayload(
            v: 1,
            name: "Push Day",
            workoutType: "Strength Training",
            durationMinutes: nil,
            exercises: []
        )

        let template = TemplateShareService.importTemplate(payload: payload, context: context)
        #expect(template.durationMinutes == nil)
    }

    @Test func importedTemplateHasCurrentDateCreated() throws {
        let context = try makeShareTestContext()
        let before = Date()

        let payload = TemplatePayload(
            v: 1,
            name: "Push Day",
            workoutType: "Strength Training",
            durationMinutes: nil,
            exercises: []
        )

        let template = TemplateShareService.importTemplate(payload: payload, context: context)
        let after = Date()

        #expect(template.dateCreated >= before)
        #expect(template.dateCreated <= after)
    }

    @Test func importCreatesExerciseSets() throws {
        let context = try makeShareTestContext()
        let payload = TemplatePayload(
            v: 1,
            name: "Push Day",
            workoutType: "Strength Training",
            durationMinutes: 60,
            exercises: [
                ExercisePayload(exerciseName: "Bench Press", sets: 4, reps: 8, weightKg: 80, sortOrder: 0),
                ExercisePayload(exerciseName: "Push-Ups", sets: 3, reps: 15, weightKg: nil, sortOrder: 1),
            ]
        )

        let template = TemplateShareService.importTemplate(payload: payload, context: context)
        #expect(template.exerciseSets.count == 2)
    }

    @Test func importedExerciseSetsHaveCorrectFields() throws {
        let context = try makeShareTestContext()
        let payload = TemplatePayload(
            v: 1,
            name: "Push Day",
            workoutType: "Strength Training",
            durationMinutes: nil,
            exercises: [
                ExercisePayload(exerciseName: "Bench Press", sets: 4, reps: 8, weightKg: 80, sortOrder: 0),
            ]
        )

        let template = TemplateShareService.importTemplate(payload: payload, context: context)
        let sets = template.exerciseSets.sorted { $0.sortOrder < $1.sortOrder }
        let bench = sets[0]
        #expect(bench.exerciseName == "Bench Press")
        #expect(bench.sets == 4)
        #expect(bench.reps == 8)
        #expect(bench.weightKg == 80)
        #expect(bench.sortOrder == 0)
    }

    @Test func importDoesNotAffectExistingTemplates() throws {
        let context = try makeShareTestContext()
        try makeSampleTemplate(name: "Existing Template", context: context)

        let payload = TemplatePayload(
            v: 1,
            name: "New Import",
            workoutType: "HIIT",
            durationMinutes: nil,
            exercises: []
        )

        TemplateShareService.importTemplate(payload: payload, context: context)

        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        #expect(templates.count == 2)
        #expect(templates.contains { $0.name == "Existing Template" })
        #expect(templates.contains { $0.name == "New Import" })
    }

    @Test func importDoesNotAffectWorkoutsOrGoals() throws {
        let context = try makeShareTestContext()

        // Create a workout and a goal
        let workout = Workout(name: "Test Workout", workoutType: "Strength Training")
        context.insert(workout)
        let goal = Goal(title: "Bench PR", targetValueKg: 100, currentValueKg: 80, sortOrder: 0)
        context.insert(goal)
        try context.save()

        let payload = TemplatePayload(
            v: 1,
            name: "Imported",
            workoutType: "Strength Training",
            durationMinutes: nil,
            exercises: []
        )

        TemplateShareService.importTemplate(payload: payload, context: context)

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        let goals = try context.fetch(FetchDescriptor<Goal>())
        #expect(workouts.count == 1)
        #expect(goals.count == 1)
        #expect(goals.first?.currentValueKg == 80)
    }

    @Test func importWithDuplicateNameAutoRenames() throws {
        let context = try makeShareTestContext()
        try makeSampleTemplate(name: "Push Day", context: context)

        let payload = TemplatePayload(
            v: 1,
            name: "Push Day",
            workoutType: "Strength Training",
            durationMinutes: nil,
            exercises: []
        )

        let template = TemplateShareService.importTemplate(payload: payload, context: context)
        #expect(template.name == "Push Day (1)")
    }
}

// MARK: - QR Code Indefinite Validity

struct TemplateShareValidityTests {

    @Test func noExpirationLogicInPayload() {
        // Verify TemplatePayload has no timestamp or expiration fields
        let payload = TemplatePayload(
            v: 1,
            name: "Test",
            workoutType: "HIIT",
            durationMinutes: nil,
            exercises: []
        )
        // The struct compiles with only v, name, workoutType, durationMinutes, exercises
        // No date/timestamp/expiration fields exist
        #expect(payload.v == 1)
        #expect(payload.name == "Test")
    }

    @Test func encodedURLContainsNoTimestampParameters() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(context: context)
        let url = TemplateShareService.encodeTemplate(template)!
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!

        let paramNames = components.queryItems?.map(\.name) ?? []
        #expect(!paramNames.contains("timestamp"))
        #expect(!paramNames.contains("expires"))
        #expect(!paramNames.contains("date"))
    }
}

// MARK: - ViewModel State

struct TemplateShareViewModelTests {

    @Test func viewModelHasTemplateToShareState() {
        let vm = WorkoutViewModel()
        #expect(vm.templateToShare == nil)
    }

    @Test func viewModelHasImportState() {
        let vm = WorkoutViewModel()
        #expect(vm.templatePayloadToImport == nil)
        #expect(vm.showImportError == false)
        #expect(vm.showImportPrompt == false)
    }

    @Test func handleDeepLinkValidURLSetsPayload() throws {
        let context = try makeShareTestContext()
        let template = try makeSampleTemplate(context: context)
        let url = TemplateShareService.encodeTemplate(template)!

        let vm = WorkoutViewModel()
        vm.handleTemplateDeepLink(url: url)

        #expect(vm.templatePayloadToImport != nil)
        #expect(vm.showImportPrompt == true)
        #expect(vm.showImportError == false)
    }

    @Test func handleDeepLinkInvalidURLSetsError() {
        let url = URL(string: "fitnavi://template?v=1&data=garbage")!

        let vm = WorkoutViewModel()
        vm.handleTemplateDeepLink(url: url)

        #expect(vm.templatePayloadToImport == nil)
        #expect(vm.showImportPrompt == true)
        #expect(vm.showImportError == true)
    }
}
