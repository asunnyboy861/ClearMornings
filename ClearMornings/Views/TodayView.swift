import SwiftUI
import SwiftData
import StoreKit

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Query private var journeys: [Journey]
    @Query private var whys: [WhyItem]
    @Query private var savings: [SavingConfig]
    @Query private var aiMessages: [AIChatMessage]

    @State private var showMornChat = false
    @State private var affirmation: String = ""

    private var journey: Journey? { journeys.first { !$0.isArchived } }
    private var todayKey: String { StreakEngine.dayKey(.now) }
    private var todayRecord: DayRecord? {
        guard let journey else { return nil }
        return CheckInService.record(for: todayKey, journeyID: journey.id, context: context)
    }
    private var streak: StreakResult {
        guard let journey else { return StreakResult(current: 0, unknownGap: 0, totalSoberDays: 0, longestStreak: 0, restarts: 0) }
        let records = CheckInService.fetchRecords(context, journeyID: journey.id)
        var map: [String: DayStatus] = [:]
        for r in records { map[r.dayKey] = r.status }
        return StreakEngine.compute(statuses: map, startDayKey: journey.startDayKey, todayKey: todayKey)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header
                    checkInCard
                    weekStrip
                    affirmationCard
                    savingsCard
                    milestoneCard
                    mornCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 96)
            }
            .background(Theme.nightBase)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.showPaywall = true
                    } label: {
                        Image(systemName: purchaseManager.isPlus ? "crown.fill" : "crown")
                            .foregroundStyle(Theme.dawnGradient)
                    }
                }
            }
        }
        .task {
            affirmation = await AppleFMService.shared.dailyAffirmation(streak: streak.current)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Morning, Day \(streak.current).")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.dawnGradient)
            Text(Date.now.formatted(date: .complete, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(Theme.calmGray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var checkInCard: some View {
        VStack(spacing: 16) {
            if let record = todayRecord, record.status == .sober {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.amber)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today is marked clear")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Tap below to edit how today felt.")
                            .font(.caption)
                            .foregroundStyle(Theme.calmGray)
                    }
                    Spacer()
                }
            } else {
                Text("How is today going?")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            HStack(spacing: 10) {
                statusButton(.sober, label: "Clear", icon: "sun.max.fill")
                statusButton(.skip, label: "Not drinking\nless", icon: "minus.circle")
                statusButton(.slip, label: "Slipped", icon: "heart.slash")
                statusButton(.unknown, label: "Can't say\nyet", icon: "moon.haze")
            }
            if let record = todayRecord, record.status == .sober {
                moodCravingEditor(record: record)
            }
        }
        .padding(20)
        .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 20))
    }

    private func statusButton(_ status: DayStatus, label: String, icon: String) -> some View {
        Button {
            markToday(status)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: status == .unknown ? "moon.haze" : (todayRecord?.status == status ? "checkmark.circle.fill" : icon))
                    .font(.title3)
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                todayRecord?.status == status ? AnyShapeStyle(Theme.dawnGradient) : AnyShapeStyle(Color.white.opacity(0.08)),
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
    }

    private func moodCravingEditor(record: DayRecord) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Mood")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.calmGray)
                Slider(value: Binding(
                    get: { Double(record.mood == 0 ? 3 : record.mood) },
                    set: { v in record.mood = Int(v) }
                ), in: 1...5, step: 1)
                .tint(Theme.dawnStart)
                Text(["Low", "Meh", "Okay", "Good", "Great"][max(0, record.moodValue.map { $0 - 1 } ?? 2)])
                    .font(.caption)
                    .foregroundStyle(.white)
                    .frame(width: 44)
            }
            HStack {
                Text("Craving")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.calmGray)
                Slider(value: Binding(
                    get: { Double(record.craving < 0 ? 3 : record.craving) },
                    set: { v in record.craving = Int(v) }
                ), in: 0...5, step: 1)
                .tint(Theme.seaBlue)
                Text("\(record.craving < 0 ? 3 : record.craving)/5")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .frame(width: 44)
            }
        }
    }

    private var weekStrip: some View {
        HStack(spacing: 8) {
            let snap = AppGroupStore.loadSnapshot()
            ForEach(0..<7, id: \.self) { i in
                let key = StreakEngine.shiftDay(todayKey, by: i - 6)
                let status = snap.statuses[key]
                VStack(spacing: 4) {
                    Text(weekdayLetter(key))
                        .font(.caption2)
                        .foregroundStyle(Theme.calmGray)
                    Circle()
                        .fill(status.map { Theme.statusColor($0) } ?? Color.white.opacity(0.1))
                        .frame(width: 30, height: 30)
                        .overlay {
                            if key == todayKey {
                                Circle().stroke(Theme.amber, lineWidth: 2)
                            }
                        }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 16))
    }

    private func weekdayLetter(_ key: String) -> String {
        guard let date = StreakEngine.date(fromKey: key) else { return "" }
        return date.formatted(.dateTime.weekday(.narrow))
    }

    private var affirmationCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "quote.opening")
                .foregroundStyle(Theme.dawnStart)
            Text(affirmation.isEmpty ? "One day at a time." : affirmation)
                .font(.subheadline.italic())
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(16)
        .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 16))
    }

    private var savingsCard: some View {
        let spend = savings.first?.dailySpend ?? 0
        let saved = SavingsEngine.saved(soberDays: streak.totalSoberDays, dailySpend: spend)
        return Group {
            if spend > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Money reclaimed")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.calmGray)
                        Spacer()
                        Text(String(format: "%.2f %@", saved, savings.first?.currency ?? "USD"))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.dawnStart)
                    }
                    if let conv = SavingsEngine.conversion(for: saved) {
                        HStack(spacing: 8) {
                            Image(systemName: conv.icon)
                                .foregroundStyle(Theme.amber)
                            Text("\(conv.count)× \(conv.label)")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(16)
                .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var milestoneCard: some View {
        Group {
            if let next = MilestoneEngine.nextRecoveryMilestone(after: streak.current) {
                let progress = Double(streak.current) / Double(next.days)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: next.icon)
                            .foregroundStyle(Theme.amber)
                        Text("Next: \(next.title)")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(next.days - streak.current)d to go")
                            .font(.caption)
                            .foregroundStyle(Theme.calmGray)
                    }
                    ProgressView(value: progress)
                        .tint(Theme.dawnGradient)
                    Text(next.detail)
                        .font(.caption)
                        .foregroundStyle(Theme.calmGray)
                }
                .padding(16)
                .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var mornCard: some View {
        Button {
            showMornChat = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.dawnGradient).frame(width: 44, height: 44)
                    Image(systemName: "sparkles").foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Talk to Morn")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("AI craving coach. Free users: \(AIRouter.freeWeeklyChats) deep chats / week.")
                        .font(.caption)
                        .foregroundStyle(Theme.calmGray)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.calmGray)
            }
            .padding(16)
            .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 16))
        }
        .sheet(isPresented: $showMornChat) { MornChatView() }
    }

    private func markToday(_ status: DayStatus) {
        guard let journey else { return }
        CheckInService.upsertRecord(context, journey: journey, dayKey: todayKey, status: status)
        let result = CheckInService.recalcAndPublish(context)
        NotificationService.rescheduleDailyRitual(streak: result?.current ?? 0)
    }
}

struct MornChatView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Query private var whys: [WhyItem]

    @State private var draft = ""
    @State private var messages: [GLMMessage] = []
    @State private var isStreaming = false
    @State private var streamText = ""
    @State private var guardAction: CrisisGuard.Action?

    private var chatContext: AIRouter.ChatContext {
        AIRouter.ChatContext(
            whyTop3: Array(whys.sorted { $0.order < $1.order }.prefix(3).map(\.text)),
            recentMoods: []
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if messages.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "sparkles")
                                        .font(.largeTitle)
                                        .foregroundStyle(Theme.dawnGradient)
                                    Text("I'm Morn. What's going on right now?")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text("Craving, temptation, a rough day — say it like it is.")
                                        .font(.caption)
                                        .foregroundStyle(Theme.calmGray)
                                }
                                .padding(.top, 60)
                            }
                            ForEach(Array(messages.enumerated()), id: \.offset) { _, msg in
                                if msg.role != "system" {
                                    bubble(msg)
                                }
                            }
                            if isStreaming && !streamText.isEmpty {
                                bubble(GLMMessage.assistant(streamText))
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: messages.count) { _, _ in
                        proxy.scrollTo(messages.count - 1, anchor: .bottom)
                    }
                }
                Divider().overlay(Theme.nightCard)
                HStack(spacing: 10) {
                    TextField("Type anything...", text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(10)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                    Button {
                        send()
                    } label: {
                        Image(systemName: isStreaming ? "stop.fill" : "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.dawnGradient)
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty && !isStreaming)
                }
                .padding(12)
            }
            .background(Theme.nightBase)
            .navigationTitle("Morn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("You're not alone", isPresented: Binding(
                get: { guardAction != nil },
                set: { if !$0 { guardAction = nil } }
            )) {
                Button("Call 988") {
                    if let url = URL(string: "tel:988") { UIApplication.shared.open(url) }
                    guardAction = nil
                }
                Button("Close", role: .cancel) { guardAction = nil }
            } message: {
                Text("If you're thinking of harming yourself, please reach the 988 Suicide & Crisis Lifeline now. SAMHSA National Helpline: 1-800-662-4357.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func bubble(_ msg: GLMMessage) -> some View {
        HStack {
            if msg.role == "user" { Spacer(minLength: 40) }
            Text(msg.text)
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(12)
                .background(
                    msg.role == "user" ? AnyShapeStyle(Theme.seaBlue.opacity(0.35)) : AnyShapeStyle(Theme.nightCard),
                    in: RoundedRectangle(cornerRadius: 14)
                )
            if msg.role != "user" { Spacer(minLength: 40) }
        }
        .id(msg.text.hashValue)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }
        draft = ""

        switch CrisisGuard.screen(text) {
        case .hotline988:
            messages.append(GLMMessage.user(text))
            guardAction = .hotline988
            return
        case .medicalFirst:
            messages.append(GLMMessage.user(text))
            messages.append(GLMMessage.assistant("Sudden alcohol withdrawal can be dangerous — please contact a doctor or urgent care first. I'm here with you meanwhile."))
            return
        case .proceed:
            break
        }

        messages.append(GLMMessage.user(text))
        let routerAI = AIRouter.shared
        if !purchaseManager.isPlus && !routerAI.canUseDeepChat {
            messages.append(GLMMessage.assistant("You've used your \(AIRouter.freeWeeklyChats) deep chats this week. Clear+ unlocks unlimited coaching."))
            router.showPaywall = true
            return
        }
        if !routerAI.canUseDeepChat {
            messages.append(GLMMessage.assistant("To chat with me, add your own GLM key in Settings (AI section) or subscribe to Clear+."))
            return
        }

        isStreaming = true
        streamText = ""
        Task {
            do {
                let stream = routerAI.streamChat(messages: messages, context: chatContext)
                for try await chunk in stream {
                    streamText += chunk
                }
                if streamText.isEmpty {
                    let reply = try await routerAI.deepChat(messages: messages, context: chatContext)
                    messages.append(GLMMessage.assistant(reply))
                } else {
                    messages.append(GLMMessage.assistant(streamText))
                }
            } catch {
                messages.append(GLMMessage.assistant("I couldn't reach the cloud just now. Try again in a moment — and if it's urgent, the wave timer and your why-wall are right here."))
            }
            streamText = ""
            isStreaming = false
            persistChat()
        }
    }

    private func persistChat() {
        let sessionID = "chat-" + StreakEngine.dayKey(.now)
        for msg in messages where msg.role != "system" {
            context.insert(AIChatMessage(sessionID: sessionID, role: msg.role, text: msg.text, modelUsed: "glm-5.3-flash"))
        }
        try? context.save()
    }
}
