import SwiftUI
import PresetKit

public struct PresetPicker: View {
    @Bindable public var store: PresetStore

    public init(store: PresetStore) { self.store = store }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick 3 active presets").font(.subheadline).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                ForEach(store.allPresets) { preset in
                    PresetChip(
                        preset: preset,
                        isActive: store.activePresets.contains(where: { $0.id == preset.id })
                    ) {
                        toggle(preset)
                    }
                }
            }
        }
    }

    private func toggle(_ preset: Preset) {
        var ids = store.activePresets.map(\.id)
        if let idx = ids.firstIndex(of: preset.id) {
            ids.remove(at: idx)
            if let replacement = store.allPresets.first(where: { !ids.contains($0.id) && $0.id != preset.id }) {
                ids.append(replacement.id)
            }
        } else if ids.count < 3 {
            ids.append(preset.id)
        } else {
            ids.removeLast()
            ids.append(preset.id)
        }
        try? store.setActive(presetIDs: ids)
    }
}
