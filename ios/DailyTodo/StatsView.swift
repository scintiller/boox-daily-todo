import SwiftUI
import Charts

struct StatsView: View {
    @ObservedObject var store: Store

    private let palette: [Color] = [.indigo, .teal, .orange, .pink, .green, .blue]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("坚持度").font(.title2).bold().padding(.top, 8)

                FocusSummary(d: FocusData(store.focusSessions))

                Text("习惯打卡").font(.title3).bold().padding(.top, 22)
                Text("随时打卡 · 看你每周/每月坚持了几次")
                    .font(.caption).foregroundColor(.secondary).padding(.top, 1)

                if store.routines.isEmpty {
                    Text("还没有 routine").foregroundColor(.secondary).padding(.top, 16)
                } else {
                    ForEach(Array(store.routines.enumerated()), id: \.element.id) { idx, r in
                        routineCard(r, color: palette[idx % palette.count])
                    }
                }
            }
            .padding(.horizontal).padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func routineCard(_ r: Routine, color: Color) -> some View {
        let dates = store.logs.filter { $0.routineId == r.id && $0.done }
            .compactMap { Cal.date($0.date) }
            .sorted(by: >)
        let now = Date()
        let weekCount = dates.filter { $0 >= Cal.monday(of: now) }.count
        let monthCount = dates.filter { $0 >= Cal.startOfMonth(now) }.count

        // last 8 weeks: count per week (timeline)
        let thisMonday = Cal.monday(of: now)
        let weeks: [(start: Date, label: String, count: Int)] = (0..<8).map { i in
            let ws = Cal.add(days: -7 * (7 - i), to: thisMonday)
            let we = Cal.add(days: 7, to: ws)
            let c = dates.filter { $0 >= ws && $0 < we }.count
            return (ws, Cal.monthDay(ws), c)
        }
        let recent = dates.prefix(4).map { Cal.monthDay($0) }.joined(separator: " · ")

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(r.icon ?? "")\(r.name)").font(.title3).bold()
                Spacer()
                Text("共 \(dates.count) 次").font(.caption).foregroundColor(.secondary)
            }

            HStack(spacing: 28) {
                statPill("本周", weekCount, color)
                statPill("本月", monthCount, color)
                Spacer()
            }

            Chart(weeks, id: \.start) { w in
                BarMark(
                    x: .value("周", w.label),
                    y: .value("次数", w.count)
                )
                .foregroundStyle(color.gradient)
                .cornerRadius(4)
            }
            .frame(height: 92)
            .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) }

            if !recent.isEmpty {
                Text("最近：\(recent)").font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .padding(.top, 14)
    }

    private func statPill(_ label: String, _ n: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(n)").font(.system(size: 30, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundColor(color)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
    }
}
