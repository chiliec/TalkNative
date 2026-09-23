import Foundation
import Testing
@testable import EnhancerCore

@Suite("ProviderSelector")
struct ProviderSelectorTests {
    private let config = GatewayConfig(baseURL: URL(string: "https://gw.example.com")!, apiKey: "k")

    private func onDevice(_ availability: LanguageModelAvailability) -> StubLanguageModelProvider {
        StubLanguageModelProvider(availability: availability, scriptedChunks: [])
    }

    @Test(arguments: [
        LanguageModelAvailability.available,
        .unavailable(.appleIntelligenceNotEnabled),
        .unavailable(.modelNotReady),
    ])
    func eligibleDevicesStayOnDevice(_ availability: LanguageModelAvailability) {
        let provider = ProviderSelector.make(
            onDevice: onDevice(availability), consentGiven: true, canReachNetwork: true, config: config)
        #expect(provider is StubLanguageModelProvider)
    }

    @Test func ineligibleWithoutBuiltInKeyStaysOnDevice() {
        let provider = ProviderSelector.make(
            onDevice: onDevice(.unavailable(.deviceNotEligible)), consentGiven: true, canReachNetwork: true,
            config: nil)
        #expect(provider is StubLanguageModelProvider)
        #expect(provider.availability == .unavailable(.deviceNotEligible))
    }

    @Test func ineligibleKeyboardWithoutFullAccessNeedsIt() {
        let provider = ProviderSelector.make(
            onDevice: onDevice(.unavailable(.deviceNotEligible)), consentGiven: true, canReachNetwork: false,
            config: config)
        #expect(provider is GatewayProvider)
        #expect(provider.availability == .unavailable(.fullAccessRequired))
    }

    @Test func ineligibleWithoutConsentAsksForIt() {
        let provider = ProviderSelector.make(
            onDevice: onDevice(.unavailable(.deviceNotEligible)), consentGiven: false, canReachNetwork: true,
            config: config)
        #expect(provider is GatewayProvider)
        #expect(provider.availability == .unavailable(.cloudConsentRequired))
    }

    @Test func ineligibleWithConsentIsAvailable() {
        let provider = ProviderSelector.make(
            onDevice: onDevice(.unavailable(.deviceNotEligible)), consentGiven: true, canReachNetwork: true,
            config: config)
        #expect(provider is GatewayProvider)
        #expect(provider.availability == .available)
    }
}
