import Foundation
import Combine

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var entries: [UsageEntry] = []
    @Published private(set) var isLoaded = false

    private var claudeWatcher: FileWatcher?
    private var codexWatcher: FileWatcher?
    private var claudeLineBuffer = ""
    private var codexLineBuffer = ""

    nonisolated static let home = FileManager.default.homeDirectoryForCurrentUser

    nonisolated init() {}
    nonisolated static let claudeURL: URL = home.appendingPathComponent(".claude/token-usage/usage.jsonl")
    nonisolated static let codexURL:  URL = home.appendingPathComponent(".codex/token-usage/usage.jsonl")

    func load() {
        let cw = FileWatcher(url: UsageStore.claudeURL)
        cw.onNewData = { [weak self] data in
            Task { @MainActor [weak self] in self?.ingest(data: data, source: "claude") }
        }
        let claudeInitial = cw.start()
        claudeWatcher = cw

        let dw = FileWatcher(url: UsageStore.codexURL)
        dw.onNewData = { [weak self] data in
            Task { @MainActor [weak self] in self?.ingest(data: data, source: "codex") }
        }
        let codexInitial = dw.start()
        codexWatcher = dw

        ingest(data: claudeInitial, source: "claude")
        ingest(data: codexInitial, source: "codex")
        isLoaded = true
    }

    private func ingest(data: Data, source: String) {
        guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }

        let combined = (source == "claude" ? claudeLineBuffer : codexLineBuffer) + chunk
        var lines = combined.components(separatedBy: "\n")
        let remainder = lines.removeLast()
        if source == "claude" { claudeLineBuffer = remainder } else { codexLineBuffer = remainder }

        let decoder = JSONDecoder.usageDecoder
        let newEntries = lines
            .filter { !$0.isEmpty }
            .compactMap { line -> UsageEntry? in
                guard let d = line.data(using: .utf8),
                      var entry = try? decoder.decode(UsageEntry.self, from: d) else { return nil }
                entry.source = source
                return entry
            }

        guard !newEntries.isEmpty else { return }
        entries.append(contentsOf: newEntries)
        entries.sort { $0.ts < $1.ts }
    }

    var knownProjects: [String] {
        Array(Set(entries.map(\.project)))
            .filter { $0 != "unknown" }
            .sorted {
                URL(fileURLWithPath: $0).lastPathComponent
                    < URL(fileURLWithPath: $1).lastPathComponent
            }
    }

    func filteredEntries(window: TimeWindow, project: String?, source: String?) -> [UsageEntry] {
        entries.filter { entry in
            guard entry.ts >= window.start && entry.ts < window.end else { return false }
            if let proj = project, entry.project != proj { return false }
            if let src  = source,  entry.source  != src  { return false }
            return true
        }
    }
}
