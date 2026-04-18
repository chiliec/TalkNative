import Testing
import Foundation
import SwiftData
@testable import HistoryKit

@Suite("HistoryStore")
@MainActor
struct HistoryStoreTests {
    private func makeStore() throws -> HistoryStore {
        let container = try HistorySchema.makeContainer(appGroupURL: nil)
        return HistoryStore(container: container)
    }

    private func sampleVariants() -> [SavedVariant] {
        [
            SavedVariant(presetID: UUID(), presetLabelSnapshot: "A", outputText: "a"),
            SavedVariant(presetID: UUID(), presetLabelSnapshot: "B", outputText: "b"),
            SavedVariant(presetID: UUID(), presetLabelSnapshot: "C", outputText: "c"),
        ]
    }

    @Test func insertIncreasesCount() throws {
        let store = try makeStore()
        try store.insert(inputText: "hi", variants: sampleVariants(), deviceModelName: "test")
        #expect(store.allMostRecentFirst().count == 1)
    }

    @Test func ordersMostRecentFirst() throws {
        let store = try makeStore()
        try store.insert(inputText: "a", variants: sampleVariants(), deviceModelName: "test")
        try store.insert(inputText: "b", variants: sampleVariants(), deviceModelName: "test")
        try store.insert(inputText: "c", variants: sampleVariants(), deviceModelName: "test")
        let items = store.allMostRecentFirst()
        #expect(items.map(\.inputText) == ["c", "b", "a"])
    }

    @Test func evictsOldestAtFiftyCap() throws {
        let store = try makeStore()
        for i in 0..<55 {
            try store.insert(inputText: "t\(i)", variants: sampleVariants(), deviceModelName: "test")
        }
        let items = store.allMostRecentFirst()
        #expect(items.count == 50)
        #expect(items.first?.inputText == "t54")
        #expect(items.last?.inputText == "t5")
    }

    @Test func clearRemovesAll() throws {
        let store = try makeStore()
        try store.insert(inputText: "x", variants: sampleVariants(), deviceModelName: "test")
        try store.clear()
        #expect(store.allMostRecentFirst().isEmpty)
    }

    @Test func exactlyFiftyItemsNotEvicted() throws {
        let store = try makeStore()
        for i in 0..<50 {
            try store.insert(inputText: "t\(i)", variants: sampleVariants(), deviceModelName: "test")
        }
        let items = store.allMostRecentFirst()
        #expect(items.count == 50)
        #expect(items.first?.inputText == "t49")
        #expect(items.last?.inputText == "t0")
    }

    @Test func insertWithEmptyVariantsPersists() throws {
        let store = try makeStore()
        try store.insert(inputText: "no variants", variants: [], deviceModelName: "test")
        let items = store.allMostRecentFirst()
        #expect(items.count == 1)
        #expect(items.first?.variants.isEmpty == true)
    }

    @Test func deleteUnknownIDIsSilentNoOp() throws {
        let store = try makeStore()
        try store.insert(inputText: "x", variants: sampleVariants(), deviceModelName: "test")
        try store.delete(id: UUID())
        #expect(store.allMostRecentFirst().count == 1)
    }

    @Test func clearOnEmptyStoreIsNoOp() throws {
        let store = try makeStore()
        try store.clear()
        #expect(store.allMostRecentFirst().isEmpty)
    }

    @Test func deleteByIDRemovesOne() throws {
        let store = try makeStore()
        try store.insert(inputText: "a", variants: sampleVariants(), deviceModelName: "test")
        try store.insert(inputText: "b", variants: sampleVariants(), deviceModelName: "test")
        let first = store.allMostRecentFirst().first!
        try store.delete(id: first.id)
        #expect(store.allMostRecentFirst().count == 1)
    }
}
