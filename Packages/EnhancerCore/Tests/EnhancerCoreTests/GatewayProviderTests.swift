import Foundation
import Testing
@testable import EnhancerCore

/// Serves one canned HTTP response per request. Static state, so the suite is serialized.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var response: (status: Int, body: String) = (200, "")
    nonisolated(unsafe) static var failure: URLError?
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var lastBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        Self.lastBody = request.httpBodyStream.map(Self.read)
        if let failure = Self.failure {
            client?.urlProtocol(self, didFailWithError: failure)
            return
        }
        let http = HTTPURLResponse(
            url: request.url!, statusCode: Self.response.status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.response.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func read(_ stream: InputStream) -> Data {
        var data = Data()
        stream.open()
        defer { stream.close() }
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let n = stream.read(&buffer, maxLength: buffer.count)
            if n <= 0 { break }
            data.append(buffer, count: n)
        }
        return data
    }
}

@Suite("GatewayProvider", .serialized)
struct GatewayProviderTests {
    private static let happySSE = """
        event: message_start
        data: {"type":"message_start","message":{"id":"m1"}}

        event: ping
        data: {"type":"ping"}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" world"}}

        event: message_delta
        data: {"type":"message_delta","delta":{"stop_reason":"end_turn"}}

        event: message_stop
        data: {"type":"message_stop"}


        """

    private func makeProvider(status: Int = 200, body: String = happySSE, failure: URLError? = nil)
        -> GatewayProvider
    {
        StubURLProtocol.response = (status, body)
        StubURLProtocol.failure = failure
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return GatewayProvider(
            config: GatewayConfig(baseURL: URL(string: "https://gw.example.com")!, apiKey: "sk-axv-test"),
            availability: .available,
            session: URLSession(configuration: configuration)
        )
    }

    private func run(_ provider: GatewayProvider) async -> (text: String, error: EnhancerError?) {
        var text = ""
        do {
            for try await delta in provider.stream(instructions: "SYS", prompt: "hey") { text += delta }
            return (text, nil)
        } catch {
            return (text, error as? EnhancerError)
        }
    }

    @Test func streamsTextDeltas() async {
        let result = await run(makeProvider())
        #expect(result.text == "Hello world")
        #expect(result.error == nil)
    }

    @Test func sendsAnthropicShapedRequest() async throws {
        _ = await run(makeProvider())
        let request = try #require(StubURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://gw.example.com/v1/messages")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "sk-axv-test")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(request.timeoutInterval == 60)
        let body = try #require(StubURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "claude-haiku-4-5")
        #expect(json["stream"] as? Bool == true)
        #expect(json["max_tokens"] as? Int == 1024)
        #expect(json["system"] as? String == "SYS")
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(messages == [["role": "user", "content": "hey"]])
    }

    @Test(arguments: [
        (401, EnhancerError.unknown("Gateway auth failed")),
        (403, .unknown("Gateway auth failed")),
        (402, .rateLimited),
        (429, .rateLimited),
        (529, .rateLimited),
        (413, .exceededContextWindow),
        (500, .unknown("HTTP 500")),
    ])
    func mapsHTTPStatus(_ status: Int, _ expected: EnhancerError) async {
        let result = await run(makeProvider(status: status, body: #"{"type":"error"}"#))
        #expect(result.error == expected)
    }

    @Test func mapsTokenLimit400ToContextWindow() async {
        let body =
            #"{"type":"error","error":{"type":"invalid_request_error","message":"prompt is too long: 300000 tokens"}}"#
        let result = await run(makeProvider(status: 400, body: body))
        #expect(result.error == .exceededContextWindow)
    }

    @Test(arguments: [URLError.Code.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost])
    func mapsConnectivityToOffline(_ code: URLError.Code) async {
        let result = await run(makeProvider(failure: URLError(code)))
        #expect(result.error == .offline)
    }

    @Test func mapsURLCancelledToCancelled() async {
        let result = await run(makeProvider(failure: URLError(.cancelled)))
        #expect(result.error == .cancelled)
    }

    /// Exercises `continuation.onTermination = { _ in task.cancel() }`: cancelling the
    /// *consuming* Task mid-stream must tear down the in-flight request without hanging
    /// or crashing, which is how `Enhancer` stops a generation early.
    @Test func cancellingConsumerTaskStopsStreamWithoutHanging() async {
        let provider = makeProvider()
        let (signal, signalContinuation) = AsyncStream<Void>.makeStream()
        let task = Task<String, Never> {
            var text = ""
            do {
                for try await delta in provider.stream(instructions: "SYS", prompt: "hey") {
                    text += delta
                    signalContinuation.yield(())
                }
            } catch {
                // Cancellation (or any other error) still leaves us with whatever was
                // collected before it happened; that's all this test needs.
            }
            return text
        }

        // Wait until at least one delta has been delivered before cancelling, so the
        // cancellation actually lands mid-stream rather than after it already finished.
        var iterator = signal.makeAsyncIterator()
        _ = await iterator.next()
        task.cancel()

        let text = await task.value  // must not hang
        #expect(!text.isEmpty)
    }

    @Test func streamWithoutMessageStopIsInterrupted() async {
        let body = """
            data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hel"}}

            """
        let result = await run(makeProvider(body: body))
        #expect(result.text == "Hel")
        #expect(result.error == .unknown("Connection interrupted"))
    }

    @Test func stepParsesEachEventType() {
        #expect(GatewayProvider.step(forLine: "event: content_block_delta") == .ignore)
        #expect(GatewayProvider.step(forLine: #"data: {"type":"ping"}"#) == .ignore)
        #expect(
            GatewayProvider.step(
                forLine: #"data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"a"}}"#)
                == .text("a"))
        #expect(GatewayProvider.step(forLine: #"data: {"type":"message_stop"}"#) == .stop)
        #expect(
            GatewayProvider.step(forLine: #"data: {"type":"message_delta","delta":{"stop_reason":"refusal"}}"#)
                == .fail(.guardrailViolation))
        #expect(
            GatewayProvider.step(forLine: #"data: {"type":"error","error":{"type":"overloaded_error"}}"#)
                == .fail(.rateLimited))
        #expect(GatewayProvider.step(forLine: "data: not json") == .fail(.unknown("Parse error")))
    }
}
