import SwiftUI

/// Expandable workout type grouping card with chevron, count badge,
/// sort/filter indicators, and optional drag handle for reorder mode.
struct FortiFitWorkoutTypeCard: View {
    let typeName: String
    let workoutCount: Int
    let isExpanded: Bool
    let isNonDefaultSort: Bool
    let activeFilterCount: Int
    let isReorderMode: Bool
    let onTap: () -> Void

    init(
        typeName: String,
        workoutCount: Int,
        isExpanded: Bool,
        isNonDefaultSort: Bool = false,
        activeFilterCount: Int = 0,
        isReorderMode: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.typeName = typeName
        self.workoutCount = workoutCount
        self.isExpanded = isExpanded
        self.isNonDefaultSort = isNonDefaultSort
        self.activeFilterCount = activeFilterCount
        self.isReorderMode = isReorderMode
        self.onTap = onTap
    }

    var body: some View {
        if isReorderMode {
            // No Button wrapper in reorder mode — allows draggable modifier
            // on the parent to receive long-press gestures for drag initiation
            cardContent
        } else {
            Button(action: onTap) {
                cardContent
            }
            .buttonStyle(PressableCardButtonStyle())
        }
    }

    private var cardContent: some View {
        FortiFitCard(borderColor: FortiFitColors.border) {
            HStack(spacing: FortiFitSpacing.elementSpacing) {
                // Workout type icon + name
                if let symbolName = AppConstants.workoutTypeSymbols[typeName] {
                    Image(systemName: symbolName)
                        .font(FortiFitTypography.widgetHeader)
                        .foregroundStyle(FortiFitColors.primaryAccent)
                        .frame(width: AppConstants.workoutTypeIconWidth, alignment: .center)
                }
                Text(typeName)
                    .font(FortiFitTypography.widgetHeader)
                    .kerning(FortiFitTypography.widgetHeaderKerning)
                    .foregroundStyle(FortiFitColors.primaryAccent)

                Spacer()

                // Count badge
                Text(countLabel)
                    .font(FortiFitTypography.label)
                    .kerning(FortiFitTypography.labelKerning)
                    .foregroundStyle(FortiFitColors.mutedText)

                // Sort indicator
                if isNonDefaultSort {
                    Image(systemName: "list.number")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FortiFitColors.mutedText)
                }

                // Filter indicator
                if activeFilterCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(FortiFitColors.mutedText)
                        Text("\(activeFilterCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(FortiFitColors.mutedText)
                    }
                }

                if isReorderMode {
                    // Drag handle
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(FortiFitColors.mutedText)
                        .rotationEffect(.degrees(90))
                } else {
                    // Chevron with rotation
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FortiFitColors.mutedText)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var countLabel: String {
        workoutCount == 1 ? "1 WORKOUT" : "\(workoutCount) WORKOUTS"
    }
}

#Preview {
    VStack(spacing: 12) {
        FortiFitWorkoutTypeCard(
            typeName: "Strength Training",
            workoutCount: 8,
            isExpanded: false,
            isNonDefaultSort: true,
            activeFilterCount: 2,
            onTap: {}
        )
        FortiFitWorkoutTypeCard(
            typeName: "Yoga",
            workoutCount: 1,
            isExpanded: true,
            isReorderMode: true,
            onTap: {}
        )
    }
    .padding()
    .background(FortiFitColors.background)
}
