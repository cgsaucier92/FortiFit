import SwiftUI

#if os(iOS)
import UIKit

struct TemplateQRModalView: View {
    let template: WorkoutTemplate
    let onDismiss: () -> Void

    @State private var qrImage: UIImage?
    @State private var showShareSheet = false
    @State private var toastMessage: String?
    @State private var showToast = false

    var body: some View {
        ZStack {
            // Dimmed background — tap to dismiss
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Modal content
            VStack(spacing: 16) {
                // Top bar: share icon (left), close button (right)
                HStack {
                    Button {
                        if let image = qrImage {
                            showShareSheet = true
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundStyle(FortiFitColors.primaryAccent)
                            .frame(width: FortiFitSpacing.minTouchTarget, height: FortiFitSpacing.minTouchTarget)
                    }
                    .opacity(qrImage != nil ? 1 : 0)

                    Spacer()

                    Button {
                        onDismiss()
                    } label: {
                        Text("×")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(FortiFitColors.mutedText)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(FortiFitColors.elevatedSurface)
                                    .stroke(FortiFitColors.border, lineWidth: 1)
                            )
                    }
                }

                // QR code container
                if let image = qrImage {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                                .fill(FortiFitColors.cardSurface)
                                .stroke(FortiFitColors.border, lineWidth: 1)
                        )
                }

                // Template info below QR code
                Text(template.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(FortiFitColors.primaryText)
                    .multilineTextAlignment(.center)

                Text(template.workoutType)
                    .font(.system(size: 13))
                    .foregroundStyle(FortiFitColors.mutedText)
            }
            .padding(FortiFitSpacing.cardPadding)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                    .fill(FortiFitColors.cardSurface)
                    .stroke(FortiFitColors.border, lineWidth: 1)
            )
            .padding(.horizontal, 40)

            // Toast overlay
            if showToast, let message = toastMessage {
                VStack {
                    Spacer()
                    Text(message)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FortiFitColors.primaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadiusSmall)
                                .fill(FortiFitColors.elevatedSurface)
                                .stroke(FortiFitColors.border, lineWidth: 1)
                        )
                        .padding(.bottom, 60)
                }
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = qrImage {
                ShareSheet(activityItems: [image])
            }
        }
        .onAppear {
            generateQR()
        }
    }

    private func generateQR() {
        guard let url = TemplateShareService.encodeTemplate(template) else {
            showToastMessage("Template is too large to share via QR code.")
            return
        }

        guard let image = TemplateShareService.generateQRCode(from: url) else {
            showToastMessage("Couldn't generate QR code. Try again.")
            return
        }

        qrImage = image
    }

    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showToast = false }
            // Auto-dismiss modal after error toast
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onDismiss()
            }
        }
    }
}
#endif
