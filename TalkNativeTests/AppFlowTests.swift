import Testing
import SwiftUI
@testable import TalkNative
import EnhancerCore
import PresetKit
import HistoryKit
import EnhancerUI

@Suite("App flow")
@MainActor
struct AppFlowTests {
    @Test func stubbedFlowProducesThreeVariants() async throws {
        let provider = StubLanguageModelProvider(scriptedChunks: ["Hi ", "there"])
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let presets = PresetStore(defaults: defaults)
        presets.seedIfNeeded()
        let container = try HistorySchema.makeContainer(appGroupURL: nil)
        let history = HistoryStore(container: container)
        let enhancer = Enhancer(provider: provider)
        _ = AppServices(presetStore: presets, historyStore: history, enhancer: enhancer, provider: provider)

        let vm = EnhancementViewModel(enhancer: enhancer)
        await vm.start(inputText: "hey", activePresets: presets.activePresets)
        await vm.waitForCompletion()

        #expect(vm.variantStates.count == 3)
        #expect(vm.variantStates.allSatisfy { $0.phase == .completed })
        #expect(vm.variantStates.allSatisfy { $0.text == "Hi there" })
    }
}
