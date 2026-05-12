import SwiftUI

struct FortiFitAddWidgetMenu: View {
    @Binding var isPresented: Bool
    let activeWidgetTypes: Set<String>
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
                    Text("Add Widgets")
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
                    .accessibilityIdentifier(AccessibilityID.addWidgetsMenuDismiss)
                }
                .padding(.horizontal, FortiFitSpacing.cardPadding)
                .padding(.top, FortiFitSpacing.cardPadding)

                Divider()
                    .background(FortiFitColors.border)
                    .padding(.top, FortiFitSpacing.elementSpacing)

                // Widget list
                VStack(spacing: 0) {
                    ForEach(AppConstants.widgetTypes, id: \.self) { widgetType in
                        widgetRow(for: widgetType)

                        if widgetType != AppConstants.widgetTypes.last {
                            Divider()
                                .background(FortiFitColors.border)
                        }
                    }
                }
                .padding(.bottom, FortiFitSpacing.cardPadding)
            }
            .background(
                RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                    .fill(FortiFitColors.cardSurface)
                    .stroke(FortiFitColors.border, lineWidth: 1)
            )
            .padding(.horizontal, FortiFitSpacing.screenHorizontal + 8)
        }
    }

    // MARK: - Widget Row

    private func widgetRow(for widgetType: String) -> some View {
        let isAdded = activeWidgetTypes.contains(widgetType)
        let displayName = AppConstants.widgetDisplayNames[widgetType] ?? widgetType
        let description = AppConstants.widgetDescriptions[widgetType] ?? ""

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
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    onAdd(widgetType)
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
                .accessibilityIdentifier(AccessibilityID.addWidgetRow(widgetType))
            }
        }
        .padding(.horizontal, FortiFitSpacing.cardPadding)
        .padding(.vertical, FortiFitSpacing.gapSmall)
    }
}
