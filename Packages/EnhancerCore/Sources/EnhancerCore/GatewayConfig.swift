import Foundation

/// Where the cloud tier sends requests. Read from Info.plist keys that the
/// build fills in from `Config/Secrets.xcconfig`; nil when no key was built in,
/// which keeps the app on-device only.
public struct GatewayConfig: Sendable, Equatable {
    public static let defaultModel = "claude-haiku-4-5"

    public let baseURL: URL
    public let apiKey: String
    public let model: String

    public init(baseURL: URL, apiKey: String, model: String = GatewayConfig.defaultModel) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
    }

    public static func fromBundle(_ bundle: Bundle = .main) -> GatewayConfig? {
        GatewayConfig(info: bundle.infoDictionary ?? [:])
    }

    init?(info: [String: Any]) {
        guard let key = Self.value(info["TNGatewayKey"]),
            let raw = Self.value(info["TNGatewayURL"]),
            let url = URL(string: raw), url.scheme == "https"
        else { return nil }
        self.init(baseURL: url, apiKey: key, model: Self.value(info["TNGatewayModel"]) ?? Self.defaultModel)
    }

    /// Empty or unexpanded (`$(VAR)`) build settings count as absent.
    private static func value(_ raw: Any?) -> String? {
        guard let s = (raw as? String)?.trimmingCharacters(in: .whitespaces), !s.isEmpty, !s.hasPrefix("$(")
        else { return nil }
        return s
    }
}
