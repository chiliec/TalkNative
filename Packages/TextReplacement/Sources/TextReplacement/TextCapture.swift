import Foundation

public enum TextCapture {
    /// Matches `TextEditorBox(maxChars: 2000)` in the host app.
    public static let defaultMaxChars = 2000

    /// Selection first, then the text before the cursor.
    ///
    /// An over-long *selection* is rejected rather than clamped. A `.selection`
    /// plan deletes with a single `deleteBackward()`, which clears the entire
    /// selection regardless of how much of it was captured — so clamping a
    /// 5000-character selection to its trailing 2000 would delete all 5000 and
    /// insert a rewrite of the last 2000, silently destroying 3000 characters.
    /// Clamping is safe only for `.contextBefore`, where the delete count is
    /// derived from the clamped string itself.
    public static func capture(
        from proxy: any TextDocumentProxying,
        maxChars: Int = defaultMaxChars
    ) -> CaptureOutcome {
        if let selected = proxy.selectedText, !isBlank(selected) {
            if selected.count > maxChars {
                return .selectionTooLong(count: selected.count)
            }
            return .captured(CapturedText(text: selected, source: .selection))
        }

        if let before = proxy.documentContextBeforeInput, !isBlank(before) {
            return .captured(CapturedText(text: clamp(before, to: maxChars), source: .contextBefore))
        }

        return .empty
    }

    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func clamp(_ text: String, to maxChars: Int) -> String {
        guard text.count > maxChars else { return text }
        return String(text.suffix(maxChars))
    }
}
