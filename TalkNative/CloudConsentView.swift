import SwiftUI

/// Shown on iPhones without Apple Intelligence before any text leaves the
/// device. App Store guideline 5.1.2(i) requires explicit permission before
/// sending personal data to a third-party AI service.
struct CloudConsentView: View {
    @Environment(AppServices.self) private var services

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "icloud").font(.system(size: 56)).foregroundStyle(.secondary)
            Text("Use cloud mode?").font(.title2.bold())
            Text(
                "This iPhone doesn't support Apple Intelligence, so TalkNative can rewrite your text in the cloud instead. The text you enhance is sent over HTTPS to the TalkNative gateway, which uses Anthropic's Claude model to produce rewrites. Nothing else is sent, and nothing is stored in your account — there is no account."
            )
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            Button("Allow") { services.cloudConsent = true }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("cloud.consent.allow")
        }
        .padding(32)
    }
}
