import SwiftUI
import SwiftData

struct CreateTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let editingTemplate: WorkoutTemplate?

    @State private var viewModel = WorkoutTemplateViewModel()
    @State private var showDeleteAlert = false
    @State private var showQRModal = false
    @State private var headerHeight: CGFloat = 0

    private var settings: UserSettings { UserSettings.shared }
    private var weightUnit: String { settings.useLbs ? "lbs" : "kg" }

    var body: some View {
        ZStack(alignment: .top) {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: FortiFitSpacing.gapLarge) {
                FortiFitScreenHeading(viewModel.isEditMode ? "Edit Template" : "Create Template")

                // Template Name
                FortiFitLabel("Template Name", color: FortiFitColors.primaryText)
                FortiFitInput(placeholder: "e.g. Push Day Template", text: $viewModel.templateName)

                // Workout Type (Strength Training / HIIT only, locked in edit mode)
                FortiFitLabel("Workout Type", color: FortiFitColors.primaryText)
                FortiFitSelect(
                    options: viewModel.templateWorkoutTypes,
                    selected: $viewModel.workoutType,
                    placeholder: "Select Type"
                )
                .disabled(viewModel.isEditMode)

                // Duration (optional)
                FortiFitLabel("Duration (minutes)", color: FortiFitColors.primaryText)
                FortiFitInput(placeholder: "Optional", text: $viewModel.durationMinutes)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif

                FortiFitDivider()

                // Exercises
                exercisesSection

                // Save Button
                FortiFitButton(
                    viewModel.isEditMode ? "Save Changes" : "Save Template",
                    style: .primary,
                    isEnabled: viewModel.canSaveTemplate
                ) {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    if viewModel.isEditMode {
                        viewModel.updateTemplate(context: modelContext)
                    } else {
                        viewModel.saveTemplate(context: modelContext)
                    }
                    dismiss()
                }
            }
            .padding(.horizontal, FortiFitSpacing.screenHorizontal)
            .padding(.top, headerHeight)
            .padding(.bottom, FortiFitSpacing.gapXLarge)
        }
        .scrollClipDisabled()

        // Fixed header
        FortiFitFixedHeader(headerHeight: $headerHeight) {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapLarge) {
                HStack {
                    FortiFitBackButton { dismiss() }
                    Spacer()
                    if viewModel.isEditMode {
                        Button {
                            showDeleteAlert = true
                        } label: {
                            Image(systemName: AppConstants.deleteIcon)
                                .font(.system(size: 16))
                                .foregroundStyle(FortiFitColors.primaryAccent)
                                .frame(width: FortiFitSpacing.minTouchTarget, height: FortiFitSpacing.minTouchTarget)
                                .background(
                                    RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                                        .fill(.clear)
                                        .stroke(FortiFitColors.primaryAccent, lineWidth: 1)
                                )
                        }

                        #if os(iOS)
                        Menu {
                            Button {
                                showQRModal = true
                            } label: {
                                Label("Share Template", systemImage: "qrcode")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16))
                                .foregroundStyle(FortiFitColors.primaryAccent)
                                .frame(width: FortiFitSpacing.minTouchTarget, height: FortiFitSpacing.minTouchTarget)
                                .background(
                                    RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                                        .fill(.clear)
                                        .stroke(FortiFitColors.primaryAccent, lineWidth: 1)
                                )
                        }
                        #endif
                    }
                }

            }
        }
        }
        .background(FortiFitColors.background)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .onAppear {
            viewModel.loadTemplates(context: modelContext)
            if let template = editingTemplate {
                viewModel.populateForm(from: template)
            }
        }
        .alert(
            "Delete \(viewModel.templateName)?",
            isPresented: $showDeleteAlert
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let template = editingTemplate {
                    viewModel.deleteTemplate(template, context: modelContext)
                }
                dismiss()
            }
        } message: {
            Text("This can't be undone.")
        }
        #if os(iOS)
        .overlay {
            if showQRModal, let template = editingTemplate {
                TemplateQRModalView(template: template) {
                    showQRModal = false
                }
            }
        }
        #endif
    }

    // MARK: - Exercises Section

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.gapMedium) {
            FortiFitWidgetHeader(title: "Exercises")

            ForEach(Array(viewModel.exercises.enumerated()), id: \.element.id) { exerciseIndex, exercise in
                ExerciseCardView(
                    exercise: exercise,
                    exerciseIndex: exerciseIndex,
                    exerciseCount: viewModel.exercises.count,
                    isEditMode: viewModel.isEditMode,
                    weightUnit: weightUnit,
                    suggestions: viewModel.suggestionsForExercise(exercise),
                    onExerciseNameChanged: { query in
                        viewModel.updateSuggestions(for: query, exerciseID: exercise.id)
                    },
                    onRemove: {
                        viewModel.exercises.removeAll { $0.id == exercise.id }
                    }
                )
                .zIndex(viewModel.activeExerciseID == exercise.id ? 100 : 0)
            }

            FortiFitButton("Add Exercise", style: .outline) {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                viewModel.exercises.append(ExerciseFormEntry())
            }
        }
    }
}

#Preview {
    NavigationStack {
        CreateTemplateView(editingTemplate: nil)
            .modelContainer(for: [WorkoutTemplate.self, TemplateExerciseSet.self], inMemory: true)
    }
}
