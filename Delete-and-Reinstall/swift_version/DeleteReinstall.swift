import AppKit
import Foundation
import SystemConfiguration

// MARK: - Data Model

struct AppEntry: Codable {
    let displayName: String
    let bundleName: String
    let bundleIdentifier: String
    let jamfPolicyID: String
    let dockLabel: String
}

struct AppConfig: Codable {
    let apps: [AppEntry]
}

// MARK: - Logging

func log(_ message: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    print("[\(ts)] [DeleteReinstall] \(message)")
    fflush(stdout)
}

func logError(_ message: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    fputs("[\(ts)] [DeleteReinstall] ERROR: \(message)\n", stderr)
    fflush(stderr)
}

// MARK: - Configuration

func loadConfig() -> AppConfig? {
    let binaryPath = CommandLine.arguments[0] as NSString
    let configPath = binaryPath.deletingLastPathComponent + "/apps.json"
    guard let data = FileManager.default.contents(atPath: configPath) else {
        logError("Config not found at \(configPath)")
        return nil
    }
    do {
        return try JSONDecoder().decode(AppConfig.self, from: data)
    } catch {
        logError("Failed to parse config: \(error)")
        return nil
    }
}

// MARK: - User Context

func getLoggedInUser() -> (username: String, uid: uid_t)? {
    var uid: uid_t = 0
    guard let cfUser = SCDynamicStoreCopyConsoleUser(nil, &uid, nil) else { return nil }
    let username = cfUser as String
    if username == "loginwindow" { return nil }
    return (username, uid)
}

func getBrandingIcon(username: String) -> NSImage? {
    let path = "/Users/\(username)/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingimage.png"
    if let img = NSImage(contentsOfFile: path) { return img }
    return NSImage(named: NSImage.applicationIconName)
}

// MARK: - Shell Commands

func runShellCommand(_ args: [String], asUser: (username: String, uid: uid_t)? = nil) -> (status: Int32, output: String) {
    let proc = Process()
    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = pipe

    if let user = asUser {
        proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        proc.arguments = ["asuser", String(user.uid), "/usr/bin/sudo", "-u", user.username] + args
    } else {
        proc.executableURL = URL(fileURLWithPath: args[0])
        proc.arguments = Array(args.dropFirst())
    }

    do {
        try proc.run()
        proc.waitUntilExit()
    } catch {
        logError("Failed to run command: \(error)")
        return (-1, "")
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    return (proc.terminationStatus, output)
}

// MARK: - Dock Management

func getDockInfo(dockLabel: String, username: String, uid: uid_t) -> (section: String, position: String)? {
    let plist = "/Users/\(username)/Library/Preferences/com.apple.dock.plist"
    let result = runShellCommand(["/usr/local/bin/dockutil", "--find", dockLabel, plist], asUser: (username, uid))

    guard result.status == 0 else {
        log("\(dockLabel) not found in dock")
        return nil
    }

    let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    var section = "persistent-apps"
    var position = "end"

    if let sectionRange = output.range(of: "found in ") {
        let afterFound = output[sectionRange.upperBound...]
        if let atRange = afterFound.range(of: " at slot ") {
            section = String(afterFound[..<atRange.lowerBound])
            let afterSlot = afterFound[atRange.upperBound...]
            if let inRange = afterSlot.range(of: " in ") {
                position = String(afterSlot[..<inRange.lowerBound])
            } else {
                position = afterSlot.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    log("Dock info: \(dockLabel) in \(section) at slot \(position)")
    return (section, position)
}

func restoreDockPosition(app: AppEntry, section: String, position: String, username: String, uid: uid_t) {
    let appPath = "/Applications/\(app.bundleName)"
    guard FileManager.default.fileExists(atPath: appPath) else {
        log("Skipping dock restore — \(appPath) not found yet")
        return
    }

    let plist = "/Users/\(username)/Library/Preferences/com.apple.dock.plist"
    var args = ["/usr/local/bin/dockutil", "--add", appPath, "--position", position]
    if section != "persistent-apps" {
        args += ["--section", section]
    }
    args.append(plist)

    let result = runShellCommand(args, asUser: (username, uid))
    if result.status == 0 {
        log("Restored \(app.dockLabel) to dock in \(section) at position \(position)")
    } else {
        logError("Failed to restore dock position: \(result.output)")
    }
}

// MARK: - App Lifecycle

func gracefullyQuitApp(bundleIdentifier: String) {
    let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
    guard !running.isEmpty else {
        log("App \(bundleIdentifier) is not running")
        return
    }

    log("Requesting graceful quit of \(bundleIdentifier)")
    for app in running { app.terminate() }

    for _ in 0..<10 {
        Thread.sleep(forTimeInterval: 0.5)
        let still = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        if still.allSatisfy({ $0.isTerminated }) {
            log("App quit gracefully")
            return
        }
    }

    log("App did not quit gracefully, force terminating")
    let still = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
    for app in still { app.forceTerminate() }

    for _ in 0..<6 {
        Thread.sleep(forTimeInterval: 0.5)
        let remaining = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        if remaining.allSatisfy({ $0.isTerminated }) {
            log("App force terminated")
            return
        }
    }

    logError("App may still be running after force terminate")
}

func deleteApp(bundleName: String) -> Bool {
    let path = "/Applications/\(bundleName)"
    do {
        try FileManager.default.removeItem(atPath: path)
        log("Deleted \(path)")
        return true
    } catch {
        logError("Failed to delete \(path): \(error)")
        return false
    }
}

func triggerReinstall(policyID: String) -> Bool {
    log("Running jamf policy -id \(policyID)")
    let result = runShellCommand(["/usr/local/bin/jamf", "policy", "-id", policyID])
    if result.status == 0 {
        log("Jamf policy completed successfully")
        return true
    } else {
        logError("Jamf policy failed (exit \(result.status)): \(result.output)")
        return false
    }
}

// MARK: - Single Window UI

enum DialogState {
    case selection
    case confirmation(AppEntry)
    case working(String)
    case success(AppEntry)
    case error(String)
}

/// Badge type for the small status indicator overlaid on the branding icon.
enum StatusBadge {
    case none
    case warning
    case error
    case success
    case working
}

/// Composites the branding icon with a small SF Symbol badge in the bottom-right corner.
func badgedIcon(base: NSImage?, badge: StatusBadge) -> NSImage {
    let size = NSSize(width: 64, height: 64)
    let result = NSImage(size: size)
    result.lockFocus()

    // Draw the branding icon at full size.
    if let base = base {
        base.draw(in: NSRect(origin: .zero, size: size))
    }

    // Draw the badge in the bottom-right corner.
    if badge != .none {
        let badgeSize: CGFloat = 24
        let badgeRect = NSRect(x: size.width - badgeSize, y: 0, width: badgeSize, height: badgeSize)

        let (symbolName, tint): (String, NSColor) = {
            switch badge {
            case .none:    return ("", .clear)
            case .warning: return ("exclamationmark.triangle.fill", .systemYellow)
            case .error:   return ("exclamationmark.triangle.fill", .systemYellow)
            case .success: return ("checkmark", .systemGreen)
            case .working: return ("arrow.triangle.2.circlepath", .systemBlue)
            }
        }()

        if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: badgeSize - 4, weight: .bold)
                .applying(.init(paletteColors: [tint]))
            let configured = symbol.withSymbolConfiguration(config) ?? symbol
            configured.isTemplate = false
            configured.draw(in: badgeRect.insetBy(dx: 2, dy: 2))
        }
    }

    result.unlockFocus()
    return result
}

/// The persistent window controller that manages a single window throughout the tool's lifecycle.
class ToolWindow {
    let window: NSWindow
    let iconView: NSImageView
    let titleLabel: NSTextField
    let messageLabel: NSTextField
    let popup: NSPopUpButton
    let primaryButton: NSButton
    let secondaryButton: NSButton
    let spinner: NSProgressIndicator
    let brandingIcon: NSImage?

    private var buttonClicked: Int = -1

    init(icon: NSImage?) {
        self.brandingIcon = icon

        // -- Window
        let w: CGFloat = 360
        let h: CGFloat = 240
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "Delete & Reinstall"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()

        let content = window.contentView!
        content.wantsLayer = true

        // -- Icon (top center)
        iconView = NSImageView(frame: NSRect(x: (w - 64) / 2, y: h - 84, width: 64, height: 64))
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.image = icon
        content.addSubview(iconView)

        // -- Title
        titleLabel = NSTextField(labelWithString: "")
        titleLabel.frame = NSRect(x: 20, y: h - 116, width: w - 40, height: 22)
        titleLabel.font = .boldSystemFont(ofSize: 15)
        titleLabel.alignment = .center
        content.addSubview(titleLabel)

        // -- Message
        messageLabel = NSTextField(wrappingLabelWithString: "")
        messageLabel.frame = NSRect(x: 20, y: h - 156, width: w - 40, height: 36)
        messageLabel.font = .systemFont(ofSize: 13)
        messageLabel.alignment = .center
        messageLabel.maximumNumberOfLines = 2
        content.addSubview(messageLabel)

        // -- Popup (only visible during selection)
        popup = NSPopUpButton(frame: NSRect(x: 40, y: h - 186, width: w - 80, height: 28), pullsDown: false)
        content.addSubview(popup)

        // -- Spinner (only visible during working state)
        spinner = NSProgressIndicator(frame: NSRect(x: (w - 32) / 2, y: h - 186, width: 32, height: 32))
        spinner.style = .spinning
        spinner.isHidden = true
        content.addSubview(spinner)

        // -- Buttons (bottom row)
        let btnW: CGFloat = 130
        let btnH: CGFloat = 32
        let btnY: CGFloat = 16
        let spacing: CGFloat = 12
        let totalW = btnW * 2 + spacing
        let startX = (w - totalW) / 2

        secondaryButton = NSButton(frame: NSRect(x: startX, y: btnY, width: btnW, height: btnH))
        secondaryButton.bezelStyle = .rounded
        secondaryButton.title = "Cancel"
        secondaryButton.target = nil
        secondaryButton.action = #selector(ToolWindow.secondaryClicked(_:))
        content.addSubview(secondaryButton)

        primaryButton = NSButton(frame: NSRect(x: startX + btnW + spacing, y: btnY, width: btnW, height: btnH))
        primaryButton.bezelStyle = .rounded
        primaryButton.title = "OK"
        primaryButton.keyEquivalent = "\r"
        primaryButton.target = nil
        primaryButton.action = #selector(ToolWindow.primaryClicked(_:))
        content.addSubview(primaryButton)
    }

    @objc static func primaryClicked(_ sender: Any?) {
        NSApplication.shared.stopModal(withCode: .alertFirstButtonReturn)
    }

    @objc static func secondaryClicked(_ sender: Any?) {
        NSApplication.shared.stopModal(withCode: .alertSecondButtonReturn)
    }

    /// Update the window to reflect the given state, then run modal and return the button code.
    func show(state: DialogState, apps: [AppEntry] = []) -> NSApplication.ModalResponse {
        primaryButton.target = ToolWindow.self
        secondaryButton.target = ToolWindow.self

        switch state {
        case .selection:
            iconView.image = badgedIcon(base: brandingIcon, badge: .none)
            titleLabel.stringValue = "Delete and Reinstall an Application"
            messageLabel.stringValue = "Select the app, then click \"Delete & Reinstall\"."
            popup.isHidden = false
            popup.removeAllItems()
            popup.addItem(withTitle: "Select Application...")
            for app in apps {
                popup.addItem(withTitle: app.displayName)
            }
            spinner.isHidden = true
            spinner.stopAnimation(nil)
            primaryButton.title = "Delete & Reinstall"
            primaryButton.isHidden = false
            primaryButton.isEnabled = true
            secondaryButton.title = "Cancel"
            secondaryButton.isHidden = false

        case .confirmation(let app):
            iconView.image = badgedIcon(base: brandingIcon, badge: .warning)
            titleLabel.stringValue = "Confirm Delete & Reinstall"
            messageLabel.stringValue = "\(app.displayName) will be quit, deleted, and reinstalled. This may take a moment."
            popup.isHidden = true
            spinner.isHidden = true
            spinner.stopAnimation(nil)
            primaryButton.title = "OK"
            primaryButton.isHidden = false
            primaryButton.isEnabled = true
            secondaryButton.title = "Cancel"
            secondaryButton.isHidden = false

        case .working(let message):
            iconView.image = badgedIcon(base: brandingIcon, badge: .working)
            titleLabel.stringValue = "Working..."
            messageLabel.stringValue = message
            popup.isHidden = true
            spinner.isHidden = false
            spinner.startAnimation(nil)
            primaryButton.isHidden = true
            secondaryButton.isHidden = true
            // Don't run modal for working state — caller manages the run loop.
            window.orderFront(nil)
            window.display()
            return .continue

        case .success(let app):
            iconView.image = badgedIcon(base: brandingIcon, badge: .success)
            titleLabel.stringValue = "Complete"
            messageLabel.stringValue = "\(app.displayName) has been reinstalled successfully."
            popup.isHidden = true
            spinner.isHidden = true
            spinner.stopAnimation(nil)
            primaryButton.title = "OK"
            primaryButton.isHidden = false
            primaryButton.isEnabled = true
            secondaryButton.isHidden = true

        case .error(let message):
            iconView.image = badgedIcon(base: brandingIcon, badge: .error)
            titleLabel.stringValue = "Error"
            messageLabel.stringValue = message
            popup.isHidden = true
            spinner.isHidden = true
            spinner.stopAnimation(nil)
            primaryButton.title = "OK"
            primaryButton.isHidden = false
            primaryButton.isEnabled = true
            secondaryButton.isHidden = true
        }

        window.orderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        return NSApplication.shared.runModal(for: window)
    }

    /// Update the working message without blocking.
    func updateWorkingMessage(_ message: String) {
        messageLabel.stringValue = message
        window.display()
    }

    var selectedPopupIndex: Int {
        return popup.indexOfSelectedItem
    }
}

// MARK: - Main

log("DeleteReinstall starting")

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.activate(ignoringOtherApps: true)

guard let config = loadConfig() else {
    logError("Failed to load configuration")
    exit(1)
}
log("Loaded \(config.apps.count) apps from config")

guard let user = getLoggedInUser() else {
    logError("No user logged in")
    exit(1)
}
log("Logged-in user: \(user.username) (uid \(user.uid))")

let icon = getBrandingIcon(username: user.username)
let toolWindow = ToolWindow(icon: icon)

// Step 1: Selection
let selResponse = toolWindow.show(state: .selection, apps: config.apps)
guard selResponse == .alertFirstButtonReturn else {
    log("User cancelled selection dialog")
    exit(0)
}

let index = toolWindow.selectedPopupIndex
guard index > 0 else {
    let _ = toolWindow.show(state: .error("No application was selected."))
    exit(0)
}

let selectedApp = config.apps[index - 1]
log("Selected: \(selectedApp.displayName) (\(selectedApp.bundleName), policy \(selectedApp.jamfPolicyID))")

// Step 2: Check if installed
let appPath = "/Applications/\(selectedApp.bundleName)"
guard FileManager.default.fileExists(atPath: appPath) else {
    let _ = toolWindow.show(state: .error("\(selectedApp.displayName) is not installed and cannot be deleted."))
    log("\(selectedApp.bundleName) not found at \(appPath)")
    exit(0)
}

// Step 3: Confirmation
let confResponse = toolWindow.show(state: .confirmation(selectedApp))
guard confResponse == .alertFirstButtonReturn else {
    log("User cancelled confirmation")
    exit(0)
}

// Step 4: Working — quit, delete, reinstall
let _ = toolWindow.show(state: .working("Quitting \(selectedApp.displayName)..."))

let dockInfo = getDockInfo(dockLabel: selectedApp.dockLabel, username: user.username, uid: user.uid)

gracefullyQuitApp(bundleIdentifier: selectedApp.bundleIdentifier)

toolWindow.updateWorkingMessage("Deleting \(selectedApp.displayName)...")

guard deleteApp(bundleName: selectedApp.bundleName) else {
    let _ = toolWindow.show(state: .error("Failed to delete \(selectedApp.displayName). Contact IT."))
    exit(1)
}

toolWindow.updateWorkingMessage("Reinstalling \(selectedApp.displayName)...")

guard triggerReinstall(policyID: selectedApp.jamfPolicyID) else {
    let _ = toolWindow.show(state: .error("Reinstall failed for \(selectedApp.displayName). Contact IT."))
    exit(1)
}

if let dock = dockInfo {
    toolWindow.updateWorkingMessage("Restoring dock position...")
    restoreDockPosition(app: selectedApp, section: dock.section, position: dock.position, username: user.username, uid: user.uid)
}

// Step 5: Success
log("Delete & Reinstall complete for \(selectedApp.displayName)")
let _ = toolWindow.show(state: .success(selectedApp))
exit(0)
