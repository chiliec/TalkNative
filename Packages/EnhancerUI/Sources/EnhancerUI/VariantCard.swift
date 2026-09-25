import SwiftUI
import EnhancerCore

public struct VariantCard: View {
    public enum ActionKind { case copy, useThis }

    public let state: VariantViewState
    /// When set, words that differ from it are highlighted once the variant completes.
    public let original: String?
    public let actionKind: ActionKind
    public let onPrimary: () -> Void
    public let onRegenerate: () -> Void

    public init(
        state: VariantViewState,
        original: String? = nil,
        actionKind: ActionKind = .copy,
        onPrimary: @escaping () -> Void,
        onRegenerate: @escaping () -> Void
    ) {
        self.state = state
        self.original = original
        self.actionKind = actionKind
        self.onPrimary = onPrimary
        self.onRegenerate = onRegenerate
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.presetLabel.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            switch state.phase {
            case .waiting:
                Text("Waiting…").foregroundStyle(.secondary).italic()
            case .streaming:
                Text(state.text.isEmpty ? "Generating…" : state.text)
                    .foregroundStyle(state.text.isEmpty ? .secondary : .primary)
                    .italic(state.text.isEmpty)
            case .completed:
                if let original {
                    // ponytail: word-level diff; a full rewrite lights up most words. Switch to a
                    // "mostly rewritten" fallback if users find dense highlights noisy.
                    Text(
                        ChangeHighlighter.attributed(
                            original: original, revised: state.text, tint: .accentColor.opacity(0.12)))
                } else {
                    Text(state.text)
                }
            case .failed(let error):
                Text(error.userFacingMessage).foregroundStyle(.red)
            }

            HStack {
                Button(actionKind == .copy ? "Copy" : "Use this", action: onPrimary)
                    .buttonStyle(.borderedProminent)
                    .disabled(state.phase != .completed)
                    .accessibilityLabel("\(actionKind == .copy ? "Copy" : "Use") \(state.presetLabel) rewrite")
                Button("Regenerate", systemImage: "arrow.clockwise", action: onRegenerate)
                    .labelStyle(.iconOnly)
                    .disabled(state.phase == .streaming || state.phase == .waiting)
                    .accessibilityLabel("Regenerate \(state.presetLabel) rewrite")
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }
}
