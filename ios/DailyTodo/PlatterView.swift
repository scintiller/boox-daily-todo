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
        let rI = rO * 0.30
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
    let resting: Bool
    let selected: Int
    let onTap: (Int) -> Void

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

                // center hub
                Circle().fill(Color(.secondarySystemBackground))
                    .frame(width: side * 0.32, height: side * 0.32)
                    .overlay(Circle().stroke(Color(.systemGray4), lineWidth: 1))
                    .overlay {
                        VStack(spacing: 1) {
                            Text(platter.half.label + "拼盘")
                                .font(.system(size: side * 0.040, weight: .bold)).foregroundColor(FOCUS)
                            Text("\(platter.settledCount)/4 格")
                                .font(.system(size: side * 0.036, weight: .medium)).foregroundColor(.secondary)
                        }
                    }
                    .allowsHitTesting(false)
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
            .fill(resting ? REST : Color(.systemGray))
            .frame(width: side * 1.04, height: side * 0.052)
            .rotationEffect(.degrees(deg))
            .animation(.easeInOut(duration: 0.3), value: resting)
            .allowsHitTesting(false)
    }
}

// MARK: - The sheet

struct PlatterView: View {
    @ObservedObject var platterStore: PlatterStore
    @ObservedObject var pomo: Pomodoro
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var selected = 0
    @State private var newItem = ""
    @State private var showReset = false

    private var platter: Platter { platterStore.platter }
    private var q: Quadrant { platter.quadrants[min(max(selected, 0), 3)] }
    private var resting: Bool { pomo.phase == .rest && pomo.running }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                intro
                BowlView(platter: platter, resting: resting, selected: selected) { tapped in
                    // Don't move the panel off a live block — that hides the 完成/顺延 controls
                    // and would let 开始专注 leap the cursor. Browsing while idle/resting is fine.
                    if pomo.phase == .work && (pomo.running || pomo.awaitingChoice) { return }
                    selected = tapped
                }
                    .frame(height: 300)
                    .padding(.horizontal, 8)
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
    @ViewBuilder private var actionRow: some View {
        if pomo.awaitingChoice {
            // A focus block just ended (still on 专注) → finish or 顺延 the current quadrant.
            VStack(spacing: 8) {
                Text("第 \(platter.current + 1) 格时间到 🎉").font(.subheadline).foregroundColor(FOCUS)
                HStack(spacing: 10) {
                    pill("完成本格", icon: "checkmark", tint: FOCUS, filled: false) { finishQuadrant() }
                    pill("顺延到下一格", icon: "arrow.turn.down.right", tint: .orange, filled: true) { carryOver() }
                }
            }
        } else if pomo.phase == .work && pomo.running {
            HStack(spacing: 12) {
                Label(pomo.label, systemImage: "timer").font(.headline).monospacedDigit().foregroundColor(FOCUS)
                Spacer()
                pill("跳过", icon: "forward.end.fill", tint: .secondary, filled: false) { pomo.skip() }
            }
        } else if pomo.phase == .rest && pomo.running {
            HStack(spacing: 12) {
                Label("休息中 " + pomo.label, systemImage: "cup.and.saucer.fill").font(.headline).monospacedDigit().foregroundColor(REST)
                Spacer()
                pill("跳过休息", icon: "forward.end.fill", tint: .secondary, filled: false) { pomo.skip() }
            }
        } else if pomo.phase == .rest {
            // rest queued/idle (not running) — start it regardless of the exact remaining value
            pill("开始休息 · \(platter.restMins)分", icon: "cup.and.saucer.fill", tint: REST, filled: true) { pomo.start() }
                .frame(maxWidth: .infinity)
        } else {
            // idle on 专注 → always start the ritual's CURRENT quadrant (never leap the cursor)
            pill("开始第 \(platter.current + 1) 格专注 · \(platter.focusMins)分", icon: "play.fill", tint: FOCUS, filled: true) {
                startQuadrant(platter.current)
            }
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
