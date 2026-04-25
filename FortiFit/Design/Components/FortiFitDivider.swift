import SwiftUI

struct FortiFitDivider: View {
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(FortiFitColors.border)
                .frame(height: 1)
            Text("✦")
                .font(.system(size: 10))
                .foregroundStyle(FortiFitColors.primaryAccent)
                .padding(.horizontal, 8)
            Rectangle()
                .fill(FortiFitColors.border)
                .frame(height: 1)
        }
    }
}

#Preview {
    FortiFitDivider()
        .padding()
        .background(FortiFitColors.background)
}
