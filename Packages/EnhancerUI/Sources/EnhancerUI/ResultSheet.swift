import SwiftUI
import EnhancerCore
import PresetKit

public struct ResultSheet: View {
    @Bindable public var viewModel: EnhancementViewModel
    public let presets: [Preset]
    public let variantAction: VariantCard.ActionKind
    public let onCopy: (String) -> Void
    public let onDismiss: () -> Void

    public init(
        viewModel: EnhancementViewModel,
        presets: [Preset],
        variantAction: VariantCard.ActionKind = .copy,
        onCopy: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.presets = presets
        self.variantAction = variantAction
        self.onCopy = onCopy
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("YOUR TEXT").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(viewModel.inputText).padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))

                    ForEach(viewModel.variantStates) { state in
                        VariantCard(
                            state: state,
                            actionKind: variantAction,
                            onPrimary: { onCopy(state.text) },
                            onRegenerate: {
                                Task { await viewModel.regenerate(presetID: state.presetID, activePresets: presets) }
                            }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Enhanced")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { viewModel.cancel(); onDismiss() }
                }
            }
        }
    }
}
