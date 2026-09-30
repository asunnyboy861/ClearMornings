import Foundation
import SwiftData

@Model
final class Journey {
    var id: UUID = UUID()
    var name: String = "Alcohol"
    var goal: String = "quit"
    var taperWeeklyLimit: Int = 7
    var startDate: Date = Date.now
    var timezoneID: String = TimeZone.current.identifier
    var colorHex: String = "#FFB347"
    var isArchived: Bool = false
    var createdAt: Date = Date.now

    init(name: String = "Alcohol", goal: String = "quit", taperWeeklyLimit: Int = 7, startDate: Date = Date.now, colorHex: String = "#FFB347") {
        self.id = UUID()
        self.name = name
        self.goal = goal
        self.taperWeeklyLimit = taperWeeklyLimit
        self.startDate = startDate
        self.timezoneID = TimeZone.current.identifier
        self.colorHex = colorHex
        self.createdAt = .now
    }

    var startDayKey: String { StreakEngine.dayKey(startDate, tz: TimeZone(identifier: timezoneID) ?? .current) }
    var isTaper: Bool { goal == "taper" }
}

@Model
final class DayRecord {
    var dayKey: String = ""
    var journeyID: UUID = UUID()
    var statusRaw: String = DayStatus.unknown.rawValue
    var mood: Int = 0
    var craving: Int = -1
    var note: String = ""
    var updatedAt: Date = Date.now

    init(dayKey: String, journeyID: UUID, status: DayStatus, mood: Int? = nil, craving: Int? = nil, note: String = "") {
        self.dayKey = dayKey
        self.journeyID = journeyID
        self.statusRaw = status.rawValue
        self.mood = mood ?? 0
        self.craving = craving ?? -1
        self.note = note
        self.updatedAt = .now
    }

    var status: DayStatus {
        get { DayStatus(rawValue: statusRaw) ?? .unknown }
        set { statusRaw = newValue.rawValue; updatedAt = .now }
    }
    var moodValue: Int? { mood == 0 ? nil : mood }
    var cravingValue: Int? { craving < 0 ? nil : craving }
}

@Model
final class EditLog {
    var dayKey: String = ""
    var field: String = ""
    var oldValue: String = ""
    var newValue: String = ""
    var editedAt: Date = Date.now

    init(dayKey: String, field: String, oldValue: String, newValue: String) {
        self.dayKey = dayKey
        self.field = field
        self.oldValue = oldValue
        self.newValue = newValue
        self.editedAt = .now
    }
}

@Model
final class WhyItem {
    var text: String = ""
    var order: Int = 0
    var isPinned: Bool = false
    var createdAt: Date = Date.now

    init(text: String, order: Int = 0, isPinned: Bool = false) {
        self.text = text
        self.order = order
        self.isPinned = isPinned
        self.createdAt = .now
    }
}

@Model
final class SavingConfig {
    var journeyID: UUID = UUID()
    var dailySpend: Double = 0
    var currency: String = "USD"

    init(journeyID: UUID, dailySpend: Double, currency: String = "USD") {
        self.journeyID = journeyID
        self.dailySpend = dailySpend
        self.currency = currency
    }
}

@Model
final class MilestoneState {
    var journeyID: UUID = UUID()
    var milestoneID: String = ""
    var achievedAt: Date = Date.distantPast
    var celebratedAt: Date?

    init(journeyID: UUID, milestoneID: String, achievedAt: Date) {
        self.journeyID = journeyID
        self.milestoneID = milestoneID
        self.achievedAt = achievedAt
    }
}

@Model
final class SOSLog {
    var triggeredAt: Date = Date.now
    var resolvedBy: String = "breathing"
    var cravingBefore: Int = -1
    var cravingAfter: Int = -1

    init(resolvedBy: String, cravingBefore: Int? = nil, cravingAfter: Int? = nil) {
        self.triggeredAt = .now
        self.resolvedBy = resolvedBy
        self.cravingBefore = cravingBefore ?? -1
        self.cravingAfter = cravingAfter ?? -1
    }
}

@Model
final class JournalEntry {
    var dayKey: String = ""
    var text: String = ""
    var aiSummary: String = ""
    var createdAt: Date = Date.now

    init(dayKey: String, text: String) {
        self.dayKey = dayKey
        self.text = text
        self.createdAt = .now
    }
}

@Model
final class PhotoCheckIn {
    var dayKey: String = ""
    var localFileName: String = ""
    var mirrorResult: String = ""
    var createdAt: Date = Date.now

    init(dayKey: String, localFileName: String) {
        self.dayKey = dayKey
        self.localFileName = localFileName
        self.createdAt = .now
    }
}

@Model
final class AIChatMessage {
    var sessionID: String = ""
    var role: String = "user"
    var text: String = ""
    var modelUsed: String = ""
    var createdAt: Date = Date.now

    init(sessionID: String, role: String, text: String, modelUsed: String) {
        self.sessionID = sessionID
        self.role = role
        self.text = text
        self.modelUsed = modelUsed
        self.createdAt = .now
    }
}
