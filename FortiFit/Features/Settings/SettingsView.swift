import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = UserSettings.shared
    @State private var headerHeight: CGFloat = 0

    private var unitSelection: String {
        settings.useLbs ? "LBS" : "KG"
    }

    private var distanceSelection: String {
        settings.useMiles ? "MILES" : "KM"
    }

    var body: some View {
        ZStack(alignment: .top) {
        ScrollView {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapLarge) {
                FortiFitScreenHeading("General Settings", color: FortiFitColors.primaryAccent)

                FortiFitCard(borderColor: FortiFitColors.border) {
                    HStack {
                        Text("Weight Unit")
                            .font(FortiFitTypography.body)
                            .foregroundStyle(FortiFitColors.primaryText)
                        Spacer()
                        FortiFitSegmentedToggle(
                            options: ["KG", "LBS"],
                            selected: Binding(
                                get: { unitSelection },
                                set: { settings.useLbs = $0 == "LBS" }
                            ),
                            accessibilityIdentifier: AccessibilityID.settingsWeightUnitToggle
                        )
                        .frame(width: 120)
                    }
                }

                FortiFitCard(borderColor: FortiFitColors.border) {
                    HStack {
                        Text("Distance Unit")
                            .font(FortiFitTypography.body)
                            .foregroundStyle(FortiFitColors.primaryText)
                        Spacer()
                        FortiFitSegmentedToggle(
                            options: ["KM", "MILES"],
                            selected: Binding(
                                get: { distanceSelection },
                                set: { settings.useMiles = $0 == "MILES" }
                            )
                        )
                        .frame(width: 120)
                    }
                }


            }
            .padding(.horizontal, FortiFitSpacing.screenHorizontal)
            .padding(.top, headerHeight)
            .padding(.bottom, FortiFitSpacing.gapXLarge)
        }
        .scrollClipDisabled()

        // Fixed header
        VStack(spacing: 0) {
            HStack {
                FortiFitBackButton { dismiss() }
                    .accessibilityIdentifier(AccessibilityID.settingsBackButton)
                Spacer()
            }
            .padding(.horizontal, FortiFitSpacing.screenHorizontal)
            .padding(.top, FortiFitSpacing.screenTop)
            .padding(.bottom, FortiFitSpacing.elementSpacing)
            .background(FortiFitColors.background.opacity(0.90))

            LinearGradient(
                colors: [FortiFitColors.background.opacity(0.90), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 30)
            .allowsHitTesting(false)
        }
        .overlay {
            GeometryReader { geo in
                Color.clear
                    .onAppear { headerHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, newValue in headerHeight = newValue }
            }
        }
        }
        .background(FortiFitColors.background)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
