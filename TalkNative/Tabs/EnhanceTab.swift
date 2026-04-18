import SwiftUI
import UIKit
import EnhancerCore
import EnhancerUI
import HistoryKit
import PresetKit

struct EnhanceSession: Identifiable {
    let id = UUID()
    let viewModel: EnhancementViewModel
}

struct EnhanceTab: View {
    @Environment(AppServices.self) private var services
    @State private var input: String = LaunchArguments.prefilledInput ?? ""
    @State private var session: EnhanceSession?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextEditorBox(text: $input, maxChars: 2000)
                    .accessibilityIdentifier("EnhanceInput")

                HStack(spacing: 6) {
                    ForEach(services.presetStore.activePresets) { p in
                        PresetChip(preset: p, isActive: true, onTap: {})
                            .allowsHitTesting(false)
                    }
                    Spacer()
                    Text("\(services.presetStore.activePresets.count) active")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Button(action: enhance) {
                    Label("Enhance", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canEnhance)
                .accessibilityIdentifier("EnhanceButton")

                Spacer()
            }
            .padding()
            .navigationTitle("TalkNative")
            .sheet(item: $session) { session in
                ResultSheet(
                    viewModel: session.viewModel,
                    presets: services.presetStore.activePresets,
                    onCopy: { UIPasteboard.general.string = $0 },
                    onDismiss: { self.session = nil }
                )
                .task { await recordOnCompletion(vm: session.viewModel) }
            }
        }
    }

    private var canEnhance: Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && input.count <= 2000
    }

    private func enhance() {
        let vm = EnhancementViewModel(enhancer: services.enhancer)
        session = EnhanceSession(viewModel: vm)
        Task {
            await vm.start(inputText: input, activePresets: services.presetStore.activePresets)
        }
    }

    private func recordOnCompletion(vm: EnhancementViewModel) async {
        await vm.waitForCompletion()
        let variants = vm.variantStates.compactMap { state -> SavedVariant? in
            guard case .completed = state.phase else { return nil }
            return SavedVariant(
                presetID: state.presetID,
                presetLabelSnapshot: state.presetLabel,
                outputText: state.text
            )
        }
        guard !variants.isEmpty else { return }
        try? services.historyStore.insert(
            inputText: vm.inputText,
            variants: variants,
            deviceModelName: UIDevice.current.model
        )
    }
}
