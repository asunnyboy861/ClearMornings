import Foundation

enum QuotaStore {
    static func weekKey() -> String {
        let cal = Calendar.current
        let week = cal.component(.weekOfYear, from: .now)
        let year = cal.component(.yearForWeekOfYear, from: .now)
        return "\(year)-W\(week)"
    }

    static func monthKey() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM"
        return df.string(from: .now)
    }

    static func deepChatsThisWeek() -> Int {
        let store = UserDefaults.standard
        if store.string(forKey: "quota.week.key") != weekKey() {
            store.set(weekKey(), forKey: "quota.week.key")
            store.set(0, forKey: "quota.week.chats")
            return 0
        }
        return store.integer(forKey: "quota.week.chats")
    }

    static func recordDeepChat() {
        _ = deepChatsThisWeek()
        let store = UserDefaults.standard
        store.set(deepChatsThisWeek() + 1, forKey: "quota.week.chats")
    }

    static func reportsThisMonth() -> Int {
        let store = UserDefaults.standard
        if store.string(forKey: "quota.month.key") != monthKey() {
            store.set(monthKey(), forKey: "quota.month.key")
            store.set(0, forKey: "quota.month.reports")
            return 0
        }
        return store.integer(forKey: "quota.month.reports")
    }

    static func recordReport() {
        _ = reportsThisMonth()
        let store = UserDefaults.standard
        store.set(reportsThisMonth() + 1, forKey: "quota.month.reports")
    }
}

@MainActor
final class AIRouter: ObservableObject {
    static let shared = AIRouter()
    static let freeWeeklyChats = 3
    static let freeMonthlyReports = 1
    static let fairUseDailyChats = 500

    @Published var isUsingFallbackNotice: Bool = false

    private var purchaseManager = PurchaseManager.shared

    var canUseDeepChat: Bool {
        guard Self.builtInConfigured || KeychainStore.byoKey != nil else { return false }
        if purchaseManager.isPro { return true }
        return QuotaStore.deepChatsThisWeek() < Self.freeWeeklyChats
    }

    var canUseReport: Bool {
        guard Self.builtInConfigured || KeychainStore.byoKey != nil else { return false }
        if purchaseManager.isPro { return true }
        return QuotaStore.reportsThisMonth() < Self.freeMonthlyReports
    }

    var deepChatsRemainingForFree: Int {
        max(0, Self.freeWeeklyChats - QuotaStore.deepChatsThisWeek())
    }

    static var builtInConfigured: Bool { GLMClient.builtInAvailable }

    private func makeClient() -> GLMClient {
        if let key = KeychainStore.byoKey, !key.isEmpty {
            return GLMClient(mode: .byo(key: key))
        }
        return GLMClient(mode: .builtIn)
    }

    struct ChatContext {
        var whyTop3: [String] = []
        var recentMoods: [String] = []
    }

    func systemPrompt(context: ChatContext, kind: String) -> String {
        var prompt = """
        You are Morn, a warm sober companion inside the Clear Mornings app. \
        Tone: warm, brief (max 120 words), never judgmental, never preachy. \
        Never give medical or medication advice, never diagnose, never call the user an alcoholic. \
        If the user mentions shaking, sweating, hallucinations or withdrawal symptoms, first say they should contact a doctor because sudden alcohol withdrawal can be dangerous, then keep company. \
        If the user expresses thoughts of self-harm or suicide, stop and gently share the 988 Suicide & Crisis Lifeline and SAMHSA 1-800-662-4357.
        """
        if !context.whyTop3.isEmpty {
            prompt += "\nTheir reasons for quitting: \(context.whyTop3.joined(separator: "; "))."
        }
        if !context.recentMoods.isEmpty {
            prompt += "\nRecent moods: \(context.recentMoods.joined(separator: ", "))."
        }
        if kind == "tripwire" {
            prompt += "\nTask: write ONE short sentence (max 15 words) naming a likely trigger trap and how to step around it. No quotes."
        }
        if kind == "report" {
            prompt += "\nTask: a gentle weekly review. 3 short bullet-style lines: a win, a pattern, one small suggestion. Max 90 words."
        }
        return prompt
    }

    func deepChat(messages: [GLMMessage], context: ChatContext) async throws -> String {
        guard canUseDeepChat else { throw GLMError.rateLimited }
        var full: [GLMMessage] = [GLMMessage.system(systemPrompt(context: context, kind: "chat"))]
        full.append(contentsOf: messages)
        let client = makeClient()
        do {
            let reply = try await client.generate(messages: full, maxTokens: 4096)
            if !purchaseManager.isPro { QuotaStore.recordDeepChat() }
            isUsingFallbackNotice = false
            return reply
        } catch {
            let fallback = try await fallbackReply(messages: full)
            isUsingFallbackNotice = true
            return fallback
        }
    }

    func streamChat(messages: [GLMMessage], context: ChatContext) -> AsyncThrowingStream<String, Error> {
        var full: [GLMMessage] = [GLMMessage.system(systemPrompt(context: context, kind: "chat"))]
        full.append(contentsOf: messages)
        let client = makeClient()
        return client.stream(messages: full, maxTokens: 4096)
    }

    func weeklyReport(summary: String, context: ChatContext) async throws -> String {
        guard canUseReport else { throw GLMError.rateLimited }
        let full: [GLMMessage] = [
            GLMMessage.system(systemPrompt(context: context, kind: "report")),
            GLMMessage.user(summary)
        ]
        let client = makeClient()
        do {
            let reply = try await client.generate(messages: full, maxTokens: 4096)
            if !purchaseManager.isPro { QuotaStore.recordReport() }
            return reply
        } catch {
            isUsingFallbackNotice = true
            return try await fallbackReply(messages: full)
        }
    }

    func tripwire(afterSlip context: ChatContext) async -> String {
        let full: [GLMMessage] = [
            GLMMessage.system(systemPrompt(context: context, kind: "tripwire")),
            GLMMessage.user("I slipped today. Help me name my next trap.")
        ]
        let client = makeClient()
        if let reply = try? await client.generate(messages: full, maxTokens: 4096), !reply.isEmpty {
            return reply
        }
        return "Notice the hour and the feeling that usually walks in first — plan a 10-minute detour."
    }

    func mirrorCompare(day1JPEG: Data, todayJPEG: Data, dayNumber: Int) async throws -> String {
        let system = """
        You are Morn, a warm sober companion. Compare two face photos (day 1 vs today, day \(dayNumber)). \
        Output 3 gentle observations about skin clarity, under-eye brightness, overall restedness. \
        No medical claims. Max 80 words.
        """
        let msg = GLMMessage(
            role: "user",
            text: "Day 1 vs Day \(dayNumber)",
            imageBase64: [day1JPEG.base64EncodedString(), todayJPEG.base64EncodedString()]
        )
        let client = makeClient()
        return try await client.generate(
            messages: [GLMMessage.system(system), msg],
            maxTokens: 8192
        )
    }

    private func fallbackReply(messages: [GLMMessage]) async throws -> String {
        if let reply = await AppleFMService.shared.reply(to: messages, kind: "chat") {
            return reply
        }
        let last = messages.last?.text ?? ""
        return RuleEngine.reply(to: last)
    }
}
