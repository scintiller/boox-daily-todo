// PlatterView.swift — the "四格拼盘" focus ritual UI: a bowl split into 4 quadrants by two
// crossed chopsticks. Drives the EXISTING shared Pomodoro (indigo focus / green rest); the
// chopstick gaps between quadrants are the rests. Tap a quadrant to plan/check its items;
// 顺延 carries unchecked items to the next quadrant. Local persistence via PlatterStore.
import SwiftUI

private let FOCUS = Color.indigo
private let REST = Color.green

// MARK: - Bowl geometry (SwiftUI screen angles: 0°=right, 90°=down, clockwise)

/// A donut wedge for quadrant `index`. 0=top, 1=right, 2=bottom, 3=left.
/// Each is a 72° band (90° sector minus an 18° chopstick gap), between the X at 45°/135°/….
struct QuadrantWedge: Shape {
    let index: Int
    // Full 90° sectors that TILE the circle and meet exactly on the diagonals (45/135/225/315);
    // the two chopsticks are drawn on top of those seams, so there's no white gap.
    // Centers at 270/0/90/180 = up/right/down/left.
    static let spans: [(Double, Double)] = [(225, 315), (315, 405), (45, 135), (135, 225)]

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let rO = min(rect.width, rect.height) / 2
        let rI = rO * 0.22
        let (s, e) = Self.spans[index]
        var p = Path()
        p.addArc(center: c, radius: rO, startAngle: .degrees(s), endAngle: .degrees(e), clockwise: false)
        p.addArc(center: c, radius: rI, startAngle: .degrees(e), endAngle: .degrees(s), clockwise: true)
        p.closeSubpath()
        return p
    }
}

/// Diagonal hatch lines (for a 顺延'd quadrant), clipped to its wedge by the caller.
struct Hatch: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let step: CGFloat = 9
        var x = -rect.height
        while x < rect.width {
            p.move(to: CGPoint(x: x, y: 0))
            p.addLine(to: CGPoint(x: x + rect.height, y: rect.height))
            x += step
        }
        return p
    }
}

// MARK: - The bowl

enum QuadState { case pending, current, done, carried }

struct BowlView: View {
    let platter: Platter
    @ObservedObject var pomo: Pomodoro
    let resting: Bool
    let selected: Int
    let onTap: (Int) -> Void
    let onCenter: () -> Void

    private var centerTint: Color { pomo.phase == .rest ? REST : FOCUS }

    @ViewBuilder private func centerLabel(_ side: CGFloat) -> some View {
        if pomo.awaitingChoice {
            VStack(spacing: 1) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: side * 0.072))
                Text("完成").font(.system(size: side * 0.040, weight: .bold))
            }.foregroundColor(FOCUS)
        } else if pomo.running {
            Text(pomo.label)
                .font(.system(size: side * 0.058, weight: .bold, design: .rounded))
                .monospacedDigit().foregroundColor(centerTint)
        } else {
            let rest = pomo.phase == .rest
            VStack(spacing: 1) {
                Image(systemName: "play.fill").font(.system(size: side * 0.064))
                Text(rest ? "休息" : (pomo.idle ? "开始" : "继续"))
                    .font(.system(size: side * 0.042, weight: .bold))
            }.foregroundColor(rest ? REST : FOCUS)
        }
    }

    private func state(_ q: Quadrant) -> QuadState {
        if q.carried { return .carried }                                   // 顺延'd → hatched
        if q.allDone || q.index < platter.current { return .done }         // finished OR passed (behind cursor)
        if q.index == platter.current { return .current }
        return .pending
    }
    private func fill(_ s: QuadState) -> Color {
        switch s {
        case .pending: return FOCUS.opacity(0.10)
        case .current: return Color.orange.opacity(0.92)   // 进行中 — a distinct warm color
        case .done:    return FOCUS.opacity(0.80)
        case .carried: return Color(.systemGray4)
        }
    }
    private func numberColor(_ s: QuadState) -> Color {
        switch s { case .current, .done: return .white; default: return .secondary }
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().stroke(Color(.systemGray3), lineWidth: 2)

                ForEach(platter.quadrants) { q in
                    let st = state(q)
                    QuadrantWedge(index: q.index)
                        .fill(fill(st))
                        .overlay {
                            if st == .carried {
                                Hatch().stroke(Color.white.opacity(0.55), lineWidth: 1.5)
                                    .clipShape(QuadrantWedge(index: q.index))
                            }
                        }
                        .overlay {   // only the tapped/selected quadrant gets an outline
                            if q.index == selected {
                                QuadrantWedge(index: q.index).stroke(FOCUS, lineWidth: 3)
                            }
                        }
                        .contentShape(QuadrantWedge(index: q.index))
                        .onTapGesture { onTap(q.index) }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: platter)

                // number labels
                ForEach(platter.quadrants) { q in
                    Text("\(q.index + 1)")
                        .font(.system(size: side * 0.055, weight: .bold, design: .rounded))
                        .foregroundColor(numberColor(state(q)))
                        .position(labelPos(q.index, side))
                        .allowsHitTesting(false)
                }

                // two crossed chopsticks (rest zones tint green while resting)
                chopstick(side: side, deg: 45)
                chopstick(side: side, deg: 135)

                // center hub → start / pause / countdown button
                Button(action: onCenter) {
                    Circle().fill(Color(.secondarySystemBackground))
                        .overlay(Circle().stroke(centerTint.opacity(0.55), lineWidth: 2))
                        .overlay { centerLabel(side) }
                }
                .buttonStyle(.plain)
                .frame(width: side * 0.26, height: side * 0.26)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func labelPos(_ i: Int, _ side: CGFloat) -> CGPoint {
        let angles: [CGFloat] = [270, 0, 90, 180]
        let a = angles[i] * .pi / 180
        let r = side * 0.31
        return CGPoint(x: side / 2 + cos(a) * r, y: side / 2 + sin(a) * r)
    }

    private func chopstick(side: CGFloat, deg: Double) -> some View {
        Capsule()
            .fill(resting ? REST : Color(.systemGray3))
            .frame(width: side * 1.0, height: side * 0.028)
            .rotationEffect(.degrees(deg))
            .animation(.easeInOut(duration: 0.3), value: resting)
            .allowsHitTesting(false)
    }
}

// MARK: - The sheet

struct PlatterView: View {
    @ObservedObject var platterStore: PlatterStore
    @ObservedObject var pomo: Pomodoro
    @ObservedObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var selected = 0
    @State private var newItem = ""
    @State private var showReset = false

    private var platter: Platter { platterStore.platter }
    private var q: Quadrant { platter.quadrants[min(max(selected, 0), 3)] }
    private var resting: Bool { pomo.phase == .rest && pomo.running }

    /// Strip the P1 🌟 marker so the platter item reads cleanly.
    private func candTitle(_ t: TodoTask) -> String {
        t.title.replacingOccurrences(of: "🌟 ", with: "").trimmingCharacters(in: .whitespaces)
    }
    /// Candidate tasks to one-tap into a quadrant: your 工作 专注-section items + all 科研 tasks,
    /// minus anything already sitting in the platter.
    private var focusCandidates: [TodoTask] {
        let taken = Set(platter.quadrants.flatMap { $0.items.map(\.title) })
        return store.tasks.filter { t in
            guard !t.done, !t.memo else { return false }
            let focus = t.category == "工作" && (t.workSection ?? "") == "focus"
            let research = t.category == "科研"
            return (focus || research) && !taken.contains(candTitle(t))
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                intro
                BowlView(platter: platter, pomo: pomo, resting: resting, selected: selected, onTap: { tapped in
                    // Don't move the panel off a live block — that hides the 完成/顺延 controls
                    // and would let 开始专注 leap the cursor. Browsing while idle/resting is fine.
                    if pomo.phase == .work && (pomo.running || pomo.awaitingChoice) { return }
                    selected = tapped
                }, onCenter: { centerTap() })
                    .frame(height: 300)
                    .padding(.horizontal, 8)
                Text("\(platter.half.label)拼盘 · \(platter.settledCount)/4 格")
                    .font(.caption).foregroundColor(.secondary)
                quadrantPanel
                durationToggles
                footer
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 28)
        }
        .navigationTitle("🍜 四格拼盘")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        .onAppear {
            platterStore.reloadForNow()
            selected = platter.current
        }
        .onChange(of: pomo.awaitingChoice) { awaiting in
            // A focus block just ended → snap the panel back to the quadrant that actually ran,
            // so its 完成/顺延 choice always shows (and can't be hidden by browsing ahead).
            if awaiting { selected = platter.current }
        }
        .onChange(of: scenePhase) { phase in
            // Handle am→pm / midnight rollover while the app was backgrounded — but never mid-run.
            if phase == .active && !pomo.running && !pomo.awaitingChoice {
                platterStore.reloadForNow()
                selected = platterStore.platter.current
            }
        }
        .confirmationDialog("清空这份拼盘、重新规划？", isPresented: $showReset, titleVisibility: .visible) {
            Button("清空重来", role: .destructive) {
                if pomo.running || pomo.awaitingChoice { pomo.reset() }   // don't strand a live timer
                platterStore.reset(); selected = 0
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var intro: some View {
        VStack(spacing: 4) {
            Text("像分四格慢慢喝一碗水那样，把\(platter.half.label)分成四段专注。")
                .font(.footnote).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Text("每格专注 \(platter.focusMins) 分钟 · 筷子处休息 \(platter.restMins) 分钟")
                .font(.caption2).foregroundColor(Color(.tertiaryLabel))
        }
    }

    private var durationToggles: some View {
        VStack(spacing: 8) {
            pickerRow(title: "专注", value: platter.focusMins, options: [45, 60], tint: FOCUS) { platterStore.setFocus($0) }
            pickerRow(title: "休息", value: platter.restMins, options: [5, 15], tint: REST) { platterStore.setRest($0) }
        }
    }

    private func pickerRow(title: String, value: Int, options: [Int], tint: Color, set: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 10) {
            Text(title).font(.subheadline).bold().foregroundColor(.secondary).frame(width: 40, alignment: .leading)
            ForEach(options, id: \.self) { m in
                let on = value == m
                Button { set(m) } label: {
                    Text("\(m) 分").font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(on ? .white : tint)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(Capsule().fill(on ? tint : tint.opacity(0.12)))
                }.buttonStyle(.plain)
            }
        }
    }

    // MARK: current-quadrant panel

    private var quadrantPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("第 \(selected + 1) 格").font(.headline)
                if q.carried { Text("已顺延").font(.caption).foregroundColor(.orange) }
                Spacer()
                Text("\(q.doneCount)/\(q.items.count)").font(.subheadline).foregroundColor(.secondary).monospacedDigit()
            }

            if q.items.isEmpty {
                Text("还没安排 · 在下面加几件这一格要做完的事").font(.caption).foregroundColor(Color(.tertiaryLabel))
            } else {
                ForEach(q.items) { item in itemRow(item) }
            }

            HStack(spacing: 8) {
                TextField("加一件要做的事…", text: $newItem)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addItem)
                Button(action: addItem) {
                    Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(FOCUS)
                }.buttonStyle(.plain).disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !focusCandidates.isEmpty {
                Divider().padding(.vertical, 2)
                Text("从专注 / 科研任务加").font(.caption).foregroundColor(.secondary)
                ForEach(focusCandidates) { t in
                    Button { platterStore.addItem(candTitle(t), to: selected) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle").font(.title3).foregroundColor(FOCUS)
                            Text(candTitle(t)).font(.subheadline).foregroundColor(.primary)
                                .lineLimit(1).truncationMode(.tail)
                            Spacer(minLength: 0)
                        }
                    }.buttonStyle(.plain)
                }
            }

            actionRow
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
    }

    private func itemRow(_ item: PlatterItem) -> some View {
        HStack(spacing: 10) {
            Button { platterStore.toggleItem(item, in: selected) } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundColor(item.done ? FOCUS : .secondary)
            }.buttonStyle(.plain)
            Text(item.title)
                .strikethrough(item.done).foregroundColor(item.done ? .secondary : .primary)
            if let from = item.carriedFrom {
                Text("↩︎\(from + 1)").font(.caption2).bold().foregroundColor(.orange)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Capsule().fill(Color.orange.opacity(0.12)))
            }
            Spacer()
            Button { platterStore.removeItem(item, from: selected) } label: {
                Image(systemName: "xmark").font(.caption).foregroundColor(Color(.tertiaryLabel))
            }.buttonStyle(.plain)
        }
    }

    // Timer-state-driven controls for this quadrant.
    // The bowl-center button owns 开始 / 继续 / 暂停 / 倒计时 / 完成. This row only carries the
    // secondary action for the current state (顺延, or 跳过 while a timer runs). Idle → nothing.
    @ViewBuilder private var actionRow: some View {
        if pomo.awaitingChoice {
            pill("顺延 · 把没做完的挪到下一格", icon: "arrow.turn.down.right", tint: .orange, filled: false) { carryOver() }
                .frame(maxWidth: .infinity)
        } else if pomo.phase == .work && pomo.running {
            pill("跳过这一格", icon: "forward.end.fill", tint: .secondary, filled: false) { pomo.skip() }
                .frame(maxWidth: .infinity)
        } else if pomo.phase == .rest && pomo.running {
            pill("跳过休息", icon: "forward.end.fill", tint: .secondary, filled: false) { pomo.skip() }
                .frame(maxWidth: .infinity)
        }
    }

    private func pill(_ title: String, icon: String, tint: Color, filled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.subheadline).fontWeight(.semibold)
                .foregroundColor(filled ? .white : tint)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Capsule().fill(filled ? tint : tint.opacity(0.14)))
        }.buttonStyle(.plain)
    }

    private var footer: some View {
        Button(role: .destructive) { showReset = true } label: {
            Label("清空重来", systemImage: "arrow.counterclockwise").font(.caption).foregroundColor(.secondary)
        }.buttonStyle(.plain)
    }

    // MARK: actions

    private func addItem() {
        let t = newItem.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        platterStore.addItem(t, to: selected)
        newItem = ""
    }

    /// The bowl-center button: does the obvious thing for the current state.
    private func centerTap() {
        if pomo.awaitingChoice { finishQuadrant(); return }
        if pomo.running { pomo.toggle(); return }          // pause a running focus/rest
        if pomo.phase == .rest { pomo.start(); return }    // start / resume the rest
        if pomo.idle { startQuadrant(platter.current) }    // fresh focus block for the current 格
        else { pomo.start() }                              // resume a paused focus
    }

    /// Point the shared Pomodoro at this quadrant and start a fresh focus block.
    private func startQuadrant(_ i: Int) {
        // If a focus block is mid-run, end it via skip() so its elapsed minutes are still
        // logged (reset() would discard them silently).
        if pomo.phase == .work && pomo.running { pomo.skip() }
        platterStore.setCurrent(i)
        selected = i
        pomo.workMins = platter.focusMins
        pomo.restMins = platter.restMins
        pomo.reset()          // phase=.work, remaining=focusMins*60, stopped, awaitingChoice=false
        pomo.start()
    }

    private func finishQuadrant() {
        guard pomo.awaitingChoice else { return }   // ignore a double-tap
        pomo.chooseRest()                            // clears awaitingChoice synchronously FIRST
        platterStore.advance()
        selected = platter.current
    }

    private func carryOver() {
        guard pomo.awaitingChoice else { return }
        let from = platter.current                   // snapshot before mutating the cursor
        pomo.chooseRest()
        platterStore.carryOver(from: from)
        selected = platter.current
    }
}
