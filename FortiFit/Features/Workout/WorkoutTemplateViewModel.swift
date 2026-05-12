import Foundation
import SwiftData

@Observable
final class WorkoutTemplateViewModel {

    // MARK: - Data
    var templates: [WorkoutTemplate] = []

    // MARK: - Form State
    var templateName = ""
    var workoutType = "Strength Training"
    var durationMinutes = ""
    var exercises: [ExerciseFormEntry] = [ExerciseFormEntry()]

    // MARK: - Edit Mode
    var isEditMode = false
    var editingTemplate: WorkoutTemplate?

    // MARK: - Delete Confirmation
    var showDeleteConfirmation = false
    var templateToDelete: WorkoutTemplate?

    // MARK: - Autocomplete State
    var exerciseHistory: [String] = []
    var exerciseSuggestions: [ExerciseSuggestionService.Suggestion] = []
    var activeExerciseID: UUID?

    // MARK: - Computed

    let templateWorkoutTypes = ["Strength Training", "HIIT"]

    var canSaveTemplate: Bool {
        let hasName = !templateName.trimmingCharacters(in: .whitespaces).isEmpty
        let hasExercise = exercises.contains { entry in
            !entry.name.trimmingCharacters(in: .whitespaces).isEmpty &&
            entry.rows.contains { !$0.sets.isEmpty && !$0.reps.isEmpty }
        }
        return hasName && hasExercise
    }

    // MARK: - Actions

    func loadTemplates(context: ModelContext) {
        templates = WorkoutTemplateService.fetchAll(context: context)
        exerciseHistory = ExerciseSuggestionService.fetchExerciseHistory(context: context)
    }

    // MARK: - Autocomplete

    func updateSuggestions(for query: String, exerciseID: UUID) {
        activeExerciseID = exerciseID
        exerciseSuggestions = ExerciseSuggestionService.suggest(
            query: query,
            history: exerciseHistory
        )
    }

    func suggestionsForExercise(_ exercise: ExerciseFormEntry) -> [ExerciseSuggestionService.Suggestion] {
        activeExerciseID == exercise.id ? exerciseSuggestions : []
    }

    func saveTemplate(context: ModelContext) {
        let data = buildExerciseData()
        WorkoutTemplateService.create(
            name: templateName.trimmingCharacters(in: .whitespaces),
            workoutType: workoutType,
            durationMinutes: parseDuration(),
            exercises: data,
            context: context
        )
        loadTemplates(context: context)
        resetForm()
    }

    func updateTemplate(context: ModelContext) {
        guard let template = editingTemplate else { return }
        let data = buildExerciseData()
        WorkoutTemplateService.update(
            template,
            name: templateName.trimmingCharacters(in: .whitespaces),
            durationMinutes: parseDuration(),
            exercises: data,
            context: context
        )
        loadTemplates(context: context)
        resetForm()
    }

    func deleteTemplate(_ template: WorkoutTemplate, context: ModelContext) {
        WorkoutTemplateService.delete(template, context: context)
        loadTemplates(context: context)
    }

    func populateForm(from template: WorkoutTemplate) {
        isEditMode = true
        editingTemplate = template
        templateName = template.name
        workoutType = template.workoutType
        durationMinutes = template.durationMinutes.map { String($0) } ?? ""

        let settings = UserSettings.shared
        let sorted = template.exerciseSets.sorted { $0.sortOrder < $1.sortOrder }
        let grouped = Dictionary(grouping: sorted, by: { $0.exerciseName })
        let orderedNames = sorted.map { $0.exerciseName }
        var seen = Set<String>()
        let uniqueNames = orderedNames.filter { seen.insert($0).inserted }

        if uniqueNames.isEmpty {
            exercises = [ExerciseFormEntry()]
        } else {
            exercises = uniqueNames.map { name in
                let entry = ExerciseFormEntry()
                entry.name = name
                if let rows = grouped[name] {
                    entry.restSeconds = rows.first?.restSeconds
                    entry.displayAsTime = rows.first?.displayAsTime
                    entry.rows = rows.map { templateSet in
                        let row = SetRow()
                        row.sets = String(templateSet.sets)
                        row.reps = String(templateSet.reps)
                        if let weightKg = templateSet.weightKg {
                            if settings.useLbs, let lbs = UnitConversion.kgToLbs(weightKg) {
                                row.weight = String(Int(round(lbs)))
                            } else {
                                row.weight = String(format: "%g", weightKg)
                            }
                        }
                        return row
                    }
                }
                return entry
            }
        }
    }

    func resetForm() {
        isEditMode = false
        editingTemplate = nil
        templateName = ""
        workoutType = "Strength Training"
        durationMinutes = ""
        exercises = [ExerciseFormEntry()]
    }

    // MARK: - Helpers

    private func buildExerciseData() -> [WorkoutTemplateService.ExerciseData] {
        var data: [WorkoutTemplateService.ExerciseData] = []
        var globalSortOrder = 0
        for entry in exercises {
            guard !entry.name.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            for row in entry.rows {
                data.append(WorkoutTemplateService.ExerciseData(
                    name: entry.name.trimmingCharacters(in: .whitespaces),
                    sets: max(Int(row.sets) ?? 1, 1),
                    reps: max(Int(row.reps) ?? 1, 1),
                    weightKg: parseWeight(row.weight),
                    sortOrder: globalSortOrder,
                    restSeconds: entry.restSeconds,
                    displayAsTime: entry.displayAsTime
                ))
                globalSortOrder += 1
            }
        }
        return data
    }

    private func parseDuration() -> Int? {
        let value = Int(durationMinutes)
        return value != nil && value! > 0 ? value : nil
    }

    private func parseWeight(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let settings = UserSettings.shared
        if let value = Double(trimmed) {
            return settings.useLbs ? UnitConversion.lbsToKg(value) : value
        }
        return nil
    }
}
