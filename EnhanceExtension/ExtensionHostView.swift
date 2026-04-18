import SwiftUI
import UIKit
import EnhancerCore
import PresetKit
import HistoryKit
import EnhancerUI

enum ExtensionMode { case share, action }

struct ExtensionHostView: View {
    let initialText: String
    let mode: ExtensionMode
    let onCopyAndDismiss: (String) -> Void
    let onUseAndReturn: (String) -> Void
    let onDismiss: () -> Void

    @State private var services: ExtensionServices = .make()
    @State private var viewModel: EnhancementViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                ResultSheet(
                    viewModel: vm,
                    presets: services.presets.activePresets,
                    variantAction: mode == .action ? .useThis : .copy,
                    onCopy: { text in
                        switch mode {
                        case .share: onCopyAndDismiss(text)
                        case .action: onUseAndReturn(text)
                        }
                    },
                    onDismiss: onDismiss
                )
                .task { await recordOnCompletion(vm: vm) }
            } else {
                ProgressView().task { await begin() }
            }
        }
    }

    private func begin() async {
        switch services.provider.availability {
        case .available:
            let vm = EnhancementViewModel(enhancer: services.enhancer)
            viewModel = vm
            await vm.start(inputText: initialText, activePresets: services.presets.activePresets)
        case .unavailable:
            onDismiss()
        }
    }

    private func recordOnCompletion(vm: EnhancementViewModel) async {
        await vm.waitForCompletion()
        let variants = vm.variantStates.compactMap { s -> SavedVariant? in
            guard case .completed = s.phase else { return nil }
            return SavedVariant(presetID: s.presetID, presetLabelSnapshot: s.presetLabel, outputText: s.text)
        }
        guard !variants.isEmpty else { return }
        try? services.history.insert(
            inputText: vm.inputText,
            variants: variants,
            deviceModelName: UIDevice.current.model
        )
    }
}

@MainActor
struct ExtensionServices {
    let presets: PresetStore
    let history: HistoryStore
    let enhancer: Enhancer
    let provider: any LanguageModelProvider

    static func make() -> ExtensionServices {
        let appGroupID = "group.com.axveer.talknative"
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        let presets = PresetStore(defaults: defaults)
        presets.seedIfNeeded()

        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        let container = (try? HistorySchema.makeContainer(appGroupURL: containerURL))
            ?? (try! HistorySchema.makeContainer(appGroupURL: nil))
        let history = HistoryStore(container: container)

        let provider = FoundationModelsProvider()
        return ExtensionServices(
            presets: presets,
            history: history,
            enhancer: Enhancer(provider: provider),
            provider: provider
        )
    }
}
