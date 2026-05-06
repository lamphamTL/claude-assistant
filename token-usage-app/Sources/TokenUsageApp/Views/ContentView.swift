import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: UsageStore
    @State private var selectedKind: TimeRangeKind = .week
    @State private var scrollDate: Date = Self.initialScrollDate(for: .week)
    @State private var selectedProject: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TimeRangePicker(selectedKind: $selectedKind)
                    .onChange(of: selectedKind) { _, kind in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            scrollDate = Self.initialScrollDate(for: kind)
                        }
                        selectedProject = nil
                    }
                Spacer()
                ProjectFilterPicker(
                    projects: store.knownProjects,
                    selectedProject: $selectedProject
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            NavigationBar(
                scrollDate: $scrollDate,
                kind: selectedKind,
                visibleDuration: visibleDuration
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            if store.isLoaded {
                BarChartView(
                    entries: projectFilteredEntries,
                    kind: selectedKind,
                    scrollDate: $scrollDate
                )
                .padding(16)
            } else {
                ProgressView("Loading usage data…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
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
