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
    let totalEntries: Int
    let bucketCounts: [Date: Int]   // entry count per bucket for footer

    static let empty = ChartData(points: [], totalCost: 0, totalEntries: 0, bucketCounts: [:])
}

struct BarChartView: View {
    let data: ChartData
    let kind: TimeRangeKind
    let scrollDate: Date            // for x-axis domain
    @Binding var scrollDateBinding: Date

    private static let palette: [Color] = [
        .blue, .purple, .orange, .teal, .pink, .indigo, .mint
    ]

    @State private var selectedBucket: Date? = nil

    private var barDuration: TimeInterval {
        switch kind {
        case .day:   return 24 * 3600
        case .week:  return 7  * 24 * 3600
        case .month: return 31 * 24 * 3600
        }
    }

    private var visibleDuration: TimeInterval {
        switch kind {
        case .day:   return 7  * 24 * 3600
        case .week:  return 5  * 7  * 24 * 3600
        case .month: return 5  * 31 * 24 * 3600
        }
    }

    private var visibleEnd: Date { scrollDate.addingTimeInterval(visibleDuration) }

    private var selectedCost: Double? {
        guard let bucket = selectedBucket else { return nil }
        let matching = data.points.filter { $0.bucketDate == bucket }
        return matching.isEmpty ? nil : matching.reduce(0) { $0 + $1.cost }
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

    private func hitBucket(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) -> Date? {
        guard let frame = proxy.plotFrame else { return nil }
        let origin = geo[frame].origin
        let xInPlot = location.x - origin.x
        let yInPlot = location.y - origin.y

        guard let clickedDate = proxy.value(atX: xInPlot, as: Date.self),
              let clickedCost = proxy.value(atY: yInPlot, as: Double.self),
              clickedCost >= 0
        else { return nil }

        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: kind.bucketComponent, for: clickedDate) else { return nil }
        let bucketStart = interval.start

        let bucketTotal = data.points.filter { $0.bucketDate == bucketStart }.reduce(0.0) { $0 + $1.cost }
        guard bucketTotal > 0, clickedCost <= bucketTotal else { return nil }
        return bucketStart
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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
                let displayCost = selectedCost ?? data.totalCost
                Text(String(format: "$%.4f", displayCost))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .leading)))

                Spacer()

                let count = selectedBucket.flatMap { data.bucketCounts[$0] } ?? data.totalEntries
                Text("\(count) event\(count == 1 ? "" : "s")")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .animation(.easeInOut(duration: 0.2), value: selectedBucket)
            .padding(.top, 2)
        }
    }
}
