import Foundation
import Testing
@testable import EnhancerCore

@Suite("GatewayConfig")
struct GatewayConfigTests {
    @Test func readsAllKeys() {
        let config = GatewayConfig(info: [
            "TNGatewayURL": "https://gateway.example.com",
            "TNGatewayKey": "sk-axv-123",
            "TNGatewayModel": "claude-x",
        ])

        #expect(
            config
                == GatewayConfig(
                    baseURL: URL(string: "https://gateway.example.com")!,
                    apiKey: "sk-axv-123",
                    model: "claude-x"
                )
        )
    }

    @Test func modelDefaultsToHaiku() {
        let config = GatewayConfig(info: ["TNGatewayURL": "https://g.example.com", "TNGatewayKey": "k"])
        #expect(config?.model == "claude-haiku-4-5")
    }

    /// CI and fresh clones build without `Config/Secrets.xcconfig`: the key
    /// expands to "" and the app must fall back to on-device behaviour.
    @Test(arguments: [nil, "", "  ", "$(TN_GATEWAY_KEY)"])
    func missingKeyMeansNoConfig(_ key: String?) {
        var info: [String: Any] = ["TNGatewayURL": "https://g.example.com"]
        info["TNGatewayKey"] = key
        #expect(GatewayConfig(info: info) == nil)
    }

    @Test func rejectsNonHTTPSURL() {
        #expect(GatewayConfig(info: ["TNGatewayURL": "http://g.example.com", "TNGatewayKey": "k"]) == nil)
    }
}
