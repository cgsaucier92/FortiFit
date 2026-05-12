import SwiftUI

struct FortiFitWatchSyncGlyph: View {
    enum State {
        case active
        case inactive
        case disabled
    }

    let state: State
    var onTap: () -> Void

    private var symbolName: String {
        switch state {
        case .active: return "applewatch.watchface"
        case .inactive, .disabled: return "applewatch.slash"
        }
    }

    private var foregroundColor: Color {
        switch state {
        case .active: return FortiFitColors.positive
        case .inactive, .disabled: return FortiFitColors.mutedText
        }
    }

    private var opacity: Double {
        switch state {
        case .active, .inactive: return 1.0
        case .disabled: return 0.4
        }
    }

    var body: some View {
        Button(action: onTap) {
            Image(systemName: symbolName)
                .font(.system(size: 20))
                .foregroundStyle(foregroundColor)
                .opacity(opacity)
        }
        .buttonStyle(.plain)
    }
}
