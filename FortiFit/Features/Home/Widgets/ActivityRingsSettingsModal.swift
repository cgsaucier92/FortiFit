import SwiftUI

struct ActivityRingsSettingsModal: View {
    let activityService: AppleActivityService
    let onDismiss: () -> Void

    @State private var settings = UserSettings.shared

    private var moveValue: Binding<Double> {
        Binding(
            get: { Double(settings.targetMoveCalories ?? AppConstants.ActivityRings.moveDefault) },
            set: { settings.targetMoveCalories = AppConstants.ActivityRings.snapToIncrement(Int($0.rounded()), increment: Int(AppConstants.ActivityRings.moveIncrement)) }
        )
    }

    private var exerciseValue: Binding<Double> {
        Binding(
            get: { Double(settings.targetExerciseMinutes ?? AppConstants.ActivityRings.exerciseDefault) },
            set: { settings.targetExerciseMinutes = AppConstants.ActivityRings.snapToIncrement(Int($0.rounded()), increment: Int(AppConstants.ActivityRings.exerciseIncrement)) }
        )
    }

    private var standValue: Binding<Double> {
        Binding(
            get: { Double(settings.targetStandHours ?? AppConstants.ActivityRings.standDefault) },
            set: { settings.targetStandHours = Int($0.rounded()) }
        )
    }

    private var importDisabled: Bool {
        !settings.healthKitEnabled || !activityService.appleWatchDetected
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: FortiFitSpacing.gapLarge) {
                Text(AppConstants.ActivityRings.settingsModalHeading)
                    .font(FortiFitTypography.widgetHeader)
                    .kerning(FortiFitTypography.labelKerning)
                    .foregroundStyle(FortiFitColors.primaryAccent)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Move slider
                sliderCard(
                    label: AppConstants.ActivityRings.settingsModalMoveSliderLabel,
                    value: moveValue,
                    range: AppConstants.ActivityRings.moveRange,
                    step: AppConstants.ActivityRings.moveIncrement,
                    unit: AppConstants.ActivityRings.moveUnit,
                    tintColor: FortiFitColors.activityMoveRing,
                    identifier: AccessibilityID.activityRingsSettings_moveSlider
                )

                // Exercise slider
                sliderCard(
                    label: AppConstants.ActivityRings.settingsModalExerciseSliderLabel,
                    value: exerciseValue,
                    range: AppConstants.ActivityRings.exerciseRange,
                    step: AppConstants.ActivityRings.exerciseIncrement,
                    unit: AppConstants.ActivityRings.exerciseUnit,
                    tintColor: FortiFitColors.activityExerciseRing,
                    identifier: AccessibilityID.activityRingsSettings_exerciseSlider
                )

                // Stand slider
                sliderCard(
                    label: AppConstants.ActivityRings.settingsModalStandSliderLabel,
                    value: standValue,
                    range: AppConstants.ActivityRings.standRange,
                    step: AppConstants.ActivityRings.standIncrement,
                    unit: AppConstants.ActivityRings.standUnit,
                    tintColor: FortiFitColors.activityStandRing,
                    identifier: AccessibilityID.activityRingsSettings_standSlider
                )

                // Phase 8.8: Import from Apple Health is now first action (directly below Stand slider)
                VStack(spacing: FortiFitSpacing.elementSpacing) {
                    FortiFitButton(AppConstants.ActivityRings.settingsModalImportButton, style: .primary) {
                        Task {
                            await activityService.importGoalsFromAppleHealth()
                        }
                    }
                    .opacity(importDisabled ? 0.4 : 1.0)
                    .disabled(importDisabled)
                    .accessibilityIdentifier(AccessibilityID.activityRingsSettings_importButton)

                    if importDisabled {
                        Text(AppConstants.ActivityRings.settingsModalImportDisabledCaption)
                            .font(FortiFitTypography.note)
                            .foregroundStyle(FortiFitColors.mutedText)
                    }
                }

                // Phase 8.8: Done button (outlined) replaces the previous Reset to defaults button
                FortiFitButton(AppConstants.SettingsModal.doneButtonLabel, style: .outline) {
                    onDismiss()
                }
                .accessibilityIdentifier(AccessibilityID.activityRingsSettings_doneButton)
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

    // MARK: - Slider Card

    private func sliderCard(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String,
        tintColor: Color,
        identifier: String
    ) -> some View {
        FortiFitCard(borderColor: FortiFitColors.border) {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                HStack {
                    Text(label)
                        .font(FortiFitTypography.tabLabel)
                        .foregroundStyle(FortiFitColors.primaryText)
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(value.wrappedValue))")
                            .font(FortiFitTypography.largeValue)
                            .foregroundStyle(tintColor)
                        Text(unit)
                            .font(FortiFitTypography.bodySmall)
                            .foregroundStyle(FortiFitColors.mutedText)
                    }
                }
                Slider(value: value, in: range, step: step)
                    .tint(tintColor)
                    .accessibilityIdentifier(identifier)
            }
        }
    }

}
