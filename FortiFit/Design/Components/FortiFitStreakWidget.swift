import SwiftUI

struct FortiFitStreakWidget: View {
    let streak: Int
    let message: String
    var isReorderMode: Bool = false

    private var tier: StreakService.Tier {
        StreakService.tier(for: streak)
    }

    var body: some View {
        FortiFitCard {
            HStack(spacing: FortiFitSpacing.gapMedium) {
                // Flame
                FlameView(tier: tier)
                    .frame(width: flameSize, height: flameSize)

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(streak)")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(FortiFitColors.primaryText)

                    Text("Week Streak")
                        .font(.system(size: 20, weight: .semibold))
                        .kerning(2)
                        .foregroundStyle(FortiFitColors.primaryAccent)

                    Text(message)
                        .font(FortiFitTypography.note)
                        .foregroundStyle(FortiFitColors.primaryText)
                }

                Spacer()
            }
            .padding(.trailing, isReorderMode ? 24 : 0)
        }
    }

    private var flameSize: CGFloat {
        switch tier {
        case .dormant: return 40
        case .building: return 48
        case .committed: return 56
        case .elite: return 64
        }
    }
}

// MARK: - Flame View

private struct FlameView: View {
    let tier: StreakService.Tier

    // Speeds for the sin() wave (radians per second)
    private let outerSpeed: Double = 2.6   // ~1.2s full cycle
    private let innerSpeed: Double = 3.5   // ~0.9s full cycle

    private var flameGradient: LinearGradient {
        switch tier {
        case .dormant:
            return LinearGradient(
                colors: [Color(hex: "404040").opacity(0.35)],
                startPoint: .bottom,
                endPoint: .top
            )
        case .building:
            return LinearGradient(
                colors: [Color(hex: "991b1b"), Color(hex: "ef4444"), Color(hex: "fca5a5")],
                startPoint: .bottom,
                endPoint: .top
            )
        case .committed:
            return LinearGradient(
                colors: [Color(hex: "7f1d1d"), Color(hex: "ef4444"), Color(hex: "fecaca")],
                startPoint: .bottom,
                endPoint: .top
            )
        case .elite:
            return LinearGradient(
                colors: [Color(hex: "7f1d1d"), Color(hex: "f87171"), Color(hex: "fef2f2")],
                startPoint: .bottom,
                endPoint: .top
            )
        }
    }

    private var glowColor: Color {
        switch tier {
        case .dormant: return .clear
        case .building: return Color(hex: "ef4444").opacity(0.2)
        case .committed: return Color(hex: "ef4444").opacity(0.4)
        case .elite: return Color(hex: "f87171").opacity(0.5)
        }
    }

    /// Maps a Date to a 0…1 wave value using sin()
    private func wave(_ date: Date, speed: Double) -> CGFloat {
        let t = date.timeIntervalSinceReferenceDate
        // sin returns -1…1, remap to 0…1
        return CGFloat((sin(t * speed) + 1) / 2)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: tier == .dormant)) { context in
            let outerWave = wave(context.date, speed: outerSpeed)
            let innerWave = wave(context.date, speed: innerSpeed)

            ZStack {
                // Glow
                if tier != .dormant {
                    Circle()
                        .fill(glowColor)
                        .blur(radius: 12)
                        .scaleEffect(1.0 + outerWave * 0.25)
                }

                // Outer flame
                FlameShape()
                    .fill(flameGradient)
                    .scaleEffect(1.0 + outerWave * 0.12)
                    .offset(y: -outerWave * 3)

                // Inner flame (brighter core for elite)
                if tier == .elite {
                    FlameShape()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "fca5a5"), .white.opacity(0.9)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .scaleEffect(0.5 + innerWave * 0.1)
                }
            }
        }
    }
}

// MARK: - Flame Shape

private struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        var path = Path()
        // Flame shape: pointed top, rounded bottom
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addCurve(
            to: CGPoint(x: w * 0.85, y: h * 0.55),
            control1: CGPoint(x: w * 0.65, y: h * 0.1),
            control2: CGPoint(x: w * 0.95, y: h * 0.35)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h),
            control1: CGPoint(x: w * 0.8, y: h * 0.8),
            control2: CGPoint(x: w * 0.65, y: h)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.15, y: h * 0.55),
            control1: CGPoint(x: w * 0.35, y: h),
            control2: CGPoint(x: w * 0.2, y: h * 0.8)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: 0),
            control1: CGPoint(x: w * 0.05, y: h * 0.35),
            control2: CGPoint(x: w * 0.35, y: h * 0.1)
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 16) {
        FortiFitStreakWidget(streak: 0, message: StreakService.message(for: 0))
        FortiFitStreakWidget(streak: 2, message: StreakService.message(for: 2))
        FortiFitStreakWidget(streak: 5, message: StreakService.message(for: 5))
        FortiFitStreakWidget(streak: 10, message: StreakService.message(for: 10))
    }
    .padding()
    .background(FortiFitColors.background)
}
