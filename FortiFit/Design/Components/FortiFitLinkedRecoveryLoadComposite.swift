import SwiftUI

/// Linked Recovery & Load composite container (Phase 11). Shared `#3b82f6` border,
/// zero internal padding, single composite tap target. See SCREENS.md § Linked
/// Recovery & Load Composite and CONSTANTS.md § Linked Recovery & Load.
struct FortiFitLinkedRecoveryLoadComposite<Recovery: View, Load: View>: View {
    let recoveryStatusCard: Recovery
    let trainingLoadCard: Load
    let isReorderMode: Bool
    var onTap: () -> Void = {}

    init(
        isReorderMode: Bool = false,
        onTap: @escaping () -> Void = {},
        @ViewBuilder recoveryStatusCard: () -> Recovery,
        @ViewBuilder trainingLoadCard: () -> Load
    ) {
        self.isReorderMode = isReorderMode
        self.onTap = onTap
        self.recoveryStatusCard = recoveryStatusCard()
        self.trainingLoadCard = trainingLoadCard()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Both cards render edge-to-edge inside the composite — zero internal padding.
            // In reorder mode the drag handle anchors at the TL card's topTrailing with a
            // negative offset so it lands on the RS/TL boundary. Anchoring on TL (rather
            // than on RS's bottom) ensures it draws *after* the RS card and isn't clipped
            // by the next sibling.
            recoveryStatusCard
            trainingLoadCard
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(FortiFitColors.border)
                        .frame(height: 1)
                        .frame(maxWidth: 100)
                }
                .overlay(alignment: .topTrailing) {
                    if isReorderMode {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(FortiFitColors.mutedText)
                            .padding(.trailing, FortiFitSpacing.cardPadding)
                            .offset(y: -12)
                    }
                }
        }
        .background(
            ZStack {
                FortiFitColors.cardSurface
                LinearGradient(
                    colors: [
                        FortiFitColors.primaryAccent.opacity(0.12),
                        FortiFitColors.primaryAccent.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                .stroke(FortiFitColors.primaryAccent, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius))
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .accessibilityIdentifier(AccessibilityID.homeWidget_linkedRecoveryLoad_composite)
    }
}
