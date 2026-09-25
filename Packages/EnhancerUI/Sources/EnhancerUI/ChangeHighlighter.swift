import SwiftUI

/// Marks the words in a rewrite that differ from the original, so learners can
/// see what the model fixed. Word-level, exact match: "friday?" → "Friday?" is
/// a change, because capitalization is exactly the kind of fix worth noticing.
public enum ChangeHighlighter {
    public struct Segment: Equatable, Sendable {
        public let text: String
        public let isChanged: Bool
    }

    /// Splits `revised` into words and whitespace runs, flagging words absent
    /// from `original`. Whitespace is never flagged.
    public static func segments(original: String, revised: String) -> [Segment] {
        let tokens = tokenize(revised)
        let originalWords = tokenize(original).filter { !$0.isWhitespace }
        let revisedWords = tokens.filter { !$0.isWhitespace }
        let inserted = Set(
            revisedWords.difference(from: originalWords).insertions.compactMap { change -> Int? in
                if case .insert(let offset, _, _) = change { return offset }
                return nil
            })
        var wordIndex = 0
        return tokens.map { token in
            if token.isWhitespace { return Segment(text: token, isChanged: false) }
            defer { wordIndex += 1 }
            return Segment(text: token, isChanged: inserted.contains(wordIndex))
        }
    }

    /// `revised` with changed words bolded and tinted. Bold carries the signal
    /// for readers who can't rely on color.
    public static func attributed(original: String, revised: String, tint: Color) -> AttributedString {
        var result = AttributedString()
        for segment in segments(original: original, revised: revised) {
            var run = AttributedString(segment.text)
            if segment.isChanged {
                run.inlinePresentationIntent = .stronglyEmphasized
                run.backgroundColor = tint
            }
            result += run
        }
        return result
    }

    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var currentIsSpace: Bool?
        for char in text {
            let isSpace = char.isWhitespace
            if let prev = currentIsSpace, prev != isSpace {
                tokens.append(current)
                current = ""
            }
            current.append(char)
            currentIsSpace = isSpace
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
}

extension String {
    fileprivate var isWhitespace: Bool { allSatisfy(\.isWhitespace) }
}
