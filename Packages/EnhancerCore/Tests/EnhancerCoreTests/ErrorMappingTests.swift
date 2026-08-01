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
        ]
        #expect(Set(messages).count == 4)
        #expect(messages[1].contains("Settings"))
        #expect(messages[2].contains("downloading"))
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
