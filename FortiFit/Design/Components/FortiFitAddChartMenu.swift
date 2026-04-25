import SwiftUI

struct FortiFitAddChartMenu: View {
    @Binding var isPresented: Bool
    let addedChartTypes: Set<String>
    let onAdd: (String) -> Void

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            // Overlay card
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Add Charts")
                        .font(FortiFitTypography.widgetHeader)
                        .kerning(FortiFitTypography.labelKerning)
                        .foregroundStyle(FortiFitColors.primaryAccent)
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FortiFitColors.mutedText)
                            .frame(
                                width: FortiFitSpacing.minTouchTarget,
                                height: FortiFitSpacing.minTouchTarget
                            )
                    }
                }
                .padding(.horizontal, FortiFitSpacing.cardPadding)
                .padding(.top, FortiFitSpacing.cardPadding)

                Divider()
                    .background(FortiFitColors.border)
                    .padding(.top, FortiFitSpacing.elementSpacing)

                // Chart list (scrollable)
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        ForEach(AppConstants.trendsChartTypes, id: \.self) { chartType in
                            chartRow(for: chartType)

                            if chartType != AppConstants.trendsChartTypes.last {
                                Divider()
                                    .background(FortiFitColors.border)
                            }
                        }
                    }
                }
                .scrollIndicators(.visible)
                .padding(.bottom, FortiFitSpacing.cardPadding)
            }
            .frame(maxHeight: 500)
            .background(
                RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                    .fill(FortiFitColors.cardSurface)
                    .stroke(FortiFitColors.border, lineWidth: 1)
            )
            .padding(.horizontal, FortiFitSpacing.screenHorizontal + 8)
        }
        .accessibilityIdentifier(AccessibilityID.addChartsMenuOverlay)
    }

    // MARK: - Chart Row

    private func chartRow(for chartType: String) -> some View {
        let isAdded = addedChartTypes.contains(chartType)
        let displayName = AppConstants.trendsChartDisplayNames[chartType] ?? chartType
        let description = AppConstants.trendsChartDescriptions[chartType] ?? ""

        return HStack(alignment: .top, spacing: FortiFitSpacing.gapSmall) {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(FortiFitTypography.bodySmall)
                    .foregroundStyle(FortiFitColors.primaryText)

                Text(description)
                    .font(FortiFitTypography.note)
                    .foregroundStyle(FortiFitColors.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if isAdded {
                Text("ADDED")
                    .font(FortiFitTypography.label)
                    .kerning(FortiFitTypography.labelKerning)
                    .foregroundStyle(FortiFitColors.mutedText)
                    .frame(height: FortiFitSpacing.minTouchTarget)
            } else {
                Button {
                    #if canImport(UIKit)
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    #endif
                    onAdd(chartType)
                } label: {
                    Text("Add")
                        .font(FortiFitTypography.label)
                        .kerning(FortiFitTypography.labelKerning)
                        .foregroundStyle(FortiFitColors.primaryAccent)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadiusSmall)
                                .stroke(FortiFitColors.primaryAccent, lineWidth: 1)
                        )
                }
                .frame(height: FortiFitSpacing.minTouchTarget)
            }
        }
        .padding(.horizontal, FortiFitSpacing.cardPadding)
        .padding(.vertical, FortiFitSpacing.gapSmall)
    }
}
