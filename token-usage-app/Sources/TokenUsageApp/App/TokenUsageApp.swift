import SwiftUI
import AppKit
import ServiceManagement
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NSPanel?
    var hosting: NSHostingView<AnyView>?
    let store = UsageStore()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.load()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.acceptsMouseMovedEvents = true

        let hosting = NSHostingView(rootView: AnyView(
            ContentView()
                .environmentObject(store)
        ))
        // Width-only autoresize — height driven by fittingSize
        hosting.autoresizingMask = [.width]
        panel.contentView = hosting
        self.hosting = hosting
        self.panel = panel

        positionPanel()
        panel.orderFrontRegardless()

        // Resize panel to content once data is loaded, then on every isLoaded toggle
        store.$isLoaded
            .filter { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // Allow one layout pass before measuring
                DispatchQueue.main.async { self?.fitPanelToContent() }
            }
            .store(in: &cancellables)

        try? SMAppService.mainApp.register()
    }

    private func fitPanelToContent() {
        guard let hosting, let panel else { return }
        hosting.layout()
        let h = hosting.fittingSize.height
        guard h > 50 else { return }
        // Keep bottom-right anchor fixed while resizing height
        let origin = NSPoint(
            x: panel.frame.origin.x,
            y: panel.frame.origin.y + panel.frame.height - h
        )
        panel.setContentSize(CGSize(width: 320, height: h))
        panel.setFrameOrigin(origin)
    }

    private func positionPanel() {
        guard let panel, let screen = NSScreen.main else { return }
        let margin: CGFloat = 24
        let x = screen.visibleFrame.maxX - 320 - margin
        let y = screen.visibleFrame.minY + margin
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct TokenUsageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
