# Building Native Swift macOS Tools for Jamf Self Service

Patterns and gotchas learned from building DownloadOne and DeleteReinstall — reusable for any future Swift CLI/GUI tool deployed via Jamf.

---

## Project Structure

Use Swift Package Manager (not Xcode project) for simplicity:

```
ToolName/
├── Package.swift
├── Sources/
│   ├── App/
│   │   └── ToolNameApp.swift
│   ├── ViewModels/
│   ├── Views/
│   ├── Models/
│   ├── Services/
│   └── Utilities/
├── build_package.sh
└── ToolName_SelfService.sh
```

`Package.swift` minimum:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ToolName",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "ToolName", path: "Sources")
    ]
)
```

macOS 14+ is required for `.symbolEffect(.pulse)` and hierarchical SF Symbol rendering.

---

## Window Activation (Critical)

A SwiftUI app launched from a Jamf script runs in a non-interactive root shell with no window server connection. Without explicit activation, the window renders but **cannot receive keyboard or mouse input**.

Required boilerplate in the App entry point:

```swift
@main
struct ToolNameApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                window.makeKeyAndOrderFront(nil)
                window.styleMask.remove(.resizable)
            }
        }
    }
}
```

Key points:
- `.setActivationPolicy(.accessory)` — establishes the window server connection. Without this, the app is invisible to the GUI. Use `.accessory` (no dock icon/menu bar) rather than `.regular`.
- `.activate(ignoringOtherApps: true)` — brings the window to front and makes it key.
- `window.makeKeyAndOrderFront(nil)` — ensures keyboard input routes to this window.
- The `DispatchQueue.main.async` delay is needed because SwiftUI may not have created the window yet when `applicationDidFinishLaunching` fires.

---

## Credential / Parameter Passing (Critical)

**Do NOT pass credentials as command line arguments.** SwiftUI and AppKit consume `CommandLine.arguments` internally and may misinterpret custom arguments, causing the app to silently fail to launch.

Use **environment variables** instead:

```swift
// In your ViewModel or service init:
let env = ProcessInfo.processInfo.environment
self.clientId = env["TOOLNAME_CLIENT_ID"] ?? ""
self.clientSecret = env["TOOLNAME_CLIENT_SECRET"] ?? ""
```

The Self Service script sets them before launching the binary:

```bash
export TOOLNAME_CLIENT_ID="$4"
export TOOLNAME_CLIENT_SECRET="$5"
"$BINARY"
```

---

## Self Service Launcher Script

Jamf script parameters 1-3 are predefined (mount point, computer name, username). Custom parameters start at `$4`.

```bash
#!/bin/bash
# ToolName_SelfService.sh

BINARY="/Library/Management/ToolName/ToolName"

if [ ! -f "$BINARY" ]; then
    echo "Binary not found at $BINARY"
    exit 1
fi

export TOOLNAME_CLIENT_ID="$4"
export TOOLNAME_CLIENT_SECRET="$5"
"$BINARY"
```

The binary runs directly as root — **do not use `launchctl asuser`**. The process inherits the GUI session from Self Service. This is how DeleteReinstall works and is confirmed functional.

---

## Text Field Focus

SwiftUI text fields won't receive input by default even after window activation. Use `@FocusState`:

```swift
@FocusState private var fieldFocused: Bool

TextField("", text: $viewModel.someText)
    .focused($fieldFocused)

// In .onAppear:
fieldFocused = true
```

---

## Logged-In User Detection

Use `SCDynamicStoreCopyConsoleUser` (requires `import SystemConfiguration`):

```swift
var loggedInUser: String {
    var uid: uid_t = 0
    let user = SCDynamicStoreCopyConsoleUser(nil, &uid, nil) as String?
    return user ?? "unknown"
}
```

This works when running as root and returns the GUI session user.

---

## File Ownership

When running as root, files you create are owned by root. To set ownership to the logged-in user:

```swift
try? FileManager.default.setAttributes(
    [.ownerAccountName: loggedInUser],
    ofItemAtPath: path
)
```

Use `try?` so it degrades gracefully if the tool is run as a non-root user (files will already be user-owned).

---

## XML Parsing (Jamf Classic API)

Use Foundation's `XMLDocument` instead of xmlstarlet:

```swift
let xmlDoc = try XMLDocument(data: data, options: [])
let root = xmlDoc.rootElement()!

// Extract values
let name = try root.nodes(forXPath: "name").first?.stringValue

// Remove nodes (equivalent to xmlstarlet ed --delete)
for node in try root.nodes(forXPath: "id") {
    node.detach()
}

// Pretty-print
let cleaned = xmlDoc.xmlString(options: [.nodePrettyPrint])
```

---

## Jamf OAuth2 Authentication

```swift
// POST https://<instance>.jamfcloud.com/api/oauth/token
// Content-Type: application/x-www-form-urlencoded
// Body: client_id=<id>&grant_type=client_credentials&client_secret=<secret>
```

Always invalidate the token on exit:

```swift
// POST /api/v1/auth/invalidate-token
// Authorization: Bearer <token>
```

---

## Build & Package Script

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PRODUCT_NAME="ToolName"
VERSION="${1:-1.0.0}"
INSTALL_DIR="/Library/Management/ToolName"
BUILD_DIR="${SCRIPT_DIR}/.build/release"
PKG_ROOT="${SCRIPT_DIR}/.build/pkg-root"
PKG_OUTPUT="${SCRIPT_DIR}/${PRODUCT_NAME}-${VERSION}.pkg"

cd "$SCRIPT_DIR"
swift build -c release

rm -rf "$PKG_ROOT"
mkdir -p "${PKG_ROOT}${INSTALL_DIR}"
cp "${BUILD_DIR}/${PRODUCT_NAME}" "${PKG_ROOT}${INSTALL_DIR}/${PRODUCT_NAME}"
chmod 755 "${PKG_ROOT}${INSTALL_DIR}/${PRODUCT_NAME}"

pkgbuild \
    --root "$PKG_ROOT" \
    --identifier "com.acme.toolname" \
    --version "$VERSION" \
    --ownership recommended \
    "$PKG_OUTPUT"
```

---

## Deployment Checklist

1. `./build_package.sh` — compile and create `.pkg`
2. Upload `.pkg` to Jamf Pro (Settings > Computer Management > Packages)
3. Upload `ToolName_SelfService.sh` as a Jamf script, set parameter labels for 4/5
4. Create a Self Service policy: attach the package + the script
5. Set parameter 4/5 values in the policy

---

## Common Pitfalls

| Problem | Cause | Fix |
|---|---|---|
| Window shows but can't type or click | Missing `setActivationPolicy(.accessory)` | Add AppDelegate with activation boilerplate |
| App silently fails to launch with args | AppKit consumes `CommandLine.arguments` | Use environment variables instead |
| App doesn't launch from Self Service | Missing activation policy or using `launchctl asuser` | Run binary directly as root with AppDelegate activation |
| Text field doesn't accept input | Window isn't key, field isn't focused | Use `@FocusState` + `.focused()` + `.onAppear` |
| Self Service branding icon overrides your icon | Branding image path exists on disk | Use SF Symbols directly, skip branding image fallback |
| `symbolEffect(.pulse)` won't compile | Platform target too low | Set `.macOS(.v14)` in Package.swift |
