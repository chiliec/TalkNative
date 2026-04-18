import Testing
import Foundation
@testable import PresetKit

@Suite("PresetStore") @MainActor
struct PresetStoreTests {
    private func makeStore() -> (PresetStore, UserDefaults) {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (PresetStore(defaults: defaults), defaults)
    }

    @Test func firstLaunchSeedsBuiltInsAndDefaultActive() {
        let (store, _) = makeStore()
        store.seedIfNeeded()
        #expect(store.allPresets.count == 8)
        #expect(store.activePresets.map(\.label) == ["Casual", "Professional", "Warm"])
    }

    @Test func seedIsIdempotent() {
        let (store, _) = makeStore()
        store.seedIfNeeded()
        store.seedIfNeeded()
        #expect(store.allPresets.count == 8)
    }

    @Test func addCustomPresetPersists() throws {
        let (store, _) = makeStore()
        store.seedIfNeeded()
        let new = try store.addCustom(label: "Startup", instructions: "Casual, no buzzwords.")
        #expect(new.isBuiltIn == false)
        #expect(store.allPresets.contains(where: { $0.id == new.id }))
    }

    @Test func addCustomRespectsCap() {
        let (store, _) = makeStore()
        store.seedIfNeeded()
        for i in 0..<20 {
            _ = try? store.addCustom(label: "P\(i)", instructions: "x")
        }
        #expect(throws: PresetValidation.Error.customPresetCapReached) {
            _ = try store.addCustom(label: "Overflow", instructions: "x")
        }
    }

    @Test func deleteCustomRemoves() throws {
        let (store, _) = makeStore()
        store.seedIfNeeded()
        let p = try store.addCustom(label: "X", instructions: "y")
        try store.deleteCustom(id: p.id)
        #expect(!store.allPresets.contains(where: { $0.id == p.id }))
    }

    @Test func deleteBuiltInThrows() {
        let (store, _) = makeStore()
        store.seedIfNeeded()
        let builtIn = store.allPresets.first { $0.isBuiltIn }!
        #expect(throws: PresetStore.Error.cannotDeleteBuiltIn) {
            try store.deleteCustom(id: builtIn.id)
        }
    }

    @Test func setActiveRequiresExactlyThree() {
        let (store, _) = makeStore()
        store.seedIfNeeded()
        let ids = store.allPresets.prefix(2).map(\.id)
        #expect(throws: PresetValidation.Error.activeSelectionWrongSize) {
            try store.setActive(presetIDs: Array(ids))
        }
    }

    @Test func deletingActiveCustomRefillsFromBuiltIns() throws {
        let (store, _) = makeStore()
        store.seedIfNeeded()
        let custom = try store.addCustom(label: "Startup", instructions: "no buzzwords")
        let builtIns = store.allPresets.filter(\.isBuiltIn)
        try store.setActive(presetIDs: [builtIns[0].id, builtIns[1].id, custom.id])
        #expect(store.activePresets.contains { $0.id == custom.id })

        try store.deleteCustom(id: custom.id)

        #expect(store.activePresets.count == 3)
        #expect(store.activePresets.allSatisfy { $0.isBuiltIn })
        #expect(!store.activePresets.contains { $0.id == custom.id })
    }

    @Test func setActiveRejectsUnknownID() {
        let (store, _) = makeStore()
        store.seedIfNeeded()
        let known = Array(store.allPresets.prefix(2).map(\.id))
        #expect(throws: PresetStore.Error.notFound) {
            try store.setActive(presetIDs: known + [UUID()])
        }
    }

    @Test func updateCustomOnBuiltInRejected() {
        let (store, _) = makeStore()
        store.seedIfNeeded()
        let builtIn = store.allPresets.first(where: \.isBuiltIn)!
        #expect(throws: PresetStore.Error.cannotDeleteBuiltIn) {
            try store.updateCustom(id: builtIn.id, label: "Override", instructions: "x")
        }
    }

    @Test func labelAtMaxLengthAccepted() throws {
        let (store, _) = makeStore()
        store.seedIfNeeded()
        let maxLabel = String(repeating: "a", count: PresetValidation.labelMax)
        _ = try store.addCustom(label: maxLabel, instructions: "x")
        #expect(store.allPresets.contains { $0.label == maxLabel })
    }

    @Test func labelOverMaxLengthRejected() {
        let (store, _) = makeStore()
        store.seedIfNeeded()
        let tooLong = String(repeating: "a", count: PresetValidation.labelMax + 1)
        #expect(throws: PresetValidation.Error.labelTooLong) {
            _ = try store.addCustom(label: tooLong, instructions: "x")
        }
    }

    @Test func setActivePersists() throws {
        let (store, defaults) = makeStore()
        store.seedIfNeeded()
        let newIDs = Array(store.allPresets.prefix(3).map(\.id))
        try store.setActive(presetIDs: newIDs)
        let reloaded = PresetStore(defaults: defaults)
        reloaded.seedIfNeeded()
        #expect(reloaded.activePresets.map(\.id) == newIDs)
    }
}
