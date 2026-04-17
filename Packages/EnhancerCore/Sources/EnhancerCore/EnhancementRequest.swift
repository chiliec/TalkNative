import Foundation

public struct VariantRequest: Sendable, Equatable {
    public let presetID: UUID
    public let presetLabel: String
    public let presetInstructions: String

    public init(presetID: UUID, presetLabel: String, presetInstructions: String) {
        self.presetID = presetID
        self.presetLabel = presetLabel
        self.presetInstructions = presetInstructions
    }
}

public struct EnhancementRequest: Sendable, Equatable {
    public let inputText: String
    public let variants: [VariantRequest]

    public init(inputText: String, variants: [VariantRequest]) {
        self.inputText = inputText
        self.variants = variants
    }
}

public enum VariantChunk: Sendable, Equatable {
    case started(presetID: UUID)
    case delta(presetID: UUID, text: String)
    case completed(presetID: UUID, fullText: String)
    case failed(presetID: UUID, error: EnhancerError)
}
