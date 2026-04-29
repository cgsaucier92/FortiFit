import SwiftUI

struct FortiFitStatCard: View {
    let symbolName: String
    let label: String
    let value: String
    let unit: String?
    let accessibilityID: String
    let onTap: () -> Void

    init(
        symbolName: String,
        label: String,
        value: String,
        unit: String? = nil,
        accessibilityIdentifier: String,
        onTap: @escaping () -> Void
    ) {
        self.symbolName = symbolName
        self.label = label
        self.value = value
        self.unit = unit
        self.accessibilityID = accessibilityIdentifier
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: symbolName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(FortiFitColors.mutedText)
                    Text(label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(FortiFitColors.mutedText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(FortiFitColors.mutedText)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(FortiFitColors.primaryText)
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

private struct StatCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
