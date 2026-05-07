# Split A PDF — Self Service UI

A native AppKit floating panel launched from Jamf Self Service. Allows users to split a large PDF into size-limited chunks with a custom output name, entirely through a GUI with no terminal interaction.

## Files

### `SplitPDFUI.swift`
Source code for the `splitpdfui` binary. Compiled on the build Mac and deployed as a compiled binary — Xcode and Xcode CLT are not required on target Macs.

**Drop zone**
- Accepts PDF files via drag and drop
- Turns green with the filename shown on a valid PDF drop
- Turns red with an error message if a non-PDF file is dropped

**Output name field**
- Live `0/12` character counter that turns red when the limit is exceeded
- Two real-time validation rows that update on every keystroke:
  - `✓` / `✗` / `○` — Letters and numbers only
  - `✓` / `✗` / `○` — Maximum 12 characters
- Split PDF button stays disabled until both validations pass and a PDF is dropped

**On success**
- Shows `✓ N files written to <name>/` inline
- Split PDF button is replaced by Close and Show in Finder buttons

**On error**
- Shows the error message inline in red
- Re-enables all controls so the user can correct and retry

> **Note on naming:** The UI copies the PDF to a temp location renamed to the user's chosen name before calling the `splitpdf` binary. The binary's sanitize step is effectively a no-op since the name is already clean, and the output directory takes the user's exact chosen name.

---

### `Sources/main.swift`
Source code for the `splitpdf` CLI binary. Compiled on the build Mac — not deployed directly to target Macs.

---

### `SplitPDF_SelfService.sh`
The Jamf script that launches the UI in the logged-in user's session.

- Verifies both binaries are present before launching
- Shows a friendly error alert if either is missing
- Launches `splitpdfui` in the correct user session via `runAsUser`

---

### `build_ui_package.sh`
Single build script that compiles both binaries and packages them in one step.

- Compiles `Sources/main.swift` → `splitpdf` universal binary (arm64 + x86_64)
- Compiles `SplitPDFUI.swift` → `splitpdfui` universal binary (arm64 + x86_64)
- Assembles both binaries into the package payload
- Copies and renames `postinstall` script for `pkgbuild`
- Verifies scripts and payload contents before finishing
- Produces `SplitPDFUI-1.0.0.pkg` ready to upload to Jamf Pro

---

## Deployment

| File | Installed path |
|------|---------------|
| CLI binary | `/usr/local/bin/splitpdf` |
| UI binary | `/Library/Management/SplitPDF/splitpdfui` |
| Jamf launch script | Uploaded directly to Jamf Pro — not packaged |

### Steps

```bash
# 1. Make the build script executable
chmod +x build_ui_package.sh

# 2. Build — compiles both binaries and assembles the .pkg
./build_ui_package.sh
```

This produces `SplitPDFUI-1.0.0.pkg` in the project root.

1. Upload `SplitPDFUI-1.0.0.pkg` to Jamf Pro:
   **Settings → Computer Management → Packages → + New**

2. Upload `SplitPDF_SelfService.sh` to Jamf Pro:
   **Settings → Computer Management → Scripts → + New**

3. Create a Self Service policy:
   - Payload: the package above
   - Scripts: `SplitPDF_SelfService.sh` set to run **After**
   - Scope: your target machines or All Managed Computers
   - Enable in Self Service with a name and description

> **Note:** A logout/login cycle is required after the first install for the Finder Quick Action to appear. The Self Service UI launches immediately with no logout required.

## Dependencies

| | Build Mac | Target Macs |
|---|---|---|
| Xcode CLT | Required (to compile binaries) | Not required |
| macOS 11 or later | Required | Required |
