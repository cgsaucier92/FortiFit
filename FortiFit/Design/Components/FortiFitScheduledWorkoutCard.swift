import SwiftUI

struct FortiFitScheduledWorkoutCard: View {
    let scheduledWorkout: ScheduledWorkout
    var onComplete: () -> Void
    var onSkip: () -> Void
    var onRestore: () -> Void
    var onRemoveFromPlan: () -> Void
    var isCompletedHealthKitLinked: Bool = false
    var onTap: (() -> Void)? = nil
    var watchSyncGlyphState: FortiFitWatchSyncGlyph.State? = nil
    var onWatchSyncTap: (() -> Void)? = nil
    var onEditWorkout: (() -> Void)? = nil
    var cardIndex: Int = 0
    var gatePopoverTitle: String? = nil
    var gatePopoverBody: String? = nil
    var gatePopoverButtonLabel: String? = nil
    var onGatePopoverButton: (() -> Void)? = nil

    @State private var showGatePopover = false

    private var isOverdue: Bool {
        scheduledWorkout.status == "planned" &&
        Calendar.current.startOfDay(for: scheduledWorkout.scheduledDate) < Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        Button(action: { onTap?() }) {
        FortiFitCard(borderColor: cardBorderColor) {
            VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
                // Workout name + watch sync glyph
                HStack(alignment: .top) {
                    Text(scheduledWorkout.workoutName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(nameColor)
                        .strikethrough(scheduledWorkout.status == "skipped")

                    Spacer()

                    if let glyphState = watchSyncGlyphState, scheduledWorkout.status != "completed" {
                        FortiFitWatchSyncGlyph(state: glyphState) {
                            if glyphState == .disabled, gatePopoverBody != nil {
                                showGatePopover = true
                            } else {
                                onWatchSyncTap?()
                            }
                        }
                        .popover(isPresented: $showGatePopover) {
                            VStack(alignment: .leading, spacing: 8) {
                                if let title = gatePopoverTitle {
                                    Text(title)
                                        .font(FortiFitTypography.label)
                                        .foregroundStyle(FortiFitColors.primaryText)
                                }
                                if let body = gatePopoverBody {
                                    Text(body)
                                        .font(FortiFitTypography.bodySmall)
                                        .foregroundStyle(FortiFitColors.primaryText)
                                }
                                if let buttonLabel = gatePopoverButtonLabel {
                                    Button(buttonLabel) {
                                        showGatePopover = false
                                        onGatePopoverButton?()
                                    }
                                    .font(FortiFitTypography.bodySmall)
                                    .foregroundStyle(FortiFitColors.primaryAccent)
                                    .accessibilityIdentifier(AccessibilityID.masterSyncOff_openSettingsButton)
                                }
                            }
                            .padding()
                            .frame(width: 280)
                            .fixedSize(horizontal: false, vertical: true)
                            .presentationCompactAdaptation(.popover)
                            .accessibilityIdentifier(AccessibilityID.masterSyncOff_popover)
                        }
                        .accessibilityIdentifier(AccessibilityID.scheduledWorkoutCardWatchSyncGlyph(cardIndex))
                    }
                }

                // Workout type pill
                HStack(spacing: 0) {
                    Text(scheduledWorkout.workoutType.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(FortiFitColors.mutedText)

                    if scheduledWorkout.status == "completed" {
                        Text(" · PLANNED SESSION")
                            .font(.system(size: 11, weight: .bold))
                            .kerning(2)
                            .foregroundStyle(FortiFitColors.mutedText)
                    }
                }

                // Overdue badge
                if isOverdue {
                    Text("OVERDUE")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(FortiFitColors.mutedText)
                }

                // Duration & time + trailing glyph
                HStack(spacing: FortiFitSpacing.elementSpacing) {
                    if let duration = scheduledWorkout.durationMinutes {
                        Text("\(duration) min")
                            .font(FortiFitTypography.bodySmall)
                            .foregroundStyle(FortiFitColors.mutedText)
                    }
                    if scheduledWorkout.durationMinutes != nil && scheduledWorkout.scheduledTime != nil {
                        Text("·")
                            .font(FortiFitTypography.bodySmall)
                            .foregroundStyle(FortiFitColors.mutedText)
                    }
                    if let time = scheduledWorkout.scheduledTime {
                        Text(time.timeFormatted)
                            .font(FortiFitTypography.bodySmall)
                            .foregroundStyle(FortiFitColors.mutedText)
                    }
                    if isCompletedHealthKitLinked && scheduledWorkout.status == "completed" {
                        Text("·")
                            .font(FortiFitTypography.bodySmall)
                            .foregroundStyle(FortiFitColors.mutedText)
                        Text("Apple Workout")
                            .font(FortiFitTypography.bodySmall)
                            .foregroundStyle(FortiFitColors.mutedText)
                    }
                }

                // Status-dependent bottom area
                switch scheduledWorkout.status {
                case "completed":
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(FortiFitColors.positive)
                            .font(.system(size: 14))
                        Text("COMPLETED")
                            .font(.system(size: 11, weight: .bold))
                            .kerning(2)
                            .foregroundStyle(FortiFitColors.positive)
                    }
                    .frame(maxWidth: .infinity, minHeight: FortiFitSpacing.minTouchTarget, alignment: .leading)

                case "skipped":
                    Text("SKIPPED")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(FortiFitColors.mutedText)

                default: // planned
                    FortiFitButton("Complete Workout", style: .outline) {
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        onComplete()
                    }
                }
            }
        }
        }
        .buttonStyle(PressableCardButtonStyle())
        .contentShape(RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius))
        .contextMenu {
            contextMenuItems
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        switch scheduledWorkout.status {
        case "planned":
            if onEditWorkout != nil {
                Button {
                    onEditWorkout?()
                } label: {
                    Label("Edit Planned Workout", systemImage: "pencil")
                }
                .accessibilityIdentifier(AccessibilityID.planScheduledCardEditMenuItem)
            }

            Button {
                onSkip()
            } label: {
                Label("Skip Workout", systemImage: "forward.end")
            }
            .accessibilityIdentifier(AccessibilityID.planScheduledCardSkipMenuItem)

            Button(role: .destructive) {
                onRemoveFromPlan()
            } label: {
                Label("Remove from Plan", systemImage: "minus.circle")
            }
            .accessibilityIdentifier(AccessibilityID.planRemoveFromPlanMenuItem)

        case "skipped":
            if onEditWorkout != nil {
                Button {
                    onEditWorkout?()
                } label: {
                    Label("Edit Planned Workout", systemImage: "pencil")
                }
                .accessibilityIdentifier(AccessibilityID.planScheduledCardEditMenuItem)
            }

            Button {
                onRestore()
            } label: {
                Label("Restore Workout", systemImage: "arrow.uturn.backward")
            }
            .accessibilityIdentifier(AccessibilityID.planScheduledCardRestoreMenuItem)

            Button(role: .destructive) {
                onRemoveFromPlan()
            } label: {
                Label("Remove from Plan", systemImage: "minus.circle")
            }
            .accessibilityIdentifier(AccessibilityID.planRemoveFromPlanMenuItem)

        case "completed":
            Button {
                onRemoveFromPlan()
            } label: {
                Label("Remove from Plan", systemImage: "minus.circle")
            }
            .accessibilityIdentifier(AccessibilityID.planRemoveFromPlanMenuItem)

        default:
            EmptyView()
        }
    }

    private var nameColor: Color {
        scheduledWorkout.status == "skipped" ? FortiFitColors.mutedText : FortiFitColors.primaryText
    }

    private var cardBorderColor: Color {
        switch scheduledWorkout.status {
        case "completed": return FortiFitColors.positive
        case "skipped": return FortiFitColors.border.opacity(0.5)
        default: return FortiFitColors.border
        }
    }
}

// MARK: - Logged-Only Workout Card

struct FortiFitLoggedWorkoutCard: View {
    let workout: Workout
    var onRemoveFromPlan: () -> Void
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
        FortiFitCard(borderColor: FortiFitColors.positive) {
            VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
                // Workout name
                Text(workout.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FortiFitColors.primaryText)

                // Workout type pill + LOGGED affordance
                HStack(spacing: 0) {
                    Text(workout.workoutType.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(FortiFitColors.mutedText)

                    Text(" · LOGGED SESSION")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(FortiFitColors.mutedText)
                }

                // Metadata row: duration + trailing glyph
                let hasDuration = workout.durationMinutes != nil
                let hasGlyph = workout.isAppleWatchSourced
                if hasDuration || hasGlyph {
                    HStack(spacing: FortiFitSpacing.elementSpacing) {
                        if let duration = workout.durationMinutes {
                            Text("\(duration) min")
                                .font(FortiFitTypography.bodySmall)
                                .foregroundStyle(FortiFitColors.mutedText)
                        }
                        if hasGlyph {
                            Text("·")
                                .font(FortiFitTypography.bodySmall)
                                .foregroundStyle(FortiFitColors.mutedText)
                            Text("Apple Workout")
                                .font(FortiFitTypography.bodySmall)
                                .foregroundStyle(FortiFitColors.mutedText)
                        }
                    }
                }

                // Completed indicator
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(FortiFitColors.positive)
                        .font(.system(size: 14))
                    Text("COMPLETED")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(FortiFitColors.positive)
                }
                .frame(maxWidth: .infinity, minHeight: FortiFitSpacing.minTouchTarget, alignment: .leading)
            }
        }
        }
        .buttonStyle(PressableCardButtonStyle())
        .contentShape(RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius))
        .contextMenu {
            Button {
                onRemoveFromPlan()
            } label: {
                Label("Remove from Plan", systemImage: "minus.circle")
            }
            .accessibilityIdentifier(AccessibilityID.planRemoveFromPlanMenuItem)
        }
    }
}
