import SwiftUI

struct MemoView: View {
    @ObservedObject var store: Store
    private var today: String { Cal.todayString }

    var body: some View {
        let items = store.tasks
            .filter { !$0.done && ($0.memo || ($0.dueDate != nil && $0.dueDate! > today)) }
            .sorted { a, b in
                // dated first (by date asc), memos (no date) last
                switch (a.dueDate, b.dueDate) {
                case let (x?, y?): return x < y
                case (nil, _?): return false
                case (_?, nil): return true
                default: return false
                }
            }
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("备忘录").font(.title2).bold().padding(.top, 8)
                if items.isEmpty {
                    Text("还没有备忘 📝").padding(.vertical, 8)
                } else {
                    ForEach(items) { t in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "circle").font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.title).font(.body)
                                if let due = t.dueDate {
                                    Text("⏰ \(due)").font(.caption).foregroundColor(.secondary)
                                } else if let c = t.category {
                                    Text(c).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 12)
                        .onTapGesture { store.toggleTask(t) }
                        Divider()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
