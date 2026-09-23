import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy").font(.title2.bold())
                Text("On iPhones with Apple Intelligence, all text you enhance is processed on your device.")
                Text(
                    "On other iPhones, cloud mode sends only the text you enhance, over HTTPS, to the TalkNative gateway, which forwards it to Anthropic's Claude model to write the rewrites. It's off until you allow it, and you can turn it off in Settings."
                )
                Text("Recent items and presets are stored on your device only, never synced, never uploaded.")
                Text("You can clear history at any time from Settings → History.")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Privacy")
    }
}
