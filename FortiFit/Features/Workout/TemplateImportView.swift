import SwiftUI
import SwiftData

struct TemplateImportView: View {
    @Environment(\.modelContext) private var modelContext

    let payload: TemplatePayload?
    let onDismiss: () -> Void
    let onSaved: () -> Void

    @State private var resolvedName: String = ""

    var body: some View {
        ZStack {
            // Dimmed background — tap to dismiss
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            if let payload {
                successContent(payload)
            } else {
                errorContent
            }
        }
        .onAppear {
            if let payload {
                resolvedName = TemplateShareService.resolveTemplateName(
                    name: payload.name,
                    context: modelContext
                )
            }
        }
    }

    // MARK: - Success Content

    private func successContent(_ payload: TemplatePayload) -> some View {
        VStack(spacing: 20) {
            // Heading
            Text("Import Template?")
                .font(FortiFitTypography.screenHeading)
                .kerning(FortiFitTypography.screenHeadingKerning)
                .foregroundStyle(FortiFitColors.primaryAccent)

            // Template preview card
            FortiFitCard(borderColor: FortiFitColors.border) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(resolvedName.isEmpty ? payload.name : resolvedName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(FortiFitColors.primaryText)

                    Text(payload.workoutType)
                        .font(.system(size: 13))
                        .foregroundStyle(FortiFitColors.mutedText)

                    Text(exerciseCountText(payload.exercises.count))
                        .font(.system(size: 13))
                        .foregroundStyle(FortiFitColors.mutedText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Action buttons
            HStack(spacing: 12) {
                // Cancel
                Button {
                    onDismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(FortiFitColors.mutedText)
                        .frame(maxWidth: .infinity)
                        .frame(height: FortiFitSpacing.minTouchTarget)
                        .background(
                            RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                                .stroke(FortiFitColors.border, lineWidth: 1)
                        )
                }

                // Save Template
                Button {
                    saveTemplate(payload)
                } label: {
                    Text("Save Template")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: FortiFitSpacing.minTouchTarget)
                        .background(
                            RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                                .fill(FortiFitColors.primaryAccent)
                        )
                }
            }
        }
        .padding(FortiFitSpacing.cardPadding)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                .fill(FortiFitColors.cardSurface)
                .stroke(FortiFitColors.border, lineWidth: 1)
        )
        .padding(.horizontal, 32)
    }

    // MARK: - Error Content

    private var errorContent: some View {
        VStack(spacing: 20) {
            Text("This QR code couldn't be read. It may be damaged or from an incompatible version of FitNavi.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FortiFitColors.primaryText)
                .multilineTextAlignment(.center)

            Button {
                onDismiss()
            } label: {
                Text("OK")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: FortiFitSpacing.minTouchTarget)
                    .background(
                        RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                            .fill(FortiFitColors.primaryAccent)
                    )
            }
        }
        .padding(FortiFitSpacing.cardPadding)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                .fill(FortiFitColors.cardSurface)
                .stroke(FortiFitColors.border, lineWidth: 1)
        )
        .padding(.horizontal, 32)
    }

    // MARK: - Helpers

    private func exerciseCountText(_ count: Int) -> String {
        count == 1 ? "1 exercise" : "\(count) exercises"
    }

    private func saveTemplate(_ payload: TemplatePayload) {
        TemplateShareService.importTemplate(payload: payload, context: modelContext)
        onSaved()
    }
}
