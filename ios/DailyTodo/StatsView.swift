import SwiftUI

private enum HeatState { case met, miss, blank }

private struct HeatCell: View {
    let state: HeatState
    var size: CGFloat = 30
    var body: some View {
        let r = RoundedRectangle(cornerRadius: 5)
        switch state {
        case .met:   r.fill(Color.primary).frame(width: size, height: size)
        case .miss:  r.stroke(Color.primary, lineWidth: 1.5).frame(width: size, height: size)
        case .blank: r.stroke(Color(white: 0.73), lineWidth: 1).frame(width: size, height: size)
        }
    }
}

struct StatsView: View {
    @ObservedObject var store: Store

    private let weeks = 8
    private var today: String { Cal.todayString }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("坚持度（最近 \(weeks) 周）").font(.title2).bold().padding(.top, 8)
                HStack(spacing: 6) {
                    HeatCell(state: .met, size: 16); Text("达成").font(.caption)
                    HeatCell(state: .miss, size: 16).padding(.leading, 8); Text("漏掉").font(.caption)
                    Text("每格一周 · 左旧右新").font(.caption).padding(.leading, 8)
                }
                .padding(.top, 6)

                if store.routines.isEmpty {
                    Text("还没有 routine，先在 Claude 里添加吧").padding(.top, 16)
                } else {
                    let thisMonday = Cal.monday(of: Date())
                    let weekStarts = (0..<weeks).map { Cal.add(days: -7 * (weeks - 1 - $0), to: thisMonday) }
                    ForEach(store.routines) { r in
                        routineBlock(r, weekStarts: weekStarts)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func routineBlock(_ r: Routine, weekStarts: [Date]) -> some View {
        let doneDates = Set(store.logs.filter { $0.routineId == r.id && $0.done }.map { $0.date })
        let createdStr = Cal.parseTimestamp(r.createdAt).map { Cal.string($0) }
        let days = r.weekdays.sorted()

        let cells: [(wd: Int, ws: Date, state: HeatState)] = weekStarts.flatMap { ws in
            days.map { wd -> (Int, Date, HeatState) in
                let s = Cal.string(Cal.add(days: wd - 1, to: ws))
                let st: HeatState
                if s > today { st = .blank }
                else if let cd = createdStr, s < cd { st = .blank }
                else if doneDates.contains(s) { st = .met }
                else { st = .miss }
                return (wd, ws, st)
            }
        }
        let counted = cells.filter { $0.state != .blank }
        let total = counted.count
        let met = counted.filter { $0.state == .met }.count
        let pct = total > 0 ? met * 100 / total : 0

        let pastDates: [String] = weekStarts.flatMap { ws in days.map { Cal.string(Cal.add(days: $0 - 1, to: ws)) } }
            .filter { $0 <= today && (createdStr == nil || $0 >= createdStr!) }
            .sorted(by: >)
        let streak = pastDates.prefix(while: { doneDates.contains($0) }).count

        VStack(alignment: .leading, spacing: 0) {
            Divider().padding(.top, 18)
            HStack(alignment: .firstTextBaseline) {
                Text("\(r.icon ?? "")\(r.name)").font(.title3).bold()
                Spacer()
                Text("\(pct)%").font(.title).bold()
                Text("\(met)/\(total) 次").font(.subheadline).padding(.leading, 6)
            }
            .padding(.top, 12)
            Text(Categories.weekdaysLabel(r.weekdays) + (streak > 0 ? "   ·   🔥 连续达成 \(streak) 次" : ""))
                .font(.caption).padding(.top, 2)

            // progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).stroke(Color.primary, lineWidth: 1)
                    Rectangle().fill(Color.primary)
                        .frame(width: geo.size.width * CGFloat(pct) / 100)
                }
            }
            .frame(height: 12).padding(.top, 8)

            // heatmap: rows = scheduled weekdays, cols = weeks
            VStack(alignment: .leading, spacing: 6) {
                ForEach(days, id: \.self) { wd in
                    HStack(spacing: 6) {
                        Text(Categories.weekdayShort[wd] ?? "?").font(.caption).frame(width: 20)
                        ForEach(Array(weekStarts.enumerated()), id: \.offset) { idx, _ in
                            let st = cells.first { $0.wd == wd && Cal.string($0.ws) == Cal.string(weekStarts[idx]) }?.state ?? .blank
                            HeatCell(state: st)
                        }
                    }
                }
            }
            .padding(.top, 14)
        }
    }
}
