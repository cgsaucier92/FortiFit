import SwiftUI
import CoreTransferable

/// Foundation's `UUID` doesn't ship with a `Transferable` conformance, so we
/// add one here using its string representation. Used by `reorderableCard` for
/// lists whose items are identified by UUID (e.g. Goals).
extension UUID: @retroactive Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(
            exporting: { (uuid: UUID) in uuid.uuidString },
            importing: { (string: String) in UUID(uuidString: string) ?? UUID() }
        )
    }
}

extension View {
    /// Makes a card draggable and a drop target for reordering within a list,
    /// using iOS 16+ `.draggable` / `.dropDestination`. The system manages drag
    /// visuals and lifecycle, so there's no manual drag-state tracking and no
    /// stuck-greyed source on cancelled drags.
    ///
    /// - Parameters:
    ///   - payload: The identifier carried by this card during the drag.
    ///   - collection: The list this card belongs to, used to resolve from/to indices.
    ///   - key: Key path from an element of `collection` to its identifier (must match `payload`).
    ///   - onReorder: Called when a different card is dropped on this one. Receives the
    ///     source index and the destination index; perform the mutation here.
    func reorderableCard<Item, Payload: Codable & Hashable & Transferable>(
        payload: Payload,
        in collection: [Item],
        identifiedBy key: KeyPath<Item, Payload>,
        onReorder: @escaping (_ from: Int, _ to: Int) -> Void
    ) -> some View {
        self
            .draggable(payload)
            .dropDestination(for: Payload.self) { items, _ in
                guard let dropped = items.first, dropped != payload else { return false }
                guard let fromIndex = collection.firstIndex(where: { $0[keyPath: key] == dropped }),
                      let toIndex = collection.firstIndex(where: { $0[keyPath: key] == payload })
                else { return false }
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                withAnimation(.easeInOut(duration: 0.2)) {
                    onReorder(fromIndex, toIndex)
                }
                return true
            }
    }
}
