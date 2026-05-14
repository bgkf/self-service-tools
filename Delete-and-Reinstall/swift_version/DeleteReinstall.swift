import AppKit
import Foundation
import SystemConfiguration

// MARK: - Data Model

struct AppEntry: Codable {
    let displayName: String
    let bundleName: String
    let bundleIdentifier: String
    let bundleId: String
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

// MARK: - App Icon Resolution

/// Resolve an app icon from the bundle identifier, falling back to the app name, then a generic SF Symbol.
func resolveAppIcon(bundleId: String, bundleName: String) -> NSImage {
    // Try NSWorkspace.urlForApplication(withBundleIdentifier:) — macOS 12+
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 36, height: 36)
        return icon
    }
    // Fallback: look in /Applications by bundle name
    let appPath = "/Applications/\(bundleName)"
    if FileManager.default.fileExists(atPath: appPath) {
        let icon = NSWorkspace.shared.icon(forFile: appPath)
        icon.size = NSSize(width: 36, height: 36)
        return icon
    }
    // Final fallback: generic SF Symbol
    if let symbol = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: bundleName) {
        let config = NSImage.SymbolConfiguration(pointSize: 28, weight: .regular)
        return symbol.withSymbolConfiguration(config) ?? symbol
    }
    return NSImage()
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

// MARK: - Icon Grid Cell

class AppIconButton: NSView {
    let appEntry: AppEntry
    let iconView: NSImageView
    let nameLabel: NSTextField
    var isSelected: Bool = false { didSet { needsDisplay = true } }
    var onClick: ((AppEntry) -> Void)?

    init(frame: NSRect, app: AppEntry) {
        self.appEntry = app

        // Icon centered in upper portion of cell
        let iconSize: CGFloat = 36
        let iconX = (frame.width - iconSize) / 2
        iconView = NSImageView(frame: NSRect(x: iconX, y: frame.height - iconSize - 8, width: iconSize, height: iconSize))
        iconView.imageScaling = .scaleProportionallyUpOrDown

        // Placeholder — will be replaced async
        if let placeholder = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: app.displayName) {
            let config = NSImage.SymbolConfiguration(pointSize: 28, weight: .regular)
                .applying(.init(paletteColors: [.secondaryLabelColor]))
            iconView.image = placeholder.withSymbolConfiguration(config) ?? placeholder
        }

        // Name label below icon
        nameLabel = NSTextField(labelWithString: app.displayName)
        nameLabel.frame = NSRect(x: 2, y: 4, width: frame.width - 4, height: 28)
        nameLabel.font = .systemFont(ofSize: 10)
        nameLabel.alignment = .center
        nameLabel.maximumNumberOfLines = 2
        nameLabel.lineBreakMode = .byWordWrapping
        nameLabel.textColor = .labelColor

        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 8

        addSubview(iconView)
        addSubview(nameLabel)

        // Load real icon async
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let resolved = resolveAppIcon(bundleId: app.bundleId, bundleName: app.bundleName)
            DispatchQueue.main.async {
                self?.iconView.image = resolved
            }
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if isSelected {
            NSColor.controlAccentColor.withAlphaComponent(0.25).setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
            NSColor.controlAccentColor.setStroke()
            let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
            border.lineWidth = 1.5
            border.stroke()
        } else {
            NSColor.quaternaryLabelColor.withAlphaComponent(0.15).setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        onClick?(appEntry)
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

enum StatusBadge {
    case none
    case warning
    case error
    case success
    case working
}

func badgedIcon(base: NSImage?, badge: StatusBadge) -> NSImage {
    let size = NSSize(width: 36, height: 36)
    let result = NSImage(size: size)
    result.lockFocus()

    if let base = base {
        base.draw(in: NSRect(origin: .zero, size: size))
    }

    if badge != .none {
        let badgeSize: CGFloat = 16
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
            configured.draw(in: badgeRect.insetBy(dx: 1, dy: 1))
        }
    }

    result.unlockFocus()
    return result
}

// MARK: - Tool Window

class ToolWindow {
    let window: NSWindow
    let brandingIconView: NSImageView
    let titleLabel: NSTextField
    let messageLabel: NSTextField
    let gridContainer: NSView
    let primaryButton: NSButton
    let secondaryButton: NSButton
    let spinner: NSProgressIndicator
    let brandingIcon: NSImage?

    // Status icon for confirmation/error/success/working states (centered, replaces grid)
    let statusIconView: NSImageView
    // Large app icon shown in status states
    let appIconView: NSImageView

    private var iconButtons: [AppIconButton] = []
    private var selectedApp: AppEntry? = nil
    private var selectedAppIcon: NSImage? = nil

    // Layout constants
    static let winW: CGFloat = 380
    static let statusH: CGFloat = 280
    static let headerH: CGFloat = 80    // topInset + icon/title/message
    static let buttonAreaH: CGFloat = 80 // buttons + padding
    static let cellH: CGFloat = 80
    static let vSpacing: CGFloat = 8

    /// Compute window height dynamically based on number of apps.
    static func selectionHeight(appCount: Int) -> CGFloat {
        let columns = 3
        let rows = Int(ceil(Double(appCount) / Double(columns)))
        let gridH = CGFloat(rows) * (cellH + vSpacing)
        return headerH + gridH + buttonAreaH + 16
    }

    init(icon: NSImage?) {
        self.brandingIcon = icon

        let w = ToolWindow.winW
        let h = ToolWindow.selectionHeight(appCount: 9) // default, resized on show()

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

        // -- Branding icon (top-left, below title bar)
        let topInset: CGFloat = 32
        brandingIconView = NSImageView(frame: NSRect(x: 16, y: h - topInset - 42, width: 36, height: 36))
        brandingIconView.imageScaling = .scaleProportionallyUpOrDown
        brandingIconView.image = icon
        content.addSubview(brandingIconView)

        // -- Title (next to branding icon)
        titleLabel = NSTextField(labelWithString: "")
        titleLabel.frame = NSRect(x: 58, y: h - topInset - 36, width: w - 74, height: 22)
        titleLabel.font = .boldSystemFont(ofSize: 15)
        titleLabel.alignment = .left
        content.addSubview(titleLabel)

        // -- Message (below title)
        messageLabel = NSTextField(wrappingLabelWithString: "")
        messageLabel.frame = NSRect(x: 58, y: h - topInset - 56, width: w - 74, height: 18)
        messageLabel.font = .systemFont(ofSize: 12)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.alignment = .left
        messageLabel.maximumNumberOfLines = 1
        content.addSubview(messageLabel)

        // -- Grid container (for selection state)
        let gridY: CGFloat = 60
        let gridH: CGFloat = h - topInset - 74 - gridY
        gridContainer = NSView(frame: NSRect(x: 16, y: gridY, width: w - 32, height: gridH))
        content.addSubview(gridContainer)

        // -- Status icon (centered, for non-selection states)
        statusIconView = NSImageView(frame: NSRect(x: (w - 64) / 2, y: h - 140, width: 64, height: 64))
        statusIconView.imageScaling = .scaleProportionallyUpOrDown
        statusIconView.isHidden = true
        content.addSubview(statusIconView)

        // -- App icon (large, centered, shown in status states)
        appIconView = NSImageView(frame: NSRect(x: (w - 64) / 2, y: h - 140, width: 64, height: 64))
        appIconView.imageScaling = .scaleProportionallyUpOrDown
        appIconView.isHidden = true
        content.addSubview(appIconView)

        // -- Spinner
        spinner = NSProgressIndicator(frame: NSRect(x: (w - 32) / 2, y: 80, width: 32, height: 32))
        spinner.style = .spinning
        spinner.isHidden = true
        content.addSubview(spinner)

        // -- Buttons
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

    private func buildGrid(apps: [AppEntry]) {
        // Clear existing
        gridContainer.subviews.forEach { $0.removeFromSuperview() }
        iconButtons.removeAll()
        selectedApp = nil

        let columns = 3
        let gridW = gridContainer.bounds.width
        let cellW = floor(gridW / CGFloat(columns)) - 8
        let cellH = ToolWindow.cellH
        let hSpacing: CGFloat = 8
        let vSpacing = ToolWindow.vSpacing

        for (i, app) in apps.enumerated() {
            let col = i % columns
            let row = i / columns
            let x = CGFloat(col) * (cellW + hSpacing)
            // Top-aligned: row 0 at top of gridContainer
            let y = gridContainer.bounds.height - CGFloat(row + 1) * (cellH + vSpacing)

            let btn = AppIconButton(frame: NSRect(x: x, y: y, width: cellW, height: cellH), app: app)
            btn.onClick = { [weak self] selected in
                self?.selectApp(selected)
            }
            gridContainer.addSubview(btn)
            iconButtons.append(btn)
        }
    }

    private func selectApp(_ app: AppEntry) {
        selectedApp = app
        selectedAppIcon = resolveAppIcon(bundleId: app.bundleId, bundleName: app.bundleName)
        for btn in iconButtons {
            btn.isSelected = (btn.appEntry.displayName == app.displayName)
        }
        primaryButton.isEnabled = true
    }

    private func resizeWindow(height: CGFloat) {
        var frame = window.frame
        let delta = height - frame.height
        frame.size.height = height
        frame.origin.y -= delta
        window.setFrame(frame, display: true, animate: true)
        repositionViews(height: height)
    }

    private func repositionViews(height: CGFloat) {
        let w = ToolWindow.winW
        let topInset: CGFloat = 32

        brandingIconView.frame = NSRect(x: 16, y: height - topInset - 42, width: 36, height: 36)
        titleLabel.frame = NSRect(x: 58, y: height - topInset - 36, width: w - 74, height: 22)
        messageLabel.frame = NSRect(x: 58, y: height - topInset - 56, width: w - 74, height: 18)

        let gridY: CGFloat = 60
        let gridH: CGFloat = height - topInset - 74 - gridY
        gridContainer.frame = NSRect(x: 16, y: gridY, width: w - 32, height: gridH)

        statusIconView.frame = NSRect(x: (w - 64) / 2, y: height - topInset - 150, width: 64, height: 64)
        appIconView.frame = NSRect(x: (w - 64) / 2, y: height - topInset - 110, width: 64, height: 64)
        spinner.frame = NSRect(x: (w - 32) / 2, y: height / 2 - 40, width: 32, height: 32)
    }

    /// Configure the layout for status states (confirmation, working, success, error).
    /// Shows the selected app icon centered, with larger centered title and message below it.
    private func configureStatusLayout(height: CGFloat, badge: StatusBadge, title: String, message: String, showAppIcon: Bool = true) {
        let w = ToolWindow.winW
        let topInset: CGFloat = 32

        gridContainer.isHidden = true
        statusIconView.isHidden = true

        // App icon — large, centered
        if showAppIcon, let appIcon = selectedAppIcon {
            appIconView.image = appIcon
            appIconView.isHidden = false
            appIconView.frame = NSRect(x: (w - 64) / 2, y: height - topInset - 110, width: 64, height: 64)
        } else {
            appIconView.isHidden = true
        }

        // Branding icon — top left with badge
        brandingIconView.isHidden = false
        brandingIconView.image = badgedIcon(base: brandingIcon, badge: badge)

        // Title — centered, larger
        titleLabel.stringValue = title
        titleLabel.font = .boldSystemFont(ofSize: 17)
        titleLabel.alignment = .center
        let titleY: CGFloat = showAppIcon ? height - topInset - 140 : height - topInset - 80
        titleLabel.frame = NSRect(x: 20, y: titleY, width: w - 40, height: 24)

        // Message — centered, larger
        messageLabel.stringValue = message
        messageLabel.font = .systemFont(ofSize: 13)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.alignment = .center
        messageLabel.maximumNumberOfLines = 2
        messageLabel.frame = NSRect(x: 20, y: titleY - 36, width: w - 40, height: 32)

        // Spinner — below message
        spinner.frame = NSRect(x: (w - 32) / 2, y: titleY - 76, width: 32, height: 32)
    }

    func show(state: DialogState, apps: [AppEntry] = []) -> NSApplication.ModalResponse {
        primaryButton.target = ToolWindow.self
        secondaryButton.target = ToolWindow.self

        switch state {
        case .selection:
            let selH = ToolWindow.selectionHeight(appCount: apps.count)
            resizeWindow(height: selH)
            brandingIconView.image = brandingIcon
            brandingIconView.isHidden = false
            titleLabel.stringValue = "Delete & Reinstall"
            titleLabel.font = .boldSystemFont(ofSize: 15)
            titleLabel.alignment = .left
            titleLabel.frame = NSRect(x: 58, y: selH - 32 - 36, width: ToolWindow.winW - 74, height: 22)
            messageLabel.stringValue = "Select an app below"
            messageLabel.font = .systemFont(ofSize: 12)
            messageLabel.textColor = .secondaryLabelColor
            messageLabel.alignment = .left
            messageLabel.maximumNumberOfLines = 1
            messageLabel.frame = NSRect(x: 58, y: selH - 32 - 56, width: ToolWindow.winW - 74, height: 18)
            gridContainer.isHidden = false
            statusIconView.isHidden = true
            appIconView.isHidden = true
            spinner.isHidden = true
            spinner.stopAnimation(nil)
            buildGrid(apps: apps)
            primaryButton.title = "Delete & Reinstall"
            primaryButton.isHidden = false
            primaryButton.isEnabled = false
            secondaryButton.title = "Cancel"
            secondaryButton.isHidden = false

        case .confirmation(let app):
            resizeWindow(height: ToolWindow.statusH)
            configureStatusLayout(height: ToolWindow.statusH, badge: .warning,
                title: "Confirm Delete & Reinstall",
                message: "\(app.displayName) will be quit, deleted, and reinstalled.")
            spinner.isHidden = true
            spinner.stopAnimation(nil)
            primaryButton.title = "OK"
            primaryButton.isHidden = false
            primaryButton.isEnabled = true
            secondaryButton.title = "Cancel"
            secondaryButton.isHidden = false

        case .working(let message):
            resizeWindow(height: ToolWindow.statusH)
            configureStatusLayout(height: ToolWindow.statusH, badge: .working,
                title: "Working...",
                message: message)
            spinner.isHidden = false
            spinner.startAnimation(nil)
            primaryButton.isHidden = true
            secondaryButton.isHidden = true
            window.orderFront(nil)
            window.display()
            return .continue

        case .success(let app):
            resizeWindow(height: ToolWindow.statusH)
            configureStatusLayout(height: ToolWindow.statusH, badge: .success,
                title: "Complete",
                message: "\(app.displayName) has been reinstalled successfully.")
            spinner.isHidden = true
            spinner.stopAnimation(nil)
            primaryButton.title = "OK"
            primaryButton.isHidden = false
            primaryButton.isEnabled = true
            secondaryButton.isHidden = true

        case .error(let message):
            resizeWindow(height: ToolWindow.statusH)
            configureStatusLayout(height: ToolWindow.statusH, badge: .error,
                title: "Error",
                message: message, showAppIcon: false)
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

    func updateWorkingMessage(_ message: String) {
        messageLabel.stringValue = message
        messageLabel.alignment = .center
        window.display()
    }

    var selectedAppEntry: AppEntry? {
        return selectedApp
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

// Filter to only installed apps
let installedApps = config.apps.filter { FileManager.default.fileExists(atPath: "/Applications/\($0.bundleName)") }
log("Found \(installedApps.count) of \(config.apps.count) apps installed")

if installedApps.isEmpty {
    let _ = toolWindow.show(state: .error("No managed apps are currently installed."))
    exit(0)
}

// Step 1: Selection via icon grid
let selResponse = toolWindow.show(state: .selection, apps: installedApps)
guard selResponse == .alertFirstButtonReturn else {
    log("User cancelled selection dialog")
    exit(0)
}

guard let selectedApp = toolWindow.selectedAppEntry else {
    let _ = toolWindow.show(state: .error("No application was selected."))
    exit(0)
}
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
