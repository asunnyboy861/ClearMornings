import Foundation

public struct WidgetSnapshot: Codable {
    public var currentStreak: Int = 0
    public var totalSoberDays: Int = 0
    public var longestStreak: Int = 0
    public var restarts: Int = 0
    public var unknownGap: Int = 0
    public var todayKey: String = ""
    public var startDayKey: String = ""
    public var journeyName: String = "Alcohol"
    public var dailySpend: Double = 0
    public var currency: String = "USD"
    public var statuses: [String: DayStatus] = [:]
    public var updatedAt: Date = .distantPast
}

public struct PendingCheckIn: Codable {
    public var dayKey: String
    public var status: DayStatus
    public var mood: Int?
    public var craving: Int?
    public var createdAt: Date
}

public enum AppGroupStore {
    public static let appGroupID = "group.com.zzoutuo.ClearMornings"
    static let snapshotKey = "cm.widget.snapshot"
    static let pendingKey = "cm.pending.checkins"

    public static var shared: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    public static func loadSnapshot() -> WidgetSnapshot {
        guard let defaults = shared,
              let data = defaults.data(forKey: snapshotKey),
              let snap = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return WidgetSnapshot()
        }
        return snap
    }

    public static func saveSnapshot(_ snap: WidgetSnapshot) {
        guard let defaults = shared,
              let data = try? JSONEncoder().encode(snap) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    public static func appendPending(_ op: PendingCheckIn) {
        guard let defaults = shared else { return }
        var ops = loadPending()
        ops.removeAll { $0.dayKey == op.dayKey }
        ops.append(op)
        if let data = try? JSONEncoder().encode(ops) {
            defaults.set(data, forKey: pendingKey)
        }
    }

    public static func loadPending() -> [PendingCheckIn] {
        guard let defaults = shared,
              let data = defaults.data(forKey: pendingKey),
              let ops = try? JSONDecoder().decode([PendingCheckIn].self, from: data) else {
            return []
        }
        return ops
    }

    public static func clearPending() {
        shared?.removeObject(forKey: pendingKey)
    }
}
