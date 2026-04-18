import SwiftUI
import EnhancerCore

public struct VariantCard: View {
    public enum ActionKind { case copy, useThis }

    public let state: VariantViewState
    public let actionKind: ActionKind
    public let onPrimary: () -> Void
    public let onRegenerate: () -> Void

    public init(state: VariantViewState,
                actionKind: ActionKind = .copy,
                onPrimary: @escaping () -> Void,
                onRegenerate: @escaping () -> Void) {
        self.state = state
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
                Text(state.text)
            case .failed(let error):
                Text(error.userFacingMessage).foregroundStyle(.red)
            }

            HStack {
                Button(actionKind == .copy ? "Copy" : "Use this", action: onPrimary)
                    .buttonStyle(.borderedProminent)
                    .disabled(state.phase != .completed)
                Button("Regenerate", systemImage: "arrow.clockwise", action: onRegenerate)
                    .labelStyle(.iconOnly)
                    .disabled(state.phase == .streaming || state.phase == .waiting)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }
}
