#!/bin/bash
# build_ui_package.sh
# Builds the Split PDF Self Service UI package.
# Compiles both main.swift and SplitPDFUI.swift into binaries and packages them.
# Run from the root of this project directory.

set -euo pipefail

VERSION="1.0.0"
IDENTIFIER="com.yourorg.splitpdf.ui"
PKG_NAME="SplitPDFUI-${VERSION}.pkg"
PAYLOAD_ROOT="$(mktemp -d)"
SCRIPTS_DIR="$(mktemp -d)"

echo "==> Building Split PDF UI package v${VERSION}"

# ── COMPILE splitpdf BINARY ───────────────────────────────────────────────────
echo "==> Compiling splitpdf binary..."
swiftc Sources/main.swift \
    -O \
    -framework PDFKit \
    -framework CoreGraphics \
    -framework Foundation \
    -target x86_64-apple-macos11 \
    -o /tmp/splitpdf_x86 2>&1 || {
        echo "    NOTE: x86_64 compile failed (expected on Apple Silicon without cross-compile SDK)"
        echo "    Falling back to native arch only..."
        swiftc Sources/main.swift \
            -O \
            -framework PDFKit \
            -framework CoreGraphics \
            -framework Foundation \
            -o /tmp/splitpdf_native
        cp /tmp/splitpdf_native /tmp/splitpdf_universal
    }

if [ -f /tmp/splitpdf_x86 ]; then
    swiftc Sources/main.swift \
        -O \
        -framework PDFKit \
        -framework CoreGraphics \
        -framework Foundation \
        -target arm64-apple-macos11 \
        -o /tmp/splitpdf_arm64

    lipo -create /tmp/splitpdf_x86 /tmp/splitpdf_arm64 \
         -output /tmp/splitpdf_universal
    echo "    Universal binary created (arm64 + x86_64)"
fi

# ── COMPILE splitpdfui BINARY ─────────────────────────────────────────────────
echo "==> Compiling splitpdfui binary..."
swiftc SplitPDFUI.swift \
    -O \
    -framework AppKit \
    -framework Foundation \
    -target x86_64-apple-macos11 \
    -o /tmp/splitpdfui_x86 2>&1 || {
        echo "    NOTE: x86_64 compile failed (expected on Apple Silicon without cross-compile SDK)"
        echo "    Falling back to native arch only..."
        swiftc SplitPDFUI.swift \
            -O \
            -framework AppKit \
            -framework Foundation \
            -o /tmp/splitpdfui_native
        cp /tmp/splitpdfui_native /tmp/splitpdfui_universal
    }

if [ -f /tmp/splitpdfui_x86 ]; then
    swiftc SplitPDFUI.swift \
        -O \
        -framework AppKit \
        -framework Foundation \
        -target arm64-apple-macos11 \
        -o /tmp/splitpdfui_arm64

    lipo -create /tmp/splitpdfui_x86 /tmp/splitpdfui_arm64 \
         -output /tmp/splitpdfui_universal
    echo "    Universal binary created (arm64 + x86_64)"
fi

# ── ASSEMBLE PAYLOAD ──────────────────────────────────────────────────────────
echo "==> Assembling package payload..."

# splitpdf binary → /usr/local/bin/splitpdf
mkdir -p "${PAYLOAD_ROOT}/usr/local/bin"
cp /tmp/splitpdf_universal "${PAYLOAD_ROOT}/usr/local/bin/splitpdf"
chmod 755 "${PAYLOAD_ROOT}/usr/local/bin/splitpdf"

# splitpdfui binary → /Library/Management/SplitPDF/splitpdfui
mkdir -p "${PAYLOAD_ROOT}/Library/Management/SplitPDF"
cp /tmp/splitpdfui_universal "${PAYLOAD_ROOT}/Library/Management/SplitPDF/splitpdfui"
chmod 755 "${PAYLOAD_ROOT}/Library/Management/SplitPDF/splitpdfui"

# ── PREPARE SCRIPTS ───────────────────────────────────────────────────────────
echo "==> Preparing installer scripts..."

cat > "${SCRIPTS_DIR}/postinstall" << 'POSTINSTALL'
#!/bin/bash
set -euo pipefail

BINARY="/usr/local/bin/splitpdf"
UI_BINARY="/Library/Management/SplitPDF/splitpdfui"
LOG_TAG="SplitPDFUI"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [$LOG_TAG] $*"; }

if [ ! -f "$BINARY" ]; then
    log "ERROR: splitpdf binary not found at $BINARY"
    exit 1
fi

if [ ! -f "$UI_BINARY" ]; then
    log "ERROR: splitpdfui binary not found at $UI_BINARY"
    exit 1
fi

log "Setting permissions on splitpdf..."
chown root:wheel "$BINARY"
chmod 755 "$BINARY"

log "Setting permissions on splitpdfui..."
chown root:wheel "$UI_BINARY"
chmod 755 "$UI_BINARY"

log "Removing quarantine attributes..."
xattr -cr "$BINARY"
xattr -cr "$UI_BINARY"

log "Installation complete."
exit 0
POSTINSTALL

chmod +x "${SCRIPTS_DIR}/postinstall"

echo "    Scripts directory contents:"
ls -la "${SCRIPTS_DIR}/"

# ── BUILD PACKAGE ─────────────────────────────────────────────────────────────
echo "==> Running pkgbuild..."
pkgbuild \
    --root "${PAYLOAD_ROOT}" \
    --identifier "${IDENTIFIER}" \
    --version "${VERSION}" \
    --scripts "${SCRIPTS_DIR}" \
    --install-location "/" \
    "${PKG_NAME}"

# ── VERIFY PACKAGE ────────────────────────────────────────────────────────────
echo "==> Verifying package..."
VERIFY_DIR="$(mktemp -d)"
pkgutil --expand "${PKG_NAME}" "${VERIFY_DIR}/expanded"
echo "    Bundled scripts:"
ls -la "${VERIFY_DIR}/expanded/Scripts/" 2>/dev/null || echo "    WARNING: Scripts directory not found in package!"
echo "    Payload binaries:"
find "${VERIFY_DIR}/expanded" -name "splitpdf" -o -name "splitpdfui" | sed "s|${VERIFY_DIR}/expanded||"
rm -rf "${VERIFY_DIR}"

# ── CLEANUP ───────────────────────────────────────────────────────────────────
rm -rf "${PAYLOAD_ROOT}"
rm -rf "${SCRIPTS_DIR}"
rm -f /tmp/splitpdf_x86 /tmp/splitpdf_arm64 /tmp/splitpdf_native /tmp/splitpdf_universal
rm -f /tmp/splitpdfui_x86 /tmp/splitpdfui_arm64 /tmp/splitpdfui_native /tmp/splitpdfui_universal

echo ""
echo "==> Done: ${PKG_NAME}"
echo ""
echo "    Upload this package to Jamf Pro:"
echo "    Settings → Computer Management → Packages → + New"
echo ""
echo "    Installed paths:"
echo "      /usr/local/bin/splitpdf"
echo "      /Library/Management/SplitPDF/splitpdfui"