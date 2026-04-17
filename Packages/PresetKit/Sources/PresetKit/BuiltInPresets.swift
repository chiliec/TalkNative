import Foundation

public enum BuiltInPresets {
    public static let all: [Preset] = [
        Preset(id: uuid("A1"),
               label: "Casual",
               instructions: "Use everyday conversational language. Light contractions. Friendly but not overly formal.",
               isBuiltIn: true, sortOrder: 0),
        Preset(id: uuid("A2"),
               label: "Neutral",
               instructions: "Neutral register. No slang, no stiffness. Plain, clear English.",
               isBuiltIn: true, sortOrder: 1),
        Preset(id: uuid("A3"),
               label: "Formal",
               instructions: "Formal English suitable for business correspondence. No contractions. Polite and precise.",
               isBuiltIn: true, sortOrder: 2),
        Preset(id: uuid("A4"),
               label: "Friendly",
               instructions: "Warm and approachable. Light exclamation use is okay. Assume a cooperative reader.",
               isBuiltIn: true, sortOrder: 3),
        Preset(id: uuid("A5"),
               label: "Direct",
               instructions: "Short sentences. Remove filler and hedging. Be assertive but courteous.",
               isBuiltIn: true, sortOrder: 4),
        Preset(id: uuid("A6"),
               label: "Professional",
               instructions: "Business-appropriate, polished, courteous. Slightly formal. Suitable for email and Slack.",
               isBuiltIn: true, sortOrder: 5),
        Preset(id: uuid("A7"),
               label: "Warm",
               instructions: "Kind, considerate phrasing. Gentle openings and closings where appropriate.",
               isBuiltIn: true, sortOrder: 6),
        Preset(id: uuid("A8"),
               label: "Confident",
               instructions: "Assertive and self-assured. Avoid apologetic language. State positions clearly.",
               isBuiltIn: true, sortOrder: 7)
    ]

    public static var defaultActive: [Preset] {
        let labels: Set<String> = ["Casual", "Professional", "Warm"]
        return all.filter { labels.contains($0.label) }
    }

    private static func uuid(_ seed: String) -> UUID {
        var bytes = Array(seed.utf8)
        while bytes.count < 16 { bytes.append(0) }
        let slice = Array(bytes.prefix(16))
        return UUID(uuid: (slice[0],slice[1],slice[2],slice[3],slice[4],slice[5],slice[6],slice[7],
                          slice[8],slice[9],slice[10],slice[11],slice[12],slice[13],slice[14],slice[15]))
    }
}
