import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("TalkNative").font(.title2.bold())
                Text(
                    "An on-device text enhancer that helps non-native English speakers write messages that sound native — across casual and professional registers."
                )
                Text(
                    "On iPhones with Apple Intelligence, all processing runs on your device. No accounts, no network, no tracking."
                )
                Text(
                    "On other iPhones, you can turn on cloud mode: the text you enhance is sent to the TalkNative gateway, which uses Anthropic's Claude model. Still no accounts and no tracking."
                )
                Text("Version 1.0").foregroundStyle(.secondary).font(.footnote)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("About")
    }
}
