import Foundation

struct TokenBreakdown: Decodable, Hashable {
    let input: Int
    let output: Int
    let cache_write: Int
    let cache_read: Int

    var total: Int { input + output + cache_write + cache_read }
}

struct UsageEntry: Decodable, Identifiable {
    let ts: Date
    let session_id: String
    let model: String
    let project: String
    let tokens: TokenBreakdown
    let cost_usd: Double

    var id: String { "\(ts.timeIntervalSince1970)-\(session_id)" }

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
