import SwiftUI

struct FortiFitEllipsisButton: View {
    var menuItems: [(label: String, systemImage: String?, identifier: String?, action: () -> Void)] = []

    var body: some View {
        if menuItems.isEmpty {
            // Non-functional stub (used on screens where ellipsis is decorative)
            ellipsisIcon
        } else {
            Menu {
                ForEach(menuItems.indices, id: \.self) { index in
                    Button {
                        menuItems[index].action()
                    } label: {
                        if let systemImage = menuItems[index].systemImage {
                            Label(menuItems[index].label, systemImage: systemImage)
                        } else {
                            Text(menuItems[index].label)
                        }
                    }
                    .accessibilityIdentifier(menuItems[index].identifier ?? "")
                }
            } label: {
                ellipsisIcon
            }
        }
    }

    private var ellipsisIcon: some View {
        Image(systemName: "ellipsis")
            .font(.system(size: 16))
            .foregroundStyle(FortiFitColors.primaryAccent)
            .frame(height: FortiFitSpacing.minTouchTarget)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                    .fill(.clear)
                    .stroke(FortiFitColors.primaryAccent, lineWidth: 1)
            )
    }
}
