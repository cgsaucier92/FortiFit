import SwiftUI

struct FortiFitSeeInfoModal: View {
    let content: AppConstants.ChartInfoCopy
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FortiFitColors.mutedText)
                            .frame(
                                width: FortiFitSpacing.minTouchTarget,
                                height: FortiFitSpacing.minTouchTarget
                            )
                    }
                    .accessibilityIdentifier(AccessibilityID.seeInfoModal_closeButton)
                    .accessibilityLabel("Close")
                }

                Text(content.title)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(FortiFitColors.primaryAccent)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(content.intro)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FortiFitColors.secondaryText)
                    .padding(.top, 24)

                ForEach(Array(content.sections.enumerated()), id: \.offset) { _, section in
                    Text(section.heading)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(FortiFitColors.primaryText)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 24)
                        .padding(.bottom, 8)

                    sectionBody(section.body)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, FortiFitSpacing.gapXLarge)
        }
        .background(FortiFitColors.cardSurface)
    }

    @ViewBuilder
    private func sectionBody(_ text: String) -> some View {
        let lines = text.components(separatedBy: "\n")
        let bulletPrefix = "- "

        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if line.hasPrefix(bulletPrefix) {
                    HStack(alignment: .top, spacing: 4) {
                        Text("•")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FortiFitColors.secondaryText)
                        Text(String(line.dropFirst(bulletPrefix.count)))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FortiFitColors.secondaryText)
                    }
                    .padding(.leading, 8)
                } else {
                    Text(line)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FortiFitColors.secondaryText)
                }
            }
        }
    }
}
