import Testing
import Foundation
import EnhancerCore
@testable import EnhancerUI

@Suite("VariantViewState")
struct VariantViewStateTests {
    @Test func transitionsFromWaitingToStreamingToComplete() {
        var state = VariantViewState(presetID: UUID(), presetLabel: "Casual")
        #expect(state.phase == .waiting)
        state.apply(.started(presetID: state.presetID))
        #expect(state.phase == .streaming)
        state.apply(.delta(presetID: state.presetID, text: "Hi"))
        state.apply(.delta(presetID: state.presetID, text: " there"))
        #expect(state.text == "Hi there")
        state.apply(.completed(presetID: state.presetID, fullText: "Hi there"))
        #expect(state.phase == .completed)
    }

    @Test func ignoresEventsForOtherPreset() {
        var state = VariantViewState(presetID: UUID(), presetLabel: "A")
        state.apply(.delta(presetID: UUID(), text: "wrong"))
        #expect(state.text.isEmpty)
        #expect(state.phase == .waiting)
    }

    @Test func failedSetsErrorPhase() {
        var state = VariantViewState(presetID: UUID(), presetLabel: "A")
        state.apply(.failed(presetID: state.presetID, error: .guardrailViolation))
        if case .failed(let e) = state.phase { #expect(e == .guardrailViolation) }
        else { Issue.record("expected .failed phase") }
    }
}
