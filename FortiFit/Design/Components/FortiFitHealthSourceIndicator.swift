import SwiftUI

struct FortiFitHealthSourceIndicator: View {
    let activityType: String
    let sourceName: String?

    var body: some View {
        HStack(spacing: 4) {
            FortiFitHealthGlyph()
            Text("\(activityType) from \(sourceName ?? "Apple Watch")")
                .font(FortiFitTypography.bodySmall)
                .foregroundStyle(FortiFitColors.mutedText)
        }
        .accessibilityIdentifier(AccessibilityID.workoutDetailHealthSourceIndicator)
    }
}
