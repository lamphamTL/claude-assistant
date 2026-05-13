import SwiftUI
import AppKit
import ServiceManagement
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    let store = UsageStore()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        store.load()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let orange = NSColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 1.0)
            let config = NSImage.SymbolConfiguration(paletteColors: [orange])
            if let img = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "Token Usage")?
                .withSymbolConfiguration(config) {
                img.isTemplate = false
                button.image = img
            }
            button.action = #selector(togglePopover)
            button.target = self
        }
        statusItem.isVisible = true

        let hostingController = NSHostingController(rootView:
            ContentView().environmentObject(store)
        )
        popover = NSPopover()
        popover.contentViewController = hostingController
        popover.behavior = .transient

        NotificationCenter.default.addObserver(
            forName: .init("com.lampham.tokenusage.close"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.popover.performClose(nil)
        }

        store.$entries
            .receive(on: RunLoop.main)
            .sink { [weak self] entries in self?.updateStatusTitle(entries: entries) }
            .store(in: &cancellables)

        try? SMAppService.mainApp.register()
    }

    private func updateStatusTitle(entries: [UsageEntry]) {
        let today = Calendar.current.startOfDay(for: Date())
        let cost = entries.filter { $0.ts >= today }.reduce(0.0) { $0 + $1.cost_usd }
        let text = String(format: " $%.2f", cost)
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 1.0),
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))
        ]
        statusItem.button?.attributedTitle = NSAttributedString(string: text, attributes: attrs)
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
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
