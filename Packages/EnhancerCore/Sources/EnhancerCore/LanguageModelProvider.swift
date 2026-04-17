import Foundation

public enum LanguageModelAvailability: Sendable, Equatable {
    case available
    case unavailable(Reason)

    public enum Reason: Sendable, Equatable {
        case deviceNotEligible
        case appleIntelligenceNotEnabled
        case modelNotReady
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
