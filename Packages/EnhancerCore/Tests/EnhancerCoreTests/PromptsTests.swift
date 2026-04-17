import Testing
@testable import EnhancerCore

@Suite("Prompts")
struct PromptsTests {
    @Test func systemInstructionsContainNativeGuidance() {
        let sys = Prompts.systemInstructions(styleInstructions: "Casual, friendly.")
        #expect(sys.contains("native English speaker"))
        #expect(sys.contains("Preserve the user's meaning"))
        #expect(sys.contains("Casual, friendly."))
    }

    @Test func systemInstructionsForbidPreamble() {
        let sys = Prompts.systemInstructions(styleInstructions: "x")
        #expect(sys.contains("No preamble"))
    }

    @Test func userPromptWrapsOriginal() {
        let p = Prompts.userPrompt(original: "hey thx")
        #expect(p == "Original: hey thx")
    }
}
