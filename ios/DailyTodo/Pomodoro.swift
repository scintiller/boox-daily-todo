import SwiftUI
import UserNotifications

@MainActor
final class Pomodoro: ObservableObject {
    enum Phase: Hashable { case work, rest }

    @Published var phase: Phase = .work {
        didSet {
            remaining = duration(phase) * 60
            if running {
                endDate = Date().addingTimeInterval(Double(remaining))
                scheduleNotification()
            }
        }
    }
    @Published var running = false
    @Published var remaining = 45 * 60
    /// True right after a FOCUS phase finishes: stay on 专注, offer 延长 / 开始休息.
    @Published var awaitingChoice = false

    @Published var workMins: Int {
        didSet {
            UserDefaults.standard.set(workMins, forKey: "pomoWork")
            if !running, phase == .work { remaining = workMins * 60 }
        }
    }
    @Published var restMins: Int {
        didSet {
            UserDefaults.standard.set(restMins, forKey: "pomoRest")
            if !running, phase == .rest { remaining = restMins * 60 }
        }
    }

    private var endDate: Date?
    private var timer: Timer?

    /// Called when a phase finishes naturally (full duration). (phase, minutes)
    var onComplete: ((Phase, Int) -> Void)?

    init() {
        workMins = UserDefaults.standard.object(forKey: "pomoWork") as? Int ?? 45
        restMins = UserDefaults.standard.object(forKey: "pomoRest") as? Int ?? 10
        remaining = (UserDefaults.standard.object(forKey: "pomoWork") as? Int ?? 45) * 60
    }

    func duration(_ p: Phase) -> Int { p == .work ? workMins : restMins }

    var label: String {
        let r = max(0, remaining)
        return String(format: "%02d:%02d", r / 60, r % 60)
    }
    var phaseLabel: String { phase == .work ? "专注" : "休息" }
    /// At rest = not running and sitting at the full duration (nothing in progress).
    var idle: Bool { !running && remaining == duration(phase) * 60 }

    func toggle() { running ? pause() : start() }

    func start() {
        awaitingChoice = false
        running = true
        endDate = Date().addingTimeInterval(Double(remaining))
        requestAuthOnce()
        scheduleNotification()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func pause() {
        running = false
        timer?.invalidate(); timer = nil
        endDate = nil
        cancelNotification()
    }

    func reset() { pause(); awaitingChoice = false; phase = .work; remaining = workMins * 60 }

    /// End the current phase early. Records the session at its ACTUAL elapsed
    /// length (e.g. skip a 45-min focus with 2 min left → logs 43 min), then
    /// switches to the next phase (paused, waiting for a tap).
    func skip() {
        let elapsedMin = Int((Double(duration(phase) * 60 - remaining) / 60.0).rounded())
        if elapsedMin >= 1 { onComplete?(phase, elapsedMin) }
        advance()
    }

    /// 专注结束后选择延长（继续专注 N 分钟）。
    func extend(_ mins: Int = 10) {
        awaitingChoice = false
        remaining = mins * 60
        start()
    }

    /// 专注结束后选择去休息（停住，等点开始）。
    func chooseRest() {
        awaitingChoice = false
        phase = .rest
    }

    private func tick() {
        guard running, let end = endDate else { return }
        let r = Int(end.timeIntervalSinceNow.rounded())
        if r <= 0 {
            Chime.shared.play()                   // 7-second end-of-session sound
            onComplete?(phase, duration(phase))   // record the completed session
            if phase == .work { finishWork() } else { advance() }
        } else { remaining = r }
    }

    /// Focus finished: STAY on 专注, wait for the user to extend or start a break.
    private func finishWork() {
        running = false
        timer?.invalidate(); timer = nil
        endDate = nil
        remaining = 0
        awaitingChoice = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func advance() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        awaitingChoice = false
        // Switch to the next phase but STOP — wait for the user to tap start.
        running = false
        timer?.invalidate(); timer = nil
        endDate = nil
        phase = (phase == .work) ? .rest : .work   // didSet: remaining = new duration (not running → no reschedule)
    }

    // MARK: notifications
    private func requestAuthOnce() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    private func scheduleNotification() {
        guard running, remaining > 0 else { return }
        let c = UNMutableNotificationContent()
        c.title = "🍅 番茄钟"
        c.body = phase == .work ? "专注结束，休息 \(restMins) 分钟 ☕️" : "休息结束，开始专注 💪"
        c.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(remaining), repeats: false)
        let req = UNNotificationRequest(identifier: "pomo", content: c, trigger: trigger)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["pomo"])
        center.add(req)
    }
    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["pomo"])
    }
}

struct PomodoroBar: View {
    @ObservedObject var pomo: Pomodoro
    @State private var expanded = ProcessInfo.processInfo.arguments.contains("-PomoOpen")

    private var color: Color { pomo.phase == .work ? .indigo : .green }

    var body: some View {
        VStack(spacing: 0) {
            header
            if expanded {
                VStack(spacing: 14) {
                    if !pomo.awaitingChoice {
                        Picker("", selection: phaseBinding) {
                            Text("专注").tag(Pomodoro.Phase.work)
                            Text("休息").tag(Pomodoro.Phase.rest)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 260)
                    }

                    if pomo.awaitingChoice {
                        // Focus finished — stay on 专注, offer to extend or take a break
                        Text("专注结束 🎉").font(.title2).bold().foregroundColor(color)
                        HStack(spacing: 12) {
                            Button { pomo.extend(10) } label: {
                                Label("延长 10 分钟", systemImage: "plus")
                                    .font(.subheadline).fontWeight(.semibold).foregroundColor(color)
                                    .padding(.horizontal, 18).padding(.vertical, 12)
                                    .background(Capsule().strokeBorder(color, lineWidth: 1.5))
                            }.buttonStyle(.plain)
                            Button { pomo.chooseRest() } label: {
                                Label("开始休息", systemImage: "cup.and.saucer.fill")
                                    .font(.subheadline).fontWeight(.semibold).foregroundColor(.white)
                                    .padding(.horizontal, 18).padding(.vertical, 12)
                                    .background(Capsule().fill(Color.green))
                            }.buttonStyle(.plain)
                        }
                    } else if pomo.idle {
                        // quick presets
                        HStack(spacing: 10) {
                            ForEach(presets, id: \.self) { m in
                                let sel = (pomo.phase == .work ? pomo.workMins : pomo.restMins) == m
                                Button { setDuration(m) } label: {
                                    Text("\(m)").font(.subheadline).fontWeight(.semibold)
                                        .foregroundColor(sel ? .white : color)
                                        .frame(width: 48, height: 34)
                                        .background(Capsule().fill(sel ? color : color.opacity(0.12)))
                                }.buttonStyle(.plain)
                            }
                            Text("分钟").font(.caption).foregroundColor(.secondary)
                        }
                        // Apple-timer-style wheel for fine control
                        Picker("", selection: durationBinding) {
                            ForEach(1...90, id: \.self) { Text("\($0) 分钟").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 110)
                        .clipped()
                        Button { pomo.start() } label: {
                            Label("开始\(pomo.phaseLabel)", systemImage: "play.fill")
                                .font(.headline).foregroundColor(.white)
                                .padding(.horizontal, 30).padding(.vertical, 12)
                                .background(Capsule().fill(color))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(pomo.label)
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .monospacedDigit().foregroundColor(color)
                        HStack(spacing: 36) {
                            ctrl("arrow.counterclockwise") { pomo.reset() }
                            Button { pomo.toggle() } label: {
                                Image(systemName: pomo.running ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 60))
                            }.buttonStyle(.plain).foregroundColor(color)
                            ctrl("forward.end.fill") { pomo.skip() }
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 16).padding(.top, 2)
            }
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
        .padding(.horizontal).padding(.top, 8)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("🍅 番茄钟").font(.subheadline).bold()
            if pomo.awaitingChoice {
                Text("·").foregroundColor(.secondary)
                Text("专注结束 🎉").font(.subheadline).foregroundColor(color)
            } else if !pomo.idle {
                Text("·").foregroundColor(.secondary)
                Text(pomo.phaseLabel).font(.subheadline).foregroundColor(color)
                Text(pomo.label).font(.subheadline).monospacedDigit().foregroundColor(.secondary)
            }
            Spacer()
            if !pomo.idle && !pomo.awaitingChoice && !expanded {
                Button { pomo.toggle() } label: {
                    Image(systemName: pomo.running ? "pause.fill" : "play.fill")
                }.buttonStyle(.plain).foregroundColor(color)
            }
            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } }
    }

    private var presets: [Int] { pomo.phase == .work ? [45, 30, 15] : [15, 10, 5] }
    private func setDuration(_ m: Int) {
        if pomo.phase == .work { pomo.workMins = m } else { pomo.restMins = m }
    }
    private var phaseBinding: Binding<Pomodoro.Phase> {
        Binding(get: { pomo.phase }, set: { pomo.awaitingChoice = false; pomo.phase = $0 })
    }
    private var durationBinding: Binding<Int> {
        Binding(get: { pomo.phase == .work ? pomo.workMins : pomo.restMins },
                set: { if pomo.phase == .work { pomo.workMins = $0 } else { pomo.restMins = $0 } })
    }
    private func ctrl(_ name: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: name).font(.title2) }
            .buttonStyle(.plain).foregroundColor(.secondary)
    }
}
