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
    let entries: [UsageEntry]          // all entries filtered by project only
    let kind: TimeRangeKind
    @Binding var scrollDate: Date      // left edge of visible window

    private var chartPoints: [ChartPoint] {
        let calendar = Calendar.current
        let component = kind.bucketComponent
        var grouped: [Date: [String: (cost: Double, tokens: Int)]] = [:]

        for entry in entries {
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
            projects.map { projName, agg in
                ChartPoint(bucketDate: date, project: projName, cost: agg.cost, totalTokens: agg.tokens)
            }
        }.sorted { $0.bucketDate < $1.bucketDate }
    }

    // Seconds to show at once
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
        case .day:   return .dateTime.month(.abbreviated).day()
        case .week:  return .dateTime.month(.abbreviated).day()
        case .month: return .dateTime.month(.abbreviated).year()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart(chartPoints) { point in
                BarMark(
                    x: .value("Time", point.bucketDate, unit: kind.bucketComponent),
                    y: .value("Cost (USD)", point.cost)
                )
                .foregroundStyle(by: .value("Project", point.project))
            }
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: visibleDuration)
            .chartScrollPosition(x: $scrollDate)
            .chartXAxis {
                AxisMarks(values: .stride(by: kind.bucketComponent)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: axisFormat)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let cost = value.as(Double.self) {
                            Text(cost, format: .currency(code: "USD").precision(.fractionLength(2)))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                Label {
                    Text(totalCost, format: .currency(code: "USD").precision(.fractionLength(4)))
                        .fontWeight(.semibold)
                } icon: {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundStyle(.green)
                }
                Spacer()
                Text("\(visibleEntries.count) event\(visibleEntries.count == 1 ? "" : "s")")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
        }
    }
}
