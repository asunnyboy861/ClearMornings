import SwiftUI
import SwiftData

struct FixAnythingView: View {
    @Environment(\.modelContext) private var context
    @Query private var journeys: [Journey]
    @Query private var allRecords: [DayRecord]

    @State private var visibleMonth: Date = .now
    @State private var selectedKey: String?
    @State private var editStatus: DayStatus = .sober
    @State private var editMood: Double = 3
    @State private var editCraving: Double = 3
    @State private var editNote = ""
    @State private var showLogs = false
    @State private var confirmRestart = false

    private var journey: Journey? { journeys.first { !$0.isArchived } }
    private var recordsByKey: [String: DayRecord] {
        guard let journey else { return [:] }
        return Dictionary(allRecords.filter { $0.journeyID == journey.id }.map { ($0.dayKey, $0) }, uniquingKeysWith: { a, _ in a })
    }

    private var monthDays: [String] {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: visibleMonth) else { return [] }
        let first = interval.start
        let days = cal.range(of: .day, in: .month, for: first) ?? 1..<29
        let weekdayOffset = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        var keys = Array(repeating: "", count: weekdayOffset)
        for d in days {
            if let date = cal.date(byAdding: .day, value: d - 1, to: first) {
                keys.append(StreakEngine.dayKey(date))
            }
        }
        return keys
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    monthHeader
                    calendarGrid
                    legendRow
                    if let key = selectedKey {
                        editorCard(dayKey: key)
                    } else {
                        tapHint
                    }
                    restartCard
                }
                .padding(20)
                .padding(.bottom, 96)
            }
            .background(Theme.nightBase)
            .navigationTitle("History")
            .sheet(isPresented: $showLogs) { EditLogSheet(dayKey: selectedKey ?? "") }
            .confirmationDialog("Brave Restart", isPresented: $confirmRestart, titleVisibility: .visible) {
                Button("Restart from selected day") { performRestart() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your sober-since date moves to the selected day. Nothing is deleted — your history stays for the Mirror.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            Spacer()
            Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            Button {
                shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 4)
    }

    private var calendarGrid: some View {
        VStack(spacing: 8) {
            let letters = ["S", "M", "T", "W", "T", "F", "S"]
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    Text(letters[i])
                        .font(.caption2)
                        .foregroundStyle(Theme.calmGray)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, key in
                    if key.isEmpty {
                        Color.clear.frame(height: 40)
                    } else {
                        dayCell(key)
                    }
                }
            }
        }
        .padding(14)
        .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 18))
    }

    private func dayCell(_ key: String) -> some View {
        let record = recordsByKey[key]
        let status = record?.status
        let isToday = key == StreakEngine.dayKey(.now)
        let isStart = key == journey?.startDayKey
        return Button {
            selectDay(key)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(status.map { Theme.statusColor($0) } ?? Color.white.opacity(0.05))
                if isToday || isStart {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.dawnGradient, lineWidth: 2)
                }
                Text(dayNumber(key))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(status == nil ? Theme.calmGray : .white)
            }
            .frame(height: 40)
        }
    }

    private var legendRow: some View {
        HStack(spacing: 14) {
            legendDot(Theme.amber, "Sober")
            legendDot(Theme.seaBlue, "Skip / taper day")
            legendDot(Theme.calmGray, "Slip")
            legendDot(Color(white: 0.35), "Unknown")
        }
        .font(.caption2)
        .foregroundStyle(Theme.calmGray)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }

    private var tapHint: some View {
        Text("Tap any day to fix it. Backfill missed days, change a status, or add notes — nothing is ever locked.")
            .font(.subheadline)
            .foregroundStyle(Theme.calmGray)
            .multilineTextAlignment(.center)
            .padding(.vertical, 12)
    }

    private func editorCard(dayKey: String) -> some View {
        let record = recordsByKey[dayKey]
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(dateLabel(dayKey))
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    showLogs = true
                } label: {
                    Label("Edit history", systemImage: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundStyle(Theme.seaBlue)
                }
            }
            HStack(spacing: 8) {
                editStatusButton(.sober, "Clear", "sun.max.fill")
                editStatusButton(.skip, "Skip", "minus.circle")
                editStatusButton(.slip, "Slip", "heart.slash")
                editStatusButton(.unknown, "Unknown", "moon.haze")
            }
            if editStatus == .sober {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mood")
                        .font(.caption)
                        .foregroundStyle(Theme.calmGray)
                    Slider(value: $editMood, in: 1...5, step: 1).tint(Theme.dawnStart)
                    Text("Craving")
                        .font(.caption)
                        .foregroundStyle(Theme.calmGray)
                    Slider(value: $editCraving, in: 0...5, step: 1).tint(Theme.seaBlue)
                }
            }
            TextField("Note for this day (optional)", text: $editNote, axis: .vertical)
                .lineLimit(2...5)
                .font(.subheadline)
                .padding(10)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
            HStack(spacing: 12) {
                Button {
                    saveEdits(dayKey: dayKey)
                } label: {
                    Text("Save")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.dawnGradient, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                Button {
                    selectedKey = nil
                } label: {
                    Text("Cancel")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
            }
            if record != nil {
                Text("Fixes are logged in the audit trail — nothing is silently rewritten.")
                    .font(.caption2)
                    .foregroundStyle(Theme.calmGray)
            }
        }
        .padding(18)
        .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 18))
        .onAppear { loadEdits(from: record) }
        .onChange(of: dayKey) { _, _ in loadEdits(from: record) }
    }

    private func editStatusButton(_ status: DayStatus, _ label: String, _ icon: String) -> some View {
        Button {
            editStatus = status
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                editStatus == status ? AnyShapeStyle(Theme.dawnGradient) : AnyShapeStyle(Color.white.opacity(0.08)),
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
    }

    private var restartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.seaBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Brave Restart")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Starting over is not failing. Pick a day above, then restart from it — your old progress stays visible in the Mirror.")
                        .font(.caption)
                        .foregroundStyle(Theme.calmGray)
                }
            }
            Button {
                confirmRestart = true
            } label: {
                Text("Restart from selected day")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.seaBlue.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            .disabled(selectedKey == nil)
        }
        .padding(18)
        .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 18))
    }

    private func shiftMonth(_ delta: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: delta, to: visibleMonth) else { return }
        visibleMonth = next
    }

    private func dayNumber(_ key: String) -> String {
        String(key.suffix(2)).drop { $0 == "0" }.description
    }

    private func dateLabel(_ key: String) -> String {
        guard let date = StreakEngine.date(fromKey: key) else { return key }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func selectDay(_ key: String) {
        selectedKey = key
        loadEdits(from: recordsByKey[key])
    }

    private func loadEdits(from record: DayRecord?) {
        if let record {
            editStatus = record.status
            editMood = Double(record.mood == 0 ? 3 : record.mood)
            editCraving = Double(record.craving < 0 ? 3 : record.craving)
            editNote = record.note
        } else {
            editStatus = .sober
            editMood = 3
            editCraving = 3
            editNote = ""
        }
    }

    private func saveEdits(dayKey: String) {
        guard let journey else { return }
        let mood = editStatus == .sober ? Int(editMood) : nil
        let craving = editStatus == .sober ? Int(editCraving) : nil
        CheckInService.upsertRecord(
            context, journey: journey, dayKey: dayKey,
            status: editStatus, mood: mood, craving: craving,
            note: editNote, logEdits: true
        )
        _ = CheckInService.recalcAndPublish(context)
        selectedKey = nil
    }

    private func performRestart() {
        guard let journey, let key = selectedKey,
              let date = StreakEngine.date(fromKey: key) else { return }
        journey.startDate = Calendar.current.startOfDay(for: date)
        journey.timezoneID = TimeZone.current.identifier
        _ = CheckInService.recalcAndPublish(context)
        selectedKey = nil
    }
}

struct EditLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var logs: [EditLog]
    let dayKey: String

    var body: some View {
        NavigationStack {
            List {
                let matching = logs.filter { $0.dayKey == dayKey }.sorted { $0.editedAt > $1.editedAt }
                if matching.isEmpty {
                    Text("No edits recorded for this day.")
                        .foregroundStyle(Theme.calmGray)
                }
                ForEach(matching) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(log.field)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("\(log.oldValue) → \(log.newValue)")
                            .font(.subheadline)
                            .foregroundStyle(Theme.calmGray)
                        Text(log.editedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(Theme.calmGray)
                    }
                }
            }
            .background(Theme.nightBase)
            .navigationTitle("Audit trail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
