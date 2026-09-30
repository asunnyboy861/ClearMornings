import Foundation

public enum DayStatus: String, Codable, CaseIterable {
    case sober
    case slip
    case skip
    case unknown
}

public struct StreakResult: Codable, Equatable {
    public var current: Int
    public var unknownGap: Int
    public var totalSoberDays: Int
    public var longestStreak: Int
    public var restarts: Int

    public init(current: Int = 0, unknownGap: Int = 0, totalSoberDays: Int = 0, longestStreak: Int = 0, restarts: Int = 0) {
        self.current = current
        self.unknownGap = unknownGap
        self.totalSoberDays = totalSoberDays
        self.longestStreak = longestStreak
        self.restarts = restarts
    }
}

public enum StreakEngine {
    public static let calendar = Calendar(identifier: .gregorian)

    public static func dayKey(_ date: Date, tz: TimeZone = .current) -> String {
        var cal = calendar
        cal.timeZone = tz
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 2000, c.month ?? 1, c.day ?? 1)
    }

    public static func date(fromKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var comps = DateComponents()
        comps.year = parts[0]
        comps.month = parts[1]
        comps.day = parts[2]
        return calendar.date(from: comps)
    }

    public static func previousDay(_ key: String) -> String {
        guard let date = date(fromKey: key),
              let prev = calendar.date(byAdding: .day, value: -1, to: date) else { return key }
        return dayKey(prev)
    }

    public static func shiftDay(_ key: String, by days: Int) -> String {
        guard let date = date(fromKey: key),
              let shifted = calendar.date(byAdding: .day, value: days, to: date) else { return key }
        return dayKey(shifted)
    }

    public static func daysBetween(_ fromKey: String, _ toKey: String) -> Int {
        guard let from = date(fromKey: fromKey), let to = date(fromKey: toKey) else { return 0 }
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    public static func compute(statuses: [String: DayStatus], startDayKey: String, todayKey: String) -> StreakResult {
        var result = StreakResult()
        result.totalSoberDays = statuses.values.filter { $0 == .sober }.count

        var walkKey = todayKey
        if statuses[todayKey] == nil {
            walkKey = previousDay(todayKey)
        }

        while walkKey >= startDayKey {
            switch statuses[walkKey] {
            case .sober:
                result.current += 1
            case .unknown, .none:
                result.unknownGap += 1
            case .slip, .skip:
                walkKey = ""
            }
            if walkKey.isEmpty { break }
            walkKey = previousDay(walkKey)
        }

        var longest = 0
        var run = 0
        var restarts = 0
        for key in statuses.keys.sorted() where key >= startDayKey {
            switch statuses[key] {
            case .sober:
                run += 1
                longest = max(longest, run)
            case .slip, .skip:
                if run > 0 { restarts += 1 }
                run = 0
            case .unknown, .none:
                break
            }
        }
        result.longestStreak = max(longest, result.current)
        result.restarts = restarts
        return result
    }
}
