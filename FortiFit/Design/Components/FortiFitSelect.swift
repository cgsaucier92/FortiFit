import SwiftUI

struct FortiFitSelect: View {
    let options: [String]
    @Binding var selected: String
    var placeholder: String
    var accessibilityIdentifier: String?
    var optionIdentifierPrefix: String?
    @Environment(\.isEnabled) private var isEnabled
    @State private var isExpanded = false

    init(
        options: [String],
        selected: Binding<String>,
        placeholder: String = "Select...",
        accessibilityIdentifier: String? = nil,
        optionIdentifierPrefix: String? = nil
    ) {
        self.options = options
        self._selected = selected
        self.placeholder = placeholder
        self.accessibilityIdentifier = accessibilityIdentifier
        self.optionIdentifierPrefix = optionIdentifierPrefix
    }

    var body: some View {
        VStack(spacing: 0) {
            // Trigger button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(selected.isEmpty ? placeholder : selected)
                        .font(FortiFitTypography.body)
                        .foregroundStyle(
                            !isEnabled
                                ? FortiFitColors.mutedText
                                : selected.isEmpty
                                    ? FortiFitColors.mutedText
                                    : FortiFitColors.primaryText
                        )
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isEnabled ? FortiFitColors.primaryAccent : FortiFitColors.mutedText)
                        .rotationEffect(.degrees(isExpanded ? -180 : 0))
                }
                .padding(.horizontal, FortiFitSpacing.cardPadding)
                .frame(height: FortiFitSpacing.minTouchTarget)
                .background(
                    RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadiusSmall)
                        .fill(isEnabled ? FortiFitColors.elevatedSurface : FortiFitColors.elevatedSurface.opacity(0.5))
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(accessibilityIdentifier ?? "")

            // Inline dropdown
            if isExpanded {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(options, id: \.self) { option in
                                Button {
                                    selected = option
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isExpanded = false
                                    }
                                } label: {
                                    HStack {
                                        Text(option)
                                            .font(FortiFitTypography.body)
                                            .foregroundStyle(
                                                option == selected
                                                    ? FortiFitColors.primaryAccent
                                                    : FortiFitColors.primaryText
                                            )
                                        Spacer()
                                        if option == selected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(FortiFitColors.primaryAccent)
                                        }
                                    }
                                    .padding(.horizontal, FortiFitSpacing.cardPadding)
                                    .frame(height: FortiFitSpacing.minTouchTarget)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier(
                                    optionIdentifierPrefix.map {
                                        AccessibilityID.optionIdentifier(prefix: $0, option: option)
                                    } ?? ""
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
                .background(
                    RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadiusSmall)
                        .fill(FortiFitColors.elevatedSurface)
                )
                .clipShape(RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadiusSmall))
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var value = ""
        var body: some View {
            FortiFitSelect(
                options: ["Strength Training", "HIIT", "Cardio"],
                selected: $value,
                placeholder: "Workout Type"
            )
            .padding()
            .background(FortiFitColors.background)
        }
    }
    return PreviewWrapper()
}
