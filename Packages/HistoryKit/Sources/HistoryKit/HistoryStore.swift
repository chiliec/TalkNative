import Foundation
import SwiftData

@MainActor
public final class HistoryStore {
    public static let maxItems = 50

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    public init(container: ModelContainer) {
        self.container = container
    }

    public func insert(inputText: String, variants: [SavedVariant], deviceModelName: String) throws {
        let item = RecentItem(inputText: inputText, variants: variants, deviceModelName: deviceModelName)
        context.insert(item)
        try evictIfNeeded()
        try context.save()
    }

    public func allMostRecentFirst() -> [RecentItem] {
        let descriptor = FetchDescriptor<RecentItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    public func delete(id: UUID) throws {
        var descriptor = FetchDescriptor<RecentItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        if let item = try context.fetch(descriptor).first {
            context.delete(item)
            try context.save()
        }
    }

    public func clear() throws {
        let all = allMostRecentFirst()
        for item in all { context.delete(item) }
        try context.save()
    }

    private func evictIfNeeded() throws {
        let all = allMostRecentFirst()
        let overflow = all.count - Self.maxItems
        guard overflow > 0 else { return }
        for victim in all.suffix(overflow) {
            context.delete(victim)
        }
    }
}
