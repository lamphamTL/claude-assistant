import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: UsageStore
    @State private var selectedKind: TimeRangeKind = .week
    @State private var scrollDate: Date = Self.initialScrollDate(for: .week)
    @State private var selectedProject: String? = nil
    @State private var selectedSource: String? = nil
    @State private var isHovering = false

    private let sources = [("All", String?.none), ("Claude", "claude"), ("Codex", "codex")]

    var body: some View {
        ZStack {
            // Glass background
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.35), .white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 8)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

            VStack(spacing: 0) {
                // ── Header ───────────────────────────────────────────────
                HStack(alignment: .center, spacing: 8) {
                    Text("AI Usage")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.8))

                    Spacer()

                    // Range picker – compact segmented
                    HStack(spacing: 2) {
                        ForEach(TimeRangeKind.allCases) { kind in
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedKind = kind
                                    scrollDate = Self.initialScrollDate(for: kind)
                                    selectedProject = nil
                                }
                            } label: {
                                Text(kind.rawValue)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        selectedKind == kind
                                            ? Color.primary.opacity(0.12)
                                            : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    )
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(selectedKind == kind ? .primary : .secondary)
                        }
                    }
                    .padding(3)
                    .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                    // Close
                    Button {
                        NSApp.terminate(nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary.opacity(isHovering ? 0.9 : 0.4))
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovering = $0 }
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, 2)

                // ── Source picker ─────────────────────────────────────────
                HStack(spacing: 2) {
                    ForEach(sources, id: \.0) { label, value in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedSource = value
                                selectedProject = nil
                            }
                        } label: {
                            Text(label)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    selectedSource == value
                                        ? Color.primary.opacity(0.12)
                                        : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(selectedSource == value ? .primary : .secondary)
                    }
                }
                .padding(3)
                .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .padding(.horizontal, 14)
                .padding(.bottom, 4)

                // ── Project filter (only if multiple projects) ────────────
                if !sourceFilteredProjects.isEmpty {
                    HStack {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Picker("", selection: $selectedProject) {
                            Text("All projects").tag(String?.none)
                            ForEach(sourceFilteredProjects, id: \.self) { path in
                                Text(URL(fileURLWithPath: path).lastPathComponent)
                                    .tag(Optional(path))
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.system(size: 11))
                        .labelsHidden()
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)
                }

                // ── Weekly credit tracker (Codex only) ───────────────────
                if selectedSource == "codex" {
                    let used   = store.weeklyCodexCredits
                    let limit  = 1000.0
                    let pct    = min(used / limit, 1.0)
                    let color: Color = pct >= 0.9 ? .red : pct >= 0.7 ? .yellow : .green
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("Weekly credits")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f / 1000", used))
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(color)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(.primary.opacity(0.08))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(color.opacity(0.8))
                                    .frame(width: geo.size.width * pct)
                            }
                        }
                        .frame(height: 4)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
                }

                // ── Nav bar ───────────────────────────────────────────────
                CompactNavigationBar(
                    scrollDate: $scrollDate,
                    kind: selectedKind,
                    visibleDuration: visibleDuration,
                    minDate: store.entries.first?.ts ?? Date()
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 4)

                // ── Chart ─────────────────────────────────────────────────
                if store.isLoaded {
                    BarChartView(
                        data: chartData,
                        kind: selectedKind,
                        scrollDate: scrollDate,
                        scrollDateBinding: $scrollDate,
                        showCredits: selectedSource == "codex"
                    )
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(width: 320)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var visibleDuration: TimeInterval {
        switch selectedKind {
        case .day:   return 7  * 24 * 3600
        case .week:  return 5  * 7  * 24 * 3600
        case .month: return 5  * 31 * 24 * 3600
        }
    }

    // Source+project filtered slice — uses pre-indexed store caches
    private var filteredEntries: [UsageEntry] {
        let base: [UsageEntry]
        if let src = selectedSource {
            base = store.entriesBySource[src] ?? []
        } else {
            base = store.entries
        }
        guard let proj = selectedProject else { return base }
        return base.filter { $0.project == proj }
    }

    // Time-window slice via binary search — O(log n + k)
    private var visibleEntries: [UsageEntry] {
        let entries = filteredEntries
        guard !entries.isEmpty else { return [] }
        let end = scrollDate.addingTimeInterval(visibleDuration)
        let lo = lowerBound(entries, target: scrollDate)
        let hi = lowerBound(entries, target: end)
        guard lo < hi else { return [] }
        return Array(entries[lo..<hi])
    }

    private func lowerBound(_ entries: [UsageEntry], target: Date) -> Int {
        var lo = 0, hi = entries.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if entries[mid].ts < target { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }

    // Pre-bucketed chart data — only 5-7 ChartPoints passed to BarChartView
    private var chartData: ChartData {
        let visible = visibleEntries
        guard !visible.isEmpty else { return .empty }

        let calendar = Calendar.current
        let component = selectedKind.bucketComponent
        let multiSource = Set(visible.map(\.source)).count > 1

        var grouped: [Date: [String: (cost: Double, tokens: Int, source: String)]] = [:]
        var bucketCounts: [Date: Int] = [:]
        var bucketCredits: [Date: Double] = [:]

        for entry in visible {
            guard let interval = calendar.dateInterval(of: component, for: entry.ts) else { continue }
            let bucket = interval.start
            let proj = entry.projectDisplayName
            let key = multiSource ? "\(proj) (\(entry.source))" : proj
            let prev = grouped[bucket]?[key] ?? (cost: 0, tokens: 0, source: entry.source)
            grouped[bucket, default: [:]][key] = (
                cost:   prev.cost + entry.cost_usd,
                tokens: prev.tokens + entry.tokens.total,
                source: entry.source
            )
            bucketCounts[bucket, default: 0] += 1
            if let cr = entry.credits { bucketCredits[bucket, default: 0] += cr }
        }

        var points: [ChartPoint] = []
        for (date, projects) in grouped {
            for (key, agg) in projects {
                points.append(ChartPoint(bucketDate: date, project: key, source: agg.source,
                                         cost: agg.cost, totalTokens: agg.tokens))
            }
        }
        points.sort { $0.bucketDate == $1.bucketDate ? $0.project < $1.project : $0.bucketDate < $1.bucketDate }

        return ChartData(
            points: points,
            totalCost: visible.reduce(0) { $0 + $1.cost_usd },
            totalCredits: visible.compactMap(\.credits).reduce(0, +),
            totalEntries: visible.count,
            bucketCounts: bucketCounts,
            bucketCredits: bucketCredits
        )
    }

    private var sourceFilteredProjects: [String] {
        if let src = selectedSource {
            return store.projectsBySource[src] ?? []
        }
        let all = store.projectsBySource.values.flatMap { $0 }
        return Array(Set(all)).sorted {
            URL(fileURLWithPath: $0).lastPathComponent < URL(fileURLWithPath: $1).lastPathComponent
        }
    }

    private static func initialScrollDate(for kind: TimeRangeKind) -> Date {
        let duration: TimeInterval
        switch kind {
        case .day:   duration = 7  * 24 * 3600
        case .week:  duration = 5  * 7  * 24 * 3600
        case .month: duration = 5  * 31 * 24 * 3600
        }
        return Date().addingTimeInterval(-duration)
    }
}
