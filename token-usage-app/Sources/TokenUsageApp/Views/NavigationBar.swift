import SwiftUI

struct CompactNavigationBar: View {
    @Binding var scrollDate: Date
    let kind: TimeRangeKind
    let visibleDuration: TimeInterval

    var body: some View {
        HStack(spacing: 6) {
            Button { shift(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.25), value: label)

            if !isAtPresent {
                Button("Now") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        scrollDate = Date().addingTimeInterval(-visibleDuration)
                    }
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.blue)
                .buttonStyle(.plain)
            }

            Button { shift(by: +1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(isAtPresent)
            .opacity(isAtPresent ? 0.3 : 1)
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
            let e = end.formatted(.dateTime.month(.abbreviated).day())
            return "\(s) – \(e)"
        case .month:
            let s = scrollDate.formatted(.dateTime.month(.abbreviated).year())
            let e = end.formatted(.dateTime.month(.abbreviated).year())
            return "\(s) – \(e)"
        }
    }
}
