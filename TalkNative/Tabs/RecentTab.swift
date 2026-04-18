import SwiftUI
import UIKit
import HistoryKit
import EnhancerUI

struct RecentTab: View {
    @Environment(AppServices.self) private var services
    @State private var selected: RecentItem?
    @State private var items: [RecentItem] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    Button { selected = item } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.inputText)
                                .lineLimit(2)
                                .foregroundStyle(.primary)
                            Text(item.createdAt, style: .relative)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: delete)
            }
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView("No recent enhancements",
                                           systemImage: "clock",
                                           description: Text("Enhanced messages appear here."))
                }
            }
            .navigationTitle("Recent")
            .sheet(item: $selected) { item in
                SavedVariantsSheet(item: item, onDismiss: { selected = nil })
            }
            .onAppear(perform: reload)
        }
    }

    private func reload() {
        items = services.historyStore.allMostRecentFirst()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            try? services.historyStore.delete(id: items[index].id)
        }
        reload()
    }
}

private struct SavedVariantsSheet: View {
    let item: RecentItem
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("YOUR TEXT").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(item.inputText).padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))

                    ForEach(item.variants, id: \.presetID) { v in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(v.presetLabelSnapshot.uppercased())
                                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(v.outputText)
                            Button("Copy") {
                                UIPasteboard.general.string = v.outputText
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(12)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("Recent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }
}
