// SplitPDFUI.swift
// Floating panel UI for the Split PDF tool.
// Compiled into a binary by build_ui_package.sh and launched from Jamf Self Service.

import AppKit
import Foundation

// MARK: - Constants

let kBinary     = "/usr/local/bin/splitpdf"
let kMaxMB      = 10.0
let kMaxNameLen = 10

// MARK: - Logging

func log(_ message: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    print("[\(ts)] [SplitPDFUI] \(message)")
    fflush(stdout)
}

func logError(_ message: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    fputs("[\(ts)] [SplitPDFUI] ERROR: \(message)\n", stderr)
    fflush(stderr)
}

// MARK: - Validation

func isValidName(_ name: String) -> (alphanumeric: Bool, length: Bool) {
    let alphanumeric = !name.isEmpty && name.unicodeScalars.allSatisfy {
        CharacterSet.alphanumerics.contains($0)
    }
    let length = name.count <= kMaxNameLen && name.count > 0
    return (alphanumeric, length)
}

// MARK: - Drop Zone View

class DropZoneView: NSView {
    var onPDFDropped: ((URL) -> Void)?
    var droppedURL: URL? { didSet { needsDisplay = true } }
    var isInvalid: Bool = false { didSet { needsDisplay = true } }
    var isDragOver: Bool = false { didSet { needsDisplay = true } }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 10
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let accent = NSColor.controlAccentColor

        // Background fill and border — use system colors only
        if droppedURL != nil {
            accent.withAlphaComponent(0.1).setFill()
            layer?.borderColor = accent.cgColor
            layer?.borderWidth = 2.0
        } else if isInvalid {
            NSColor.systemRed.withAlphaComponent(0.1).setFill()
            layer?.borderColor = NSColor.systemRed.cgColor
            layer?.borderWidth = 2.0
        } else if isDragOver {
            accent.withAlphaComponent(0.12).setFill()
            layer?.borderColor = accent.cgColor
            layer?.borderWidth = 2.0
        } else {
            // Standard unfilled drop zone — dashed border
            NSColor.clear.setFill()
            layer?.borderColor = NSColor.separatorColor.cgColor
            layer?.borderWidth = 1.5
        }
        NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10).fill()

        // Dashed border when idle
        if droppedURL == nil && !isInvalid && !isDragOver {
            let dash = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 10, yRadius: 10)
            dash.lineWidth = 1.5
            let pattern: [CGFloat] = [6, 4]
            dash.setLineDash(pattern, count: 2, phase: 0)
            NSColor.tertiaryLabelColor.setStroke()
            dash.stroke()
        }

        // PDF icon — upper center
        let iconSize: CGFloat = 36
        let icon: NSImage
        if let dropped = droppedURL {
            icon = NSWorkspace.shared.icon(forFile: dropped.path)
        } else {
            icon = NSWorkspace.shared.icon(forFileType: "pdf")
        }
        icon.size = NSSize(width: iconSize, height: iconSize)
        let iconX = (bounds.width - iconSize) / 2
        let iconY = bounds.midY + 6
        icon.draw(in: NSRect(x: iconX, y: iconY, width: iconSize, height: iconSize))

        // Primary label
        let primaryLabel: String
        let primaryColor: NSColor
        if let dropped = droppedURL {
            let name = dropped.lastPathComponent
            primaryLabel = name.count > 24
                ? String(name.prefix(11)) + "…" + String(name.suffix(11))
                : name
            primaryColor = accent
        } else if isInvalid {
            primaryLabel = "PDFs only"
            primaryColor = .systemRed
        } else {
            primaryLabel = "Drop PDF here"
            primaryColor = .secondaryLabelColor
        }

        let primaryAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: primaryColor
        ]
        let primaryStr = NSAttributedString(string: primaryLabel, attributes: primaryAttrs)
        let primarySz  = primaryStr.size()
        primaryStr.draw(at: NSPoint(
            x: (bounds.width - primarySz.width) / 2,
            y: bounds.midY - primarySz.height - 2
        ))

        // Hint — only when idle and no file
        if droppedURL == nil && !isInvalid {
            let hintAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.tertiaryLabelColor
            ]
            let hintStr = NSAttributedString(string: "or click to browse", attributes: hintAttrs)
            let hintSz  = hintStr.size()
            hintStr.draw(at: NSPoint(
                x: (bounds.width - hintSz.width) / 2,
                y: bounds.midY - primarySz.height - hintSz.height - 8
            ))
        }
    }

    override func mouseUp(with event: NSEvent) {
        DispatchQueue.main.async {
            let picker = NSOpenPanel()
            picker.allowedFileTypes        = ["pdf"]
            picker.allowsMultipleSelection = false
            picker.canChooseDirectories    = false
            picker.canChooseFiles          = true
            picker.title                   = "Select a PDF"
            picker.prompt                  = "Select"

            // Attach as a sheet to the main panel window so it opens
            // in front of the GUI rather than behind it
            if let window = self.window {
                picker.beginSheetModal(for: window) { [weak self] response in
                    guard let self = self else { return }
                    if response == .OK, let url = picker.url {
                        log("File selected via picker: \(url.path)")
                        self.isInvalid  = false
                        self.droppedURL = url
                        self.onPDFDropped?(url)
                    }
                }
            } else {
                // Fallback if window reference is unavailable
                NSApp.activate(ignoringOtherApps: true)
                picker.begin { [weak self] response in
                    guard let self = self else { return }
                    if response == .OK, let url = picker.url {
                        log("File selected via picker: \(url.path)")
                        self.isInvalid  = false
                        self.droppedURL = url
                        self.onPDFDropped?(url)
                    }
                }
            }
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if urlFromDrag(sender)?.pathExtension.lowercased() == "pdf" {
            isDragOver = true
            isInvalid  = false
            return .copy
        }
        isDragOver = false
        isInvalid  = true
        return []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDragOver   = false
        isInvalid    = false
        needsDisplay = true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDragOver = false
        guard let url = urlFromDrag(sender),
              url.pathExtension.lowercased() == "pdf" else {
            isInvalid = true
            log("Drop rejected — not a PDF")
            return false
        }
        isInvalid  = false
        droppedURL = url
        log("PDF dropped: \(url.path)")
        onPDFDropped?(url)
        return true
    }

    private func urlFromDrag(_ sender: NSDraggingInfo) -> URL? {
        sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )?.first as? URL
    }
}

// MARK: - Validation Row

class ValidationRow: NSView {
    private let indicator = NSTextField(labelWithString: "")
    private let label     = NSTextField(labelWithString: "")

    init(labelText: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: 240, height: 18))
        indicator.font  = .systemFont(ofSize: 13)
        indicator.frame = NSRect(x: 0, y: 0, width: 18, height: 18)
        label.font      = .systemFont(ofSize: 13)
        label.frame     = NSRect(x: 22, y: 0, width: 218, height: 18)
        label.stringValue = labelText
        addSubview(indicator)
        addSubview(label)
        setState(nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setState(_ passing: Bool?) {
        switch passing {
        case nil:
            indicator.stringValue = "○"
            indicator.textColor   = .tertiaryLabelColor
            label.textColor       = .secondaryLabelColor
        case true:
            indicator.stringValue = "✓"
            indicator.textColor   = .controlAccentColor
            label.textColor       = .labelColor
        case false:
            indicator.stringValue = "✗"
            indicator.textColor   = .systemRed
            label.textColor       = .systemRed
        }
    }
}

// MARK: - Main Panel Controller

class SplitPDFController: NSObject, NSTextFieldDelegate {

    var panel: NSPanel!
    var dropZone: DropZoneView!
    var nameField: NSTextField!
    var charCounter: NSTextField!
    var alphanumRow: ValidationRow!
    var lengthRow: ValidationRow!
    var splitButton: NSButton!
    var cancelButton: NSButton!
    var statusLabel: NSTextField!
    var exampleLabel: NSTextField!
    var closeButton: NSButton!
    var revealButton: NSButton!

    var droppedURL: URL?
    var outputDirURL: URL?

    let panelW: CGFloat = 600
    let panelH: CGFloat = 300
    let pad:    CGFloat = 24
    let dropW:  CGFloat = 210
    let gutter: CGFloat = 20

    func buildAndShow() {
        log("Building UI panel")

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelW, height: panelH),
            styleMask:   [.titled, .closable, .nonactivatingPanel],
            backing:     .buffered,
            defer:       false
        )
        panel.title             = "Split a PDF"
        panel.level             = .floating
        panel.isFloatingPanel   = true
        panel.hidesOnDeactivate = false
        panel.center()

        // Use NSVisualEffectView as the content view for correct HIG-compliant
        // background in both light and dark mode
        let fx = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: panelW, height: panelH))
        fx.material     = .windowBackground
        fx.blendingMode = .behindWindow
        fx.state        = .active
        panel.contentView = fx

        let rightX = pad + dropW + gutter
        let rightW = panelW - rightX - pad
        var y: CGFloat = pad

        // ── BUTTONS ROW ───────────────────────────────────────────────────
        let btnW = (rightW - 12) / 2

        // Close / Reveal (shown after success)
        closeButton = NSButton(frame: NSRect(x: rightX, y: y, width: btnW, height: 28))
        closeButton.title      = "Close"
        closeButton.bezelStyle = .rounded
        closeButton.target     = self
        closeButton.action     = #selector(didClose)
        closeButton.isHidden   = true
        fx.addSubview(closeButton)

        revealButton = NSButton(frame: NSRect(x: rightX + btnW + 12, y: y, width: btnW, height: 28))
        revealButton.title      = "Show in Finder"
        revealButton.bezelStyle = .rounded
        revealButton.target     = self
        revealButton.action     = #selector(didReveal)
        revealButton.isHidden   = true
        fx.addSubview(revealButton)

        // Cancel / Split (shown initially)
        cancelButton = NSButton(frame: NSRect(x: rightX, y: y, width: btnW, height: 28))
        cancelButton.title      = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.target     = self
        cancelButton.action     = #selector(didCancel)
        fx.addSubview(cancelButton)

        splitButton = NSButton(frame: NSRect(x: rightX + btnW + 12, y: y, width: btnW, height: 28))
        splitButton.title         = "Split PDF"
        splitButton.bezelStyle    = .rounded
        splitButton.keyEquivalent = "\r"
        splitButton.target        = self
        splitButton.action        = #selector(didSplit)
        splitButton.isEnabled     = false
        fx.addSubview(splitButton)

        y += 40

        // ── STATUS LABEL ──────────────────────────────────────────────────
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.frame         = NSRect(x: rightX, y: y, width: rightW, height: 36)
        statusLabel.font          = .systemFont(ofSize: 13)
        statusLabel.textColor     = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.isHidden      = true
        fx.addSubview(statusLabel)

        y += 44

        // ── VALIDATION ROWS ───────────────────────────────────────────────
        lengthRow = ValidationRow(labelText: "Max \(kMaxNameLen) characters")
        lengthRow.frame = NSRect(x: rightX, y: y, width: rightW, height: 18)
        fx.addSubview(lengthRow)
        y += 24

        alphanumRow = ValidationRow(labelText: "Letters and numbers only")
        alphanumRow.frame = NSRect(x: rightX, y: y, width: rightW, height: 18)
        fx.addSubview(alphanumRow)
        y += 32

        // ── EXAMPLE LABEL (below input) ───────────────────────────────────
        exampleLabel = NSTextField(labelWithString: "e.g. testing01.pdf, testing02.pdf…")
        exampleLabel.frame         = NSRect(x: rightX, y: y, width: rightW, height: 18)
        exampleLabel.font          = .systemFont(ofSize: 12)
        exampleLabel.textColor     = .tertiaryLabelColor
        exampleLabel.lineBreakMode = .byTruncatingTail
        fx.addSubview(exampleLabel)
        y += 22

        // ── CHARACTER COUNTER + NAME FIELD ────────────────────────────────
        charCounter = NSTextField(labelWithString: "0/\(kMaxNameLen)")
        charCounter.frame     = NSRect(x: rightX + rightW - 40, y: y, width: 40, height: 20)
        charCounter.font      = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        charCounter.textColor = .tertiaryLabelColor
        charCounter.alignment = .right
        fx.addSubview(charCounter)

        nameField = NSTextField(frame: NSRect(x: rightX, y: y, width: rightW - 48, height: 22))
        nameField.placeholderString = "e.g. testing"
        nameField.delegate          = self
        nameField.font              = .systemFont(ofSize: 14)
        fx.addSubview(nameField)
        y += 30

        // ── OUTPUT NAME LABEL ─────────────────────────────────────────────
        let nameLabel = NSTextField(labelWithString: "Enter a name for the split PDFs")
        nameLabel.frame     = NSRect(x: rightX, y: y, width: rightW, height: 18)
        nameLabel.font      = .systemFont(ofSize: 13, weight: .semibold)
        nameLabel.textColor = .labelColor
        fx.addSubview(nameLabel)
        y += 28

        // ── CRITERIA NOTE ─────────────────────────────────────────────────
        let note = NSTextField(labelWithString:
            "Alphanumeric only · max \(kMaxNameLen) chars · \(Int(kMaxMB)) MB chunks")
        note.frame         = NSRect(x: rightX, y: y, width: rightW, height: 16)
        note.font          = .systemFont(ofSize: 11)
        note.textColor     = .tertiaryLabelColor
        fx.addSubview(note)

        // ── DROP ZONE ─────────────────────────────────────────────────────
        let dropH = panelH - (pad * 2)
        dropZone = DropZoneView(frame: NSRect(x: pad, y: pad, width: dropW, height: dropH))
        dropZone.onPDFDropped = { [weak self] url in
            self?.droppedURL = url
            self?.validateAll()
        }
        fx.addSubview(dropZone)

        // ── INFO BUTTON (top-right corner) ───────────────────────────────
        let infoButton = NSButton(frame: NSRect(x: panelW - 32, y: panelH - 32, width: 24, height: 24))
        infoButton.bezelStyle  = .helpButton
        infoButton.title       = ""
        infoButton.target      = self
        infoButton.action      = #selector(didShowInfo(_:))
        fx.addSubview(infoButton)

        panel.makeKeyAndOrderFront(nil)
        log("UI panel displayed")
    }

    // MARK: - Info popover

    @objc func didShowInfo(_ sender: NSButton) {
        let popover = NSPopover()
        popover.behavior = .transient

        let vc = NSViewController()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 320))
        vc.view = view

        // Title
        let title = NSTextField(labelWithString: "Split PDF — Requirements")
        title.frame     = NSRect(x: 16, y: 288, width: 268, height: 22)
        title.font      = .systemFont(ofSize: 14, weight: .semibold)
        title.textColor = .labelColor
        view.addSubview(title)

        // Divider
        let divider = NSBox(frame: NSRect(x: 16, y: 278, width: 268, height: 1))
        divider.boxType = .separator
        view.addSubview(divider)

        // Requirements
        let requirements = [
            "PDF files only",
            "Entered name: letters and numbers only",
            "Entered name: max 10 characters",
            "A 2-digit number is appended automatically",
            "  e.g. testing → testing01.pdf",
            "Each split PDF is under \(Int(kMaxMB)) MB",
        ]

        var ry: CGFloat = 248
        for req in requirements {
            let row = NSTextField(labelWithString: req)
            row.frame     = NSRect(x: req.hasPrefix(" ") ? 30 : 16, y: ry, width: 268, height: 18)
            row.font      = .systemFont(ofSize: 12)
            row.textColor = req.hasPrefix(" ") ? .secondaryLabelColor : .labelColor
            view.addSubview(row)
            ry -= 24
        }

        // Divider
        let divider2 = NSBox(frame: NSRect(x: 16, y: ry + 6, width: 268, height: 1))
        divider2.boxType = .separator
        view.addSubview(divider2)
        ry -= 16

        // Contact
        let contactTitle = NSTextField(labelWithString: "Need help?")
        contactTitle.frame     = NSRect(x: 16, y: ry, width: 268, height: 18)
        contactTitle.font      = .systemFont(ofSize: 12, weight: .semibold)
        contactTitle.textColor = .labelColor
        view.addSubview(contactTitle)
        ry -= 22

        // Slack channel link
        let slackTeamID   = "T04FG340V"   // ← replace with your Slack team ID
        let slackChannelID = "CFT5YH5QF"  // ← replace with your #helpdesk channel ID
        let slackURL      = URL(string: "slack://channel?team=\(slackTeamID)&id=\(slackChannelID)")!

        let contactInfo = NSTextField(labelWithString: "")
        contactInfo.frame                       = NSRect(x: 16, y: ry, width: 268, height: 18)
        contactInfo.isSelectable                = true
        contactInfo.allowsEditingTextAttributes = true
        contactInfo.drawsBackground             = false
        contactInfo.isBordered                  = false

        let slackText  = "Contact IT in the #helpdesk Slack channel"
        let slackRange = (slackText as NSString).range(of: "#helpdesk Slack channel")
        let slackLinked = NSMutableAttributedString(string: slackText, attributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor
        ])
        slackLinked.addAttributes([
            .link: slackURL,
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ], range: slackRange)
        contactInfo.attributedStringValue = slackLinked
        view.addSubview(contactInfo)

        ry -= 22

        // Support document link
        let supportDocURL = URL(string: "https://app.getguru.com/card/cayen4qi/Troubleshooting-Document-Upload-Issues")! // ← replace with your support doc URL
        let supportInfo   = NSTextField(labelWithString: "")
        supportInfo.frame                       = NSRect(x: 16, y: ry, width: 268, height: 18)
        supportInfo.isSelectable                = true
        supportInfo.allowsEditingTextAttributes = true
        supportInfo.drawsBackground             = false
        supportInfo.isBordered                  = false

        let supportText  = "View the support document"
        let supportRange = (supportText as NSString).range(of: supportText)
        let supportLinked = NSMutableAttributedString(string: supportText, attributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor
        ])
        supportLinked.addAttributes([
            .link: supportDocURL,
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ], range: supportRange)
        supportInfo.attributedStringValue = supportLinked
        view.addSubview(supportInfo)

        popover.contentViewController = vc
        popover.contentSize = view.frame.size
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
        log("Info popover shown")
    }

    // MARK: - Example label

    func updateExampleLabel() {
        let name = nameField?.stringValue ?? ""
        if name.isEmpty {
            exampleLabel.stringValue = "e.g. testing01.pdf, testing02.pdf…"
            exampleLabel.textColor   = .tertiaryLabelColor
        } else {
            let v = isValidName(name)
            if v.alphanumeric && v.length {
                exampleLabel.stringValue = "\(name)01.pdf, \(name)02.pdf…"
                exampleLabel.textColor   = .controlAccentColor
            } else {
                exampleLabel.stringValue = "Fix the name to see a preview"
                exampleLabel.textColor   = .tertiaryLabelColor
            }
        }
    }

    // MARK: - Validation

    func validateAll() {
        let name    = nameField.stringValue
        let v       = isValidName(name)
        let hasFile = droppedURL != nil

        if name.isEmpty {
            alphanumRow.setState(nil)
            lengthRow.setState(nil)
            charCounter.stringValue = "0/\(kMaxNameLen)"
            charCounter.textColor   = .tertiaryLabelColor
        } else {
            alphanumRow.setState(v.alphanumeric)
            lengthRow.setState(v.length)
            charCounter.stringValue = "\(name.count)/\(kMaxNameLen)"
            charCounter.textColor   = name.count > kMaxNameLen ? .systemRed : .tertiaryLabelColor
        }

        updateExampleLabel()
        splitButton.isEnabled = hasFile && v.alphanumeric && v.length
        log("Validation — name: '\(name)' alphanumeric: \(v.alphanumeric) length: \(v.length) hasFile: \(hasFile)")
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        validateAll()
    }

    // MARK: - Actions

    @objc func didCancel() {
        log("User cancelled")
        NSApp.terminate(nil)
    }

    @objc func didClose() {
        log("User closed panel")
        NSApp.terminate(nil)
    }

    @objc func didReveal() {
        if let url = outputDirURL {
            log("Revealing output directory: \(url.path)")
            NSWorkspace.shared.open(url)
        }
        NSApp.terminate(nil)
    }

    @objc func didSplit() {
        guard let url = droppedURL else { return }
        let name = nameField.stringValue

        log("Starting split — file: \(url.path) name: \(name) maxMB: \(kMaxMB)")

        splitButton.isEnabled  = false
        cancelButton.isEnabled = false
        nameField.isEnabled    = false
        dropZone.alphaValue    = 0.5

        statusLabel.stringValue = "Splitting the PDF, please wait…\nLarge PDFs (100+ pages) may take several minutes."
        statusLabel.textColor   = .secondaryLabelColor
        statusLabel.isHidden    = false

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let fm         = FileManager.default
            let tempDir    = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let renamedPDF = tempDir.appendingPathComponent("\(name).pdf")

            do {
                try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
                try fm.copyItem(at: url, to: renamedPDF)
                log("Copied PDF to temp location: \(renamedPDF.path)")
            } catch {
                self.showError("Could not prepare PDF: \(error.localizedDescription)")
                return
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: kBinary)
            process.arguments     = [renamedPDF.path, String(kMaxMB)]

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError  = errPipe

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                self.showError("Could not launch splitpdf: \(error.localizedDescription)")
                try? fm.removeItem(at: tempDir)
                return
            }

            let outStr = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let errStr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

            if !outStr.isEmpty { log("splitpdf stdout: \(outStr.trimmingCharacters(in: .whitespacesAndNewlines))") }
            if !errStr.isEmpty { logError("splitpdf stderr: \(errStr.trimmingCharacters(in: .whitespacesAndNewlines))") }

            guard process.terminationStatus == 0 else {
                self.showError("splitpdf failed (exit \(process.terminationStatus))")
                try? fm.removeItem(at: tempDir)
                return
            }

            let tempOutputDir  = tempDir.appendingPathComponent(name)
            let finalOutputDir = url.deletingLastPathComponent().appendingPathComponent(name)

            do {
                if fm.fileExists(atPath: finalOutputDir.path) {
                    try fm.removeItem(at: finalOutputDir)
                }
                try fm.moveItem(at: tempOutputDir, to: finalOutputDir)
                try fm.removeItem(at: tempDir)
                log("Output moved to: \(finalOutputDir.path)")
            } catch {
                self.showError("Could not move output: \(error.localizedDescription)")
                return
            }

            self.outputDirURL = finalOutputDir

            let files = (try? fm.contentsOfDirectory(atPath: finalOutputDir.path)) ?? []
            let count = files.filter { $0.hasSuffix(".pdf") }.count
            log("Split complete — \(count) file(s) written to \(finalOutputDir.path)")

            DispatchQueue.main.async {
                self.showSuccess("\(count) file\(count == 1 ? "" : "s") written to \(name)/")
            }
        }
    }

    // MARK: - Result states

    func showSuccess(_ message: String) {
        statusLabel.stringValue = "✓  " + message
        statusLabel.textColor   = .controlAccentColor
        statusLabel.isHidden    = false
        splitButton.isHidden    = true
        cancelButton.isHidden   = true
        closeButton.isHidden    = false
        revealButton.isHidden   = false
    }

    func showError(_ message: String) {
        logError(message)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.statusLabel.stringValue = "✗  " + message
            self.statusLabel.textColor   = .systemRed
            self.statusLabel.isHidden    = false
            self.splitButton.isEnabled   = true
            self.cancelButton.isEnabled  = true
            self.nameField.isEnabled     = true
            self.dropZone.alphaValue     = 1.0
        }
    }
}

// MARK: - App entry point

log("splitpdfui starting")

let app        = NSApplication.shared
app.setActivationPolicy(.accessory)

let controller = SplitPDFController()
controller.buildAndShow()

app.activate(ignoringOtherApps: true)
app.run()