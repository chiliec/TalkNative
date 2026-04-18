import Foundation

public struct StubLanguageModelProvider: LanguageModelProvider {
    public var availability: LanguageModelAvailability
    public var scriptedChunks: [String]
    public var scriptedError: Error?
    public var chunkDelay: Duration

    public init(
        availability: LanguageModelAvailability = .available,
        scriptedChunks: [String],
        scriptedError: Error? = nil,
        chunkDelay: Duration = .milliseconds(0)
    ) {
        self.availability = availability
        self.scriptedChunks = scriptedChunks
        self.scriptedError = scriptedError
        self.chunkDelay = chunkDelay
    }

    public func stream(
        instructions: String,
        prompt: String
    ) -> AsyncThrowingStream<String, Error> {
        let chunks = scriptedChunks
        let error = scriptedError
        let delay = chunkDelay
        return AsyncThrowingStream { continuation in
            let task = Task {
                for chunk in chunks {
                    if Task.isCancelled { break }
                    if delay > .zero { try? await Task.sleep(for: delay) }
                    continuation.yield(chunk)
                }
                if let error { continuation.finish(throwing: error) } else { continuation.finish() }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
