import SwiftUI

struct SearchSuggestionsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let suggestions: [MapSearchSuggestion]
    let onSelect: (MapSearchSuggestion) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                Button {
                    onSelect(suggestion)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.primary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)

                            if !visibleSubtitle(for: suggestion).isEmpty {
                                Text(visibleSubtitle(for: suggestion))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 58)
                }
                .buttonStyle(StarFlyPressStyle())
                .accessibilityLabel(accessibilityLabel(for: suggestion))
                .accessibilityHint("選取此位置")

                if index < suggestions.count - 1 {
                    Divider()
                        .padding(.leading, 46)
                }
            }
        }
        .starFlyGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func accessibilityLabel(for suggestion: MapSearchSuggestion) -> String {
        let subtitle = visibleSubtitle(for: suggestion)
        return subtitle.isEmpty ? suggestion.title : "\(suggestion.title), \(subtitle)"
    }

    private func visibleSubtitle(for suggestion: MapSearchSuggestion) -> String {
        let invisibleCharacters = CharacterSet.whitespacesAndNewlines.union(
            CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{FEFF}")
        )
        let detail = suggestion.subtitle.trimmingCharacters(in: invisibleCharacters)
        return detail
    }
}
