import Foundation
import SwiftData

public struct SavedVariant: Codable, Equatable, Hashable, Sendable {
    public let presetID: UUID
    public let presetLabelSnapshot: String
    public let outputText: String

    public init(presetID: UUID, presetLabelSnapshot: String, outputText: String) {
        self.presetID = presetID
        self.presetLabelSnapshot = presetLabelSnapshot
        self.outputText = outputText
    }
}

@Model
public final class RecentItem {
    @Attribute(.unique) public var id: UUID
    public var createdAt: Date
    public var inputText: String
    public var variantsData: Data  // JSON-encoded [SavedVariant]
    public var deviceModelName: String

    public init(
        id: UUID = UUID(), createdAt: Date = .now, inputText: String, variants: [SavedVariant], deviceModelName: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.inputText = inputText
        self.variantsData = (try? JSONEncoder().encode(variants)) ?? Data()
        self.deviceModelName = deviceModelName
    }

    public var variants: [SavedVariant] {
        get { (try? JSONDecoder().decode([SavedVariant].self, from: variantsData)) ?? [] }
        set { variantsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
}
