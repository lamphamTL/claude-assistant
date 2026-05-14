import SwiftUI
import Charts

struct ChartPoint: Identifiable {
    var id: String { "\(bucketDate.timeIntervalSinceReferenceDate)-\(project)-\(source)" }
    let bucketDate: Date
    let project: String
    let source: String
    let cost: Double
    let totalTokens: Int
}

// Pre-computed chart data passed from ContentView — no raw entries inside BarChartView
struct ChartData {
    let points: [ChartPoint]
    let totalCost: Double
    let totalCredits: Double        // 0 for Claude (no credits field)
    let totalEntries: Int
    let bucketCounts: [Date: Int]
    let bucketCredits: [Date: Double]

    static let empty = ChartData(points: [], totalCost: 0, totalCredits: 0,
                                 totalEntries: 0, bucketCounts: [:], bucketCredits: [:])
}

struct BarChartView: View {
    let data: ChartData
    let kind: TimeRangeKind
    let barCount: Int
    let scrollDate: Date            // for x-axis domain
    @Binding var scrollDateBinding: Date
    let projectColors: [String: Int]
    var showCredits: Bool = false
    var showEfficiency: Bool = false

    @Environment(\.displayMode) private var displayMode

    private var chartMinHeight: CGFloat { 150 }
    private var chartMaxHeight: CGFloat { displayMode == .window ? 280 : 150 }

    private static let palette: [Color] = [
        .blue, .purple, .orange, .teal, .pink, .indigo, .mint
    ]

    // Strip " (claude)" / " (codex)" suffix that's appended when the visible
    // window spans multiple sources, so colour lookup keys to the base project.
    private static let sourceSuffixes = [" (claude)", " (codex)"]
    private func baseProjectKey(_ key: String) -> String {
        for suffix in Self.sourceSuffixes where key.hasSuffix(suffix) {
            return String(key.dropLast(suffix.count))
        }
        return key
    }

    private func colorFor(_ projectKey: String) -> Color {
        let base = baseProjectKey(projectKey)
        if let idx = projectColors[base] {
            return Self.palette[idx % Self.palette.count]
        }
        return Self.palette[abs(base.hashValue) % Self.palette.count]
    }

    @State private var selectedBucket: Date? = nil

    private var barDuration: TimeInterval {
        switch kind {
        case .day:   return 24 * 3600
        case .week:  return 7  * 24 * 3600
        case .month: return 31 * 24 * 3600
        }
    }

    private var visibleDuration: TimeInterval {
        Double(max(barCount, 1)) * barDuration
    }

    private var visibleEnd: Date { scrollDate.addingTimeInterval(visibleDuration) }

    // One bar per bucket: total cost / event count
    private var efficiencyPoints: [ChartPoint] {
        var bucketCosts: [Date: Double] = [:]
        for point in data.points {
            bucketCosts[point.bucketDate, default: 0] += point.cost
        }
        return bucketCosts.compactMap { date, cost in
            guard let count = data.bucketCounts[date], count > 0 else { return nil }
            return ChartPoint(bucketDate: date, project: "avg", source: "",
                              cost: cost / Double(count), totalTokens: 0)
        }.sorted { $0.bucketDate < $1.bucketDate }
    }

    private var activePoints: [ChartPoint] { showEfficiency ? efficiencyPoints : data.points }

    private var selectedBucketValue: Double? {
        guard let bucket = selectedBucket else { return nil }
        let matching = activePoints.filter { $0.bucketDate == bucket }
        return matching.isEmpty ? nil : matching.reduce(0) { $0 + $1.cost }
    }

    private var overallEfficiency: Double {
        guard data.totalEntries > 0 else { return 0 }
        return data.totalCost / Double(data.totalEntries)
    }

    private var allProjects: [String] { Array(Set(data.points.map(\.project))).sorted() }

    private var axisFormat: Date.FormatStyle {
        switch kind {
        case .day, .week: return .dateTime.month(.abbreviated).day()
        case .month:      return .dateTime.month(.abbreviated)
        }
    }

    @ViewBuilder
    private func dayLabel(for date: Date) -> some View {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            Text("Today")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.blue)
        } else {
            VStack(spacing: 1) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    @ViewBuilder
    private func weekLabel(for date: Date) -> some View {
        VStack(spacing: 1) {
            Text(date.formatted(.dateTime.month(.abbreviated)))
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text(date.formatted(.dateTime.day()))
                .font(.system(size: 9, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    private func hitBucket(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) -> Date? {
        guard let frame = proxy.plotFrame else { return nil }
        let origin = geo[frame].origin
        let xInPlot = location.x - origin.x
        let yInPlot = location.y - origin.y

        guard let clickedDate = proxy.value(atX: xInPlot, as: Date.self),
              let clickedValue = proxy.value(atY: yInPlot, as: Double.self),
              clickedValue >= 0
        else { return nil }

        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: kind.bucketComponent, for: clickedDate) else { return nil }
        let bucketStart = interval.start

        if showEfficiency {
            // Line chart: accept tap anywhere in the bucket column
            return activePoints.contains { $0.bucketDate == bucketStart } ? bucketStart : nil
        } else {
            let bucketTotal = activePoints.filter { $0.bucketDate == bucketStart }.reduce(0.0) { $0 + $1.cost }
            guard bucketTotal > 0, clickedValue <= bucketTotal else { return nil }
            return bucketStart
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showEfficiency {
                Chart(efficiencyPoints) { point in
                    LineMark(
                        x: .value("Time", point.bucketDate, unit: kind.bucketComponent),
                        y: .value("$/event", point.cost)
                    )
                    .foregroundStyle(Color.green.opacity(0.85))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Time", point.bucketDate, unit: kind.bucketComponent),
                        y: .value("$/event", point.cost)
                    )
                    .foregroundStyle(selectedBucket == nil || selectedBucket == point.bucketDate
                        ? Color.green
                        : Color.green.opacity(0.3))
                    .symbolSize(selectedBucket == point.bucketDate ? 60 : 30)
                }
                .chartXAxis { efficiencyXAxis }
                .chartYAxis { efficiencyYAxis }
                .chartXScale(domain: scrollDate.addingTimeInterval(-barDuration / 2) ... visibleEnd.addingTimeInterval(barDuration / 2))
                .chartLegend(.hidden)
                .frame(minHeight: chartMinHeight, maxHeight: chartMaxHeight)
                .animation(nil, value: kind)
                .animation(nil, value: scrollDate)
                .animation(nil, value: barCount)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onTapGesture { location in
                                if let bucket = hitBucket(at: location, proxy: proxy, geo: geo) {
                                    selectedBucket = (selectedBucket == bucket) ? nil : bucket
                                } else {
                                    selectedBucket = nil
                                }
                            }
                    }
                }
                .onChange(of: scrollDate)     { _, _ in selectedBucket = nil }
                .onChange(of: kind)           { _, _ in selectedBucket = nil }
                .onChange(of: showEfficiency) { _, _ in selectedBucket = nil }
            } else {
                Chart(data.points) { point in
                    BarMark(
                        x: .value("Time", point.bucketDate, unit: kind.bucketComponent),
                        y: .value("Cost", point.cost)
                    )
                    .foregroundStyle(by: .value("Project", point.project))
                    .cornerRadius(3)
                    .opacity(selectedBucket == nil || selectedBucket == point.bucketDate ? 1.0 : 0.3)
                }
                .chartForegroundStyleScale(
                    domain: allProjects,
                    range: allProjects.map { colorFor($0) }
                )
                .chartXAxis { costXAxis }
                .chartYAxis { costYAxis }
                .chartXScale(domain: scrollDate.addingTimeInterval(-barDuration / 2) ... visibleEnd.addingTimeInterval(barDuration / 2))
                .chartLegend(.hidden)
                .frame(minHeight: chartMinHeight, maxHeight: chartMaxHeight)
                .animation(nil, value: kind)
                .animation(nil, value: scrollDate)
                .animation(nil, value: barCount)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onTapGesture { location in
                                if let bucket = hitBucket(at: location, proxy: proxy, geo: geo) {
                                    selectedBucket = (selectedBucket == bucket) ? nil : bucket
                                } else {
                                    selectedBucket = nil
                                }
                            }
                    }
                }
                .onChange(of: scrollDate)     { _, _ in selectedBucket = nil }
                .onChange(of: kind)           { _, _ in selectedBucket = nil }
                .onChange(of: showEfficiency) { _, _ in selectedBucket = nil }
            }

            // ── Footer ─────────────────────────────────────────────────
            ZStack(alignment: .center) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    if showEfficiency {
                        let displayAvg = selectedBucketValue ?? overallEfficiency
                        Text(String(format: "$%.4f/event", displayAvg))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.green)
                            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .leading)))
                    } else {
                        let displayCost = selectedBucketValue ?? data.totalCost
                        Text(String(format: "$%.4f", displayCost))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .leading)))
                    }

                    Spacer()

                    if !showEfficiency {
                        let count = selectedBucket.flatMap { data.bucketCounts[$0] } ?? data.totalEntries
                        Text("\(count) event\(count == 1 ? "" : "s")")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }

                if showCredits && !showEfficiency {
                    let displayCredits = selectedBucket.flatMap { data.bucketCredits[$0] } ?? data.totalCredits
                    Text(String(format: "%.2f cr", displayCredits))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.yellow.opacity(0.85))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedBucket)
            .padding(.top, 2)
        }
    }

    @AxisContentBuilder
    private var costXAxis: some AxisContent {
        AxisMarks(values: .stride(by: kind.bucketComponent)) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(.primary.opacity(0.18))
            AxisValueLabel {
                if let date = value.as(Date.self) {
                    if kind == .day {
                        dayLabel(for: date)
                    } else if kind == .week {
                        weekLabel(for: date)
                    } else {
                        Text(date.formatted(axisFormat))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    @AxisContentBuilder
    private var efficiencyXAxis: some AxisContent {
        AxisMarks(values: .stride(by: kind.bucketComponent)) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(.primary.opacity(0.18))
            AxisValueLabel {
                if let date = value.as(Date.self) {
                    if kind == .day {
                        dayLabel(for: date)
                    } else if kind == .week {
                        weekLabel(for: date)
                    } else {
                        Text(date.formatted(axisFormat))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    @AxisContentBuilder
    private var costYAxis: some AxisContent {
        AxisMarks(position: .leading) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(.primary.opacity(0.18))
            AxisValueLabel {
                if let v = value.as(Double.self) {
                    Text(String(format: "$%.0f", v))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    @AxisContentBuilder
    private var efficiencyYAxis: some AxisContent {
        AxisMarks(position: .leading) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(.primary.opacity(0.18))
            AxisValueLabel {
                if let v = value.as(Double.self) {
                    Text(String(format: "$%.4f", v))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
    }
}
