import SwiftUI

struct FortiFitExerciseAutocomplete: View {
    let placeholder: String
    @Binding var text: String
    let suggestions: [ExerciseSuggestionService.Suggestion]
    let onQueryChanged: (String) -> Void
    var accessibilityIdentifier: String?

    @State private var showDropdown = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FortiFitInput(placeholder: placeholder, text: $text)
                .accessibilityIdentifier(accessibilityIdentifier ?? "")
                .focused($isInputFocused)
                .onChange(of: text) { _, newValue in
                    onQueryChanged(newValue)
                    let hasQuery = !newValue.trimmingCharacters(in: .whitespaces).isEmpty
                    showDropdown = hasQuery && isInputFocused
                }
                .onChange(of: isInputFocused) { _, focused in
                    if !focused {
                        showDropdown = false
                    } else {
                        let hasQuery = !text.trimmingCharacters(in: .whitespaces).isEmpty
                        showDropdown = hasQuery && !suggestions.isEmpty
                    }
                }
                .onSubmit {
                    showDropdown = false
                }
        }
        .background {
            if showDropdown && !suggestions.isEmpty {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: 10000, height: 10000)
                    .onTapGesture {
                        showDropdown = false
                        isInputFocused = false
                    }
            }
        }
        .overlay(alignment: .top) {
            if showDropdown && !suggestions.isEmpty {
                dropdownContent
                    .offset(y: FortiFitSpacing.minTouchTarget + 4)
                    .transition(.opacity)
            }
        }
        .animation(.easeIn(duration: 0.15), value: showDropdown)
        .zIndex(showDropdown ? 100 : 0)
    }

    private let maxVisibleRows = 3

    /// Computes dropdown height: up to 3 rows (44pt each) + dividers (1pt each)
    private var dropdownHeight: CGFloat {
        let rowCount = min(suggestions.count, maxVisibleRows)
        let dividerCount = max(rowCount - 1, 0)
        return CGFloat(rowCount) * FortiFitSpacing.minTouchTarget + CGFloat(dividerCount)
    }

    private var hasOverflow: Bool { suggestions.count > maxVisibleRows }

    @ViewBuilder
    private var suggestionRows: some View {
        ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
            Button {
                text = suggestion.name
                showDropdown = false
                isInputFocused = false
            } label: {
                HStack {
                    Text(suggestion.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FortiFitColors.primaryText)
                    Spacer()
                }
                .frame(height: FortiFitSpacing.minTouchTarget)
                .padding(.horizontal, FortiFitSpacing.cardPadding)
                .background(
                    index == 0
                        ? FortiFitColors.primaryAccent.opacity(0.1)
                        : Color.clear
                )
            }
            .buttonStyle(.plain)

            if index < suggestions.count - 1 {
                Rectangle()
                    .fill(FortiFitColors.border)
                    .frame(height: 1)
            }


        }
    }

    private var dropdownContent: some View {
        VStack(spacing: 0) {
            if hasOverflow {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        suggestionRows
                    }
                }
                .frame(height: dropdownHeight)
                .clipped()
                .scrollBounceBehavior(.basedOnSize)
            } else {
                VStack(spacing: 0) {
                    suggestionRows
                }
            }


        }
        .background(
            RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadiusSmall)
                .fill(FortiFitColors.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadiusSmall)
                .stroke(FortiFitColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadiusSmall))
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var text = "Ben"
        var body: some View {
            VStack(spacing: 40) {
                FortiFitExerciseAutocomplete(
                    placeholder: "Exercise name",
                    text: $text,
                    suggestions: [
                        .init(name: "Bench Press", isFromHistory: true),
                        .init(name: "Incline Bench Press", isFromHistory: false),
                        .init(name: "Dumbbell Bench Press", isFromHistory: false)
                    ],
                    onQueryChanged: { _ in }
                )

                Text("Other content below")
                    .foregroundStyle(FortiFitColors.mutedText)
            }
            .padding()
            .background(FortiFitColors.background)
        }
    }
    return PreviewWrapper()
}
