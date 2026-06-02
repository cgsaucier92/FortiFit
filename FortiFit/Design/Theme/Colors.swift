import SwiftUI

enum FortiFitColors {
    // MARK: - Accent Colors
    static let primaryAccent = Color(hex: "3b82f6")     // Blue — brand mark, active tabs, CTAs
    static let secondary = Color(hex: "60a5fa")          // Light Blue — charts, secondary emphasis

    // MARK: - Surfaces
    static let background = Color(hex: "0a0a0a")         // Primary screen background
    static let cardSurface = Color(hex: "1a1a1a")        // Card backgrounds, tab bar
    static let elevatedSurface = Color(hex: "2d2d2d")    // Toggle backgrounds, input fields
    static let border = Color(hex: "404040")             // Card and divider borders

    // MARK: - Text
    static let primaryText = Color(hex: "e5e5e5")        // Headings, body content
    static let mutedText = Color(hex: "737373")          // Labels, secondary info, hints
    static let secondaryText = Color(hex: "a3a3a3")      // Exercise pill text, note text

    // MARK: - Semantic
    static let positive = Color(hex: "10b981")           // Green — low load, PR indicators
    static let caution = Color(hex: "C4F648")            // Yellow — moderate load, cautionary warnings
    static let warning = Color(hex: "B7FF00")            // Dark Yellow — moderate-high load, more intense warnings
    static let alert = Color(hex: "ef4444")              // Red — peak load, high-intensity

    // MARK: - Speed and Distance Dual-Arc Ring Colors
    static let goalDistanceRing = Color(hex: "4B2893")    // Purple — outer ring (distance)
    static let goalDurationRing = Color(hex: "8FE6F6")    // Light Cyan — inner ring (duration)

    // MARK: - Activity Rings
    static let activityMoveRing = Color(hex: "ef4444")
    static let activityExerciseRing = Color(hex: "10b981")
    static let activityStandRing = Color(hex: "0845AD")

    // MARK: - Sleep (Phase 11)
    static let sleepAwake = Color(hex: "FF6B5B")         // Awake segment of the sleep stages bar (Recovery Status / Linked Detail Sheets)

    // MARK: - Chart Colors
    static let chartPink = Color(hex: "BB2BC0")
    static let chartOrange = Color(hex: "FFBF51")
    static let chartTeal = Color(hex: "289193")
    static let chartPurple = Color(hex: "4B2893")
    static let chartLightCyan = Color(hex: "8FE6F6")
    static let chartDeepBlue = Color(hex: "0845AD")

    // MARK: - Goal Colors (cycled by colorIndex % 4)
    static let goalColors: [Color] = [
        Color(hex: "FFBF51"),   // Orange
        Color(hex: "BB2BC0"),   // Pink
        Color(hex: "10b981"),   // Green
        Color(hex: "ef4444")    // Red
    ]
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
