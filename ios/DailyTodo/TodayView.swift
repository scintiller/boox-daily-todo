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
    @State private var adding = false
    // ---- finger-drag to move a task between work sections ----
    // @GestureState auto-resets on gesture end OR cancel → the floating card can never get stuck.
    @GestureState private var drag: DragInfo? = nil
    @State private var sectionFrames: [String: CGRect] = [:]
    @State private var dragCardWidth: CGFloat = 320

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
                miniButton(systemImage: "target") { showGoals = true }
                miniButton(systemImage: "timer", text: pomo.running ? pomo.label : nil,
                           tint: pomo.running ? (pomo.phase == .work ? .indigo : .green) : nil) { showPomo = true }
                miniButton(systemImage: "chart.bar.xaxis") { showStats = true }
            }
            .padding(.horizontal).padding(.top, 10).padding(.bottom, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if bucket == 0 { workContent } else { lifeContent }
                }
                .padding(.bottom, 28)
                .background(
                    GeometryReader { g in
                        Color.clear
                            .onAppear { dragCardWidth = g.size.width - 32 }
                            .onChange(of: g.size.width) { dragCardWidth = $0 - 32 }
                    }
                )
            }
            .coordinateSpace(name: "today")
            .onPreferenceChange(SectionFrameKey.self) { sectionFrames = $0 }
            .overlay {
                if let dg = drag, let t = store.tasks.first(where: { $0.id == dg.id }) {
                    floatingCard(t, y: dg.location.y)
                }
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
        .sheet(isPresented: $adding) {
            AddTaskView(store: store, defaultCategory: bucket == 0 ? "工作" : "生活")
        }
        .overlay(alignment: .bottomTrailing) {
            Button { adding = true } label: {
                Image(systemName: "plus").font(.title2.weight(.bold)).foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.accentColor))
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
            }
            .padding(.trailing, 22).padding(.bottom, 22)
        }
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

    // drop zones (also drag-source keys): focus, feature P1 (starred), feature P2
    private let dropZones = ["focus", "feature:p1", "feature:p2"]

    // MARK: content
    @ViewBuilder private var workContent: some View {
        let pending = store.tasks.filter { $0.category == "工作" && isPending($0) }
        let focusItems = pending.filter { ($0.workSection ?? "") == "focus" }
        let feat = pending.filter { ($0.workSection ?? "") == "feature" }
        let p1 = feat.filter { $0.title.contains("🌟") }
        let p2 = feat.filter { !$0.title.contains("🌟") }

        zone("focus") {
            sectionHeader("focus")
            if focusItems.isEmpty { dropHint("focus") }
            else { ForEach(focusItems) { t in baseCell(t, section: "focus") } }
        }
        sectionHeader("feature")
        zone("feature:p1") {
            prioHeader("P1", .orange)
            if p1.isEmpty { dropHint("feature:p1") }
            else { ForEach(p1) { t in baseCell(t, section: "feature:p1", accent: .orange) } }
        }
        zone("feature:p2") {
            prioHeader("P2", .teal)
            if p2.isEmpty { dropHint("feature:p2") }
            else { ForEach(p2) { t in baseCell(t, section: "feature:p2", accent: .teal) } }
        }
        let uncat = pending.filter { !["focus", "feature"].contains($0.workSection ?? "") }
        if !uncat.isEmpty {
            subHeader("· 未分类")
            ForEach(uncat) { t in baseCell(t) }
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
        let isWork = t.category == "工作"
        let resolved = section ?? (isWork ? (t.workSection ?? "feature") : "life")
        rowContent(t, accent: accent ?? sectionAccent(isWork ? t.workSection : "life"))
            .opacity(drag?.id == t.id ? 0 : 1)   // original stays in tree, just invisible while its copy floats
            .contentShape(Rectangle())
            .applyIf(isWork) {
                $0.onTapGesture { editing = t }                              // quick tap → edit
                  .overlay(alignment: .trailing) { dragHandle(t, section: resolved) }  // only the ≡ handle drags → row body still scrolls
            }
            .applyIf(!isWork) { $0.onTapGesture { editing = t }.contextMenu { rowMenu(t, nil) } }
            .padding(.horizontal, 16).padding(.vertical, 5)
    }

    /// Whether `key` is the zone the finger is currently hovering a valid drop over.
    private func isDropTarget(_ key: String) -> Bool {
        guard let dg = drag else { return false }
        let hov = sectionFrames.first { $0.value.contains(dg.location) }?.key
        return hov == key && key != dg.from
    }

    /// A measured, highlightable drop zone (its frame goes into sectionFrames under `key`).
    @ViewBuilder private func zone<Content: View>(_ key: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(GeometryReader { g in
                Color.clear.preference(key: SectionFrameKey.self, value: [key: g.frame(in: .named("today"))])
            })
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.accentColor.opacity(isDropTarget(key) ? 0.10 : 0)))
    }

    /// Apply a drop onto a zone: focus = section only; feature P1/P2 = section feature + 🌟 add/remove.
    private func applyDrop(_ t: TodoTask, to zone: String) {
        switch zone {
        case "focus": store.setTaskSection(t, "focus")
        case "feature:p1": store.setFeaturePriority(t, p1: true)
        case "feature:p2": store.setFeaturePriority(t, p1: false)
        default: break
        }
    }

    // The ≡ grip on each work row. Drag ONLY starts here, so the rest of the row scrolls
    // normally inside the ScrollView (the old whole-row long-press gesture stole scroll touches).
    @ViewBuilder private func dragHandle(_ t: TodoTask, section: String) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.body).foregroundColor(Color(.tertiaryLabel))
            .frame(width: 44, height: 44)           // generous touch target
            .contentShape(Rectangle())
            .gesture(handleDrag(t, section: section))
    }

    // Direct drag (no long-press needed — it's a dedicated handle). @GestureState `drag`
    // auto-resets on end OR cancel, so the floating card can never get stuck.
    private func handleDrag(_ t: TodoTask, section: String) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("today"))
            .updating($drag) { value, state, _ in
                state = DragInfo(id: t.id, from: section, location: value.location)
            }
            .onEnded { value in
                let target = sectionFrames.first { $0.value.contains(value.location) }?.key
                if let target, target != section, dropZones.contains(target),
                   let live = store.tasks.first(where: { $0.id == t.id }) {
                    applyDrop(live, to: target)   // ONLY a known, different zone → can never lose a task
                }
            }
    }

    @ViewBuilder private func floatingCard(_ t: TodoTask, y: CGFloat) -> some View {
        rowContent(t, accent: sectionAccent(t.category == "工作" ? t.workSection : "life"))
            .frame(width: dragCardWidth)
            .scaleEffect(1.04)
            .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
            .opacity(0.96)
            .allowsHitTesting(false)
            .position(x: dragCardWidth / 2 + 16, y: y)   // horizontally fixed like a row; follows finger vertically
            .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.85), value: y)
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
        Text("（空 · 拖任务右侧 ≡ 可移过来）").font(.caption).foregroundColor(Color(.tertiaryLabel))
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
        return Button {
            if !on { store.toggleTask(t) }
        } label: {
            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                .font(.title2).foregroundStyle(color)
                .frame(width: 36, height: 36).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
struct DragInfo: Equatable {
    let id: String
    let from: String
    let location: CGPoint
}

private struct SectionFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    @ViewBuilder func applyIf<T: View>(_ cond: Bool, _ transform: (Self) -> T) -> some View {
        if cond { transform(self) } else { self }
    }
}

/// Create a new task.
struct AddTaskView: View {
    @ObservedObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var category: String
    @State private var section = "focus"
    @State private var p1 = false
    @State private var hasDue = false
    @State private var due = Date()
    @State private var memo = false

    init(store: Store, defaultCategory: String = "工作") {
        self.store = store
        _category = State(initialValue: defaultCategory)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("新任务", text: $title, axis: .vertical) }
                Section("分类") {
                    Picker("分类", selection: $category) {
                        Text("工作").tag("工作"); Text("运动").tag("运动"); Text("生活").tag("生活")
                    }
                    .pickerStyle(.segmented)
                    if category == "工作" {
                        Picker("分区", selection: $section) {
                            Text("🔥 专注").tag("focus")
                            Text("🛠 随手做").tag("feature")
                        }
                        if section == "feature" { Toggle("P1 优先 🌟", isOn: $p1) }
                    }
                }
                Section {
                    Toggle("设为备忘（不进今日）", isOn: $memo)
                    Toggle("有截止日期", isOn: $hasDue.animation())
                    if hasDue { DatePicker("截止", selection: $due, displayedComponents: .date) }
                }
            }
            .navigationTitle("新任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") { add() }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func add() {
        var t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if category == "工作", section == "feature", p1, !t.contains("🌟") { t = "🌟 " + t }
        store.addTask(title: t, category: category,
                      section: category == "工作" ? section : nil,
                      dueDate: hasDue ? Cal.string(due) : nil, memo: memo)
        dismiss()
    }
}

struct GoalsSheet: View {
    @ObservedObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var editingGoal: Goal? = nil
    @State private var adding = false
    var body: some View {
        NavigationStack {
            List {
                let active = store.goals.filter { !$0.done }
                if active.isEmpty {
                    Text("还没有目标 · 点右上角 ＋ 添加").foregroundColor(.secondary)
                }
                ForEach(active) { g in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "circle").font(.title2).foregroundStyle(.indigo)
                            .frame(width: 36, height: 36).contentShape(Rectangle())
                            .onTapGesture { store.toggleGoal(g) }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(g.title).font(.body).fontWeight(.medium)
                            if let d = g.targetDate {
                                Text("🗓 预期 \(d)" + goalCountdown(d)).font(.caption).foregroundColor(.secondary)
                            } else {
                                Text("未设预期时间").font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(Color(.tertiaryLabel))
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture { editingGoal = g }   // tap a goal → edit
                }
            }
            .navigationTitle("🎯 目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { adding = true } label: { Image(systemName: "plus.circle.fill") }
                }
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
            .sheet(item: $editingGoal) { g in GoalEditView(store: store, goal: g) }
            .sheet(isPresented: $adding) { GoalEditView(store: store, goal: nil) }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

/// Add or edit a goal (title + optional target date).
struct GoalEditView: View {
    @ObservedObject var store: Store
    let goal: Goal?   // nil = add new
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var hasDate: Bool
    @State private var date: Date

    init(store: Store, goal: Goal?) {
        self.store = store; self.goal = goal
        _title = State(initialValue: goal?.title ?? "")
        _hasDate = State(initialValue: goal?.targetDate != nil)
        _date = State(initialValue: goal?.targetDate.flatMap { Cal.date($0) } ?? Date())
    }
    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("目标", text: $title, axis: .vertical) }
                Section {
                    Toggle("有预期时间", isOn: $hasDate.animation())
                    if hasDate { DatePicker("预期完成", selection: $date, displayedComponents: .date) }
                }
                if let g = goal {
                    Section {
                        Button(role: .destructive) { store.deleteGoal(g); dismiss() } label: {
                            HStack { Spacer(); Label("删除目标", systemImage: "trash"); Spacer() }
                        }
                    }
                }
            }
            .navigationTitle(goal == nil ? "新目标" : "编辑目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    private func save() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let td = hasDate ? Cal.string(date) : nil
        if let g = goal { store.updateGoal(g, title: t, targetDate: td) }
        else { store.addGoal(title: t, targetDate: td) }
        dismiss()
    }
}
