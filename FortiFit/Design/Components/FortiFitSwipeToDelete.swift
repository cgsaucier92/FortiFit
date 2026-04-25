import SwiftUI

/// A reusable wrapper that adds swipe-to-delete functionality to any content.
/// Works inside ScrollView/LazyVStack (unlike .swipeActions which requires List).
///
/// Usage:
/// ```
/// FortiFitSwipeToDelete(
///     itemID: item.id,
///     activeSwipeID: $activeSwipeID,
///     onDelete: { deleteItem(item) }
/// ) {
///     MyRowContent(item: item)
/// }
/// ```
struct FortiFitSwipeToDelete<Content: View>: View {
    let itemID: UUID
    @Binding var activeSwipeID: UUID?
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var isShowingDelete = false

    private let deleteButtonWidth: CGFloat = 80
    private let swipeThreshold: CGFloat = 60

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button revealed behind content
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    offset = 0
                    isShowingDelete = false
                }
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: deleteButtonWidth)
                    .frame(maxHeight: .infinity)
            }
            .background(FortiFitColors.alert)

            // Main content offset by drag
            content()
                .offset(x: offset)
                .gesture(swipeGesture)
                .animation(.easeInOut(duration: 0.2), value: offset)
        }
        .clipped()
        .onChange(of: activeSwipeID) { _, newValue in
            if newValue != itemID && isShowingDelete {
                withAnimation(.easeInOut(duration: 0.2)) {
                    offset = 0
                    isShowingDelete = false
                }
            }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                // Only handle horizontal-dominant drags to avoid stealing vertical scroll
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                // Claim this row as the active swipe
                if activeSwipeID != itemID {
                    activeSwipeID = itemID
                }

                let translation = value.translation.width
                if translation < 0 {
                    // Swiping left — clamp to button width + small rubber-band
                    offset = max(translation, -deleteButtonWidth - 20)
                } else if isShowingDelete {
                    // Swiping right to close
                    offset = min(0, -deleteButtonWidth + translation)
                }
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }

                let translation = value.translation.width
                if translation < -swipeThreshold && !isShowingDelete {
                    // Snap open
                    withAnimation(.easeInOut(duration: 0.2)) {
                        offset = -deleteButtonWidth
                        isShowingDelete = true
                    }
                } else if isShowingDelete && translation > swipeThreshold {
                    // Snap closed
                    withAnimation(.easeInOut(duration: 0.2)) {
                        offset = 0
                        isShowingDelete = false
                        activeSwipeID = nil
                    }
                } else {
                    // Return to current state
                    withAnimation(.easeInOut(duration: 0.2)) {
                        offset = isShowingDelete ? -deleteButtonWidth : 0
                    }
                }
            }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var activeSwipeID: UUID?
        let items = [
            (id: UUID(), name: "Push Day I"),
            (id: UUID(), name: "Pull Day II"),
            (id: UUID(), name: "Leg Day III")
        ]

        var body: some View {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(items, id: \.id) { item in
                        FortiFitSwipeToDelete(
                            itemID: item.id,
                            activeSwipeID: $activeSwipeID,
                            onDelete: { print("Delete \(item.name)") }
                        ) {
                            HStack {
                                Text(item.name)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(FortiFitColors.primaryText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(FortiFitColors.mutedText)
                            }
                            .padding()
                            .background(FortiFitColors.cardSurface)
                        }
                        .onTapGesture {
                            if activeSwipeID != nil {
                                activeSwipeID = nil
                            } else {
                                print("Navigate to \(item.name)")
                            }
                        }
                    }
                }
                .padding()
            }
            .background(FortiFitColors.background)
        }
    }

    return PreviewWrapper()
}
