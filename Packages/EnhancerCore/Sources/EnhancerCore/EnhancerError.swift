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
        case .modelUnavailable:
            return "Apple Intelligence isn't available right now."
        case .cancelled:
            return "Cancelled."
        case .unknown:
            return "Something went wrong."
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .rateLimited, .unknown: return true
        default: return false
        }
    }
}
