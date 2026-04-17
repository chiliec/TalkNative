import Testing
@testable import PresetKit

@Suite("BuiltInPresets")
struct BuiltInPresetsTests {
    @Test func containsExactlyEight() {
        #expect(BuiltInPresets.all.count == 8)
    }

    @Test func labelsMatchSpec() {
        let expected = ["Casual", "Neutral", "Formal", "Friendly", "Direct", "Professional", "Warm", "Confident"]
        let labels = BuiltInPresets.all.map(\.label)
        #expect(labels == expected)
    }

    @Test func allAreBuiltIn() {
        #expect(BuiltInPresets.all.allSatisfy { $0.isBuiltIn })
    }

    @Test func allHaveNonEmptyInstructions() {
        #expect(BuiltInPresets.all.allSatisfy { !$0.instructions.isEmpty })
    }

    @Test func sortOrdersAreUniqueAscending() {
        let orders = BuiltInPresets.all.map(\.sortOrder)
        #expect(orders == orders.sorted())
        #expect(Set(orders).count == orders.count)
    }

    @Test func defaultActiveSet() {
        let defaults = BuiltInPresets.defaultActive
        #expect(defaults.count == 3)
        let labels = defaults.map(\.label)
        #expect(labels == ["Casual", "Professional", "Warm"])
    }
}
