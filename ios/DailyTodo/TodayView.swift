import SwiftUI

struct TodayView: View {
    @ObservedObject var store: Store

    private var today: String { Cal.todayString }
    private var yesterday: String { Cal.string(Cal.add(days: -1, to: Date())) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("待办").font(.title2).bold().padding(.top, 8)

                let pending = store.tasks.filter {
                    !$0.done && !$0.memo && ($0.dueDate == nil || $0.dueDate! <= today)
                }
                if pending.isEmpty {
                    Text("今天没有待办 🎉").padding(.vertical, 8)
                } else {
                    ForEach(Categories.grouped(pending), id: \.0) { cat, items in
                        Text(cat).font(.subheadline).bold().padding(.top, 12)
                        ForEach(items) { t in taskRow(t, trailing: dueLabel(t)) }
                    }
                }

                Text("今日 Routine").font(.title2).bold().padding(.top, 24)
                let todays = store.routines.filter { $0.weekdays.contains(Cal.isoWeekday(Date())) }
                if todays.isEmpty {
                    Text("今天没有安排的 routine").padding(.vertical, 8)
                } else {
                    ForEach(todays) { r in
                        let done = store.logs.contains { $0.routineId == r.id && $0.date == today && $0.done }
                        HStack(spacing: 12) {
                            Image(systemName: done ? "checkmark.circle.fill" : "circle").font(.title2)
                            Text("\(r.icon ?? "")\(r.name)").font(.body)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 12)
                        .onTapGesture { store.toggleRoutineToday(r) }
                        Divider()
                    }
                }

                completedSection
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var completedSection: some View {
        let doneItems: [(Date, TodoTask)] = store.tasks
            .filter { $0.done }
            .compactMap { t in Cal.parseTimestamp(t.completedAt).map { ($0, t) } }
        let show = doneItems.contains { Cal.string($0.0) == today || Cal.string($0.0) == yesterday }
        if show {
            Text("已完成").font(.title2).bold().padding(.top, 24)
            ForEach([("今天", today), ("昨天", yesterday)], id: \.0) { label, day in
                let items = doneItems
                    .filter { Cal.string($0.0) == day }
                    .sorted { $0.0 > $1.0 }
                if !items.isEmpty {
                    Text(label).font(.subheadline).bold().padding(.top, 12)
                    ForEach(items, id: \.1.id) { date, t in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill").font(.title2).foregroundColor(.secondary)
                            Text(t.title).strikethrough().foregroundColor(.secondary)
                            Spacer()
                            Text(Cal.hourMinute(date)).font(.caption).foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 12)
                        .onTapGesture { store.toggleTask(t) }
                        Divider()
                    }
                }
            }
        }
    }

    private func dueLabel(_ t: TodoTask) -> String? {
        guard let due = t.dueDate else { return nil }
        return (due < today ? "⚠ 逾期 " : "⏰ ") + due
    }

    @ViewBuilder private func taskRow(_ t: TodoTask, trailing: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: t.done ? "checkmark.circle.fill" : "circle").font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.title).font(.body)
                if let trailing { Text(trailing).font(.caption).foregroundColor(.secondary) }
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.vertical, 12)
        .onTapGesture { store.toggleTask(t) }
        Divider()
    }
}
