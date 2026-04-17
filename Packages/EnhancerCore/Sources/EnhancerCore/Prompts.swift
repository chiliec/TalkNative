import Foundation

public enum Prompts {
    public static func systemInstructions(styleInstructions: String) -> String {
        """
        You rewrite the user's message so it sounds like a native English speaker wrote it.
        Fix grammar, idioms, article usage, and awkward phrasing.
        Preserve the user's meaning and intent exactly.
        Preserve register (casual stays casual, formal stays formal) unless the style instruction says otherwise.
        Apply the style: \(styleInstructions)
        Output only the rewritten message. No preamble, no explanations.
        """
    }

    public static func userPrompt(original: String) -> String {
        "Original: \(original)"
    }
}
