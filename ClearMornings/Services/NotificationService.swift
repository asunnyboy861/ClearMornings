import Foundation
import UserNotifications

enum NotificationService {
    static let ritualPrefix = "cm.ritual."
    static let fixYesterdayID = "cm.fix.yesterday"
    static let milestonePrefix = "cm.milestone."
    static let trialID = "cm.trial.reminder"

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func rescheduleDailyRitual(streak: Int, hour: Int = 8) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: (0..<7).map { ritualPrefix + String($0) })

        let cal = Calendar.current
        for offset in 0..<7 {
            guard let fireDay = cal.date(byAdding: .day, value: offset + 1, to: cal.startOfDay(for: .now)) else { continue }
            var comps = cal.dateComponents([.year, .month, .day], from: fireDay)
            comps.hour = hour
            comps.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            let content = UNMutableNotificationContent()
            let day = streak + offset + 1
            content.title = "Morning, Day \(day)."
            content.body = "One check-in keeps the streak alive."
            content.sound = .default
            content.userInfo = ["streak": day]

            let req = UNNotificationRequest(identifier: ritualPrefix + String(offset), content: content, trigger: trigger)
            center.add(req)
        }
    }

    static func scheduleFixYesterdayReminder(yesterdayKey: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [fixYesterdayID])

        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: .now)
        comps.hour = 9
        comps.minute = 30
        if let target = cal.date(from: comps), target <= .now {
            comps = cal.dateComponents([.year, .month, .day], from: .now)
            comps.hour = 22
            comps.minute = 0
        }
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = "Yesterday is still fixable."
        content.body = "Fix Anything lets you backfill any day. Tap to complete it."
        content.sound = .default
        content.userInfo = ["dayKey": yesterdayKey]

        center.add(UNNotificationRequest(identifier: fixYesterdayID, content: content, trigger: trigger))
    }

    static func scheduleMilestoneHeadsUp(_ milestone: RecoveryMilestone, achievedOn: Date) {
        let id = milestonePrefix + milestone.id
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let eve = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: achievedOn)) ?? achievedOn
        guard eve > .now else { return }
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: eve)
        comps.hour = 8
        comps.minute = 30
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = "Tomorrow: \(milestone.title)."
        content.body = milestone.detail
        content.sound = .default

        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func scheduleTrialReminder(daysLeft: Int) {
        let center = UNUserNotificationCenter.current()
        guard daysLeft > 3,
              let fireDate = Calendar.current.date(byAdding: .day, value: daysLeft - 3, to: Calendar.current.startOfDay(for: .now)),
              fireDate > .now else { return }
        center.removePendingNotificationRequests(withIdentifiers: [trialID])

        var comps = Calendar.current.dateComponents([.year, .month, .day], from: fireDate)
        comps.hour = 10
        comps.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = "Your Clear+ trial ends soon."
        content.body = "You have \(daysLeft) days left. Keep AI coach, Mirror, and deep insights."
        content.sound = .default

        center.add(UNNotificationRequest(identifier: trialID, content: content, trigger: trigger))
    }

    static func cancelTrialReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [trialID])
    }
}
