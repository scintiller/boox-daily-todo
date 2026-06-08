import SwiftUI

struct MemoView: View {
    @ObservedObject var store: Store
    @State private var editing: TodoTask?
    private var today: String { Cal.todayString }

    private func memoSort(_ a: TodoTask, _ b: TodoTask) -> Bool {
        switch (a.dueDate, b.dueDate) {
        case let (x?, y?): return x < y        // dated first, soonest first
        case (nil, _?): return false
        case (_?, nil): return true
        default: return false                  // memos (no date) keep order
        }
    }

    var body: some View {
        let all = store.tasks.filter {
            !$0.done && ($0.memo || ($0.dueDate != nil && $0.dueDate! > today))
        }
        let life = all.filter { $0.category != "工作" }.sorted(by: memoSort)
        let work = all.filter { $0.category == "工作" }.sorted(by: memoSort)

        VStack(spacing: 0) {
            HStack {
                Text("备忘录").font(.title2).bold()
                Spacer()
            }
            .padding(.horizontal).padding(.top, 8).padding(.bottom, 6)

            List {
                if all.isEmpty {
                    Text("还没有备忘 📝").foregroundColor(.secondary)
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                } else {
                    if !life.isEmpty {
                        subHeader("生活")
                        ForEach(life) { memoRow($0) }
                    }
                    if !work.isEmpty {
                        subHeader("工作")
                        ForEach(work) { memoRow($0) }
                    }
                }
            }
            .listStyle(.plain)
        }
        .sheet(item: $editing) { t in
            EditTaskView(task: t,
                         onSave: { store.updateTask($0) },
                         onDelete: { store.deleteTask(t) })
        }
    }

    private func subHeader(_ s: String) -> some View {
        Text(s).font(.subheadline).bold().foregroundColor(.secondary)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 4, trailing: 16))
            .listRowBackground(Color.clear)
    }

    @ViewBuilder private func memoRow(_ t: TodoTask) -> some View {
        let accent = sectionAccent(t.category == "工作" ? t.workSection : "life")
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "circle").font(.title2).foregroundStyle(accent)
                .frame(width: 36, height: 36).contentShape(Rectangle())
                .onTapGesture { store.toggleTask(t) }
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
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
        .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
        .contentShape(Rectangle())
        .onTapGesture { editing = t }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
        .listRowBackground(Color.clear)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { store.moveToToday(t) } label: { Label("转待办", systemImage: "arrow.uturn.left") }.tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { store.deleteTask(t) } label: { Label("删除", systemImage: "trash.fill") }
        }
    }
}
