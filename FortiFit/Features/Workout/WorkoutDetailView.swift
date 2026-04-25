import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let workout: Workout
    @Bindable var viewModel: WorkoutViewModel
    @State private var isEditingNote = false
    @State private var noteText = ""
    @State private var showDeleteAlert = false
    @State private var showEditWorkout = false
    @State private var showSaveAsTemplatePrompt = false
    @State private var saveAsTemplateName = ""
    @State private var showTemplateSavedToast = false
    @State private var showShowOnPlanToast = false
    @State private var headerHeight: CGFloat = 0

    private var settings: UserSettings { UserSettings.shared }

    var body: some View {
        ZStack {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: FortiFitSpacing.gapLarge) {
                    // Title
                    FortiFitLabel("Workout")
                    FortiFitScreenHeading(workout.name)
                    Text("\(workout.date.shortFormatted)\(workout.time != nil ? " · \(workout.time!.timeFormatted)" : "") · \(workout.workoutType)")
                        .font(FortiFitTypography.bodySmall)
                        .foregroundStyle(FortiFitColors.mutedText)

                    FortiFitDivider()

                    // Content based on workout type
                    if workout.workoutType == "Strength Training" || workout.workoutType == "HIIT" {
                        strengthDetailSection
                    } else if workout.workoutType == "Cardio" || workout.workoutType == "Sprints" {
                        cardioDetailSection
                    } else {
                        yogaDetailSection
                    }

                    FortiFitDivider()

                    // Session Notes
                    notesSection
                }
                .padding(.horizontal, FortiFitSpacing.screenHorizontal)
                .padding(.top, headerHeight)
                .padding(.bottom, FortiFitSpacing.gapXLarge)
            }
            .scrollClipDisabled()

            // Fixed header
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: FortiFitSpacing.gapLarge) {
                    HStack {
                        FortiFitBackButton { dismiss() }
                        Spacer()
                        FortiFitActionButtonGroup(
                            onShare: {
                                #if os(iOS)
                                viewModel.exportWorkout(workout)
                                #endif
                            },
                            onEdit: {
                                viewModel.populateForm(from: workout)
                                showEditWorkout = true
                            },
                            onDelete: {
                                showDeleteAlert = true
                            }
                        )
                        if workout.workoutType == "Strength Training" || workout.workoutType == "HIIT" || workout.hiddenFromPlan {
                            Menu {
                                if workout.workoutType == "Strength Training" || workout.workoutType == "HIIT" {
                                    Button {
                                        saveAsTemplateName = workout.name
                                        showSaveAsTemplatePrompt = true
                                    } label: {
                                        Label("Save As Template", systemImage: "square.and.arrow.down")
                                    }
                                    .accessibilityIdentifier(AccessibilityID.saveAsTemplateMenuItem)
                                }
                                if workout.hiddenFromPlan {
                                    Button {
                                        PlanService.setHiddenFromPlan(workout: workout, hidden: false, context: modelContext)
                                        withAnimation {
                                            showShowOnPlanToast = true
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            withAnimation {
                                                showShowOnPlanToast = false
                                            }
                                        }
                                    } label: {
                                        Label("Show on Plan", systemImage: "calendar.badge.plus")
                                    }
                                    .accessibilityIdentifier(AccessibilityID.workoutDetailShowOnPlanMenuItem)
                                }
                            } label: {
                                FortiFitEllipsisButton()
                            }
                            .accessibilityIdentifier(AccessibilityID.workoutDetailEllipsis)
                        }
                    }
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
        .background(FortiFitColors.background)

            // Share error toast
            if viewModel.showShareError {
                VStack {
                    Text("Couldn't generate image. Try again.")
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

            // "Showing on Plan." toast
            VStack {
                Text("Showing on Plan")
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
            .opacity(showShowOnPlanToast ? 1 : 0)
            .offset(y: showShowOnPlanToast ? 0 : -60)
            .allowsHitTesting(showShowOnPlanToast)
            .animation(.easeInOut(duration: 0.2), value: showShowOnPlanToast)

            // "Template saved!" toast
            if showTemplateSavedToast {
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
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .onAppear {
            noteText = workout.note ?? ""
        }
        .alert(
            "Delete \(workout.name)?",
            isPresented: $showDeleteAlert
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteWorkout(workout, context: modelContext)
                dismiss()
            }
        } message: {
            Text("This can't be undone.")
        }
        .alert("Name Template", isPresented: $showSaveAsTemplatePrompt) {
            TextField("Template name", text: $saveAsTemplateName)
            Button("Cancel", role: .cancel) {
                saveAsTemplateName = ""
            }
            Button("Save") {
                viewModel.saveWorkoutAsTemplate(
                    name: saveAsTemplateName,
                    workout: workout,
                    context: modelContext
                )
                saveAsTemplateName = ""
                withAnimation {
                    showTemplateSavedToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showTemplateSavedToast = false
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityID.saveTemplateConfirmButton)
        } message: {
            Text("Enter a name for this template.")
        }
        .navigationDestination(isPresented: $showEditWorkout) {
            LogWorkoutView(viewModel: viewModel) {
                dismiss()
            }
            .onDisappear {
                viewModel.loadWorkouts(context: modelContext)
            }
        }
        #if os(iOS)
        .sheet(isPresented: Binding(
            get: { viewModel.shareImage != nil },
            set: { if !$0 { viewModel.shareImage = nil } }
        )) {
            if let image = viewModel.shareImage {
                ShareSheet(activityItems: [image])
            }
        }
        #endif
        .onChange(of: viewModel.showShareError) { _, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        viewModel.showShareError = false
                    }
                }
            }
        }
    }

    // MARK: - Strength Detail

    private var strengthDetailSection: some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
            if workout.rpe != nil || workout.durationMinutes != nil {
                FortiFitWidgetHeader(title: "Summary")

                FortiFitCard(borderColor: FortiFitColors.border) {
                    VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                        if let rpe = workout.rpe {
                            summaryRow(field: "RPE", value: "\(rpe)")
                        }
                        if let duration = workout.durationMinutes {
                            summaryRow(field: "Duration", value: "\(duration) min")
                        }
                    }
                }
            }

            FortiFitWidgetHeader(title: "Exercises")

            let grouped = Dictionary(grouping: workout.exerciseSets.sorted { $0.sortOrder < $1.sortOrder }, by: { $0.exerciseName })
            let sortedNames = grouped.keys.sorted { name1, name2 in
                let order1 = grouped[name1]?.first?.sortOrder ?? 0
                let order2 = grouped[name2]?.first?.sortOrder ?? 0
                return order1 < order2
            }

            ForEach(sortedNames, id: \.self) { exerciseName in
                if let sets = grouped[exerciseName] {
                    FortiFitCard(borderColor: FortiFitColors.border) {
                        VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                            Text(exerciseName)
                                .font(FortiFitTypography.dataValue)
                                .foregroundStyle(FortiFitColors.primaryText)

                            ForEach(sets) { exerciseSet in
                                HStack {
                                    Text("\(exerciseSet.sets) sets × \(exerciseSet.reps) reps")
                                        .font(FortiFitTypography.bodySmall)
                                        .foregroundStyle(FortiFitColors.secondaryText)
                                    Spacer()
                                    Text(UnitConversion.displayWeight(exerciseSet.weightKg, useLbs: settings.useLbs))
                                        .font(FortiFitTypography.dataValue)
                                        .foregroundStyle(FortiFitColors.primaryAccent)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Cardio Detail

    private var cardioDetailSection: some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
            FortiFitWidgetHeader(title: "Summary")

            FortiFitCard(borderColor: FortiFitColors.border) {
                VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                    if let rpe = workout.rpe {
                        summaryRow(field: "RPE", value: "\(rpe)")
                    }
                    if let duration = workout.durationMinutes {
                        summaryRow(field: "Duration", value: "\(duration) min")
                    }
                    if let distance = workout.distanceKm {
                        summaryRow(field: "Distance", value: UnitConversion.displayDistance(distance, useMiles: settings.useMiles))
                    }
                    if workout.rpe == nil && workout.durationMinutes == nil && workout.distanceKm == nil {
                        Text(workout.workoutType)
                            .font(FortiFitTypography.bodySmall)
                            .foregroundStyle(FortiFitColors.secondaryText)
                    }
                }
            }
        }
    }

    // MARK: - Yoga Detail

    private var yogaDetailSection: some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
            FortiFitWidgetHeader(title: "Summary")

            FortiFitCard(borderColor: FortiFitColors.border) {
                VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                    if let rpe = workout.rpe {
                        summaryRow(field: "RPE", value: "\(rpe)")
                    }
                    if let duration = workout.durationMinutes {
                        summaryRow(field: "Duration", value: "\(duration) min")
                    }
                    if workout.rpe == nil && workout.durationMinutes == nil {
                        Text(workout.workoutType)
                            .font(FortiFitTypography.bodySmall)
                            .foregroundStyle(FortiFitColors.secondaryText)
                    }
                }
            }
        }
    }

    // MARK: - Summary Row

    private func summaryRow(field: String, value: String) -> some View {
        HStack {
            if let symbolName = AppConstants.summaryFieldSymbols[field] {
                Image(systemName: symbolName)
                    .font(FortiFitTypography.body)
                    .foregroundStyle(FortiFitColors.primaryText)
            }
            Text(field)
                .font(FortiFitTypography.body)
                .foregroundStyle(FortiFitColors.primaryText)
            Spacer()
            Text(value)
                .font(FortiFitTypography.dataValue)
                .foregroundStyle(FortiFitColors.primaryAccent)
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
            HStack {
                FortiFitWidgetHeader(title: "Session Notes")
                Spacer()
                Button {
                    isEditingNote.toggle()
                } label: {
                    Image(systemName: isEditingNote ? "checkmark.circle.fill" : "pencil")
                        .font(.system(size: 16))
                        .foregroundStyle(FortiFitColors.primaryAccent)
                        .frame(width: FortiFitSpacing.minTouchTarget, height: FortiFitSpacing.minTouchTarget)
                }
            }

            if isEditingNote {
                TextEditor(text: $noteText)
                    .font(FortiFitTypography.body)
                    .foregroundStyle(FortiFitColors.primaryText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100)
                    .padding(FortiFitSpacing.cardPadding)
                    .background(FortiFitColors.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadiusSmall))
                    .tint(FortiFitColors.primaryAccent)

                FortiFitButton("Save Notes", style: .primary) {
                    viewModel.updateNote(workout, note: noteText.isEmpty ? nil : noteText, context: modelContext)
                    isEditingNote = false
                }
            } else {
                FortiFitCard(borderColor: FortiFitColors.border) {
                    Text(noteText.isEmpty ? "No notes for this session." : noteText)
                        .font(noteText.isEmpty ? FortiFitTypography.note : FortiFitTypography.body)
                        .foregroundStyle(noteText.isEmpty ? FortiFitColors.mutedText : FortiFitColors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

#Preview {
    let workout = Workout(name: "Push Day I", workoutType: "Strength Training", rpe: 8)
    NavigationStack {
        WorkoutDetailView(workout: workout, viewModel: WorkoutViewModel())
    }
}
