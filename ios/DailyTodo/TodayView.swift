import SwiftUI
import UniformTypeIdentifiers

/// Load dropped task ids (NSString) and move them into `key`.
private func acceptDrop(_ providers: [NSItemProvider], _ key: String,
                        _ move: @escaping ([String], String) -> Void) -> Bool {
    var any = false
    for p in providers where p.canLoadObject(ofClass: NSString.self) {
        any = true
        _ = p.loadObject(ofClass: NSString.self) { obj, _ in
            if let s = obj as? String {
                DispatchQueue.main.async { move([s], key) }
            }
        }
    }
    return any
}

struct TodayView: View {
    @ObservedObject var store: Store
    @ObservedObject var pomo: Pomodoro
    @State private var bucket = 0           // 0=工作 1=生活
    @State private var style: TaskStyle = .card
    @State private var editing: TodoTask?
    @State private var showStats = false
    @State private var showGoals = false

    private var today: String { Cal.todayString }
    private var yesterday: String { Cal.string(Cal.add(days: -1, to: Date())) }

    private func isPending(_ t: TodoTask) -> Bool {
        !t.done && !t.memo && (t.dueDate == nil || t.dueDate! <= today)
    }

    var body: some View {
        VStack(spacing: 0) {
            PomodoroBar(pomo: pomo)

            topButtons

            // 工作/生活 toggle on the left
            HStack {
                bucketToggle
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 6)

            List {
                if bucket == 0 { workContent } else { lifeContent }
            }
            .listStyle(.plain)
        }
        .onAppear { style = TaskStyle.fromArgs() }
        .sheet(item: $editing) { t in
            EditTaskView(task: t,
                         onSave: { store.updateTask($0) },
                         onDelete: { store.deleteTask(t) })
        }
        .sheet(isPresented: $showStats) {
            NavigationStack { StatsView(store: store) }
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showGoals) {
            GoalsSheet(store: store)
        }
    }

    private var topButtons: some View {
        HStack(spacing: 12) {
            Button { showStats = true } label: {
                Label("坚持度", systemImage: "chart.bar.xaxis")
                    .font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
            }.buttonStyle(.plain)
            Button { showGoals = true } label: {
                HStack(spacing: 6) {
                    Label("目标", systemImage: "target")
                        .font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                    let n = store.goals.filter { !$0.done }.count
                    if n > 0 {
                        Text("\(n)").font(.caption2).bold().foregroundColor(.white)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(Color.indigo))
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal).padding(.top, 8)
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

    // MARK: content
    @ViewBuilder private var workContent: some View {
        let pending = store.tasks.filter { $0.category == "工作" && isPending($0) }
        // Always show all 3 sections as drop targets (长按任务可拖到别的分区)
        ForEach(WorkSections.order, id: \.self) { key in
            let items = pending.filter { ($0.workSection ?? "") == key }
            sectionHeader(key)
            if items.isEmpty {
                dropHint(key)
            } else if key == "feature" {
                // 随手做 split into P1 (starred 🌟) / P2 (rest)
                let p1 = items.filter { $0.title.contains("🌟") }
                let p2 = items.filter { !$0.title.contains("🌟") }
                if !p1.isEmpty { prioHeader("P1"); ForEach(p1) { t in baseCell(t, section: key) } }
                if !p2.isEmpty { prioHeader("P2"); ForEach(p2) { t in baseCell(t, section: key) } }
            } else {
                ForEach(items) { t in baseCell(t, section: key) }
            }
        }
        let uncat = pending.filter { !WorkSections.order.contains($0.workSection ?? "") }
        if !uncat.isEmpty {
            subHeader("· 未分类")
            ForEach(uncat) { t in baseCell(t, section: "feature") }
        }
        completedRows(work: true)
    }

    @ViewBuilder private var lifeContent: some View {
        let pending = store.tasks.filter { $0.category != "工作" && isPending($0) }
        if pending.isEmpty { emptyRow("生活没有待办 🎉") }
        ForEach(pending) { t in baseCell(t) }
        subHeader("今日 Routine")
        // anytime habits: show all, check off whenever you do them
        if store.routines.isEmpty { emptyRow("还没有 routine") }
        ForEach(store.routines) { r in routineCell(r) }
        completedRows(work: false)
    }

    @ViewBuilder private func completedRows(work: Bool) -> some View {
        let doneItems = store.tasks
            .filter { $0.done && (($0.category == "工作") == work) }
            .compactMap { t in Cal.parseTimestamp(t.completedAt).map { ($0, t) } }
        if doneItems.contains(where: { Cal.string($0.0) == today || Cal.string($0.0) == yesterday }) {
            subHeader("已完成")
            ForEach([("今天", today), ("昨天", yesterday)], id: \.0) { label, day in
                let items = doneItems.filter { Cal.string($0.0) == day }.sorted { $0.0 > $1.0 }
                if !items.isEmpty {
                    Text(label).font(.caption).bold().foregroundColor(.secondary)
                        .plainRow(EdgeInsets(top: 8, leading: 16, bottom: 2, trailing: 16))
                    ForEach(items, id: \.1.id) { date, t in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(.secondary)
                            Text(t.title).strikethrough().foregroundColor(.secondary)
                            Spacer()
                            Text(Cal.hourMinute(date)).font(.caption).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                        .onTapGesture { store.toggleTask(t) }
                        .plainRow(rowInsets)
                    }
                }
            }
        }
    }

    // MARK: cells
    @ViewBuilder private func baseCell(_ t: TodoTask, section: String? = nil) -> some View {
        rowContent(t, accent: sectionAccent(t.category == "工作" ? t.workSection : "life"))
            .contentShape(Rectangle())
            .onTapGesture { editing = t }    // tap row → edit (checkbox handles complete)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button { store.moveToMemo(t) } label: { Label("备忘", systemImage: "tray.and.arrow.down.fill") }.tint(.indigo)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) { store.deleteTask(t) } label: { Label("删除", systemImage: "trash.fill") }
            }
            .modifier(SectionDragDrop(id: t.id, section: section, move: moveToSection))
            .listRowSeparator(style == .bold ? .automatic : .hidden)
            .listRowInsets(rowInsets)
            .listRowBackground(Color.clear)
    }

    /// Move dragged task ids into a work section.
    private func moveToSection(_ ids: [String], _ key: String) {
        for id in ids {
            if let t = store.tasks.first(where: { $0.id == id }), (t.workSection ?? "") != key {
                store.setTaskSection(t, key)
            }
        }
    }

    /// Section sub-header that's also a drop target.
    private func sectionHeader(_ key: String) -> some View {
        Text(WorkSections.name[key] ?? key)
            .font(.subheadline).bold().foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onDrop(of: [UTType.text], isTargeted: nil) { acceptDrop($0, key, moveToSection) }
            .plainRow(EdgeInsets(top: 16, leading: 16, bottom: 4, trailing: 16))
    }

    private func dropHint(_ key: String) -> some View {
        Text("拖任务到这里").font(.caption).foregroundColor(Color(.tertiaryLabel))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10).padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(.systemGray4), style: StrokeStyle(lineWidth: 1, dash: [4])))
            .contentShape(Rectangle())
            .onDrop(of: [UTType.text], isTargeted: nil) { acceptDrop($0, key, moveToSection) }
            .plainRow(EdgeInsets(top: 2, leading: 16, bottom: 6, trailing: 16))
    }

    @ViewBuilder private func routineCell(_ r: Routine) -> some View {
        let done = store.logs.contains { $0.routineId == r.id && $0.date == today && $0.done }
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(Color.green)
            Text("\(r.icon ?? "")\(r.name)").font(.body)
            Spacer()
        }
        .padding(.vertical, style == .card ? 14 : 11)
        .contentShape(Rectangle())
        .onTapGesture { store.toggleRoutineToday(r) }
        .plainRow(rowInsets, separator: style == .bold)
    }

    // MARK: row visuals per style
    @ViewBuilder private func rowContent(_ t: TodoTask, accent: Color) -> some View {
        switch style {
        case .minimal:
            HStack(alignment: .center, spacing: 12) {
                checkbox(t, color: .secondary, big: false)
                VStack(alignment: .leading, spacing: 3) { titleText(t); metaText(t) }
                Spacer()
            }
            .padding(.vertical, 13)
        case .card:
            HStack(alignment: .center, spacing: 12) {
                checkbox(t, color: accent, big: false)
                VStack(alignment: .leading, spacing: 3) { titleText(t); metaText(t) }
                Spacer()
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
            .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
        case .accentBar:
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 4)
                HStack(alignment: .center, spacing: 10) {
                    checkbox(t, color: accent, big: false)
                    VStack(alignment: .leading, spacing: 2) { titleText(t); metaText(t) }
                    Spacer()
                }
                .padding(.vertical, 10).padding(.leading, 11).padding(.trailing, 8)
            }
            .background(RoundedRectangle(cornerRadius: 9).fill(accent.opacity(0.07)))
        case .bold:
            HStack(alignment: .center, spacing: 14) {
                checkbox(t, color: accent, big: true)
                VStack(alignment: .leading, spacing: 3) { titleText(t, weight: .medium); metaText(t) }
                Spacer()
            }
            .padding(.vertical, 11)
        }
    }

    private func checkbox(_ t: TodoTask, color: Color, big: Bool) -> some View {
        let on = t.done || store.completingIds.contains(t.id)
        return Image(systemName: on ? "checkmark.circle.fill" : "circle")
            .font(big ? .title : .title2)
            .foregroundStyle(color)
            .frame(width: 36, height: 36)        // bigger hit area
            .contentShape(Rectangle())
            .onTapGesture { if !on { store.toggleTask(t) } } // tap circle → complete
    }

    private func titleText(_ t: TodoTask, weight: Font.Weight = .regular) -> some View {
        let on = t.done || store.completingIds.contains(t.id)
        return Text(t.title).font(.body.weight(weight))
            .strikethrough(on).foregroundColor(on ? .secondary : .primary)
    }

    @ViewBuilder private func metaText(_ t: TodoTask) -> some View {
        if let d = dueLabel(t) { Text(d).font(.caption).foregroundColor(.secondary) }
    }

    // MARK: small helpers
    private func subHeader(_ s: String) -> some View {
        Text(s).font(.subheadline).bold().foregroundColor(.secondary)
            .plainRow(EdgeInsets(top: 16, leading: 16, bottom: 4, trailing: 16))
    }

    private func prioHeader(_ s: String) -> some View {
        Text(s).font(.caption).bold().foregroundColor(.indigo)
            .plainRow(EdgeInsets(top: 8, leading: 28, bottom: 2, trailing: 16))
    }

    private func emptyRow(_ s: String) -> some View {
        Text(s).foregroundColor(.secondary)
            .plainRow(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private var rowInsets: EdgeInsets {
        switch style {
        case .card: return EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16)
        case .accentBar: return EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)
        default: return EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        }
    }

    private func dueLabel(_ t: TodoTask) -> String? {
        guard let due = t.dueDate else { return nil }
        return (due < today ? "⚠ 逾期 " : "⏰ ") + due
    }
}

private extension View {
    func plainRow(_ insets: EdgeInsets, separator: Bool = false) -> some View {
        self.listRowSeparator(separator ? .automatic : .hidden)
            .listRowInsets(insets)
            .listRowBackground(Color.clear)
    }
}

/// 目标 sheet — opened from the 目标 button.
struct GoalsSheet: View {
    @ObservedObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                let active = store.goals.filter { !$0.done }
                if active.isEmpty {
                    Text("还没有目标 🎯").foregroundColor(.secondary)
                } else {
                    ForEach(active) { g in
                        HStack(spacing: 12) {
                            Image(systemName: "circle").font(.title2).foregroundStyle(.indigo)
                                .frame(width: 36, height: 36).contentShape(Rectangle())
                                .onTapGesture { store.toggleGoal(g) }
                            Text(g.title).font(.body).fontWeight(.medium)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("🎯 本周目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// Makes a work row draggable and a drop target; no-op for rows without a section.
private struct SectionDragDrop: ViewModifier {
    let id: String
    let section: String?
    let move: ([String], String) -> Void
    func body(content: Content) -> some View {
        if let section {
            content
                .onDrag { NSItemProvider(object: id as NSString) }
                .onDrop(of: [UTType.text], isTargeted: nil) { acceptDrop($0, section, move) }
        } else {
            content
        }
    }
}
