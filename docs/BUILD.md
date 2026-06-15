# Build Documentation

Detailed instructions for building Arcanus OS from Linux Mint.

## Overview

Arcanus OS is a remastered Linux Mint 22 Cinnamon ISO with Arcanus branding applied. The build process:

1. Downloads official Linux Mint ISO
2. Extracts filesystem
3. Applies Arcanus branding (logos, wallpapers, themes)
4. Repacks into new ISO
5. Ready for distribution/testing

**Total build time:** ~10-15 minutes (depending on download speed)  
**Disk space needed:** ~8-10 GB (temporary)  
**Requirements:** Linux system with sudo access (or Docker on macOS)

## System Requirements

### Linux (Ubuntu/Debian/Mint)

```bash
# Install dependencies
sudo apt update
sudo apt install -y \
    wget \
    squashfs-tools \
    mkisofs \
    rsync \
    sudo
```

### macOS (via Docker)

Since macOS can't directly run Linux tools, use Docker:

```bash
# Install Docker Desktop for Mac first
docker run -it -v $(pwd):/build ubuntu:22.04 bash
cd /build
sudo apt update
sudo apt install -y wget squashfs-tools mkisofs rsync
make remaster
```

## Build Steps (Quick)

```bash
# 1. Prepare
make verify                   # Check repo structure

# 2. Download Linux Mint ISO
make download-mint            # ~2GB download

# 3. Build
make remaster                 # Requires sudo

# 4. Find result
ls -lh dist/arcanus-os-demo.iso
```

## Build Steps (Manual)

If `make` doesn't work:

```bash
# Download Linux Mint 22 Cinnamon
wget https://mirrors.layeronline.com/linuxmint/stable/22/linuxmint-22-cinnamon-64bit.iso

# Run remaster script
chmod +x scripts/remaster-iso.sh
sudo ./scripts/remaster-iso.sh linuxmint-22-cinnamon-64bit.iso dist/

# Output
ls dist/arcanus-os-demo.iso
```

## Customization

### Add Your Branding

Before building, place files in `branding/`:

```bash
cp /path/to/your/arcanus-logo.png branding/
cp /path/to/your/wallpaper.png branding/
```

See `branding/README.md` for specifications.

### Add Arcanus Ledger

If you have the built Linux app, place it:

```bash
# Copy from earlier build
cp /Volumes/MacMiniDock/Developer/Arcanus_Finance/dist/arcanus-ledger-linux.tar.gz dist/

# Then build
make remaster
```

The script will automatically install it to `/opt/arcanus-ledger/` in the ISO.

## Testing the ISO

### VirtualBox (Recommended)

```bash
# Create new VM
VBoxManage createvm --name "Arcanus OS" --ostype Ubuntu_64

# Allocate resources
VBoxManage modifyvm "Arcanus OS" \
    --memory 4096 \
    --cpus 2 \
    --vram 128

# Mount ISO
VBoxManage storageattach "Arcanus OS" \
    --storagectl IDE \
    --port 0 --device 0 \
    --type dvddrive \
    --medium dist/arcanus-os-demo.iso

# Boot and test
VirtualBox &
```

### QEMU (Command-line)

```bash
qemu-system-x86_64 \
    -cdrom dist/arcanus-os-demo.iso \
    -m 4G \
    -smp 2 \
    -enable-kvm
```

### USB Stick (Real Hardware)

```bash
# macOS
diskutil list
diskutil unmountDisk /dev/diskX
sudo dd if=dist/arcanus-os-demo.iso of=/dev/rdiskX bs=4m
diskutil ejectDisk /dev/diskX

# Linux
sudo dd if=dist/arcanus-os-demo.iso of=/dev/sdX bs=4M status=progress
sync
```

## Troubleshooting

### "Permission denied" on scripts

```bash
chmod +x scripts/*.sh
```

### "Mount: permission denied"

Remaster script requires sudo:

```bash
sudo make remaster
# or
sudo ./scripts/remaster-iso.sh linuxmint-22-cinnamon-64bit.iso dist/
```

### ISO won't boot

- Verify you're burning to USB correctly (not just copying)
- Try `dd` instead of GUI tools
- Ensure ISO is from `dist/` folder (not temp work dir)

### Build hangs

If `mksquashfs` seems frozen, it's still compressing. Wait ~5+ minutes. Monitor with:

```bash
# In another terminal
ps aux | grep mksquashfs
```

## Advanced Options

### Change Linux Mint Version

```bash
# Modify makefile or run directly
MINT_VERSION=21 make download-mint
```

### Custom ISO Name/Volume

Edit `scripts/remaster-iso.sh` line with `mkisofs`:

```bash
-V "YOUR_CUSTOM_NAME"   # Change ISO volume label
```

### Skip Arcanus Ledger

Edit `scripts/remaster-iso.sh` and comment out the Arcanus Ledger section (lines ~110-130).

## Next Steps

1. **Test the ISO** in VirtualBox
2. **Verify branding** looks correct
3. **Check Arcanus Ledger** launches properly
4. **Burn to USB** for hardware testing
5. **Submit for review** to Linux Mint team (with licensing docs)

## Support

- **Issues:** Check repo Issues tab
- **Questions:** Start a Discussion
- **Improvements:** Submit PR with changes

---

**Build system:** live-build + mkisofs  
**Base:** Linux Mint 22 Cinnamon  
**License:** GPL-2.0 (inherited from Linux Mint)
