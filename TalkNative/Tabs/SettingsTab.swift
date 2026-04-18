import SwiftUI
import PresetKit

struct SettingsTab: View {
    @Environment(AppServices.self) private var services
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            List {
                Section("Presets") {
                    NavigationLink("Active presets") { ActivePresetsView() }
                    NavigationLink("Custom presets") { CustomPresetsListView() }
                }
                Section("History") {
                    Button("Clear history", role: .destructive) { confirmClear = true }
                        .disabled(services.historyStore.allMostRecentFirst().isEmpty)
                }
                Section("About") {
                    NavigationLink("About TalkNative") { AboutView() }
                    NavigationLink("Privacy") { PrivacyView() }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Delete all enhancement history?",
                                isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear history", role: .destructive) {
                    try? services.historyStore.clear()
                }
            }
        }
    }
}

private struct CustomPresetsListView: View {
    @Environment(AppServices.self) private var services
    @State private var editing: Preset?
    @State private var showEditor: Bool = false

    var body: some View {
        List {
            Section("Custom") {
                ForEach(services.presetStore.allPresets.filter { !$0.isBuiltIn }) { p in
                    Button { editing = p; showEditor = true } label: { Text(p.label) }
                }
                .onDelete { offsets in
                    let customs = services.presetStore.allPresets.filter { !$0.isBuiltIn }
                    for i in offsets {
                        try? services.presetStore.deleteCustom(id: customs[i].id)
                    }
                }
                Button {
                    editing = nil; showEditor = true
                } label: {
                    Label("New custom preset", systemImage: "plus")
                }
                .disabled(services.presetStore.allPresets.filter { !$0.isBuiltIn }.count >= 20)
            }
        }
        .navigationTitle("Custom presets")
        .sheet(isPresented: $showEditor) {
            CustomPresetEditor(editing: editing, onDismiss: { showEditor = false })
        }
    }
}
