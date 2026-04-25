import SwiftUI

struct FortiFitHealthSourceIndicator: View {
    let activityType: String
    let sourceName: String?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.system(size: 11))
                .foregroundStyle(.pink)
            Text("\(activityType) from \(sourceName ?? "Apple Health")")
                .font(FortiFitTypography.label)
                .foregroundStyle(FortiFitColors.mutedText)
        }
        .accessibilityIdentifier(AccessibilityID.workoutDetailHealthSourceIndicator)
    }
}
