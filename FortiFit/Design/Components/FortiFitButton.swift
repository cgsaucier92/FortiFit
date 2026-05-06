import SwiftUI

struct FortiFitButton: View {
    let title: String
    var style: ButtonStyle
    var isEnabled: Bool
    let action: () -> Void

    enum ButtonStyle {
        case primary    // Blue background, dark text
        case outline    // Blue border, blue text
        case secondary  // Surface background, muted text
    }

    init(
        _ title: String,
        style: ButtonStyle = .primary,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(FortiFitTypography.body)
                .kerning(FortiFitTypography.labelKerning)
                .frame(maxWidth: .infinity)
                .frame(height: FortiFitSpacing.minTouchTarget)
                .foregroundStyle(foregroundColor)
                .background(
                    RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                        .fill(backgroundColor)
                        .stroke(borderColor, lineWidth: 1)
                )
                .animation(.easeInOut(duration: 0.2), value: isEnabled)
        }
        .disabled(!isEnabled)
    }

    private var foregroundColor: Color {
        guard isEnabled else { return FortiFitColors.mutedText }
        switch style {
        case .primary: return FortiFitColors.background
        case .outline: return FortiFitColors.primaryAccent
        case .secondary: return FortiFitColors.primaryText
        }
    }

    private var backgroundColor: Color {
        guard isEnabled else { return FortiFitColors.elevatedSurface }
        switch style {
        case .primary: return FortiFitColors.primaryAccent
        case .outline: return .clear
        case .secondary: return FortiFitColors.elevatedSurface
        }
    }

    private var borderColor: Color {
        guard isEnabled else { return FortiFitColors.border }
        switch style {
        case .primary: return .clear
        case .outline: return FortiFitColors.primaryAccent
        case .secondary: return FortiFitColors.border
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        FortiFitButton("Save Workout", style: .primary) {}
        FortiFitButton("Log Workout", style: .outline) {}
        FortiFitButton("Cancel", style: .secondary) {}
        FortiFitButton("Disabled", isEnabled: false) {}
    }
    .padding()
    .background(FortiFitColors.background)
}

