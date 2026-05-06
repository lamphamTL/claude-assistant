import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: UsageStore
    @State private var selectedKind: TimeRangeKind = .week
    @State private var scrollDate: Date = Self.initialScrollDate(for: .week)
    @State private var selectedProject: String? = nil
    @State private var isHovering = false

    var body: some View {
        ZStack {
            // Glass background
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
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
                    Text("Token Usage")
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
                .padding(.top, 14)
                .padding(.bottom, 8)

                // ── Project filter (only if multiple projects) ────────────
                if !store.knownProjects.isEmpty {
                    HStack {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Picker("", selection: $selectedProject) {
                            Text("All projects").tag(String?.none)
                            ForEach(store.knownProjects, id: \.self) { path in
                                Text(URL(fileURLWithPath: path).lastPathComponent)
                                    .tag(Optional(path))
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.system(size: 11))
                        .labelsHidden()
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
                }

                // ── Nav bar ───────────────────────────────────────────────
                CompactNavigationBar(
                    scrollDate: $scrollDate,
                    kind: selectedKind,
                    visibleDuration: visibleDuration
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 10)

                // ── Chart ─────────────────────────────────────────────────
                if store.isLoaded {
                    BarChartView(
                        entries: projectFilteredEntries,
                        kind: selectedKind,
                        scrollDate: $scrollDate
                    )
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.bottom, 14)
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

    private var projectFilteredEntries: [UsageEntry] {
        guard let proj = selectedProject else { return store.entries }
        return store.entries.filter { $0.project == proj }
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
