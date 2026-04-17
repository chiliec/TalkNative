import Foundation

public actor Enhancer {
    public typealias ErrorMapper = @Sendable (Error) -> EnhancerError

    private let provider: LanguageModelProvider
    private let errorMapper: ErrorMapper

    public init(
        provider: LanguageModelProvider,
        errorMapper: @escaping ErrorMapper = Enhancer.defaultErrorMapper
    ) {
        self.provider = provider
        self.errorMapper = errorMapper
    }

    public static let defaultErrorMapper: ErrorMapper = { error in
        if error is CancellationError { return .cancelled }
        return .unknown(error)
    }

    public nonisolated func enhance(_ request: EnhancementRequest) -> AsyncStream<VariantChunk> {
        let provider = self.provider
        let errorMapper = self.errorMapper
        return AsyncStream { continuation in
            let task = Task {
                for variant in request.variants {
                    if Task.isCancelled { break }
                    continuation.yield(.started(presetID: variant.presetID))
                    var aggregated = ""
                    do {
                        let stream = provider.stream(
                            instructions: Prompts.systemInstructions(styleInstructions: variant.presetInstructions),
                            prompt: Prompts.userPrompt(original: request.inputText)
                        )
                        for try await delta in stream {
                            if Task.isCancelled { break }
                            aggregated += delta
                            continuation.yield(.delta(presetID: variant.presetID, text: delta))
                        }
                        if Task.isCancelled { break }
                        continuation.yield(.completed(presetID: variant.presetID, fullText: aggregated))
                    } catch {
                        continuation.yield(.failed(presetID: variant.presetID, error: errorMapper(error)))
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
