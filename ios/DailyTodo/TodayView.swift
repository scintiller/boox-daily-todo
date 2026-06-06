import SwiftUI

struct TodayView: View {
    @ObservedObject var store: Store
    @State private var bucket = 0   // 0=工作 1=生活

    private var today: String { Cal.todayString }
    private var yesterday: String { Cal.string(Cal.add(days: -1, to: Date())) }

    private func isPending(_ t: TodoTask) -> Bool {
        !t.done && !t.memo && (t.dueDate == nil || t.dueDate! <= today)
    }

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

            List {
                if bucket == 0 { workBucket } else { lifeBucket }
            }
            .listStyle(.plain)
            // List animates row moves (待办 → 已完成) driven by the optimistic toggle.
        }
    }

    // MARK: 工作 — split into 主线 / 沟通 / 随手做
    @ViewBuilder private var workBucket: some View {
        let pending = store.tasks.filter { $0.category == "工作" && isPending($0) }
        Section {
            if pending.isEmpty {
                Text("工作没有待办 🎉").foregroundColor(.secondary)
            } else {
                ForEach(WorkSections.order, id: \.self) { key in
                    let items = pending.filter { ($0.workSection ?? "") == key }
                    if !items.isEmpty {
                        subHeader(WorkSections.name[key] ?? key)
                        ForEach(items) { t in workRow(t) }
                    }
                }
                let uncat = pending.filter { !WorkSections.order.contains($0.workSection ?? "") }
                if !uncat.isEmpty {
                    subHeader("· 未分类")
                    ForEach(uncat) { t in workRow(t) }
                }
            }
        } header: { sectionTitle("待办") }

        completedSection(work: true)
    }

    // MARK: 生活 — 生活 + 运动 (flat) + 今日 Routine
    @ViewBuilder private var lifeBucket: some View {
        let pending = store.tasks.filter { $0.category != "工作" && isPending($0) }
        Section {
            if pending.isEmpty {
                Text("生活没有待办 🎉").foregroundColor(.secondary)
            } else {
                ForEach(pending) { t in taskRow(t) }
            }
        } header: { sectionTitle("待办") }

        routineSection
        completedSection(work: false)
    }

    // MARK: 今日 Routine
    @ViewBuilder private var routineSection: some View {
        let todays = store.routines.filter { $0.weekdays.contains(Cal.isoWeekday(Date())) }
        Section {
            if todays.isEmpty {
                Text("今天没有安排的 routine").foregroundColor(.secondary)
            } else {
                ForEach(todays) { r in
                    let done = store.logs.contains { $0.routineId == r.id && $0.date == today && $0.done }
                    Button { store.toggleRoutineToday(r) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: done ? "checkmark.circle.fill" : "circle").font(.title2)
                            Text("\(r.icon ?? "")\(r.name)").font(.body)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: { sectionTitle("今日 Routine") }
    }

    // MARK: 已完成
    @ViewBuilder private func completedSection(work: Bool) -> some View {
        let doneItems: [(Date, TodoTask)] = store.tasks
            .filter { $0.done && (($0.category == "工作") == work) }
            .compactMap { t in Cal.parseTimestamp(t.completedAt).map { ($0, t) } }
        let show = doneItems.contains { Cal.string($0.0) == today || Cal.string($0.0) == yesterday }
        if show {
            Section {
                ForEach([("今天", today), ("昨天", yesterday)], id: \.0) { label, day in
                    let items = doneItems.filter { Cal.string($0.0) == day }.sorted { $0.0 > $1.0 }
                    if !items.isEmpty {
                        subHeader(label)
                        ForEach(items, id: \.1.id) { date, t in
                            Button { store.toggleTask(t) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill").font(.title2).foregroundColor(.secondary)
                                    Text(t.title).strikethrough().foregroundColor(.secondary)
                                    Spacer()
                                    Text(Cal.hourMinute(date)).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } header: { sectionTitle("已完成") }
        }
    }

    // MARK: rows
    @ViewBuilder private func taskRow(_ t: TodoTask) -> some View {
        taskButton(t, trailing: dueLabel(t))
            .swipeActions(edge: .leading, allowsFullSwipe: true) {   // 右滑 → 备忘
                Button { store.moveToMemo(t) } label: {
                    Label("备忘", systemImage: "tray.and.arrow.down.fill")
                }.tint(.indigo)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {  // 左滑 → 删除
                Button(role: .destructive) { store.deleteTask(t) } label: {
                    Label("删除", systemImage: "trash.fill")
                }
            }
    }

    // work row adds a long-press menu to move between 主线/沟通/随手做
    @ViewBuilder private func workRow(_ t: TodoTask) -> some View {
        taskRow(t)
            .contextMenu {
                Text("移到")
                ForEach(WorkSections.order, id: \.self) { key in
                    if (t.workSection ?? "") != key {
                        Button { store.setTaskSection(t, key) } label: {
                            Label(WorkSections.name[key] ?? key, systemImage: "arrow.right.circle")
                        }
                    }
                }
            }
    }

    @ViewBuilder private func taskButton(_ t: TodoTask, trailing: String?) -> some View {
        Button { store.toggleTask(t) } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: t.done ? "checkmark.circle.fill" : "circle").font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.title).font(.body)
                    if let trailing { Text(trailing).font(.caption).foregroundColor(.secondary) }
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: helpers
    private func sectionTitle(_ s: String) -> some View {
        Text(s).font(.title2).bold().foregroundColor(.primary).textCase(nil).padding(.top, 4)
    }

    private func subHeader(_ s: String) -> some View {
        Text(s).font(.subheadline).bold().foregroundColor(.secondary).listRowSeparator(.hidden)
    }

    private func dueLabel(_ t: TodoTask) -> String? {
        guard let due = t.dueDate else { return nil }
        return (due < today ? "⚠ 逾期 " : "⏰ ") + due
    }
}
