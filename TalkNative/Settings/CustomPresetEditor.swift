import SwiftUI
import PresetKit

struct CustomPresetEditor: View {
    let editing: Preset?
    let onDismiss: () -> Void
    @Environment(AppServices.self) private var services

    @State private var label: String = ""
    @State private var instructions: String = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Label") {
                    TextField("e.g. Startup casual", text: $label)
                }
                Section("Instructions") {
                    TextEditor(text: $instructions).frame(minHeight: 120)
                    Text("\(instructions.count) / 400").font(.caption).foregroundStyle(.secondary)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle(editing == nil ? "New preset" : "Edit preset")
            .onAppear {
                if let editing {
                    label = editing.label
                    instructions = editing.instructions
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onDismiss) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(label.isEmpty || instructions.isEmpty)
                }
            }
        }
    }

    private func save() {
        do {
            if let editing {
                try services.presetStore.updateCustom(id: editing.id, label: label, instructions: instructions)
            } else {
                _ = try services.presetStore.addCustom(label: label, instructions: instructions)
            }
            onDismiss()
        } catch let e as PresetValidation.Error {
            error = describe(e)
        } catch {
            self.error = "Could not save preset."
        }
    }

    private func describe(_ e: PresetValidation.Error) -> String {
        switch e {
        case .emptyLabel: return "Label cannot be empty."
        case .labelTooLong: return "Label is too long (max 24)."
        case .emptyInstructions: return "Instructions cannot be empty."
        case .instructionsTooLong: return "Instructions too long (max 400)."
        case .customPresetCapReached: return "You already have 20 custom presets — delete one first."
        case .activeSelectionWrongSize: return "Pick exactly 3 active presets."
        }
    }
}
