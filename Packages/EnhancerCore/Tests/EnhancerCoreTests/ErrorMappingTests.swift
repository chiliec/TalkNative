import Testing
@testable import EnhancerCore

@Suite("EnhancerError")
struct ErrorMappingTests {
    @Test func guardrailViolationHasRetryableAdvice() {
        let err: EnhancerError = .guardrailViolation
        #expect(err.userFacingMessage.contains("rephrasing"))
        #expect(err.isRetryable == false)
    }

    @Test func rateLimitedIsRetryable() {
        #expect(EnhancerError.rateLimited.isRetryable == true)
    }

    /// The keyboard panel renders these strings directly, so each reason has to
    /// say something actionable — a downloading model must not read the same as
    /// an ineligible device.
    @Test func unavailableMessagesAreReasonSpecific() {
        let messages = [
            EnhancerError.modelUnavailable(.deviceNotEligible).userFacingMessage,
            EnhancerError.modelUnavailable(.appleIntelligenceNotEnabled).userFacingMessage,
            EnhancerError.modelUnavailable(.modelNotReady).userFacingMessage,
            EnhancerError.modelUnavailable(.other("boom")).userFacingMessage,
            EnhancerError.modelUnavailable(.cloudConsentRequired).userFacingMessage,
            EnhancerError.modelUnavailable(.fullAccessRequired).userFacingMessage,
        ]
        #expect(Set(messages).count == 6)
        #expect(messages[1].contains("Settings"))
        #expect(messages[2].contains("downloading"))
        #expect(messages[4] == "Open TalkNative once to allow cloud mode on this iPhone.")
        #expect(messages[5] == "Turn on Allow Full Access for TalkNative in Settings to use it on this iPhone.")
    }

    @Test func offlineIsRetryableWithOwnMessage() {
        #expect(EnhancerError.offline.userFacingMessage == "No internet connection.")
        #expect(EnhancerError.offline.isRetryable == true)
    }

    @Test func defaultMapperPassesEnhancerErrorsThrough() {
        #expect(Enhancer.defaultErrorMapper(EnhancerError.guardrailViolation) == .guardrailViolation)
        #expect(Enhancer.defaultErrorMapper(EnhancerError.offline) == .offline)
        #expect(Enhancer.defaultErrorMapper(CancellationError()) == .cancelled)
    }

    @Test func onlyADownloadingModelIsWorthRetrying() {
        #expect(EnhancerError.modelUnavailable(.modelNotReady).isRetryable == true)
        #expect(EnhancerError.modelUnavailable(.deviceNotEligible).isRetryable == false)
        #expect(EnhancerError.modelUnavailable(.appleIntelligenceNotEnabled).isRetryable == false)
    }

    @Test func unknownWrapsUnderlying() {
        struct X: Error {}
        let err = EnhancerError.unknown(X())
        #expect(err.userFacingMessage.contains("Something went wrong"))
    }
}
