import SwiftUI

struct FortiFitActionButtonGroup: View {
    var onShare: (() -> Void)?
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            if let onShare {
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                        .foregroundStyle(FortiFitColors.primaryAccent)
                        .frame(width: FortiFitSpacing.minTouchTarget, height: FortiFitSpacing.minTouchTarget)
                }
            }
            Button(action: onEdit) {
                Image(systemName: AppConstants.editIcon)
                    .font(.system(size: 16))
                    .foregroundStyle(FortiFitColors.primaryAccent)
                    .frame(width: FortiFitSpacing.minTouchTarget, height: FortiFitSpacing.minTouchTarget)
            }
            Button(action: onDelete) {
                Image(systemName: AppConstants.deleteIcon)
                    .font(.system(size: 16))
                    .foregroundStyle(FortiFitColors.primaryAccent)
                    .frame(width: FortiFitSpacing.minTouchTarget, height: FortiFitSpacing.minTouchTarget)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                .fill(.clear)
                .stroke(FortiFitColors.primaryAccent, lineWidth: 1)
        )
    }
}

#Preview {
    FortiFitActionButtonGroup(onEdit: {}, onDelete: {})
        .padding()
        .background(FortiFitColors.background)
}
