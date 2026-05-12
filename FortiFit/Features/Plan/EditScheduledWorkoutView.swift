import SwiftUI
import SwiftData

@Observable
final class EditScheduledWorkoutViewModel {
    var workoutName: String = ""
    var scheduledDate: Date = Date()
    var scheduledTime: Date? = nil
    var durationMinutes: String = ""
    var exercises: [EditableExercise] = []
    var syncToAppleWatch: Bool = false
    var workoutType: String = ""

    var showRecurrencePrompt = false
    var pendingRecurrenceScope: RecurrenceScope = .thisOnly
    var dateChanged = false

    private var originalDate: Date = Date()
    private(set) var scheduledWorkout: ScheduledWorkout?

    struct EditableSetRow: Identifiable {
        let id = UUID()
        var sets: String
        var reps: String
        var weight: String
    }

    struct EditableExercise: Identifiable {
        let id = UUID()
        var exerciseName: String
        var rows: [EditableSetRow]
        var sortOrder: Int
        var restSeconds: Int?
        var displayAsTime: Bool?

        var resolvedDisplayAsTime: Bool {
            displayAsTime ?? ExerciseSuggestionService.isIsometric(exerciseName)
        }
    }

    var isValid: Bool {
        !workoutName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !exercises.isEmpty &&
        exercises.allSatisfy { ex in
            !ex.rows.isEmpty &&
            ex.rows.allSatisfy { row in
                (Int(row.sets) ?? 0) > 0 && (Int(row.reps) ?? 0) > 0
            }
        }
    }

    var isRecurring: Bool {
        scheduledWorkout?.recurrenceGroupId != nil
    }

    func load(from sw: ScheduledWorkout) {
        scheduledWorkout = sw
        workoutName = sw.workoutName
        scheduledDate = sw.scheduledDate
        originalDate = sw.scheduledDate
        scheduledTime = sw.scheduledTime
        durationMinutes = sw.durationMinutes.map { "\($0)" } ?? ""
        syncToAppleWatch = sw.syncToAppleWatch
        workoutType = sw.workoutType

        if let data = sw.scheduledWorkoutSnapshot {
            let snapshots = PlanService.decodeSnapshot(data: data).sorted { $0.sortOrder < $1.sortOrder }
            let settings = UserSettings.shared

            var seen = Set<String>()
            var orderedNames: [String] = []
            for snap in snapshots {
                if seen.insert(snap.exerciseName).inserted {
                    orderedNames.append(snap.exerciseName)
                }
            }
            let grouped = Dictionary(grouping: snapshots, by: { $0.exerciseName })

            exercises = orderedNames.enumerated().map { index, name in
                let entries = grouped[name]!
                return EditableExercise(
                    exerciseName: name,
                    rows: entries.map { snap in
                        var weightStr = ""
                        if let kg = snap.weightKg {
                            if settings.useLbs {
                                if let lbs = UnitConversion.kgToLbs(kg) {
                                    weightStr = String(Int(round(lbs)))
                                }
                            } else {
                                weightStr = String(format: "%g", kg)
                            }
                        }
                        return EditableSetRow(
                            sets: String(snap.sets),
                            reps: String(snap.reps),
                            weight: weightStr
                        )
                    },
                    sortOrder: index,
                    restSeconds: entries.first?.restSeconds,
                    displayAsTime: entries.first?.displayAsTime
                )
            }
        }
    }

    func addExercise() {
        let nextSort = (exercises.map { $0.sortOrder }.max() ?? -1) + 1
        exercises.append(EditableExercise(
            exerciseName: "",
            rows: [EditableSetRow(sets: "", reps: "", weight: "")],
            sortOrder: nextSort,
            restSeconds: nil,
            displayAsTime: nil
        ))
    }

    func addRow(exerciseIndex: Int) {
        exercises[exerciseIndex].rows.append(EditableSetRow(sets: "", reps: "", weight: ""))
    }

    func removeRow(exerciseIndex: Int, rowId: UUID) {
        exercises[exerciseIndex].rows.removeAll { $0.id == rowId }
        if exercises[exerciseIndex].rows.isEmpty {
            exercises[exerciseIndex].rows.append(EditableSetRow(sets: "", reps: "", weight: ""))
        }
    }

    func removeExercise(at index: Int) {
        exercises.remove(at: index)
        for i in exercises.indices {
            exercises[i].sortOrder = i
        }
    }

    func save(context: ModelContext, watchScheduleService: WatchScheduleService?) async {
        guard let sw = scheduledWorkout else { return }

        dateChanged = Calendar.current.startOfDay(for: scheduledDate) != originalDate

        if isRecurring && !dateChanged {
            showRecurrencePrompt = true
            return
        }

        await performSave(scope: .thisOnly, context: context, watchScheduleService: watchScheduleService)
    }

    func performSave(scope: RecurrenceScope, context: ModelContext, watchScheduleService: WatchScheduleService?) async {
        guard let sw = scheduledWorkout else { return }

        var globalSort = 0
        let snapshotExercises: [SnapshotExercise] = exercises.flatMap { ex in
            ex.rows.map { row in
                defer { globalSort += 1 }
                return SnapshotExercise(
                    exerciseName: ex.exerciseName,
                    sets: Int(row.sets) ?? 0,
                    reps: Int(row.reps) ?? 0,
                    weightKg: parseWeight(row.weight),
                    sortOrder: globalSort,
                    restSeconds: ex.restSeconds,
                    displayAsTime: ex.displayAsTime
                )
            }
        }

        let edits = PlanService.ScheduledWorkoutEdits(
            workoutName: workoutName,
            scheduledDate: scheduledDate,
            scheduledTime: scheduledTime,
            durationMinutes: Int(durationMinutes),
            exercises: snapshotExercises,
            syncToAppleWatch: syncToAppleWatch,
            workoutType: workoutType
        )

        let affected = PlanService.editScheduledWorkout(
            sw,
            edits: edits,
            applyTo: scope,
            context: context
        )

        if let service = watchScheduleService {
            for instance in affected where instance.syncToAppleWatch {
                await service.resync(instance, context: context)
            }
        }
    }

    private func parseWeight(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let value = Double(trimmed) else { return nil }
        return UserSettings.shared.useLbs ? UnitConversion.lbsToKg(value) : value
    }
}

// MARK: - View

struct EditScheduledWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State var viewModel = EditScheduledWorkoutViewModel()
    var watchScheduleService: WatchScheduleService?
    let scheduledWorkout: ScheduledWorkout
    @State private var headerHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: FortiFitSpacing.gapLarge) {
                    FortiFitScreenHeading("Edit Planned Workout")
                    nameSection
                    dateTimeSection
                    workoutTypeDisplay
                    durationSection
                    FortiFitDivider()
                    exercisesSection
                    addExerciseButton
                    watchSyncSection
                    saveButton
                }
                .padding(.horizontal, FortiFitSpacing.screenHorizontal)
                .padding(.top, headerHeight)
                .padding(.bottom, FortiFitSpacing.gapXLarge)
            }
            .scrollClipDisabled()
            .scrollDismissesKeyboard(.interactively)

            FortiFitFixedHeader(headerHeight: $headerHeight) {
                HStack {
                    FortiFitBackButton { dismiss() }
                        .accessibilityIdentifier(AccessibilityID.editScheduledWorkout_backButton)
                    Spacer()
                }
            }
        }
        .background(FortiFitColors.background)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .onAppear {
            viewModel.load(from: scheduledWorkout)
        }
        .confirmationDialog(
            "This is a recurring workout",
            isPresented: $viewModel.showRecurrencePrompt
        ) {
            Button("This Workout Only") {
                Task {
                    await viewModel.performSave(scope: .thisOnly, context: modelContext, watchScheduleService: watchScheduleService)
                    dismiss()
                }
            }
            .accessibilityIdentifier(AccessibilityID.editScheduledWorkout_recurrencePrompt_thisOnly)

            Button("This & Future Workouts") {
                Task {
                    await viewModel.performSave(scope: .thisAndFuture, context: modelContext, watchScheduleService: watchScheduleService)
                    dismiss()
                }
            }
            .accessibilityIdentifier(AccessibilityID.editScheduledWorkout_recurrencePrompt_thisAndFuture)

            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var nameSection: some View {
        Group {
            FortiFitLabel("Workout Name", color: FortiFitColors.primaryText)
            FortiFitInput(
                placeholder: "Workout name",
                text: $viewModel.workoutName
            )
        }
    }

    @ViewBuilder
    private var dateTimeSection: some View {
        Group {
            FortiFitLabel("Scheduled Date", color: FortiFitColors.primaryText)
            DatePicker(
                "",
                selection: $viewModel.scheduledDate,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .tint(FortiFitColors.primaryAccent)
            .colorScheme(.dark)
            .accessibilityIdentifier(AccessibilityID.editScheduledWorkout_dateField)

            Toggle(isOn: Binding(
                get: { viewModel.scheduledTime != nil },
                set: { newValue in
                    viewModel.scheduledTime = newValue ? Date() : nil
                }
            )) {
                FortiFitLabel("Scheduled Time", color: FortiFitColors.primaryText)
            }
            .tint(FortiFitColors.primaryAccent)
            .accessibilityIdentifier(AccessibilityID.editScheduledWorkout_timeField)

            if let time = viewModel.scheduledTime {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { time },
                        set: { viewModel.scheduledTime = $0 }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(FortiFitColors.primaryAccent)
                .colorScheme(.dark)
            }
        }
    }

    @ViewBuilder
    private var workoutTypeDisplay: some View {
        Group {
            FortiFitLabel("Workout Type", color: FortiFitColors.primaryText)
            FortiFitSelect(
                options: AppConstants.workoutTypes,
                selected: $viewModel.workoutType,
                placeholder: "Select Type",
                accessibilityIdentifier: AccessibilityID.workoutTypeDropdown,
                optionIdentifierPrefix: AccessibilityID.workoutTypeOptionPrefix
            )
            .frame(width: 220, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(true)
        }
    }

    @ViewBuilder
    private var durationSection: some View {
        Group {
            FortiFitLabel("Duration (minutes)", color: FortiFitColors.primaryText)
            FortiFitInput(
                placeholder: "Optional",
                text: $viewModel.durationMinutes
            )
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
            .frame(width: 120, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var exercisesSection: some View {
        if !viewModel.exercises.isEmpty {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapMedium) {
                FortiFitWidgetHeader(title: "Exercises")

                ForEach(viewModel.exercises) { exercise in
                    exerciseCard(exerciseId: exercise.id)
                }
            }
        }
    }

    private func exerciseBinding(for id: UUID) -> Binding<EditScheduledWorkoutViewModel.EditableExercise> {
        Binding(
            get: {
                viewModel.exercises.first { $0.id == id } ??
                    EditScheduledWorkoutViewModel.EditableExercise(
                        exerciseName: "", rows: [], sortOrder: 0,
                        restSeconds: nil, displayAsTime: nil
                    )
            },
            set: { newValue in
                if let i = viewModel.exercises.firstIndex(where: { $0.id == id }) {
                    viewModel.exercises[i] = newValue
                }
            }
        )
    }

    private func rowBinding(exerciseId: UUID, rowId: UUID) -> Binding<EditScheduledWorkoutViewModel.EditableSetRow> {
        Binding(
            get: {
                let ex = viewModel.exercises.first { $0.id == exerciseId }
                return ex?.rows.first { $0.id == rowId } ??
                    EditScheduledWorkoutViewModel.EditableSetRow(sets: "", reps: "", weight: "")
            },
            set: { newValue in
                if let ei = viewModel.exercises.firstIndex(where: { $0.id == exerciseId }),
                   let ri = viewModel.exercises[ei].rows.firstIndex(where: { $0.id == rowId }) {
                    viewModel.exercises[ei].rows[ri] = newValue
                }
            }
        )
    }

    @ViewBuilder
    private func exerciseCard(exerciseId: UUID) -> some View {
        let binding = exerciseBinding(for: exerciseId)
        let exercise = binding.wrappedValue
        let index = viewModel.exercises.firstIndex(where: { $0.id == exerciseId })

        FortiFitCard(borderColor: FortiFitColors.border) {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                HStack {
                    FortiFitInput(
                        placeholder: "Exercise name",
                        text: binding.exerciseName
                    )
                    if viewModel.exercises.count > 1 {
                        Button {
                            if let idx = viewModel.exercises.firstIndex(where: { $0.id == exerciseId }) {
                                viewModel.removeExercise(at: idx)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(FortiFitColors.mutedText)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                    }
                }

                EditScheduledExerciseRestToggleRow(
                    restSeconds: binding.restSeconds,
                    displayAsTime: binding.displayAsTime,
                    exerciseName: exercise.exerciseName,
                    exerciseIndex: index ?? 0
                )

                HStack(spacing: FortiFitSpacing.elementSpacing) {
                    Text("SETS")
                        .frame(maxWidth: .infinity)
                    Text(exercise.resolvedDisplayAsTime ? "TIME" : "REPS")
                        .frame(maxWidth: .infinity)
                    Text(UserSettings.shared.useLbs ? "LBS" : "KG")
                        .frame(maxWidth: .infinity)
                    Color.clear.frame(width: 32)
                }
                .font(FortiFitTypography.label)
                .kerning(FortiFitTypography.labelKerning)
                .foregroundStyle(FortiFitColors.mutedText)

                ForEach(exercise.rows) { row in
                    EditScheduledSetRowView(
                        row: rowBinding(exerciseId: exerciseId, rowId: row.id),
                        isTimeMode: exercise.resolvedDisplayAsTime,
                        canRemove: exercise.rows.count > 1,
                        onRemove: {
                            if let idx = viewModel.exercises.firstIndex(where: { $0.id == exerciseId }) {
                                viewModel.removeRow(exerciseIndex: idx, rowId: row.id)
                            }
                        }
                    )
                }

                Button {
                    if let idx = viewModel.exercises.firstIndex(where: { $0.id == exerciseId }) {
                        viewModel.addRow(exerciseIndex: idx)
                    }
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

    @ViewBuilder
    private var addExerciseButton: some View {
        FortiFitButton("Add Exercise", style: .outline) {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            viewModel.addExercise()
        }
    }

    @State private var showWatchSyncInfoPopover = false

    @ViewBuilder
    private var watchSyncSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $viewModel.syncToAppleWatch) {
                HStack(spacing: 6) {
                    Text(AppConstants.AppleWatch.watchSyncToggleLabel)
                        .foregroundStyle(FortiFitColors.primaryText)
                    Button { showWatchSyncInfoPopover.toggle() } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(FortiFitColors.mutedText)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showWatchSyncInfoPopover) {
                        Text(AppConstants.AppleWatch.watchSyncInfoPopover)
                            .font(FortiFitTypography.bodySmall)
                            .foregroundStyle(FortiFitColors.primaryText)
                            .padding()
                            .frame(width: 280)
                            .fixedSize(horizontal: false, vertical: true)
                            .presentationCompactAdaptation(.popover)
                    }
                    .accessibilityIdentifier(AccessibilityID.editScheduledWorkout_watchSyncInfoPopover)
                }
            }
            .tint(FortiFitColors.primaryAccent)
            .accessibilityIdentifier(AccessibilityID.editScheduledWorkout_watchSyncToggle)
        }
    }

    @ViewBuilder
    private var saveButton: some View {
        FortiFitButton("Save Changes", style: .primary) {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            Task {
                await viewModel.save(context: modelContext, watchScheduleService: watchScheduleService)
                if !viewModel.showRecurrencePrompt {
                    dismiss()
                }
            }
        }
        .disabled(!viewModel.isValid)
        .accessibilityIdentifier(AccessibilityID.editScheduledWorkout_saveButton)
    }
}

// MARK: - Set Row View

struct EditScheduledSetRowView: View {
    @Binding var row: EditScheduledWorkoutViewModel.EditableSetRow
    var isTimeMode: Bool
    var canRemove: Bool
    var onRemove: () -> Void

    @State private var showTimePicker = false

    var body: some View {
        HStack(spacing: FortiFitSpacing.elementSpacing) {
            NumberFieldView(
                text: $row.sets,
                placeholder: "0"
            )

            if isTimeMode {
                Button { showTimePicker.toggle() } label: {
                    Text(DurationFormat.display(seconds: Int(row.reps)))
                        .font(FortiFitTypography.body)
                        .foregroundStyle(row.reps.isEmpty ? FortiFitColors.mutedText : FortiFitColors.primaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadiusSmall)
                                .fill(FortiFitColors.elevatedSurface)
                        )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showTimePicker) {
                    DurationPickerView(
                        seconds: Binding(
                            get: { Int(row.reps) },
                            set: { row.reps = $0.map { String($0) } ?? "" }
                        ),
                        isPresented: $showTimePicker
                    )
                    .presentationCompactAdaptation(.popover)
                }
            } else {
                NumberFieldView(
                    text: $row.reps,
                    placeholder: "0"
                )
            }

            NumberFieldView(
                text: $row.weight,
                placeholder: "BW"
            )

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

// MARK: - REST PER SET + REPS/TIME Toggle Row

struct EditScheduledExerciseRestToggleRow: View {
    @Binding var restSeconds: Int?
    @Binding var displayAsTime: Bool?
    let exerciseName: String
    let exerciseIndex: Int

    @State private var showRestPicker = false
    @State private var showInfoPopover = false

    private var resolvedDisplayAsTime: Bool {
        displayAsTime ?? ExerciseSuggestionService.isIsometric(exerciseName)
    }

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Text("REST PER SET")
                    .font(.system(size: 14, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(FortiFitColors.mutedText)

                Button { showInfoPopover.toggle() } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(FortiFitColors.mutedText)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showInfoPopover) {
                    Text(AppConstants.AppleWatch.restPerSetPopover)
                        .font(FortiFitTypography.bodySmall)
                        .foregroundStyle(FortiFitColors.primaryText)
                        .padding()
                        .frame(width: 280)
                        .fixedSize(horizontal: false, vertical: true)
                        .presentationCompactAdaptation(.popover)
                }
                .accessibilityIdentifier(AccessibilityID.exerciseCardRestPerSetInfoPopover(exerciseIndex))

                Spacer().frame(width: 4)

                Button { showRestPicker.toggle() } label: {
                    Text(DurationFormat.display(seconds: restSeconds))
                        .font(FortiFitTypography.body)
                        .foregroundStyle(restSeconds != nil ? FortiFitColors.primaryText : FortiFitColors.mutedText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadiusSmall)
                                .fill(FortiFitColors.elevatedSurface)
                        )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showRestPicker) {
                    DurationPickerView(seconds: $restSeconds, isPresented: $showRestPicker)
                        .presentationCompactAdaptation(.popover)
                }
                .accessibilityIdentifier(AccessibilityID.exerciseCardRestPerSetField(exerciseIndex))
            }

            Spacer()

            Picker("", selection: Binding(
                get: { resolvedDisplayAsTime },
                set: { displayAsTime = $0 }
            )) {
                Text("REPS").tag(false)
                Text("TIME").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            .onAppear {
                UISegmentedControl.appearance().setTitleTextAttributes(
                    [.font: UIFont.boldSystemFont(ofSize: 14)], for: .normal
                )
            }
            .accessibilityIdentifier(AccessibilityID.exerciseCardRepsTimeToggle(exerciseIndex))
        }
    }
}
