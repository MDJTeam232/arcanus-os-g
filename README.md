# Arcanus OS – Linux Mint Remaster

A customized Linux Mint distribution rebranded with Arcanus visual identity for demo purposes. Maintains full Linux Mint functionality while applying Arcanus branding, themes, and pre-installs Arcanus Ledger.

## Features

- ✅ Full Linux Mint 22 Cinnamon functionality
- ✅ Arcanus visual branding (logos, wallpapers, themes)
- ✅ Pre-installed Arcanus Ledger app
- ✅ Custom boot splash and GRUB theming
- ✅ Ready for ISO distribution and demo deployments

## Quick Start

### Prerequisites

**Linux system** (Ubuntu/Mint/Debian):
```bash
sudo apt install -y live-build squashfs-tools mkisofs xorriso rsync wget
```

**macOS** (via Docker):
```bash
docker run -it -v $(pwd):/build ubuntu:jammy bash
cd /build
```

### Build Steps

```bash
# 1. Clone this repo
git clone https://github.com/MDJTeam232/arcanus-os-g.git
cd arcanus-os-g

# 2. Add your branding assets (see section below)
# 3. Download Linux Mint ISO
make download-mint

# 4. Remaster with Arcanus branding
make remaster

# 5. Find ISO in dist/
ls dist/arcanus-os-demo.iso
```

## Adding Branding Assets

Place your Arcanus branding files in the `branding/` folder:

```
branding/
├── arcanus-logo.png          # Menu & boot logo (256x256px)
├── arcanus-logo-small.png    # Panel icon (48x48px)
├── wallpaper.png             # Desktop background (1920x1080px)
└── splash.png                # Boot splash screen (1024x768px)
```

Custom themes go in `theme/`:
```
theme/
└── Arcanus/
    ├── gtk-3.0/
    ├── gtk-4.0/
    └── index.theme
```

## Directory Structure

```
.
├── branding/              # Logo & wallpaper assets
├── theme/                 # GTK/XFCE theme customizations
├── scripts/
│   ├── remaster-iso.sh    # Main build script
│   └── customize.sh       # Post-install customizations
├── rootfs/                # Optional filesystem overlays
├── dist/                  # Output ISO directory
├── docs/
│   ├── BUILD.md           # Detailed build instructions
│   ├── BRANDING.md        # Asset specifications
│   └── LICENSING.md       # Compliance & licensing info
├── makefile               # Build automation
└── README.md
```

## Build Commands

```bash
make help              # Show all commands
make download-mint     # Download Linux Mint ISO
make remaster          # Build remastered ISO
make clean             # Remove build artifacts
make verify            # Check directory structure
```

## Testing the ISO

### VirtualBox
```bash
VBoxManage createvm --name "Arcanus OS Demo" --ostype Ubuntu_64
VBoxManage modifyvm "Arcanus OS Demo" --cpus 2 --memory 4096 --vram 128
VBoxManage storageattach "Arcanus OS Demo" --storagectl IDE --port 0 --device 0 \
  --type dvddrive --medium dist/arcanus-os-demo.iso
```

### Command Line
```bash
qemu-system-x86_64 -cdrom dist/arcanus-os-demo.iso -m 4G -smp 2
```

## Licensing & Attribution

This project repackages **Linux Mint 22** (LGPL/GPL licensed). Compliance requirements:

- ✅ Attribution to Linux Mint and its team
- ✅ GPL compliance for any modifications
- ✅ License files included in ISO
- ✅ Source code available on GitHub

**When approaching Linux Mint officially for licensing/partnership:**
- Reference this repo
- Include compliance documentation
- Describe use case (demo/internal/etc)

See `docs/LICENSING.md` for full details.

## Project Structure

| Folder | Purpose |
|--------|---------|
| `branding/` | Arcanus logos, wallpapers, splash screens |
| `theme/` | GTK/XFCE theme overrides |
| `scripts/` | Build & customization scripts |
| `rootfs/` | Optional filesystem overlays |
| `dist/` | Built ISO output |
| `docs/` | Documentation & guides |

## Contributing

1. Fork the repo
2. Add/modify branding assets
3. Test with `make remaster`
4. Submit PR with before/after screenshots

## Support & Contact

- **Issues**: GitHub Issues
- **Questions**: Discussion tab
- **Licensing**: See `docs/LICENSING.md`

---

**Built with:** Linux Mint, live-build, mkisofs  
**License:** GPL-2.0 (inherits from Linux Mint)
