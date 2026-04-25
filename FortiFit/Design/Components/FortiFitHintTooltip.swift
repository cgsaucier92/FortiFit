import SwiftUI

struct FortiFitHintTooltip: View {
    let message: String
    @Binding var isVisible: Bool

    var body: some View {
        Button {
            isVisible.toggle()
        } label: {
            Text("?")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(FortiFitColors.mutedText)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .stroke(FortiFitColors.mutedText, lineWidth: 1)
                )
        }
        .frame(minWidth: FortiFitSpacing.minTouchTarget, minHeight: FortiFitSpacing.minTouchTarget)
        .popover(isPresented: $isVisible) {
            Text(message)
                .font(FortiFitTypography.note)
                .foregroundStyle(FortiFitColors.secondaryText)
                .padding(FortiFitSpacing.cardPadding)
                .presentationCompactAdaptation(.popover)
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var show = false
        var body: some View {
            FortiFitHintTooltip(
                message: "Training load measures your daily training stress",
                isVisible: $show
            )
            .padding()
            .background(FortiFitColors.background)
        }
    }
    return PreviewWrapper()
}
