import Foundation

enum TimeRangeKind: String, CaseIterable, Identifiable {
    case day   = "Day"
    case week  = "Week"
    case month = "Month"

    var id: String { rawValue }

    var bucketComponent: Calendar.Component {
        switch self {
        case .day:   return .hour
        case .week:  return .day
        case .month: return .day
        }
    }

    var navigationComponent: Calendar.Component {
        switch self {
        case .day:   return .day
        case .week:  return .weekOfYear
        case .month: return .month
        }
    }
}

struct TimeWindow {
    let kind: TimeRangeKind
    let start: Date
    let end: Date

    var label: String {
        switch kind {
        case .day:
            return start.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
        case .week:
            let endInclusive = end.addingTimeInterval(-1)
            let s = start.formatted(.dateTime.month(.abbreviated).day())
            let e = endInclusive.formatted(.dateTime.month(.abbreviated).day().year())
            return "\(s) – \(e)"
        case .month:
            return start.formatted(.dateTime.month(.wide).year())
        }
    }

    func navigated(by offset: Int, calendar: Calendar = .current) -> TimeWindow {
        let newStart = calendar.date(byAdding: kind.navigationComponent, value: offset, to: start)!
        return TimeWindow.containing(newStart, kind: kind, calendar: calendar)
    }

    static func containing(_ date: Date, kind: TimeRangeKind, calendar: Calendar = .current) -> TimeWindow {
        var cal = calendar
        if kind == .week { cal.firstWeekday = 2 } // Monday
        let interval: DateInterval
        switch kind {
        case .day:   interval = cal.dateInterval(of: .day, for: date)!
        case .week:  interval = cal.dateInterval(of: .weekOfYear, for: date)!
        case .month: interval = cal.dateInterval(of: .month, for: date)!
        }
        return TimeWindow(kind: kind, start: interval.start, end: interval.end)
    }

    static func current(kind: TimeRangeKind) -> TimeWindow {
        containing(Date(), kind: kind)
    }
}
