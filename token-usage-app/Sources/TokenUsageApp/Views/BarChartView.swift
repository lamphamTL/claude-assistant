import SwiftUI
import Charts

struct ChartPoint: Identifiable {
    var id: String { "\(bucketDate.timeIntervalSinceReferenceDate)-\(project)" }
    let bucketDate: Date
    let project: String
    let cost: Double
    let totalTokens: Int
}

struct BarChartView: View {
    let entries: [UsageEntry]
    let kind: TimeRangeKind
    @Binding var scrollDate: Date

    private static let palette: [Color] = [
        .blue, .purple, .orange, .teal, .pink, .indigo, .mint
    ]

    @State private var selectedBucket: Date? = nil

    // MARK: - Derived data

    private var chartPoints: [ChartPoint] {
        let calendar = Calendar.current
        let component = kind.bucketComponent
        var grouped: [Date: [String: (cost: Double, tokens: Int)]] = [:]

        for entry in visibleEntries {
            guard let interval = calendar.dateInterval(of: component, for: entry.ts) else { continue }
            let bucket = interval.start
            let proj = entry.projectDisplayName
            let prev = grouped[bucket]?[proj] ?? (cost: 0, tokens: 0)
            grouped[bucket, default: [:]][proj] = (
                cost:   prev.cost + entry.cost_usd,
                tokens: prev.tokens + entry.tokens.total
            )
        }

        var points: [ChartPoint] = []
        for (date, projects) in grouped {
            for (proj, agg) in projects {
                points.append(ChartPoint(bucketDate: date, project: proj, cost: agg.cost, totalTokens: agg.tokens))
            }
        }
        points.sort {
            $0.bucketDate == $1.bucketDate ? $0.project < $1.project : $0.bucketDate < $1.bucketDate
        }
        return points
    }

    var visibleDuration: TimeInterval {
        switch kind {
        case .day:   return 7  * 24 * 3600
        case .week:  return 5  * 7  * 24 * 3600
        case .month: return 5  * 31 * 24 * 3600
        }
    }

    private var barDuration: TimeInterval {
        switch kind {
        case .day:   return 24 * 3600
        case .week:  return 7  * 24 * 3600
        case .month: return 31 * 24 * 3600
        }
    }

    private var visibleEnd: Date { scrollDate.addingTimeInterval(visibleDuration) }
    private var visibleEntries: [UsageEntry] { entries.filter { $0.ts >= scrollDate && $0.ts < visibleEnd } }
    private var totalCost: Double { visibleEntries.reduce(0) { $0 + $1.cost_usd } }

    // Cost of the selected bucket (sum across all projects for that bucket)
    private var selectedCost: Double? {
        guard let bucket = selectedBucket else { return nil }
        let matching = chartPoints.filter { $0.bucketDate == bucket }
        return matching.isEmpty ? nil : matching.reduce(0) { $0 + $1.cost }
    }

    private var allProjects: [String] { Array(Set(chartPoints.map(\.project))).sorted() }

    private var axisFormat: Date.FormatStyle {
        switch kind {
        case .day, .week: return .dateTime.month(.abbreviated).day()
        case .month:      return .dateTime.month(.abbreviated)
        }
    }

    // MARK: - Helpers

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

    // Returns the bucket the tap lands on, or nil if tap misses all bars.
    private func hitBucket(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) -> Date? {
        guard let frame = proxy.plotFrame else { return nil }
        let origin = geo[frame].origin
        let xInPlot = location.x - origin.x
        let yInPlot = location.y - origin.y

        guard let clickedDate = proxy.value(atX: xInPlot, as: Date.self),
              let clickedCost = proxy.value(atY: yInPlot, as: Double.self),
              clickedCost >= 0
        else { return nil }

        // Calendar containment: which bucket period does the clicked date fall in?
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: kind.bucketComponent, for: clickedDate) else { return nil }
        let bucketStart = interval.start

        // Bucket must exist in visible data
        let bucketTotal = chartPoints
            .filter { $0.bucketDate == bucketStart }
            .reduce(0.0) { $0 + $1.cost }
        guard bucketTotal > 0, clickedCost <= bucketTotal else { return nil }

        return bucketStart
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Chart(chartPoints) { point in
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
                range: Self.palette.prefix(max(allProjects.count, 1)).map { $0 }
            )
            .chartXAxis {
                AxisMarks(values: .stride(by: kind.bucketComponent)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.primary.opacity(0.18))
                    AxisValueLabel {
                        if kind == .day, let date = value.as(Date.self) {
                            dayLabel(for: date)
                        } else if let date = value.as(Date.self) {
                            Text(date.formatted(axisFormat))
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.primary.opacity(0.18))
                    AxisValueLabel {
                        if let cost = value.as(Double.self) {
                            Text(String(format: "$%.0f", cost))
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .chartXScale(domain: scrollDate.addingTimeInterval(-barDuration / 2) ... visibleEnd.addingTimeInterval(barDuration / 2))
            .chartLegend(.hidden)
            .frame(height: 150)
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
            .onChange(of: scrollDate) { _, _ in selectedBucket = nil }
            .onChange(of: kind)       { _, _ in selectedBucket = nil }

            // ── Footer ─────────────────────────────────────────────────
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                if let cost = selectedCost {
                    Text(String(format: "$%.4f", cost))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .leading)))
                } else {
                    Text(String(format: "$%.4f", totalCost))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .leading)))
                }

                Spacer()

                Text(selectedBucket != nil ? "selected" : "\(visibleEntries.count) event\(visibleEntries.count == 1 ? "" : "s")")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .animation(.easeInOut(duration: 0.2), value: selectedBucket)
            .padding(.top, 2)
        }
    }
}
