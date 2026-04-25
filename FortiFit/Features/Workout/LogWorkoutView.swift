import SwiftUI
import SwiftData

struct LogWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: WorkoutViewModel
    @State private var showRPETooltip = false
    @State private var showDeleteAlert = false
    @State private var showHealthSourceInfoSheet = false
    var onDeleteWorkout: (() -> Void)?
    @State private var headerHeight: CGFloat = 0

    private var settings: UserSettings { UserSettings.shared }
    private var weightUnit: String { settings.useLbs ? "lbs" : "kg" }
    private var distanceUnit: String { settings.useMiles ? "mi" : "km" }

    var body: some View {
        ZStack {
        ZStack(alignment: .top) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: FortiFitSpacing.gapLarge) {
                    FortiFitScreenHeading(viewModel.isEditMode ? "Edit Workout" : "Log Workout")

                    // Workout Name
                    FortiFitLabel("Workout Name", color: FortiFitColors.primaryText)
                    FortiFitInput(placeholder: "e.g. Push Day IV", text: $viewModel.workoutName)
                        .accessibilityIdentifier(AccessibilityID.workoutNameInput)

                    // Date & Start Time Picker
                    FortiFitLabel("Date & Start Time", color: FortiFitColors.primaryText)
                    DatePicker(
                        "",
                        selection: $viewModel.workoutDate,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(FortiFitColors.primaryAccent)
                    .colorScheme(.dark)
                    .disabled(viewModel.isHealthKitLinked)
                    .opacity(viewModel.isHealthKitLinked ? 0.5 : 1)

                    if viewModel.isHealthKitLinked {
                        healthKitHelperText(identifier: AccessibilityID.logWorkoutDateReadOnlyHelper)
                    }

                    // Workout Type
                    FortiFitLabel("Workout Type", color: FortiFitColors.primaryText)
                    FortiFitSelect(
                        options: AppConstants.workoutTypes,
                        selected: $viewModel.workoutType,
                        placeholder: "Select Type",
                        accessibilityIdentifier: AccessibilityID.workoutTypeDropdown,
                        optionIdentifierPrefix: AccessibilityID.workoutTypeOptionPrefix
                    )
                    .disabled(viewModel.isEditMode)

                    // RPE
                    HStack(spacing: FortiFitSpacing.elementSpacing) {
                        FortiFitLabel("Post-Workout RPE", color: FortiFitColors.primaryText)
                        FortiFitHintTooltip(
                            message: "Rate of Perceived Exertion (1–10). How hard did the workout feel overall? 1 = very easy, 10 = maximal effort",
                            isVisible: $showRPETooltip
                        )
                    }
                    FortiFitSelect(
                        options: AppConstants.rpeScale.map { String($0) },
                        selected: Binding(
                            get: { viewModel.selectedRPE.map { String($0) } ?? "" },
                            set: { viewModel.selectedRPE = Int($0) }
                        ),
                        placeholder: "Select RPE (optional)"
                    )

                    // Duration (all workout types)
                    FortiFitLabel("Duration (minutes)", color: FortiFitColors.primaryText)
                    FortiFitInput(placeholder: "Optional", text: $viewModel.durationMinutes)
                        .accessibilityIdentifier(AccessibilityID.durationInput)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .disabled(viewModel.isHealthKitLinked)
                        .opacity(viewModel.isHealthKitLinked ? 0.5 : 1)

                    if viewModel.isHealthKitLinked {
                        healthKitHelperText(identifier: AccessibilityID.logWorkoutDurationReadOnlyHelper)
                    }

                    // Type-specific fields
                    if viewModel.isStrengthOrHIIT {
                        exercisesSection
                    } else if viewModel.isCardioOrSprints {
                        distanceSection
                    }

                    // Save Button
                    FortiFitButton(
                        viewModel.isEditMode ? "Save Changes" : "Save Workout",
                        style: .primary,
                        isEnabled: viewModel.canSaveWorkout
                    ) {
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        if viewModel.isEditMode {
                            viewModel.saveEditedWorkout(context: modelContext)
                        } else {
                            viewModel.saveWorkout(context: modelContext)
                        }
                        dismiss()
                    }
                    .accessibilityIdentifier(AccessibilityID.saveWorkoutButton)
                }
                .padding(.horizontal, FortiFitSpacing.screenHorizontal)
                .padding(.top, headerHeight)
                .padding(.bottom, FortiFitSpacing.gapXLarge)
            }
            .scrollClipDisabled()
            .scrollDismissesKeyboard(.interactively)

            // Fixed header
            VStack(spacing: 0) {
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
                        } else {
                            ellipsisMenu
                        }
                    }

                    FortiFitDivider()
                }
                .padding(.horizontal, FortiFitSpacing.screenHorizontal)
                .padding(.top, FortiFitSpacing.screenTop)
                .padding(.bottom, FortiFitSpacing.elementSpacing)
                .background(FortiFitColors.background.opacity(0.90))

                LinearGradient(
                    colors: [FortiFitColors.background.opacity(0.90), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 30)
                .allowsHitTesting(false)
            }
            .overlay {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { headerHeight = geo.size.height }
                        .onChange(of: geo.size.height) { _, newValue in headerHeight = newValue }
                }
            }
        }
            // Template selector overlay
            if viewModel.showTemplateSelector {
                templateSelectorOverlay
            }

            // "Template saved!" toast
            if viewModel.showTemplateSavedToast {
                VStack {
                    Text("Template saved!")
                        .font(FortiFitTypography.bodySmall)
                        .foregroundStyle(.white)
                        .padding(.horizontal, FortiFitSpacing.cardPadding)
                        .padding(.vertical, FortiFitSpacing.elementSpacing)
                        .background(
                            Capsule()
                                .fill(FortiFitColors.primaryAccent)
                        )
                        .padding(.top, FortiFitSpacing.screenTop)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
        .background(FortiFitColors.background)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .onAppear { viewModel.loadTemplates(context: modelContext) }
        .alert("Name Template", isPresented: $viewModel.showSaveAsTemplatePrompt) {
            TextField("Template name", text: $viewModel.saveAsTemplateName)
            Button("Cancel", role: .cancel) {
                viewModel.saveAsTemplateName = ""
            }
            Button("Save") {
                viewModel.saveCurrentFormAsTemplate(
                    name: viewModel.saveAsTemplateName,
                    context: modelContext
                )
                viewModel.saveAsTemplateName = ""
                withAnimation {
                    viewModel.showTemplateSavedToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        viewModel.showTemplateSavedToast = false
                    }
                }
            }
        } message: {
            Text("Enter a name for this template.")
        }
        .sheet(isPresented: $showHealthSourceInfoSheet) {
            if let workout = viewModel.editingWorkout {
                FortiFitHealthSourceInfoSheet(
                    workout: workout,
                    sourceName: workout.healthKitSourceBundleID
                ) {
                    WorkoutService.unlink(workout, context: modelContext)
                }
            }
        }
        .alert(
            "Delete \(viewModel.workoutName)?",
            isPresented: $showDeleteAlert
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let workout = viewModel.editingWorkout {
                    viewModel.deleteWorkout(workout, context: modelContext)
                }
                dismiss()
                onDeleteWorkout?()
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    // MARK: - Ellipsis Menu

    private var ellipsisMenu: some View {
        Menu {
            Button {
                viewModel.showTemplateSelector = true
            } label: {
                Label("Use Template", systemImage: "doc.badge.arrow.up")
            }
            Button {
                viewModel.saveAsTemplateName = viewModel.workoutName
                viewModel.showSaveAsTemplatePrompt = true
            } label: {
                Label("Save As Template", systemImage: "square.and.arrow.down")
            }
            .disabled(!viewModel.canSaveAsTemplate)
        } label: {
            FortiFitEllipsisButton()
        }
    }

    // MARK: - Template Selector Overlay

    private var templateSelectorOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.showTemplateSelector = false
                }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Select Template")
                        .font(FortiFitTypography.label)
                        .foregroundStyle(FortiFitColors.primaryAccent)
                    Spacer()
                    Button {
                        viewModel.showTemplateSelector = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FortiFitColors.mutedText)
                    }
                }
                .padding(FortiFitSpacing.cardPadding)

                Rectangle()
                    .fill(FortiFitColors.border)
                    .frame(height: 1)

                if viewModel.templates.isEmpty {
                    Text("No saved templates yet.")
                        .font(FortiFitTypography.note)
                        .foregroundStyle(FortiFitColors.mutedText)
                        .padding(FortiFitSpacing.gapXLarge)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(viewModel.templates) { template in
                                Button {
                                    viewModel.applyTemplate(template)
                                    viewModel.showTemplateSelector = false
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(template.name)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(FortiFitColors.primaryText)
                                            Text(template.workoutType)
                                                .font(FortiFitTypography.bodySmall)
                                                .foregroundStyle(FortiFitColors.mutedText)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, FortiFitSpacing.cardPadding)
                                    .padding(.vertical, FortiFitSpacing.gapSmall)
                                }

                                if template.id != viewModel.templates.last?.id {
                                    Rectangle()
                                        .fill(FortiFitColors.border)
                                        .frame(height: 1)
                                        .padding(.horizontal, FortiFitSpacing.cardPadding)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 320)
                }
            }
            .frame(width: 300)
            .background(FortiFitColors.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                    .stroke(FortiFitColors.border, lineWidth: 1)
            )
        }
    }

    // MARK: - HealthKit Helper Text

    private func healthKitHelperText(identifier: String) -> some View {
        Button {
            showHealthSourceInfoSheet = true
        } label: {
            Text("LINKED TO APPLE HEALTH · TAP TO UNLINK")
                .font(.system(size: 11, weight: .bold))
                .kerning(2)
                .foregroundStyle(FortiFitColors.mutedText)
        }
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Exercises Section (Strength/HIIT)

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
            .accessibilityIdentifier(AccessibilityID.addExerciseButton)
        }
    }

    // MARK: - Distance (Cardio/Sprints)

    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
            FortiFitLabel("Distance (\(distanceUnit))", color: FortiFitColors.primaryText)
            FortiFitInput(placeholder: "Optional", text: $viewModel.distanceKm)
                .accessibilityIdentifier(AccessibilityID.distanceInput)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .disabled(viewModel.isHealthKitLinked)
                .opacity(viewModel.isHealthKitLinked ? 0.5 : 1)

            if viewModel.isHealthKitLinked {
                healthKitHelperText(identifier: AccessibilityID.logWorkoutDistanceReadOnlyHelper)
            }
        }
    }
}

// MARK: - ExerciseCardView (isolated observation scope)

struct ExerciseCardView: View {
    let exercise: ExerciseFormEntry
    let exerciseIndex: Int
    let exerciseCount: Int
    let isEditMode: Bool
    let weightUnit: String
    var suggestions: [ExerciseSuggestionService.Suggestion] = []
    var onExerciseNameChanged: ((String) -> Void)?
    let onRemove: () -> Void

    var body: some View {
        FortiFitCard(borderColor: FortiFitColors.border) {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                HStack {
                    FortiFitExerciseAutocomplete(
                        placeholder: "Exercise name",
                        text: Binding(
                            get: { exercise.name },
                            set: { exercise.name = $0 }
                        ),
                        suggestions: suggestions,
                        onQueryChanged: { query in
                            onExerciseNameChanged?(query)
                        },
                        accessibilityIdentifier: AccessibilityID.exerciseNameInput(exerciseIndex)
                    )
                    if exerciseCount > 1 || isEditMode {
                        Button(action: onRemove) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(FortiFitColors.mutedText)
                                .frame(width: 44, height: 44)
                        }
                    }
                }
                .zIndex(1)

                // Column headers
                HStack(spacing: FortiFitSpacing.elementSpacing) {
                    Text("SETS")
                        .frame(maxWidth: .infinity)
                    Text("REPS")
                        .frame(maxWidth: .infinity)
                    Text(weightUnit.uppercased())
                        .frame(maxWidth: .infinity)
                    Color.clear.frame(width: 32)
                }
                .font(FortiFitTypography.label)
                .kerning(FortiFitTypography.labelKerning)
                .foregroundStyle(FortiFitColors.mutedText)

                ForEach(Array(exercise.rows.enumerated()), id: \.element.id) { rowIndex, row in
                    SetRowView(
                        row: row,
                        exerciseIndex: exerciseIndex,
                        rowIndex: rowIndex,
                        canRemove: exercise.rows.count > 1,
                        onRemove: { exercise.removeRow(row) }
                    )
                }

                Button {
                    exercise.addRow()
                } label: {
                    Text("ADD ROW")
                        .font(FortiFitTypography.label)
                        .kerning(FortiFitTypography.labelKerning)
                        .foregroundStyle(FortiFitColors.primaryAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
            }
        }
    }
}

// MARK: - SetRowView (isolated observation scope)

struct SetRowView: View {
    let row: SetRow
    let exerciseIndex: Int
    let rowIndex: Int
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: FortiFitSpacing.elementSpacing) {
            NumberFieldView(
                text: Binding(get: { row.sets }, set: { row.sets = $0 }),
                placeholder: "0"
            )
            .accessibilityIdentifier(AccessibilityID.setsInput(exerciseIndex, rowIndex))
            NumberFieldView(
                text: Binding(get: { row.reps }, set: { row.reps = $0 }),
                placeholder: "0"
            )
            .accessibilityIdentifier(AccessibilityID.repsInput(exerciseIndex, rowIndex))
            NumberFieldView(
                text: Binding(get: { row.weight }, set: { row.weight = $0 }),
                placeholder: "BW"
            )
            .accessibilityIdentifier(AccessibilityID.weightInput(exerciseIndex, rowIndex))
            if canRemove {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(FortiFitColors.alert)
                        .frame(width: 32, height: 32)
                }
            } else {
                Color.clear.frame(width: 32, height: 32)
            }
        }
    }
}

// MARK: - NumberFieldView (isolated observation scope)

struct NumberFieldView: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(FortiFitTypography.body)
            .foregroundStyle(FortiFitColors.primaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadiusSmall)
                    .fill(FortiFitColors.elevatedSurface)
            )
            #if os(iOS)
            .keyboardType(.decimalPad)
            #endif
            .tint(FortiFitColors.primaryAccent)
    }
}

#Preview {
    NavigationStack {
        LogWorkoutView(viewModel: WorkoutViewModel())
            .modelContainer(for: [Workout.self, ExerciseSet.self, Goal.self], inMemory: true)
    }
}
