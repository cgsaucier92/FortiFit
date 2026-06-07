import SwiftUI

/// Recovery Status Home widget (Phase 11). Four gating states + a no-sleep-last-night
/// sub-state in Live. See SCREENS.md § Home Screen → Recovery Status widget and
/// CONSTANTS.md § Recovery Status Widget.
struct FortiFitRecoveryStatusWidget: View {
    let gatingState: RecoveryStatusGatingState
    let sleepMinutes: Int?
    let deepSleepMinutes: Int
    /// Bare value for the SINCE LAST WORKOUT hero column (e.g. `4h 12m`, `NO DATA`).
    /// Sourced from `RecoveryStatusService.lastWorkoutHeroFormatted` /
    /// `lastWorkoutHero(context:)`.
    let lastWorkoutValue: String
    /// Display name of the workout the SINCE LAST WORKOUT timer is anchored to. Rendered
    /// as-stored (sentence/title case as the user entered it) in the caption beneath the
    /// hero value. Empty string suppresses the caption — used in the no-workouts-yet state.
    let lastWorkoutName: String
    var isReorderMode: Bool = false
    /// When true, the card suppresses its own border so the linked Recovery & Load
    /// composite renders as a single seamless card (the composite supplies its own
    /// outer Primary Accent Blue border).
    var isEmbedded: Bool = false
    var onConnect: () -> Void = {}
    var onOpenIOSSettings: () -> Void = {}

    private var watermarkOpacity: Double {
        switch gatingState {
        case .live:               return 0.1
        case .connectAppleHealth: return 0.06
        case .sleepAccessDenied:  return 0.06
        case .noSleepTracker:     return 0.06
        }
    }

    private var stateIdentifier: String {
        switch gatingState {
        case .live:               return AccessibilityID.homeWidget_recoveryStatus_state_live
        case .connectAppleHealth: return AccessibilityID.homeWidget_recoveryStatus_state_connectAppleHealth
        case .sleepAccessDenied:  return AccessibilityID.homeWidget_recoveryStatus_state_sleepAccessDenied
        case .noSleepTracker:     return AccessibilityID.homeWidget_recoveryStatus_state_noSleepTracker
        }
    }

    var body: some View {
        FortiFitCard(
            borderColor: isEmbedded ? .clear : FortiFitColors.border,
            fillColor: isEmbedded ? .clear : FortiFitColors.cardSurface
        ) {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                FortiFitWidgetHeader(title: "Recovery Status")

                switch gatingState {
                case .live:
                    liveBody
                case .connectAppleHealth:
                    connectAppleHealthBody
                case .sleepAccessDenied:
                    sleepAccessDeniedBody
                case .noSleepTracker:
                    noSleepTrackerBody
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, isReorderMode ? 24 : 0)
            .background(alignment: .center) {
                if !isEmbedded {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 90, weight: .regular))
                        .foregroundStyle(FortiFitColors.mutedText.opacity(watermarkOpacity))
                        .accessibilityIdentifier(AccessibilityID.homeWidget_recoveryStatus_watermark)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityIdentifier(stateIdentifier)
    }

    // MARK: - Live body (with no-sleep-last-night sub-state)

    @ViewBuilder
    private var liveBody: some View {
        HStack(alignment: .top, spacing: FortiFitSpacing.gapMedium) {
            VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
                Text("SLEEP")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(FortiFitColors.primaryAccent)
                    .accessibilityIdentifier(AccessibilityID.homeWidget_recoveryStatus_sleepHero)

                // Hero value — renders the no-sleep-last-night sub-state when `sleepMinutes`
                // is nil (or zero) per SCREENS.md § Recovery Status widget → no-sleep-last-night.
                Text(heroValueText)
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(heroValueColor)
                    .accessibilityIdentifier(AccessibilityID.homeWidget_recoveryStatus_sleepValue)

                Text(deepCaptionText)
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(FortiFitColors.mutedText)
                    .accessibilityIdentifier(AccessibilityID.homeWidget_recoveryStatus_deepSleepCaption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            lastWorkoutColumn
        }
    }

    /// SINCE LAST WORKOUT hero column — label + bare value, plus an optional caption
    /// naming the source workout (mirrors the SLEEP column's deep caption typography,
    /// but rendered in the workout's as-stored case rather than forced uppercase). The
    /// caption is suppressed when `lastWorkoutName` is empty (no-workouts-yet state).
    /// Renders in all 4 gating states (workout history is independent of HK sleep gating).
    private var lastWorkoutColumn: some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
            Text("SINCE LAST WORKOUT")
                .font(.system(size: 11, weight: .bold))
                .kerning(2)
                .foregroundStyle(FortiFitColors.primaryAccent)
                .accessibilityIdentifier(AccessibilityID.homeWidget_recoveryStatus_lastWorkoutHero)

            Text(lastWorkoutValue.isEmpty ? "NO DATA" : lastWorkoutValue)
                .font(.system(size: 32, weight: .black))
                .foregroundStyle(lastWorkoutValueColor)
                .accessibilityIdentifier(AccessibilityID.homeWidget_recoveryStatus_lastWorkoutValue)

            if !lastWorkoutName.isEmpty {
                Text(lastWorkoutName)
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(FortiFitColors.mutedText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityIdentifier(AccessibilityID.homeWidget_recoveryStatus_lastWorkoutCaption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lastWorkoutValueColor: Color {
        (lastWorkoutValue.isEmpty || lastWorkoutValue == "NO DATA")
            ? FortiFitColors.mutedText
            : FortiFitColors.primaryText
    }

    private var hasSleepLastNight: Bool {
        (sleepMinutes ?? 0) > 0
    }

    private var heroValueText: String {
        guard hasSleepLastNight, let minutes = sleepMinutes else { return "— h —m" }
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(String(format: "%02d", mins))m"
    }

    private var heroValueColor: Color {
        hasSleepLastNight ? FortiFitColors.primaryText : FortiFitColors.mutedText
    }

    private var deepCaptionText: String {
        guard hasSleepLastNight, let minutes = sleepMinutes, minutes > 0 else { return "NO DATA" }
        let percent = Int((Double(deepSleepMinutes) / Double(minutes) * 100).rounded())
        let deepHours = deepSleepMinutes / 60
        let deepMins = deepSleepMinutes % 60
        if deepHours > 0 {
            return "\(percent)% DEEP · \(deepHours)h \(String(format: "%02d", deepMins))m"
        }
        return "\(percent)% DEEP · \(deepMins)m"
    }

    // MARK: - Degraded-state bodies

    @ViewBuilder
    private var connectAppleHealthBody: some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
            heroRowWithLastWorkout
            Text("Connect Apple Health to track your sleep and recovery.")
                .font(.system(size: 13))
                .foregroundStyle(FortiFitColors.primaryText)
                .multilineTextAlignment(.leading)

            Button(action: onConnect) {
                Text("Connect")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FortiFitColors.primaryAccent)
            }
            .accessibilityIdentifier(AccessibilityID.homeWidget_recoveryStatus_connectButton)
        }
    }

    @ViewBuilder
    private var sleepAccessDeniedBody: some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
            heroRowWithLastWorkout
            Text("Allow sleep access in Apple Health Settings to use this widget.")
                .font(.system(size: 13))
                .foregroundStyle(FortiFitColors.primaryText)
                .multilineTextAlignment(.leading)

            Button(action: onOpenIOSSettings) {
                Text("Open Settings")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FortiFitColors.primaryAccent)
            }
            .accessibilityIdentifier(AccessibilityID.homeWidget_recoveryStatus_openIOSSettingsButton)
        }
    }

    @ViewBuilder
    private var noSleepTrackerBody: some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
            heroRowWithLastWorkout
            Text("Wear a sleep tracking device to display your sleep data.")
                .font(.system(size: 13))
                .foregroundStyle(FortiFitColors.primaryText)
                .multilineTextAlignment(.leading)
        }
    }

    /// Degraded-state hero row — placeholder SLEEP value on the left, real SINCE LAST
    /// WORKOUT value on the right (workout history is independent of HK sleep gating).
    private var heroRowWithLastWorkout: some View {
        HStack(alignment: .top, spacing: FortiFitSpacing.gapMedium) {
            VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
                Text("SLEEP")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(FortiFitColors.primaryAccent)
                heroPlaceholder
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            lastWorkoutColumn
        }
    }

    private var heroPlaceholder: some View {
        Text("— h —m")
            .font(.system(size: 32, weight: .black))
            .foregroundStyle(FortiFitColors.mutedText)
            .accessibilityIdentifier(AccessibilityID.homeWidget_recoveryStatus_sleepValue)
    }
}
