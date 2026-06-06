import SwiftUI
import UserNotifications

@MainActor
final class Pomodoro: ObservableObject {
    enum Phase { case work, rest }

    @Published var phase: Phase = .work
    @Published var running = false
    @Published var remaining = 45 * 60

    var workMins = 45
    var restMins = 15

    private var endDate: Date?
    private var timer: Timer?

    var label: String {
        let r = max(0, remaining)
        return String(format: "%02d:%02d", r / 60, r % 60)
    }
    var phaseLabel: String { phase == .work ? "专注" : "休息" }
    var idle: Bool { !running && phase == .work && remaining == workMins * 60 }

    func toggle() { running ? pause() : start() }

    func start() {
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

    func reset() {
        pause()
        phase = .work
        remaining = workMins * 60
    }

    func skip() { advance() }

    private func tick() {
        guard running, let end = endDate else { return }
        let r = Int(end.timeIntervalSinceNow.rounded())
        if r <= 0 { advance() } else { remaining = r }
    }

    private func advance() {
        phase = (phase == .work) ? .rest : .work
        remaining = (phase == .work ? workMins : restMins) * 60
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if running {
            endDate = Date().addingTimeInterval(Double(remaining))
            scheduleNotification()
        }
    }

    // MARK: notifications (so it alerts even if you put the iPad down)
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
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Always-visible compact header (tap to expand/collapse)
            HStack(spacing: 8) {
                Text("🍅 番茄钟").font(.subheadline).bold()
                if !pomo.idle {
                    Text("·").foregroundColor(.secondary)
                    Text(pomo.phaseLabel).font(.subheadline)
                        .foregroundColor(pomo.phase == .work ? .red : .green)
                    Text(pomo.label).font(.subheadline).monospacedDigit().foregroundColor(.secondary)
                }
                Spacer()
                if !pomo.idle && !expanded {
                    Button { pomo.toggle() } label: {
                        Image(systemName: pomo.running ? "pause.fill" : "play.fill")
                    }.buttonStyle(.plain)
                }
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } }

            if expanded {
                VStack(spacing: 12) {
                    Text(pomo.label)
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(pomo.phase == .work ? .red : .green)
                    Text(pomo.phase == .work ? "专注 \(pomo.workMins) 分钟" : "休息 \(pomo.restMins) 分钟")
                        .font(.subheadline).foregroundColor(.secondary)
                    HStack(spacing: 36) {
                        Button { pomo.reset() } label: {
                            Image(systemName: "arrow.counterclockwise").font(.title2)
                        }.buttonStyle(.plain).foregroundColor(.secondary)
                        Button { pomo.toggle() } label: {
                            Image(systemName: pomo.running ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 60))
                        }.buttonStyle(.plain).foregroundColor(pomo.phase == .work ? .red : .green)
                        Button { pomo.skip() } label: {
                            Image(systemName: "forward.end.fill").font(.title2)
                        }.buttonStyle(.plain).foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 16).padding(.top, 4)
            }
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
        .padding(.horizontal).padding(.top, 8)
    }
}
