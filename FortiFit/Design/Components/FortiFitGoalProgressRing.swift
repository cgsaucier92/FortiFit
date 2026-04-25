import SwiftUI

struct FortiFitGoalProgressRing: View {
    let progress: Double // 0.0–1.0+
    let goalType: String
    let colorIndex: Int
    let isVictory: Bool
    var distanceProgress: Double = 0
    var durationProgress: Double = 0
    var hasDualTargets: Bool = false
    var shouldPulse: Bool = false

    private var isDualArc: Bool {
        goalType == "Speed and Distance" && hasDualTargets
    }

    private var ringColor: Color {
        FortiFitColors.goalColors[colorIndex % FortiFitColors.goalColors.count]
    }

    private var pulseColor: Color {
        if isDualArc { return FortiFitColors.goalDistanceRing }
        return singleArcColor
    }

    private var sfSymbol: String {
        switch goalType {
        case "Strength PR": return AppConstants.goalSymbolStrengthPR
        case "Repetitions PR": return AppConstants.goalSymbolRepsPR
        case "Speed and Distance": return AppConstants.goalSymbolSpeedDistance
        case "weeklyWorkouts": return AppConstants.goalSymbolWeeklyWorkouts
        default: return AppConstants.goalSymbolStrengthPR
        }
    }

    private var silhouetteOpacity: Double {
        if isVictory { return AppConstants.goalSilhouetteCompletedOpacity }
        return 0.10 + (min(progress, 1.0) * 0.30)
    }

    private var silhouetteColor: Color {
        if isVictory { return FortiFitColors.primaryAccent }
        return FortiFitColors.primaryText
    }

    private let ringSize: CGFloat = 130
    private let lineWidth: CGFloat = 9
    private let trackColor = Color(hex: "404040")

    // Pulse animation state
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.0

    var body: some View {
        ZStack {
            if isDualArc {
                dualArcRing
            } else {
                singleRing
            }

            // Center content: SF Symbol silhouette only
            Image(systemName: sfSymbol)
                .font(.system(size: ringSize * 0.24, weight: .medium))
                .foregroundStyle(silhouetteColor.opacity(silhouetteOpacity))
                .animation(.easeInOut(duration: 0.25), value: isVictory)

            // Pulse animation overlay
            if shouldPulse {
                Circle()
                    .stroke(pulseColor, lineWidth: 3)
                    .frame(width: ringSize + 8, height: ringSize + 8)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
            }
        }
        .frame(width: ringSize, height: ringSize)
        .onChange(of: shouldPulse) { _, newValue in
            if newValue {
                firePulse()
            }
        }
        .onAppear {
            if shouldPulse {
                firePulse()
            }
        }
    }

    // MARK: - Pulse Animation

    private func firePulse() {
        pulseScale = 1.0
        pulseOpacity = 0.0

        withAnimation(.easeOut(duration: 0.6)) {
            pulseOpacity = 0.4
            pulseScale = 1.15
        }

        withAnimation(.easeIn(duration: 0.6).delay(0.6)) {
            pulseOpacity = 0.0
            pulseScale = 1.2
        }
    }

    // MARK: - Single Ring

    private var singleRing: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    singleArcColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }

    private var singleArcColor: Color {
        if goalType == "Speed and Distance" {
            if distanceProgress > 0 { return FortiFitColors.goalDistanceRing }
            if durationProgress > 0 { return FortiFitColors.goalDurationRing }
        }
        return ringColor
    }

    // MARK: - Dual Arc Ring

    private var dualArcRing: some View {
        let innerLineWidth: CGFloat = 7
        let outerLineWidth: CGFloat = 7
        let gap: CGFloat = 4

        return ZStack {
            // Outer track (distance)
            Circle()
                .stroke(trackColor, lineWidth: outerLineWidth)

            // Outer arc (distance)
            Circle()
                .trim(from: 0, to: min(distanceProgress, 1.0))
                .stroke(
                    FortiFitColors.goalDistanceRing,
                    style: StrokeStyle(lineWidth: outerLineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Inner track (duration)
            Circle()
                .stroke(trackColor, lineWidth: innerLineWidth)
                .padding(outerLineWidth + gap)

            // Inner arc (duration)
            Circle()
                .trim(from: 0, to: min(durationProgress, 1.0))
                .stroke(
                    FortiFitColors.goalDurationRing,
                    style: StrokeStyle(lineWidth: innerLineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(outerLineWidth + gap)
        }
    }
}
