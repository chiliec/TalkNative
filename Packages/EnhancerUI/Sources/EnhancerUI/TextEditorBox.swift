import SwiftUI

public struct TextEditorBox: View {
    @Binding public var text: String
    public let maxChars: Int

    public init(text: Binding<String>, maxChars: Int = 2000) {
        self._text = text
        self.maxChars = maxChars
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            TextEditor(text: $text)
                .frame(minHeight: 120)
                .padding(8)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            HStack {
                if text.count > maxChars {
                    Label("Too long — trim to \(maxChars) characters.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red).font(.caption)
                }
                Spacer()
                Text("\(text.count) / \(maxChars)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(text.count > maxChars ? .red : .secondary)
            }
        }
    }
}
