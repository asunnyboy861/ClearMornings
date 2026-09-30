import Foundation
import StoreKit

enum GLMError: LocalizedError {
    case notConfigured
    case network(Int)
    case rateLimited
    case invalidKey
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "The AI service is not configured yet."
        case .network(let code): return "Network error (\(code)). Please try again."
        case .rateLimited: return "Too many requests. Try again in a little while."
        case .invalidKey: return "That API key didn't work. Please double-check it."
        case .emptyResponse: return "The coach didn't respond. Please try again."
        }
    }
}

struct GLMMessage {
    var role: String
    var text: String
    var imageBase64: [String] = []

    static func system(_ text: String) -> GLMMessage { GLMMessage(role: "system", text: text) }
    static func user(_ text: String) -> GLMMessage { GLMMessage(role: "user", text: text) }
    static func assistant(_ text: String) -> GLMMessage { GLMMessage(role: "assistant", text: text) }
}

struct GLMClient {
    static let proxyURL = URL(string: "https://cramjam-api.calcs.top")!
    static let proxyBackupURL = URL(string: "https://cramjam-proxy.iocompile67692.workers.dev")!
    static let zaiURL = URL(string: "https://api.z.ai/api/paas/v4/chat/completions")!
    static let bigmodelURL = URL(string: "https://open.bigmodel.cn/api/paas/v4/chat/completions")!
    static let appID = "clearmornings"
    static let model = "glm-5.3-flash"

    enum Mode {
        case builtIn
        case byo(key: String)
    }

    let mode: Mode

    static var devKey: String? {
        guard let url = Bundle.main.url(forResource: "GLMProxySecret", withExtension: "txt"),
              let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        for line in raw.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2, parts[0] == "devKey", !parts[1].isEmpty {
                return parts[1]
            }
        }
        return nil
    }

    static var builtInAvailable: Bool { devKey != nil }

    /// StoreKit 2 signed entitlement JWS for the proxy (production channel).
    /// The JWS lives on the VerificationResult, NOT on the Transaction.
    /// Covers both subscriptions (pro_monthly/yearly) and the BYO non-consumable (pro_lifetime).
    static func currentEntitlementJWS() async -> String? {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result,
                  tx.revocationDate == nil,
                  tx.productType == .autoRenewable || tx.productType == .nonConsumable else { continue }
            return result.jwsRepresentation
        }
        return nil
    }

    struct SSEChunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable { var content: String? }
            var delta: Delta
        }
        var choices: [Choice]
    }

    struct CompletionResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { var content: String? }
            var message: Message
        }
        var choices: [Choice]
    }

    private func payloadBody(messages: [GLMMessage], maxTokens: Int, temperature: Double) -> [String: Any] {
        let payload: [String: Any] = [
            "model": Self.model,
            "messages": Self.encode(messages: messages),
            "thinking": ["level": "low"],
            "max_tokens": maxTokens,
            "temperature": temperature
        ]
        return payload
    }

    static func encode(messages: [GLMMessage]) -> [[String: Any]] {
        messages.map { msg in
            if msg.imageBase64.isEmpty {
                return ["role": msg.role, "content": msg.text]
            }
            var parts: [[String: Any]] = msg.imageBase64.map {
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\($0)"]]
            }
            if !msg.text.isEmpty {
                parts.append(["type": "text", "text": msg.text])
            }
            return ["role": msg.role, "content": parts]
        }
    }

    func generate(messages: [GLMMessage], maxTokens: Int = 4096, temperature: Double = 0.3) async throws -> String {
        switch mode {
        case .builtIn:
            return try await generateViaProxy(messages: messages, maxTokens: maxTokens, temperature: temperature, url: Self.proxyURL)
        case .byo(let key):
            let body: [String: Any] = [
                "model": Self.model,
                "messages": Self.encode(messages: messages),
                "thinking": ["level": "low"],
                "max_tokens": maxTokens,
                "temperature": temperature
            ]
            let content = try await requestOnce(url: Self.zaiURL, body: body, bearer: key)
            return content
        }
    }

    private func generateViaProxy(messages: [GLMMessage], maxTokens: Int, temperature: Double, url: URL) async throws -> String {
        var body: [String: Any] = [
            "appId": Self.appID,
            "userId": KeychainStore.userId(),
            "payload": payloadBody(messages: messages, maxTokens: maxTokens, temperature: temperature)
        ]
        // Credential priority: devKey (test period) -> subscription JWS (production)
        if let devKey = Self.devKey {
            body["devKey"] = devKey
        } else if let jws = await Self.currentEntitlementJWS() {
            body["appTransaction"] = jws
        } else {
            throw GLMError.notConfigured
        }
        do {
            return try await requestOnce(url: url, body: body, bearer: nil)
        } catch let error as GLMError {
            switch error {
            case .network(let code) where code >= 500 || code == 0, .emptyResponse:
                return try await requestOnce(url: Self.proxyBackupURL, body: body, bearer: nil)
            default:
                throw error
            }
        }
    }

    private func requestOnce(url: URL, body: [String: Any], bearer: String?) async throws -> String {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 45
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearer {
            req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            if status == 429 { throw GLMError.rateLimited }
            if status == 401 { throw GLMError.invalidKey }
            throw GLMError.network(status)
        }
        let decoded = try JSONDecoder().decode(CompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
            throw GLMError.emptyResponse
        }
        return content
    }

    func stream(messages: [GLMMessage], maxTokens: Int = 4096) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { cont in
            Task {
                do {
                    guard case .byo(let key) = mode else {
                        let full = try await generate(messages: messages, maxTokens: maxTokens)
                        cont.yield(full)
                        cont.finish()
                        return
                    }
                    var req = URLRequest(url: Self.zaiURL)
                    req.httpMethod = "POST"
                    req.timeoutInterval = 60
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                    let body: [String: Any] = [
                        "model": Self.model,
                        "messages": Self.encode(messages: messages),
                        "thinking": ["level": "low"],
                        "max_tokens": maxTokens,
                        "stream": true
                    ]
                    req.httpBody = try JSONSerialization.data(withJSONObject: body)
                    let (bytes, resp) = try await URLSession.shared.bytes(for: req)
                    let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
                    guard status == 200 else {
                        if status == 429 { throw GLMError.rateLimited }
                        if status == 401 { throw GLMError.invalidKey }
                        throw GLMError.network(status)
                    }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: "), line != "data: [DONE]" else { continue }
                        if let data = String(line.dropFirst(6)).data(using: .utf8),
                           let chunk = try? JSONDecoder().decode(SSEChunk.self, from: data),
                           let token = chunk.choices.first?.delta.content, !token.isEmpty {
                            cont.yield(token)
                        }
                    }
                    cont.finish()
                } catch {
                    cont.finish(throwing: error)
                }
            }
        }
    }

    static func ping(key: String) async -> Bool {
        let client = GLMClient(mode: .byo(key: key))
        do {
            let reply = try await client.generate(
                messages: [GLMMessage.user("Reply with the single word: ok")],
                maxTokens: 4096
            )
            return !reply.isEmpty
        } catch {
            return false
        }
    }
}
