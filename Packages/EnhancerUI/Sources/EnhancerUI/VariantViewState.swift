import Foundation
import EnhancerCore

public struct VariantViewState: Identifiable, Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case waiting
        case streaming
        case completed
        case failed(EnhancerError)
    }

    public let presetID: UUID
    public let presetLabel: String
    public private(set) var text: String = ""
    public private(set) var phase: Phase = .waiting

    public var id: UUID { presetID }

    public init(presetID: UUID, presetLabel: String) {
        self.presetID = presetID
        self.presetLabel = presetLabel
    }

    public mutating func apply(_ chunk: VariantChunk) {
        switch chunk {
        case .started(let id) where id == presetID:
            phase = .streaming
        case .delta(let id, let text) where id == presetID:
            self.text += text
        case .completed(let id, let fullText) where id == presetID:
            self.text = fullText
            phase = .completed
        case .failed(let id, let error) where id == presetID:
            phase = .failed(error)
        default:
            break
        }
    }
}
