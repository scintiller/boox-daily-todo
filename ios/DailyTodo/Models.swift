import Foundation

// Named TodoTask (not Task) to avoid clashing with Swift Concurrency's Task.
struct TodoTask: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var notes: String?
    var done: Bool
    var memo: Bool
    var category: String?
    var workSection: String?     // 工作 only: focus | comms | feature
    var dueDate: String?
    var createdAt: String?
    var completedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, notes, done, memo, category
        case workSection = "work_section"
        case dueDate = "due_date"
        case createdAt = "created_at"
        case completedAt = "completed_at"
    }
}

struct Routine: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var icon: String?
    var weekdays: [Int]          // ISO weekday 1=Mon..7=Sun
    var active: Bool
    var category: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, icon, weekdays, active, category
        case createdAt = "created_at"
    }
}

struct RoutineLog: Codable, Identifiable, Equatable {
    var id: String?
    let routineId: String
    let date: String             // yyyy-MM-dd
    var done: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case routineId = "routine_id"
        case date, done
    }
}

struct Goal: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var period: String = "week"
    var done: Bool
    var targetDate: String?      // 预期完成时间 YYYY-MM-DD

    enum CodingKeys: String, CodingKey {
        case id, title, period, done
        case targetDate = "target_date"
    }
}

struct FocusSession: Codable, Identifiable, Equatable {
    let id: String
    let phase: String            // work | rest
    let minutes: Int
    let endedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, phase, minutes
        case endedAt = "ended_at"
    }
}

struct DayWeather: Equatable, Identifiable {
    var id: String { date }
    let date: String
    let code: Int                // WMO code
    let tMax: Int                // °C
    let tMin: Int                // °C
    let precip: Double           // mm
    let precipProb: Int          // %
    var currentTemp: Int? = nil  // °C, today only
}

// MARK: - Open-Meteo response

struct WeatherResponse: Codable {
    let daily: WeatherDaily
    let current: WeatherCurrent?
}

struct WeatherCurrent: Codable {
    let temperature_2m: Double?
}

struct WeatherDaily: Codable {
    let time: [String]
    let weather_code: [Int]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
    let precipitation_sum: [Double]
    let precipitation_probability_max: [Int?]
}
