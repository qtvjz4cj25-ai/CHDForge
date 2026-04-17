import AppKit
import SwiftUI

@main
struct CHDMANApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = AppViewModel()

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        Window("CHDForge", id: "main") {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 960, minHeight: 640)
        }
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
                .environmentObject(viewModel)
        }
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let icon = Self.loadAppIcon() {
            NSApp.applicationIconImage = icon
        }
    }

    private static func loadAppIcon() -> NSImage? {
        // Try the SwiftPM resource bundle next to the executable
        let execURL = Bundle.main.executableURL?.deletingLastPathComponent()
        if let execURL,
           let bundle = Bundle(url: execURL.appendingPathComponent("CHDMAN_CHDMAN.bundle")),
           let url = bundle.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            return icon
        }
        // Fall back to main bundle Resources (distributed .app)
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            return icon
        }
        return nil
    }
}
