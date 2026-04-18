import Foundation
import Observation
import EnhancerCore
import PresetKit

@Observable
@MainActor
public final class EnhancementViewModel {
    public private(set) var inputText: String = ""
    public private(set) var variantStates: [VariantViewState] = []
    public private(set) var isRunning: Bool = false

    private let enhancer: Enhancer
    private var consumerTask: Task<Void, Never>?
    private var completionContinuation: CheckedContinuation<Void, Never>?

    public init(enhancer: Enhancer) {
        self.enhancer = enhancer
    }

    public func start(inputText: String, activePresets: [Preset]) async {
        self.inputText = inputText
        self.variantStates = activePresets.map {
            VariantViewState(presetID: $0.id, presetLabel: $0.label)
        }
        let variants = activePresets.map {
            VariantRequest(presetID: $0.id, presetLabel: $0.label, presetInstructions: $0.instructions)
        }
        let request = EnhancementRequest(inputText: inputText, variants: variants)

        isRunning = true
        let task = Task { [weak self] in
            guard let self else { return }
            for await event in self.enhancer.enhance(request) {
                if Task.isCancelled { break }
                self.apply(event)
            }
            self.isRunning = false
            self.completionContinuation?.resume()
            self.completionContinuation = nil
        }
        self.consumerTask = task
    }

    public func cancel() {
        consumerTask?.cancel()
    }

    public func regenerate(presetID: UUID, activePresets: [Preset]) async {
        guard let preset = activePresets.first(where: { $0.id == presetID }) else { return }
        if let idx = variantStates.firstIndex(where: { $0.presetID == presetID }) {
            variantStates[idx] = VariantViewState(presetID: preset.id, presetLabel: preset.label)
        }
        let request = EnhancementRequest(
            inputText: inputText,
            variants: [VariantRequest(presetID: preset.id, presetLabel: preset.label, presetInstructions: preset.instructions)]
        )
        for await event in enhancer.enhance(request) {
            apply(event)
        }
    }

    public func waitForCompletion() async {
        guard isRunning else { return }
        await withCheckedContinuation { cont in
            completionContinuation = cont
        }
    }

    private func apply(_ chunk: VariantChunk) {
        switch chunk {
        case .started(let id), .delta(let id, _), .completed(let id, _), .failed(let id, _):
            if let idx = variantStates.firstIndex(where: { $0.presetID == id }) {
                variantStates[idx].apply(chunk)
            }
        }
    }
}
