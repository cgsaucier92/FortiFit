import SwiftUI

struct FortiFitScreenHeading: View {
    let title: String
    var color: Color

    init(_ title: String, color: Color = FortiFitColors.primaryAccent) {
        self.title = title
        self.color = color
    }

    var body: some View {
        Text(title)
            .font(FortiFitTypography.screenHeading)
            .kerning(FortiFitTypography.screenHeadingKerning)
            .foregroundStyle(color)
    }
}

#Preview {
    VStack(spacing: 16) {
        FortiFitScreenHeading("Workouts")
        FortiFitScreenHeading("Settings", color: FortiFitColors.primaryText)
    }
    .padding()
    .background(FortiFitColors.background)
}
