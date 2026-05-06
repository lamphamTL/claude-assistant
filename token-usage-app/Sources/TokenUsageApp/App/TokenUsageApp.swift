import SwiftUI
import AppKit
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NSPanel?
    let store = UsageStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.load()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 390),
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

        let hosting = NSHostingView(rootView:
            ContentView()
                .environmentObject(store)
        )
        hosting.frame = panel.contentRect(forFrameRect: panel.frame)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting

        // Bottom-right corner with margin
        if let screen = NSScreen.main {
            let margin: CGFloat = 24
            let x = screen.visibleFrame.maxX - panel.frame.width - margin
            let y = screen.visibleFrame.minY + margin
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFrontRegardless()
        self.panel = panel

        // Register as login item (idempotent — safe to call every launch)
        try? SMAppService.mainApp.register()
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
