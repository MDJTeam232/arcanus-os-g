# Branding Guidelines

This folder contains Arcanus visual identity assets used to customize the Linux Mint ISO.

## Available Assets

### Icons (SVG)
- **`arcanus-os.svg`** – Main OS logo/icon
- **`ledger.svg`** – Arcanus Ledger app icon
- **`vault.svg`** – Vault/security icon
- **`intelligence.svg`** – AI/intelligence icon
- **`knowledge.svg`** – Knowledge base icon
- **`workspace.svg`** – Workspace icon
- **`terminal.svg`** – Terminal icon
- **`link.svg`** – Link/connection icon

### Icon Theme
- **`icon-theme/`** – Complete icon theme structure
  - Inherits from Adwaita for missing icons
  - Scalable SVG icons for all sizes

## Adding to ISO

The build script automatically:
1. Installs icon theme to `/usr/share/icons/Arcanus/`
2. Sets Arcanus as default icon theme
3. Uses `arcanus-os.svg` for app launchers and menus

## Required Files (for minimal build)

Add these to complete the branding:

- **`wallpaper.png`** (1920×1080 px)
  - Desktop background
  
- **`splash.png`** (1024×768 px, optional)
  - Boot screen

## Color Palette (Reference)

Based on your Arcanus branding:
- **Primary:** Purple/Violet (#8B5CF6)
- **Secondary:** Dark backgrounds (#0F0F1E)
- **Accent:** Cyan/Light blue highlights (#06B6D4)

## File Structure

```
branding/
├── arcanus-os.svg          ✓ (ready)
├── ledger.svg              ✓ (ready)
├── vault.svg               ✓ (ready)
├── intelligence.svg        ✓ (ready)
├── knowledge.svg           ✓ (ready)
├── workspace.svg           ✓ (ready)
├── terminal.svg            ✓ (ready)
├── link.svg                ✓ (ready)
├── icon-theme/             ✓ (ready)
│   ├── index.theme
│   └── scalable/apps/
├── wallpaper.png           ← NEEDED
├── splash.png              ← Optional
└── README.md
```

## Testing Icons

After building the ISO, icons appear in:
- Application menu
- Taskbar
- File manager
- System tray

## Converting SVG to PNG

If you need PNG versions for specific uses:

```bash
# macOS
for svg in *.svg; do
    convert -density 300 "$svg" -resize 256x256 "${svg%.svg}.png"
done

# Or use ImageMagick
sips -s format png arcanus-os.svg --out arcanus-os.png
```

---

Icons ready! Just add wallpaper.png to complete the branding package.
