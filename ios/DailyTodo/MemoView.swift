import SwiftUI

struct MemoView: View {
    @ObservedObject var store: Store
    @State private var bucket = 0   // 0=工作 1=生活
    private var today: String { Cal.todayString }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $bucket) {
                Text("工作").tag(0)
                Text("生活").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)

            let all = store.tasks.filter {
                !$0.done && ($0.memo || ($0.dueDate != nil && $0.dueDate! > today))
            }
            let items = all
                .filter { ($0.category == "工作") == (bucket == 0) }
                .sorted { a, b in
                    switch (a.dueDate, b.dueDate) {     // dated first (asc), memos last
                    case let (x?, y?): return x < y
                    case (nil, _?): return false
                    case (_?, nil): return true
                    default: return false
                    }
                }

            List {
                Section {
                    if items.isEmpty {
                        Text(bucket == 0 ? "工作没有备忘 📝" : "生活没有备忘 📝")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(items) { t in memoRow(t) }
                    }
                } header: {
                    Text("备忘录").font(.title2).bold().foregroundColor(.primary)
                        .textCase(nil).padding(.top, 4)
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder private func memoRow(_ t: TodoTask) -> some View {
        Button { store.toggleTask(t) } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "circle").font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.title).font(.body)
                    if let due = t.dueDate {
                        Text("⏰ \(due)").font(.caption).foregroundColor(.secondary)
                    } else if t.category == "工作", let s = t.workSection {
                        Text(WorkSections.display(s)).font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {   // 右滑 → 转为今日待办
            Button { store.moveToToday(t) } label: {
                Label("转待办", systemImage: "arrow.uturn.left")
            }.tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {  // 左滑 → 删除
            Button(role: .destructive) { store.deleteTask(t) } label: {
                Label("删除", systemImage: "trash.fill")
            }
        }
    }
}
