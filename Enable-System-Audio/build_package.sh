#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PRODUCT_NAME="NotionAudioEnabler"
VERSION="${1:-1.0.0}"
INSTALL_DIR="/Library/Management/NotionAudioEnabler"
BUILD_DIR="${SCRIPT_DIR}/.build/release"
PKG_ROOT="${SCRIPT_DIR}/.build/pkg-root"
PKG_OUTPUT="${SCRIPT_DIR}/${PRODUCT_NAME}-${VERSION}.pkg"

SIGN_IDENTITY="${SIGN_IDENTITY:-}"
PKG_SIGN_IDENTITY="${PKG_SIGN_IDENTITY:-}"

cd "$SCRIPT_DIR"

echo "==> Building ${PRODUCT_NAME} v${VERSION}..."
swift build -c release

echo "==> Preparing package payload..."
rm -rf "$PKG_ROOT"
mkdir -p "${PKG_ROOT}${INSTALL_DIR}"
cp "${BUILD_DIR}/${PRODUCT_NAME}" "${PKG_ROOT}${INSTALL_DIR}/${PRODUCT_NAME}"
chmod 755 "${PKG_ROOT}${INSTALL_DIR}/${PRODUCT_NAME}"

if [ -n "$SIGN_IDENTITY" ]; then
    echo "==> Code signing binary with: ${SIGN_IDENTITY}"
    codesign --force --sign "$SIGN_IDENTITY" \
        --options runtime \
        "${PKG_ROOT}${INSTALL_DIR}/${PRODUCT_NAME}"
    codesign --verify --verbose "${PKG_ROOT}${INSTALL_DIR}/${PRODUCT_NAME}"
fi

echo "==> Building .pkg..."
PKG_CMD=(
    pkgbuild
    --root "$PKG_ROOT"
    --identifier "com.wellthy.notion-audio-enabler"
    --version "$VERSION"
    --ownership recommended
)

if [ -n "$PKG_SIGN_IDENTITY" ]; then
    PKG_CMD+=(--sign "$PKG_SIGN_IDENTITY")
fi

PKG_CMD+=("$PKG_OUTPUT")
"${PKG_CMD[@]}"

echo ""
echo "==> Package built: ${PKG_OUTPUT}"
echo "    Installs to: ${INSTALL_DIR}/${PRODUCT_NAME}"
echo ""
echo "Upload this .pkg to Jamf Pro and create a Self Service policy."
