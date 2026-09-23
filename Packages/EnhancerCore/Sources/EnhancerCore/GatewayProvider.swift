import Foundation

/// Streams rewrites from the TalkNative gateway, which speaks Anthropic's
/// `/v1/messages` format, on devices without Apple Intelligence.
///
/// The only file allowed to touch the network — `scripts/no-network-check.sh`
/// allowlists it by path.
public struct GatewayProvider: LanguageModelProvider {
    public let availability: LanguageModelAvailability
    private let config: GatewayConfig
    private let session: URLSession

    public init(config: GatewayConfig, availability: LanguageModelAvailability, session: URLSession = .shared) {
        self.config = config
        self.availability = availability
        self.session = session
    }

    public func stream(instructions: String, prompt: String) -> AsyncThrowingStream<String, Error> {
        let request = makeRequest(instructions: instructions, prompt: prompt)
        let session = session
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    guard (200..<300).contains(status) else {
                        var body = ""
                        for try await line in bytes.lines { body += line }
                        throw Self.httpError(status: status, body: body)
                    }
                    // `lines` drops blank lines, so SSE frame boundaries are
                    // invisible here; each Anthropic `data:` payload carries its
                    // own `type`, which is all the parser needs.
                    for try await line in bytes.lines {
                        switch Self.step(forLine: line) {
                        case .text(let text): continuation.yield(text)
                        case .stop:
                            continuation.finish()
                            return
                        case .fail(let error): throw error
                        case .ignore: continue
                        }
                    }
                    throw EnhancerError.unknown("Connection interrupted")
                } catch {
                    continuation.finish(throwing: Self.mapped(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func makeRequest(instructions: String, prompt: String) -> URLRequest {
        var request = URLRequest(url: config.baseURL.appending(path: "v1/messages"), timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        let body = RequestBody(
            model: config.model, system: instructions, messages: [.init(role: "user", content: prompt)])
        request.httpBody = try? JSONEncoder().encode(body)
        return request
    }

    // MARK: - Parsing

    enum Step: Equatable {
        case text(String)
        case stop
        case fail(EnhancerError)
        case ignore
    }

    static func step(forLine line: String) -> Step {
        guard line.hasPrefix("data:") else { return .ignore }
        let json = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
        guard let event = try? JSONDecoder().decode(Event.self, from: Data(json.utf8)) else {
            return .fail(.unknown("Parse error"))
        }
        switch event.type {
        case "content_block_delta":
            guard event.delta?.type == "text_delta", let text = event.delta?.text else { return .ignore }
            return .text(text)
        case "message_delta":
            return event.delta?.stopReason == "refusal" ? .fail(.guardrailViolation) : .ignore
        case "message_stop":
            return .stop
        case "error":
            return .fail(apiError(type: event.error?.type ?? "", message: event.error?.message ?? ""))
        default:
            return .ignore
        }
    }

    // MARK: - Error mapping

    static func httpError(status: Int, body: String) -> EnhancerError {
        switch status {
        case 401, 403: return .unknown("Gateway auth failed")
        case 402, 429, 529: return .rateLimited
        case 413: return .exceededContextWindow
        case 400:
            let lowered = body.lowercased()
            if lowered.contains("token") || lowered.contains("context") { return .exceededContextWindow }
            return .unknown("HTTP 400")
        default: return .unknown("HTTP \(status)")
        }
    }

    private static func apiError(type: String, message: String) -> EnhancerError {
        switch type {
        case "rate_limit_error", "overloaded_error": return .rateLimited
        case "request_too_large": return .exceededContextWindow
        default: return .unknown(type.isEmpty ? message : type)
        }
    }

    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost,
        .timedOut, .dataNotAllowed, .secureConnectionFailed,
    ]

    private static func mapped(_ error: Error) -> Error {
        if error is EnhancerError { return error }
        if error is CancellationError { return EnhancerError.cancelled }
        if let urlError = error as? URLError {
            if urlError.code == .cancelled { return EnhancerError.cancelled }
            if offlineCodes.contains(urlError.code) { return EnhancerError.offline }
        }
        return EnhancerError.unknown(error)
    }

    // MARK: - Wire types

    private struct RequestBody: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }
        let model: String
        let stream = true
        let maxTokens = 1024
        let system: String
        let messages: [Message]

        enum CodingKeys: String, CodingKey {
            case model, stream, system, messages
            case maxTokens = "max_tokens"
        }
    }

    private struct Event: Decodable {
        struct Delta: Decodable {
            let type: String?
            let text: String?
            let stopReason: String?

            enum CodingKeys: String, CodingKey {
                case type, text
                case stopReason = "stop_reason"
            }
        }
        struct APIError: Decodable {
            let type: String
            let message: String?
        }
        let type: String
        let delta: Delta?
        let error: APIError?
    }
}
