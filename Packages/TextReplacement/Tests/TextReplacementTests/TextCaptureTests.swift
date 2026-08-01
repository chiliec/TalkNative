import Testing
@testable import TextReplacement

@Suite("TextCapture")
struct TextCaptureTests {
    @Test func selectionWinsOverContext() {
        let proxy = StubTextDocumentProxy(before: "context text", selected: "chosen", after: "")
        #expect(TextCapture.capture(from: proxy) == .captured(
            CapturedText(text: "chosen", source: .selection)))
    }

    @Test func blankSelectionFallsThroughToContext() {
        let proxy = StubTextDocumentProxy(before: "the draft", selected: "   \n ", after: "")
        #expect(TextCapture.capture(from: proxy) == .captured(
            CapturedText(text: "the draft", source: .contextBefore)))
    }

    @Test func emptyFieldYieldsEmpty() {
        #expect(TextCapture.capture(from: StubTextDocumentProxy()) == .empty)
    }

    @Test func blankContextYieldsEmpty() {
        let proxy = StubTextDocumentProxy(before: "   \n\t ", after: "")
        #expect(TextCapture.capture(from: proxy) == .empty)
    }

    @Test func afterContextIsIgnored() {
        let proxy = StubTextDocumentProxy(before: "", selected: "", after: "trailing text")
        #expect(TextCapture.capture(from: proxy) == .empty)
    }

    @Test func overLongContextKeepsTrailingCharacters() {
        let long = String(repeating: "a", count: 40) + "TAIL"
        let proxy = StubTextDocumentProxy(before: long, after: "")
        let outcome = TextCapture.capture(from: proxy, maxChars: 10)
        #expect(outcome == .captured(CapturedText(text: "aaaaaaTAIL", source: .contextBefore)))
    }

    @Test func overLongSelectionIsRejectedNotClamped() {
        let long = String(repeating: "b", count: 25)
        let proxy = StubTextDocumentProxy(before: "x", selected: long, after: "")
        #expect(TextCapture.capture(from: proxy, maxChars: 10) == .selectionTooLong(count: 25))
    }

    @Test func selectionExactlyAtLimitIsAccepted() {
        let exact = String(repeating: "c", count: 10)
        let proxy = StubTextDocumentProxy(selected: exact)
        #expect(TextCapture.capture(from: proxy, maxChars: 10) == .captured(
            CapturedText(text: exact, source: .selection)))
    }

    @Test func lengthsAreCountedInGraphemeClusters() {
        // Five flags: 5 graphemes, 20 UTF-16 units. Must be accepted at maxChars 10.
        let flags = String(repeating: "\u{1F1FA}\u{1F1E6}", count: 5)
        let proxy = StubTextDocumentProxy(selected: flags)
        #expect(TextCapture.capture(from: proxy, maxChars: 10) == .captured(
            CapturedText(text: flags, source: .selection)))
    }
}
