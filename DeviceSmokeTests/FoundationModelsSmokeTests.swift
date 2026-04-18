import Testing
import Foundation
import EnhancerCore

@Suite("FoundationModels smoke — runs on Apple Intelligence–capable device/sim")
struct FoundationModelsSmokeTests {
    private let inputs = [
        "hey can u send me the docs asap thx",
        "I would like to kindly request your attendance to the upcoming meeting",
        "it a funny situation but i dont know what to do with",
        "hit the nail on the head i think",
        "ok"
    ]

    @Test(.enabled(if: FoundationModelsSmokeTests.available()))
    func eachInputProducesNonEmptyDifferentOutputPerBuiltInPreset() async throws {
        let provider = FoundationModelsProvider()
        let enhancer = Enhancer(provider: provider)

        for text in inputs {
            let variants = [
                VariantRequest(presetID: UUID(), presetLabel: "Casual",
                               presetInstructions: "Everyday conversational language."),
                VariantRequest(presetID: UUID(), presetLabel: "Professional",
                               presetInstructions: "Business-appropriate, courteous."),
                VariantRequest(presetID: UUID(), presetLabel: "Warm",
                               presetInstructions: "Kind, considerate phrasing.")
            ]
            let request = EnhancementRequest(inputText: text, variants: variants)

            var outputs: [UUID: String] = [:]
            for await event in enhancer.enhance(request) {
                if case let .completed(pid, full) = event { outputs[pid] = full }
            }
            for variant in variants {
                let produced = outputs[variant.presetID] ?? ""
                #expect(!produced.isEmpty, "empty output for \(variant.presetLabel) on \(text)")
                #expect(produced != text, "unchanged output for \(variant.presetLabel)")
                let refusalMarkers = ["I can't", "I'm sorry", "I am unable"]
                #expect(refusalMarkers.allSatisfy { !produced.contains($0) }, "refusal-like output")
            }
        }
    }

    static func available() -> Bool {
        FoundationModelsProvider().availability == .available
    }
}
