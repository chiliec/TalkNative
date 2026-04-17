import Foundation
import SwiftData

public enum HistorySchema {
    public static let versionedSchema = Schema([RecentItem.self])

    public static func makeContainer(appGroupURL: URL?) throws -> ModelContainer {
        let config: ModelConfiguration
        if let appGroupURL {
            let storeURL = appGroupURL.appendingPathComponent("history.sqlite")
            config = ModelConfiguration(url: storeURL)
        } else {
            config = ModelConfiguration(isStoredInMemoryOnly: true)
        }
        return try ModelContainer(for: versionedSchema, configurations: config)
    }
}
