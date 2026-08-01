import Foundation

/// Text pulled out of the host app's field, tagged with how it was obtained.
///
/// `source` determines the delete arithmetic in `ReplacementPlan`, so it must
/// always reflect the field's *current* state, not how the text originally
/// arrived.
public struct CapturedText: Equatable, Sendable {
    public enum Source: Equatable, Sendable {
        /// The user had text selected. One `deleteBackward()` clears all of it.
        case selection
        /// No selection; text was read from `documentContextBeforeInput`.
        /// Requires one `deleteBackward()` per grapheme cluster.
        case contextBefore
    }

    public let text: String
    public let source: Source

    public init(text: String, source: Source) {
        self.text = text
        self.source = source
    }
}

public enum CaptureOutcome: Equatable, Sendable {
    case captured(CapturedText)
    /// The selection exceeds `maxChars`. Deliberately not clamped — see `TextCapture`.
    case selectionTooLong(count: Int)
    case empty
}
