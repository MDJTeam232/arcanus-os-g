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
for cmd in xorriso unsquashfs mksquashfs rsync; do
    command -v "${cmd}" >/dev/null 2>&1 || log_err "Required tool missing: ${cmd}"
done

# Cleanup function
cleanup() {
    if mountpoint -q "${WORK_DIR}/mnt" 2>/dev/null; then
        sudo umount "${WORK_DIR}/mnt" || true
    fi
    sudo rm -rf "${WORK_DIR}" 2>/dev/null || true
}

trap cleanup EXIT

# Create work directory
log_info "Setting up work environment..."
sudo rm -rf "${WORK_DIR}" 2>/dev/null || true
sudo mkdir -p "${WORK_DIR}"/{mnt,iso-root}
sudo mkdir -p "${WORK_DIR}/squashfs-root"
sudo chmod 777 "${WORK_DIR}" "${WORK_DIR}/squashfs-root"
log_ok "Work directory ready"

# Extract ISO using xorriso (more reliable than mount)
log_info "Extracting Linux Mint ISO..."
if ! xorriso -osirrox on -indev "${MINT_ISO}" -extract / "${WORK_DIR}/iso-root" >/dev/null 2>&1; then
    log_err "Failed to extract ISO with xorriso"
fi
chmod -R u+w "${WORK_DIR}/iso-root"
log_ok "ISO extracted"

# Find and extract squashfs filesystem
log_info "Extracting filesystem..."
cd "${WORK_DIR}/iso-root/casper"

# Detect filesystem image
FSIMG=""
if [ -f "filesystem.squashfs" ]; then
    FSIMG="filesystem.squashfs"
    log_info "Found filesystem: $FSIMG"
elif [ -f "filesystem.cfs" ]; then
    FSIMG="filesystem.cfs"
    log_info "Found filesystem: $FSIMG"
else
    log_err "No filesystem image found in casper/. Available: $(ls -1 | tr '\n' ' ')"
fi

# Extract with -f flag to force overwrite and show real errors
# Let unsquashfs create the directory by removing it first
sudo rm -rf "${WORK_DIR}/squashfs-root"
if ! sudo unsquashfs -f -d "${WORK_DIR}/squashfs-root" "$FSIMG" 2>&1; then
    log_err "Failed to extract filesystem: $FSIMG"
fi
# Fix permissions so we can write to it
sudo chown -R "$(id -u):$(id -g)" "${WORK_DIR}/squashfs-root" || sudo chmod -R 777 "${WORK_DIR}/squashfs-root"
log_ok "Filesystem extracted"

# Apply branding
log_info "Applying Arcanus branding..."

# Copy wallpaper
if [ -f "${BRANDING_DIR}/wallpaper.png" ]; then
    mkdir -p "${WORK_DIR}/squashfs-root/usr/share/backgrounds"
    cp "${BRANDING_DIR}/wallpaper.png" "${WORK_DIR}/squashfs-root/usr/share/backgrounds/arcanus-wallpaper.png"
    log_ok "Wallpaper installed"
fi

# Copy logo
if [ -f "${BRANDING_DIR}/arcanus-logo.png" ]; then
    mkdir -p "${WORK_DIR}/squashfs-root/usr/share/pixmaps"
    cp "${BRANDING_DIR}/arcanus-logo.png" "${WORK_DIR}/squashfs-root/usr/share/pixmaps/arcanus-logo.png"
    log_ok "Logo installed"
fi

# Copy theme if exists
if [ -d "${BRANDING_DIR}/theme" ]; then
    mkdir -p "${WORK_DIR}/squashfs-root/usr/share/themes"
    cp -r "${BRANDING_DIR}/theme" "${WORK_DIR}/squashfs-root/usr/share/themes/"
    log_ok "Theme installed"
fi

# Update branding files
log_info "Customizing boot environment..."
tee "${WORK_DIR}/squashfs-root/etc/issue" > /dev/null << 'EOF'

 ╔═══════════════════════════════════════╗
 ║   ARCANUS OS – Secure Finance         ║
 ║   Based on Linux Mint 22 Cinnamon     ║
 ╚═══════════════════════════════════════╝

EOF

# Create Arcanus Ledger desktop shortcut
if [ -f "${BUILD_DIR}/dist/arcanus-ledger-linux.tar.gz" ] || [ -d "${BUILD_DIR}/arcanus-ledger" ]; then
    log_info "Installing Arcanus Ledger..."
    mkdir -p "${WORK_DIR}/squashfs-root/opt/arcanus-ledger"
    
    if [ -f "${BUILD_DIR}/dist/arcanus-ledger-linux.tar.gz" ]; then
        tar -xzf "${BUILD_DIR}/dist/arcanus-ledger-linux.tar.gz" \
            -C "${WORK_DIR}/squashfs-root/opt/arcanus-ledger/" 2>/dev/null || true
    fi
    
    # Desktop entry
    mkdir -p "${WORK_DIR}/squashfs-root/usr/share/applications"
    tee "${WORK_DIR}/squashfs-root/usr/share/applications/arcanus-ledger.desktop" > /dev/null << 'DESK'
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

# Repack squashfs
log_info "Repacking filesystem..."
cd "${WORK_DIR}/iso-root/casper"
sudo rm -f "$FSIMG"

# Fix permissions before repacking - ensure root owns everything
sudo chown -R root:root "${WORK_DIR}/squashfs-root" 2>/dev/null || true

# Repack with proper exclusions
if ! sudo mksquashfs "${WORK_DIR}/squashfs-root" "$FSIMG" \
    -noappend \
    -comp xz \
    -b 1M \
    -e proc sys dev run tmp 2>&1; then
    log_err "Failed to repack filesystem"
fi
log_ok "Filesystem repacked"

# Regenerate ISO
log_info "Creating Arcanus OS ISO..."
cd "${BUILD_DIR}"

# Use xorriso for more reliable ISO creation
if xorriso \
    -indev "${MINT_ISO}" \
    -outdev "${OUTPUT_DIR}/arcanus-os-demo.iso" \
    -boot_image any replay \
    -volid "ARCANUS_OS" \
    -update_r "${WORK_DIR}/iso-root" / \
    -commit >/dev/null 2>&1; then
    log_ok "ISO created (xorriso replay)"
else
    log_warn "xorriso replay failed, trying fallback..."
    
    # Fallback: use mkisofs
    mkisofs -iso-level 3 \
        -r -V "ARCANUS_OS" \
        -cache-inodes -J -l \
        -b isolinux/isolinux.bin \
        -c isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -o "${OUTPUT_DIR}/arcanus-os-demo.iso" \
        "${WORK_DIR}/iso-root" >/dev/null 2>&1 || log_err "ISO creation failed"
    log_ok "ISO created (mkisofs fallback)"
fi

# Results
echo ""
echo "╔════════════════════════════════════════╗"
echo "║  ✅ Arcanus OS Build Complete!         ║"
echo "╚════════════════════════════════════════╝"
echo ""
ls -lh "${OUTPUT_DIR}/arcanus-os-demo.iso"
echo ""
log_ok "Ready to test in VirtualBox/QEMU"
