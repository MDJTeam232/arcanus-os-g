
personal

Give feedback
Sessions





failed again sorry - is there anythng in this old build.iso.sh that might help

it didnt completly work but most did and yours is better but struggling

 #!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=/dev/null
source "$REPO_ROOT/build/config/mint-alpha.conf"

OUTPUT_ISO_NAME="${OUTPUT_ISO_NAME:-ArcanusOS-Alpha-x86_64.iso}"
ISO_VOLUME_ID="${ISO_VOLUME_ID:-ARCANUS_ALPHA}"
MINT_ISO_URL="${MINT_ISO_URL:-https://mirrors.edge.kernel.org/linuxmint/stable/22.3/linuxmint-22.3-xfce-64bit.iso}"
MINT_SHA256_URL="${MINT_SHA256_URL:-https://mirrors.edge.kernel.org/linuxmint/stable/22.3/sha256sum.txt}"
MINT_ISO_NAME="${MINT_ISO_NAME:-$(basename "$MINT_ISO_URL")}"

BUILD_ROOT="${BUILD_ROOT:-$REPO_ROOT/.build/iso}"
CACHE_DIR="${CACHE_DIR:-$REPO_ROOT/.cache/iso}"
DIST_DIR="${DIST_DIR:-$REPO_ROOT/dist}"
BASE_ISO="$CACHE_DIR/$MINT_ISO_NAME"
ISO_ROOT="$BUILD_ROOT/iso-root"
SQUASHFS_ROOT="$BUILD_ROOT/squashfs-root"
OUTPUT_ISO="$DIST_DIR/$OUTPUT_ISO_NAME"

log() {
  printf '[arcanus-iso] %s\n' "$*"
}

fail() {
  printf '[arcanus-iso] ERROR: %s\n' "$*" >&2
  exit 1
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    fail "ISO build needs root for squashfs ownership, chroot, and initramfs regeneration. Run with sudo."
  fi
}

require_tools() {
  local missing=()
  local tool

  for tool in curl sha256sum md5sum xorriso unsquashfs mksquashfs rsync sed awk grep find sort xargs du chroot mount umount mountpoint; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done

  if [[ "${#missing[@]}" -gt 0 ]]; then
    fail "missing required tools: ${missing[*]}"
  fi
}

download_base_iso() {
  install -d "$CACHE_DIR"

  if [[ -f "$BASE_ISO" ]]; then
    log "Using cached upstream ISO: $BASE_ISO"
  else
    log "Downloading upstream Mint XFCE ISO: $MINT_ISO_URL"
    curl -L --fail --retry 5 --retry-delay 5 -o "$BASE_ISO.partial" "$MINT_ISO_URL"
    mv "$BASE_ISO.partial" "$BASE_ISO"
  fi

  log "Downloading upstream SHA256 manifest"
  curl -L --fail --retry 5 --retry-delay 5 -o "$CACHE_DIR/sha256sum.txt" "$MINT_SHA256_URL"

  if awk -v file="*$MINT_ISO_NAME" '
    {
      for (i = 1; i < NF; i++) {
        if ($(i + 1) == file) {
          print $i "  " substr($(i + 1), 2)
          found = 1
          exit
        }
      }
    }
    END { exit found ? 0 : 1 }
  ' "$CACHE_DIR/sha256sum.txt" > "$CACHE_DIR/$MINT_ISO_NAME.sha256"; then
    (cd "$CACHE_DIR" && sha256sum -c "$MINT_ISO_NAME.sha256")
  else
    fail "checksum entry for $MINT_ISO_NAME not found in $MINT_SHA256_URL"
  fi
}

reset_workspace() {
  log "Preparing build workspace"
  rm -rf "$BUILD_ROOT"
  install -d "$ISO_ROOT" "$SQUASHFS_ROOT" "$DIST_DIR"
}

extract_iso() {
  log "Extracting upstream ISO"
  xorriso -osirrox on -indev "$BASE_ISO" -extract / "$ISO_ROOT" >/dev/null
  chmod -R u+w "$ISO_ROOT"
}

extract_squashfs() {
  local squashfs="$ISO_ROOT/casper/filesystem.squashfs"
  [[ -f "$squashfs" ]] || fail "casper filesystem not found: $squashfs"

  log "Extracting live filesystem"
  # Add the -f flag here to force overwrite
  unsquashfs -f -d "$SQUASHFS_ROOT" "$squashfs" >/dev/null
}

bind_mount_chroot() {
  mount -t proc proc "$SQUASHFS_ROOT/proc"
  mount --rbind /sys "$SQUASHFS_ROOT/sys"
  mount --make-rslave "$SQUASHFS_ROOT/sys"
  mount --rbind /dev "$SQUASHFS_ROOT/dev"
  mount --make-rslave "$SQUASHFS_ROOT/dev"
  mount --bind /run "$SQUASHFS_ROOT/run"
}

unmount_chroot() {
  local target
  for target in "$SQUASHFS_ROOT/run" "$SQUASHFS_ROOT/dev" "$SQUASHFS_ROOT/sys" "$SQUASHFS_ROOT/proc"; do
    if mountpoint -q "$target"; then
      umount -R "$target" || true
    fi
  done
}

activate_boot_branding() {
  log "Activating Arcanus Plymouth theme inside live filesystem"

  bind_mount_chroot
  chroot "$SQUASHFS_ROOT" update-alternatives \
    --install /usr/share/plymouth/themes/default.plymouth default.plymouth \
    /usr/share/plymouth/themes/arcanus/arcanus.plymouth 200
  chroot "$SQUASHFS_ROOT" update-alternatives \
    --set default.plymouth /usr/share/plymouth/themes/arcanus/arcanus.plymouth
  chroot "$SQUASHFS_ROOT" update-initramfs -u -k all

  local initrd
  initrd="$(find "$SQUASHFS_ROOT/boot" -maxdepth 1 -type f -name 'initrd.img-*' | sort | tail -1)"
  [[ -n "$initrd" && -f "$initrd" ]] || fail "updated initrd not found in live filesystem"

  if [[ -f "$ISO_ROOT/casper/initrd.lz" ]]; then
    cp "$initrd" "$ISO_ROOT/casper/initrd.lz"
  elif [[ -f "$ISO_ROOT/casper/initrd" ]]; then
    cp "$initrd" "$ISO_ROOT/casper/initrd"
  else
    fail "could not find ISO casper initrd target"
  fi
}

apply_arcanus_branding() {
  log "Applying Arcanus rootfs branding"
  "$REPO_ROOT/scripts/apply-branding.sh" "$SQUASHFS_ROOT"

  log "Suppressing visible Mint welcome entries"
  install -d "$SQUASHFS_ROOT/etc/xdg/autostart"
  cat > "$SQUASHFS_ROOT/etc/xdg/autostart/mintwelcome.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Arcanus Welcome
Hidden=true
X-GNOME-Autostart-enabled=false
EOF

  if [[ -f "$SQUASHFS_ROOT/usr/share/applications/mintwelcome.desktop" ]]; then
    sed -i -e 's/^Name=.*/Name=Arcanus Welcome/' \
           -e 's/^Comment=.*/Comment=Welcome to Arcanus OS/' \
           -e 's#^Exec=.*#Exec=arcanus-welcome#' \
           -e 's/^Icon=.*/Icon=arcanus-logo/' \
           "$SQUASHFS_ROOT/usr/share/applications/mintwelcome.desktop"
  fi

  log "Replacing visible Mint strings in launchers and installer metadata"
  local visible_text_dirs=("$SQUASHFS_ROOT/usr/share/applications" "$SQUASHFS_ROOT/etc/xdg/autostart" "$SQUASHFS_ROOT/usr/share/ubiquity" "$SQUASHFS_ROOT/usr/share/calamares")
  
  while IFS= read -r -d '' file; do
    case "$file" in
      *.desktop)
        sed -i -E -e '/^(Name|GenericName|Comment|Keywords)(\[[^]]+\])?=/ s/Linux Mint/Arcanus OS/g' \
                  -e '/^(Name|GenericName|Comment|Keywords)(\[[^]]+\])?=/ s/linuxmint/Arcanus/g' "$file" ;;
      *.ui|*.conf|*.xml|*.html)
        sed -i -e 's/Linux Mint/Arcanus OS/g' "$file" ;;
    esac
  done < <(find "${visible_text_dirs[@]}" -type f \( -name '*.desktop' -o -name '*.ui' -o -name '*.conf' -o -name '*.xml' -o -name '*.html' \) -print0 2>/dev/null)

  activate_boot_branding
}

rebrand_iso_boot_files() {
  log "Rebranding ISO boot menu and metadata"

  [[ -d "$ISO_ROOT/.disk" ]] && printf 'Arcanus OS Alpha x86_64\n' > "$ISO_ROOT/.disk/info"
  [[ -f "$ISO_ROOT/README.diskdefines" ]] && sed -i 's/Linux Mint/Arcanus OS/g' "$ISO_ROOT/README.diskdefines"

  while IFS= read -r -d '' file; do
    if grep -Iq . "$file"; then
      sed -i -e 's/Start Linux Mint/Start Arcanus OS/g' -e 's/Linux Mint/Arcanus OS/g' "$file" 2>/dev/null || true
    fi
  done < <(find "$ISO_ROOT" -type f \( -name '*.cfg' -o -name '*.txt' -o -name '*.tr' -o -name '*.theme' \) -print0)
}

regenerate_squashfs() {
  log "Regenerating squashfs"
  umount -R "$SQUASHFS_ROOT/proc" "$SQUASHFS_ROOT/sys" "$SQUASHFS_ROOT/dev" "$SQUASHFS_ROOT/run" 2>/dev/null || true
  rm -f "$ISO_ROOT/casper/filesystem.squashfs"
  mksquashfs "$SQUASHFS_ROOT" "$ISO_ROOT/casper/filesystem.squashfs" -noappend -comp xz -b 1M -e proc sys dev run tmp >/dev/null
}

regenerate_md5sums() {
  log "Regenerating ISO md5sum.txt"
  (
    cd "$ISO_ROOT"
    rm -f md5sum.txt
    find . -type f ! -name 'md5sum.txt' ! -path './isolinux/boot.cat' -print0 | sort -z | xargs -0 md5sum > md5sum.txt
  )
}

repack_iso_replay() {
  log "Repacking bootable ISO"
  rm -f "$OUTPUT_ISO"

  xorriso \
    -indev "$BASE_ISO" \
    -outdev "$OUTPUT_ISO" \
    -boot_image any replay \
    -volid "$ISO_VOLUME_ID" \
    -update_r "$ISO_ROOT" / \
    -commit >/dev/null
}

repack_iso_fallback() {
  log "Replay repack failed; trying explicit El Torito fallback"
  rm -f "$OUTPUT_ISO"

  local mbr="/usr/lib/ISOLINUX/isohdpfx.bin"
  [[ -f "$mbr" ]] || mbr="/usr/lib/syslinux/isohdpfx.bin"
  [[ -f "$mbr" ]] || fail "isohdpfx.bin not found; install isolinux/syslinux-common"

  local args=(
    -as mkisofs
    -r
    -V "$ISO_VOLUME_ID"
    -J
    -joliet-long
    -l
    -iso-level 3
    -o "$OUTPUT_ISO"
  )

  if [[ -f "$ISO_ROOT/isolinux/isolinux.bin" ]]; then
    args+=(
      -isohybrid-mbr "$mbr"
      -partition_offset 16
      -c isolinux/boot.cat
      -b isolinux/isolinux.bin
      -no-emul-boot
      -boot-load-size 4
      -boot-info-table
    )
  elif [[ -f "$ISO_ROOT/boot/grub/i386-pc/eltorito.img" ]]; then
    args+=(
      -b boot/grub/i386-pc/eltorito.img
      -no-emul-boot
      -boot-load-size 4
      -boot-info-table
    )
  else
    fail "no BIOS boot image found in extracted ISO"
  fi

  if [[ -f "$ISO_ROOT/boot/grub/efi.img" ]]; then
    args+=(
      -eltorito-alt-boot
      -e boot/grub/efi.img
      -no-emul-boot
      -isohybrid-gpt-basdat
    )
  fi

  xorriso "${args[@]}" "$ISO_ROOT" >/dev/null
}

repack_iso() {
  if ! repack_iso_replay; then
    repack_iso_fallback
  fi
}

write_checksum() {
  log "Writing SHA256 checksum"
  (
    cd "$DIST_DIR"
    sha256sum "$OUTPUT_ISO_NAME" > "$OUTPUT_ISO_NAME.sha256"
  )
}

cleanup() {
  unmount_chroot
}

main() {
  require_root
  require_tools
  trap cleanup EXIT

  download_base_iso
  reset_workspace
  extract_iso
  extract_squashfs
  apply_arcanus_branding
  regenerate_squashfs
  regenerate_md5sums
  repack_iso
  write_checksum

  log "ISO ready: $OUTPUT_ISO"
  log "Checksum: $OUTPUT_ISO.sha256"
}

main "$@"

Attachment 2
Show more
Activity

I can see from the screenshot that your build is still failing at "Failed to extract filesystem". The old script has several improvements. Let me create a new version that combines the best of both:

Write

./scripts/remaster-iso.sh
Params
Path:

~/.docker/cagent/working_directories/https-3a-2f-2fai-backend-service-docker-com-2fproxy-2fgordon-agent-3fgordontag-3dv8-26desktopversion-3d4-77-0-26origin-3ddesktop/40738cd0-6e43-42c4-9689-92fb94f6aacf/default/scripts/remaster-iso.sh

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
for cmd in mount unsquashfs mksquashfs xorriso rsync; do
    command -v "${cmd}" >/dev/null 2>&1 || log_err "Required tool missing: ${cmd}"
done

# Cleanup function
cleanup() {
    log_info "Cleaning up..."
    if mountpoint -q "${WORK_DIR}/mnt" 2>/dev/null; then
        sudo umount "${WORK_DIR}/mnt" || true
    fi
    sudo rm -rf "${WORK_DIR}" 2>/dev/null || true
    log_ok "Temporary files removed"
}

trap cleanup EXIT

# Create work directory
log_info "Setting up work environment..."
sudo rm -rf "${WORK_DIR}" 2>/dev/null || true
mkdir -p "${WORK_DIR}"/{mnt,iso-root,squashfs-root}
log_ok "Work directory ready"

# Extract ISO using xorriso (more reliable than mount)
log_info "Extracting Linux Mint ISO..."
xorriso -osirrox on -indev "${MINT_ISO}" -extract / "${WORK_DIR}/iso-root" >/dev/null 2>&1 || log_err "Failed to extract ISO with xorriso"
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
if ! sudo unsquashfs -f -d "${WORK_DIR}/squashfs-root" "$FSIMG" 2>&1; then
    log_err "Failed to extract filesystem: $FSIMG"
fi
log_ok "Filesystem extracted"

# Apply branding
log_info "Applying Arcanus branding..."

# Copy wallpaper
if [ -f "${BRANDING_DIR}/wallpaper.png" ]; then
    sudo mkdir -p "${WORK_DIR}/squashfs-root/usr/share/backgrounds"
    sudo cp "${BRANDING_DIR}/wallpaper.png" "${WORK_DIR}/squashfs-root/usr/share/backgrounds/arcanus-wallpaper.png"
    log_ok "Wallpaper installed"
fi

# Copy logo
if [ -f "${BRANDING_DIR}/arcanus-logo.png" ]; then
    sudo mkdir -p "${WORK_DIR}/squashfs-root/usr/share/pixmaps"
    sudo cp "${BRANDING_DIR}/arcanus-logo.png" "${WORK_DIR}/squashfs-root/usr/share/pixmaps/arcanus-logo.png"
    log_ok "Logo installed"
fi

# Copy theme if exists
if [ -d "${BRANDING_DIR}/theme" ]; then
    sudo mkdir -p "${WORK_DIR}/squashfs-root/usr/share/themes"
    sudo cp -r "${BRANDING_DIR}/theme" "${WORK_DIR}/squashfs-root/usr/share/themes/"
    log_ok "Theme installed"
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
    sudo mkdir -p "${WORK_DIR}/squashfs-root/usr/share/applications"
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

# Repack squashfs
log_info "Repacking filesystem..."
cd "${WORK_DIR}/iso-root/casper"
sudo rm -f "$FSIMG"

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
Key improvements from the old script:

xorriso for extraction - More reliable than mount/rsync
-f flag on unsquashfs - Forces extraction and shows real errors
Better error handling - Displays actual error messages
Proper cleanup trap - Ensures mount cleanup on exit
Fallback ISO creation - xorriso first, then mkisofs
Exclusions on repack - -e proc sys dev run tmp prevents permission issues
Commit and push:

git add scripts/remaster-iso.sh
git commit -m "Refactor: Use xorriso for ISO extraction and add proper error handling"
git push origin main
This should now show you the actual error if something fails. Let me know what the new output says!

What should I build, check, or explain?
0





View file
~/.docker/cagent/working_directories/https-3a-2f-2fai-backend-service-docker-com-2fproxy-2fgordon-agent-3fgordontag-3dv8-26desktopversion-3d4-77-0-26origin-3ddesktop/40738cd0-6e43-42c4-9689-92fb94f6aacf/default/scripts/remaster-iso.sh
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
for cmd in mount unsquashfs mksquashfs xorriso rsync; do
    command -v "${cmd}" >/dev/null 2>&1 || log_err "Required tool missing: ${cmd}"
done

# Cleanup function
cleanup() {
    log_info "Cleaning up..."
    if mountpoint -q "${WORK_DIR}/mnt" 2>/dev/null; then
        sudo umount "${WORK_DIR}/mnt" || true
    fi
    sudo rm -rf "${WORK_DIR}" 2>/dev/null || true
    log_ok "Temporary files removed"
}

trap cleanup EXIT

# Create work directory
log_info "Setting up work environment..."
sudo rm -rf "${WORK_DIR}" 2>/dev/null || true
mkdir -p "${WORK_DIR}"/{mnt,iso-root,squashfs-root}
log_ok "Work directory ready"

# Extract ISO using xorriso (more reliable than mount)
log_info "Extracting Linux Mint ISO..."
xorriso -osirrox on -indev "${MINT_ISO}" -extract / "${WORK_DIR}/iso-root" >/dev/null 2>&1 || log_err "Failed to extract ISO with xorriso"
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
if ! sudo unsquashfs -f -d "${WORK_DIR}/squashfs-root" "$FSIMG" 2>&1; then
    log_err "Failed to extract filesystem: $FSIMG"
fi
log_ok "Filesystem extracted"

# Apply branding
log_info "Applying Arcanus branding..."

# Copy wallpaper
if [ -f "${BRANDING_DIR}/wallpaper.png" ]; then
    sudo mkdir -p "${WORK_DIR}/squashfs-root/usr/share/backgrounds"
    sudo cp "${BRANDING_DIR}/wallpaper.png" "${WORK_DIR}/squashfs-root/usr/share/backgrounds/arcanus-wallpaper.png"
    log_ok "Wallpaper installed"
fi

# Copy logo
if [ -f "${BRANDING_DIR}/arcanus-logo.png" ]; then
    sudo mkdir -p "${WORK_DIR}/squashfs-root/usr/share/pixmaps"
    sudo cp "${BRANDING_DIR}/arcanus-logo.png" "${WORK_DIR}/squashfs-root/usr/share/pixmaps/arcanus-logo.png"
    log_ok "Logo installed"
fi

# Copy theme if exists
if [ -d "${BRANDING_DIR}/theme" ]; then
    sudo mkdir -p "${WORK_DIR}/squashfs-root/usr/share/themes"
    sudo cp -r "${BRANDING_DIR}/theme" "${WORK_DIR}/squashfs-root/usr/share/themes/"
    log_ok "Theme installed"
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
    sudo mkdir -p "${WORK_DIR}/squashfs-root/usr/share/applications"
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

# Repack squashfs
log_info "Repacking filesystem..."
cd "${WORK_DIR}/iso-root/casper"
sudo rm -f "$FSIMG"

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
