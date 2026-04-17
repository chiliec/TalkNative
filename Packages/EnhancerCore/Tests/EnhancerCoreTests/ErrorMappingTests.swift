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

    @Test func unknownWrapsUnderlying() {
        struct X: Error {}
        let err = EnhancerError.unknown(X())
        #expect(err.userFacingMessage.contains("Something went wrong"))
    }
}
