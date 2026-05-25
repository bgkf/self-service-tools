#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PRODUCT_NAME="DownloadOne"
VERSION="${1:-1.3.0}"
INSTALL_DIR="/Library/Management/DownloadOne"
BUILD_DIR="${SCRIPT_DIR}/.build/release"
PKG_ROOT="${SCRIPT_DIR}/.build/pkg-root"
PKG_OUTPUT="${SCRIPT_DIR}/${PRODUCT_NAME}-${VERSION}.pkg"

echo "==> Building ${PRODUCT_NAME} (release)…"
cd "$SCRIPT_DIR"
swift build -c release

echo "==> Assembling package root…"
rm -rf "$PKG_ROOT"
mkdir -p "${PKG_ROOT}${INSTALL_DIR}"
cp "${BUILD_DIR}/${PRODUCT_NAME}" "${PKG_ROOT}${INSTALL_DIR}/${PRODUCT_NAME}"
chmod 755 "${PKG_ROOT}${INSTALL_DIR}/${PRODUCT_NAME}"

echo "==> Building installer package…"
pkgbuild \
    --root "$PKG_ROOT" \
    --identifier "com.acme.downloadone" \
    --version "$VERSION" \
    --ownership recommended \
    "$PKG_OUTPUT"

echo "==> Done: ${PKG_OUTPUT}"
