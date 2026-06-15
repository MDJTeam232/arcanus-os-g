#!/bin/bash
set -euo pipefail

# Arcanus OS Live Build Script
# Customizes Linux Mint with Arcanus branding

BUILD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="${BUILD_DIR}/dist"
LB_CONFIG="${BUILD_DIR}/lb-config"

echo "🔧 Building Arcanus OS (Linux Mint based)..."

# Create distribution directory
mkdir -p "${DIST_DIR}"

# Initialize live-build config
if [ ! -d "${LB_CONFIG}" ]; then
    echo "📦 Initializing live-build config..."
    mkdir -p "${LB_CONFIG}"
    cd "${LB_CONFIG}"
    lb config \
        --distribution jammy \
        --archive-areas "main universe restricted multiverse" \
        --image-type iso-hybrid \
        --iso-application "Arcanus OS" \
        --iso-preparer "MDJ Team" \
        --iso-publisher "Arcanus Finance" \
        --iso-volume "ARCANUS_OS" \
        --hostname arcanus \
        --username arcanus \
        --bootappend-live "boot=live components quiet splash" \
        --bootloader syslinux \
        --linux-packages linux-image-generic \
        --includes "${BUILD_DIR}/rootfs"
fi

# Copy Arcanus branding to filesystem
echo "🎨 Applying Arcanus branding..."
cp -r "${BUILD_DIR}/branding"/* "${LB_CONFIG}/chroot/etc/branding/" 2>/dev/null || true
cp -r "${BUILD_DIR}/theme"/* "${LB_CONFIG}/chroot/usr/share/themes/" 2>/dev/null || true

# Build ISO
echo "⚙️  Building ISO image..."
cd "${LB_CONFIG}"
lb build noiso 2>&1 | tee "${DIST_DIR}/build.log"
lb build iso 2>&1 | tee -a "${DIST_DIR}/build.log"

# Copy output
if [ -f "${LB_CONFIG}/live-image-amd64.iso" ]; then
    cp "${LB_CONFIG}/live-image-amd64.iso" "${DIST_DIR}/arcanus-os-demo.iso"
    echo "✅ ISO built: ${DIST_DIR}/arcanus-os-demo.iso"
else
    echo "❌ Build failed. Check ${DIST_DIR}/build.log"
    exit 1
fi
