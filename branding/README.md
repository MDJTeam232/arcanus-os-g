# Branding Guidelines

This folder contains Arcanus visual identity assets used to customize the Linux Mint ISO.

## Required Files

### Logos

- **`arcanus-logo.png`** (256×256 px, RGBA)
  - Used in menus, taskbar, application launcher
  - Background should be transparent
  - Save as PNG with transparency

- **`arcanus-logo-small.png`** (48×48 px, RGBA)
  - Used in panel/taskbar icons
  - Must be clear at small sizes

### Wallpaper

- **`wallpaper.png`** (1920×1080 px or higher)
  - Desktop background for live environment
  - PNG or JPG format
  - Should match Arcanus color scheme (purples, dark backgrounds)

### Optional Boot Assets

- **`splash.png`** (1024×768 px)
  - Boot screen splash image
  - Appears during system startup

## Color Palette (Reference)

Based on your Arcanus branding image:
- **Primary:** Purple/Violet (#8B5CF6 or similar)
- **Secondary:** Dark backgrounds (#0F0F1E or similar)
- **Accent:** Cyan/Light blue highlights

## Placement in Repository

```
branding/
├── arcanus-logo.png
├── arcanus-logo-small.png
├── wallpaper.png
├── splash.png (optional)
└── README.md (this file)
```

## Testing Your Assets

After adding files, verify:

```bash
make verify          # Check all files exist
make remaster        # Build ISO with your assets
```

Then test the ISO in VirtualBox to see how your branding looks in the actual environment.

## Tips

1. **High Resolution:** Use high-quality PNG/JPG; mkisofs will handle compression
2. **Transparency:** Logos should have transparent backgrounds (not white/black)
3. **Consistency:** Ensure color palette matches across all assets
4. **Dark Theme:** Since Arcanus appears to use dark UI, choose appropriately-colored wallpapers
5. **Testing:** Quick test in GIMP/Inkscape before building full ISO

## Asset Sources

Your existing branding materials:
- From the Arcanus presentation image you shared (purple neon A logo)
- Color scheme: dark purple backgrounds with bright purple/cyan accents
