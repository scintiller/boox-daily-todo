import Foundation

/// Thin Supabase PostgREST client + Open-Meteo weather. Mirrors the Android Repository.
struct Repository {
    private let base = Secrets.supabaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/rest/v1/"
    private let key = Secrets.supabaseAnonKey
    private let decoder = JSONDecoder()

    private func request(_ path: String, method: String, body: Data? = nil, prefer: String? = nil) -> URLRequest {
        var req = URLRequest(url: URL(string: base + path)!)
        req.httpMethod = method
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let prefer { req.setValue(prefer, forHTTPHeaderField: "Prefer") }
        req.httpBody = body
        return req
    }

    @discardableResult
    private func send(_ req: URLRequest) async throws -> Data {
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(code) else {
            throw NSError(domain: "supabase", code: code,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(code): \(String(data: data, encoding: .utf8) ?? "")"])
        }
        return data
    }

    // MARK: Tasks

    func getTasks() async throws -> [TodoTask] {
        let cutoff = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3 * 24 * 3600))
        let path = "tasks?select=*&or=(done.is.false,completed_at.gte.\(cutoff))&order=due_date.asc.nullslast,created_at.asc"
        let data = try await send(request(path, method: "GET"))
        return try decoder.decode([TodoTask].self, from: data)
    }

    func setTaskDone(id: String, done: Bool) async throws {
        var body: [String: Any] = ["done": done]
        body["completed_at"] = done ? ISO8601DateFormatter().string(from: Date()) : NSNull()
        let data = try JSONSerialization.data(withJSONObject: body)
        try await send(request("tasks?id=eq.\(id)", method: "PATCH", body: data, prefer: "return=minimal"))
    }

    func setTaskMemo(id: String, memo: Bool) async throws {
        let data = try JSONSerialization.data(withJSONObject: ["memo": memo])
        try await send(request("tasks?id=eq.\(id)", method: "PATCH", body: data, prefer: "return=minimal"))
    }

    func deleteTask(id: String) async throws {
        try await send(request("tasks?id=eq.\(id)", method: "DELETE", prefer: "return=minimal"))
    }

    func setTaskSection(id: String, section: String) async throws {
        let data = try JSONSerialization.data(withJSONObject: ["work_section": section])
        try await send(request("tasks?id=eq.\(id)", method: "PATCH", body: data, prefer: "return=minimal"))
    }

    func updateTask(id: String, title: String, category: String?, workSection: String?,
                    dueDate: String?, memo: Bool) async throws {
        var body: [String: Any] = ["title": title, "memo": memo]
        body["category"] = category ?? NSNull()
        body["work_section"] = workSection ?? NSNull()
        body["due_date"] = (dueDate?.isEmpty == false) ? dueDate! : NSNull()
        let data = try JSONSerialization.data(withJSONObject: body)
        try await send(request("tasks?id=eq.\(id)", method: "PATCH", body: data, prefer: "return=minimal"))
    }

    func moveTaskToToday(id: String) async throws {
        // un-memo and drop any future due date so it surfaces in 今日
        let data = try JSONSerialization.data(withJSONObject: ["memo": false, "due_date": NSNull()])
        try await send(request("tasks?id=eq.\(id)", method: "PATCH", body: data, prefer: "return=minimal"))
    }

    // MARK: Routines

    func getRoutines() async throws -> [Routine] {
        let data = try await send(request("routines?select=*&active=is.true&order=created_at.asc", method: "GET"))
        return try decoder.decode([Routine].self, from: data)
    }

    func getLogs(since date: String) async throws -> [RoutineLog] {
        let data = try await send(request("routine_logs?select=*&date=gte.\(date)", method: "GET"))
        return try decoder.decode([RoutineLog].self, from: data)
    }

    func logRoutine(routineId: String, date: String, done: Bool) async throws {
        if done {
            let data = try JSONSerialization.data(withJSONObject: ["routine_id": routineId, "date": date, "done": true])
            try await send(request("routine_logs?on_conflict=routine_id,date", method: "POST",
                                   body: data, prefer: "resolution=merge-duplicates,return=minimal"))
        } else {
            try await send(request("routine_logs?routine_id=eq.\(routineId)&date=eq.\(date)", method: "DELETE"))
        }
    }

    // MARK: Focus sessions (pomodoro)

    func getFocusSessions(sinceDays: Int) async throws -> [FocusSession] {
        let cutoff = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-Double(sinceDays) * 86400))
        let path = "focus_sessions?select=*&ended_at=gte.\(cutoff)&order=ended_at.desc"
        let data = try await send(request(path, method: "GET"))
        return try decoder.decode([FocusSession].self, from: data)
    }

    func logFocusSession(phase: String, minutes: Int) async throws {
        let data = try JSONSerialization.data(withJSONObject: ["phase": phase, "minutes": minutes])
        try await send(request("focus_sessions", method: "POST", body: data, prefer: "return=minimal"))
    }

    // MARK: Weather (Open-Meteo, no key, Gilbert AZ)

    func getWeather() async throws -> [DayWeather] {
        let url = URL(string: "https://api.open-meteo.com/v1/forecast"
            + "?latitude=33.3528&longitude=-111.789"
            + "&current=temperature_2m"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max"
            + "&timezone=America%2FPhoenix&forecast_days=3"
            + "&temperature_unit=celsius&precipitation_unit=mm")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let resp = try JSONDecoder().decode(WeatherResponse.self, from: data)
        let cur = resp.current?.temperature_2m
        let d = resp.daily
        return (0..<d.time.count).map { i in
            DayWeather(
                date: d.time[i],
                code: d.weather_code[i],
                tMax: Int(d.temperature_2m_max[i].rounded()),
                tMin: Int(d.temperature_2m_min[i].rounded()),
                precip: d.precipitation_sum[i],
                precipProb: d.precipitation_probability_max[i] ?? 0,
                currentTemp: i == 0 ? cur.map { Int($0.rounded()) } : nil
            )
        }
    }
}
