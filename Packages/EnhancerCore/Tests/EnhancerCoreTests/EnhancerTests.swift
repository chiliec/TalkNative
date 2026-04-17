import Testing
import Foundation
@testable import EnhancerCore

@Suite("Enhancer")
struct EnhancerTests {
    private func sampleRequest() -> EnhancementRequest {
        EnhancementRequest(
            inputText: "hey",
            variants: [
                VariantRequest(presetID: UUID(), presetLabel: "A", presetInstructions: "ia"),
                VariantRequest(presetID: UUID(), presetLabel: "B", presetInstructions: "ib"),
                VariantRequest(presetID: UUID(), presetLabel: "C", presetInstructions: "ic")
            ]
        )
    }

    @Test func emitsStartDeltaCompleteForEachVariantInOrder() async throws {
        let provider = StubLanguageModelProvider(scriptedChunks: ["Hi", " there"])
        let enhancer = Enhancer(provider: provider)
        let request = sampleRequest()

        var events: [VariantChunk] = []
        for await event in enhancer.enhance(request) {
            events.append(event)
        }

        // Per variant: started, delta "Hi", delta " there", completed → 4 events
        let expectedPerVariant = 4
        #expect(events.count == request.variants.count * expectedPerVariant)

        for (index, v) in request.variants.enumerated() {
            let base = index * expectedPerVariant
            if case .started(let pid) = events[base] {
                #expect(pid == v.presetID)
            } else { Issue.record("expected .started at \(base)") }
            if case .completed(let pid, let text) = events[base + 3] {
                #expect(pid == v.presetID)
                #expect(text == "Hi there")
            } else { Issue.record("expected .completed at \(base + 3)") }
        }
    }

    @Test func mapsGuardrailViolationToFailedEventPerVariant() async throws {
        struct Guardrail: Error {}
        let provider = StubLanguageModelProvider(
            scriptedChunks: ["partial"],
            scriptedError: Guardrail()
        )
        let enhancer = Enhancer(
            provider: provider,
            errorMapper: { _ in .guardrailViolation }
        )

        var failures = 0
        for await event in enhancer.enhance(sampleRequest()) {
            if case .failed(_, .guardrailViolation) = event { failures += 1 }
        }
        #expect(failures == 3)
    }

    @Test func cancellationStopsMidStream() async throws {
        let provider = StubLanguageModelProvider(
            scriptedChunks: Array(repeating: "x", count: 100),
            chunkDelay: .milliseconds(10)
        )
        let enhancer = Enhancer(provider: provider)
        let request = sampleRequest()

        let task = Task {
            var count = 0
            for await _ in enhancer.enhance(request) {
                count += 1
                if count == 3 { break }  // consumer breaks early
            }
            return count
        }
        let received = await task.value
        #expect(received == 3)
    }
}
