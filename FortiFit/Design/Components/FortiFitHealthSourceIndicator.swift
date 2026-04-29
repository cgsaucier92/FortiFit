import SwiftUI

struct FortiFitHealthSourceIndicator: View {
    let activityType: String
    let sourceName: String?
    var showGlyph: Bool = false

    private var displaySourceName: String {
        sourceName ?? "another app"
    }

    var body: some View {
        HStack(spacing: 4) {
            Text("\(activityType) · \(displaySourceName)")
                .font(.system(size: 11, weight: .bold))
                .kerning(2)
                .foregroundStyle(FortiFitColors.mutedText)
            if showGlyph {
                FortiFitHealthGlyph()
            }
        }
        .accessibilityIdentifier(AccessibilityID.workoutDetailHealthSourceIndicator)
    }
}
