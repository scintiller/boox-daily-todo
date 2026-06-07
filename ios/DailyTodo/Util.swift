import Foundation
import SwiftUI

enum Cal {
    static let cal = Calendar.current

    private static let ymd: DateFormatter = {
        let f = DateFormatter()
        f.calendar = cal
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func string(_ date: Date) -> String { ymd.string(from: date) }
    static func date(_ s: String) -> Date? { ymd.date(from: s) }

    static var todayString: String { string(Date()) }

    static func add(days: Int, to date: Date) -> Date {
        cal.date(byAdding: .day, value: days, to: date)!
    }

    /// ISO weekday: 1=Mon .. 7=Sun
    static func isoWeekday(_ date: Date) -> Int {
        let wd = cal.component(.weekday, from: date) // 1=Sun..7=Sat
        return wd == 1 ? 7 : wd - 1
    }

    /// Monday of the week containing `date`.
    static func monday(of date: Date) -> Date {
        add(days: -(isoWeekday(date) - 1), to: date)
    }

    static func startOfMonth(_ date: Date) -> Date {
        cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }

    private static let md: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "M/d"
        return f
    }()
    static func monthDay(_ date: Date) -> String { md.string(from: date) }

    /// Parse a Postgres timestamptz (e.g. 2026-05-28T18:32:00.12+00:00 or ...Z) to Date.
    static func parseTimestamp(_ s: String?) -> Date? {
        guard let s else { return nil }
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFrac.date(from: s) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: s)
    }

    private static let hhmm: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()
    static func hourMinute(_ date: Date) -> String { hhmm.string(from: date) }
}

enum WorkSections {
    static let order = ["focus", "comms", "feature"]
    static let name = ["focus": "🎯 主线", "comms": "💬 沟通", "feature": "🛠 随手做"]
    static func display(_ key: String?) -> String { name[key ?? ""] ?? "· 未分类" }
}

/// Accent color per work section / 生活, used by the accent-styled rows.
func sectionAccent(_ key: String?) -> Color {
    switch key {
    case "focus": return .indigo
    case "comms": return .teal
    case "feature": return .orange
    default: return .green   // 生活 / 未分类
    }
}

enum TaskStyle: Int, CaseIterable, Identifiable {
    case minimal, card, accentBar, bold
    var id: Int { rawValue }
    var label: String { ["简约", "卡片", "色条", "彩色圆"][rawValue] }
    static func fromArgs() -> TaskStyle {
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "-Style"), i + 1 < a.count, let n = Int(a[i + 1]),
           let s = TaskStyle(rawValue: n) { return s }
        return .card   // chosen default
    }
}

enum Categories {
    static let order = ["工作", "运动", "生活"]
    static let weekdayShort = [1: "一", 2: "二", 3: "三", 4: "四", 5: "五", 6: "六", 7: "日"]
    static let weekdayCN = [1: "周一", 2: "周二", 3: "周三", 4: "周四", 5: "周五", 6: "周六", 7: "周日"]

    static func weekdaysLabel(_ days: [Int]) -> String {
        days.sorted().compactMap { weekdayCN[$0] }.joined(separator: "、")
    }

    /// Group tasks by category, 工作→运动→生活→其他→(rest), preserving input order within a group.
    static func grouped(_ tasks: [TodoTask]) -> [(String, [TodoTask])] {
        var buckets: [String: [TodoTask]] = [:]
        var seen: [String] = []
        for t in tasks {
            let c = t.category ?? "其他"
            if buckets[c] == nil { seen.append(c) }
            buckets[c, default: []].append(t)
        }
        let head = (order + ["其他"]).filter { buckets[$0] != nil }
        let tail = seen.filter { !head.contains($0) }
        return (head + tail).map { ($0, buckets[$0]!) }
    }
}

// MARK: - Weather

func weatherInfo(_ code: Int) -> (String, String) {
    switch code {
    case 0: return ("☀️", "晴")
    case 1, 2: return ("🌤", "多云")
    case 3: return ("☁️", "阴")
    case 45, 48: return ("🌫", "雾")
    case 51...57: return ("🌦", "毛毛雨")
    case 61, 63: return ("🌧", "小雨")
    case 65: return ("🌧", "大雨")
    case 66, 67: return ("🌧", "冻雨")
    case 71...77: return ("🌨", "雪")
    case 80, 81: return ("🌦", "阵雨")
    case 82: return ("⛈", "强阵雨")
    case 85, 86: return ("🌨", "阵雪")
    case 95: return ("⛈", "雷暴")
    case 96, 99: return ("⛈", "雷暴冰雹")
    default: return ("❓", "—")
    }
}

func isHeavyRain(_ w: DayWeather) -> Bool {
    [65, 82, 95, 96, 99].contains(w.code) || w.precip >= 20.0
}
