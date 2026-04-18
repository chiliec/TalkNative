import Foundation
import Observation

@Observable
@MainActor
public final class PresetStore {
    public enum Error: Swift.Error, Equatable {
        case cannotDeleteBuiltIn
        case notFound
    }

    private enum Keys {
        static let presets = "presets.v1"
        static let selection = "presets.selection.v1"
        static let seeded = "presets.seeded.v1"
    }

    private let defaults: UserDefaults
    public private(set) var allPresets: [Preset] = []
    public private(set) var activePresets: [Preset] = []

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    public func seedIfNeeded() {
        if defaults.bool(forKey: Keys.seeded) {
            load()
            return
        }
        allPresets = BuiltInPresets.all
        let defaultActiveIDs = BuiltInPresets.defaultActive.map(\.id)
        persist(presets: allPresets, activeIDs: defaultActiveIDs)
        defaults.set(true, forKey: Keys.seeded)
        load()
    }

    @discardableResult
    public func addCustom(label: String, instructions: String) throws -> Preset {
        try PresetValidation.validate(label: label, instructions: instructions)
        let customCount = allPresets.filter { !$0.isBuiltIn }.count
        if customCount >= PresetValidation.customPresetCap {
            throw PresetValidation.Error.customPresetCapReached
        }
        let sortOrder = (allPresets.map(\.sortOrder).max() ?? 0) + 1
        let new = Preset(label: label, instructions: instructions, isBuiltIn: false, sortOrder: sortOrder)
        var updated = allPresets
        updated.append(new)
        persist(presets: updated, activeIDs: activePresets.map(\.id))
        load()
        return new
    }

    public func updateCustom(id: UUID, label: String, instructions: String) throws {
        try PresetValidation.validate(label: label, instructions: instructions)
        guard let idx = allPresets.firstIndex(where: { $0.id == id }) else { throw Error.notFound }
        if allPresets[idx].isBuiltIn { throw Error.cannotDeleteBuiltIn }
        var updated = allPresets
        updated[idx].label = label
        updated[idx].instructions = instructions
        persist(presets: updated, activeIDs: activePresets.map(\.id))
        load()
    }

    public func deleteCustom(id: UUID) throws {
        guard let existing = allPresets.first(where: { $0.id == id }) else { throw Error.notFound }
        if existing.isBuiltIn { throw Error.cannotDeleteBuiltIn }
        var updated = allPresets
        updated.removeAll { $0.id == id }
        var active = activePresets.map(\.id)
        active.removeAll { $0 == id }
        if active.count < PresetValidation.activeSelectionSize {
            for p in BuiltInPresets.all where !active.contains(p.id) {
                active.append(p.id)
                if active.count == PresetValidation.activeSelectionSize { break }
            }
        }
        persist(presets: updated, activeIDs: active)
        load()
    }

    public func setActive(presetIDs: [UUID]) throws {
        try PresetValidation.validateActiveSelection(count: presetIDs.count)
        let knownIDs = Set(allPresets.map(\.id))
        guard presetIDs.allSatisfy({ knownIDs.contains($0) }) else { throw Error.notFound }
        persist(presets: allPresets, activeIDs: presetIDs)
        load()
    }

    private func load() {
        let decoder = JSONDecoder()
        if let data = defaults.data(forKey: Keys.presets),
            let decoded = try? decoder.decode([Preset].self, from: data)
        {
            allPresets = decoded.sorted(by: { $0.sortOrder < $1.sortOrder })
        } else {
            allPresets = []
        }
        if let selData = defaults.data(forKey: Keys.selection),
            let sel = try? decoder.decode(PresetSelection.self, from: selData)
        {
            activePresets = sel.activePresetIDs.compactMap { id in allPresets.first(where: { $0.id == id }) }
        } else {
            activePresets = []
        }
    }

    private func persist(presets: [Preset], activeIDs: [UUID]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(presets) { defaults.set(data, forKey: Keys.presets) }
        let selection = PresetSelection(activePresetIDs: activeIDs)
        if let data = try? encoder.encode(selection) { defaults.set(data, forKey: Keys.selection) }
    }
}
