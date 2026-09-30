import Foundation
import SwiftData
import WidgetKit

@MainActor
enum CheckInService {
    static func fetchPrimaryJourney(_ context: ModelContext) -> Journey? {
        let descriptor = FetchDescriptor<Journey>(sortBy: [SortDescriptor(\.createdAt)])
        let all = (try? context.fetch(descriptor)) ?? []
        return all.first { !$0.isArchived } ?? all.first
    }

    static func fetchRecords(_ context: ModelContext, journeyID: UUID) -> [DayRecord] {
        let descriptor = FetchDescriptor<DayRecord>(
            predicate: #Predicate { $0.journeyID == journeyID },
            sortBy: [SortDescriptor(\.dayKey)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func record(for dayKey: String, journeyID: UUID, context: ModelContext) -> DayRecord? {
        let descriptor = FetchDescriptor<DayRecord>(
            predicate: #Predicate { $0.journeyID == journeyID && $0.dayKey == dayKey }
        )
        return (try? context.fetch(descriptor))?.first
    }

    static func upsertRecord(
        _ context: ModelContext,
        journey: Journey,
        dayKey: String,
        status: DayStatus,
        mood: Int? = nil,
        craving: Int? = nil,
        note: String? = nil,
        logEdits: Bool = true
    ) {
        let existing = record(for: dayKey, journeyID: journey.id, context: context)
        if let rec = existing {
            if logEdits {
                if rec.status != status {
                    context.insert(EditLog(dayKey: dayKey, field: "status", oldValue: rec.status.rawValue, newValue: status.rawValue))
                }
                if let mood, rec.moodValue != mood {
                    context.insert(EditLog(dayKey: dayKey, field: "mood", oldValue: "\(rec.moodValue ?? -1)", newValue: "\(mood)"))
                }
                if let craving, rec.cravingValue != craving {
                    context.insert(EditLog(dayKey: dayKey, field: "craving", oldValue: "\(rec.cravingValue ?? -1)", newValue: "\(craving)"))
                }
                if let note, rec.note != note {
                    context.insert(EditLog(dayKey: dayKey, field: "note", oldValue: rec.note, newValue: note))
                }
            }
            rec.status = status
            if let mood { rec.mood = mood }
            if let craving { rec.craving = craving }
            if let note { rec.note = note }
            rec.updatedAt = .now
        } else {
            context.insert(DayRecord(dayKey: dayKey, journeyID: journey.id, status: status, mood: mood, craving: craving, note: note ?? ""))
        }
    }

    static func ensureYesterdayPlaceholder(_ context: ModelContext) {
        guard let journey = fetchPrimaryJourney(context) else { return }
        let todayKey = StreakEngine.dayKey(.now)
        let yesterdayKey = StreakEngine.previousDay(todayKey)
        if yesterdayKey >= journey.startDayKey, record(for: yesterdayKey, journeyID: journey.id, context: context) == nil {
            upsertRecord(context, journey: journey, dayKey: yesterdayKey, status: .unknown, logEdits: false)
        }
    }

    static func syncPendingFromWidget(_ context: ModelContext) {
        let ops = AppGroupStore.loadPending()
        guard !ops.isEmpty else { return }
        guard let journey = fetchPrimaryJourney(context) else { return }
        for op in ops {
            if let existing = record(for: op.dayKey, journeyID: journey.id, context: context) {
                if existing.updatedAt < op.createdAt {
                    existing.status = op.status
                    if let m = op.mood { existing.mood = m }
                    if let c = op.craving { existing.craving = c }
                    existing.updatedAt = op.createdAt
                }
            } else {
                context.insert(DayRecord(dayKey: op.dayKey, journeyID: journey.id, status: op.status, mood: op.mood, craving: op.craving))
            }
        }
        AppGroupStore.clearPending()
    }

    static func recalcAndPublish(_ context: ModelContext) -> StreakResult? {
        guard let journey = fetchPrimaryJourney(context) else { return nil }
        let records = fetchRecords(context, journeyID: journey.id)
        let todayKey = StreakEngine.dayKey(.now)
        var statuses: [String: DayStatus] = [:]
        for r in records {
            statuses[r.dayKey] = r.status
        }
        let result = StreakEngine.compute(statuses: statuses, startDayKey: journey.startDayKey, todayKey: todayKey)

        var snap = AppGroupStore.loadSnapshot()
        snap.currentStreak = result.current
        snap.totalSoberDays = result.totalSoberDays
        snap.longestStreak = result.longestStreak
        snap.restarts = result.restarts
        snap.unknownGap = result.unknownGap
        snap.todayKey = todayKey
        snap.startDayKey = journey.startDayKey
        snap.journeyName = journey.name
        snap.statuses = Self.prune(statuses, keeping: 500)
        snap.updatedAt = .now
        if let config = fetchSavingConfig(context, journeyID: journey.id) {
            snap.dailySpend = config.dailySpend
            snap.currency = config.currency
        }
        AppGroupStore.saveSnapshot(snap)
        WidgetCenter.shared.reloadAllTimelines()
        return result
    }

    static func prune(_ statuses: [String: DayStatus], keeping days: Int) -> [String: DayStatus] {
        guard statuses.count > days else { return statuses }
        let keys = statuses.keys.sorted().suffix(days)
        var out: [String: DayStatus] = [:]
        for k in keys { out[k] = statuses[k] ?? .unknown }
        return out
    }

    static func fetchSavingConfig(_ context: ModelContext, journeyID: UUID) -> SavingConfig? {
        let descriptor = FetchDescriptor<SavingConfig>(
            predicate: #Predicate { $0.journeyID == journeyID }
        )
        return (try? context.fetch(descriptor))?.first
    }

    static func widgetCheckIn() -> Int {
        var snap = AppGroupStore.loadSnapshot()
        let todayKey = StreakEngine.dayKey(.now)
        if snap.todayKey != todayKey {
            snap.todayKey = todayKey
        }
        snap.statuses[todayKey] = .sober
        let result = StreakEngine.compute(
            statuses: snap.statuses,
            startDayKey: snap.startDayKey.isEmpty ? StreakEngine.shiftDay(todayKey, by: -snap.currentStreak) : snap.startDayKey,
            todayKey: todayKey
        )
        snap.currentStreak = result.current
        snap.totalSoberDays = result.totalSoberDays
        snap.longestStreak = result.longestStreak
        snap.unknownGap = result.unknownGap
        snap.updatedAt = .now
        AppGroupStore.saveSnapshot(snap)
        AppGroupStore.appendPending(PendingCheckIn(dayKey: todayKey, status: .sober, mood: nil, craving: nil, createdAt: .now))
        WidgetCenter.shared.reloadAllTimelines()
        return result.current
    }
}
