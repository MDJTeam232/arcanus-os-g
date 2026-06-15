#!/bin/bash
# Arcanus OS Remaster Script
# Converts Linux Mint ISO to Arcanus OS branded ISO
# Usage: ./remaster-iso.sh <input-iso> <output-dir>

set -euo pipefail

MINT_ISO="${1:?Missing argument: path to Linux Mint ISO}"
OUTPUT_DIR="${2:-.dist}"
WORK_DIR=".work"
BUILD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRANDING_DIR="${BUILD_DIR}/branding"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_ok() { echo -e "${GREEN}✓${NC} $*"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $*"; }
log_err() { echo -e "${RED}✗${NC} $*"; exit 1; }

# Verify inputs
[ -f "${MINT_ISO}" ] || log_err "ISO not found: ${MINT_ISO}"
[ -d "${BRANDING_DIR}" ] || log_err "Branding directory not found: ${BRANDING_DIR}"
mkdir -p "${OUTPUT_DIR}"

# Check for required tools
for cmd in mount unsquashfs mksquashfs mkisofs rsync; do
    command -v "${cmd}" >/dev/null 2>&1 || log_err "Required tool missing: ${cmd}"
done

# Create work directory
log_info "Setting up work environment..."
sudo rm -rf "${WORK_DIR}" 2>/dev/null || true
mkdir -p "${WORK_DIR}"/{mnt,extracted,squashfs-root}
log_ok "Work directory ready"

# Mount and extract ISO (use remount to make writable)
log_info "Extracting Linux Mint ISO..."
sudo mount -o loop,ro "${MINT_ISO}" "${WORK_DIR}/mnt" 2>/dev/null || log_err "Failed to mount ISO"

# Use tar to extract instead of rsync to avoid permission issues
log_info "Copying ISO contents..."
cd "${WORK_DIR}/mnt"
sudo tar --exclude='*.squashfs' -cf - . | (cd "${WORK_DIR}/extracted" && sudo tar -xf -)
cd - >/dev/null

sudo umount "${WORK_DIR}/mnt"
log_ok "ISO extracted"

# Extract squashfs
log_info "Extracting filesystem..."
cd "${WORK_DIR}/extracted/casper"
sudo unsquashfs -d "${WORK_DIR}/squashfs-root" filesystem.squashfs 2>&1 | grep -v "Parallel unsquashfs" || true
log_ok "Filesystem extracted"

# Fix permissions on squashfs-root
sudo chmod -R u+w "${WORK_DIR}/squashfs-root"

# Apply branding
log_info "Applying Arcanus branding..."

# Copy wallpaper
if [ -f "${BRANDING_DIR}/wallpaper.png" ]; then
    sudo cp "${BRANDING_DIR}/wallpaper.png" "${WORK_DIR}/squashfs-root/usr/share/backgrounds/arcanus-wallpaper.png"
    log_ok "Wallpaper installed"
fi

# Copy logo
if [ -f "${BRANDING_DIR}/arcanus-logo.png" ]; then
    sudo cp "${BRANDING_DIR}/arcanus-logo.png" "${WORK_DIR}/squashfs-root/usr/share/pixmaps/arcanus-logo.png"
    log_ok "Logo installed"
fi

# Copy icon theme if exists
if [ -d "${BRANDING_DIR}/icon-theme" ]; then
    sudo mkdir -p "${WORK_DIR}/squashfs-root/usr/share/icons/Arcanus"
    sudo cp -r "${BRANDING_DIR}/icon-theme"/* "${WORK_DIR}/squashfs-root/usr/share/icons/Arcanus/"
    log_ok "Icon theme installed"
fi

# Copy GTK theme if exists
if [ -d "${BRANDING_DIR}/theme" ]; then
    sudo cp -r "${BRANDING_DIR}/theme" "${WORK_DIR}/squashfs-root/usr/share/themes/"
    log_ok "GTK theme installed"
fi

# Update branding files
log_info "Customizing boot environment..."
sudo tee "${WORK_DIR}/squashfs-root/etc/issue" > /dev/null << 'EOF'

 ╔═══════════════════════════════════════╗
 ║   ARCANUS OS – Secure Finance         ║
 ║   Based on Linux Mint 22 Cinnamon     ║
 ╚═══════════════════════════════════════╝

EOF

# Create Arcanus Ledger desktop shortcut
if [ -f "${BUILD_DIR}/dist/arcanus-ledger-linux.tar.gz" ] || [ -d "${BUILD_DIR}/arcanus-ledger" ]; then
    log_info "Installing Arcanus Ledger..."
    sudo mkdir -p "${WORK_DIR}/squashfs-root/opt/arcanus-ledger"
    
    if [ -f "${BUILD_DIR}/dist/arcanus-ledger-linux.tar.gz" ]; then
        sudo tar -xzf "${BUILD_DIR}/dist/arcanus-ledger-linux.tar.gz" \
            -C "${WORK_DIR}/squashfs-root/opt/arcanus-ledger/" 2>/dev/null || true
    fi
    
    # Desktop entry
    sudo tee "${WORK_DIR}/squashfs-root/usr/share/applications/arcanus-ledger.desktop" > /dev/null << 'DESK'
[Desktop Entry]
Type=Application
Name=Arcanus Ledger
Comment=Secure Business Ledger & Finance Management
Exec=/opt/arcanus-ledger/arcanus_ledger
Icon=arcanus-logo
Categories=Finance;Office;
Terminal=false
DESK
    log_ok "Arcanus Ledger ready"
else
    log_warn "Arcanus Ledger not found (optional)"
fi

log_ok "Branding applied"

# Repack filesystem
log_info "Repacking filesystem (this may take several minutes)..."
cd "${WORK_DIR}/extracted/casper"
sudo rm -f filesystem.squashfs
sudo mksquashfs "${WORK_DIR}/squashfs-root" filesystem.squashfs -comp xz -processors 1 2>&1 | tail -1 || true
log_ok "Filesystem repacked"

# Build ISO
log_info "Creating Arcanus OS ISO..."
cd "${BUILD_DIR}"

sudo mkisofs -iso-level 3 \
    -r -V "ARCANUS_OS" \
    -cache-inodes -J -l \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -o "${OUTPUT_DIR}/arcanus-os-demo.iso" \
    "${WORK_DIR}/extracted" 2>&1 | grep -v "^  " || true

log_ok "ISO created"

# Cleanup
log_info "Cleaning up..."
sudo rm -rf "${WORK_DIR}"
log_ok "Temporary files removed"

# Results
echo ""
echo "╔════════════════════════════════════════╗"
echo "║  ✅ Arcanus OS Build Complete!         ║"
echo "╚════════════════════════════════════════╝"
echo ""
if [ -f "${OUTPUT_DIR}/arcanus-os-demo.iso" ]; then
    ls -lh "${OUTPUT_DIR}/arcanus-os-demo.iso"
    echo ""
    log_ok "Ready to test in VirtualBox/QEMU"
else
    log_err "ISO file not found at ${OUTPUT_DIR}/arcanus-os-demo.iso"
fi
