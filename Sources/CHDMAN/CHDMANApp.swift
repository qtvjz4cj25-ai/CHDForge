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
        Window("RetroForge", id: "main") {
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
        // Load icon from main bundle (Contents/Resources/AppIcon.icns)
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
    }
}
