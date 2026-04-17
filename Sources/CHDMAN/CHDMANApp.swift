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
        let bundleName = "CHDMAN_CHDMAN.bundle"
        // Search for the resource bundle in common locations
        let candidates = [
            // Next to executable (swift build / Xcode debug)
            Bundle.main.executableURL?.deletingLastPathComponent(),
            // In Resources (distributed .app)
            Bundle.main.resourceURL
        ]
        for candidate in candidates {
            guard let dir = candidate else { continue }
            if let bundle = Bundle(url: dir.appendingPathComponent(bundleName)),
               let url = bundle.url(forResource: "AppIcon", withExtension: "icns"),
               let icon = NSImage(contentsOf: url) {
                return icon
            }
        }
        // Direct lookup in main bundle Resources
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            return icon
        }
        return nil
    }
}
