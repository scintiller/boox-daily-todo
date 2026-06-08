import SwiftUI
import Charts

func fmtMin(_ m: Int) -> String { m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m" }

/// Aggregates focus (work) sessions by day.
struct FocusData {
    let byDayMin: [String: Int]
    let byDayCount: [String: Int]

    init(_ sessions: [FocusSession]) {
        var m: [String: Int] = [:], c: [String: Int] = [:]
        for s in sessions where s.phase == "work" {
            guard let d = Cal.parseTimestamp(s.endedAt) else { continue }
            let k = Cal.string(d)
            m[k, default: 0] += s.minutes
            c[k, default: 0] += 1
        }
        byDayMin = m; byDayCount = c
    }

    func minutes(_ day: Date) -> Int { byDayMin[Cal.string(day)] ?? 0 }
    var todayMin: Int { minutes(Date()) }

    private func sumSince(_ start: Date, _ dict: [String: Int]) -> Int {
        dict.filter { (Cal.date($0.key) ?? .distantPast) >= start }.values.reduce(0, +)
    }
    var weekMin: Int { sumSince(Cal.monday(of: Date()), byDayMin) }
    var totalCount: Int { byDayCount.values.reduce(0, +) }
}

/// 专注记录 — daily focus-minutes bar chart (last 7 days) + week/total.
struct FocusSummary: View {
    let d: FocusData
    var body: some View {
        let days = (0..<7).map { Cal.add(days: -(6 - $0), to: Date()) }
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("🍅 专注").font(.title3).bold()
                Spacer()
                Text("本周 \(fmtMin(d.weekMin)) · 累计 \(d.totalCount) 🍅")
                    .font(.caption).foregroundColor(.secondary)
            }
            Text("今日 \(fmtMin(d.todayMin))").font(.subheadline).foregroundColor(.indigo)
            Chart(days, id: \.self) { day in
                BarMark(x: .value("日", Cal.monthDay(day)),
                        y: .value("分钟", d.minutes(day)))
                    .foregroundStyle(Color.indigo.gradient)
                    .cornerRadius(4)
            }
            .frame(height: 130)
            .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .padding(.top, 12)
    }
}
