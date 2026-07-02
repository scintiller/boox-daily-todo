// Platter.swift — data model + local store for the "四格拼盘" (bowl + 4 quadrants) focus ritual.
// LOCAL-ONLY (UserDefaults JSON), iOS 16+, Codable. Colors: indigo = focus, green = rest.
//
// The ritual: one half-day = one "platter" (a bowl split into 4 quadrants by two crossed
// chopsticks). Each quadrant is a focus block holding a few checkable items you type in the
// morning. Run a quadrant → focus timer; the chopstick gaps between quadrants are the rests.
// If a quadrant isn't finished you 顺延 (carry its unchecked items into the next quadrant).
//
// Items are plain local strings with a `done` flag — deliberately NOT TodoTask references,
// because Store reloads from Supabase every 60s and any task-id links would dangle.
import Foundation
import SwiftUI

// MARK: - Model

/// One checkable to-do inside a quadrant.
struct PlatterItem: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var done: Bool
    /// If carried in from an earlier quadrant, the quadrant index (0..3) it originally started in.
    /// Drives the small ↩︎ 顺延 badge. nil = planned right here.
    var carriedFrom: Int?

    init(id: String = UUID().uuidString, title: String, done: Bool = false, carriedFrom: Int? = nil) {
        self.id = id; self.title = title; self.done = done; self.carriedFrom = carriedFrom
    }
}

/// One of the 4 quadrants. Position is fixed: 0=top, 1=right, 2=bottom, 3=left.
struct Quadrant: Codable, Identifiable, Equatable {
    let id: String
    let index: Int
    var items: [PlatterItem]
    /// Set by 顺延 (unchecked items moved to the next quadrant). Pure visual/record flag.
    var carried: Bool

    init(id: String = UUID().uuidString, index: Int, items: [PlatterItem] = [], carried: Bool = false) {
        self.id = id; self.index = index; self.items = items; self.carried = carried
    }

    var openItems: [PlatterItem] { items.filter { !$0.done } }
    var doneCount: Int { items.filter { $0.done }.count }
    /// Cleanly done when it has items and they're all checked. Empty quadrant is not "done".
    var allDone: Bool { !items.isEmpty && openItems.isEmpty }
}

/// One half-day = one platter: 4 quadrants + the durations chosen for this platter + a cursor.
struct Platter: Codable, Identifiable, Equatable {
    let id: String
    let dateKey: String          // "yyyy-MM-dd"
    let half: HalfDay            // am | pm
    var quadrants: [Quadrant]    // ALWAYS exactly 4, index 0..3
    var focusMins: Int           // 45 or 60 — this platter's focus length
    var restMins: Int            // 5 or 15  — this platter's rest length
    /// Which quadrant is the current one in the ritual loop (0..3). Advanced explicitly.
    var current: Int
    let createdAt: String

    enum HalfDay: String, Codable {
        case am, pm
        var label: String { self == .am ? "上午" : "下午" }
        /// hour < 12 => am, else pm.
        static func current(_ date: Date = Date()) -> HalfDay {
            Cal.cal.component(.hour, from: date) < 12 ? .am : .pm
        }
    }

    static func storageKey(date: String, half: HalfDay) -> String { "platter.\(date).\(half.rawValue)" }
    var storageKey: String { Platter.storageKey(date: dateKey, half: half) }

    static func fresh(dateKey: String, half: HalfDay) -> Platter {
        Platter(id: UUID().uuidString, dateKey: dateKey, half: half,
                quadrants: (0..<4).map { Quadrant(index: $0) },
                focusMins: 45, restMins: 5, current: 0,
                createdAt: ISO8601DateFormatter().string(from: Date()))
    }

    var totalOpen: Int { quadrants.reduce(0) { $0 + $1.openItems.count } }
    var totalItems: Int { quadrants.reduce(0) { $0 + $1.items.count } }
    var totalDone: Int { quadrants.reduce(0) { $0 + $1.doneCount } }
    /// How many of the 4 quadrants are "eaten" (finished, 顺延'd, or passed behind the cursor).
    var settledCount: Int { quadrants.filter { $0.allDone || $0.carried || $0.index < current }.count }
    var allSettled: Bool { quadrants.allSatisfy { $0.allDone || $0.carried || $0.items.isEmpty } }
}

// MARK: - Store (local persistence + tiny state machine)

@MainActor
final class PlatterStore: ObservableObject {
    @Published private(set) var platter: Platter
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, now: Date = Date()) {
        self.defaults = defaults
        self.platter = PlatterStore.loadOrCreate(defaults: defaults, now: now)
    }

    /// Swap to the correct half-day platter on am→pm / new-day rollover. Call on sheet .onAppear.
    func reloadForNow(_ now: Date = Date()) {
        let wanted = Platter.storageKey(date: Cal.string(now), half: Platter.HalfDay.current(now))
        if platter.storageKey != wanted {
            platter = PlatterStore.loadOrCreate(defaults: defaults, now: now)
        }
    }

    private static func loadOrCreate(defaults: UserDefaults, now: Date) -> Platter {
        let date = Cal.string(now)
        let half = Platter.HalfDay.current(now)
        let key = Platter.storageKey(date: date, half: half)
        if let data = defaults.data(forKey: key),
           let p = try? JSONDecoder().decode(Platter.self, from: data) {
            return p
        }
        let fresh = Platter.fresh(dateKey: date, half: half)
        if let data = try? JSONEncoder().encode(fresh) { defaults.set(data, forKey: key) }
        return fresh
    }

    private func persist() {
        objectWillChange.send()
        if let data = try? JSONEncoder().encode(platter) {
            defaults.set(data, forKey: platter.storageKey)
        }
    }

    // MARK: planning
    func addItem(_ title: String, to i: Int) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, platter.quadrants.indices.contains(i) else { return }
        platter.quadrants[i].items.append(PlatterItem(title: t))
        persist()
    }
    func removeItem(_ item: PlatterItem, from i: Int) {
        guard platter.quadrants.indices.contains(i) else { return }
        platter.quadrants[i].items.removeAll { $0.id == item.id }
        persist()
    }
    func toggleItem(_ item: PlatterItem, in i: Int) {
        guard platter.quadrants.indices.contains(i),
              let j = platter.quadrants[i].items.firstIndex(where: { $0.id == item.id }) else { return }
        platter.quadrants[i].items[j].done.toggle()
        persist()
    }

    // MARK: durations
    func setFocus(_ m: Int) { platter.focusMins = m; persist() }
    func setRest(_ m: Int) { platter.restMins = m; persist() }

    // MARK: ritual cursor
    func setCurrent(_ i: Int) {
        guard platter.quadrants.indices.contains(i) else { return }
        platter.current = i; persist()
    }
    /// Advance the cursor 0→1→2→3 (stops at 3).
    func advance() {
        if platter.current < 3 { platter.current += 1; persist() }
    }

    /// ONE-TAP 顺延: copy every unchecked item of quadrant i into quadrant i+1 (tagged carriedFrom),
    /// mark quadrant i .carried, then advance. Quadrant 3 (last): items stay put, still flagged.
    func carryOver(from i: Int) {
        guard platter.quadrants.indices.contains(i) else { return }
        let next = i + 1
        if platter.quadrants.indices.contains(next) {
            for it in platter.quadrants[i].openItems {
                let origin = it.carriedFrom ?? i          // keep ORIGINAL origin across double-顺延
                platter.quadrants[next].items.append(
                    PlatterItem(title: it.title, done: false, carriedFrom: origin))
            }
            platter.quadrants[i].items.removeAll { !$0.done }   // keep done ones as its record
        }
        platter.quadrants[i].carried = true
        persist()
        advance()
    }

    /// Wipe this half-day's platter and re-plan (keeps the same focus/rest durations).
    func reset() {
        var f = Platter.fresh(dateKey: platter.dateKey, half: platter.half)
        f.focusMins = platter.focusMins; f.restMins = platter.restMins
        platter = f
        persist()
    }
}
