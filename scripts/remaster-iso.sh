#!/bin/bash
# ==============================================================================
#      ARCANUS OS IMAGE REMASTER ROUTINE (DEBIAN 12 SPECIALIZED HARDENING)
# ==============================================================================

# Establish strict execution termination on fault lines
set -e

# Core Environmental Definitions
WORKSPACE=$(pwd)
BUILD_DIR="${WORKSPACE}/build_env"
ISO_EXTRACT="${BUILD_DIR}/iso_root"
SQUASH_EXTRACT="${BUILD_DIR}/squashfs_root"
OUTPUT_DIR="${WORKSPACE}/output"
ISO_NAME="arcanus-os-live-arm64.iso"

# Output Color Matrix Visual Indicators
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() { echo -e "${PURPLE}[⚙️ ARCANUS BUILD] $1${NC}"; }
log_success() { echo -e "${GREEN}[🎉 SUCCESS] $1${NC}"; }
log_error() { echo -e "${RED}[❌ FATAL ERROR] $1${NC}"; }

# Enforce strict system privilege gates
if [ "$EUID" -ne 0 ]; then
    log_error "This installation layout optimizer must be executed with root permissions. Run via sudo."
    exit 1
fi

# Ensure output directory target locations are active
mkdir -p "$OUTPUT_DIR"

# ==============================================================================
# PHASE 1: DESKTOP & SYSTEM INTERFACE LAYER STAGING
# ==============================================================================
log_info "Synchronizing custom branding assets, vectors, and layouts to image layers..."

# Verify source asset presence before copying
if [ -d "${WORKSPACE}/branding" ]; then
    # Inject primary OS system layer wallpapers
    mkdir -p "${SQUASH_EXTRACT}/usr/share/backgrounds/arcanus"
    cp "${WORKSPACE}/branding/wallpaper.png" "${SQUASH_EXTRACT}/usr/share/backgrounds/arcanus/wallpaper.png"
    
    # Inject application vector launcher assets to native Linux directory slots
    mkdir -p "${SQUASH_EXTRACT}/usr/share/icons/hicolor/scalable/apps"
    cp ${WORKSPACE}/branding/*.svg "${SQUASH_EXTRACT}/usr/share/icons/hicolor/scalable/apps/" 2>/dev/null || true
    
    # Sync complete custom icon package structures
    if [ -d "${WORKSPACE}/branding/icon-theme" ]; then
        mkdir -p "${SQUASH_EXTRACT}/usr/share/icons/Arcanus"
        rsync -a "${WORKSPACE}/branding/icon-theme/" "${SQUASH_EXTRACT}/usr/share/icons/Arcanus/"
    fi
else
    log_error "Branding repository asset folder missing. Verify tree layout properties."
    exit 1
fi

# Inject custom GTK window skins directly into the Debian look-and-feel manager
if [ -d "${WORKSPACE}/theme" ]; then
    log_info "Injecting custom GTK-3.0 window container styles..."
    mkdir -p "${SQUASH_EXTRACT}/usr/share/themes/Arcanus"
    rsync -a "${WORKSPACE}/theme/" "${SQUASH_EXTRACT}/usr/share/themes/Arcanus/"
fi

# ==============================================================================
# PHASE 2: CHROOT ENVIROMENT JAIL EXECUTION GATEWAY
# ==============================================================================
log_info "Entering Debian 12 Chroot filesystem environment to execute customize.sh..."

if [ -f "${WORKSPACE}/scripts/customize.sh" ]; then
    # Transfer the customization shell script straight into the image /tmp directory
    cp "${WORKSPACE}/scripts/customize.sh" "${SQUASH_EXTRACT}/tmp/customize.sh"
    chmod +x "${SQUASH_EXTRACT}/tmp/customize.sh"
    
    # Mount native system file system pipelines to keep commands functional inside the jail
    mount --bind /dev "$SQUASH_EXTRACT/dev"
    mount --bind /dev/pts "$SQUASH_EXTRACT/dev/pts"
    mount --bind /proc "$SQUASH_EXTRACT/proc"
    mount --bind /sys "$SQUASH_EXTRACT/sys"
    mount --bind /run "$SQUASH_EXTRACT/run"
    
    # Safely switch processing loops over into the system squashfs image shell
    chroot "$SQUASH_EXTRACT" /bin/bash /tmp/customize.sh || {
        log_error "Customization sub-script execution failed within Chroot system layer."
        # Clean up directory mounts defensively on processing failures
        umount "$SQUASH_EXTRACT/dev/pts" || true; umount "$SQUASH_EXTRACT/dev" || true
        umount "$SQUASH_EXTRACT/proc" || true; umount "$SQUASH_EXTRACT/sys" || true
        umount "$SQUASH_EXTRACT/run" || true
        exit 1
    }
    
    # Flush loopback hardware bindings securely
    log_info "Detaching kernel virtualization tracking mounts from system workspace..."
    umount "$SQUASH_EXTRACT/dev/pts"
    umount "$SQUASH_EXTRACT/dev"
    umount "$SQUASH_EXTRACT/proc"
    umount "$SQUASH_EXTRACT/sys"
    umount "$SQUASH_EXTRACT/run"
    
    # Purge working script asset footprints
    rm -f "${SQUASH_EXTRACT}/tmp/customize.sh"
else
    log_error "Customization script layout component missing at scripts/customize.sh."
    exit 1
fi

# ==============================================================================
# PHASE 3: FILE SYSTEM SQUASHFS COMPILATION LAYER
# ==============================================================================
log_info "Re-compressing the modified Debian 12 SquashFS container (Using maximum XZ algorithms)..."
mkdir -p "${ISO_EXTRACT}/live"
rm -f "${ISO_EXTRACT}/live/filesystem.squashfs"

# Compile and optimize system layer archives 
mksquashfs "$SQUASH_EXTRACT" "${ISO_EXTRACT}/live/filesystem.squashfs" \
    -comp xz \
    -b 1M \
    -noappend \
    -e boot tmp

# ==============================================================================
# PHASE 4: FINAL ISO COMPILE EXECUTION (XORRISO PROTOCOL)
# ==============================================================================
log_info "Generating production-ready bootable Arcanus ISO package..."

# Verify and default boot metadata profiles if required for multi-architecture stability
if [ ! -d "${ISO_EXTRACT}/isolinux" ]; then
    mkdir -p "${ISO_EXTRACT}/isolinux"
    # Fallback to grub/efi template components if building native arm64 live images
fi

# Execute high-fidelity ISO compilation via xorriso
xorriso -as mkisofs -r -V "ARCANUS_OS" \
    -o "${OUTPUT_DIR}/${ISO_NAME}" \
    -J -joliet-long \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    "$ISO_EXTRACT"

log_success "Master Arcanus OS Debian 12 compilation sequence finalized!"
log_success "Target installation artifact generated at: output/${ISO_NAME}"
