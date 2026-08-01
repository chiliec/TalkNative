import Testing
@testable import TextReplacement

@Suite("Replace/undo round trip")
struct RoundTripTests {
    @Test(arguments: UnicodeCorpus.samples)
    func selectionRoundTripRestoresDocumentExactly(sample: (name: String, text: String)) {
        let proxy = StubTextDocumentProxy(before: "PRE ", selected: sample.text, after: " POST")
        let start = proxy.document

        guard case .captured(let captured) = TextCapture.capture(from: proxy) else {
            Issue.record("expected a capture for \(sample.name)")
            return
        }
        #expect(captured.source == .selection)

        let plan = ReplacementPlan.replacing(captured, with: "REWRITTEN \u{1F44D}")
        TextReplacer.apply(plan, to: proxy)
        #expect(proxy.document == "PRE REWRITTEN \u{1F44D} POST", "\(sample.name)")

        // After a replacement there is no selection, so the restored text must
        // be re-sourced as `.contextBefore` for any subsequent operation.
        TextReplacer.apply(ReplacementPlan.undoing(plan, restoring: captured), to: proxy)
        #expect(proxy.document == start, "\(sample.name)")
    }

    @Test(arguments: UnicodeCorpus.samples)
    func contextRoundTripRestoresDocumentExactly(sample: (name: String, text: String)) {
        let proxy = StubTextDocumentProxy(before: sample.text, after: "")
        let start = proxy.document

        guard case .captured(let captured) = TextCapture.capture(from: proxy) else {
            Issue.record("expected a capture for \(sample.name)")
            return
        }
        #expect(captured.source == .contextBefore)

        let plan = ReplacementPlan.replacing(captured, with: "REWRITTEN")
        TextReplacer.apply(plan, to: proxy)
        #expect(proxy.document == "REWRITTEN", "\(sample.name)")

        TextReplacer.apply(ReplacementPlan.undoing(plan, restoring: captured), to: proxy)
        #expect(proxy.document == start, "\(sample.name)")
    }

    @Test func contextReplacementNeverTouchesTextBeforeTheCapturedSpan() {
        // Regression guard: a UTF-16 delete count would eat into "UNTOUCHED".
        let proxy = StubTextDocumentProxy(before: "UNTOUCHED \u{1F1FA}\u{1F1E6}\u{1F44D}", after: "")
        let captured = CapturedText(text: "\u{1F1FA}\u{1F1E6}\u{1F44D}", source: .contextBefore)
        TextReplacer.apply(ReplacementPlan.replacing(captured, with: "ok"), to: proxy)
        #expect(proxy.document == "UNTOUCHED ok")
    }

    @Test func secondReplacementAfterUndoUsesContextSemantics() {
        let proxy = StubTextDocumentProxy(before: "Draft: ", selected: "old text", after: "")
        guard case .captured(let captured) = TextCapture.capture(from: proxy) else {
            Issue.record("expected a capture"); return
        }
        let plan = ReplacementPlan.replacing(captured, with: "first")
        TextReplacer.apply(plan, to: proxy)
        TextReplacer.apply(ReplacementPlan.undoing(plan, restoring: captured), to: proxy)

        // The restored text is no longer selected, so it must be re-sourced.
        let restored = CapturedText(text: captured.text, source: .contextBefore)
        TextReplacer.apply(ReplacementPlan.replacing(restored, with: "second"), to: proxy)
        #expect(proxy.document == "Draft: second")
    }
}
