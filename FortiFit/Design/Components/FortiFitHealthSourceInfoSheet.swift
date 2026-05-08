import SwiftUI

struct FortiFitHealthSourceInfoSheet: View {
    let workout: Workout
    let sourceName: String?
    let lastSyncDate: Date?
    let onUnlink: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var displaySourceName: String {
        sourceName ?? AppConstants.HealthKit.unknownSourceName
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FortiFitSpacing.gapLarge) {
                // 1. Header icon
                Image(systemName: AppConstants.HealthKit.infoSheetHeaderIcon)
                    .font(.system(size: 32))
                    .foregroundStyle(Color(hex: "FF2D55"))

                // 2. Title
                Text(AppConstants.HealthKit.infoSheetTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(FortiFitColors.primaryText)
                    .multilineTextAlignment(.center)

                // 3. Lead sentence
                Text(AppConstants.HealthKit.infoSheetLead)
                    .font(.system(size: 14))
                    .foregroundStyle(FortiFitColors.secondaryText)
                    .multilineTextAlignment(.center)

                // 4. Two-row callout card
                VStack(spacing: FortiFitSpacing.elementSpacing) {
                    calloutRow(
                        icon: AppConstants.HealthKit.infoSheetReadOnlyIcon,
                        iconColor: FortiFitColors.mutedText,
                        headline: AppConstants.HealthKit.infoSheetReadOnlyHeadline,
                        subline: AppConstants.HealthKit.infoSheetReadOnlySubline,
                        identifier: AccessibilityID.sourceInfoSheetReadOnlyCallout
                    )

                    calloutRow(
                        icon: AppConstants.HealthKit.infoSheetPermanentIcon,
                        iconColor: FortiFitColors.alert,
                        headline: AppConstants.HealthKit.infoSheetPermanentHeadline,
                        subline: AppConstants.HealthKit.infoSheetPermanentSubline,
                        identifier: AccessibilityID.sourceInfoSheetPermanentUnlinkCallout
                    )
                }

                // 5. Primary safe action — Done
                FortiFitButton(AppConstants.HealthKit.infoSheetDoneButton, style: .outline) {
                    dismiss()
                }
                .accessibilityIdentifier(AccessibilityID.sourceInfoSheetDoneButton)

                // 6. Demoted destructive link — Unlink (no confirmation; the sheet itself warns)
                Button {
                    onUnlink()
                    dismiss()
                } label: {
                    Text(AppConstants.HealthKit.infoSheetUnlinkLink)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FortiFitColors.alert)
                }
                .accessibilityIdentifier(AccessibilityID.workoutDetailHealthUnlinkButton)

                // 8. Footer metadata
                footerMetadata
            }
            .padding(FortiFitSpacing.screenHorizontal)
            .padding(.bottom, FortiFitSpacing.gapXLarge)
        }
        .presentationDetents([.large])
        .presentationBackground(FortiFitColors.background)
    }

    // MARK: - Callout Row

    private func calloutRow(
        icon: String,
        iconColor: Color,
        headline: String,
        subline: String,
        identifier: String
    ) -> some View {
        HStack(alignment: .top, spacing: FortiFitSpacing.gapSmall) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FortiFitColors.primaryText)
                Text(subline)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(FortiFitColors.mutedText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FortiFitSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                .fill(FortiFitColors.cardSurface)
                .stroke(FortiFitColors.border, lineWidth: 1)
        )
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Footer Metadata

    private var footerMetadata: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let activityType = workout.healthKitActivityType {
                footerRow(label: AppConstants.HealthKit.infoSheetActivityTypeLabel, value: activityType)
            }
            footerRow(label: AppConstants.HealthKit.infoSheetSourceLabel, value: displaySourceName)
            footerRow(
                label: AppConstants.HealthKit.infoSheetImportedLabel,
                value: workout.date.formatted(date: .abbreviated, time: .shortened)
            )
            if let syncDate = lastSyncDate {
                footerRow(
                    label: AppConstants.HealthKit.infoSheetLastSyncedLabel,
                    value: syncDate.formatted(.relative(presentation: .named))
                )
                .accessibilityIdentifier(AccessibilityID.sourceInfoSheetLastSyncedRow)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func footerRow(label: String, value: String) -> some View {
        Text("\(label) · \(value)")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(FortiFitColors.mutedText)
    }
}
