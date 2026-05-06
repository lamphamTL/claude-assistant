import SwiftUI

struct NavigationBar: View {
    @Binding var scrollDate: Date
    let kind: TimeRangeKind
    let visibleDuration: TimeInterval

    var body: some View {
        HStack(spacing: 12) {
            Button { shift(by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            Spacer()

            Text(label)
                .font(.headline)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.25), value: label)

            Spacer()

            Button { shift(by: +1) } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .disabled(isAtPresent)

            Button("Today") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    scrollDate = Date().addingTimeInterval(-visibleDuration)
                }
            }
            .buttonStyle(.bordered)
            .font(.callout)
            .disabled(isAtPresent)
        }
    }

    private func shift(by direction: Int) {
        let step: TimeInterval
        switch kind {
        case .day:   step = 24 * 3600
        case .week:  step = 7  * 24 * 3600
        case .month: step = 31 * 24 * 3600
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            scrollDate = scrollDate.addingTimeInterval(Double(direction) * step)
        }
    }

    private var visibleEnd: Date { scrollDate.addingTimeInterval(visibleDuration) }

    private var isAtPresent: Bool { visibleEnd >= Date() }

    private var label: String {
        let end = visibleEnd.addingTimeInterval(-1)
        switch kind {
        case .day, .week:
            let s = scrollDate.formatted(.dateTime.month(.abbreviated).day())
            let e = end.formatted(.dateTime.month(.abbreviated).day().year())
            return "\(s) – \(e)"
        case .month:
            let s = scrollDate.formatted(.dateTime.month(.abbreviated).year())
            let e = end.formatted(.dateTime.month(.abbreviated).year())
            return "\(s) – \(e)"
        }
    }
}
