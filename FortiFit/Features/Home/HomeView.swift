import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = HomeViewModel()
    @State private var workoutVM = WorkoutViewModel()
    @State private var showSettings = false
    @State private var showLoadTooltip = false
    @State private var showPowerLevelTooltip = false
    @State private var draggingWidgetType: String?
    @State private var showTrainingLoadSettings = false
    @State private var showStreakSettings = false
    @State private var settings = UserSettings.shared
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
                                    Text("Log your first workout to see it here")
                                        .font(FortiFitTypography.note)
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
                    VStack(spacing: 0) {
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

                // Add Widget Menu Overlay
                if viewModel.showAddWidgetMenu {
                    FortiFitAddWidgetMenu(
                        isPresented: $viewModel.showAddWidgetMenu,
                        activeWidgetTypes: viewModel.activeWidgetTypes,
                        onAdd: { widgetType in
                            viewModel.addWidget(widgetType: widgetType, context: modelContext)
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
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.showAddWidgetMenu)
            .animation(.easeInOut(duration: 0.2), value: showTrainingLoadSettings)
            .animation(.easeInOut(duration: 0.2), value: showStreakSettings)
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .onAppear { viewModel.loadData(context: modelContext) }
            .onDisappear { viewModel.isEditMode = false }
            .onChange(of: selectedTab) { oldValue, _ in
                guard oldValue == 0 else { return }
                showSettings = false
                workoutVM.showLogWorkout = false
                workoutVM.selectedWorkout = nil
                showPlanCompletion = false
                viewModel.showAddWidgetMenu = false
                viewModel.isEditMode = false
                showLoadTooltip = false
                showPowerLevelTooltip = false
                showTrainingLoadSettings = false
                showStreakSettings = false
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
        }
    }

    // MARK: - Widget Card (drag/context menu)

    private func widgetCard(for widget: HomeWidget) -> some View {
        Group {
            if viewModel.isEditMode {
                widgetContent(for: widget)
            } else {
                Button(action: {}) {
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
                    .rotationEffect(.degrees(90))
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

        case "workoutInfo":
            FortiFitCard {
                VStack(spacing: 0) {
                    FortiFitWidgetHeader(title: "Workout Info")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, FortiFitSpacing.gapSmall)

                    Rectangle()
                        .fill(FortiFitColors.border)
                        .frame(height: 1)
                        .padding(.bottom, FortiFitSpacing.gapSmall)

                    HStack(alignment: .top, spacing: 0) {
                        // Left half: Last Workout
                        VStack(alignment: .center, spacing: 4) {
                            Text("Last Workout")
                                .font(FortiFitTypography.body)
                                .kerning(FortiFitTypography.labelKerning)
                                .foregroundStyle(FortiFitColors.primaryAccent)
                            Text(viewModel.lastWorkoutName)
                                .font(FortiFitTypography.dataValue)
                                .foregroundStyle(FortiFitColors.primaryText)
                                .lineLimit(1)
                            if viewModel.lastWorkoutDate != "—" {
                                Text(viewModel.lastWorkoutDate)
                                    .font(FortiFitTypography.body)
                                    .foregroundStyle(FortiFitColors.primaryText)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)

                        // Vertical divider
                        Rectangle()
                            .fill(FortiFitColors.border)
                            .frame(width: 1)
                            .padding(.vertical, 2)
                            .padding(.horizontal, FortiFitSpacing.gapMedium)

                        // Right half: Total Workouts
                        VStack(alignment: .center, spacing: 4) {
                            Text("Total Workouts")
                                .font(FortiFitTypography.body)
                                .kerning(FortiFitTypography.labelKerning)
                                .foregroundStyle(FortiFitColors.primaryAccent)
                                .multilineTextAlignment(.center)
                            Text(viewModel.totalWorkouts > 0 ? "\(viewModel.totalWorkouts)" : "—")
                                .font(FortiFitTypography.dataValue)
                                .foregroundStyle(FortiFitColors.primaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.trailing, viewModel.isEditMode ? 24 : 0)
            }

        case "weekStreak":
            FortiFitStreakWidget(
                streak: viewModel.streakResult.streak,
                message: viewModel.streakResult.message,
                isReorderMode: viewModel.isEditMode,
                onGearTap: { showStreakSettings = true }
            )

        case "powerLevel":
            FortiFitPowerLevelWidget(
                result: viewModel.powerLevelResult,
                showTooltip: $showPowerLevelTooltip,
                isReorderMode: viewModel.isEditMode
            )

        case "todaysPlan":
            todaysPlanWidget

        default:
            EmptyView()
        }
    }

    // MARK: - Today's Plan Widget

    private var todaysPlanWidget: some View {
        FortiFitCard {
            HStack(alignment: .top, spacing: FortiFitSpacing.gapMedium) {
                // Left column — title + workout info
                VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                    FortiFitWidgetHeader(title: "Today's Plan")

                    if let workout = viewModel.currentPlannedWorkout {
                        Text(workout.workoutName)
                            .font(FortiFitTypography.dataValue)
                            .foregroundStyle(FortiFitColors.primaryText)
                            .lineLimit(2)

                        Text(workout.workoutType.uppercased())
                            .font(FortiFitTypography.labelSmall)
                            .kerning(FortiFitTypography.labelKerning)
                            .foregroundStyle(FortiFitColors.secondaryText)

                        Button {
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            planCompletionRPE = nil
                            planCompletionDuration = ""
                            showPlanCompletion = true
                        } label: {
                            Text("Complete Workout")
                                .font(.system(size: 13, weight: .semibold))
                                .kerning(FortiFitTypography.labelKerning)
                                .foregroundStyle(FortiFitColors.primaryAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                                        .stroke(FortiFitColors.primaryAccent, lineWidth: 1)
                                )
                        }

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
                HStack {
                    FortiFitWidgetHeader(title: "Training Load")
                    FortiFitHintTooltip(
                        message: "Measures your daily training stress based on your workout patterns and experience level",
                        isVisible: $showLoadTooltip
                    )
                    Spacer()
                }

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
        .overlay(alignment: .topTrailing) {
            if !viewModel.isEditMode {
                Button { showTrainingLoadSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(FortiFitColors.primaryAccent)
                        .frame(
                            width: FortiFitSpacing.minTouchTarget,
                            height: FortiFitSpacing.minTouchTarget
                        )
                }
                .padding(.top, 4)
                .padding(.trailing, 4)
            }
        }
    }

    // MARK: - Training Load Settings Modal

    private var trainingLoadSettingsModal: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { dismissTrainingLoadSettings() }

            VStack(spacing: FortiFitSpacing.gapLarge) {
                // Header
                HStack {
                    Text("Configure Training Load")
                        .font(FortiFitTypography.widgetHeader)
                        .kerning(FortiFitTypography.labelKerning)
                        .foregroundStyle(FortiFitColors.primaryAccent)
                    Spacer()
                    Button { dismissTrainingLoadSettings() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FortiFitColors.mutedText)
                            .frame(
                                width: FortiFitSpacing.minTouchTarget,
                                height: FortiFitSpacing.minTouchTarget
                            )
                    }
                }

                // Training Experience
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

                // Target Workout Duration
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
            .padding(FortiFitSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                    .fill(FortiFitColors.cardSurface)
                    .stroke(FortiFitColors.border, lineWidth: 1)
            )
            .padding(.horizontal, FortiFitSpacing.screenHorizontal + 8)
        }
    }

    private func dismissTrainingLoadSettings() {
        showTrainingLoadSettings = false
        viewModel.loadData(context: modelContext)
    }

    // MARK: - Weekly Streak Settings Modal

    private var streakSettingsModal: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { dismissStreakSettings() }

            VStack(spacing: FortiFitSpacing.gapLarge) {
                // Header
                HStack {
                    Text("Configure Streak Widget")
                        .font(FortiFitTypography.widgetHeader)
                        .kerning(FortiFitTypography.labelKerning)
                        .foregroundStyle(FortiFitColors.primaryAccent)
                    Spacer()
                    Button { dismissStreakSettings() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FortiFitColors.mutedText)
                            .frame(
                                width: FortiFitSpacing.minTouchTarget,
                                height: FortiFitSpacing.minTouchTarget
                            )
                    }
                }

                // Target Workouts Per Week
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
            .padding(FortiFitSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                    .fill(FortiFitColors.cardSurface)
                    .stroke(FortiFitColors.border, lineWidth: 1)
            )
            .padding(.horizontal, FortiFitSpacing.screenHorizontal + 8)
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

    private func dismissStreakSettings() {
        showStreakSettings = false
        viewModel.loadData(context: modelContext)
    }

    // MARK: - Recent Workout Row

    private func recentWorkoutRow(_ workout: Workout) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if workout.isHealthKitLinked {
                        FortiFitHealthGlyph()
                    }
                    Text(workout.name)
                        .font(FortiFitTypography.dataValue)
                        .foregroundStyle(FortiFitColors.primaryText)
                }

                HStack(spacing: FortiFitSpacing.elementSpacing) {
                    Text(workout.date.dayFormatted)
                        .font(FortiFitTypography.bodySmall)
                        .foregroundStyle(FortiFitColors.mutedText)

                    if workout.workoutType == "Strength Training" || workout.workoutType == "HIIT" {
                        let count = Set(workout.exerciseSets.map { $0.exerciseName }).count
                        Text("· \(count) exercise\(count == 1 ? "" : "s")")
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

// MARK: - Widget Drop Delegate

private struct WidgetDropDelegate: DropDelegate {
    let widget: HomeWidget
    let viewModel: HomeViewModel
    @Binding var draggingWidgetType: String?
    let modelContext: ModelContext

    func performDrop(info: DropInfo) -> Bool {
        draggingWidgetType = nil
        viewModel.isEditMode = false
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
}
