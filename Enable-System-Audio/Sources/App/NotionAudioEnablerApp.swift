import SwiftUI

@main
struct NotionAudioEnablerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            OverlayView(viewModel: appDelegate.viewModel)
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = EnablerViewModel()

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard LockFile.acquire() else {
            let alert = NSAlert()
            alert.messageText = "Already Running"
            alert.informativeText = "Notion Audio Enabler is already running. Only one instance is allowed at a time."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            NSApp.terminate(nil)
            return
        }

        installSignalHandlers()

        NSApplication.shared.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                window.makeKeyAndOrderFront(nil)
                window.level = .floating
                window.styleMask.remove(.resizable)
                window.title = "Notion — Enable System Audio"
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.safeRevert()
        LockFile.release()
    }

    private func installSignalHandlers() {
        let handler: @convention(c) (Int32) -> Void = { _ in
            if ElevationManager.isAdmin() {
                try? ElevationManager.revert()
            }
            LockFile.release()
            exit(0)
        }
        signal(SIGTERM, handler)
        signal(SIGINT, handler)
        signal(SIGHUP, handler)
    }
}
