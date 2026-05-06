import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: UsageStore
    @State private var selectedKind: TimeRangeKind = .week
    @State private var window: TimeWindow = .current(kind: .week)
    @State private var selectedProject: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TimeRangePicker(selectedKind: $selectedKind)
                    .onChange(of: selectedKind) { _, kind in
                        window = .current(kind: kind)
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

            NavigationBar(window: $window)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            Divider()

            if store.isLoaded {
                BarChartView(
                    entries: store.filteredEntries(window: window, project: selectedProject),
                    window: window
                )
                .padding(16)
                .gesture(
                    DragGesture(minimumDistance: 40)
                        .onEnded { value in
                            if value.translation.width < -40 {
                                window = window.navigated(by: +1)
                            } else if value.translation.width > 40 {
                                window = window.navigated(by: -1)
                            }
                        }
                )
            } else {
                ProgressView("Loading usage data…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}
