import SwiftUI

struct TodayView: View {
    @ObservedObject var store: Store

    private var today: String { Cal.todayString }
    private var yesterday: String { Cal.string(Cal.add(days: -1, to: Date())) }

    var body: some View {
        List {
            pendingSection
            routineSection
            completedSection
        }
        .listStyle(.plain)
    }

    // MARK: 待办 (left-swipe → 备忘)

    @ViewBuilder private var pendingSection: some View {
        let pending = store.tasks.filter {
            !$0.done && !$0.memo && ($0.dueDate == nil || $0.dueDate! <= today)
        }
        Section {
            if pending.isEmpty {
                Text("今天没有待办 🎉").foregroundColor(.secondary)
            } else {
                ForEach(Categories.grouped(pending), id: \.0) { cat, items in
                    Text(cat).font(.subheadline).bold().foregroundColor(.secondary)
                        .listRowSeparator(.hidden)
                    ForEach(items) { t in
                        taskButton(t, trailing: dueLabel(t))
                            // 右滑 → 备忘
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button { store.moveToMemo(t) } label: {
                                    Label("备忘", systemImage: "tray.and.arrow.down.fill")
                                }
                                .tint(.indigo)
                            }
                            // 左滑 → 删除
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { store.deleteTask(t) } label: {
                                    Label("删除", systemImage: "trash.fill")
                                }
                            }
                    }
                }
            }
        } header: {
            sectionTitle("待办")
        }
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
        } header: {
            sectionTitle("今日 Routine")
        }
    }

    // MARK: 已完成 (今天 / 昨天)

    @ViewBuilder private var completedSection: some View {
        let doneItems: [(Date, TodoTask)] = store.tasks
            .filter { $0.done }
            .compactMap { t in Cal.parseTimestamp(t.completedAt).map { ($0, t) } }
        let show = doneItems.contains { Cal.string($0.0) == today || Cal.string($0.0) == yesterday }
        if show {
            Section {
                ForEach([("今天", today), ("昨天", yesterday)], id: \.0) { label, day in
                    let items = doneItems.filter { Cal.string($0.0) == day }.sorted { $0.0 > $1.0 }
                    if !items.isEmpty {
                        Text(label).font(.subheadline).bold().foregroundColor(.secondary)
                            .listRowSeparator(.hidden)
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
            } header: {
                sectionTitle("已完成")
            }
        }
    }

    // MARK: helpers

    private func sectionTitle(_ s: String) -> some View {
        Text(s).font(.title2).bold().foregroundColor(.primary).textCase(nil).padding(.top, 4)
    }

    private func dueLabel(_ t: TodoTask) -> String? {
        guard let due = t.dueDate else { return nil }
        return (due < today ? "⚠ 逾期 " : "⏰ ") + due
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
}
