import Testing
@testable import EnhancerCore

@Suite("StubLanguageModelProvider")
struct StubProviderTests {
    @Test func streamsScriptedChunks() async throws {
        let stub = StubLanguageModelProvider(
            scriptedChunks: ["Hello", ", ", "world!"]
        )
        var collected = ""
        for try await chunk in stub.stream(instructions: "sys", prompt: "in") {
            collected += chunk
        }
        #expect(collected == "Hello, world!")
    }

    @Test func throwsScriptedError() async {
        struct Boom: Error {}
        let stub = StubLanguageModelProvider(
            scriptedChunks: ["partial"],
            scriptedError: Boom()
        )
        var collected = ""
        do {
            for try await chunk in stub.stream(instructions: "", prompt: "") {
                collected += chunk
            }
            Issue.record("expected error was not thrown")
        } catch is Boom {
            #expect(collected == "partial")
        } catch {
            Issue.record("wrong error type: \(error)")
        }
    }

    @Test func defaultAvailabilityIsAvailable() {
        let stub = StubLanguageModelProvider(scriptedChunks: [])
        #expect(stub.availability == .available)
    }
}
