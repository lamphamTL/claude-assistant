import SwiftUI

struct NavigationBar: View {
    @Binding var window: TimeWindow

    var body: some View {
        HStack(spacing: 12) {
            Button { window = window.navigated(by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            Spacer()

            Text(window.label)
                .font(.headline)
                .lineLimit(1)

            Spacer()

            Button { window = window.navigated(by: +1) } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .disabled(window.end > Date())

            Button("Today") { window = .current(kind: window.kind) }
                .buttonStyle(.bordered)
                .font(.callout)
                .disabled(isCurrentWindow)
        }
    }

    private var isCurrentWindow: Bool {
        let now = Date()
        return window.start <= now && window.end > now
    }
}
