import UIKit
import TextReplacement

/// Forwards `TextDocumentProxying` to the real `UITextDocumentProxy`.
///
/// This class is the only place UIKit meets the replacement logic, which is why
/// it holds no logic of its own.
final class LiveTextDocumentProxy: TextDocumentProxying {
    private let proxy: UITextDocumentProxy

    init(_ proxy: UITextDocumentProxy) {
        self.proxy = proxy
    }

    var selectedText: String? { proxy.selectedText }
    var documentContextBeforeInput: String? { proxy.documentContextBeforeInput }
    var documentContextAfterInput: String? { proxy.documentContextAfterInput }

    func insertText(_ text: String) { proxy.insertText(text) }
    func deleteBackward() { proxy.deleteBackward() }
}
