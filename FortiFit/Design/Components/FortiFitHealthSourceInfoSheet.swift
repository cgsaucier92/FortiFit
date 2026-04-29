import SwiftUI

struct FortiFitHealthSourceInfoSheet: View {
    let workout: Workout
    let sourceName: String?
    let onUnlink: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var displaySourceName: String {
        sourceName ?? "another app"
    }

    var body: some View {
        VStack(spacing: FortiFitSpacing.gapLarge) {
            VStack(spacing: FortiFitSpacing.gapSmall) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.pink)

                Text("Imported from Apple Health")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(FortiFitColors.primaryText)
                    .multilineTextAlignment(.center)

                Text("This workout was imported from Apple Health via \(displaySourceName). Measured values like duration, distance, heart rate, and calories are sourced from Apple Health and cannot be edited here.")
                    .font(.system(size: 14))
                    .foregroundStyle(FortiFitColors.secondaryText)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                if let activityType = workout.healthKitActivityType {
                    HStack {
                        Text("Activity Type:")
                            .font(FortiFitTypography.bodySmall)
                            .foregroundStyle(FortiFitColors.mutedText)
                        Text(activityType)
                            .font(FortiFitTypography.body)
                            .foregroundStyle(FortiFitColors.primaryText)
                    }
                }
                HStack {
                    Text("Source:")
                        .font(FortiFitTypography.bodySmall)
                        .foregroundStyle(FortiFitColors.mutedText)
                    Text(displaySourceName)
                        .font(FortiFitTypography.body)
                        .foregroundStyle(FortiFitColors.primaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(role: .destructive) {
                onUnlink()
                dismiss()
            } label: {
                Text("Unlink from Apple Health")
                    .font(FortiFitTypography.body.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FortiFitSpacing.elementSpacing)
                    .background(FortiFitColors.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadiusSmall))
            }
            .accessibilityIdentifier(AccessibilityID.workoutDetailHealthUnlinkButton)

            Button("Done") {
                dismiss()
            }
            .tint(FortiFitColors.primaryAccent)
        }
        .padding(FortiFitSpacing.screenHorizontal)
        .presentationDetents([.medium])
        .presentationBackground(FortiFitColors.background)
    }
}
