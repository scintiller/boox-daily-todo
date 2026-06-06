import SwiftUI

struct MemoView: View {
    @ObservedObject var store: Store
    @State private var bucket = 0   // 0=工作 1=生活
    @State private var editing: TodoTask?
    private var today: String { Cal.todayString }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("备忘录").font(.title2).bold()
                Spacer()
                bucketToggle
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 6)

            let all = store.tasks.filter {
                !$0.done && ($0.memo || ($0.dueDate != nil && $0.dueDate! > today))
            }
            let items = all
                .filter { ($0.category == "工作") == (bucket == 0) }
                .sorted { a, b in
                    switch (a.dueDate, b.dueDate) {
                    case let (x?, y?): return x < y
                    case (nil, _?): return false
                    case (_?, nil): return true
                    default: return false
                    }
                }

            List {
                if items.isEmpty {
                    Text(bucket == 0 ? "工作没有备忘 📝" : "生活没有备忘 📝")
                        .foregroundColor(.secondary)
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                } else {
                    ForEach(items) { t in memoRow(t) }
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

    private var bucketToggle: some View {
        HStack(spacing: 0) {
            ForEach(0..<2, id: \.self) { i in
                Text(["工作", "生活"][i])
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(bucket == i ? .white : .secondary)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .background { if bucket == i { Capsule().fill(Color.accentColor) } }
                    .contentShape(Capsule())
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.18)) { bucket = i } }
            }
        }
        .padding(3)
        .background(Capsule().fill(Color(.systemGray5)))
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
