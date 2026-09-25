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

    @Test func systemInstructionsGuardContentAndLength() {
        let sys = Prompts.systemInstructions(styleInstructions: "x")
        #expect(sys.contains("Do not add, remove, or invent information"))
        #expect(sys.contains("a short message stays short"))
        #expect(sys.contains("URLs, email addresses, code"))
        #expect(sys.contains("translate it into natural English"))
    }

    @Test func userPromptWrapsOriginal() {
        let p = Prompts.userPrompt(original: "hey thx")
        #expect(p == "Original: hey thx")
    }
}
