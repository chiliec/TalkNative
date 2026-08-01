import Foundation

/// An in-memory model of a text field, for tests.
///
/// Tests assert on `document` — the final state of the user's text — rather
/// than on call sequences. Whether we called the right methods matters less
/// than whether the user's text is correct afterwards.
public final class StubTextDocumentProxy: TextDocumentProxying {
    public var before: String
    public var selected: String
    public var after: String

    public init(before: String = "", selected: String = "", after: String = "") {
        self.before = before
        self.selected = selected
        self.after = after
    }

    public var document: String { before + selected + after }

    public var selectedText: String? { selected.isEmpty ? nil : selected }
    public var documentContextBeforeInput: String? { before.isEmpty ? nil : before }
    public var documentContextAfterInput: String? { after.isEmpty ? nil : after }

    public func insertText(_ text: String) {
        selected = ""
        before += text
    }

    public func deleteBackward() {
        if !selected.isEmpty {
            selected = ""
            return
        }
        // `removeLast` drops one `Character`, i.e. one extended grapheme
        // cluster — the same unit a real backspace removes.
        if !before.isEmpty {
            before.removeLast()
        }
    }
}
