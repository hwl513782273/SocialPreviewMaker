import SwiftUI
import AppKit

@main
struct SocialPreviewMakerApp: App {
    init() {
        CLI.handleIfRequested()   // --export 模式：无界面导出后退出
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于 SocialPreviewMaker") { Self.showAbout() }
            }
        }
    }

    static func showAbout() {
        let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0.0"
        let hosting = NSHostingController(rootView: AboutView(version: version))
        let win = NSWindow(contentViewController: hosting)
        win.title = "关于 SocialPreviewMaker"
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.center()
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }
}
