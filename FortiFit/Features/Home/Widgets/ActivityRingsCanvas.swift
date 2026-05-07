import SwiftUI

struct ActivityRingsCanvas: View {
    let moveProgress: Double
    let exerciseProgress: Double
    let standProgress: Double
    var muted: Bool = false

    private let ringThickness: CGFloat = 10
    private let ringGap: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGSize(width: geo.size.width / 2, height: geo.size.height / 2)

            ZStack {
                let standRadius = (size / 2) - (ringThickness / 2) - 2 * (ringThickness + ringGap)

                // Move ring (outermost)
                ringLayer(
                    progress: moveProgress,
                    color: FortiFitColors.activityMoveRing,
                    radius: (size / 2) - (ringThickness / 2)
                )
                .accessibilityIdentifier(AccessibilityID.homeWidget_appleActivity_moveRing)

                // Exercise ring (middle)
                ringLayer(
                    progress: exerciseProgress,
                    color: FortiFitColors.activityExerciseRing,
                    radius: (size / 2) - (ringThickness / 2) - ringThickness - ringGap
                )
                .accessibilityIdentifier(AccessibilityID.homeWidget_appleActivity_exerciseRing)

                // Stand ring (innermost)
                ringLayer(
                    progress: standProgress,
                    color: FortiFitColors.activityStandRing,
                    radius: standRadius
                )
                .accessibilityIdentifier(AccessibilityID.homeWidget_appleActivity_standRing)

                if !muted {
                    VStack(spacing: 0) {
                        Text(Date().formatted(.dateTime.month(.abbreviated)).uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(FortiFitColors.mutedText)
                        Text(Date().formatted(.dateTime.day()))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(FortiFitColors.mutedText)
                    }
                }
            }
            .position(x: center.width, y: center.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func ringLayer(progress: Double, color: Color, radius: CGFloat) -> some View {
        let strokeColor = muted ? FortiFitColors.mutedText.opacity(0.3) : color
        let baseProgress = min(max(progress, 0), 1.0)
        let overProgress = max(progress - 1.0, 0)

        // Background track
        Circle()
            .stroke(
                muted ? FortiFitColors.mutedText.opacity(0.15) : color.opacity(0.2),
                style: StrokeStyle(lineWidth: ringThickness, lineCap: .round)
            )
            .frame(width: radius * 2, height: radius * 2)

        // Base arc (0–100%)
        Circle()
            .trim(from: 0, to: baseProgress)
            .stroke(
                strokeColor,
                style: StrokeStyle(lineWidth: ringThickness, lineCap: .round)
            )
            .frame(width: radius * 2, height: radius * 2)
            .rotationEffect(.degrees(-90))

        // Over-100% overlay arc
        if overProgress > 0 && !muted {
            let cappedOver = min(overProgress, 1.0)

            // Curved shadow behind trailing tip — drawn first so overlay covers it
            Circle()
                .trim(from: max(cappedOver - 0.05, 0), to: cappedOver)
                .stroke(
                    Color.black.opacity(0.5),
                    style: StrokeStyle(lineWidth: ringThickness + 2, lineCap: .round)
                )
                .frame(width: radius * 2, height: radius * 2)
                .rotationEffect(.degrees(-90))
                .blur(radius: 2)

            // Second-pass arc
            Circle()
                .trim(from: 0, to: cappedOver)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: ringThickness, lineCap: .round)
                )
                .frame(width: radius * 2, height: radius * 2)
                .rotationEffect(.degrees(-90))
        }
    }
}
