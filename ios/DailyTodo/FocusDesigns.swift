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
    func count(_ day: Date) -> Int { byDayCount[Cal.string(day)] ?? 0 }
    var todayMin: Int { minutes(Date()) }
    var todayCount: Int { count(Date()) }

    private func sumSince(_ start: Date, _ dict: [String: Int]) -> Int {
        dict.filter { (Cal.date($0.key) ?? .distantPast) >= start }.values.reduce(0, +)
    }
    var weekMin: Int { sumSince(Cal.monday(of: Date()), byDayMin) }
    var weekCount: Int { sumSince(Cal.monday(of: Date()), byDayCount) }
    var monthMin: Int { sumSince(Cal.startOfMonth(Date()), byDayMin) }
    var totalCount: Int { byDayCount.values.reduce(0, +) }
}

private func miniStat(_ label: String, _ value: String, _ color: Color = .primary) -> some View {
    VStack(alignment: .leading, spacing: 1) {
        Text(value).font(.title3).bold().foregroundColor(color)
        Text(label).font(.caption2).foregroundColor(.secondary)
    }
}

// MARK: A — 今日番茄 (Forest / 番茄ToDo style count)
struct FocusDesignA: View {
    let d: FocusData
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(d.todayCount > 0 ? String(repeating: "🍅", count: min(d.todayCount, 16))
                                  : "今天还没专注 · 开始一个吧")
                .font(.system(size: 30))
                .lineLimit(2)
            HStack(spacing: 24) {
                miniStat("今日", "\(d.todayCount) 🍅", .indigo)
                miniStat("今日时长", fmtMin(d.todayMin))
                miniStat("本周", "\(d.weekCount) 🍅")
                miniStat("累计", "\(d.totalCount)")
                Spacer()
            }
        }
    }
}

// MARK: B — 每日柱状 (Session / Bear style daily minutes)
struct FocusDesignB: View {
    let d: FocusData
    var body: some View {
        let days = (0..<7).map { Cal.add(days: -(6 - $0), to: Date()) }
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("本周专注 \(fmtMin(d.weekMin))").font(.headline)
                Spacer()
                Text("今日 \(fmtMin(d.todayMin))").font(.caption).foregroundColor(.secondary)
            }
            Chart(days, id: \.self) { day in
                BarMark(x: .value("日", Cal.monthDay(day)),
                        y: .value("分钟", d.minutes(day)))
                    .foregroundStyle(Color.indigo.gradient)
                    .cornerRadius(4)
            }
            .frame(height: 120)
            .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) }
        }
    }
}

// MARK: C — 热力图 (GitHub-contributions style)
struct FocusDesignC: View {
    let d: FocusData
    private func heat(_ m: Int) -> Color {
        switch m {
        case 0: return Color(.systemGray5)
        case 1..<30: return .indigo.opacity(0.30)
        case 30..<60: return .indigo.opacity(0.55)
        case 60..<120: return .indigo.opacity(0.80)
        default: return .indigo
        }
    }
    var body: some View {
        let thisMonday = Cal.monday(of: Date())
        let weekStarts = (0..<8).map { Cal.add(days: -7 * (7 - $0), to: thisMonday) }
        let todayStr = Cal.todayString
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("本月 \(fmtMin(d.monthMin))").font(.headline)
                Spacer()
                HStack(spacing: 3) {
                    Text("少").font(.caption2).foregroundColor(.secondary)
                    ForEach([0, 20, 45, 90, 130], id: \.self) { RoundedRectangle(cornerRadius: 2).fill(heat($0)).frame(width: 11, height: 11) }
                    Text("多").font(.caption2).foregroundColor(.secondary)
                }
            }
            VStack(spacing: 4) {
                ForEach(1...7, id: \.self) { wd in
                    HStack(spacing: 4) {
                        Text(Categories.weekdayShort[wd] ?? "").font(.caption2).foregroundColor(.secondary).frame(width: 14)
                        ForEach(Array(weekStarts.enumerated()), id: \.offset) { _, ws in
                            let day = Cal.add(days: wd - 1, to: ws)
                            let future = Cal.string(day) > todayStr
                            RoundedRectangle(cornerRadius: 3)
                                .fill(future ? Color.clear : heat(d.minutes(day)))
                                .frame(height: 18)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }
}

// MARK: D — 目标环 (Apple-Activity style ring vs daily goal)
struct FocusDesignD: View {
    let d: FocusData
    private let goal = 120
    var body: some View {
        let prog = min(1.0, Double(d.todayMin) / Double(goal))
        HStack(spacing: 22) {
            ZStack {
                Circle().stroke(Color(.systemGray5), lineWidth: 14)
                Circle().trim(from: 0, to: prog)
                    .stroke(Color.indigo, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(d.todayMin)").font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("/ \(goal) 分").font(.caption2).foregroundColor(.secondary)
                }
            }
            .frame(width: 124, height: 124)
            VStack(alignment: .leading, spacing: 12) {
                miniStat("今日目标", "\(Int(prog * 100))%", .indigo)
                miniStat("本周", fmtMin(d.weekMin))
                miniStat("累计番茄", "\(d.totalCount) 🍅")
            }
            Spacer()
        }
    }
}
