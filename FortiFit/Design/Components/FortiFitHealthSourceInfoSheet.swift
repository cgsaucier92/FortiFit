import SwiftUI

struct FortiFitHealthSourceInfoSheet: View {
    let workout: Workout
    let sourceName: String?
    let onUnlink: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: FortiFitSpacing.gapLarge) {
            VStack(spacing: FortiFitSpacing.gapSmall) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.pink)

                Text(workout.healthKitActivityType ?? "Workout")
                    .font(FortiFitTypography.screenHeading)
                    .foregroundStyle(FortiFitColors.primaryText)

                Text("This workout was imported from Apple Health via \(sourceName ?? "Apple Health").")
                    .font(FortiFitTypography.body)
                    .foregroundStyle(FortiFitColors.secondaryText)
                    .multilineTextAlignment(.center)
            }

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

            Button("Dismiss") {
                dismiss()
            }
            .tint(FortiFitColors.primaryAccent)
        }
        .padding(FortiFitSpacing.screenHorizontal)
        .presentationDetents([.medium])
        .presentationBackground(FortiFitColors.background)
    }
}
