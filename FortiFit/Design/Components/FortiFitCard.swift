import SwiftUI

struct FortiFitCard<Content: View>: View {
    var borderColor: Color
    var borderWidth: CGFloat
    let content: () -> Content

    init(
        borderColor: Color = FortiFitColors.border,
        borderWidth: CGFloat = 1,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.content = content
    }

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FortiFitSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                    .fill(FortiFitColors.cardSurface)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
    }
}

// MARK: - Pressable Card Button Style

/// Button style that provides subtle scale and brightness feedback on press,
/// hinting that the card supports long-press interactions (e.g., context menus).
struct PressableCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .brightness(configuration.isPressed ? 0.04 : 0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    FortiFitCard {
        Text("Sample Card")
            .font(FortiFitTypography.body)
            .foregroundStyle(FortiFitColors.primaryText)
    }
    .padding()
    .background(FortiFitColors.background)
}
