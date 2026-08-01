import Testing
@testable import TextReplacement

@Suite("ReplacementPlan")
struct ReplacementPlanTests {
    @Test func selectionPlanAlwaysDeletesExactlyOnce() {
        let captured = CapturedText(text: "a very long selected sentence", source: .selection)
        let plan = ReplacementPlan.replacing(captured, with: "rewritten")
        #expect(plan.deleteCount == 1)
        #expect(plan.insert == "rewritten")
    }

    @Test func contextPlanDeletesOnePerGraphemeCluster() {
        let captured = CapturedText(text: "hello", source: .contextBefore)
        let plan = ReplacementPlan.replacing(captured, with: "hi")
        #expect(plan.deleteCount == 5)
    }

    @Test(arguments: UnicodeCorpus.samples)
    func contextDeleteCountUsesGraphemesNotUTF16(sample: (name: String, text: String)) {
        let captured = CapturedText(text: sample.text, source: .contextBefore)
        let plan = ReplacementPlan.replacing(captured, with: "x")
        #expect(plan.deleteCount == sample.text.count, "\(sample.name)")
    }

    @Test func undoPlanDeletesTheInsertedTextAndRestoresTheOriginal() {
        let captured = CapturedText(text: "original words", source: .selection)
        let plan = ReplacementPlan.replacing(captured, with: "new \u{1F44D}")
        let undo = ReplacementPlan.undoing(plan, restoring: captured)
        #expect(undo.deleteCount == 5)  // "new " + one emoji grapheme
        #expect(undo.insert == "original words")
    }

    @Test func applyDeletesThenInserts() {
        let proxy = StubTextDocumentProxy(before: "Say ", selected: "hello", after: " now")
        let captured = CapturedText(text: "hello", source: .selection)
        TextReplacer.apply(ReplacementPlan.replacing(captured, with: "greetings"), to: proxy)
        #expect(proxy.document == "Say greetings now")
    }

    @Test func applyOnContextSourceDeletesOnlyTheCapturedSpan() {
        let proxy = StubTextDocumentProxy(before: "keep this hello", after: "")
        let captured = CapturedText(text: "hello", source: .contextBefore)
        TextReplacer.apply(ReplacementPlan.replacing(captured, with: "goodbye"), to: proxy)
        #expect(proxy.document == "keep this goodbye")
    }

    @Test func applyWithZeroDeleteCountOnlyInserts() {
        let proxy = StubTextDocumentProxy(before: "abc", after: "")
        TextReplacer.apply(ReplacementPlan(deleteCount: 0, insert: "def"), to: proxy)
        #expect(proxy.document == "abcdef")
    }
}
