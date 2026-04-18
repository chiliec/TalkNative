import SwiftUI
import PresetKit
import EnhancerUI

struct ActivePresetsView: View {
    @Environment(AppServices.self) private var services

    var body: some View {
        ScrollView {
            PresetPicker(store: services.presetStore).padding()
        }
        .navigationTitle("Active presets")
    }
}
