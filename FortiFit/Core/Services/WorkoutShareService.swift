import SwiftUI

#if os(iOS)
import UIKit

enum WorkoutShareService {
    /// Renders a workout as a styled PNG image card at @3x scale.
    /// Returns nil if rendering fails.
    @MainActor
    static func renderShareImage(workout: Workout, userSettings: UserSettings) -> UIImage? {
        let cardView = WorkoutShareCardView(workout: workout, userSettings: userSettings)
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0
        return renderer.uiImage
    }
}
#endif // os(iOS)
