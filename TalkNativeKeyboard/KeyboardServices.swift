import Foundation
import UIKit
import EnhancerCore
import PresetKit
import HistoryKit
import EnhancerUI

/// Mirrors `ExtensionServices` in `EnhanceExtension/ExtensionHostView.swift`,
/// but degrades when Full Access is off.
///
/// Without Full Access a keyboard extension cannot reach the App Group, so
/// custom presets and Recents are unavailable. The keyboard still works with
/// the eight built-in presets.
@MainActor
struct KeyboardServices {
    let presets: PresetStore
    let history: HistoryStore?
    let provider: any LanguageModelProvider

    static func make(hasFullAccess: Bool) -> KeyboardServices {
        let provider = FoundationModelsProvider()

        guard hasFullAccess else {
            let presets = PresetStore(defaults: .standard)
            presets.seedIfNeeded()
            return KeyboardServices(presets: presets, history: nil, provider: provider)
        }

        let appGroupID = "group.com.axveer.talknative"
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        let presets = PresetStore(defaults: defaults)
        presets.seedIfNeeded()

        let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        let history = (try? HistorySchema.makeContainer(appGroupURL: containerURL))
            .map(HistoryStore.init(container:))

        return KeyboardServices(presets: presets, history: history, provider: provider)
    }

    func makeEnhancementViewModel() -> EnhancementViewModel {
        EnhancementViewModel(enhancer: Enhancer(provider: provider))
    }

    /// Record a completed run. No-op without Full Access.
    func record(inputText: String, variants: [SavedVariant]) {
        guard let history, !variants.isEmpty else { return }
        try? history.insert(
            inputText: inputText,
            variants: variants,
            deviceModelName: UIDevice.current.model
        )
    }
}
