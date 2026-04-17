import Foundation

public struct Preset: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var label: String
    public var instructions: String
    public var isBuiltIn: Bool
    public var sortOrder: Int

    public init(id: UUID = UUID(), label: String, instructions: String, isBuiltIn: Bool, sortOrder: Int) {
        self.id = id
        self.label = label
        self.instructions = instructions
        self.isBuiltIn = isBuiltIn
        self.sortOrder = sortOrder
    }
}

public struct PresetSelection: Codable, Equatable, Sendable {
    public var activePresetIDs: [UUID]

    public init(activePresetIDs: [UUID]) {
        self.activePresetIDs = activePresetIDs
    }
}
