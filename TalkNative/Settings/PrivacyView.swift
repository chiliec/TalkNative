import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy").font(.title2.bold())
                Text("All text you enhance is processed on your device. TalkNative has no network layer.")
                Text("Recent items and presets are stored on your device only, never synced, never uploaded.")
                Text("You can clear history at any time from Settings → History.")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Privacy")
    }
}
