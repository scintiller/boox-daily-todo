import SwiftUI

@MainActor
final class Store: ObservableObject {
    private let repo = Repository()

    @Published var tasks: [TodoTask] = []
    @Published var routines: [Routine] = []
    @Published var logs: [RoutineLog] = []
    @Published var weather: [DayWeather] = []
    @Published var goals: [Goal] = []
    @Published var focusSessions: [FocusSession] = []
    @Published var loading = false
    @Published var errorText: String?
    @Published var completingIds: Set<String> = []   // struck-through, mid-celebration
    @Published var celebration: CelebrationEvent?
    private var celebCounter = 0
    @Published var toast: String?

    private var timer: Timer?

    func start() {
        if ProcessInfo.processInfo.arguments.contains("-MockData") {
            loadMock(); return   // offline sample data for UI screenshots
        }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { await self?.load() }
        }
    }

    private func loadMock() {
        let now = ISO8601DateFormatter().string(from: Date())
        func iso(_ minAgo: Int) -> String {
            ISO8601DateFormatter().string(from: Date().addingTimeInterval(-Double(minAgo) * 60))
        }
        func t(_ id: String, _ title: String, _ cat: String, _ sec: String? = nil,
               done: Bool = false, comp: String? = nil) -> TodoTask {
            TodoTask(id: id, title: title, notes: nil, done: done, memo: false,
                     category: cat, workSection: sec, dueDate: nil, createdAt: now, completedAt: comp)
        }
        tasks = [
            t("1", "升级到 4.7 模型，加好 monitor", "工作", "focus"),
            t("2", "Debugmate latency / job run dashboard", "工作", "focus"),
            t("3", "再问两个人 paper 的事", "工作", "focus"),
            t("4", "onboard harmony & hatch", "工作", "feature"),
            t("5", "fix sub agent error issue", "工作", "feature"),
            t("6", "hide debugmate on QA bug tasks", "工作", "feature"),
            t("7", "买菜 🥬", "生活"),
            t("8", "预约牙医", "生活"),
            t("c1", "回复 PR review", "工作", "focus", done: true, comp: iso(95)),
            t("c2", "晨会站会", "工作", "focus", done: true, comp: iso(280)),
        ]
        let allDays = [1, 2, 3, 4, 5, 6, 7]
        routines = [
            Routine(id: "r1", name: "网球", icon: "🎾", weekdays: allDays, active: true, category: "运动", createdAt: now),
            Routine(id: "r2", name: "复健", icon: "💪", weekdays: allDays, active: true, category: "运动", createdAt: now),
            Routine(id: "r3", name: "游泳", icon: "🏊", weekdays: allDays, active: true, category: "运动", createdAt: now),
        ]
        func mkLogs(_ rid: String, _ offsets: [Int]) -> [RoutineLog] {
            offsets.map { RoutineLog(id: nil, routineId: rid,
                                     date: Cal.string(Cal.add(days: -$0, to: Date())), done: true) }
        }
        logs = mkLogs("r1", [0, 2, 5, 9, 12, 16, 19, 23, 27, 33, 40])
             + mkLogs("r2", [1, 3, 6, 8, 13, 15, 20, 28, 35])
             + mkLogs("r3", [0, 4, 7, 14, 21, 26, 38])
        weather = [DayWeather(date: Cal.todayString, code: 0, tMax: 33, tMin: 20,
                              precip: 0, precipProb: 0, currentTemp: 29)]
        goals = [
            Goal(id: "g1", title: "提交 NIW assessment", period: "week", done: false),
            Goal(id: "g2", title: "问黄老师是否有科研机会", period: "week", done: false),
            Goal(id: "g3", title: "改好简历，添加GitHub项目+个人主页，投3份简历", period: "week", done: false),
        ]
        let f: [(Int, Int)] = [(0, 45), (0, 45), (0, 25), (1, 45), (1, 45), (2, 45), (3, 25), (3, 45),
                               (4, 45), (5, 45), (6, 45), (7, 45), (8, 25), (10, 45), (11, 45), (13, 45),
                               (14, 45), (16, 45), (18, 45), (20, 45), (21, 45), (24, 45), (27, 45), (33, 45)]
        focusSessions = f.enumerated().map { i, e in
            FocusSession(id: "f\(i)", phase: "work", minutes: e.1,
                         endedAt: ISO8601DateFormatter().string(
                            from: Date().addingTimeInterval(-Double(e.0) * 86400 - Double(i) * 600)))
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
            async let f = repo.getFocusSessions(sinceDays: 90)
            async let g = repo.getGoals()
            tasks = try await t
            routines = try await r
            logs = try await l
            focusSessions = try await f
            goals = try await g
        } catch {
            errorText = error.localizedDescription
        }
        loading = false
        // Weather fetched separately so a hiccup never blanks the tasks.
        if let w = try? await repo.getWeather() { weather = w }
    }

    func toggleGoal(_ g: Goal) {
        if let i = goals.firstIndex(where: { $0.id == g.id }), !g.done {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { goals[i].done = true }
        }
        Task {
            do { try await repo.setGoalDone(id: g.id, done: !g.done); await load() }
            catch { errorText = error.localizedDescription; await load() }
        }
    }

    func addGoal(title: String, targetDate: String?) {
        Task {
            do { try await repo.addGoal(title: title, targetDate: targetDate); await load() }
            catch { errorText = error.localizedDescription }
        }
    }

    func updateGoal(_ g: Goal, title: String, targetDate: String?) {
        if let i = goals.firstIndex(where: { $0.id == g.id }) {
            goals[i].title = title; goals[i].targetDate = targetDate
        }
        Task {
            do { try await repo.updateGoal(id: g.id, title: title, targetDate: targetDate); await load() }
            catch { errorText = error.localizedDescription; await load() }
        }
    }

    func deleteGoal(_ g: Goal) {
        withAnimation { goals.removeAll { $0.id == g.id } }
        Task {
            do { try await repo.deleteGoal(id: g.id); await load() }
            catch { errorText = error.localizedDescription; await load() }
        }
    }

    /// Drag into P1/P2: set work_section=feature and add/remove the 🌟 priority marker in the title.
    func setFeaturePriority(_ t: TodoTask, p1: Bool) {
        var title = t.title
        let hasStar = title.contains("🌟")
        if p1 && !hasStar {
            title = "🌟 " + title
        } else if !p1 && hasStar {
            title = title.replacingOccurrences(of: "🌟", with: "").trimmingCharacters(in: .whitespaces)
        }
        if let i = tasks.firstIndex(where: { $0.id == t.id }) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                tasks[i].workSection = "feature"; tasks[i].title = title
            }
        }
        let newTitle = title
        Task {
            do {
                try await repo.setTaskTitleSection(id: t.id, title: newTitle, section: "feature")
                showToast(p1 ? "已设为 P1 🌟" : "已设为 P2")
                await load()
            } catch { errorText = error.localizedDescription; await load() }
        }
    }

    func addTask(title: String, category: String, section: String?, dueDate: String?, memo: Bool) {
        Task {
            do {
                try await repo.addTask(title: title, category: category,
                                       section: category == "工作" ? section : nil,
                                       dueDate: dueDate, memo: memo)
                showToast("已添加 ✅")
                await load()
            } catch { errorText = error.localizedDescription }
        }
    }

    func logFocus(phase: String, minutes: Int) {
        Task {
            do { try await repo.logFocusSession(phase: phase, minutes: minutes); await load() }
            catch { errorText = error.localizedDescription }
        }
    }

    func toggleTask(_ t: TodoTask) {
        if !t.done {
            // Completing: 1) strike the line through in place, 2) celebrate,
            //             3) after a beat, move it into 已完成.
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            completingIds.insert(t.id)
            celebCounter += 1
            celebration = CelebrationEvent(id: celebCounter, effect: Int.random(in: 0..<10))
            let id = t.id
            Task {
                try? await Task.sleep(nanoseconds: 850_000_000)
                completingIds.remove(id)
                if let i = tasks.firstIndex(where: { $0.id == id }) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
                        tasks[i].done = true
                        tasks[i].completedAt = ISO8601DateFormatter().string(from: Date())
                    }
                }
                do { try await repo.setTaskDone(id: id, done: true); await load() }
                catch { errorText = error.localizedDescription; await load() }
            }
        } else {
            // Un-complete (tapped in 已完成): revert immediately.
            if let i = tasks.firstIndex(where: { $0.id == t.id }) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
                    tasks[i].done = false
                    tasks[i].completedAt = nil
                }
            }
            Task {
                do { try await repo.setTaskDone(id: t.id, done: false); await load() }
                catch { errorText = error.localizedDescription; await load() }
            }
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
                // re-assert the optimistic value in case a stale concurrent reload clobbered it
                if let i = tasks.firstIndex(where: { $0.id == t.id }), tasks[i].workSection != section {
                    tasks[i].workSection = section
                }
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

    func updateTask(_ edited: TodoTask) {
        if let i = tasks.firstIndex(where: { $0.id == edited.id }) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { tasks[i] = edited }
        }
        Task {
            do {
                try await repo.updateTask(id: edited.id, title: edited.title, category: edited.category,
                                          workSection: edited.workSection, dueDate: edited.dueDate, memo: edited.memo)
                showToast("已更新 ✏️")
                await load()
            } catch { errorText = error.localizedDescription; await load() }
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
