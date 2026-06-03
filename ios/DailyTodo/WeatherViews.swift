import SwiftUI

func todayWeatherSummary(_ days: [DayWeather]) -> String? {
    guard let w = days.first else { return nil }
    let (emoji, label) = weatherInfo(w.code)
    if let cur = w.currentTemp {
        return "\(emoji)\(label) \(cur)° (\(w.tMax)°/\(w.tMin)°)"
    }
    return "\(emoji)\(label) \(w.tMax)°/\(w.tMin)°"
}

private let dayLabels = ["今天", "明天", "后天"]

struct WeatherAlertView: View {
    let days: [DayWeather]
    var body: some View {
        if let idx = days.prefix(3).firstIndex(where: { isHeavyRain($0) }) {
            let w = days[idx]
            let (_, label) = weatherInfo(w.code)
            let mm = w.precip >= 1 ? "，预计降水 \(Int(w.precip))mm" : ""
            Text("⚠️ 大暴雨预警：\(dayLabels[safe: idx] ?? "近期")有\(label)\(mm)，记得带伞 ☔")
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary, lineWidth: 2))
                .padding(.horizontal)
        }
    }
}

struct WeatherDetailView: View {
    let days: [DayWeather]
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(days.prefix(3).enumerated()), id: \.offset) { i, w in
                let (emoji, label) = weatherInfo(w.code)
                VStack(spacing: 4) {
                    Text(dayLabels[safe: i] ?? "").font(.subheadline).bold()
                    Text(emoji).font(.system(size: 32))
                    Text(label).font(.subheadline)
                    if let cur = w.currentTemp {
                        Text("\(cur)°").font(.title3).bold()
                        Text("(\(w.tMax)°/\(w.tMin)°)").font(.caption)
                    } else {
                        Text("\(w.tMax)° / \(w.tMin)°").font(.subheadline)
                    }
                    if w.precipProb > 0 {
                        Text("💧 \(w.precipProb)%").font(.caption)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
