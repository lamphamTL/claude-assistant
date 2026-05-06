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
    let window: TimeWindow

    private var chartPoints: [ChartPoint] {
        let calendar = Calendar.current
        let component = window.kind.bucketComponent
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

    private var totalCost: Double { entries.reduce(0) { $0 + $1.cost_usd } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart(chartPoints) { point in
                BarMark(
                    x: .value("Time", point.bucketDate, unit: window.kind.bucketComponent),
                    y: .value("Cost (USD)", point.cost)
                )
                .foregroundStyle(by: .value("Project", point.project))
            }
            .chartXScale(domain: window.start ... window.end)
            .chartXAxis {
                AxisMarks(
                    values: window.kind == .month
                        ? .automatic(desiredCount: 8)
                        : .stride(by: window.kind.bucketComponent)
                ) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(
                        format: window.kind == .day
                            ? .dateTime.hour()
                            : .dateTime.month(.abbreviated).day()
                    )
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

                Text("\(entries.count) event\(entries.count == 1 ? "" : "s")")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
        }
    }
}
