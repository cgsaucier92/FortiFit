import SwiftUI

struct FortiFitFixedHeader<Content: View>: View {
    @Binding var headerHeight: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
                .padding(.horizontal, FortiFitSpacing.screenHorizontal)
                .padding(.top, FortiFitSpacing.screenTop)
                .padding(.bottom, FortiFitSpacing.elementSpacing)
                .background(FortiFitColors.background.opacity(0.90))

            LinearGradient(
                colors: [FortiFitColors.background.opacity(0.90), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 25)
            .allowsHitTesting(false)
        }
        .overlay {
            GeometryReader { geo in
                Color.clear
                    .onAppear { headerHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, newValue in headerHeight = newValue }
            }
        }
    }
}
