import Testing
import Foundation
import EnhancerCore
import PresetKit
@testable import EnhancerUI

@Suite("EnhancementViewModel")
@MainActor
struct EnhancementViewModelTests {
    private func presets() -> [Preset] { Array(BuiltInPresets.all.prefix(3)) }

    @Test func startPopulatesAllVariantStates() async {
        let provider = StubLanguageModelProvider(scriptedChunks: ["Hi"])
        let enhancer = Enhancer(provider: provider)
        let vm = EnhancementViewModel(enhancer: enhancer)
        await vm.start(inputText: "hey", activePresets: presets())
        #expect(vm.variantStates.count == 3)
    }

    @Test func variantStatesReachCompleted() async {
        let provider = StubLanguageModelProvider(scriptedChunks: ["Hi"])
        let enhancer = Enhancer(provider: provider)
        let vm = EnhancementViewModel(enhancer: enhancer)
        await vm.start(inputText: "hey", activePresets: presets())
        await vm.waitForCompletion()
        #expect(vm.variantStates.allSatisfy { $0.phase == .completed })
        #expect(vm.variantStates.allSatisfy { $0.text == "Hi" })
    }

    @Test func cancelStopsFurtherEvents() async {
        let provider = StubLanguageModelProvider(
            scriptedChunks: Array(repeating: "x", count: 50),
            chunkDelay: .milliseconds(20)
        )
        let enhancer = Enhancer(provider: provider)
        let vm = EnhancementViewModel(enhancer: enhancer)
        await vm.start(inputText: "hey", activePresets: presets())
        try? await Task.sleep(for: .milliseconds(40))
        vm.cancel()
        await vm.waitForCompletion()
        #expect(
            vm.variantStates.contains(where: { $0.phase == .streaming || $0.phase == .waiting }) == false
                || vm.variantStates.count == 3)
    }
}
