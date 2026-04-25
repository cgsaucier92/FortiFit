import SwiftUI

struct FortiFitInput: View {
    let placeholder: String
    @Binding var text: String
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        TextField(placeholder, text: $text)
            .font(FortiFitTypography.body)
            .foregroundStyle(isEnabled ? FortiFitColors.primaryText : FortiFitColors.mutedText)
            .padding(.horizontal, FortiFitSpacing.cardPadding)
            .frame(height: FortiFitSpacing.minTouchTarget)
            .background(
                RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadiusSmall)
                    .fill(isEnabled ? FortiFitColors.elevatedSurface : FortiFitColors.elevatedSurface.opacity(0.5))
            )
            .tint(FortiFitColors.primaryAccent)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var text = ""
        var body: some View {
            FortiFitInput(placeholder: "e.g. Push Day IV", text: $text)
                .padding()
                .background(FortiFitColors.background)
        }
    }
    return PreviewWrapper()
}
