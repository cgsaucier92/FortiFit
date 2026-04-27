import SwiftUI

struct FortiFitHealthGlyph: View {
    var body: some View {
        Image(systemName: "figure.run.circle.fill")
            .font(.system(size: 20))
            .foregroundStyle(Color(hex: "6CCC00"))
            .accessibilityIdentifier("healthGlyph")
    }
}
