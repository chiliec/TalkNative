import Foundation

/// The subset of `UITextDocumentProxy` this package needs.
///
/// Declared here so capture and replacement logic can be unit-tested on macOS
/// without UIKit. `LiveTextDocumentProxy` in the keyboard target forwards to
/// the real `UITextDocumentProxy`.
public protocol TextDocumentProxying: AnyObject {
    var selectedText: String? { get }
    var documentContextBeforeInput: String? { get }
    var documentContextAfterInput: String? { get }
    func insertText(_ text: String)
    func deleteBackward()
}
