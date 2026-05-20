import SwiftUI

extension View {
    // Restores left-to-right edge-swipe pop on screens that hide the system nav bar
    // via `.toolbar(.hidden, for: .navigationBar)`, which otherwise disables the
    // built-in interactive pop gesture.
    func swipeToDismiss() -> some View {
        modifier(SwipeToDismissModifier())
    }
}

private struct SwipeToDismissModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    let startedAtLeftEdge = value.startLocation.x < 40
                    let movedRightEnough = value.translation.width > 80
                    let isPrimarilyHorizontal =
                        abs(value.translation.width) > abs(value.translation.height) * 1.5
                    if startedAtLeftEdge && movedRightEnough && isPrimarilyHorizontal {
                        dismiss()
                    }
                }
        )
    }
}
