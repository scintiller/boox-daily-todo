import SwiftUI

@MainActor
final class Store: ObservableObject {
    private let repo = Repository()

    @Published var tasks: [TodoTask] = []
    @Published var routines: [Routine] = []
    @Published var logs: [RoutineLog] = []
    @Published var weather: [DayWeather] = []
    @Published var loading = false
    @Published var errorText: String?

    private var timer: Timer?

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { await self?.load() }
        }
    }

    func refresh() {
        Task { await load() }
    }

    private func load() async {
        loading = true
        errorText = nil
        do {
            let since = Cal.string(Cal.add(days: -56, to: Date())) // ~8 weeks
            async let t = repo.getTasks()
            async let r = repo.getRoutines()
            async let l = repo.getLogs(since: since)
            tasks = try await t
            routines = try await r
            logs = try await l
        } catch {
            errorText = error.localizedDescription
        }
        loading = false
        // Weather fetched separately so a hiccup never blanks the tasks.
        if let w = try? await repo.getWeather() { weather = w }
    }

    func toggleTask(_ t: TodoTask) {
        Task {
            do {
                try await repo.setTaskDone(id: t.id, done: !t.done)
                await load()
            } catch { errorText = error.localizedDescription }
        }
    }

    func toggleRoutineToday(_ r: Routine) {
        Task {
            let today = Cal.todayString
            let currentlyDone = logs.contains { $0.routineId == r.id && $0.date == today && $0.done }
            do {
                try await repo.logRoutine(routineId: r.id, date: today, done: !currentlyDone)
                await load()
            } catch { errorText = error.localizedDescription }
        }
    }
}
