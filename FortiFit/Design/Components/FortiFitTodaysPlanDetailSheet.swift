import SwiftUI
import SwiftData

/// Today's Plan Detail Sheet — opened by tapping the Today's Plan home widget.
/// Renders a scrollable stack of mini-cards (one per `ScheduledWorkout` for today).
/// Reactive to PlanService changes via reload-on-cascade.
///
/// See SCREENS.md § Today's Plan Detail Sheet for the full spec.
struct FortiFitTodaysPlanDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var rows: [ScheduledWorkout] = []
    @State private var completionTarget: ScheduledWorkout?
    @State private var completionRPE: Int?
    @State private var completionDuration: String = ""

    /// Closure called when the user taps a Completed row — host navigates to that workout's detail.
    var onNavigateToCompletedWorkout: ((UUID) -> Void)?

    /// Closure called when the user taps Modify Exercises in the completion sheet —
    /// host dismisses this sheet and pushes LogWorkout pre-populated from the scheduled workout.
    var onModifyExercises: ((ScheduledWorkout) -> Void)?

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if rows.isEmpty {
                    emptyState
                } else {
                    ForEach(rows, id: \.id) { row in
                        miniCard(for: row)
                            .padding(.bottom, FortiFitSpacing.gapMedium)
                    }
                }
            }
            .padding(.horizontal, FortiFitSpacing.screenHorizontal)
            .padding(.bottom, FortiFitSpacing.gapXLarge)
        }
        .background(FortiFitColors.cardSurface)
        .task { reload() }
        .sheet(item: $completionTarget) { target in
            CompletePlanView(
                scheduledWorkout: target,
                completionRPE: $completionRPE,
                completionDuration: $completionDuration,
                onSave: {
                    let durationMin = Int(completionDuration)
                    PlanService.completeWorkout(
                        scheduledWorkout: target,
                        date: Date(),
                        rpe: completionRPE,
                        durationMinutes: durationMin,
                        context: modelContext
                    )
                    completionTarget = nil
                    completionRPE = nil
                    completionDuration = ""
                    reload()
                },
                onModifyExercises: {
                    let target = completionTarget
                    completionTarget = nil
                    guard let target else { return }
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onModifyExercises?(target)
                    }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(FortiFitColors.cardSurface)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FortiFitColors.mutedText)
                        .frame(
                            width: FortiFitSpacing.minTouchTarget,
                            height: FortiFitSpacing.minTouchTarget
                        )
                }
                .accessibilityIdentifier(AccessibilityID.todaysPlanDetailSheet_closeButton)
            }

            Text("Today's Plan – \(formattedDate)")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(FortiFitColors.primaryAccent)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, FortiFitSpacing.gapLarge)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Text(AppConstants.WidgetDetail.EmptyState.todaysPlanNoWorkouts)
            .font(FortiFitTypography.note)
            .foregroundStyle(FortiFitColors.mutedText)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, FortiFitSpacing.gapXLarge)
            .accessibilityIdentifier(AccessibilityID.todaysPlanDetailSheet_emptyState)
    }

    // MARK: - Mini Card

    private func miniCard(for row: ScheduledWorkout) -> some View {
        // 2pt outer border gives visual separation from the 1pt inner exercise cards
        // listed in `exerciseBlock(...)`.
        FortiFitCard(borderColor: cardBorderColor(for: row.status), borderWidth: 2) {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                topRow(for: row)
                metaRow(for: row)
                detailRow(for: row)
                actionRow(for: row)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            handleRowTap(row)
        }
    }

    private func cardBorderColor(for status: String) -> Color {
        switch status {
        case "completed": return FortiFitColors.positive
        default: return FortiFitColors.border
        }
    }

    private func topRow(for row: ScheduledWorkout) -> some View {
        HStack(alignment: .center, spacing: FortiFitSpacing.elementSpacing) {
            if let symbol = AppConstants.workoutTypeSymbols[row.workoutType] {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppConstants.workoutTypeChartColors[row.workoutType] ?? FortiFitColors.primaryAccent)
            }
            Text(row.workoutName)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(FortiFitColors.primaryText)
                .lineLimit(2)
            Spacer()
            statusPill(for: row.status)
        }
    }

    private func statusPill(for status: String) -> some View {
        let (label, foreground, background, border): (String, Color, Color, Color)
        switch status {
        case "completed":
            label = "Completed"
            foreground = .white
            background = FortiFitColors.positive
            border = .clear
        case "skipped":
            label = "Skipped"
            foreground = FortiFitColors.mutedText
            background = .clear
            border = FortiFitColors.mutedText
        default:
            label = "Planned"
            foreground = FortiFitColors.primaryAccent
            background = .clear
            border = FortiFitColors.primaryAccent
        }
        return Text(label)
            .font(.system(size: 13, weight: .bold))
            .kerning(FortiFitTypography.labelKerning)
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadiusPill)
                    .fill(background)
                    .stroke(border, lineWidth: 1)
            )
    }

    private func metaRow(for row: ScheduledWorkout) -> some View {
        HStack(spacing: FortiFitSpacing.elementSpacing) {
            if let time = row.scheduledTime {
                Text(time.timeFormatted)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FortiFitColors.mutedText)
                Text("·")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FortiFitColors.mutedText)
            }
            if let duration = row.durationMinutes {
                Text("\(duration) min")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FortiFitColors.mutedText)
            }
        }
    }

    @ViewBuilder
    private func detailRow(for row: ScheduledWorkout) -> some View {
        if let snapshotData = row.scheduledWorkoutSnapshot {
            let exercises = PlanService.decodeSnapshot(data: snapshotData)
                .sorted { $0.sortOrder < $1.sortOrder }
            if !exercises.isEmpty {
                exerciseList(exercises: exercises)
            }
        }
    }

    /// Renders the snapshot's exercises grouped by exerciseName.
    /// Each SnapshotExercise represents a set group (N identical sets). Same name across
    /// multiple SnapshotExercises = heterogeneous set rows for that exercise.
    private func exerciseList(exercises: [SnapshotExercise]) -> some View {
        // Preserve first-encountered order of names while grouping their set groups together.
        var nameOrder: [String] = []
        var groupsByName: [String: [SnapshotExercise]] = [:]
        for ex in exercises {
            if groupsByName[ex.exerciseName] == nil { nameOrder.append(ex.exerciseName) }
            groupsByName[ex.exerciseName, default: []].append(ex)
        }
        return VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
            ForEach(nameOrder, id: \.self) { name in
                exerciseBlock(name: name, groups: groupsByName[name] ?? [])
            }
        }
    }

    /// Each exercise renders in its own grey card to match the Workout Detail and
    /// Log Workout exercise-card convention.
    private func exerciseBlock(name: String, groups: [SnapshotExercise]) -> some View {
        FortiFitCard(borderColor: FortiFitColors.border) {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                Text(name)
                    .font(FortiFitTypography.dataValue)
                    .foregroundStyle(FortiFitColors.primaryText)
                ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                    Text(setLine(group: group))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FortiFitColors.mutedText)
                }
            }
        }
    }

    /// Formats a single set group: `{sets} × {reps_or_time}{ × weight}{ · rest Ns}`.
    /// Honors `displayAsTime` (renders reps as seconds), bodyweight (suppresses weight),
    /// and `useLbs` (converts kg → lbs). `restSeconds` appended only when present.
    ///
    /// `displayAsTime` resolution: explicit value on the snapshot wins; nil falls back to
    /// `ExerciseSuggestionService.isIsometric(...)` so older templates and templates whose
    /// authors didn't toggle the REPS/TIME control still render isometric exercises (Planks,
    /// Dead Hang, etc.) as time rather than reps.
    private func setLine(group: SnapshotExercise) -> String {
        let setsCount = group.sets
        let isTime = group.displayAsTime
            ?? ExerciseSuggestionService.isIsometric(group.exerciseName)
        let useLbs = UserSettings.shared.useLbs

        let repsToken: String
        if isTime {
            repsToken = "\(group.reps)s"
        } else {
            repsToken = "\(group.reps) reps"
        }

        var pieces: [String] = ["\(setsCount) × \(repsToken)"]

        if let weightKg = group.weightKg, weightKg > 0 {
            let displayWeight: String
            if useLbs {
                let lbs = weightKg * UnitConversion.kgToLbsFactor
                displayWeight = "\(Int(lbs.rounded())) lbs"
            } else {
                displayWeight = weightKg.truncatingRemainder(dividingBy: 1) == 0
                    ? "\(Int(weightKg)) kg"
                    : String(format: "%.1f kg", weightKg)
            }
            pieces.append(displayWeight)
        }

        if let rest = group.restSeconds, rest > 0 {
            pieces.append("rest \(rest)s")
        }

        return pieces.joined(separator: " · ")
    }

    @ViewBuilder
    private func actionRow(for row: ScheduledWorkout) -> some View {
        switch row.status {
        case "planned":
            Button {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                completionRPE = nil
                completionDuration = ""
                completionTarget = row
            } label: {
                Text("Complete Workout")
                    .font(FortiFitTypography.body)
                    .kerning(FortiFitTypography.labelKerning)
                    .frame(maxWidth: .infinity)
                    .frame(height: FortiFitSpacing.minTouchTarget)
                    .foregroundStyle(FortiFitColors.background)
                    .background(
                        RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                            .fill(FortiFitColors.primaryAccent)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.todaysPlanDetailSheet_rowCompleteButton(scheduledWorkoutId: row.id))
        default:
            // Completed and Skipped rows have no action row — the status pill in the top-right
            // is the sole completion signal.
            EmptyView()
        }
    }

    // MARK: - Actions

    private func handleRowTap(_ row: ScheduledWorkout) {
        switch row.status {
        case "completed":
            guard let completedId = row.completedWorkoutId else { return }
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                onNavigateToCompletedWorkout?(completedId)
            }
        default:
            break
        }
    }

    private func reload() {
        rows = PlanService.fetchTodaysScheduledWorkouts(context: modelContext)
    }
}
