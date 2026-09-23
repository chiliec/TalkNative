import Foundation

public enum LanguageModelAvailability: Sendable, Equatable {
    case available
    case unavailable(Reason)

    public enum Reason: Sendable, Equatable {
        case deviceNotEligible
        case appleIntelligenceNotEnabled
        case modelNotReady
        /// Cloud tier: the user hasn't allowed sending text to the gateway yet.
        case cloudConsentRequired
        /// Cloud tier, keyboard only: no network without Full Access.
        case fullAccessRequired
        case other(String)
    }
}

public protocol LanguageModelProvider: Sendable {
    var availability: LanguageModelAvailability { get }
    func stream(
        instructions: String,
        prompt: String
    ) -> AsyncThrowingStream<String, Error>
}
