import Foundation

/// Strings whose grapheme-cluster count differs from their UTF-16 count.
/// Every one of these is a case where using `utf16.count` as a delete count
/// would over-delete and eat text the user never selected.
enum UnicodeCorpus {
    static let samples: [(name: String, text: String)] = [
        ("ascii", "hello world"),
        ("emoji", "nice \u{1F44D}"),
        ("zwjFamily", "family \u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}"),
        ("flag", "from \u{1F1FA}\u{1F1E6}"),
        ("combiningAccent", "caf\u{65}\u{301}"),
        ("crlf", "line one\r\nline two"),
        ("mixed", "ok \u{1F44D}\u{1F1FA}\u{1F1E6} caf\u{65}\u{301}\r\ndone"),
    ]
}
