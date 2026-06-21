import SwiftUI

struct TodayView: View {
    @ObservedObject var store: Store
    @ObservedObject var pomo: Pomodoro
    @State private var bucket = 0           // 0=工作 1=生活
    @State private var style: TaskStyle = .card
    @State private var editing: TodoTask?
    @State private var showStats = false
    @State private var showGoals = false
    @State private var showPomo = false

    private var today: String { Cal.todayString }
    private var yesterday: String { Cal.string(Cal.add(days: -1, to: Date())) }

    private func isPending(_ t: TodoTask) -> Bool {
        !t.done && !t.memo && (t.dueDate == nil || t.dueDate! <= today)
    }

    var body: some View {
        VStack(spacing: 0) {
            // single header row: 工作/生活 toggle (left) + small buttons (right)
            HStack(spacing: 8) {
                bucketToggle
                Spacer()
                miniButton(systemImage: "timer", text: pomo.running ? pomo.label : nil,
                           tint: pomo.running ? (pomo.phase == .work ? .indigo : .green) : nil) { showPomo = true }
                miniButton(systemImage: "chart.bar.xaxis") { showStats = true }
                miniButton(systemImage: "target") { showGoals = true }
            }
            .padding(.horizontal).padding(.top, 10).padding(.bottom, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if bucket == 0 { workContent } else { lifeContent }
                }
                .padding(.bottom, 28)
            }
        }
        .onAppear { style = TaskStyle.fromArgs() }
        .sheet(item: $editing) { t in
            EditTaskView(task: t, onSave: { store.updateTask($0) }, onDelete: { store.deleteTask(t) })
        }
        .sheet(isPresented: $showPomo) {
            NavigationStack {
                ScrollView { PomodoroBar(pomo: pomo, startExpanded: true).padding(.top, 12) }
                    .navigationTitle("🍅 番茄钟").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showPomo = false } } }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStats) {
            NavigationStack { StatsView(store: store) }.presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showGoals) { GoalsSheet(store: store) }
    }

    private func miniButton(systemImage: String, text: String? = nil, badge: Int = 0,
                            tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage).font(.subheadline)
                if let text { Text(text).font(.caption).monospacedDigit() }
                if badge > 0 {
                    Text("\(badge)").font(.caption2).bold().foregroundColor(.white)
                        .padding(.horizontal, 5).padding(.vertical, 1).background(Capsule().fill(Color.indigo))
                }
            }
            .foregroundColor(tint ?? .primary)
            .padding(.horizontal, 11).padding(.vertical, 7)
            .background(Capsule().fill(Color(.secondarySystemBackground)))
        }.buttonStyle(.plain)
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
        ForEach(WorkSections.order, id: \.self) { key in
            let items = pending.filter { ($0.workSection ?? "") == key }
            sectionHeader(key)
            if items.isEmpty {
                dropHint(key)
            } else if key == "feature" {
                let p1 = items.filter { $0.title.contains("🌟") }
                let p2 = items.filter { !$0.title.contains("🌟") }
                if !p1.isEmpty { prioHeader("P1", .orange); ForEach(p1) { t in baseCell(t, section: key, accent: .orange) } }
                if !p2.isEmpty { prioHeader("P2", .teal); ForEach(p2) { t in baseCell(t, section: key, accent: .teal) } }
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
                        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 2)
                    ForEach(items, id: \.1.id) { date, t in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(.secondary)
                            Text(t.title).strikethrough().foregroundColor(.secondary)
                            Spacer()
                            Text(Cal.hourMinute(date)).font(.caption).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 10).padding(.horizontal, 16)
                        .contentShape(Rectangle())
                        .onTapGesture { store.toggleTask(t) }
                    }
                }
            }
        }
    }

    // MARK: cells
    @ViewBuilder private func baseCell(_ t: TodoTask, section: String? = nil, accent: Color? = nil) -> some View {
        rowContent(t, accent: accent ?? sectionAccent(t.category == "工作" ? t.workSection : "life"))
            .contentShape(Rectangle())
            .onTapGesture { editing = t }
            .contextMenu { rowMenu(t, section) }   // long-press → move / 备忘 / 删除
            .padding(.horizontal, 16).padding(.vertical, 5)
    }

    @ViewBuilder private func rowMenu(_ t: TodoTask, _ section: String?) -> some View {
        if let section {
            ForEach(WorkSections.order.filter { $0 != section }, id: \.self) { key in
                Button { store.setTaskSection(t, key) } label: {
                    Label("移到 \(WorkSections.name[key] ?? key)", systemImage: "arrow.right.circle")
                }
            }
            Divider()
        }
        Button { store.moveToMemo(t) } label: { Label("移到备忘", systemImage: "tray.and.arrow.down") }
        Button(role: .destructive) { store.deleteTask(t) } label: { Label("删除", systemImage: "trash") }
    }

    private func sectionHeader(_ key: String) -> some View {
        Text(WorkSections.name[key] ?? key)
            .font(.subheadline).bold().foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 4)
    }

    private func dropHint(_ key: String) -> some View {
        Text("（空 · 长按别的任务可移过来）").font(.caption).foregroundColor(Color(.tertiaryLabel))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 4)
    }

    @ViewBuilder private func routineCell(_ r: Routine) -> some View {
        let done = store.logs.contains { $0.routineId == r.id && $0.date == today && $0.done }
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(Color.green)
            Text("\(r.icon ?? "")\(r.name)").font(.body)
            Spacer()
        }
        .padding(.vertical, 12).padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture { store.toggleRoutineToday(r) }
    }

    // MARK: row visuals
    @ViewBuilder private func rowContent(_ t: TodoTask, accent: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            checkbox(t, color: accent, big: false)
            VStack(alignment: .leading, spacing: 3) { titleText(t); metaText(t) }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
        .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
    }

    private func checkbox(_ t: TodoTask, color: Color, big: Bool) -> some View {
        let on = t.done || store.completingIds.contains(t.id)
        return Image(systemName: on ? "checkmark.circle.fill" : "circle")
            .font(.title2)
            .foregroundStyle(color)
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
            .onTapGesture { if !on { store.toggleTask(t) } }
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 4)
    }

    private func prioHeader(_ s: String, _ color: Color) -> some View {
        Text(s).font(.caption).bold().foregroundColor(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 28).padding(.trailing, 16).padding(.top, 8).padding(.bottom, 2)
    }

    private func emptyRow(_ s: String) -> some View {
        Text(s).foregroundColor(.secondary)
            .padding(.horizontal, 16).padding(.vertical, 8)
    }

    private func dueLabel(_ t: TodoTask) -> String? {
        guard let due = t.dueDate else { return nil }
        return (due < today ? "⚠ 逾期 " : "⏰ ") + due
    }
}


private func goalCountdown(_ ymd: String) -> String {
    guard let d = Cal.date(ymd) else { return "" }
    let days = Cal.cal.dateComponents([.day], from: Date(), to: d).day ?? 0
    if days > 0 { return "  · 还剩 \(days) 天" }
    if days == 0 { return "  · 今天" }
    return "  · 已过期"
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
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "circle").font(.title2).foregroundStyle(.indigo)
                                .frame(width: 36, height: 36).contentShape(Rectangle())
                                .onTapGesture { store.toggleGoal(g) }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(g.title).font(.body).fontWeight(.medium)
                                if let d = g.targetDate {
                                    Text("🗓 预期 \(d)" + goalCountdown(d))
                                        .font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("🎯 目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
