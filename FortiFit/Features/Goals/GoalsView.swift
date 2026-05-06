import SwiftUI
import SwiftData
import Charts
import UniformTypeIdentifiers

struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = GoalsViewModel()
    @State private var draggingGoalID: UUID?
    @State private var goalIdsToPulse: Set<UUID> = []
    @State private var headerHeight: CGFloat = 0
    private var settings: UserSettings { UserSettings.shared }
    var selectedTab: Int = 4

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                if viewModel.goals.isEmpty {
                    VStack {
                        Spacer()
                        VStack(spacing: FortiFitSpacing.gapMedium) {
                            Text("Set your first goal to start tracking")
                                .font(FortiFitTypography.body)
                                .foregroundStyle(FortiFitColors.mutedText)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, FortiFitSpacing.screenHorizontal)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: FortiFitSpacing.elementSpacing * 2) {
                            ForEach(viewModel.filteredGoals) { goal in
                                Group {
                                    if viewModel.isReorderMode {
                                        goalCard(goal)
                                            .overlay(alignment: .trailing) {
                                                Image(systemName: "line.3.horizontal")
                                                    .font(.system(size: 20, weight: .semibold))
                                                    .foregroundStyle(FortiFitColors.mutedText)
                                                    .padding(.trailing, FortiFitSpacing.cardPadding)
                                            }
                                    } else {
                                        Button(action: {}) {
                                            goalCard(goal)
                                        }
                                        .buttonStyle(PressableCardButtonStyle())
                                    }
                                }
                                .animation(.easeInOut(duration: 0.2), value: viewModel.isReorderMode)
                                .opacity(draggingGoalID == goal.id ? 0.5 : 1.0)
                                .contentShape(Rectangle())
                                .onDrag {
                                    guard viewModel.isReorderMode else {
                                        return NSItemProvider()
                                    }
                                    draggingGoalID = goal.id
                                    return NSItemProvider(object: goal.id.uuidString as NSString)
                                }
                                .onDrop(of: [.text], delegate: GoalDropDelegate(
                                    goal: goal,
                                    viewModel: viewModel,
                                    draggingGoalID: $draggingGoalID,
                                    modelContext: modelContext
                                ))
                                .contextMenu {
                                    if !viewModel.isReorderMode {
                                        if goal.goalType != "weeklyWorkouts" {
                                            Button {
                                                viewModel.populateFormFromGoal(goal)
                                                viewModel.showAddGoal = true
                                            } label: {
                                                Label("Edit Goal", systemImage: "pencil")
                                            }
                                        }

                                        if goal.goalType != "weeklyWorkouts" {
                                            Button {
                                                viewModel.goalToReset = goal
                                                viewModel.showResetConfirmation = true
                                            } label: {
                                                Label("Reset Goal Progress", systemImage: "arrow.counterclockwise")
                                            }
                                        }

                                        Button {
                                            viewModel.isReorderMode = true
                                        } label: {
                                            Label("Reorder Goals", systemImage: "arrow.up.arrow.down")
                                        }

                                        Button(role: .destructive) {
                                            viewModel.goalToDelete = goal
                                            viewModel.showDeleteConfirmation = true
                                        } label: {
                                            Label("Delete Goal", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, FortiFitSpacing.screenHorizontal)
                        .padding(.top, headerHeight)
                        .padding(.bottom, FortiFitSpacing.elementSpacing)
                    }
                    .scrollClipDisabled()
                }

                FortiFitFixedHeader(headerHeight: $headerHeight) {
                    HStack {
                        ellipsisMenu

                        Spacer()

                        Button {
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            viewModel.resetForm()
                            viewModel.showAddGoal = true
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
                        .accessibilityIdentifier(AccessibilityID.addGoalButton)
                    }
                }
            }
            .background(FortiFitColors.background)
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.dismissLegendTooltip()
                if viewModel.isReorderMode {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.isReorderMode = false
                    }
                }
            }
            .onAppear {
                viewModel.loadGoals(context: modelContext)
                // Trigger pulse for goals completed today
                let ids = viewModel.identifyGoalsToPulse()
                goalIdsToPulse = Set(ids)
            }
            .onDisappear {
                viewModel.isReorderMode = false
                viewModel.clearPulsedGoalIds()
            }
            .onChange(of: selectedTab) { oldValue, _ in
                guard oldValue == 4 else { return }
                DispatchQueue.main.async {
                    viewModel.showAddGoal = false
                    viewModel.isReorderMode = false
                    viewModel.showDeleteConfirmation = false
                    viewModel.showResetConfirmation = false
                    viewModel.goalToDelete = nil
                    viewModel.goalToReset = nil
                    viewModel.dismissLegendTooltip()
                    draggingGoalID = nil
                }
            }
            .navigationDestination(isPresented: $viewModel.showAddGoal) {
                AddGoalView(viewModel: viewModel)
                    .onDisappear {
                        viewModel.isReorderMode = false
                        viewModel.loadGoals(context: modelContext)
                    }
            }
            .alert(
                "Delete \(viewModel.goalToDelete?.title ?? "") goal?",
                isPresented: $viewModel.showDeleteConfirmation
            ) {
                Button("Cancel", role: .cancel) {
                    viewModel.goalToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let goal = viewModel.goalToDelete {
                        viewModel.deleteGoal(goal, context: modelContext)
                        viewModel.goalToDelete = nil
                    }
                }
            } message: {
                Text("This can't be undone")
            }
            .alert(
                "Reset \(viewModel.goalToReset?.title ?? "") progress to zero?",
                isPresented: $viewModel.showResetConfirmation
            ) {
                Button("Cancel", role: .cancel) {
                    viewModel.goalToReset = nil
                }
                Button("Reset", role: .destructive) {
                    if let goal = viewModel.goalToReset {
                        viewModel.resetGoalProgress(goal, context: modelContext)
                        viewModel.goalToReset = nil
                    }
                }
            } message: {
                Text("This can't be undone")
            }
        }
    }

    // MARK: - Ellipsis Menu

    private var ellipsisMenu: some View {
        Menu {
            Menu {
                Button {
                    viewModel.activeFilter = .all
                } label: {
                    if viewModel.activeFilter == .all {
                        Label("All", systemImage: "checkmark")
                    } else {
                        Text("All")
                    }
                }
                Button {
                    viewModel.activeFilter = .active
                } label: {
                    if viewModel.activeFilter == .active {
                        Label("Active", systemImage: "checkmark")
                    } else {
                        Text("Active")
                    }
                }
                Button {
                    viewModel.activeFilter = .completed
                } label: {
                    if viewModel.activeFilter == .completed {
                        Label("Completed", systemImage: "checkmark")
                    } else {
                        Text("Completed")
                    }
                }
            } label: {
                Label("Filter Goals", systemImage: "line.3.horizontal.decrease.circle")
            }

            Button {
                if viewModel.expandCollapseLabel == "Expand All" {
                    viewModel.expandAll()
                } else {
                    viewModel.collapseAll()
                }
            } label: {
                Label(viewModel.expandCollapseLabel, systemImage: viewModel.expandCollapseIcon)
            }
        } label: {
            Image(systemName: "ellipsis")
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
    }

    // MARK: - Goal Card (dispatches by type)

    @ViewBuilder
    private func goalCard(_ goal: Goal) -> some View {
        let isComplete: Bool = {
            if goal.goalType == "weeklyWorkouts" { return viewModel.weeklyWorkoutsComplete }
            return viewModel.isComplete(goal)
        }()
        let progress: Double = {
            if goal.goalType == "weeklyWorkouts" { return viewModel.weeklyWorkoutsPercentage / 100 }
            return viewModel.completionPercentage(for: goal) / 100
        }()
        let isExpanded = viewModel.expandedGoalIds.contains(goal.id)
        let shouldPulse = goalIdsToPulse.contains(goal.id)

        FortiFitCard(
            borderColor: isComplete ? FortiFitColors.primaryAccent : FortiFitColors.border
        ) {
            VStack(spacing: FortiFitSpacing.gapSmall) {
                // Completed label at top center
                if isComplete, let celebratedDate = goal.lastCelebratedDate {
                    Text("COMPLETED \(formattedCompletedDate(celebratedDate))")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(FortiFitColors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                }

                // Main content: info on leading, ring on trailing
                HStack(alignment: .center, spacing: FortiFitSpacing.gapMedium) {
                    // Leading: three-section left column
                    VStack(alignment: .leading, spacing: 10) {
                        goalInfoSections(goal)
                    }

                    Spacer()

                    // Trailing: progress ring with optional tooltip overlay
                    goalProgressRingWithTooltip(goal: goal, progress: progress, isComplete: isComplete, shouldPulse: shouldPulse)
                        .padding(.trailing, 8)
                }

                // Expandable sparkline section
                if isExpanded {
                    sparklineSection(goal: goal)
                        .onAppear {
                            viewModel.loadSnapshots(for: goal, context: modelContext)
                        }
                        .transition(.opacity)
                }

                // Chevron toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        viewModel.toggleExpanded(goalId: goal.id)
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FortiFitColors.mutedText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, viewModel.isReorderMode ? 36 : 0)
        }
        // 3% blue wash for completed goals
        .overlay {
            if isComplete {
                RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                    .fill(FortiFitColors.primaryAccent.opacity(0.03))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isComplete)
    }

    // MARK: - Completed Date Formatter

    private func formattedCompletedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date).uppercased()
    }

    // MARK: - Three-Section Goal Info (leading side)

    @ViewBuilder
    private func goalInfoSections(_ goal: Goal) -> some View {
        // Section 1: Type-specific header
        sectionLabel(goal.headerLabel)
        Text(goal.title)
            .font(FortiFitTypography.dataValue)
            .foregroundStyle(FortiFitColors.primaryText)

        // Section 2: Target
        sectionLabel("Target")
        targetText(goal)

        // Section 3: Progress
        sectionLabel("Progress")
        progressText(goal)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(FortiFitTypography.label)
            .tracking(FortiFitTypography.labelKerning)
            .foregroundStyle(FortiFitColors.primaryAccent)
    }

    @ViewBuilder
    private func targetText(_ goal: Goal) -> some View {
        switch goal.goalType {
        case "Strength PR":
            Text(UnitConversion.displayWeight(goal.targetValueKg, useLbs: settings.useLbs))
                .font(FortiFitTypography.body)
                .foregroundStyle(FortiFitColors.primaryText)

        case "Repetitions PR":
            Text("\(goal.targetReps) reps")
                .font(FortiFitTypography.body)
                .foregroundStyle(FortiFitColors.primaryText)

        case "Speed and Distance":
            if let targetDist = goal.targetDistanceKm, let targetDur = goal.targetDurationMinutes {
                // Dual-target: conversational phrasing
                let distDisplay: String = {
                    if settings.useMiles {
                        return String(format: "%.1f miles", targetDist * UnitConversion.kmToMilesFactor)
                    } else {
                        return String(format: "%.1f km", targetDist)
                    }
                }()
                Text("\(distDisplay) in \(Int(targetDur)) minutes")
                    .font(FortiFitTypography.body)
                    .foregroundStyle(FortiFitColors.primaryText)
            } else if let targetDist = goal.targetDistanceKm {
                let distDisplay: String = {
                    if settings.useMiles {
                        return String(format: "%.1f miles", targetDist * UnitConversion.kmToMilesFactor)
                    } else {
                        return String(format: "%.1f km", targetDist)
                    }
                }()
                Text(distDisplay)
                    .font(FortiFitTypography.body)
                    .foregroundStyle(FortiFitColors.primaryText)
            } else if let targetDur = goal.targetDurationMinutes {
                Text("\(Int(targetDur)) minutes")
                    .font(FortiFitTypography.body)
                    .foregroundStyle(FortiFitColors.primaryText)
            }

        case "weeklyWorkouts":
            Text("\(viewModel.weeklyWorkoutsTarget) workouts / week")
                .font(FortiFitTypography.body)
                .foregroundStyle(FortiFitColors.primaryText)

        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func progressText(_ goal: Goal) -> some View {
        switch goal.goalType {
        case "Strength PR":
            let weightUnit = settings.useLbs ? "lbs" : "kg"
            Text("\(UnitConversion.displayValue(goal.currentValueKg, useLbs: settings.useLbs)) / \(UnitConversion.displayValue(goal.targetValueKg, useLbs: settings.useLbs)) \(weightUnit)")
                .font(FortiFitTypography.body)
                .foregroundStyle(FortiFitColors.primaryText)

        case "Repetitions PR":
            Text("\(goal.currentReps) / \(goal.targetReps) reps")
                .font(FortiFitTypography.body)
                .foregroundStyle(FortiFitColors.primaryText)

        case "Speed and Distance":
            if goal.targetDistanceKm != nil {
                let distLabel: String = {
                    if settings.useMiles {
                        let factor = UnitConversion.kmToMilesFactor
                        return String(format: "%.1f / %.1f mi", goal.currentDistanceKm * factor, (goal.targetDistanceKm ?? 0) * factor)
                    } else {
                        return String(format: "%.1f / %.1f km", goal.currentDistanceKm, goal.targetDistanceKm ?? 0)
                    }
                }()
                Text(distLabel)
                    .font(FortiFitTypography.body)
                    .foregroundStyle(FortiFitColors.primaryText)
            }
            if let targetDur = goal.targetDurationMinutes {
                Text(String(format: "%.0f / %.0f min", goal.currentDurationMinutes, targetDur))
                    .font(FortiFitTypography.body)
                    .foregroundStyle(FortiFitColors.primaryText)
            }

        case "weeklyWorkouts":
            Text("\(viewModel.weeklyWorkoutsCurrent) / \(viewModel.weeklyWorkoutsTarget)")
                .font(FortiFitTypography.body)
                .foregroundStyle(FortiFitColors.primaryText)

        default:
            EmptyView()
        }
    }

    // MARK: - Progress Ring with Tooltip

    @ViewBuilder
    private func goalProgressRingWithTooltip(goal: Goal, progress: Double, isComplete: Bool, shouldPulse: Bool) -> some View {
        let isDualArc = goal.goalType == "Speed and Distance"
            && goal.targetDistanceKm != nil
            && goal.targetDurationMinutes != nil

        let displayPercentage: Int = {
            let clamped = min(max(progress, 0), 1.0)
            return Int(clamped * 100)
        }()

        VStack(spacing: 8) {
            FortiFitGoalProgressRing(
                progress: progress,
                goalType: goal.goalType,
                colorIndex: goal.colorIndex,
                isVictory: isComplete,
                distanceProgress: isDualArc ? viewModel.distanceProgress(for: goal) : (goal.targetDistanceKm != nil ? viewModel.distanceProgress(for: goal) : 0),
                durationProgress: isDualArc ? viewModel.durationProgress(for: goal) : (goal.targetDurationMinutes != nil ? viewModel.durationProgress(for: goal) : 0),
                hasDualTargets: isDualArc,
                shouldPulse: shouldPulse
            )
            .onTapGesture {
                viewModel.toggleLegendTooltip(for: goal.id)
            }

            // Tooltip overlay (positioned below ring)
            if viewModel.tappedRingGoalId == goal.id {
                FortiFitGoalLegendTooltip(
                    isVisible: .constant(true),
                    percentage: displayPercentage,
                    isDualArc: isDualArc
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(goalAccessibilityLabel(goal: goal, percentage: displayPercentage, isDualArc: isDualArc))
    }

    private func goalAccessibilityLabel(goal: Goal, percentage: Int, isDualArc: Bool) -> String {
        var label = "\(goal.title) goal, \(percentage)% complete"
        if isDualArc {
            label += ". Distance shown in purple, Duration shown in light cyan"
        }
        return label
    }

    // MARK: - Sparkline Section

    @ViewBuilder
    private func sparklineSection(goal: Goal) -> some View {
        let isEmpty = viewModel.isSparklineEmpty(for: goal)

        VStack(alignment: .leading, spacing: 6) {
            FortiFitDivider()

            // 1. "LAST 30 DAYS" header — always present
            Text("LAST 30 DAYS")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(FortiFitColors.mutedText)

            // 2. Chart area
            if isEmpty {
                skeletonDashedLine()
                    .frame(height: 60)
            } else {
                sparklineChart(snapshots: viewModel.snapshotCache[goal.id] ?? [])
                    .frame(height: 60)
            }

            // 3. Footer note
            Text(isEmpty ? "Log more workouts to see progress toward this goal." : "Goal progress")
                .font(.system(size: 12))
                .italic()
                .foregroundStyle(FortiFitColors.mutedText)
        }
        .transition(.opacity)
    }

    private func skeletonDashedLine() -> some View {
        GeometryReader { geo in
            Path { path in
                let midY = geo.size.height / 2
                path.move(to: CGPoint(x: 0, y: midY))
                path.addLine(to: CGPoint(x: geo.size.width, y: midY))
            }
            .stroke(FortiFitColors.border, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
        }
    }

    private func sparklineChart(snapshots: [GoalSnapshot]) -> some View {
        let calendar = Calendar.current
        var dataPoints: [(date: Date, value: Double)] = []

        guard let firstDate = snapshots.first?.date else {
            return AnyView(EmptyView())
        }

        let today = calendar.startOfDay(for: Date())
        var currentDate = calendar.startOfDay(for: firstDate)
        var lastValue: Double = 0

        let snapshotByDate: [Date: Double] = {
            var dict: [Date: Double] = [:]
            for s in snapshots {
                dict[calendar.startOfDay(for: s.date)] = s.value
            }
            return dict
        }()

        while currentDate <= today {
            if let value = snapshotByDate[currentDate] {
                lastValue = value
            }
            dataPoints.append((date: currentDate, value: lastValue))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? today
        }

        return AnyView(
            Chart(dataPoints, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(FortiFitColors.primaryAccent)
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
        )
    }
}

// MARK: - Goal Drop Delegate

private struct GoalDropDelegate: DropDelegate {
    let goal: Goal
    let viewModel: GoalsViewModel
    @Binding var draggingGoalID: UUID?
    let modelContext: ModelContext

    func performDrop(info: DropInfo) -> Bool {
        draggingGoalID = nil
        viewModel.isReorderMode = false
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggingID = draggingGoalID,
              draggingID != goal.id,
              let fromIndex = viewModel.goals.firstIndex(where: { $0.id == draggingID }),
              let toIndex = viewModel.goals.firstIndex(where: { $0.id == goal.id })
        else { return }

        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif

        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.goals.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
            GoalService.reorder(goals: viewModel.goals, context: modelContext)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

#Preview {
    GoalsView()
        .modelContainer(for: [Workout.self, ExerciseSet.self, Goal.self, GoalSnapshot.self], inMemory: true)
}
