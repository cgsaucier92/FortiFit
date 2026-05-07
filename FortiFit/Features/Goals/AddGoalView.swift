import SwiftUI
import SwiftData

struct AddGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: GoalsViewModel
    @State private var headerHeight: CGFloat = 0

    private var settings: UserSettings { UserSettings.shared }
    private var weightUnit: String { settings.useLbs ? "lbs" : "kg" }
    private var distanceUnit: String { settings.useMiles ? "mi" : "km" }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: FortiFitSpacing.gapLarge) {
                    FortiFitScreenHeading(viewModel.isEditMode ? "Edit Goal" : "Add Goal")

                    // Goal Type Selector — hidden in edit mode (type is locked)
                    if !viewModel.isEditMode {
                        FortiFitLabel("Goal Type", color: FortiFitColors.primaryText)
                        goalTypeSelector
                    }

                    // Conditional form — only shown after a type is selected
                    VStack(alignment: .leading, spacing: FortiFitSpacing.gapLarge) {
                        if !viewModel.selectedGoalType.isEmpty {
                            if !viewModel.isEditMode {
                                FortiFitDivider()
                            }

                            switch viewModel.selectedGoalType {
                            case "Strength PR":
                                exercisePRForm
                            case "Repetitions PR":
                                repetitionsPRForm
                            case "Speed and Distance":
                                speedDistanceForm
                            case "Number of Weekly Workouts":
                                weeklyWorkoutsForm
                            default:
                                EmptyView()
                            }
                        }
                    }
                    .zIndex(1)

                    // Save Button
                    FortiFitButton(
                        viewModel.isEditMode ? "Save Changes" : "Save Goal",
                        style: .primary,
                        isEnabled: viewModel.canSaveGoal
                    ) {
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        if viewModel.isEditMode {
                            viewModel.saveEditedGoal(context: modelContext)
                        } else {
                            viewModel.saveGoal(context: modelContext)
                        }
                        dismiss()
                    }
                    .accessibilityIdentifier(AccessibilityID.saveGoalButton)
                }
                .padding(.horizontal, FortiFitSpacing.screenHorizontal)
                .padding(.top, headerHeight)
                .padding(.bottom, FortiFitSpacing.gapXLarge)
            }
            .scrollClipDisabled()

            FortiFitFixedHeader(headerHeight: $headerHeight) {
                HStack {
                    FortiFitBackButton { dismiss() }
                    Spacer()
                }
            }
        }
        .background(FortiFitColors.background)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    // MARK: - Shared Exercise Input

    private var customExerciseInput: some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.gapLarge) {
            if viewModel.isCustomExercise {
                FortiFitLabel("Exercise Name", color: FortiFitColors.primaryText)
                FortiFitExerciseAutocomplete(
                    placeholder: "e.g. Front Squat",
                    text: $viewModel.customExerciseName,
                    suggestions: viewModel.customExerciseSuggestions,
                    onQueryChanged: { query in
                        viewModel.updateCustomExerciseSuggestions(query: query)
                    }
                )
            }
        }
        .zIndex(1)
    }

    // MARK: - Strength PR Form

    private var exercisePRForm: some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.gapLarge) {
            FortiFitLabel("Exercise", color: FortiFitColors.primaryText)
            FortiFitSelect(
                options: AppConstants.exerciseOptions,
                selected: $viewModel.selectedExercise,
                placeholder: "Select Exercise",
                accessibilityIdentifier: AccessibilityID.goalExerciseDropdown,
                optionIdentifierPrefix: AccessibilityID.goalExerciseOptionPrefix
            )

            customExerciseInput

            if viewModel.isEditMode {
                VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
                    FortiFitLabel("Target (\(weightUnit))", color: FortiFitColors.primaryText)
                    FortiFitInput(placeholder: "0", text: $viewModel.targetWeightText)
                        .accessibilityIdentifier(AccessibilityID.goalTargetWeightInput)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
            } else {
                HStack(spacing: FortiFitSpacing.gapSmall) {
                    VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
                        FortiFitLabel("Current (\(weightUnit))", color: FortiFitColors.primaryText)
                        FortiFitInput(placeholder: "0", text: $viewModel.currentWeightText)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    }

                    VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
                        FortiFitLabel("Target (\(weightUnit))", color: FortiFitColors.primaryText)
                        FortiFitInput(placeholder: "0", text: $viewModel.targetWeightText)
                            .accessibilityIdentifier(AccessibilityID.goalTargetWeightInput)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    }
                }
            }
        }
    }

    // MARK: - Repetitions PR Form

    private var repetitionsPRForm: some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.gapLarge) {
            FortiFitLabel("Exercise", color: FortiFitColors.primaryText)
            FortiFitSelect(
                options: AppConstants.exerciseOptions,
                selected: $viewModel.selectedExercise,
                placeholder: "Select Exercise"
            )

            customExerciseInput

            if viewModel.isEditMode {
                VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
                    FortiFitLabel("Target Reps", color: FortiFitColors.primaryText)
                    FortiFitInput(placeholder: "0", text: $viewModel.targetRepsText)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }
            } else {
                HStack(spacing: FortiFitSpacing.gapSmall) {
                    VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
                        FortiFitLabel("Current Reps", color: FortiFitColors.primaryText)
                        FortiFitInput(placeholder: "0", text: $viewModel.currentRepsText)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                    }

                    VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
                        FortiFitLabel("Target Reps", color: FortiFitColors.primaryText)
                        FortiFitInput(placeholder: "0", text: $viewModel.targetRepsText)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                    }
                }
            }
        }
    }

    // MARK: - Goal Type Selector

    private var weeklyWorkoutsAlreadyExists: Bool {
        GoalService.weeklyWorkoutsGoalExists(context: modelContext)
    }

    private var goalTypeSelector: some View {
        FortiFitSelect(
            options: AppConstants.goalTypes.filter { type in
                !(type == "Number of Weekly Workouts" && weeklyWorkoutsAlreadyExists)
            },
            selected: $viewModel.selectedGoalType,
            placeholder: "Select Goal Type"
        )
    }

    // MARK: - Weekly Workouts Form

    private var weeklyWorkoutsForm: some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.gapLarge) {
            VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
                FortiFitLabel("Target Workouts Per Week", color: FortiFitColors.primaryText)
                Text("\(settings.targetWorkoutsPerWeek)")
                    .font(FortiFitTypography.dataValue)
                    .foregroundStyle(FortiFitColors.primaryText)
                    .padding(.horizontal, FortiFitSpacing.cardPadding)
                    .frame(height: FortiFitSpacing.minTouchTarget, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadiusSmall)
                            .fill(FortiFitColors.elevatedSurface.opacity(0.5))
                    )
            }

            Text("This goal tracks your weekly workout target. To change the target, long-press the Weekly Streak widget on the DASHBOARD screen and tap Configure Settings.")
                .font(FortiFitTypography.note)
                .italic()
                .foregroundStyle(FortiFitColors.mutedText)
        }
    }

    // MARK: - Speed and Distance Form

    private var speedDistanceForm: some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.gapLarge) {
            FortiFitLabel("Goal Name", color: FortiFitColors.primaryText)
            FortiFitInput(placeholder: "e.g. 5K Run", text: $viewModel.goalNameText)

            FortiFitLabel("Workout Type", color: FortiFitColors.primaryText)
            FortiFitSelect(
                options: AppConstants.workoutTypes,
                selected: $viewModel.selectedLinkedWorkoutType,
                placeholder: "Select Workout Type"
            )
            .disabled(viewModel.isEditMode)

            VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
                FortiFitLabel("Target Distance (\(distanceUnit))", color: FortiFitColors.primaryText)
                FortiFitInput(placeholder: "0", text: $viewModel.targetDistanceText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            }

            VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
                FortiFitLabel("Target Duration (min)", color: FortiFitColors.primaryText)
                FortiFitInput(placeholder: "0", text: $viewModel.targetDurationText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            }

            Text("Select a workout type and set at least one target (distance or duration)")
                .font(FortiFitTypography.note)
                .foregroundStyle(FortiFitColors.mutedText)
        }
    }
}

#Preview {
    NavigationStack {
        AddGoalView(viewModel: GoalsViewModel())
            .modelContainer(for: [Workout.self, ExerciseSet.self, Goal.self], inMemory: true)
    }
}
