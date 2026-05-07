import SwiftUI
import SwiftData

struct PlanView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = PlanViewModel()
    @State private var workoutVM = WorkoutViewModel()
    @State private var calendarModeString = "Week"
    @State private var showSavedTemplates = false
    @State private var headerHeight: CGFloat = 0
    var selectedTab: Int = 2

    var body: some View {
        NavigationStack {
            planContentWithAlerts
        }
    }

    // MARK: - Content Layers (split to help the compiler)

    private var planContentWithAlerts: some View {
        planContentWithSheets
            .alert("Date Selection", isPresented: $viewModel.showDateResolutionPrompt) {
                dateResolutionAlertButtons
            } message: {
                dateResolutionAlertMessage
            }
            .alert(
                removeAlertTitle,
                isPresented: $viewModel.showRemoveConfirmation
            ) {
                Button("Cancel", role: .cancel) { viewModel.itemToRemove = nil }
                Button("Remove", role: removeButtonRole) {
                    viewModel.executeRemoveFromPlan(context: modelContext)
                }
            } message: {
                Text(removeConfirmationBody)
            }
            .confirmationDialog(
                "This is a recurring workout",
                isPresented: $viewModel.showRecurringRemovePrompt
            ) {
                Button("This Workout Only") {
                    viewModel.proceedWithRemoveAfterScopeSelection(scope: .thisOnly)
                }
                Button("This & Future Workouts") {
                    viewModel.proceedWithRemoveAfterScopeSelection(scope: .thisAndFuture)
                }
                Button("Cancel", role: .cancel) {
                    viewModel.itemToRemove = nil
                }
            }
            .navigationDestination(isPresented: $showSavedTemplates) {
                SavedTemplatesListView()
            }
            .navigationDestination(isPresented: $workoutVM.showLogWorkout) {
                LogWorkoutView(viewModel: workoutVM)
                    .onDisappear {
                        viewModel.loadWorkoutsForCurrentView(context: modelContext)
                    }
            }
            .navigationDestination(isPresented: $viewModel.showWorkoutDetail) {
                if let workout = viewModel.selectedWorkoutForDetail {
                    WorkoutDetailView(workout: workout, viewModel: workoutVM)
                        .onDisappear {
                            viewModel.loadWorkoutsForCurrentView(context: modelContext)
                        }
                }
            }
    }

    private var planContentWithSheets: some View {
        planZStack
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .onAppear {
                viewModel.resetToToday()
                viewModel.loadWorkoutsForCurrentView(context: modelContext)
            }
            .onChange(of: selectedTab) { oldValue, _ in
                guard oldValue == 2 else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        showSavedTemplates = false
                        workoutVM.showLogWorkout = false
                        viewModel.showWorkoutDetail = false
                        viewModel.selectedWorkoutForDetail = nil
                        viewModel.showScheduleSheet = false
                        viewModel.showCompletionSheet = false
                        viewModel.showDateResolutionPrompt = false
                        viewModel.showRemoveConfirmation = false
                        viewModel.showRecurringRemovePrompt = false
                        viewModel.showCompletedToast = false
                        viewModel.showRemovedFromPlanToast = false
                        viewModel.itemToRemove = nil
                    }
                }
            }
            .onChange(of: viewModel.dayOffset) { _, _ in
                viewModel.loadWorkoutsForCurrentView(context: modelContext)
            }
            .onChange(of: viewModel.displayedMonth) { _, _ in
                viewModel.loadWorkoutsForCurrentView(context: modelContext)
            }
            .onChange(of: viewModel.calendarMode) { _, _ in
                viewModel.loadWorkoutsForCurrentView(context: modelContext)
            }
            .onChange(of: viewModel.selectedDate) { _, _ in
                viewModel.updateSelectedDayItems(context: modelContext)
            }
            .onChange(of: calendarModeString) { _, newValue in
                viewModel.calendarMode = newValue == "Month" ? .month : .week
            }
            .sheet(isPresented: $viewModel.showScheduleSheet) {
                ScheduleWorkoutView(
                    preSelectedDate: viewModel.selectedDate,
                    preSelectedTemplate: viewModel.preSelectedTemplate,
                    onSchedule: { template, date, time, recurrence in
                        viewModel.scheduleWorkout(
                            template: template,
                            date: date,
                            time: time,
                            recurrenceRule: recurrence,
                            context: modelContext
                        )
                    }
                )
            }
            .sheet(isPresented: $viewModel.showCompletionSheet) {
                CompletePlanView(
                    scheduledWorkout: viewModel.activeScheduledWorkout,
                    completionRPE: $viewModel.completionRPE,
                    completionDuration: $viewModel.completionDuration,
                    onSave: {
                        viewModel.completeWorkout(context: modelContext)
                    },
                    onModifyExercises: {
                        viewModel.showCompletionSheet = false
                        if let scheduled = viewModel.activeScheduledWorkout {
                            prepareLogWorkoutFromScheduled(scheduled)
                        }
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationBackground(FortiFitColors.cardSurface)
            }
    }

    private var planZStack: some View {
        ZStack {
            ZStack(alignment: .top) {
                if viewModel.showEmptyState {
                    VStack {
                        Spacer()
                        Text("Schedule your first workout to start planning")
                            .font(FortiFitTypography.body)
                            .foregroundStyle(FortiFitColors.mutedText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, FortiFitSpacing.screenHorizontal)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: FortiFitSpacing.gapMedium) {
                            FortiFitSegmentedToggle(
                                options: ["Week", "Month"],
                                selected: $calendarModeString
                            )

                            switch viewModel.calendarMode {
                            case .week:
                                FortiFitWeekStrip(
                                    selectedDate: $viewModel.selectedDate,
                                    dayOffset: $viewModel.dayOffset,
                                    planItems: viewModel.planItemsForView
                                )
                            case .month:
                                FortiFitMonthGrid(
                                    selectedDate: $viewModel.selectedDate,
                                    displayedMonth: $viewModel.displayedMonth,
                                    planItems: viewModel.planItemsForView
                                )
                            }

                            dayDetailSection
                        }
                        .padding(.horizontal, FortiFitSpacing.screenHorizontal)
                        .padding(.top, headerHeight)
                        .padding(.bottom, FortiFitSpacing.gapXLarge)
                    }
                    .scrollClipDisabled()
                }

                FortiFitFixedHeader(headerHeight: $headerHeight) {
                    HStack {
                        FortiFitEllipsisButton(menuItems: [
                            (label: "Saved Templates", systemImage: "doc.on.doc", identifier: AccessibilityID.planSavedTemplatesMenuItem, action: {
                                showSavedTemplates = true
                            })
                        ])
                        .accessibilityIdentifier(AccessibilityID.planEllipsisMenu)
                        Spacer()
                        Button {
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            viewModel.openScheduleSheet()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16))
                                .foregroundStyle(FortiFitColors.primaryAccent)
                                .frame(height: FortiFitSpacing.minTouchTarget)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                                        .fill(.clear)
                                        .stroke(FortiFitColors.primaryAccent, lineWidth: 1)
                                )
                        }
                        .accessibilityIdentifier(AccessibilityID.planAddButton)
                    }
                }
            }
            .background(FortiFitColors.background)

            // Toast
            if viewModel.showCompletedToast {
                VStack {
                    Text("Workout completed.")
                        .font(FortiFitTypography.bodySmall)
                        .foregroundStyle(.white)
                        .padding(.horizontal, FortiFitSpacing.cardPadding)
                        .padding(.vertical, FortiFitSpacing.elementSpacing)
                        .background(Capsule().fill(FortiFitColors.primaryAccent))
                        .padding(.top, FortiFitSpacing.screenTop)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(false)
            }

            // Undo toast for Remove from Plan
            VStack {
                HStack(spacing: FortiFitSpacing.elementSpacing) {
                    Text("Removed from Plan")
                        .font(FortiFitTypography.bodySmall)
                        .foregroundStyle(.white)
                    Button("Undo") {
                        viewModel.undoRemoveFromPlan(context: modelContext)
                    }
                    .font(FortiFitTypography.bodySmall.weight(.semibold))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier(AccessibilityID.planRemoveUndoToastAction)
                }
                .padding(.horizontal, FortiFitSpacing.cardPadding)
                .padding(.vertical, FortiFitSpacing.elementSpacing)
                .background(Capsule().fill(FortiFitColors.primaryAccent))
                .padding(.top, FortiFitSpacing.screenTop)
                Spacer()
            }
            .opacity(viewModel.showRemovedFromPlanToast ? 1 : 0)
            .offset(y: viewModel.showRemovedFromPlanToast ? 0 : -60)
            .allowsHitTesting(viewModel.showRemovedFromPlanToast)
            .animation(.easeInOut(duration: 0.2), value: viewModel.showRemovedFromPlanToast)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showCompletedToast)
    }

    // MARK: - Alert Helpers

    private var removeAlertTitle: String {
        guard let item = viewModel.itemToRemove else { return "Remove from Plan?" }
        return "Remove \(viewModel.nameForItem(item)) from Plan?"
    }

    private var removeButtonRole: ButtonRole? {
        guard let item = viewModel.itemToRemove else { return .destructive }
        return viewModel.isDestructiveRemoval(item) ? .destructive : nil
    }

    private var removeConfirmationBody: String {
        guard let item = viewModel.itemToRemove else { return "" }
        return viewModel.removeConfirmationMessage(item)
    }

    // MARK: - Day Detail

    @ViewBuilder
    private var dayDetailSection: some View {
        if viewModel.selectedDayItems.isEmpty {
            EmptyView()
        } else {
            ForEach(Array(viewModel.selectedDayItems.enumerated()), id: \.element.id) { index, item in
                switch item {
                case .scheduled(let scheduledWorkout):
                    FortiFitScheduledWorkoutCard(
                        scheduledWorkout: scheduledWorkout,
                        onComplete: { viewModel.initiateCompletion(scheduledWorkout: scheduledWorkout) },
                        onSkip: { viewModel.skipWorkout(scheduledWorkout, context: modelContext) },
                        onRestore: { viewModel.restoreWorkout(scheduledWorkout, context: modelContext) },
                        onRemoveFromPlan: { viewModel.confirmRemoveFromPlan(item) },
                        isCompletedHealthKitLinked: isCompletedWorkoutHealthKitLinked(scheduledWorkout),
                        onTap: scheduledWorkout.status == "completed" ? {
                            navigateToWorkoutDetail(completedWorkoutId: scheduledWorkout.completedWorkoutId)
                        } : nil
                    )
                    .accessibilityIdentifier(AccessibilityID.scheduledWorkoutCard(index))

                case .loggedOnly(let workout):
                    FortiFitLoggedWorkoutCard(
                        workout: workout,
                        onRemoveFromPlan: { viewModel.confirmRemoveFromPlan(item) },
                        onTap: {
                            viewModel.selectedWorkoutForDetail = workout
                            viewModel.showWorkoutDetail = true
                        }
                    )
                    .accessibilityIdentifier(AccessibilityID.planLoggedOnlyCard(index))
                }
            }
        }
    }

    // MARK: - Date Resolution Alert

    @ViewBuilder
    private var dateResolutionAlertButtons: some View {
        if case .pastDate = viewModel.dateResolution {
            Button("Scheduled Date") { viewModel.resolveWithScheduledDate() }
            Button("Today") { viewModel.resolveWithToday() }
            Button("Cancel", role: .cancel) { viewModel.cancelDateResolution() }
        } else {
            Button("Log for Today") { viewModel.resolveWithToday() }
            Button("Cancel", role: .cancel) { viewModel.cancelDateResolution() }
        }
    }

    @ViewBuilder
    private var dateResolutionAlertMessage: some View {
        switch viewModel.dateResolution {
        case .pastDate(let scheduled):
            Text("This workout was planned for \(scheduled.shortFormatted). Log for \(scheduled.shortFormatted) or today?")
        case .futureDate(let scheduled):
            Text("This workout is planned for \(scheduled.shortFormatted). Log for today instead?")
        default:
            Text("")
        }
    }

    // MARK: - HealthKit Helpers

    private func isCompletedWorkoutHealthKitLinked(_ scheduledWorkout: ScheduledWorkout) -> Bool {
        guard scheduledWorkout.status == "completed",
              let workoutId = scheduledWorkout.completedWorkoutId else { return false }
        let predicate = #Predicate<Workout> { w in w.id == workoutId }
        var descriptor = FetchDescriptor<Workout>(predicate: predicate)
        descriptor.fetchLimit = 1
        guard let workout = try? modelContext.fetch(descriptor).first else { return false }
        return workout.isHealthKitLinked
    }

    // MARK: - Navigation Helpers

    private func navigateToWorkoutDetail(completedWorkoutId: UUID?) {
        guard let workoutId = completedWorkoutId else { return }
        let predicate = #Predicate<Workout> { w in w.id == workoutId }
        let descriptor = FetchDescriptor<Workout>(predicate: predicate)
        if let workout = try? modelContext.fetch(descriptor).first {
            viewModel.selectedWorkoutForDetail = workout
            viewModel.showWorkoutDetail = true
        }
    }

    // MARK: - Helpers

    private func prepareLogWorkoutFromScheduled(_ scheduled: ScheduledWorkout) {
        workoutVM.resetForm()
        workoutVM.workoutName = scheduled.workoutName
        workoutVM.workoutType = scheduled.workoutType
        workoutVM.durationMinutes = scheduled.durationMinutes.map { String($0) } ?? ""
        workoutVM.workoutDate = viewModel.resolvedDate
        workoutVM.selectedRPE = nil
        workoutVM.scheduledWorkoutId = scheduled.id

        if let snapshotData = scheduled.templateSnapshot {
            let exercises = PlanService.decodeSnapshot(data: snapshotData)
            let settings = UserSettings.shared
            var seen = Set<String>()
            var uniqueNames: [String] = []
            let sorted = exercises.sorted { $0.sortOrder < $1.sortOrder }
            for ex in sorted {
                if seen.insert(ex.exerciseName).inserted { uniqueNames.append(ex.exerciseName) }
            }
            let grouped = Dictionary(grouping: sorted, by: { $0.exerciseName })

            if uniqueNames.isEmpty {
                workoutVM.exercises = [ExerciseFormEntry()]
            } else {
                workoutVM.exercises = uniqueNames.map { name in
                    let entry = ExerciseFormEntry()
                    entry.name = name
                    if let rows = grouped[name] {
                        entry.rows = rows.map { ex in
                            let row = SetRow()
                            row.sets = String(ex.sets)
                            row.reps = String(ex.reps)
                            if let weightKg = ex.weightKg {
                                if settings.useLbs {
                                    if let lbs = UnitConversion.kgToLbs(weightKg) {
                                        row.weight = String(Int(round(lbs)))
                                    }
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

        workoutVM.showLogWorkout = true
    }
}
