import SwiftUI

/// Shows exactly what will be rewritten.
///
/// Hosts truncate `documentContextBeforeInput` at around 300 characters and we
/// cannot detect when that happened, so we show the captured text rather than
/// letting the user assume their whole draft is in play.
public struct CapturedTextStrip: View {
    public let text: String
    public let isClamped: Bool

    public init(text: String, isClamped: Bool) {
        self.text = text
        self.isClamped = isClamped
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            if isClamped {
                Text("Rewriting the last \(text.count) characters.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .accessibilityIdentifier("keyboardPanel.capturedStrip")
    }
}
