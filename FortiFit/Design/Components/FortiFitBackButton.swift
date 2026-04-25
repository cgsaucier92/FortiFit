import SwiftUI

struct FortiFitBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16))
                    .font(FortiFitTypography.bodySmall)
                    .kerning(FortiFitTypography.labelKerning)
            }
            .foregroundStyle(FortiFitColors.primaryAccent)
            .frame(width: FortiFitSpacing.minTouchTarget, height: FortiFitSpacing.minTouchTarget)
            .background(
                RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                    .fill(.clear)
                    .stroke(FortiFitColors.primaryAccent, lineWidth: 1)
            )
        }
        .frame(minHeight: FortiFitSpacing.minTouchTarget)
    }
}

#Preview {
    FortiFitBackButton {}
        .padding()
        .background(FortiFitColors.background)
}
