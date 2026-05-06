import Foundation

enum TimeRangeKind: String, CaseIterable, Identifiable {
    case day   = "Day"
    case week  = "Week"
    case month = "Month"

    var id: String { rawValue }

    // Calendar component that defines one bar
    var bucketComponent: Calendar.Component {
        switch self {
        case .day:   return .day
        case .week:  return .weekOfYear
        case .month: return .month
        }
    }

    // How many bars to show at once
    var barCount: Int {
        switch self {
        case .day:   return 30
        case .week:  return 12
        case .month: return 12
        }
    }
}

/// A sliding window showing `kind.barCount` bars ending at (or containing) `anchorDate`.
struct TimeWindow {
    let kind: TimeRangeKind
    let anchorDate: Date  // the last bar contains this date

    private var calendar: Calendar {
        var cal = Calendar.current
        if kind == .week { cal.firstWeekday = 2 } // Monday
        return cal
    }

    // End of the bar that contains anchorDate (exclusive)
    var end: Date {
        calendar.dateInterval(of: kind.bucketComponent, for: anchorDate)!.end
    }

    // Start of the window: go back barCount buckets from end
    var start: Date {
        calendar.date(byAdding: kind.bucketComponent, value: -kind.barCount, to: end)!
    }

    var label: String {
        let s = start
        let e = end.addingTimeInterval(-1)
        switch kind {
        case .day:
            let sf = s.formatted(.dateTime.month(.abbreviated).day())
            let ef = e.formatted(.dateTime.month(.abbreviated).day().year())
            return "\(sf) – \(ef)"
        case .week:
            let sf = s.formatted(.dateTime.month(.abbreviated).day())
            let ef = e.formatted(.dateTime.month(.abbreviated).day().year())
            return "\(sf) – \(ef)"
        case .month:
            let sf = s.formatted(.dateTime.month(.abbreviated).year())
            let ef = e.formatted(.dateTime.month(.abbreviated).year())
            return "\(sf) – \(ef)"
        }
    }

    func navigated(by offset: Int) -> TimeWindow {
        let newAnchor = calendar.date(
            byAdding: kind.bucketComponent,
            value: offset * kind.barCount,
            to: anchorDate
        )!
        return TimeWindow(kind: kind, anchorDate: newAnchor)
    }

    var isAtPresent: Bool {
        end > Date()
    }

    static func current(kind: TimeRangeKind) -> TimeWindow {
        TimeWindow(kind: kind, anchorDate: Date())
    }
}
