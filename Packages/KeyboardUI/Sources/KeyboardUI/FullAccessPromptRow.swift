import SwiftUI

/// A keyboard extension cannot reach `UIApplication.shared`, so this cannot
/// deep-link into Settings. It shows the path as text instead.
public struct FullAccessPromptRow: View {
    public let onDismiss: () -> Void

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Using built-in presets only")
                    .font(.caption.weight(.semibold))
                Text(
                    "For your custom presets and Recents: Settings → General → Keyboard → Keyboards → TalkNative → Allow Full Access"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .accessibilityIdentifier("keyboardPanel.fullAccessPrompt")
    }
}
