import SwiftUI

struct FortiFitLabel: View {
    let text: String
    var color: Color

    init(_ text: String, color: Color = FortiFitColors.mutedText) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(FortiFitTypography.label)
            .kerning(FortiFitTypography.labelKerning)
            .foregroundStyle(color)
    }
}

#Preview {
    VStack(spacing: 16) {
        FortiFitLabel("Training Log")
        FortiFitLabel("Workouts", color: FortiFitColors.primaryAccent)
    }
    .padding()
    .background(FortiFitColors.background)
}
