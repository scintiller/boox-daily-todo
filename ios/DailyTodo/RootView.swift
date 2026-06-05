import SwiftUI

struct RootView: View {
    @StateObject private var store = Store()
    @State private var tab = 0
    @State private var weatherExpanded = false

    private var dateHeader: String {
        let iso = Cal.isoWeekday(Date())
        return "\(Cal.todayString) \(Categories.weekdayCN[iso] ?? "")"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header: date + today's weather (tap to expand) + refresh
            HStack(alignment: .firstTextBaseline) {
                let wx = todayWeatherSummary(store.weather)
                HStack(spacing: 6) {
                    Text(dateHeader).font(.headline)
                    if let wx {
                        Text(wx).font(.subheadline)
                        Image(systemName: weatherExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { if wx != nil { weatherExpanded.toggle() } }

                Spacer()

                Button(action: { store.refresh() }) {
                    Label(store.loading ? "刷新中…" : "刷新", systemImage: "arrow.clockwise")
                        .labelStyle(.titleAndIcon)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            WeatherAlertView(days: store.weather)
            if weatherExpanded { WeatherDetailView(days: store.weather).padding(.bottom, 6) }

            if let err = store.errorText {
                Text("⚠️ \(err)").font(.caption).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
            }

            Picker("", selection: $tab) {
                Text("今日").tag(0)
                Text("坚持度").tag(1)
                Text("备忘").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 6)

            Divider()

            switch tab {
            case 0: TodayView(store: store)
            case 1: StatsView(store: store)
            default: MemoView(store: store)
            }
        }
        .overlay(alignment: .bottom) {
            if let t = store.toast {
                ToastView(text: t)
            }
        }
        .onAppear { if store.tasks.isEmpty { store.start() } }
    }
}

struct ToastView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline).bold()
            .padding(.horizontal, 18).padding(.vertical, 11)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(0.15)))
            .shadow(radius: 6, y: 2)
            .padding(.bottom, 34)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
