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

    private func makeServices(
        scriptedChunks: [String] = ["Hi ", "there"]
    ) throws -> (AppServices, EnhancementViewModel) {
        let provider = StubLanguageModelProvider(scriptedChunks: scriptedChunks)
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let presets = PresetStore(defaults: defaults)
        presets.seedIfNeeded()
        let container = try HistorySchema.makeContainer(appGroupURL: nil)
        let history = HistoryStore(container: container)
        let enhancer = Enhancer(provider: provider)
        let services = AppServices(
            presetStore: presets,
            historyStore: history,
            enhancer: enhancer,
            provider: provider
        )
        let vm = EnhancementViewModel(enhancer: enhancer)
        return (services, vm)
    }

    @Test func stubbedFlowProducesThreeVariants() async throws {
        let (services, vm) = try makeServices()

        await vm.start(inputText: "hey", activePresets: services.presetStore.activePresets)
        await vm.waitForCompletion()

        #expect(vm.variantStates.count == 3)
        #expect(vm.variantStates.allSatisfy { $0.phase == .completed })
        #expect(vm.variantStates.allSatisfy { $0.text == "Hi there" })
    }

    @Test func completionCanBePersistedToHistory() async throws {
        let (services, vm) = try makeServices()

        await vm.start(inputText: "see you later", activePresets: services.presetStore.activePresets)
        await vm.waitForCompletion()

        let savedVariants: [SavedVariant] = vm.variantStates.compactMap { state in
            guard case .completed = state.phase else { return nil }
            return SavedVariant(
                presetID: state.presetID,
                presetLabelSnapshot: state.presetLabel,
                outputText: state.text
            )
        }
        try services.historyStore.insert(
            inputText: vm.inputText,
            variants: savedVariants,
            deviceModelName: "iPhone simulator"
        )

        let all = services.historyStore.allMostRecentFirst()
        #expect(all.count == 1)
        #expect(all.first?.inputText == "see you later")
        #expect(all.first?.variants.count == 3)
    }

    @Test func startIsIdempotentForSameInput() async throws {
        let (services, vm) = try makeServices()
        await vm.start(inputText: "one", activePresets: services.presetStore.activePresets)
        await vm.waitForCompletion()
        #expect(vm.variantStates.count == 3)

        await vm.start(inputText: "two", activePresets: services.presetStore.activePresets)
        await vm.waitForCompletion()
        #expect(vm.variantStates.count == 3)
        #expect(vm.inputText == "two")
    }

    @Test func cancelStopsRunningEnhancement() async throws {
        let (services, vm) = try makeServices(scriptedChunks: ["Slow "])
        await vm.start(inputText: "hi", activePresets: services.presetStore.activePresets)
        vm.cancel()
        await vm.waitForCompletion()
        #expect(vm.isRunning == false)
    }

    @Test func regenerateReplacesOnlyTargetVariant() async throws {
        let (services, vm) = try makeServices()
        let presets = services.presetStore.activePresets
        await vm.start(inputText: "meeting", activePresets: presets)
        await vm.waitForCompletion()

        let targetID = presets[0].id
        await vm.regenerate(presetID: targetID, activePresets: presets)

        #expect(vm.variantStates.count == 3)
        #expect(vm.variantStates.allSatisfy { $0.text == "Hi there" })
    }
}
