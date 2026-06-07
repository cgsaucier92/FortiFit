import SwiftUI

struct FortiFitStatCard<Icon: View>: View {
    let icon: Icon
    let label: String
    let value: String
    let unit: String?
    let valueColor: Color
    let accessibilityID: String
    let onTap: () -> Void

    init(
        label: String,
        value: String,
        unit: String? = nil,
        valueColor: Color = FortiFitColors.primaryText,
        accessibilityIdentifier: String,
        onTap: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon
    ) {
        self.icon = icon()
        self.label = label
        self.value = value
        self.unit = unit
        self.valueColor = valueColor
        self.accessibilityID = accessibilityIdentifier
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    icon
                    Text(label)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FortiFitColors.primaryText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(FortiFitColors.mutedText)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(valueColor)
                    if let unit {
                        Text(unit)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(FortiFitColors.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(FortiFitColors.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(FortiFitColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(StatCardButtonStyle())
        .accessibilityIdentifier(accessibilityID)
        .accessibilityHint("Opens metric details")
    }
}

extension FortiFitStatCard where Icon == SymbolStatCardIcon {
    init(
        symbolName: String,
        label: String,
        value: String,
        unit: String? = nil,
        iconColor: Color = FortiFitColors.mutedText,
        valueColor: Color = FortiFitColors.primaryText,
        accessibilityIdentifier: String,
        onTap: @escaping () -> Void
    ) {
        self.init(
            label: label,
            value: value,
            unit: unit,
            valueColor: valueColor,
            accessibilityIdentifier: accessibilityIdentifier,
            onTap: onTap,
            icon: { SymbolStatCardIcon(symbolName: symbolName, color: iconColor) }
        )
    }
}

struct SymbolStatCardIcon: View {
    let symbolName: String
    let color: Color

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(color)
    }
}

private struct StatCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
