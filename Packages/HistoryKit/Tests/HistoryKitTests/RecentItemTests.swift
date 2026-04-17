import Testing
import Foundation
@testable import HistoryKit

@Suite("RecentItem")
struct RecentItemTests {
    @Test func variantsRoundTrip() throws {
        let variant = SavedVariant(
            presetID: UUID(),
            presetLabelSnapshot: "Casual",
            outputText: "Hey there!"
        )
        let data = try JSONEncoder().encode([variant])
        let decoded = try JSONDecoder().decode([SavedVariant].self, from: data)
        #expect(decoded == [variant])
    }
}
