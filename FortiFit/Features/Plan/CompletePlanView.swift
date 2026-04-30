import SwiftUI

struct CompletePlanView: View {
    let scheduledWorkout: ScheduledWorkout?
    @Binding var completionRPE: Int?
    @Binding var completionDuration: String
    var onSave: () -> Void
    var onModifyExercises: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.gapLarge) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Text(scheduledWorkout?.workoutName ?? "Workout")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(FortiFitColors.primaryText)
                    Text("— \(Date.now.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(FortiFitColors.primaryText)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FortiFitColors.mutedText)
                        .frame(width: FortiFitSpacing.minTouchTarget, height: FortiFitSpacing.minTouchTarget)
                }
            }

            // RPE selector
            VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
                Text("Effort")
                    .font(.system(size: 16, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(FortiFitColors.primaryText)

                HStack(spacing: 6) {
                    ForEach(1...10, id: \.self) { value in
                        Button {
                            if completionRPE == value {
                                completionRPE = nil
                            } else {
                                completionRPE = value
                            }
                        } label: {
                            Text("\(value)")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 34, height: 34)
                                .foregroundStyle(
                                    completionRPE == value
                                        ? FortiFitColors.primaryText
                                        : FortiFitColors.mutedText
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            completionRPE == value
                                                ? FortiFitColors.primaryAccent
                                                : FortiFitColors.elevatedSurface
                                        )
                                )
                        }
                    }
                }
            }

            // Duration input
            VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
                Text("Duration")
                    .font(.system(size: 16, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(FortiFitColors.primaryText)

                HStack(spacing: FortiFitSpacing.elementSpacing) {
                    FortiFitInput(placeholder: "Optional", text: $completionDuration)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .frame(width: 120)
                    Text("min")
                        .font(FortiFitTypography.bodySmall)
                        .foregroundStyle(FortiFitColors.mutedText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Save button
            FortiFitButton("Save Workout", style: .primary) {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                onSave()
                dismiss()
            }

            // Modify Exercises button
            FortiFitButton("Modify Exercises", style: .outline) {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                onModifyExercises()
            }
        }
        .padding(FortiFitSpacing.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
