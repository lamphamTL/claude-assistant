import SwiftUI
import Charts

struct ChartPoint: Identifiable {
    let id = UUID()
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

    private var chartPoints: [ChartPoint] {
        let calendar = Calendar.current
        let component = kind.bucketComponent
        var grouped: [Date: [String: (cost: Double, tokens: Int)]] = [:]

        // Only aggregate entries within the visible window
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

        return grouped.flatMap { date, projects in
            projects.map { ChartPoint(bucketDate: date, project: $0, cost: $1.cost, totalTokens: $1.tokens) }
        }.sorted { $0.bucketDate < $1.bucketDate }
    }

    var visibleDuration: TimeInterval {
        switch kind {
        case .day:   return 7  * 24 * 3600
        case .week:  return 5  * 7  * 24 * 3600
        case .month: return 5  * 31 * 24 * 3600
        }
    }

    private var visibleEnd: Date { scrollDate.addingTimeInterval(visibleDuration) }

    private var visibleEntries: [UsageEntry] {
        entries.filter { $0.ts >= scrollDate && $0.ts < visibleEnd }
    }

    private var totalCost: Double { visibleEntries.reduce(0) { $0 + $1.cost_usd } }

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
            VStack(spacing: 1) {
                Text("Today")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
            }
        } else {
            VStack(spacing: 1) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.8))
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.85))
            }
        }
    }

    // Unique projects for stable color mapping
    private var allProjects: [String] {
        Array(Set(chartPoints.map(\.project))).sorted()
    }

    @State private var chartWidth: CGFloat = 260
    @State private var dragStartDate: Date? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Chart(chartPoints) { point in
                BarMark(
                    x: .value("Time", point.bucketDate, unit: kind.bucketComponent),
                    y: .value("Cost", point.cost)
                )
                .foregroundStyle(by: .value("Project", point.project))
                .cornerRadius(3)
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
                                .foregroundStyle(.primary.opacity(0.8))
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
            .chartXScale(domain: scrollDate ... visibleEnd)
            .chartLegend(.hidden)
            .frame(height: 160)
            .background(GeometryReader { geo in
                Color.clear.onAppear { chartWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, w in chartWidth = w }
            })
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        if dragStartDate == nil { dragStartDate = scrollDate }
                        let secsPerPixel = visibleDuration / Double(chartWidth)
                        scrollDate = (dragStartDate ?? scrollDate)
                            .addingTimeInterval(-Double(value.translation.width) * secsPerPixel)
                    }
                    .onEnded { _ in dragStartDate = nil }
            )

            // ── Footer ─────────────────────────────────────────────────
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(String(format: "$%.4f", totalCost))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(visibleEntries.count) event\(visibleEntries.count == 1 ? "" : "s")")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 2)
        }
    }
}
