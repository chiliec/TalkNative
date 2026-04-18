import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("TalkNative").font(.title2.bold())
                Text("An on-device text enhancer that helps non-native English speakers write messages that sound native — across casual and professional registers.")
                Text("All processing runs on your device using Apple Intelligence. No accounts, no network, no tracking.")
                Text("Version 1.0").foregroundStyle(.secondary).font(.footnote)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("About")
    }
}
