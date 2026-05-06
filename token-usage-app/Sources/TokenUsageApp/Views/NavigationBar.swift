import SwiftUI

struct NavigationBar: View {
    @Binding var window: TimeWindow

    var body: some View {
        HStack(spacing: 12) {
            Button { withAnimation(.easeInOut(duration: 0.3)) { window = window.navigated(by: -1) } } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            Spacer()

            Text(window.label)
                .font(.headline)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: window.label)

            Spacer()

            Button { withAnimation(.easeInOut(duration: 0.3)) { window = window.navigated(by: +1) } } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .disabled(window.isAtPresent)

            Button("Today") { withAnimation(.easeInOut(duration: 0.3)) { window = .current(kind: window.kind) } }
                .buttonStyle(.bordered)
                .font(.callout)
                .disabled(isCurrentWindow)
        }
    }

    private var isCurrentWindow: Bool { window.isAtPresent }
}
