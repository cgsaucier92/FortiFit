import SwiftUI
import SwiftData

/// Weekly Streak Insights Sheet — opened by tapping the Weekly Streak home widget.
/// Renders a typographic hero (no flame), stat row, this-week ring, 26-week heatmap, milestone shelf.
///
/// See SCREENS.md § Weekly Streak Insights Sheet and CONSTANTS.md § Weekly Streak Insights.
struct FortiFitWeeklyStreakDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var heatmap: [StreakService.StreakHeatmapCell] = []
    @State private var thisWeek: StreakService.ThisWeekProgress = .init(currentCount: 0, target: 0, daysRemainingThisWeek: 0)
    @State private var history: StreakService.StreakHistorySummary = .init(currentStreak: 0, longestStreakAllTime: 0, totalWeeksLogged: 0, unlockedMilestones: [], nextUnlockedMilestone: nil)
    @State private var heroDisplayed: Int = 0
    @State private var selectedHeatmapIndex: Int?

    var onConfigureSettings: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FortiFitSpacing.cardPadding) {
                header
                heroBlock
                statRowBlock
                thisWeekBlock
                heatmapBlock
                milestoneShelf
                footer
            }
            .padding(.horizontal, FortiFitSpacing.screenHorizontal)
            .padding(.bottom, FortiFitSpacing.gapXLarge)
        }
        .background(FortiFitColors.cardSurface)
        .task {
            reload()
            await animateHero()
        }
        .onTapGesture {
            // Dismiss heatmap tooltip on outside tap
            selectedHeatmapIndex = nil
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FortiFitColors.mutedText)
                        .frame(width: FortiFitSpacing.minTouchTarget, height: FortiFitSpacing.minTouchTarget)
                }
                .accessibilityIdentifier(AccessibilityID.weeklyStreakDetailSheet_closeButton)
            }

            Text("Streak Insights")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(FortiFitColors.primaryAccent)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, FortiFitSpacing.gapMedium)
        }
    }

    // MARK: - Hero

    private var heroBlock: some View {
        VStack(spacing: FortiFitSpacing.elementSpacing) {
            Text("\(heroDisplayed)")
                .font(.system(size: 96, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [FortiFitColors.primaryAccent, Color(hex: "93c5fd")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(maxWidth: .infinity)

            Text("WEEK STREAK")
                .font(FortiFitTypography.bodySmall)
                .kerning(2)
                .foregroundStyle(FortiFitColors.primaryAccent)
                .frame(maxWidth: .infinity)

            if history.currentStreak == 0 {
                Text(AppConstants.WidgetDetail.EmptyState.weeklyStreakHeroSubline)
                    .font(FortiFitTypography.bodySmall)
                    .foregroundStyle(FortiFitColors.mutedText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, FortiFitSpacing.gapLarge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(history.currentStreak), week streak")
        .accessibilityIdentifier(AccessibilityID.weeklyStreakDetailSheet_hero)
    }

    // MARK: - Stat Row

    private var statRowBlock: some View {
        FortiFitCard {
            HStack(spacing: 0) {
                statColumn(value: history.currentStreak, label: "Current Streak")
                Divider().background(FortiFitColors.border).frame(width: 1)
                statColumn(value: history.longestStreakAllTime, label: "All-Time-Best")
                Divider().background(FortiFitColors.border).frame(width: 1)
                statColumn(value: history.totalWeeksLogged, label: "Total Weeks Logged")
            }
        }
        .accessibilityIdentifier(AccessibilityID.weeklyStreakDetailSheet_statRow)
    }

    private func statColumn(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(FortiFitColors.primaryText)
            Text(label)
                .font(FortiFitTypography.bodySmall)
                .foregroundStyle(FortiFitColors.mutedText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - This Week's Progress

    @ViewBuilder
    private var thisWeekBlock: some View {
        if thisWeek.target == 0 {
            FortiFitCard {
                Text(AppConstants.WidgetDetail.EmptyState.weeklyStreakThisWeekTargetZero)
                    .font(FortiFitTypography.bodySmall)
                    .foregroundStyle(FortiFitColors.mutedText)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .accessibilityIdentifier(AccessibilityID.weeklyStreakDetailSheet_thisWeekRing)
        } else {
            FortiFitCard {
                VStack(spacing: FortiFitSpacing.gapSmall) {
                    thisWeekRing
                    Text("\(thisWeek.daysRemainingThisWeek) day\(thisWeek.daysRemainingThisWeek == 1 ? "" : "s") left this week")
                        .font(FortiFitTypography.bodySmall)
                        .foregroundStyle(FortiFitColors.mutedText)
                }
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier(AccessibilityID.weeklyStreakDetailSheet_thisWeekRing)
        }
    }

    private var thisWeekRing: some View {
        let progress = thisWeek.target > 0 ? min(Double(thisWeek.currentCount) / Double(thisWeek.target), 1.0) : 0
        return ZStack {
            Circle()
                .stroke(FortiFitColors.elevatedSurface, lineWidth: 12)
                .frame(width: 120, height: 120)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(FortiFitColors.primaryAccent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(thisWeek.currentCount) / \(thisWeek.target)")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(FortiFitColors.primaryText)
                Text("Workouts\nThis Week")
                    .font(FortiFitTypography.bodySmall)
                    .foregroundStyle(FortiFitColors.mutedText)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Heatmap

    private var heatmapBlock: some View {
        // Reverse so the oldest week sits in the top-left and the current
        // in-progress week sits in the bottom-right (dates ascend left-to-right).
        // Cell accessibility identifiers align with visual position: index 0 = top-left = oldest.
        let orderedForGrid = Array(heatmap.reversed())
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)
        return FortiFitCard {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                Text("Last 26 weeks")
                    .font(FortiFitTypography.bodySmall)
                    .foregroundStyle(FortiFitColors.primaryText)

                if heatmap.allSatisfy({ $0.isUntracked }) {
                    Text(AppConstants.WidgetDetail.EmptyState.weeklyStreakHeatmap)
                        .font(FortiFitTypography.bodySmall)
                        .foregroundStyle(FortiFitColors.mutedText)
                        .padding(.vertical, FortiFitSpacing.gapSmall)
                }

                if let index = selectedHeatmapIndex, orderedForGrid.indices.contains(index) {
                    tooltip(for: orderedForGrid[index])
                }

                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Array(orderedForGrid.enumerated()), id: \.offset) { index, cell in
                        heatmapCell(cell, index: index)
                    }
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.weeklyStreakDetailSheet_heatmap)
    }

    private func heatmapCell(_ cell: StreakService.StreakHeatmapCell, index: Int) -> some View {
        let (fill, border): (Color, Color)
        switch cell.status {
        case .untracked:
            fill = FortiFitColors.cardSurface
            border = FortiFitColors.border
        case .belowTarget:
            fill = FortiFitColors.primaryAccent.opacity(cell.workoutCount > 0 ? 0.25 : 0.05)
            border = .clear
        case .targetMet:
            fill = FortiFitColors.primaryAccent
            border = .clear
        case .inProgress:
            // Color by current count band
            if cell.workoutCount >= cell.target && cell.target > 0 {
                fill = FortiFitColors.primaryAccent
            } else if cell.workoutCount > 0 {
                fill = FortiFitColors.primaryAccent.opacity(0.25)
            } else {
                fill = FortiFitColors.cardSurface
            }
            border = FortiFitColors.primaryAccent
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        let dayLabel = formatter.string(from: cell.weekStartDate)

        return ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(border, lineWidth: 1)
                )
                .frame(height: 32)
            Text(dayLabel)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(FortiFitColors.primaryText)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedHeatmapIndex = selectedHeatmapIndex == index ? nil : index
        }
        .accessibilityIdentifier(AccessibilityID.weeklyStreakDetailSheet_heatmapCell(index))
        .accessibilityLabel("Week of \(cell.weekStartDate.shortFormatted), \(cell.workoutCount) of \(cell.target) workouts")
    }

    private func tooltip(for cell: StreakService.StreakHeatmapCell) -> some View {
        Text("\(cell.workoutCount) of \(cell.target) workouts · week of \(cell.weekStartDate.shortFormatted)")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(FortiFitColors.primaryText)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, FortiFitSpacing.elementSpacing)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadiusSmall)
                    .fill(FortiFitColors.elevatedSurface)
                    .stroke(FortiFitColors.border, lineWidth: 1)
            )
    }

    // MARK: - Milestone Shelf

    private var milestoneShelf: some View {
        FortiFitCard {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                Text("Milestones")
                    .font(FortiFitTypography.bodySmall)
                    .foregroundStyle(FortiFitColors.primaryText)

                HStack(spacing: FortiFitSpacing.gapSmall) {
                    ForEach(StreakService.milestoneMarks, id: \.self) { mark in
                        milestoneBadge(mark: mark)
                    }
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.weeklyStreakDetailSheet_milestoneShelf)
    }

    private func milestoneBadge(mark: Int) -> some View {
        let isUnlocked = history.unlockedMilestones.contains(mark)
        return VStack(spacing: 6) {
            Image(systemName: isUnlocked ? "trophy.fill" : "trophy")
                .font(.system(size: 36))
                .foregroundStyle(isUnlocked ? FortiFitColors.primaryAccent : FortiFitColors.mutedText)
            Text(mark == 1 ? "1 WK" : "\(mark) WKS")
                .font(FortiFitTypography.bodySmall)
                .foregroundStyle(FortiFitColors.primaryAccent)
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier(AccessibilityID.weeklyStreakDetailSheet_milestone(mark))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onConfigureSettings?()
                }
            } label: {
                Text("Configure Settings")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FortiFitColors.primaryAccent)
                    .frame(minHeight: FortiFitSpacing.minTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.weeklyStreakDetailSheet_configureSettingsButton)
            Spacer()
        }
        .padding(.top, FortiFitSpacing.gapLarge)
    }

    // MARK: - Reload

    private func reload() {
        heatmap = StreakService.fetchHeatmap(context: modelContext)
        thisWeek = StreakService.thisWeekProgress(context: modelContext)
        history = StreakService.historySummary(context: modelContext)
    }

    /// Frame-by-frame count-up animation from 0 → `currentStreak` over 0.6s with cubic ease-out.
    /// SwiftUI's `withAnimation` doesn't interpolate the displayed digit of `Text("\(Int)")`, so we drive the
    /// integer manually with `Task.sleep` ticks. Honors Reduce Motion.
    @MainActor
    private func animateHero() async {
        let reduceMotion: Bool
        #if os(iOS)
        reduceMotion = UIAccessibility.isReduceMotionEnabled
        #else
        reduceMotion = false
        #endif

        let target = history.currentStreak
        if reduceMotion || target <= 0 {
            heroDisplayed = target
            return
        }

        let duration: TimeInterval = 0.6
        let frameCount = 30   // ~50ms per frame at 0.6s total
        let frameInterval = duration / Double(frameCount)
        heroDisplayed = 0

        for frame in 1...frameCount {
            try? await Task.sleep(nanoseconds: UInt64(frameInterval * 1_000_000_000))
            if Task.isCancelled { return }
            let t = Double(frame) / Double(frameCount)
            let eased = 1 - pow(1 - t, 3)  // cubic ease-out
            heroDisplayed = Int((Double(target) * eased).rounded())
        }
        // Ensure exact final value (defends against rounding drift on the last frame)
        heroDisplayed = target
    }
}
