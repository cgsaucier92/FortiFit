import SwiftUI

struct FortiFitProgressBar: View {
    let progress: Double // 0.0 to 1.0
    var barColor: Color
    var backgroundColor: Color

    @State private var animatedProgress: Double = 0

    init(
        progress: Double,
        barColor: Color = FortiFitColors.primaryAccent,
        backgroundColor: Color = FortiFitColors.elevatedSurface
    ) {
        self.progress = min(max(progress, 0), 1)
        self.barColor = barColor
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(backgroundColor)
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 4)
                    .fill(barColor)
                    .frame(
                        width: geometry.size.width * animatedProgress,
                        height: 6
                    )
            }
        }
        .frame(height: 6)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeInOut(duration: 0.4)) {
                animatedProgress = newValue
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        FortiFitProgressBar(progress: 0.6)
        FortiFitProgressBar(progress: 0.9, barColor: FortiFitColors.positive)
        FortiFitProgressBar(progress: 0.3, barColor: FortiFitColors.alert)
    }
    .padding()
    .background(FortiFitColors.background)
}
