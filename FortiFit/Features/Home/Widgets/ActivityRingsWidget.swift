import SwiftUI

struct ActivityRingsWidget: View {
    let activityService: AppleActivityService
    var isReorderMode: Bool = false
    var onTapConnect: () -> Void = {}
    var onTapWidget: () -> Void = {}

    @State private var hasCelebrated = false
    @State private var celebrationScale: CGFloat = 1.0

    var body: some View {
        FortiFitCard {
            VStack(spacing: FortiFitSpacing.gapSmall) {
                switch activityService.widgetState {
                case .connectAppleHealth:
                    connectAppleHealthState

                case .pairAppleWatch:
                    pairAppleWatchState

                case .liveRings:
                    liveRingsState
                }
            }
            .padding(.trailing, isReorderMode ? 36 : 0)
        }
        .accessibilityIdentifier(AccessibilityID.homeWidget_appleActivity_card)
        .scaleEffect(celebrationScale)
        .onChange(of: activityService.allRingsClosedToday) { _, closed in
            if closed && !hasCelebrated {
                hasCelebrated = true
                withAnimation(.easeInOut(duration: 0.6)) {
                    celebrationScale = 1.05
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        celebrationScale = 1.0
                    }
                }
            }
        }
    }

    // MARK: - State 1: Connect Apple Health

    private var connectAppleHealthState: some View {
        VStack(spacing: 0) {
            FortiFitWidgetHeader(title: AppConstants.ActivityRings.cardHeader)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: FortiFitSpacing.gapMedium) {
                VStack(spacing: FortiFitSpacing.gapSmall) {
                    Text(AppConstants.ActivityRings.stateConnectAppleHealthMessage)
                        .font(FortiFitTypography.note)
                        .foregroundStyle(FortiFitColors.mutedText)
                        .multilineTextAlignment(.center)

                    Button {
                        onTapConnect()
                    } label: {
                        Text(AppConstants.ActivityRings.stateConnectAppleHealthCTA)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FortiFitColors.primaryAccent)
                    }
                    .accessibilityIdentifier(AccessibilityID.homeWidget_appleActivity_connectButton)
                }
                .frame(maxWidth: .infinity)

                ActivityRingsCanvas(
                    moveProgress: 0,
                    exerciseProgress: 0,
                    standProgress: 0,
                    muted: true
                )
                .frame(width: 130, height: 130)
            }
        }
        .accessibilityIdentifier(AccessibilityID.homeWidget_appleActivity_state_connectAppleHealth)
    }

    // MARK: - State 2: Pair Apple Watch

    private var pairAppleWatchState: some View {
        VStack(spacing: 0) {
            FortiFitWidgetHeader(title: AppConstants.ActivityRings.cardHeader)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: FortiFitSpacing.gapMedium) {
                Text(AppConstants.ActivityRings.statePairAppleWatchMessage)
                    .font(FortiFitTypography.note)
                    .foregroundStyle(FortiFitColors.mutedText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                ActivityRingsCanvas(
                    moveProgress: 0,
                    exerciseProgress: 0,
                    standProgress: 0,
                    muted: true
                )
                .frame(width: 130, height: 130)
            }
        }
        .accessibilityIdentifier(AccessibilityID.homeWidget_appleActivity_state_pairAppleWatch)
    }

    // MARK: - State 3: Live Rings

    private var liveRingsState: some View {
        VStack(spacing: FortiFitSpacing.gapSmall) {
            FortiFitWidgetHeader(title: AppConstants.ActivityRings.cardHeader)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .top, spacing: FortiFitSpacing.gapMedium) {
                // Left column — labels + fractions
                VStack(alignment: .leading, spacing: FortiFitSpacing.gapMedium) {
                    ringFraction(
                        label: AppConstants.ActivityRings.moveLabel,
                        icon: AppConstants.ActivityRings.moveChevron,
                        current: activityService.moveCalories,
                        goal: activityService.moveGoal,
                        unit: AppConstants.ActivityRings.moveUnit,
                        ringColor: FortiFitColors.activityMoveRing,
                        isClosed: activityService.moveProgress >= 1.0,
                        contributionValue: activityService.todayMoveContributionFromWorkouts,
                        contributionUnit: AppConstants.ActivityRings.moveUnit
                    )

                    ringFraction(
                        label: AppConstants.ActivityRings.exerciseLabel,
                        icon: AppConstants.ActivityRings.exerciseChevron,
                        current: activityService.exerciseMinutes,
                        goal: activityService.exerciseGoal,
                        unit: AppConstants.ActivityRings.exerciseUnit,
                        ringColor: FortiFitColors.activityExerciseRing,
                        isClosed: activityService.exerciseProgress >= 1.0,
                        contributionValue: activityService.todayExerciseContributionFromWorkouts,
                        contributionUnit: AppConstants.ActivityRings.exerciseUnit
                    )

                    ringFraction(
                        label: AppConstants.ActivityRings.standLabel,
                        icon: AppConstants.ActivityRings.standChevron,
                        current: activityService.standHours,
                        goal: activityService.standGoal,
                        unit: AppConstants.ActivityRings.standUnit,
                        ringColor: FortiFitColors.activityStandRing,
                        isClosed: activityService.standProgress >= 1.0,
                        contributionValue: nil,
                        contributionUnit: nil
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right column — rings
                ActivityRingsCanvas(
                    moveProgress: activityService.moveProgress,
                    exerciseProgress: activityService.exerciseProgress,
                    standProgress: activityService.standProgress
                )
                .frame(width: 130, height: 130)
            }

            // Weekly closure chip
            Text(AppConstants.ActivityRings.weeklyClosureChip(count: activityService.closedAllRingsDayCount))
                .font(FortiFitTypography.note)
                .foregroundStyle(FortiFitColors.primaryText)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityIdentifier(AccessibilityID.homeWidget_appleActivity_weeklyClosureChip)
        }
    }

    // MARK: - Ring Fraction Row

    private func ringFraction(
        label: String,
        icon: String,
        current: Int,
        goal: Int,
        unit: String,
        ringColor: Color,
        isClosed: Bool,
        contributionValue: Int?,
        contributionUnit: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ringColor)
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(FortiFitColors.primaryText)
            }

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(current)")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(ringColor)
                Text("/\(goal) \(unit)")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(ringColor)
            }

            if let value = contributionValue, let cUnit = contributionUnit, value > 0 {
                contributionCaption(value: value, unit: cUnit)
            }
        }
    }

    @ViewBuilder
    private func contributionCaption(value: Int, unit: String) -> some View {
        let names = activityService.todayContributingWorkoutNames
        if names.count == 1 {
            Text(AppConstants.ActivityRings.captionFromSingleWorkout(
                value: value, unit: unit, workoutName: names[0]
            ))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(FortiFitColors.mutedText)
        } else if names.count > 1 {
            Text(AppConstants.ActivityRings.captionFromMultipleWorkouts(
                value: value, unit: unit
            ))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(FortiFitColors.mutedText)
        }
    }
}
