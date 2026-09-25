import Testing
@testable import EnhancerUI

@Suite("ChangeHighlighter")
struct ChangeHighlighterTests {
    private func changed(_ original: String, _ revised: String) -> [String] {
        ChangeHighlighter.segments(original: original, revised: revised).filter(\.isChanged).map(\.text)
    }

    @Test func flagsReplacedAndInsertedWords() {
        #expect(changed("i has went to the store", "I went to the store") == ["I"])
        #expect(changed("send me docs", "please send me the docs") == ["please", "the"])
    }

    @Test func capitalizationAndPunctuationCountAsChanges() {
        #expect(changed("until friday?", "by Friday?") == ["by", "Friday?"])
    }

    @Test func identicalTextHasNoChanges() {
        #expect(changed("all good here", "all good here").isEmpty)
    }

    @Test func segmentsRoundTripToRevisedText() {
        let revised = "Hey,  could you\nsend it by Friday?"
        let joined = ChangeHighlighter.segments(original: "hey send it friday", revised: revised).map(\.text).joined()
        #expect(joined == revised)
    }

    @Test func whitespaceIsNeverFlagged() {
        let segments = ChangeHighlighter.segments(original: "", revised: "a b")
        #expect(segments.map(\.isChanged) == [true, false, true])
    }
}
