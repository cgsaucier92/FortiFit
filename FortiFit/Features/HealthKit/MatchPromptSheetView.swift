import SwiftUI
import SwiftData

struct MatchPromptSheetView: View {
    let pendingMatch: PendingMatch
    let workout: Workout?
    let onLink: () -> Void
    let onKeepSeparate: () -> Void
    let onDecideLater: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var settings: UserSettings { UserSettings.shared }
    private var distanceUnit: String { settings.useMiles ? "mi" : "km" }

    var body: some View {
        VStack(spacing: FortiFitSpacing.gapLarge) {
            Text("Possible Match")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(FortiFitColors.primaryText)

            Text("Apple Health imported a workout that looks similar to one you already logged. Would you like to link them?")
                .font(.system(size: 14))
                .foregroundStyle(FortiFitColors.secondaryText)
                .multilineTextAlignment(.center)

            HStack(alignment: .top, spacing: FortiFitSpacing.gapSmall) {
                hkCard
                fortiFitCard
            }

            VStack(spacing: FortiFitSpacing.gapSmall) {
                FortiFitButton("Link these workouts", style: .primary) {
                    onLink()
                    dismiss()
                }
                .accessibilityIdentifier(AccessibilityID.matchPromptSheetLinkButton)

                FortiFitButton("Keep separate", style: .outline) {
                    onKeepSeparate()
                    dismiss()
                }
                .accessibilityIdentifier(AccessibilityID.matchPromptSheetKeepSeparateButton)

                Button {
                    onDecideLater()
                    dismiss()
                } label: {
                    Text("Decide later")
                        .font(FortiFitTypography.body)
                        .foregroundStyle(FortiFitColors.mutedText)
                }
                .accessibilityIdentifier(AccessibilityID.matchPromptSheetDecideLaterButton)
            }
        }
        .padding(FortiFitSpacing.screenHorizontal)
        .presentationDetents([.medium])
        .presentationBackground(FortiFitColors.background)
    }

    // MARK: - HK Card

    private var hkCard: some View {
        let snapshot = pendingMatch.snapshot
        let mapping = snapshot.mapping
        return FortiFitCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: "#FF2D55"))
                    Text("FROM APPLE HEALTH")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(Color(hex: "#FF2D55"))
                }

                Text(mapping.workoutType.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(FortiFitColors.mutedText)

                Text(mapping.displayString)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FortiFitColors.primaryText)

                Text(snapshot.startDate.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 13))
                    .foregroundStyle(FortiFitColors.mutedText)

                Text("\(snapshot.durationMinutes) min")
                    .font(.system(size: 13))
                    .foregroundStyle(FortiFitColors.mutedText)

                if let km = snapshot.distanceKm {
                    let display = settings.useMiles ? String(format: "%.1f mi", km * 0.621371) : String(format: "%.1f km", km)
                    Text(display)
                        .font(.system(size: 13))
                        .foregroundStyle(FortiFitColors.mutedText)
                }

                if let hr = snapshot.avgHeartRate {
                    Text("\(hr) bpm avg")
                        .font(.system(size: 13))
                        .foregroundStyle(FortiFitColors.mutedText)
                }

                if let kcal = snapshot.activeEnergyKcal {
                    Text("\(Int(kcal)) kcal")
                        .font(.system(size: 13))
                        .foregroundStyle(FortiFitColors.mutedText)
                }
            }
        }
    }

    // MARK: - FortiFit Card

    private var fortiFitCard: some View {
        FortiFitCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("YOUR LOG")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(FortiFitColors.mutedText)

                if let workout {
                    Text(workout.workoutType.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(FortiFitColors.mutedText)

                    Text(workout.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FortiFitColors.primaryText)

                    if let time = workout.time {
                        Text(time.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 13))
                            .foregroundStyle(FortiFitColors.mutedText)
                    }

                    if let dur = workout.durationMinutes {
                        Text("\(dur) min")
                            .font(.system(size: 13))
                            .foregroundStyle(FortiFitColors.mutedText)
                    }

                    if let rpe = workout.rpe {
                        Text("RPE \(rpe)")
                            .font(.system(size: 13))
                            .foregroundStyle(FortiFitColors.mutedText)
                    }

                    let exerciseCount = Set(workout.exerciseSets.map { $0.exerciseName }).count
                    if exerciseCount > 0 {
                        Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
                            .font(.system(size: 13))
                            .foregroundStyle(FortiFitColors.mutedText)
                    }
                } else {
                    Text("Workout not found")
                        .font(.system(size: 13))
                        .foregroundStyle(FortiFitColors.mutedText)
                }
            }
        }
    }
}
