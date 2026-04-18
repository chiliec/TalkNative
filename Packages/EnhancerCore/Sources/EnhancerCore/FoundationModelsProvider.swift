import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

public struct FoundationModelsProvider: LanguageModelProvider {

    public init() {}

    public var availability: LanguageModelAvailability {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            return .unavailable(Self.mapReason(reason))
        }
        #else
        return .unavailable(.deviceNotEligible)
        #endif
    }

    public func stream(instructions: String, prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                #if canImport(FoundationModels)
                do {
                    let session = LanguageModelSession(
                        model: SystemLanguageModel.default,
                        instructions: Instructions { instructions }
                    )
                    let responseStream = session.streamResponse(to: prompt)
                    var lastSnapshot = ""
                    for try await snapshot in responseStream {
                        if Task.isCancelled { break }
                        let full = snapshot.content
                        let delta = String(full.dropFirst(lastSnapshot.count))
                        lastSnapshot = full
                        if !delta.isEmpty { continuation.yield(delta) }
                    }
                    continuation.finish()
                } catch let error as LanguageModelSession.GenerationError {
                    continuation.finish(throwing: Self.mapError(error))
                } catch {
                    continuation.finish(throwing: error)
                }
                #else
                continuation.finish(throwing: EnhancerError.modelUnavailable(.deviceNotEligible))
                #endif
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    #if canImport(FoundationModels)
    private static func mapReason(_ reason: SystemLanguageModel.UnavailableReason) -> LanguageModelAvailability.Reason {
        switch reason {
        case .deviceNotEligible: return .deviceNotEligible
        case .appleIntelligenceNotEnabled: return .appleIntelligenceNotEnabled
        case .modelNotReady: return .modelNotReady
        @unknown default: return .other(String(describing: reason))
        }
    }

    private static func mapError(_ error: LanguageModelSession.GenerationError) -> EnhancerError {
        switch error {
        case .guardrailViolation: return .guardrailViolation
        case .rateLimited: return .rateLimited
        case .exceededContextWindow: return .exceededContextWindow
        default: return .unknown(error)
        }
    }
    #endif
}
