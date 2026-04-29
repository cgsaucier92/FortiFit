import SwiftUI

struct FortiFitWidgetHeader: View {
    let title: String
    var isReorderMode: Bool = false

    var body: some View {
        HStack(spacing: FortiFitSpacing.elementSpacing) {
            Text(title)
                .font(FortiFitTypography.widgetHeader)
                .kerning(FortiFitTypography.widgetHeaderKerning)
                .foregroundStyle(FortiFitColors.primaryAccent)

            if isReorderMode {
                Spacer()
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FortiFitColors.mutedText)
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        FortiFitWidgetHeader(title: "Weekly Exercise Load")
        FortiFitWidgetHeader(title: "Weekly Exercise Load", isReorderMode: true)
    }
    .padding()
    .background(FortiFitColors.background)
}
