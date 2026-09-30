import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class AppleFMService {
    static let shared = AppleFMService()

    static var foundationModelsAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    func reply(to messages: [GLMMessage], kind: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), Self.foundationModelsAvailable {
            return await replyWithFM(messages: messages, kind: kind)
        }
        #endif
        return nil
    }

    func dailyAffirmation(streak: Int) async -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), Self.foundationModelsAvailable {
            let prompt = """
            Write one warm affirmation (max 18 words) for someone on day \(streak) of quitting alcohol. \
            Focus on the reward of a clear morning. No clichés, no emoji.
            """
            if let text = await generate(prompt: prompt) {
                return text
            }
        }
        #endif
        return RuleEngine.affirmation(streak: streak)
    }

    func journalSummary(_ text: String) async -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), Self.foundationModelsAvailable {
            let prompt = "Summarize this journal entry in one gentle sentence (max 15 words): \(text)"
            if let result = await generate(prompt: prompt) {
                return result
            }
        }
        #endif
        return RuleEngine.journalSummary(text)
    }

    func sosSteps(cravingLevel: Int) async -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), Self.foundationModelsAvailable {
            let prompt = """
            Give 3 very short steps (one line each, max 8 words per line) to ride out a craving \
            of intensity \(cravingLevel)/5. Warm, direct, no medical advice.
            """
            if let text = await generate(prompt: prompt) {
                return text
            }
        }
        #endif
        return RuleEngine.sosSteps
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func generate(prompt: String) async -> String? {
        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    @available(iOS 26.0, *)
    private func replyWithFM(messages: [GLMMessage], kind: String) async -> String? {
        let last = messages.last?.text ?? ""
        let prompt = "Reply warmly in max 120 words. The person says: \(last)"
        return await generate(prompt: prompt)
    }
    #endif
}

enum RuleEngine {
    static let affirmations = [
        "You woke up clear today. That was the whole win.",
        "Day by day, your mornings are becoming yours again.",
        "The wave always passes. You have proven that before.",
        "Clear eyes, quiet head, one more honest day.",
        "You are not missing out. You are showing up.",
        "Rest is progress too. Let today be easy.",
        "Your future self is already thanking you.",
        "One decision, repeated. That is all strength is."
    ]

    static let sosSteps = "1. Breathe with the circle for 60 seconds.\n2. Read one reason from your wall.\n3. Start the 10-minute wave timer."

    static func affirmation(streak: Int) -> String {
        affirmations[abs(streak) % affirmations.count]
    }

    static func journalSummary(_ text: String) -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return "" }
        let words = clean.split(separator: " ")
        if words.count <= 12 { return clean }
        return words.prefix(12).joined(separator: " ") + "…"
    }

    static func reply(to text: String) -> String {
        let lowered = text.lowercased()
        if lowered.contains("craving") || lowered.contains("want to drink") || lowered.contains("urge") {
            return "That wave is real, and it will pass — most fade within 10 minutes. Breathe with me for one minute, then read one reason from your wall. I'm right here."
        }
        if lowered.contains("slip") || lowered.contains("drank") || lowered.contains("relapse") {
            return "Data, not a verdict. Your total days are still yours — nothing is erased. What happened right before, and how were you feeling?"
        }
        if lowered.contains("tired") || lowered.contains("hard") {
            return "Days like this are the quiet proof of the work. Rest counts as showing up. Tomorrow's morning is already being earned."
        }
        return "I hear you. Take one slow breath with me. What would make the next ten minutes a little softer?"
    }
}
