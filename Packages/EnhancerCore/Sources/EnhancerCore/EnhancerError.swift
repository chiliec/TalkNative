import Foundation

public enum EnhancerError: Error, Sendable, Equatable {
    case guardrailViolation
    case rateLimited
    case exceededContextWindow
    case modelUnavailable(LanguageModelAvailability.Reason)
    case cancelled
    case unknown(String)

    public static func unknown(_ error: Error) -> EnhancerError {
        .unknown(String(describing: error))
    }

    public var userFacingMessage: String {
        switch self {
        case .guardrailViolation:
            return "Couldn't enhance this — try rephrasing."
        case .rateLimited:
            return "Too many requests — try again in a moment."
        case .exceededContextWindow:
            return "Text is too complex — try splitting it."
        case .modelUnavailable(let reason):
            return Self.unavailableMessage(reason)
        case .cancelled:
            return "Cancelled."
        case .unknown:
            return "Something went wrong."
        }
    }

    /// Short, reason-specific copy. Kept brief because the keyboard panel shows
    /// it in a footnote; the app's `UnsupportedDeviceView` carries longer prose
    /// for the same reasons.
    private static func unavailableMessage(_ reason: LanguageModelAvailability.Reason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings to use TalkNative."
        case .modelNotReady:
            return "Apple Intelligence is still downloading — try again shortly."
        case .other:
            return "Apple Intelligence isn't available right now."
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .rateLimited, .unknown: return true
        // The model becoming ready is a matter of waiting, unlike an ineligible
        // device or a disabled feature, which need the user to act.
        case .modelUnavailable(.modelNotReady): return true
        default: return false
        }
    }
}
