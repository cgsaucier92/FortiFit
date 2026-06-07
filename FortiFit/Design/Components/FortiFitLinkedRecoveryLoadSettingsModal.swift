import SwiftUI

/// Combined settings modal for the linked Recovery & Load composite (Phase 11).
/// Three sliders (Training Experience, Target Workout Duration, Sleep Target) +
/// Import from Apple Health (Sleep Target only) + Done. See SCREENS.md §
/// Linked Recovery & Load Settings Modal and CONSTANTS.md § Linked Recovery & Load
/// Settings Modal.
struct FortiFitLinkedRecoveryLoadSettingsModal: View {
    var onDismiss: () -> Void
    var onImportFromAppleHealth: () async -> Void

    @State private var settings = UserSettings.shared
    @State private var toastMessage: String?

    private var hkConnected: Bool { settings.healthKitEnabled }

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: FortiFitSpacing.gapLarge) {
                Text("Configure Recovery & Load")
                    .font(FortiFitTypography.widgetHeader)
                    .kerning(FortiFitTypography.labelKerning)
                    .foregroundStyle(FortiFitColors.primaryAccent)
                    .frame(maxWidth: .infinity, alignment: .leading)

                experienceCard
                targetWorkoutDurationCard
                sleepTargetCard
                importFromAppleHealthRow

                FortiFitButton("Done", style: .outline) {
                    onDismiss()
                }
                .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadSettings_doneButton)
            }
            .padding(FortiFitSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                    .fill(FortiFitColors.cardSurface)
                    .stroke(FortiFitColors.border, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FortiFitColors.mutedText)
                        .frame(
                            width: FortiFitSpacing.minTouchTarget,
                            height: FortiFitSpacing.minTouchTarget
                        )
                }
                .padding([.top, .trailing], FortiFitSpacing.cardPadding / 2)
                .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadSettings_closeButton)
            }
            .padding(.horizontal, FortiFitSpacing.screenHorizontal + 8)
            .overlay(alignment: .top) {
                if let toast = toastMessage {
                    Text(toast)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FortiFitColors.primaryText)
                        .padding(.horizontal, FortiFitSpacing.cardPadding)
                        .padding(.vertical, FortiFitSpacing.elementSpacing)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(FortiFitColors.elevatedSurface)
                                .stroke(FortiFitColors.border, lineWidth: 1)
                        )
                        .offset(y: -32)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: toastMessage)
        }
        .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadSettings_modal)
    }

    // MARK: - Experience card

    private var experienceCard: some View {
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
                .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadSettings_experienceLevelSlider)
                // BUG-081: .lineLimit(1) + .fixedSize keep INTERMEDIATE on a single line
                // on 393pt-class devices (HStack would otherwise propose ~⅓ width per Text
                // and force the middle label to wrap mid-word).
                HStack {
                    Text("BEGINNER")
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer()
                    Text("INTERMEDIATE")
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer()
                    Text("ADVANCED")
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .font(FortiFitTypography.labelSmall)
                .kerning(FortiFitTypography.labelKerning)
                .foregroundStyle(FortiFitColors.mutedText)
            }
        }
    }

    // MARK: - Workout duration card

    private var targetWorkoutDurationCard: some View {
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
                .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadSettings_targetWorkoutDurationSlider)
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

    // MARK: - Sleep target card

    private var sleepTargetCard: some View {
        FortiFitCard(borderColor: FortiFitColors.border) {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                HStack {
                    Text("Sleep Target")
                        .font(FortiFitTypography.tabLabel)
                        .foregroundStyle(FortiFitColors.primaryText)
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(formattedHours(settings.targetSleepHours))
                            .font(FortiFitTypography.largeValue)
                            .foregroundStyle(FortiFitColors.primaryAccent)
                        Text("hrs")
                            .font(FortiFitTypography.bodySmall)
                            .foregroundStyle(FortiFitColors.mutedText)
                    }
                }
                Slider(
                    value: Binding(
                        get: { settings.targetSleepHours },
                        set: { newValue in
                            let snapped = (newValue * 2.0).rounded() / 2.0
                            settings.targetSleepHours = min(max(snapped, 4.0), 12.0)
                        }
                    ),
                    in: 4.0...12.0,
                    step: 0.5
                )
                .tint(FortiFitColors.primaryAccent)
                .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadSettings_targetSleepHoursSlider)
                HStack {
                    Text("4 HRS")
                    Spacer()
                    Text("12 HRS")
                }
                .font(FortiFitTypography.labelSmall)
                .kerning(FortiFitTypography.labelKerning)
                .foregroundStyle(FortiFitColors.mutedText)
            }
        }
    }

    private func formattedHours(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    // MARK: - Import row

    /// Matches the Activity Rings Settings Modal — full-width filled primary button,
    /// dim/disable when HK is not connected, muted caption below.
    private var importFromAppleHealthRow: some View {
        VStack(spacing: FortiFitSpacing.elementSpacing) {
            FortiFitButton("Import from Apple Health", style: .primary) {
                Task {
                    await onImportFromAppleHealth()
                    if let recovery = RecoveryStatusService.current,
                       let toast = recovery.lastToastMessage {
                        toastMessage = toast
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        toastMessage = nil
                    }
                }
            }
            .opacity(hkConnected ? 1.0 : 0.4)
            .disabled(!hkConnected)
            .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadSettings_importButton)

            if !hkConnected {
                Text("Connect Apple Health to import your goal.")
                    .font(FortiFitTypography.note)
                    .foregroundStyle(FortiFitColors.mutedText)
            }
        }
    }
}
