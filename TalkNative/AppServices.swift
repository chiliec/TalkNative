import Foundation
import SwiftData
import Observation
import EnhancerCore
import PresetKit
import HistoryKit

@Observable
@MainActor
final class AppServices {
    let presetStore: PresetStore
    let historyStore: HistoryStore
    let enhancer: Enhancer
    let provider: any LanguageModelProvider

    init(presetStore: PresetStore, historyStore: HistoryStore, enhancer: Enhancer, provider: any LanguageModelProvider) {
        self.presetStore = presetStore
        self.historyStore = historyStore
        self.enhancer = enhancer
        self.provider = provider
    }

    static func makeProduction() -> AppServices {
        let defaults = AppGroup.sharedDefaults
        let presetStore = PresetStore(defaults: defaults)
        presetStore.seedIfNeeded()

        let container: ModelContainer
        do {
            container = try HistorySchema.makeContainer(appGroupURL: AppGroup.containerURL)
        } catch {
            fatalError("Failed to create history container: \(error)")
        }
        let historyStore = HistoryStore(container: container)

        let provider = FoundationModelsProvider()
        let enhancer = Enhancer(provider: provider)
        return AppServices(presetStore: presetStore, historyStore: historyStore, enhancer: enhancer, provider: provider)
    }
}

extension AppServices {
    static func makeStubbed() -> AppServices {
        let defaults = UserDefaults(suiteName: "ui-test.\(UUID().uuidString)")!
        let presetStore = PresetStore(defaults: defaults)
        presetStore.seedIfNeeded()
        let container = (try? HistorySchema.makeContainer(appGroupURL: nil))!
        let historyStore = HistoryStore(container: container)
        let provider = StubLanguageModelProvider(scriptedChunks: ["Hi ", "there"])
        let enhancer = Enhancer(provider: provider)
        return AppServices(presetStore: presetStore, historyStore: historyStore, enhancer: enhancer, provider: provider)
    }
}
