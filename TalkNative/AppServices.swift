import Foundation
import SwiftData
import Observation
import EnhancerCore
import PresetKit
import HistoryKit

@Observable
@MainActor
final class AppServices {
    typealias ProviderResolver = @MainActor (_ consentGiven: Bool) -> any LanguageModelProvider

    let presetStore: PresetStore
    let historyStore: HistoryStore
    private(set) var enhancer: Enhancer
    private(set) var provider: any LanguageModelProvider
    /// True when this device uses the cloud gateway; Settings shows the consent toggle only then.
    let isCloudTier: Bool
    var cloudConsent: Bool {
        didSet {
            defaults.set(cloudConsent, forKey: ProviderSelector.consentKey)
            refreshProvider()
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let resolveProvider: ProviderResolver?

    init(
        presetStore: PresetStore,
        historyStore: HistoryStore,
        enhancer: Enhancer,
        provider: any LanguageModelProvider,
        defaults: UserDefaults = .standard,
        isCloudTier: Bool = false,
        resolveProvider: ProviderResolver? = nil
    ) {
        self.presetStore = presetStore
        self.historyStore = historyStore
        self.enhancer = enhancer
        self.provider = provider
        self.defaults = defaults
        self.isCloudTier = isCloudTier
        self.cloudConsent = defaults.bool(forKey: ProviderSelector.consentKey)
        self.resolveProvider = resolveProvider
    }

    /// Re-picks the backend — after consent changes, and on foregrounding in
    /// case Apple Intelligence state changed while backgrounded.
    func refreshProvider() {
        guard let resolveProvider else { return }
        provider = resolveProvider(cloudConsent)
        enhancer = Enhancer(provider: provider)
    }

    private static func make(
        presetStore: PresetStore, historyStore: HistoryStore, defaults: UserDefaults, isCloudTier: Bool,
        resolveProvider: @escaping ProviderResolver
    ) -> AppServices {
        let provider = resolveProvider(defaults.bool(forKey: ProviderSelector.consentKey))
        return AppServices(
            presetStore: presetStore, historyStore: historyStore, enhancer: Enhancer(provider: provider),
            provider: provider, defaults: defaults, isCloudTier: isCloudTier, resolveProvider: resolveProvider)
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

        let config = GatewayConfig.fromBundle()
        let resolve: ProviderResolver = { consent in
            ProviderSelector.make(
                onDevice: FoundationModelsProvider(), consentGiven: consent, canReachNetwork: true, config: config)
        }
        let isCloudTier =
            config != nil && FoundationModelsProvider().availability == .unavailable(.deviceNotEligible)
        return make(
            presetStore: presetStore, historyStore: historyStore, defaults: defaults, isCloudTier: isCloudTier,
            resolveProvider: resolve)
    }
}

extension AppServices {
    static func makeStubbed() -> AppServices {
        let defaults = UserDefaults(suiteName: "ui-test.\(UUID().uuidString)")!
        let presetStore = PresetStore(defaults: defaults)
        presetStore.seedIfNeeded()
        let container = (try? HistorySchema.makeContainer(appGroupURL: nil))!
        let historyStore = HistoryStore(container: container)
        let ineligible = LaunchArguments.simulateIneligibleDevice
        // Mirrors ProviderSelector's consent rows without a real GatewayProvider,
        // so UI tests never touch the network.
        let resolve: ProviderResolver = { consent in
            StubLanguageModelProvider(
                availability: ineligible && !consent ? .unavailable(.cloudConsentRequired) : .available,
                scriptedChunks: ["Hi ", "there"])
        }
        return make(
            presetStore: presetStore, historyStore: historyStore, defaults: defaults, isCloudTier: ineligible,
            resolveProvider: resolve)
    }
}
