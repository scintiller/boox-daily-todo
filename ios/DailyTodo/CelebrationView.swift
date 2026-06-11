import SwiftUI

/// One celebration trigger. `effect` 0..<10 picks which of the 10 effects to show.
struct CelebrationEvent: Equatable, Identifiable {
    let id: Int
    let effect: Int
}

private let confettiColors: [Color] = [.red, .orange, .yellow, .green, .mint, .blue, .indigo, .purple, .pink]

private struct Particle: Identifiable {
    let id: Int
    var color: Color = .clear
    var emoji: String? = nil
    var sx: CGFloat = 0; var sy: CGFloat = 0      // start position
    var dx: CGFloat = 0; var dy: CGFloat = 0      // end position
    var rot: Double = 0
    var size: CGFloat = 9
    var endOpacity: Double = 0
}

// MARK: - generic particle burst
private struct Burst: View {
    let make: (CGSize) -> [Particle]
    var duration: Double = 1.4
    @State private var particles: [Particle] = []
    @State private var go = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    piece(p)
                        .rotationEffect(.degrees(go ? p.rot : 0))
                        .position(x: go ? p.dx : p.sx, y: go ? p.dy : p.sy)
                        .opacity(go ? p.endOpacity : 1)
                }
            }
            .onAppear {
                particles = make(geo.size)
                withAnimation(.easeOut(duration: duration)) { go = true }
            }
        }
    }

    @ViewBuilder private func piece(_ p: Particle) -> some View {
        if let e = p.emoji {
            Text(e).font(.system(size: p.size))
        } else {
            RoundedRectangle(cornerRadius: 2).fill(p.color).frame(width: p.size, height: p.size * 0.6)
        }
    }
}

// MARK: - particle generators
private func confettiBurstCenter(_ s: CGSize) -> [Particle] {
    let cx = s.width / 2, cy = s.height * 0.42
    return (0..<46).map { i in
        let ang = Double.random(in: 0..<2 * .pi), dist = Double.random(in: 80...340)
        return Particle(id: i, color: confettiColors.randomElement()!,
                        sx: cx, sy: cy,
                        dx: cx + CGFloat(cos(ang) * dist),
                        dy: cy + CGFloat(sin(ang) * dist) + CGFloat.random(in: 60...200),
                        rot: Double.random(in: -360...360), size: CGFloat.random(in: 7...13))
    }
}

private func confettiRain(_ s: CGSize) -> [Particle] {
    (0..<64).map { i in
        let x = CGFloat.random(in: 0...s.width)
        return Particle(id: i, color: confettiColors.randomElement()!,
                        sx: x, sy: CGFloat.random(in: -120 ... -10),
                        dx: x + CGFloat.random(in: -30...30), dy: s.height + 40,
                        rot: Double.random(in: -300...300), size: CGFloat.random(in: 6...12))
    }
}

private func fireworks(_ s: CGSize) -> [Particle] {
    var ps: [Particle] = []; var id = 0
    for _ in 0..<3 {
        let cx = CGFloat.random(in: s.width * 0.2...s.width * 0.8)
        let cy = CGFloat.random(in: s.height * 0.15...s.height * 0.5)
        let col = confettiColors.randomElement()!
        for k in 0..<20 {
            let ang = Double(k) / 20 * 2 * .pi, dist = Double.random(in: 90...150)
            ps.append(Particle(id: id, color: col, sx: cx, sy: cy,
                               dx: cx + CGFloat(cos(ang) * dist), dy: cy + CGFloat(sin(ang) * dist),
                               size: 7)); id += 1
        }
    }
    return ps
}

private func starShower(_ s: CGSize) -> [Particle] {
    (0..<40).map { i in
        let x = CGFloat.random(in: 0...s.width)
        return Particle(id: i, emoji: ["⭐️", "✨", "🌟", "💫"].randomElement(),
                        sx: x, sy: CGFloat.random(in: -100 ... -10),
                        dx: x + CGFloat.random(in: -20...20), dy: s.height + 40,
                        rot: Double.random(in: -180...180), size: CGFloat.random(in: 16...28))
    }
}

private func sideCannons(_ s: CGSize) -> [Particle] {
    var ps: [Particle] = []; var id = 0
    let corners = [(CGPoint(x: 0, y: s.height), false), (CGPoint(x: s.width, y: s.height), true)]
    for (corner, fromRight) in corners {
        for _ in 0..<26 {
            let ang = fromRight ? Double.random(in: -(.pi * 0.85) ... -(.pi * 0.45))
                                : Double.random(in: -(.pi * 0.55) ... -(.pi * 0.15))
            let dist = Double.random(in: 220...460)
            ps.append(Particle(id: id, color: confettiColors.randomElement()!,
                               sx: corner.x, sy: corner.y,
                               dx: corner.x + CGFloat(cos(ang) * dist), dy: corner.y + CGFloat(sin(ang) * dist),
                               rot: Double.random(in: -300...300), size: CGFloat.random(in: 7...12))); id += 1
        }
    }
    return ps
}

private func emojiFountain(_ s: CGSize) -> [Particle] {
    let cx = s.width / 2, base = s.height
    return (0..<26).map { i in
        let ang = Double.random(in: -(.pi * 0.78) ... -(.pi * 0.22)), dist = Double.random(in: 160...360)
        return Particle(id: i, emoji: ["💪", "🔥", "🏆", "🎉", "⭐️", "👏"].randomElement(),
                        sx: cx, sy: base,
                        dx: cx + CGFloat(cos(ang) * dist),
                        dy: base + CGFloat(sin(ang) * dist) + CGFloat.random(in: 0...130),
                        rot: Double.random(in: -120...120), size: CGFloat.random(in: 20...32))
    }
}

private func sparkleBurst(_ s: CGSize) -> [Particle] {
    let cx = s.width / 2, cy = s.height * 0.45
    return (0..<28).map { i in
        let ang = Double.random(in: 0..<2 * .pi), dist = Double.random(in: 60...210)
        return Particle(id: i, emoji: "✨", sx: cx, sy: cy,
                        dx: cx + CGFloat(cos(ang) * dist), dy: cy + CGFloat(sin(ang) * dist),
                        size: CGFloat.random(in: 14...26))
    }
}

// MARK: - dedicated (non-particle) effects
private struct EmojiPop: View {
    let emoji: String
    @State private var s: CGFloat = 0.2
    @State private var o: Double = 0
    var body: some View {
        Text(emoji).font(.system(size: 120)).scaleEffect(s).opacity(o)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) { s = 1; o = 1 }
                withAnimation(.easeIn(duration: 0.5).delay(1.1)) { o = 0; s = 1.3 }
            }
    }
}

private struct TextBanner: View {
    let text: String
    @State private var y: CGFloat = 50
    @State private var o: Double = 0
    var body: some View {
        Text(text).font(.title2).bold().foregroundColor(.white)
            .padding(.horizontal, 22).padding(.vertical, 14)
            .background(Capsule().fill(Color.indigo)).shadow(radius: 10, y: 4)
            .offset(y: y).opacity(o)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { y = 0; o = 1 }
                withAnimation(.easeIn(duration: 0.4).delay(1.3)) { o = 0; y = -30 }
            }
    }
}

private struct CheckRingPulse: View {
    @State private var go = false
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle().stroke(Color.green.opacity(0.5), lineWidth: 4)
                    .frame(width: go ? 220 + CGFloat(i) * 70 : 40, height: go ? 220 + CGFloat(i) * 70 : 40)
                    .opacity(go ? 0 : 0.8)
            }
            Image(systemName: "checkmark.circle.fill").font(.system(size: 92)).foregroundColor(.green)
                .scaleEffect(go ? 1 : 0.3)
        }
        .onAppear { withAnimation(.easeOut(duration: 1.1)) { go = true } }
    }
}

private struct SparkleText: View {
    let text: String
    @State private var o = 0.0
    @State private var s: CGFloat = 0.6
    var body: some View {
        ZStack {
            Burst(make: sparkleBurst, duration: 1.3)
            Text(text).font(.largeTitle).bold()
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(.ultraThinMaterial, in: Capsule())
                .scaleEffect(s).opacity(o)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { o = 1; s = 1 }
                    withAnimation(.easeIn(duration: 0.4).delay(1.1)) { o = 0 }
                }
        }
    }
}

// MARK: - dispatcher
struct CelebrationView: View {
    let effect: Int
    let onDone: () -> Void

    private let praises = ["太棒啦，又完成了一件事 🎉", "干得漂亮 💪", "完成 +1 ✅", "继续加油 🔥", "你真厉害 ⭐️"]
    private let popEmojis = ["🎉", "🥳", "✨", "🏆", "🌟"]

    var body: some View {
        ZStack {
            switch effect % 10 {
            case 0: Burst(make: confettiBurstCenter)
            case 1: Burst(make: confettiRain, duration: 1.9)
            case 2: Burst(make: fireworks, duration: 1.4)
            case 3: EmojiPop(emoji: popEmojis.randomElement()!)
            case 4: TextBanner(text: praises.randomElement()!)
            case 5: Burst(make: starShower, duration: 1.9)
            case 6: CheckRingPulse()
            case 7: Burst(make: sideCannons, duration: 1.6)
            case 8: Burst(make: emojiFountain, duration: 1.7)
            default: SparkleText(text: "完成 ✅")
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) { onDone() }
        }
    }
}
