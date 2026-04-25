import SwiftUI

struct FortiFitSegmentedToggle: View {
    let options: [String]
    @Binding var selected: String
    var accessibilityIdentifier: String?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button {
                    selected = option
                } label: {
                    Text(option.uppercased())
                        .font(FortiFitTypography.bodySmall)
                        .kerning(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .foregroundStyle(
                            selected == option
                                ? FortiFitColors.primaryText
                                : FortiFitColors.mutedText
                        )
                        .background(
                            selected == option
                                ? FortiFitColors.primaryAccent
                                : FortiFitColors.elevatedSurface
                        )
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadiusSmall))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
        .accessibilityValue(selected)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var selection = "KG"
        var body: some View {
            FortiFitSegmentedToggle(
                options: ["KG", "LBS"],
                selected: $selection
            )
            .padding()
            .background(FortiFitColors.background)
        }
    }
    return PreviewWrapper()
}
