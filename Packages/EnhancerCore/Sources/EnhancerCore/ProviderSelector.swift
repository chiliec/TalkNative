import Foundation

/// Chooses the model backend. Apple-Intelligence devices — including ones where
/// it is merely off or downloading — always stay on-device; only hardware Apple
/// excludes gets the cloud gateway, and only when a key was built in.
public enum ProviderSelector {
    /// App Group defaults key set by the app's consent screen.
    public static let consentKey = "cloud.consentAccepted"

    public static func make(
        onDevice: any LanguageModelProvider,
        consentGiven: Bool,
        canReachNetwork: Bool,
        config: GatewayConfig?
    ) -> any LanguageModelProvider {
        guard onDevice.availability == .unavailable(.deviceNotEligible), let config else { return onDevice }
        let availability: LanguageModelAvailability =
            if !canReachNetwork {
                .unavailable(.fullAccessRequired)
            } else if !consentGiven {
                .unavailable(.cloudConsentRequired)
            } else {
                .available
            }
        return GatewayProvider(config: config, availability: availability)
    }
}
