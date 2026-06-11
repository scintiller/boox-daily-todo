import AVFoundation

/// Plays a ~7-second beeping chime when a pomodoro phase ends.
/// Synthesizes the tone in code (no bundled asset) and uses .playback so it
/// sounds even if the ringer is on silent.
final class Chime: NSObject, AVAudioPlayerDelegate {
    static let shared = Chime()
    private var player: AVAudioPlayer?

    func play() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.duckOthers])
        try? session.setActive(true)
        guard let data = Self.makeWav() else { return }
        player = try? AVAudioPlayer(data: data)
        player?.delegate = self
        player?.volume = 1.0
        player?.play()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    // 7s of a gentle repeating beep (0.25s tone @ 880Hz + 0.15s gap), 16-bit mono WAV.
    private static func makeWav() -> Data? {
        let sr = 44100.0, duration = 7.0, freq = 880.0
        let total = Int(sr * duration)
        let onN = Int(0.25 * sr), offN = Int(0.15 * sr), period = onN + offN
        var samples = [Int16](); samples.reserveCapacity(total)
        for i in 0..<total {
            let pos = i % period
            var amp = 0.0
            if pos < onN {
                let env = sin(Double.pi * Double(pos) / Double(onN))   // fade in/out, no clicks
                amp = 0.5 * env * sin(2 * Double.pi * freq * Double(i) / sr)
            }
            samples.append(Int16(amp * Double(Int16.max)))
        }
        return wav(samples, sampleRate: Int(sr))
    }

    private static func wav(_ samples: [Int16], sampleRate: Int) -> Data {
        func u32(_ v: UInt32) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
        func u16(_ v: UInt16) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
        let dataSize = samples.count * 2
        var d = Data()
        d.append("RIFF".data(using: .ascii)!); d.append(u32(UInt32(36 + dataSize)))
        d.append("WAVE".data(using: .ascii)!)
        d.append("fmt ".data(using: .ascii)!); d.append(u32(16)); d.append(u16(1)); d.append(u16(1))
        d.append(u32(UInt32(sampleRate))); d.append(u32(UInt32(sampleRate * 2)))
        d.append(u16(2)); d.append(u16(16))
        d.append("data".data(using: .ascii)!); d.append(u32(UInt32(dataSize)))
        for s in samples { d.append(u16(UInt16(bitPattern: s))) }
        return d
    }
}
