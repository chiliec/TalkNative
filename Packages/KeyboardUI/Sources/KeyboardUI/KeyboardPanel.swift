import SwiftUI
import EnhancerCore
import EnhancerUI
import TextReplacement

public struct KeyboardPanel: View {
    @State private var viewModel: KeyboardPanelViewModel
    private let isFullAccessPromptDismissed: Bool
    private let onDismissFullAccessPrompt: () -> Void

    public init(
        viewModel: KeyboardPanelViewModel,
        isFullAccessPromptDismissed: Bool,
        onDismissFullAccessPrompt: @escaping () -> Void
    ) {
        self._viewModel = State(initialValue: viewModel)
        self.isFullAccessPromptDismissed = isFullAccessPromptDismissed
        self.onDismissFullAccessPrompt = onDismissFullAccessPrompt
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !viewModel.hasFullAccess && !isFullAccessPromptDismissed {
                FullAccessPromptRow(onDismiss: onDismissFullAccessPrompt)
            }

            switch viewModel.state {
            case .needsText:
                message("Select the text you want to rewrite, or type something first.")
                    .accessibilityIdentifier("keyboardPanel.needsText")

            case .selectionTooLong(let count):
                message("That selection is \(count) characters. Select up to \(TextCapture.defaultMaxChars).")
                    .accessibilityIdentifier("keyboardPanel.selectionTooLong")

            case .unavailable(let reason):
                message(EnhancerError.modelUnavailable(reason).userFacingMessage)
                    .accessibilityIdentifier("keyboardPanel.unavailable")

            case .ready(let captured):
                CapturedTextStrip(
                    text: captured.text,
                    isClamped: captured.text.count == TextCapture.defaultMaxChars)
                variantRows(isEnabled: true)

            case .enhancing(let captured):
                CapturedTextStrip(
                    text: captured.text,
                    isClamped: captured.text.count == TextCapture.defaultMaxChars)
                variantRows(isEnabled: false)

            case .replaced:
                replacedStrip
                variantRows(isEnabled: false)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .task { await viewModel.onAppear() }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
    }

    private var replacedStrip: some View {
        HStack(spacing: 8) {
            Label("Replaced", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
            Spacer()
            Button("Undo") { viewModel.undo() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier("keyboardPanel.undo")
        }
        .padding(.horizontal, 10)
        .accessibilityIdentifier("keyboardPanel.replacedConfirmation")
    }

    /// Rows stay visible after a replacement but go inert. Undoing first keeps
    /// the undo plan's precondition — inserted text immediately behind the
    /// cursor — trivially true.
    private func variantRows(isEnabled: Bool) -> some View {
        VStack(spacing: 6) {
            ForEach(viewModel.enhancement.variantStates) { state in
                CompactVariantRow(state: state) {
                    viewModel.select(variantText: state.text)
                }
            }
        }
        .padding(.horizontal, 10)
        .disabled(!isEnabled)
    }
}
