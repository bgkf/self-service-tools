#!/bin/bash
set -euo pipefail

VERSION="2.0.2"
IDENTIFIER="com.wellthy.delete-reinstall"
PKG_NAME="DeleteReinstall-${VERSION}.pkg"
PAYLOAD_ROOT="$(mktemp -d)"
SCRIPTS_DIR="$(mktemp -d)"
INSTALL_DIR="/Library/Management/DeleteReinstall"

echo "==> Building Delete & Reinstall package v${VERSION}"

# ── COMPILE BINARY ───────────────────────────────────────────────────────────
echo "==> Compiling delete-reinstall binary..."
swiftc DeleteReinstall.swift \
    -O \
    -framework AppKit \
    -framework Foundation \
    -framework SystemConfiguration \
    -target x86_64-apple-macos13 \
    -o /tmp/dr_x86 2>&1 || {
        echo "    NOTE: x86_64 compile failed (expected on Apple Silicon without cross-compile SDK)"
        echo "    Falling back to native arch only..."
        swiftc DeleteReinstall.swift \
            -O \
            -framework AppKit \
            -framework Foundation \
            -framework SystemConfiguration \
            -o /tmp/dr_native
        cp /tmp/dr_native /tmp/dr_universal
    }

if [ -f /tmp/dr_x86 ]; then
    swiftc DeleteReinstall.swift \
        -O \
        -framework AppKit \
        -framework Foundation \
        -framework SystemConfiguration \
        -target arm64-apple-macos13 \
        -o /tmp/dr_arm64

    lipo -create /tmp/dr_x86 /tmp/dr_arm64 \
         -output /tmp/dr_universal
    echo "    Universal binary created (arm64 + x86_64)"
fi

# ── ASSEMBLE PAYLOAD ────────────────────────────────────────────────────────
echo "==> Assembling package payload..."

mkdir -p "${PAYLOAD_ROOT}${INSTALL_DIR}"
cp /tmp/dr_universal "${PAYLOAD_ROOT}${INSTALL_DIR}/delete-reinstall"
chmod 755 "${PAYLOAD_ROOT}${INSTALL_DIR}/delete-reinstall"

cp apps.json "${PAYLOAD_ROOT}${INSTALL_DIR}/apps.json"
chmod 644 "${PAYLOAD_ROOT}${INSTALL_DIR}/apps.json"

# ── PREPARE SCRIPTS ─────────────────────────────────────────────────────────
echo "==> Preparing installer scripts..."

cat > "${SCRIPTS_DIR}/postinstall" << 'POSTINSTALL'
#!/bin/bash
set -euo pipefail

INSTALL_DIR="/Library/Management/DeleteReinstall"
BINARY="${INSTALL_DIR}/delete-reinstall"
CONFIG="${INSTALL_DIR}/apps.json"
LOG_TAG="DeleteReinstall"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [$LOG_TAG] $*"; }

if [ ! -f "$BINARY" ]; then
    log "ERROR: binary not found at $BINARY"
    exit 1
fi

log "Setting permissions..."
chown root:wheel "$BINARY"
chmod 755 "$BINARY"
chown root:wheel "$CONFIG"
chmod 644 "$CONFIG"

log "Removing quarantine attributes..."
xattr -cr "$INSTALL_DIR"

log "Installation complete."
exit 0
POSTINSTALL

chmod +x "${SCRIPTS_DIR}/postinstall"

echo "    Scripts directory contents:"
ls -la "${SCRIPTS_DIR}/"

# ── BUILD PACKAGE ────────────────────────────────────────────────────────────
echo "==> Running pkgbuild..."
pkgbuild \
    --root "${PAYLOAD_ROOT}" \
    --identifier "${IDENTIFIER}" \
    --version "${VERSION}" \
    --scripts "${SCRIPTS_DIR}" \
    --install-location "/" \
    "${PKG_NAME}"

# ── VERIFY PACKAGE ───────────────────────────────────────────────────────────
echo "==> Verifying package..."
VERIFY_DIR="$(mktemp -d)"
pkgutil --expand "${PKG_NAME}" "${VERIFY_DIR}/expanded"
echo "    Bundled scripts:"
ls -la "${VERIFY_DIR}/expanded/Scripts/" 2>/dev/null || echo "    WARNING: Scripts directory not found in package!"
echo "    Payload contents:"
find "${VERIFY_DIR}/expanded" -name "delete-reinstall" -o -name "apps.json" | sed "s|${VERIFY_DIR}/expanded||"
rm -rf "${VERIFY_DIR}"

# ── CLEANUP ──────────────────────────────────────────────────────────────────
rm -rf "${PAYLOAD_ROOT}"
rm -rf "${SCRIPTS_DIR}"
rm -f /tmp/dr_x86 /tmp/dr_arm64 /tmp/dr_native /tmp/dr_universal

echo ""
echo "==> Done: ${PKG_NAME}"
echo ""
echo "    Upload this package to Jamf Pro:"
echo "    Settings > Computer Management > Packages > + New"
echo ""
echo "    Installed path:"
echo "      ${INSTALL_DIR}/delete-reinstall"
echo "      ${INSTALL_DIR}/apps.json"
