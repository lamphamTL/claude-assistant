import Foundation
import Combine

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var entries: [UsageEntry] = []
    @Published private(set) var isLoaded = false

    private let fileURL: URL
    private var watcher: FileWatcher?
    private var lineBuffer = ""

    nonisolated static let defaultURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/token-usage/usage.jsonl")

    nonisolated init(url: URL = UsageStore.defaultURL) {
        self.fileURL = url
    }

    func load() {
        let watcher = FileWatcher(url: fileURL)
        watcher.onNewData = { [weak self] data in
            Task { @MainActor [weak self] in self?.ingest(data: data) }
        }
        let initial = watcher.start()
        self.watcher = watcher
        ingest(data: initial)
        isLoaded = true
    }

    private func ingest(data: Data) {
        guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }

        let combined = lineBuffer + chunk
        var lines = combined.components(separatedBy: "\n")
        lineBuffer = lines.removeLast()

        let decoder = JSONDecoder.usageDecoder
        let newEntries = lines
            .filter { !$0.isEmpty }
            .compactMap { line -> UsageEntry? in
                guard let d = line.data(using: .utf8) else { return nil }
                return try? decoder.decode(UsageEntry.self, from: d)
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

    func filteredEntries(window: TimeWindow, project: String?) -> [UsageEntry] {
        entries.filter { entry in
            guard entry.ts >= window.start && entry.ts < window.end else { return false }
            if let proj = project { return entry.project == proj }
            return true
        }
    }
}
