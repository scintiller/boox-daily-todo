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
    @Published var toast: String?

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
        let newDone = !t.done
        // Optimistic + animated: the row springs from 待办 into 已完成 right away.
        if let i = tasks.firstIndex(where: { $0.id == t.id }) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
                tasks[i].done = newDone
                tasks[i].completedAt = newDone ? ISO8601DateFormatter().string(from: Date()) : nil
            }
        }
        if newDone {
            UINotificationFeedbackGenerator().notificationOccurred(.success) // no-op on iPad, fires on iPhone
        }
        Task {
            do {
                try await repo.setTaskDone(id: t.id, done: newDone)
                await load()
            } catch { errorText = error.localizedDescription; await load() }
        }
    }

    func setTaskSection(_ t: TodoTask, _ section: String) {
        if let i = tasks.firstIndex(where: { $0.id == t.id }) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                tasks[i].workSection = section
            }
        }
        Task {
            do {
                try await repo.setTaskSection(id: t.id, section: section)
                showToast("已移到 \(WorkSections.display(section))")
                await load()
            } catch { errorText = error.localizedDescription; await load() }
        }
    }

    func moveToMemo(_ t: TodoTask) {
        // optimistic: drop it from the today list immediately for a snappy swipe
        tasks.removeAll { $0.id == t.id }
        Task {
            do {
                try await repo.setTaskMemo(id: t.id, memo: true)
                showToast("已移到备忘录 📝")
                await load()
            } catch {
                errorText = error.localizedDescription
                await load() // restore on failure
            }
        }
    }

    func moveToToday(_ t: TodoTask) {
        tasks.removeAll { $0.id == t.id }
        Task {
            do {
                try await repo.moveTaskToToday(id: t.id)
                showToast("已转为今日待办 ✅")
                await load()
            } catch {
                errorText = error.localizedDescription
                await load()
            }
        }
    }

    func deleteTask(_ t: TodoTask) {
        tasks.removeAll { $0.id == t.id }
        Task {
            do {
                try await repo.deleteTask(id: t.id)
                showToast("已删除 🗑️")
                await load()
            } catch {
                errorText = error.localizedDescription
                await load()
            }
        }
    }

    private func showToast(_ s: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { toast = s }
        Task {
            try? await Task.sleep(nanoseconds: 1_900_000_000)
            withAnimation(.easeOut(duration: 0.3)) { toast = nil }
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
