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
                // Flame + rising embers
                ZStack {
                    EmberLayer(tier: tier)
                        .frame(width: flameSize * 1.2, height: flameSize * 1.6)
                        .offset(y: -flameSize * 0.3)
                        .allowsHitTesting(false)

                    FlameView(tier: tier)
                        .frame(width: flameSize, height: flameSize)
                }
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

    // Speed for the sin() wave (radians per second)
    private let outerSpeed: Double = 2.6   // ~1.2s full cycle

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
            }
        }
    }
}

// MARK: - Ember Layer

private struct EmberLayer: View {
    let tier: StreakService.Tier

    private var emberCount: Int {
        switch tier {
        case .dormant: return 0
        case .building: return 4
        case .committed: return 6
        case .elite: return 8
        }
    }

    private var emberColor: Color {
        switch tier {
        case .dormant: return .clear
        case .building: return Color(hex: "ef4444")
        case .committed: return Color(hex: "ef4444")
        case .elite: return Color(hex: "f87171")
        }
    }

    private var maxOpacity: Double {
        switch tier {
        case .dormant: return 0
        case .building: return 0.35
        case .committed: return 0.45
        case .elite: return 0.55
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: tier == .dormant)) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                let count = emberCount
                guard count > 0 else { return }

                for i in 0..<count {
                    let seed = Double(i)
                    let cycleDuration = 2.4 + (seed.truncatingRemainder(dividingBy: 3.0)) * 0.5
                    let phaseOffset = seed / Double(count)
                    let progress = ((t / cycleDuration) + phaseOffset).truncatingRemainder(dividingBy: 1.0)

                    let xBase = 0.2 + (seed * 0.137).truncatingRemainder(dividingBy: 0.6)
                    let xDrift = sin((t + seed * 1.7) * 1.3) * 0.04
                    let x = (xBase + xDrift) * size.width

                    let yStart = size.height * 0.7
                    let yEnd = size.height * 0.05
                    let y = yStart + (yEnd - yStart) * progress

                    let fadeIn = min(progress / 0.2, 1.0)
                    let fadeOut = 1.0 - max((progress - 0.5) / 0.5, 0.0)
                    let opacity = fadeIn * fadeOut * maxOpacity

                    let emberSize: CGFloat = 2.5 + CGFloat((seed * 0.31).truncatingRemainder(dividingBy: 1.0))
                    let rect = CGRect(
                        x: x - emberSize / 2,
                        y: y - emberSize / 2,
                        width: emberSize,
                        height: emberSize
                    )
                    ctx.fill(Path(ellipseIn: rect), with: .color(emberColor.opacity(opacity)))
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
