import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = HomeViewModel()
    @State private var workoutVM = WorkoutViewModel()
    @State private var showSettings = false
    @State private var draggingWidgetType: String?
    @State private var seeInfoWidgetType: String?
    @State private var showTrainingLoadSettings = false
    @State private var showStreakSettings = false
    @State private var showActivityRingsSettings = false
    @State private var showActivityDetailSheet = false
    @State private var settings = UserSettings.shared
    @Environment(AppleActivityService.self) private var activityService
    @State private var headerHeight: CGFloat = 0
    var selectedTab: Int = 0

    // Today's Plan completion
    @State private var showPlanCompletion = false
    @State private var planCompletionRPE: Int? = nil
    @State private var planCompletionDuration: String = ""

    private var loadColor: Color {
        Color(hex: viewModel.loadResult.zoneColor)
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
                                ForEach(viewModel.activeWidgets) { widget in
                                    widgetCard(for: widget)
                                }
                                .animation(.easeInOut(duration: 0.2), value: viewModel.activeWidgets.map(\.widgetType))
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
                    // Catch-all: drops landing outside any widget clear the stale drag state
                    .onDrop(of: [.text], isTargeted: nil) { _, _ in
                        draggingWidgetType = nil
                        return false
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
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.showAddWidgetMenu)
            .animation(.easeInOut(duration: 0.2), value: showTrainingLoadSettings)
            .animation(.easeInOut(duration: 0.2), value: showStreakSettings)
            .animation(.easeInOut(duration: 0.2), value: showActivityRingsSettings)
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .onAppear {
                viewModel.loadData(context: modelContext)
                activityService.refreshWorkoutContributions(context: modelContext)
            }
            .onDisappear { viewModel.isEditMode = false }
            .onChange(of: viewModel.isEditMode) { _, isOn in
                if !isOn { draggingWidgetType = nil }
            }
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
                ActivityDetailSheet(activityService: activityService)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(FortiFitColors.cardSurface)
            }
        }
    }

    // MARK: - Widget Card (drag/context menu)

    private func widgetCard(for widget: HomeWidget) -> some View {
        Group {
            if viewModel.isEditMode {
                widgetContent(for: widget)
            } else {
                Button(action: {
                    if widget.widgetType == "appleActivity" && activityService.widgetState == .liveRings {
                        showActivityDetailSheet = true
                    }
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
        .opacity(draggingWidgetType == widget.widgetType ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isEditMode)
        .contentShape(Rectangle())
        .onDrag {
            guard viewModel.isEditMode else {
                return NSItemProvider()
            }
            draggingWidgetType = widget.widgetType
            return NSItemProvider(object: widget.widgetType as NSString)
        }
        .onDrop(of: [.text], delegate: WidgetDropDelegate(
            widget: widget,
            viewModel: viewModel,
            draggingWidgetType: $draggingWidgetType,
            modelContext: modelContext
        ))
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

                if widget.widgetType == "trainingLoad" || widget.widgetType == "powerLevel" || widget.widgetType == "appleActivity" {
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
                                : AccessibilityID.homeWidget_appleActivity_seeInfo
                    )
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
        FortiFitCard {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                FortiFitWidgetHeader(title: "Training Load")

                Text(viewModel.loadResult.zone)
                    .font(FortiFitTypography.dataValue)
                    .foregroundStyle(loadColor)

                Text(viewModel.loadResult.advisory)
                    .font(FortiFitTypography.note)
                    .foregroundStyle(FortiFitColors.primaryText)

                FortiFitProgressBar(
                    progress: viewModel.loadResult.score / 100,
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

// MARK: - Widget Drop Delegate

private struct WidgetDropDelegate: DropDelegate {
    let widget: HomeWidget
    let viewModel: HomeViewModel
    @Binding var draggingWidgetType: String?
    let modelContext: ModelContext

    func performDrop(info: DropInfo) -> Bool {
        draggingWidgetType = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingWidgetType,
              dragging != widget.widgetType,
              let fromIndex = viewModel.activeWidgets.firstIndex(where: { $0.widgetType == dragging }),
              let toIndex = viewModel.activeWidgets.firstIndex(where: { $0.widgetType == widget.widgetType })
        else { return }

        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif

        withAnimation(.easeInOut(duration: 0.2)) {
            var types = viewModel.activeWidgets.map(\.widgetType)
            types.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            viewModel.reorderWidgets(orderedTypes: types, context: modelContext)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
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
