import Foundation

struct TokenBreakdown: Decodable, Hashable {
    let input: Int
    let output: Int
    let cache_write: Int?   // Claude only
    let cache_read: Int
    let reasoning: Int?     // Codex only

    var total: Int { input + output + (cache_write ?? 0) + cache_read + (reasoning ?? 0) }
}

struct UsageEntry: Decodable, Identifiable {
    let ts: Date
    let session_id: String
    let model: String
    let project: String
    let tokens: TokenBreakdown
    let cost_usd: Double
    var source: String = "claude"   // injected by UsageStore after decode

    enum CodingKeys: String, CodingKey {
        case ts, session_id, model, project, tokens, cost_usd
    }

    var id: String { "\(ts.timeIntervalSince1970)-\(session_id)-\(source)" }

    var projectDisplayName: String {
        guard project != "unknown" else { return "Unknown" }
        return URL(fileURLWithPath: project).lastPathComponent
    }
}

extension JSONDecoder {
    static let usageDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
