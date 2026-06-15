#!/bin/bash
# ==============================================================================
# ARCANUS OS IMAGE REMASTER ROUTINE (DEBIAN 12 SPECIALIZED)
# ==============================================================================
set -e

# Arguments passed from Makefile: [1] Workspace, [2] Output Dir, [3] Arch
WORKSPACE=$1
OUTPUT_DIR=$2
ARCH=$3
ISO_NAME="arcanus-os-live-${ARCH}.iso"

# Paths
BUILD_DIR="${WORKSPACE}/build_env"
ISO_EXTRACT="${BUILD_DIR}/iso_root"
SQUASH_EXTRACT="${BUILD_DIR}/squashfs_root"

# Colors
PURPLE='\033[0;35m'; GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
log_info() { echo -e "${PURPLE}[⚙️ ARCANUS BUILD] $1${NC}"; }
log_success() { echo -e "${GREEN}[🎉 SUCCESS] $1${NC}"; }
log_error() { echo -e "${RED}[❌ FATAL ERROR] $1${NC}"; }

if [ "$EUID" -ne 0 ]; then
    log_error "This script must be executed with root permissions."
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# PHASE 1: Asset Injection
log_info "Synchronizing assets to image layers..."
cp "${WORKSPACE}/branding/wallpaper.png" "${SQUASH_EXTRACT}/usr/share/backgrounds/arcanus/wallpaper.png"
if [ -d "${WORKSPACE}/theme" ]; then
    rsync -a "${WORKSPACE}/theme/" "${SQUASH_EXTRACT}/usr/share/themes/Arcanus/"
fi

# PHASE 2: Chroot Environment
log_info "Entering Chroot..."
for dir in dev dev/pts proc sys run; do mount --bind /"$dir" "$SQUASH_EXTRACT/$dir"; done

# Execute customization script inside the jail
chroot "$SQUASH_EXTRACT" /bin/bash /tmp/customize.sh || {
    log_error "Customization failed."
    for dir in run sys proc dev/pts dev; do umount "$SQUASH_EXTRACT/$dir"; done
    exit 1
}

# Cleanup mounts
for dir in run sys proc dev/pts dev; do umount "$SQUASH_EXTRACT/$dir"; done

# PHASE 3: SquashFS
log_info "Compressing SquashFS..."
rm -f "${ISO_EXTRACT}/live/filesystem.squashfs"
mksquashfs "$SQUASH_EXTRACT" "${ISO_EXTRACT}/live/filesystem.squashfs" \
    -comp xz -b 1M -noappend -e boot tmp

# PHASE 4: ISO Compilation
log_info "Generating ISO: ${ISO_NAME}"
xorriso -as mkisofs -r -V "ARCANUS_OS" \
    -o "${OUTPUT_DIR}/${ISO_NAME}" \
    -J -joliet-long \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    "$ISO_EXTRACT"

log_success "Artifact generated at: ${OUTPUT_DIR}/${ISO_NAME}"
