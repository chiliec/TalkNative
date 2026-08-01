import Testing
@testable import TextReplacement

@Suite("StubTextDocumentProxy")
struct StubTextDocumentProxyTests {
    @Test func reportsSelectionAndContext() {
        let proxy = StubTextDocumentProxy(before: "Hello ", selected: "world", after: "!")
        #expect(proxy.selectedText == "world")
        #expect(proxy.documentContextBeforeInput == "Hello ")
        #expect(proxy.documentContextAfterInput == "!")
        #expect(proxy.document == "Hello world!")
    }

    @Test func emptyFieldsReportNil() {
        let proxy = StubTextDocumentProxy()
        #expect(proxy.selectedText == nil)
        #expect(proxy.documentContextBeforeInput == nil)
        #expect(proxy.documentContextAfterInput == nil)
    }

    @Test func deleteBackwardClearsEntireSelectionInOneCall() {
        let proxy = StubTextDocumentProxy(before: "a", selected: "bcdef", after: "g")
        proxy.deleteBackward()
        #expect(proxy.document == "ag")
        #expect(proxy.selectedText == nil)
    }

    @Test func deleteBackwardRemovesOneGraphemeClusterWhenNoSelection() {
        let proxy = StubTextDocumentProxy(before: "ab\u{1F1FA}\u{1F1E6}", after: "")
        proxy.deleteBackward()
        #expect(proxy.document == "ab")
    }

    @Test func insertTextReplacesSelection() {
        let proxy = StubTextDocumentProxy(before: "Hi ", selected: "there", after: "!")
        proxy.insertText("everyone")
        #expect(proxy.document == "Hi everyone!")
        #expect(proxy.selectedText == nil)
    }

    @Test func deleteBackwardOnEmptyDocumentIsSafe() {
        let proxy = StubTextDocumentProxy()
        proxy.deleteBackward()
        #expect(proxy.document == "")
    }
}
