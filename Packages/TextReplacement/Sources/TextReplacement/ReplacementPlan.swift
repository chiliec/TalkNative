import Foundation

/// A backspace count plus the string to type. The only two numbers that can
/// destroy the user's text, so they live in one small, heavily tested type.
public struct ReplacementPlan: Equatable, Sendable {
    public let deleteCount: Int
    public let insert: String

    public init(deleteCount: Int, insert: String) {
        self.deleteCount = deleteCount
        self.insert = insert
    }

    public static func replacing(_ captured: CapturedText, with text: String) -> ReplacementPlan {
        switch captured.source {
        case .selection:
            // A single `deleteBackward()` clears an entire selection atomically.
            return ReplacementPlan(deleteCount: 1, insert: text)
        case .contextBefore:
            // `deleteBackward()` removes one user-perceived character, so the
            // count is grapheme clusters. `utf16.count` would over-delete on
            // emoji, flags, and combining marks.
            return ReplacementPlan(deleteCount: captured.text.count, insert: text)
        }
    }

    /// The inverse of `plan`, assuming `plan.insert` still sits immediately
    /// behind the cursor. Callers must invalidate the undo plan on any external
    /// edit — see `KeyboardPanelViewModel`.
    public static func undoing(
        _ plan: ReplacementPlan,
        restoring captured: CapturedText
    ) -> ReplacementPlan {
        ReplacementPlan(deleteCount: plan.insert.count, insert: captured.text)
    }
}
