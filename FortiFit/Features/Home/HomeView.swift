import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = HomeViewModel()
    @State private var workoutVM = WorkoutViewModel()
    @State private var showSettings = false
    @State private var seeInfoWidgetType: String?
    @State private var showTrainingLoadSettings = false
    @State private var showStreakSettings = false
    @State private var showActivityRingsSettings = false
    @State private var showActivityDetailSheet = false
    @State private var settings = UserSettings.shared
    @Environment(AppleActivityService.self) private var activityService
    @Environment(RecoveryStatusService.self) private var recoveryService
    @State private var showRecoveryStatusSettings = false
    @State private var showLinkedRecoveryLoadSettings = false

    // Phase 11 — Composite rendering helpers
    private var isLinkedActive: Bool {
        HomeWidgetService.isLinkedActive(widgets: viewModel.activeWidgets, settings: settings)
    }

    /// Returns the index of the FIRST card of the linked pair (lowest sortOrder),
    /// or nil if not linked. The second card's render is skipped because the
    /// composite renders both inside itself.
    private var linkedPairFirstIndex: Int? {
        guard isLinkedActive else { return nil }
        guard let rsIdx = viewModel.activeWidgets.firstIndex(where: { $0.widgetType == "recoveryStatus" }),
              let tlIdx = viewModel.activeWidgets.firstIndex(where: { $0.widgetType == "trainingLoad" })
        else { return nil }
        return min(rsIdx, tlIdx)
    }

    private var linkedPairSecondIndex: Int? {
        guard isLinkedActive else { return nil }
        guard let rsIdx = viewModel.activeWidgets.firstIndex(where: { $0.widgetType == "recoveryStatus" }),
              let tlIdx = viewModel.activeWidgets.firstIndex(where: { $0.widgetType == "trainingLoad" })
        else { return nil }
        return max(rsIdx, tlIdx)
    }
    @State private var headerHeight: CGFloat = 0
    var selectedTab: Int = 0

    // Today's Plan completion
    @State private var showPlanCompletion = false
    @State private var planCompletionRPE: Int? = nil
    @State private var planCompletionDuration: String = ""

    // Phase 8.8 — Widget Detail Sheets
    @State private var presentedDetailSheet: WidgetDetailRoute?

    private var loadColor: Color {
        Color(hex: linkedAwareLoadResult.zoneColor)
    }

    /// BUG-064 — Training Load widget bar must reflect the sleep-adjusted score when
    /// linked, matching the linked detail sheet and the persisted `DailyTrainingLoadSnapshot`.
    /// When unlinked, falls back to the sleep-blind `viewModel.loadResult` (correct
    /// unlinked behavior). Recomputes on every render so it stays current with sleep
    /// observer updates and linking-state changes without an explicit refresh hook.
    private var linkedAwareLoadResult: ExerciseLoadService.LoadResult {
        guard isLinkedActive else { return viewModel.loadResult }
        let cutoff = Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date()
        let workouts = WorkoutService.fetchWorkouts(from: cutoff, to: Date(), context: modelContext)
        return ExerciseLoadService.computeCurrentScore(
            workouts: workouts,
            sleepSnapshotsByDay: recoveryService.cachedSnapshotsByDay(),
            targetSleepHours: settings.targetSleepHours,
            experienceLevel: settings.experienceLevel,
            targetMinutesPerWorkout: settings.targetMinutesPerWorkout
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ZStack(alignment: .top) {
                    // ScrollView (fills full area, content padded below header)
                    ScrollView {
                        VStack(spacing: FortiFitSpacing.gapMedium) {
                            // Dynamic Widget Area
                            if viewModel.activeWidgets.isEmpty {
                                Text("Tap the menu to add widgets to your Home screen.")
                                    .font(FortiFitTypography.note)
                                    .foregroundStyle(FortiFitColors.mutedText)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, FortiFitSpacing.gapXLarge)
                            } else {
                                ForEach(Array(viewModel.activeWidgets.enumerated()), id: \.element.id) { index, widget in
                                    if let firstIdx = linkedPairFirstIndex, index == firstIdx {
                                        linkedCompositeView
                                    } else if let secondIdx = linkedPairSecondIndex, index == secondIdx {
                                        EmptyView() // Skipped — rendered inside the composite above.
                                    } else {
                                        widgetCard(for: widget)
                                    }
                                }
                                .animation(.easeInOut(duration: 0.2), value: viewModel.activeWidgets.map(\.widgetType))
                                .animation(.easeInOut(duration: 0.2), value: isLinkedActive)
                            }

                            // Log Workout CTA
                            FortiFitDivider()

                            FortiFitButton("Log Workout", style: .outline) {
                                #if os(iOS)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                #endif
                                workoutVM.resetForm()
                                workoutVM.showLogWorkout = true
                            }
                            .accessibilityIdentifier(AccessibilityID.logWorkoutCTA)

                            // Recent Workouts
                            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                                FortiFitWidgetHeader(title: "Recent Workouts")

                                if viewModel.recentWorkouts.isEmpty {
                                    Text("Log your first workout to see it here.")
                                        .font(FortiFitTypography.bodySmall)
                                        .foregroundStyle(FortiFitColors.mutedText)
                                } else {
                                    ForEach(viewModel.recentWorkouts) { workout in
                                        Button {
                                            workoutVM.selectedWorkout = workout
                                        } label: {
                                            recentWorkoutRow(workout)
                                        }

                                        if workout.id != viewModel.recentWorkouts.last?.id {
                                            Divider()
                                                .background(FortiFitColors.border)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, FortiFitSpacing.screenHorizontal)
                        .padding(.top, headerHeight)
                        .padding(.bottom, FortiFitSpacing.gapXLarge)
                    }
                    .scrollClipDisabled()
                    .onTapGesture {
                        if viewModel.isEditMode {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.isEditMode = false
                            }
                        }
                    }

                    // Header (floats on top of scroll content)
                    FortiFitFixedHeader(headerHeight: $headerHeight) {
                        HStack {
                            FortiFitEllipsisButton(menuItems: [
                                (label: "Add Widgets", systemImage: "plus.rectangle.on.rectangle", identifier: AccessibilityID.addWidgetsMenuItem, action: {
                                    viewModel.showAddWidgetMenu = true
                                })
                            ])
                            .accessibilityIdentifier(AccessibilityID.homeEllipsisMenu)
                            Spacer()
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(FortiFitColors.primaryAccent)
                                    .frame(
                                        width: FortiFitSpacing.minTouchTarget,
                                        height: FortiFitSpacing.minTouchTarget
                                    )
                            }
                            .accessibilityIdentifier(AccessibilityID.settingsGearIcon)
                        }
                    }
                }
                .background(FortiFitColors.background)

                // Add Widget Menu Overlay
                if viewModel.showAddWidgetMenu {
                    FortiFitAddWidgetMenu(
                        isPresented: $viewModel.showAddWidgetMenu,
                        activeWidgetTypes: viewModel.activeWidgetTypes,
                        onAdd: { widgetType in
                            viewModel.addWidget(widgetType: widgetType, context: modelContext)
                            if widgetType == "appleActivity" {
                                let settings = UserSettings.shared
                                if settings.targetMoveCalories == nil || settings.targetExerciseMinutes == nil || settings.targetStandHours == nil {
                                    Task {
                                        await activityService.importGoalsFromAppleHealth()
                                        activityService.refresh()
                                        activityService.refreshWorkoutContributions(context: modelContext)
                                    }
                                }
                            }
                        }
                    )
                    .transition(.opacity)
                }

                // Training Load Settings Modal
                if showTrainingLoadSettings {
                    trainingLoadSettingsModal
                        .transition(.opacity)
                }

                // Weekly Streak Settings Modal
                if showStreakSettings {
                    streakSettingsModal
                        .transition(.opacity)
                }

                // Activity Rings Settings Modal
                if showActivityRingsSettings {
                    ActivityRingsSettingsModal(
                        activityService: activityService,
                        onDismiss: { dismissActivityRingsSettings() }
                    )
                    .transition(.opacity)
                }

                // Recovery Status Settings Modal (Phase 11)
                if showRecoveryStatusSettings {
                    FortiFitRecoveryStatusSettingsModal(
                        onDismiss: {
                            showRecoveryStatusSettings = false
                        },
                        onImportFromAppleHealth: {
                            await recoveryService.importSleepGoalFromAppleHealth()
                        }
                    )
                    .transition(.opacity)
                }

                // Linked Recovery & Load Settings Modal (Phase 11)
                if showLinkedRecoveryLoadSettings {
                    FortiFitLinkedRecoveryLoadSettingsModal(
                        onDismiss: {
                            showLinkedRecoveryLoadSettings = false
                            viewModel.loadData(context: modelContext)
                        },
                        onImportFromAppleHealth: {
                            await recoveryService.importSleepGoalFromAppleHealth()
                        }
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.showAddWidgetMenu)
            .animation(.easeInOut(duration: 0.2), value: showTrainingLoadSettings)
            .animation(.easeInOut(duration: 0.2), value: showStreakSettings)
            .animation(.easeInOut(duration: 0.2), value: showActivityRingsSettings)
            .animation(.easeInOut(duration: 0.2), value: showRecoveryStatusSettings)
            .animation(.easeInOut(duration: 0.2), value: showLinkedRecoveryLoadSettings)
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .onAppear {
                viewModel.loadData(context: modelContext)
                activityService.refreshWorkoutContributions(context: modelContext)
                recoveryService.isLinkedActive = isLinkedActive
                recoveryService.refreshTimerLine(context: modelContext)
            }
            // BUG-062 — per SERVICES.md § RecoveryStatusService → Derived State,
            // the SINCE LAST WORKOUT hero value must refresh on foreground entry and
            // every 60s while the Home tab is visible. Without these, the value
            // freezes at whatever the Workout Cascade last set it to (e.g. "0 min"
            // immediately after logging).
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 60_000_000_000)
                    if Task.isCancelled { break }
                    recoveryService.refreshTimerLine(context: modelContext)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    recoveryService.refreshTimerLine(context: modelContext)
                }
            }
            .onChange(of: viewModel.activeWidgets.map(\.widgetType)) { _, _ in
                recoveryService.isLinkedActive = isLinkedActive
            }
            .onChange(of: settings.recoveryLoadManuallyUnlinked) { _, _ in
                recoveryService.isLinkedActive = isLinkedActive
            }
            .onChange(of: recoveryService.currentGatingState) { _, _ in
                recoveryService.isLinkedActive = isLinkedActive
            }
            .onDisappear { viewModel.isEditMode = false }
            .onChange(of: selectedTab) { oldValue, _ in
                guard oldValue == 0 else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        showSettings = false
                        workoutVM.showLogWorkout = false
                        workoutVM.selectedWorkout = nil
                        showPlanCompletion = false
                        viewModel.showAddWidgetMenu = false
                        viewModel.isEditMode = false
                        showTrainingLoadSettings = false
                        showStreakSettings = false
                        showActivityRingsSettings = false
                        showActivityDetailSheet = false
                        showRecoveryStatusSettings = false
                        showLinkedRecoveryLoadSettings = false
                        presentedDetailSheet = nil
                    }
                }
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
                    .onDisappear { viewModel.loadData(context: modelContext) }
            }
            .navigationDestination(isPresented: $workoutVM.showLogWorkout) {
                LogWorkoutView(viewModel: workoutVM)
                    .onDisappear { viewModel.loadData(context: modelContext) }
            }
            .navigationDestination(item: $workoutVM.selectedWorkout) { workout in
                WorkoutDetailView(workout: workout, viewModel: workoutVM)
                    .onDisappear { viewModel.loadData(context: modelContext) }
            }
            .sheet(isPresented: $showPlanCompletion) {
                CompletePlanView(
                    scheduledWorkout: viewModel.currentPlannedWorkout,
                    completionRPE: $planCompletionRPE,
                    completionDuration: $planCompletionDuration,
                    onSave: {
                        guard let sw = viewModel.currentPlannedWorkout else { return }
                        let durationMin = Int(planCompletionDuration)
                        PlanService.completeWorkout(
                            scheduledWorkout: sw,
                            date: Date(),
                            rpe: planCompletionRPE,
                            durationMinutes: durationMin,
                            context: modelContext
                        )
                        showPlanCompletion = false
                        viewModel.loadData(context: modelContext)
                    },
                    onModifyExercises: {
                        showPlanCompletion = false
                        if let scheduled = viewModel.currentPlannedWorkout {
                            prepareLogWorkoutFromScheduled(scheduled)
                        }
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(FortiFitColors.cardSurface)
            }
            .sheet(item: Binding(
                get: { seeInfoWidgetType.flatMap { SeeInfoWidgetID(widgetType: $0) } },
                set: { seeInfoWidgetType = $0?.widgetType }
            )) { item in
                if let content = AppConstants.widgetInfoModalCopy[item.widgetType] {
                    FortiFitSeeInfoModal(content: content)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showActivityDetailSheet) {
                ActivityDetailSheet(
                    activityService: activityService,
                    onSeeInfo: {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            seeInfoWidgetType = "appleActivity"
                        }
                    },
                    onConfigureSettings: {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            showActivityRingsSettings = true
                        }
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(FortiFitColors.cardSurface)
            }
            .sheet(item: $presentedDetailSheet) { route in
                widgetDetailSheet(for: route)
            }
        }
    }

    // MARK: - Widget Detail Sheet Routing (Phase 8.8)

    private func handleWidgetTap(_ widget: HomeWidget) {
        let route = viewModel.tapRoute(
            for: widget,
            isEditMode: viewModel.isEditMode,
            appleActivityLive: activityService.widgetState == .liveRings,
            healthKitEnabled: settings.healthKitEnabled,
            recoveryStatusGating: recoveryService.currentGatingState,
            isLinkedActive: isLinkedActive
        )
        switch route {
        case .suppressed:
            return
        case .appleActivityLive:
            showActivityDetailSheet = true
        case .appleActivityConnectHK:
            showSettings = true
        case .appleActivityPairWatch:
            return
        case .recoveryStatusLive:
            presentedDetailSheet = route
        case .recoveryStatusConnectHK:
            showSettings = true
        case .recoveryStatusSleepDenied:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        case .recoveryStatusNoTracker:
            return
        case .linkedRecoveryLoad:
            presentedDetailSheet = route
        case .todaysPlan, .trainingLoad, .weeklyStreak, .powerLevel:
            presentedDetailSheet = route
        }
    }

    @ViewBuilder
    private func widgetDetailSheet(for route: WidgetDetailRoute) -> some View {
        switch route {
        case .todaysPlan:
            FortiFitTodaysPlanDetailSheet(
                onNavigateToCompletedWorkout: { workoutId in
                    navigateToWorkout(workoutId: workoutId)
                },
                onModifyExercises: { scheduled in
                    prepareLogWorkoutFromScheduled(scheduled)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(FortiFitColors.cardSurface)
        case .trainingLoad:
            FortiFitTrainingLoadDetailSheet(
                onSeeInfo: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        seeInfoWidgetType = "trainingLoad"
                    }
                },
                onConfigureSettings: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        showTrainingLoadSettings = true
                    }
                },
                onNavigateToWorkout: { workoutId in
                    navigateToWorkout(workoutId: workoutId)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(FortiFitColors.cardSurface)
        case .weeklyStreak:
            FortiFitWeeklyStreakDetailSheet(
                onConfigureSettings: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        showStreakSettings = true
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(FortiFitColors.cardSurface)
        case .powerLevel:
            FortiFitPowerLevelDetailSheet(
                onSeeInfo: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        seeInfoWidgetType = "powerLevel"
                    }
                },
                onNavigateToStrengthTracker: { _ in
                    // Reserved: deep-link to Trends → Strength Tracker chart detail pre-filtered to that exercise.
                    // No-op for now — exits to Home tab.
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(FortiFitColors.cardSurface)
        case .linkedRecoveryLoad:
            FortiFitLinkedRecoveryLoadDetailSheet(
                onSeeInfo: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        seeInfoWidgetType = "linkedRecoveryLoad"
                    }
                },
                onConfigureSettings: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        showLinkedRecoveryLoadSettings = true
                    }
                },
                onNavigateToWorkout: { workoutId in
                    navigateToWorkout(workoutId: workoutId)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(FortiFitColors.cardSurface)
        case .recoveryStatusLive:
            FortiFitRecoveryStatusDetailSheet(
                onSeeInfo: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        seeInfoWidgetType = "recoveryStatus"
                    }
                },
                onConfigureSettings: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        showRecoveryStatusSettings = true
                    }
                },
                onLogWorkout: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        workoutVM.resetForm()
                        workoutVM.showLogWorkout = true
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(FortiFitColors.cardSurface)
        default:
            EmptyView()
        }
    }

    private func navigateToWorkout(workoutId: UUID) {
        let predicate = #Predicate<Workout> { $0.id == workoutId }
        let descriptor = FetchDescriptor<Workout>(predicate: predicate)
        if let workout = (try? modelContext.fetch(descriptor))?.first {
            workoutVM.selectedWorkout = workout
        }
    }

    // MARK: - Widget Card (drag/context menu)

    private func widgetCard(for widget: HomeWidget) -> some View {
        Group {
            if viewModel.isEditMode {
                widgetContent(for: widget)
                    .reorderableCard(
                        payload: widget.widgetType,
                        in: viewModel.activeWidgets,
                        identifiedBy: \.widgetType
                    ) { fromIndex, toIndex in
                        let previousTypes = viewModel.activeWidgets.map(\.widgetType)
                        guard fromIndex < previousTypes.count else { return }
                        let draggedType = previousTypes[fromIndex]
                        // Phase 11 — when the composite is the drag source, the
                        // destination card's onReorder runs (this closure). Route
                        // through the pair-mover so both widgets travel together;
                        // otherwise the single-widget `types.move` would split them.
                        if isLinkedActive && (draggedType == "recoveryStatus" || draggedType == "trainingLoad") {
                            movePairToTarget(targetType: widget.widgetType)
                            return
                        }
                        var types = previousTypes
                        types.move(fromOffsets: IndexSet(integer: fromIndex),
                                   toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
                        // Phase 11 — clear the sticky manual-unlink flag if either
                        // Recovery Status or Training Load actually changed position.
                        HomeWidgetService.clearManualUnlinkIfReorderAffectedPair(
                            previousOrderedTypes: previousTypes,
                            newOrderedTypes: types,
                            settings: settings
                        )
                        viewModel.reorderWidgets(orderedTypes: types, context: modelContext)
                    }
            } else {
                Button(action: {
                    handleWidgetTap(widget)
                }) {
                    widgetContent(for: widget)
                }
                .buttonStyle(PressableCardButtonStyle())
            }
        }
        .overlay(alignment: .trailing) {
            if viewModel.isEditMode {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(FortiFitColors.mutedText)
                    .padding(.trailing, FortiFitSpacing.cardPadding)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isEditMode)
        .contentShape(Rectangle())
        .contextMenu {
            if !viewModel.isEditMode {
                if widget.widgetType == "todaysPlan" && viewModel.currentPlannedWorkout != nil {
                    Button {
                        planCompletionRPE = nil
                        planCompletionDuration = ""
                        showPlanCompletion = true
                    } label: {
                        Label("Complete Workout", systemImage: AppConstants.completeWorkoutIcon)
                    }
                    .accessibilityIdentifier(AccessibilityID.homeWidget_todaysPlan_completeWorkoutMenuItem)
                }

                if widget.widgetType == "trainingLoad" || widget.widgetType == "powerLevel" || widget.widgetType == "appleActivity" || widget.widgetType == "recoveryStatus" {
                    Button {
                        seeInfoWidgetType = widget.widgetType
                    } label: {
                        Label("See Info", systemImage: AppConstants.seeInfoIcon)
                    }
                    .accessibilityIdentifier(
                        widget.widgetType == "trainingLoad"
                            ? AccessibilityID.homeWidget_trainingLoad_seeInfo
                            : widget.widgetType == "powerLevel"
                                ? AccessibilityID.homeWidget_powerLevel_seeInfo
                                : widget.widgetType == "appleActivity"
                                    ? AccessibilityID.homeWidget_appleActivity_seeInfo
                                    : AccessibilityID.homeWidget_recoveryStatus_seeInfo
                    )
                }

                if widget.widgetType == "recoveryStatus" {
                    Button {
                        showRecoveryStatusSettings = true
                    } label: {
                        Label("Configure Settings", systemImage: AppConstants.configureSettingsIcon)
                    }
                    .accessibilityIdentifier(AccessibilityID.homeWidget_recoveryStatus_configureSettings)
                }

                if widget.widgetType == "trainingLoad" {
                    Button {
                        showTrainingLoadSettings = true
                    } label: {
                        Label("Configure Settings", systemImage: AppConstants.configureSettingsIcon)
                    }
                    .accessibilityIdentifier(AccessibilityID.homeWidget_trainingLoad_configureSettings)
                }

                if widget.widgetType == "weekStreak" {
                    Button {
                        showStreakSettings = true
                    } label: {
                        Label("Configure Settings", systemImage: AppConstants.configureSettingsIcon)
                    }
                    .accessibilityIdentifier(AccessibilityID.homeWidget_weeklyStreak_configureSettings)
                }

                if widget.widgetType == "appleActivity" {
                    Button {
                        showActivityRingsSettings = true
                    } label: {
                        Label("Configure Settings", systemImage: AppConstants.configureSettingsIcon)
                    }
                    .accessibilityIdentifier(AccessibilityID.homeWidget_appleActivity_configureSettings)
                }

                Button {
                    viewModel.isEditMode = true
                } label: {
                    Label("Reorder Widgets", systemImage: "arrow.up.arrow.down")
                }

                Button(role: .destructive) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.deleteWidget(widget, context: modelContext)
                    }
                } label: {
                    Label("Delete Widget", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Widget Content Factory

    @ViewBuilder
    private func widgetContent(for widget: HomeWidget) -> some View {
        switch widget.widgetType {
        case "trainingLoad":
            trainingLoadWidget

        case "weekStreak":
            FortiFitStreakWidget(
                streak: viewModel.streakResult.streak,
                message: viewModel.streakResult.message,
                isReorderMode: viewModel.isEditMode
            )

        case "powerLevel":
            FortiFitPowerLevelWidget(
                result: viewModel.powerLevelResult,
                isReorderMode: viewModel.isEditMode
            )

        case "todaysPlan":
            todaysPlanWidget

        case "appleActivity":
            ActivityRingsWidget(
                activityService: activityService,
                isReorderMode: viewModel.isEditMode,
                onTapConnect: { showSettings = true },
                onTapWidget: { showActivityDetailSheet = true }
            )

        case "recoveryStatus":
            FortiFitRecoveryStatusWidget(
                gatingState: recoveryService.currentGatingState,
                sleepMinutes: recoveryService.todaysSnapshot?.totalSleepMinutes,
                deepSleepMinutes: recoveryService.todaysSnapshot?.deepSleepMinutes ?? 0,
                lastWorkoutValue: recoveryService.lastWorkoutHeroFormatted.isEmpty
                    ? recoveryService.lastWorkoutHero(context: modelContext)
                    : recoveryService.lastWorkoutHeroFormatted,
                isReorderMode: viewModel.isEditMode,
                onConnect: { showSettings = true },
                onOpenIOSSettings: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            )

        default:
            EmptyView()
        }
    }

    // MARK: - Today's Plan Widget

    private var todaysPlanWidget: some View {
        FortiFitCard {
            HStack(alignment: .top, spacing: FortiFitSpacing.gapMedium) {
                // Left column — title + workout info with silhouette watermark
                ZStack(alignment: .center) {
                    if let workout = viewModel.currentPlannedWorkout,
                       let symbol = AppConstants.workoutTypeSymbols[workout.workoutType] {
                        Image(systemName: symbol)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundStyle(FortiFitColors.mutedText.opacity(0.1))
                            .accessibilityIdentifier(AccessibilityID.homeWidget_todaysPlan_silhouette)
                            .accessibilityHidden(true)
                    }

                    VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                        FortiFitWidgetHeader(title: "Today's Plan")

                        if let workout = viewModel.currentPlannedWorkout {
                            Text(workout.workoutName)
                                .font(FortiFitTypography.dataValue)
                                .foregroundStyle(FortiFitColors.primaryText)
                                .lineLimit(2)

                            if viewModel.additionalPlannedCount > 0 {
                                Text("\(viewModel.additionalPlannedCount) more planned")
                                    .font(.system(size: 11, weight: .bold))
                                    .kerning(FortiFitTypography.labelKerning)
                                    .foregroundStyle(FortiFitColors.mutedText)
                            }
                        } else if viewModel.todaysPlanAllCompleted {
                            HStack(spacing: FortiFitSpacing.elementSpacing) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(FortiFitColors.positive)
                                Text("All planned workouts completed.")
                                    .font(FortiFitTypography.note)
                                    .foregroundStyle(FortiFitColors.mutedText)
                            }
                        } else {
                            Text("No workout planned for today.")
                                .font(FortiFitTypography.note)
                                .foregroundStyle(FortiFitColors.primaryText)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity)

                // Right column — calendar square (25% width)
                GeometryReader { geo in
                    TodayCalendarSquareView(
                        plannedCount: viewModel.todaysPlannedDotCount,
                        completedCount: viewModel.todaysCompletedDotCount
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .frame(minHeight: 80, maxHeight: .infinity)
                .containerRelativeFrame(.horizontal) { length, _ in
                    length * 0.25
                }
            }
            .padding(.trailing, viewModel.isEditMode ? 36 : 0)
        }
    }

    // MARK: - Training Load Widget

    private var trainingLoadWidget: some View {
        trainingLoadWidget(embedded: false)
    }

    /// `embedded == true` is passed by the linked composite so the card suppresses
    /// its own border (the composite supplies the outer Primary Accent Blue stroke).
    private func trainingLoadWidget(embedded: Bool) -> some View {
        FortiFitCard(
            borderColor: embedded ? .clear : FortiFitColors.border,
            fillColor: embedded ? .clear : FortiFitColors.cardSurface
        ) {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                FortiFitWidgetHeader(title: "Training Load")

                Text(linkedAwareLoadResult.zone)
                    .font(FortiFitTypography.dataValue)
                    .foregroundStyle(loadColor)

                Text(linkedAwareAdvisory)
                    .font(FortiFitTypography.note)
                    .foregroundStyle(FortiFitColors.primaryText)

                if isLinkedActive {
                    sleepImpactChip
                }

                FortiFitProgressBar(
                    progress: linkedAwareLoadResult.score / 100,
                    barColor: loadColor
                )

                HStack {
                    Text("LOW")
                        .font(FortiFitTypography.label)
                        .kerning(FortiFitTypography.labelKerning)
                        .foregroundStyle(FortiFitColors.mutedText)
                    Spacer()
                    Text("HIGH")
                        .font(FortiFitTypography.label)
                        .kerning(FortiFitTypography.labelKerning)
                        .foregroundStyle(FortiFitColors.mutedText)
                }
            }
            .padding(.trailing, viewModel.isEditMode ? 24 : 0)
        }
    }

    // MARK: - Linked Composite + TL linked-variant additions (Phase 11)

    private var linkedCompositeView: some View {
        let composite = FortiFitLinkedRecoveryLoadComposite(
            isReorderMode: viewModel.isEditMode,
            onTap: {
                if viewModel.isEditMode {
                    // Match the parent ScrollView's tap-to-exit behavior for non-linked
                    // widgets. The composite's `.onTapGesture` consumes the tap before
                    // it can bubble up to the ScrollView, so we exit edit mode here.
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.isEditMode = false
                    }
                } else {
                    presentedDetailSheet = .linkedRecoveryLoad
                }
            },
            recoveryStatusCard: {
                FortiFitRecoveryStatusWidget(
                    gatingState: recoveryService.currentGatingState,
                    sleepMinutes: recoveryService.todaysSnapshot?.totalSleepMinutes,
                    deepSleepMinutes: recoveryService.todaysSnapshot?.deepSleepMinutes ?? 0,
                    lastWorkoutValue: recoveryService.lastWorkoutHeroFormatted.isEmpty
                        ? recoveryService.lastWorkoutHero(context: modelContext)
                        : recoveryService.lastWorkoutHeroFormatted,
                    isReorderMode: viewModel.isEditMode,
                    isEmbedded: true,
                    onConnect: { showSettings = true },
                    onOpenIOSSettings: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                )
            },
            trainingLoadCard: {
                trainingLoadWidget(embedded: true)
            }
        )

        return Group {
            if viewModel.isEditMode {
                composite
                    .reorderableCard(
                        payload: "recoveryStatus",
                        in: viewModel.activeWidgets,
                        identifiedBy: \.widgetType,
                        onReorder: reorderLinkedComposite
                    )
            } else {
                composite
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isEditMode)
        .contextMenu {
            // Combined 4-item menu — no Delete Widget per SCREENS § Widget Context Menu.
            Button {
                seeInfoWidgetType = "linkedRecoveryLoad"
            } label: {
                Label("See Info", systemImage: AppConstants.seeInfoIcon)
            }
            Button {
                showLinkedRecoveryLoadSettings = true
            } label: {
                Label("Configure Settings", systemImage: AppConstants.configureSettingsIcon)
            }
            Button {
                settings.recoveryLoadManuallyUnlinked = true
                recoveryService.isLinkedActive = false
            } label: {
                Label("Unlink Widgets", systemImage: "rectangle.on.rectangle.slash")
            }
            .accessibilityIdentifier(AccessibilityID.homeWidget_linkedRecoveryLoad_unlinkMenuItem)
            Button {
                viewModel.isEditMode = true
            } label: {
                Label("Reorder Widgets", systemImage: "arrow.up.arrow.down")
            }
        }
    }

    /// Reorder handler for the linked composite as a drop *destination* (a regular
    /// widget dragged onto the composite). Delegates to `movePairToTarget` so the
    /// composite-as-source path (`widgetCard`'s onReorder) and the composite-as-
    /// destination path share a single mover.
    private func reorderLinkedComposite(fromIndex: Int, toIndex: Int) {
        let previousTypes = viewModel.activeWidgets.map(\.widgetType)
        guard toIndex < previousTypes.count else { return }
        movePairToTarget(targetType: previousTypes[toIndex])
    }

    /// Moves the linked Recovery Status + Training Load pair as a single unit so
    /// the pair lands adjacent to `targetType`, preserving the pair's relative
    /// order. Called from both the composite-as-destination path
    /// (`reorderLinkedComposite`) and the composite-as-source path (`widgetCard`'s
    /// onReorder closure) so the pair travels together regardless of drag direction.
    /// Pure array math lives on `HomeWidgetService.movePairOrderedTypes` so it can
    /// be unit-tested without the SwiftUI view.
    private func movePairToTarget(targetType: String) {
        let previousTypes = viewModel.activeWidgets.map(\.widgetType)
        guard let newTypes = HomeWidgetService.movePairOrderedTypes(
            previousOrderedTypes: previousTypes,
            targetType: targetType
        ) else { return }
        HomeWidgetService.clearManualUnlinkIfReorderAffectedPair(
            previousOrderedTypes: previousTypes,
            newOrderedTypes: newTypes,
            settings: settings
        )
        viewModel.reorderWidgets(orderedTypes: newTypes, context: modelContext)
    }

    /// When linked, swap the bare TL advisory for the joint Recovery & Load advisory
    /// keyed off (zone, trainedToday, sleepBucket). Standalone TL widget continues to
    /// render `LoadResult.advisory` directly. See BUG-061.
    private var linkedAwareAdvisory: String {
        let result = linkedAwareLoadResult
        guard isLinkedActive else { return result.advisory }
        let sleepHours = recoveryService.todaysSnapshot.map { Double($0.totalSleepMinutes) / 60.0 }
        return recoveryService.computeLinkedAdvisory(
            baseAdvisory: result.advisory,
            zone: result.zone,
            trainedToday: result.trainedToday,
            sleepHours: sleepHours,
            targetSleepHours: settings.targetSleepHours
        )
    }

    private var sleepImpactChip: some View {
        // BUG-063 — both sides must use the same decay *shape* (discrete per-day step)
        // so the delta isolates pure sleep variation. `baseline` passes an empty snapshot
        // map → `perDayFactor` falls through to 1.0 for every day → neutral-sleep variant
        // of `computeCurrentScore`. `linked` passes the real snapshot map. The only
        // remaining difference between the two is the per-day `sleepFactor`. With sleep
        // at/above target, `delta = 0`; with sub-target sleep, `delta > 0` (slowed decay
        // retained more stress). `delta < 0` is now mathematically unreachable.
        //
        // BUG-067 — round each operand to an integer *before* subtracting so the chip's
        // integer delta equals the visible integer change on the bar (and on the linked
        // detail sheet hero). Previously the delta was computed on the unrounded doubles
        // and rounded at the end, so `round(linked - baseline)` could disagree with
        // `round(linked) - round(baseline)` by ±1 on boundary cases.
        let cutoff = Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date()
        let workouts = WorkoutService.fetchWorkouts(from: cutoff, to: Date(), context: modelContext)
        let baseline = ExerciseLoadService.computeCurrentScore(
            workouts: workouts,
            sleepSnapshotsByDay: [:],
            targetSleepHours: settings.targetSleepHours,
            experienceLevel: settings.experienceLevel,
            targetMinutesPerWorkout: settings.targetMinutesPerWorkout
        )
        let linked = ExerciseLoadService.computeCurrentScore(
            workouts: workouts,
            sleepSnapshotsByDay: recoveryService.cachedSnapshotsByDay(),
            targetSleepHours: settings.targetSleepHours,
            experienceLevel: settings.experienceLevel,
            targetMinutesPerWorkout: settings.targetMinutesPerWorkout
        )
        let baselineInt = Int(baseline.score.rounded())
        let linkedInt = Int(linked.score.rounded())
        let delta = max(linkedInt - baselineInt, 0)
        let chipColor: Color = {
            switch delta {
            case 5...:  return FortiFitColors.alert
            case 1...4: return FortiFitColors.caution
            default:    return FortiFitColors.mutedText
            }
        }()
        return HStack(spacing: 4) {
            if delta > 0 {
                Text("↑")
            }
            Text("+\(delta) from sleep")
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(chipColor)
        .accessibilityIdentifier(AccessibilityID.homeWidget_trainingLoad_sleepImpactChip)
    }

    // MARK: - Settings Modal Wrapper

    private func settingsModalWrapper<Content: View>(
        title: String,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: FortiFitSpacing.gapLarge) {
                Text(title)
                    .font(FortiFitTypography.widgetHeader)
                    .kerning(FortiFitTypography.labelKerning)
                    .foregroundStyle(FortiFitColors.primaryAccent)
                    .frame(maxWidth: .infinity, alignment: .leading)

                content()
            }
            .padding(FortiFitSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                    .fill(FortiFitColors.cardSurface)
                    .stroke(FortiFitColors.border, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                Button { onDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FortiFitColors.mutedText)
                        .frame(
                            width: FortiFitSpacing.minTouchTarget,
                            height: FortiFitSpacing.minTouchTarget
                        )
                }
                .padding([.top, .trailing], FortiFitSpacing.cardPadding / 2)
            }
            .padding(.horizontal, FortiFitSpacing.screenHorizontal + 8)
        }
    }

    // MARK: - Training Load Settings Modal

    private var trainingLoadSettingsModal: some View {
        settingsModalWrapper(title: "Configure Training Load", onDismiss: dismissTrainingLoadSettings) {
            FortiFitCard(borderColor: FortiFitColors.border) {
                VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                    HStack {
                        Text("Training Experience")
                            .font(FortiFitTypography.tabLabel)
                            .foregroundStyle(FortiFitColors.primaryText)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(AppConstants.experienceLevels[settings.experienceLevel])
                                .font(FortiFitTypography.dataValue)
                                .foregroundStyle(FortiFitColors.primaryAccent)
                            Text(AppConstants.experienceDescriptions[settings.experienceLevel])
                                .font(FortiFitTypography.bodySmall)
                                .foregroundStyle(FortiFitColors.mutedText)
                        }
                    }
                    Slider(
                        value: Binding(
                            get: { Double(settings.experienceLevel) },
                            set: { settings.experienceLevel = Int($0.rounded()) }
                        ),
                        in: 0...2,
                        step: 1
                    )
                    .tint(FortiFitColors.primaryAccent)
                    HStack {
                        Text("BEGINNER")
                        Spacer()
                        Text("INTERMEDIATE")
                        Spacer()
                        Text("ADVANCED")
                    }
                    .font(FortiFitTypography.labelSmall)
                    .kerning(FortiFitTypography.labelKerning)
                    .foregroundStyle(FortiFitColors.mutedText)
                }
            }

            FortiFitCard(borderColor: FortiFitColors.border) {
                VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                    HStack {
                        Text("Target Workout Duration")
                            .font(FortiFitTypography.tabLabel)
                            .foregroundStyle(FortiFitColors.primaryText)
                        Spacer()
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(settings.targetMinutesPerWorkout)")
                                .font(FortiFitTypography.largeValue)
                                .foregroundStyle(FortiFitColors.primaryAccent)
                            Text("min")
                                .font(FortiFitTypography.bodySmall)
                                .foregroundStyle(FortiFitColors.mutedText)
                        }
                    }
                    Slider(
                        value: Binding(
                            get: { Double(settings.targetMinutesPerWorkout) },
                            set: { settings.targetMinutesPerWorkout = Int($0.rounded()) }
                        ),
                        in: 0...300,
                        step: 1
                    )
                    .tint(FortiFitColors.primaryAccent)
                    HStack {
                        Text("0")
                        Spacer()
                        Text("300 MIN")
                    }
                    .font(FortiFitTypography.labelSmall)
                    .kerning(FortiFitTypography.labelKerning)
                    .foregroundStyle(FortiFitColors.mutedText)
                }
            }

            // Phase 8.8 — Done button
            FortiFitButton(AppConstants.SettingsModal.doneButtonLabel, style: .outline) {
                dismissTrainingLoadSettings()
            }
            .accessibilityIdentifier(AccessibilityID.trainingLoadSettings_doneButton)
        }
    }

    private func dismissTrainingLoadSettings() {
        showTrainingLoadSettings = false
        viewModel.loadData(context: modelContext)
    }

    // MARK: - Weekly Streak Settings Modal

    private var streakSettingsModal: some View {
        settingsModalWrapper(title: "Configure Streak Widget", onDismiss: dismissStreakSettings) {
            FortiFitCard(borderColor: FortiFitColors.border) {
                VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                    HStack {
                        Text("Target Workouts Per Week")
                            .font(FortiFitTypography.tabLabel)
                            .foregroundStyle(FortiFitColors.primaryText)
                        Spacer()
                        Text("\(settings.targetWorkoutsPerWeek)")
                            .font(FortiFitTypography.largeValue)
                            .foregroundStyle(FortiFitColors.primaryAccent)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(settings.targetWorkoutsPerWeek) },
                            set: { settings.targetWorkoutsPerWeek = Int($0.rounded()) }
                        ),
                        in: 0...99,
                        step: 1
                    )
                    .tint(FortiFitColors.primaryAccent)
                    HStack {
                        Text("0")
                        Spacer()
                        Text("99")
                    }
                    .font(FortiFitTypography.labelSmall)
                    .kerning(FortiFitTypography.labelKerning)
                    .foregroundStyle(FortiFitColors.mutedText)
                }
            }

            // Phase 8.8 — Done button
            FortiFitButton(AppConstants.SettingsModal.doneButtonLabel, style: .outline) {
                dismissStreakSettings()
            }
            .accessibilityIdentifier(AccessibilityID.weeklyStreakSettings_doneButton)
        }
    }

    // MARK: - Log Workout from Scheduled

    private func prepareLogWorkoutFromScheduled(_ scheduled: ScheduledWorkout) {
        workoutVM.resetForm()
        workoutVM.workoutName = scheduled.workoutName
        workoutVM.workoutType = scheduled.workoutType
        workoutVM.durationMinutes = scheduled.durationMinutes.map { String($0) } ?? ""
        workoutVM.workoutDate = Date()
        workoutVM.selectedRPE = nil
        workoutVM.scheduledWorkoutId = scheduled.id

        if let snapshotData = scheduled.scheduledWorkoutSnapshot {
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

    private func dismissStreakSettings() {
        showStreakSettings = false
        viewModel.loadData(context: modelContext)
    }

    private func dismissActivityRingsSettings() {
        showActivityRingsSettings = false
        activityService.refresh()
    }

    // MARK: - Recent Workout Row

    private func recentWorkoutRow(_ workout: Workout) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name)
                    .font(FortiFitTypography.dataValue)
                    .foregroundStyle(FortiFitColors.primaryText)

                Text(workout.date.dayFormatted)
                    .font(FortiFitTypography.bodySmall)
                    .foregroundStyle(FortiFitColors.mutedText)

                HStack(spacing: FortiFitSpacing.elementSpacing) {
                    if let duration = workout.durationMinutes {
                        Text("\(duration) min")
                            .font(FortiFitTypography.bodySmall)
                            .foregroundStyle(FortiFitColors.mutedText)
                    }
                    if workout.isAppleWatchSourced {
                        if workout.durationMinutes != nil {
                            Text("·")
                                .font(FortiFitTypography.bodySmall)
                                .foregroundStyle(FortiFitColors.mutedText)
                        }
                        Text("Apple Workout")
                            .font(FortiFitTypography.bodySmall)
                            .foregroundStyle(FortiFitColors.mutedText)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FortiFitColors.mutedText)
        }
        .padding(.vertical, FortiFitSpacing.elementSpacing)
    }
}

// MARK: - See Info Widget Identifier

private struct SeeInfoWidgetID: Identifiable {
    let widgetType: String
    var id: String { widgetType }
}

// MARK: - Notification Names

extension Notification.Name {
    static let navigateToPlanTab = Notification.Name("navigateToPlanTab")
}

#Preview {
    HomeView()
        .modelContainer(for: [Workout.self, ExerciseSet.self, Goal.self, HomeWidget.self], inMemory: true)
        .environment(AppleActivityService(client: DefaultHealthKitClient()))
}
