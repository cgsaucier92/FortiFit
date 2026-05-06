import SwiftUI

struct FortiFitHealthSourceIndicator: View {
    let sourceName: String?
    var showGlyph: Bool = false

    private var displaySourceName: String {
        sourceName ?? "another app"
    }

    var body: some View {
        HStack(spacing: 4) {
            if showGlyph {
                FortiFitHealthGlyph()
            }
            Text(displaySourceName)
                .font(.system(size: 14, weight: .semibold))
                .kerning(2)
                .foregroundStyle(FortiFitColors.mutedText)
        }
        .accessibilityElement(children: .combine)
    }
}
