import SwiftUI

struct RecoveryMilestone: Identifiable, Equatable {
    let id: String
    let days: Int
    let title: String
    let detail: String
    let icon: String
}

enum MilestoneEngine {
    static let recovery: [RecoveryMilestone] = [
        RecoveryMilestone(id: "r24h", days: 1, title: "24 Hours", detail: "Blood sugar normalizes. Your body begins to repair.", icon: "drop.fill"),
        RecoveryMilestone(id: "r72h", days: 3, title: "72 Hours", detail: "Hydration rebounds. Headaches start to ease.", icon: "brain.head.profile"),
        RecoveryMilestone(id: "r1w", days: 7, title: "1 Week", detail: "Sleep deepens. Morning fog starts lifting.", icon: "moon.zzz.fill"),
        RecoveryMilestone(id: "r2w", days: 14, title: "2 Weeks", detail: "Liver fat begins to drop. Reflux calms down.", icon: "leaf.fill"),
        RecoveryMilestone(id: "r30d", days: 30, title: "30 Days", detail: "Mental clarity rises. Blood pressure improves.", icon: "sun.max.fill"),
        RecoveryMilestone(id: "r60d", days: 60, title: "60 Days", detail: "Skin tone brightens. Energy becomes steady.", icon: "sparkles"),
        RecoveryMilestone(id: "r90d", days: 90, title: "90 Days", detail: "Brain chemistry rebalances. Mood stabilizes.", icon: "brain"),
        RecoveryMilestone(id: "r100d", days: 100, title: "100 Days", detail: "A hundred clear mornings. A different life.", icon: "star.fill"),
        RecoveryMilestone(id: "r180d", days: 180, title: "6 Months", detail: "Immune system strengthens. Anxiety quiets.", icon: "shield.fill"),
        RecoveryMilestone(id: "r1y", days: 365, title: "1 Year", detail: "Heart disease risk drops significantly.", icon: "heart.fill"),
        RecoveryMilestone(id: "r500d", days: 500, title: "500 Days", detail: "You've built something most people never do.", icon: "mountain.2.fill"),
        RecoveryMilestone(id: "r1000d", days: 1000, title: "1000 Days", detail: "A thousand clear mornings. Legendary.", icon: "crown.fill")
    ]

    static let streakBadges: [Int] = [1, 3, 7, 14, 21, 30, 60, 90, 100, 180, 365, 500, 1000]

    static func nextRecoveryMilestone(after days: Int) -> RecoveryMilestone? {
        recovery.first { $0.days > days }
    }

    static func achievedRecovery(days: Int) -> [RecoveryMilestone] {
        recovery.filter { $0.days <= days }
    }

    static func achievedBadges(days: Int) -> [Int] {
        streakBadges.filter { $0 <= days }
    }

    static func nextBadge(after days: Int) -> Int? {
        streakBadges.first { $0 > days }
    }
}

enum SavingsEngine {
    static let conversions: [(label: String, icon: String, cost: Double)] = [
        (label: "Gas fill-up", icon: "fuelpump.fill", cost: 45),
        (label: "Nice dinner out", icon: "fork.knife", cost: 60),
        (label: "Concert ticket", icon: "music.note", cost: 90),
        (label: "Weekend getaway", icon: "airplane", cost: 350)
    ]

    static func saved(soberDays: Int, dailySpend: Double) -> Double {
        Double(soberDays) * dailySpend
    }

    static func conversion(for amount: Double) -> (label: String, icon: String, count: Int)? {
        conversions
            .compactMap { item -> (label: String, icon: String, count: Int)? in
                let count = Int(amount / item.cost)
                guard count >= 1 else { return nil }
                return (item.label, item.icon, count)
            }
            .last
    }
}

enum Theme {
    static let nightBase = Color(red: 0.059, green: 0.071, blue: 0.133)
    static let nightCard = Color(red: 0.10, green: 0.11, blue: 0.19)
    static let dawnStart = Color(red: 1.0, green: 0.702, blue: 0.278)
    static let dawnEnd = Color(red: 1.0, green: 0.42, blue: 0.616)
    static let amber = Color(red: 1.0, green: 0.702, blue: 0.278)
    static let seaBlue = Color(red: 0.35, green: 0.55, blue: 0.95)
    static let calmGray = Color(white: 0.55)

    static var dawnGradient: LinearGradient {
        LinearGradient(colors: [dawnStart, dawnEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var statusColor: (DayStatus) -> Color {
        { status in
            switch status {
            case .sober: return amber
            case .slip: return calmGray
            case .skip: return seaBlue
            case .unknown: return Color(white: 0.35)
            }
        }
    }
}
