import Foundation
import EnhancerCore
import TextReplacement

public enum KeyboardPanelState: Equatable {
    /// Nothing usable in the field.
    case needsText
    /// The selection is larger than we will operate on. Never clamped — see `TextCapture`.
    case selectionTooLong(count: Int)
    /// Text captured, variants may be shown and tapped.
    case ready(CapturedText)
    /// A generation is in flight. Re-capture is suppressed in this state.
    case enhancing(CapturedText)
    /// Text was replaced and can be undone while `undo` remains valid.
    case replaced(undo: ReplacementPlan, original: CapturedText)
    case unavailable(LanguageModelAvailability.Reason)
}
