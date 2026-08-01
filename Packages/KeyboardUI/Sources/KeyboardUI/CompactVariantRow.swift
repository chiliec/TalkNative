import SwiftUI
import EnhancerCore
import EnhancerUI

/// A variant at keyboard density: one line of label, two lines of text, one button.
public struct CompactVariantRow: View {
    public let state: VariantViewState
    public let onUse: () -> Void

    public init(state: VariantViewState, onUse: @escaping () -> Void) {
        self.state = state
        self.onUse = onUse
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.presetLabel.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                switch state.phase {
                case .waiting:
                    Text("Waiting…").font(.footnote).foregroundStyle(.secondary).italic()
                case .streaming:
                    Text(state.text.isEmpty ? "Generating…" : state.text)
                        .font(.footnote)
                        .foregroundStyle(state.text.isEmpty ? .secondary : .primary)
                        .italic(state.text.isEmpty)
                        .lineLimit(2)
                case .completed:
                    Text(state.text).font(.footnote).lineLimit(2)
                case .failed(let error):
                    Text(error.userFacingMessage).font(.footnote).foregroundStyle(.red).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Use", action: onUse)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(state.phase != .completed)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("keyboardPanel.variantRow")
    }
}
