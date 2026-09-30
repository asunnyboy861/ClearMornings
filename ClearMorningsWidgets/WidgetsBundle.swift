import WidgetKit
import SwiftUI
import AppIntents

struct ClearMorningsStreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let totalSober: Int
    let saved: Double
    let currency: String
    let todayDone: Bool
    let journeyName: String
}

struct ClearMorningsStreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClearMorningsStreakEntry {
        ClearMorningsStreakEntry(date: .now, streak: 47, totalSober: 120, saved: 300, currency: "USD", todayDone: false, journeyName: "Alcohol")
    }

    func getSnapshot(in context: Context, completion: @escaping (ClearMorningsStreakEntry) -> Void) {
        completion(entryFromSnapshot())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClearMorningsStreakEntry>) -> Void) {
        var entry = entryFromSnapshot()
        let nextMidnight = Calendar.current.startOfDay(for: .now).addingTimeInterval(86400)
        if nextMidnight > .now {
            entry = ClearMorningsStreakEntry(date: nextMidnight, streak: entry.streak, totalSober: entry.totalSober, saved: entry.saved, currency: entry.currency, todayDone: false, journeyName: entry.journeyName)
        }
        completion(Timeline(entries: [entry], policy: .atEnd))
    }

    private func entryFromSnapshot() -> ClearMorningsStreakEntry {
        let snap = AppGroupStore.loadSnapshot()
        let todayKey = StreakEngine.dayKey(.now)
        var map = snap.statuses
        map[todayKey] = map[todayKey] ?? .unknown
        let result = StreakEngine.compute(statuses: map, startDayKey: snap.startDayKey, todayKey: todayKey)
        return ClearMorningsStreakEntry(
            date: .now,
            streak: result.current,
            totalSober: result.totalSoberDays,
            saved: SavingsEngine.saved(soberDays: result.totalSoberDays, dailySpend: snap.dailySpend),
            currency: snap.currency,
            todayDone: snap.statuses[todayKey] == .sober,
            journeyName: snap.journeyName
        )
    }
}

struct MarkClearIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark today clear"
    static var description: IntentDescription = "Check in today as an alcohol-free day."

    func perform() async throws -> some IntentResult {
        let todayKey = StreakEngine.dayKey(.now)
        var snap = AppGroupStore.loadSnapshot()
        if snap.startDayKey.isEmpty {
            snap.startDayKey = todayKey
        }
        snap.statuses[todayKey] = .sober
        snap.todayKey = todayKey
        let result = StreakEngine.compute(statuses: snap.statuses, startDayKey: snap.startDayKey, todayKey: todayKey)
        snap.currentStreak = result.current
        snap.totalSoberDays = result.totalSoberDays
        snap.longestStreak = result.longestStreak
        snap.restarts = result.restarts
        snap.unknownGap = result.unknownGap
        snap.updatedAt = .now
        AppGroupStore.saveSnapshot(snap)
        AppGroupStore.appendPending(PendingCheckIn(dayKey: todayKey, status: .sober, mood: nil, craving: nil, createdAt: .now))
        WidgetCenter.shared.reloadTimelines(ofKind: "ClearMorningsStreakWidget")
        return .result()
    }
}

struct ClearMorningsStreakWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ClearMorningsStreakEntry

    var body: some View {
        switch family {
        case .systemSmall: small
        case .systemMedium: medium
        case .accessoryCircular: accessoryCircular
        default: accessoryRectangular
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.dawnGradient)
                Text("CLEAR MORNINGS")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.calmGray)
                Spacer()
            }
            Text("\(entry.streak)")
                .font(.system(size: 46, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.dawnGradient)
            Text(entry.todayDone ? "Day \(entry.streak) — marked clear" : "Morning, Day \(entry.streak).")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            if !entry.todayDone {
                checkInButton
            } else {
                Text("See you tomorrow morning")
                    .font(.caption2)
                    .foregroundStyle(Theme.calmGray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var medium: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.streak)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.dawnGradient)
                Text("days clear")
                    .font(.caption)
                    .foregroundStyle(Theme.calmGray)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Morning, Day \(entry.streak).")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(entry.totalSober) sober days total")
                    .font(.caption)
                    .foregroundStyle(Theme.calmGray)
                if entry.saved > 0 {
                    Text(String(format: "%@ %.0f saved", entry.currency, entry.saved))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.amber)
                }
                if !entry.todayDone {
                    checkInButton
                }
            }
            Spacer()
        }
    }

    private var accessoryCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text("\(entry.streak)")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.dawnGradient)
                Text("clear")
                    .font(.caption2)
                    .foregroundStyle(Theme.calmGray)
            }
        }
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Morning, Day \(entry.streak).")
                .font(.headline)
                .foregroundStyle(Theme.dawnGradient)
            Text(entry.todayDone ? "Marked clear today" : "Tap to mark today clear")
                .font(.caption)
                .foregroundStyle(.white)
            Text("\(entry.totalSober) sober days total")
                .font(.caption2)
                .foregroundStyle(Theme.calmGray)
        }
    }

    private var checkInButton: some View {
        Button(intent: MarkClearIntent()) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text("Mark clear today")
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.dawnGradient, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ClearMorningsStreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ClearMorningsStreakWidget", provider: ClearMorningsStreakProvider()) { entry in
            ClearMorningsStreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Clear Mornings")
        .description("Your streak, your savings, and a one-tap morning check-in.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct ClearMorningsWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClearMorningsStreakWidget()
    }
}
