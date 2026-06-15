# Theme Customization

Optional: Add custom GTK/XFCE themes to further customize Arcanus OS appearance.

## Structure

```
theme/
└── Arcanus/
    ├── index.theme          # Theme metadata
    ├── gtk-3.0/
    │   ├── gtk.css
    │   └── settings.ini
    └── gtk-4.0/
        └── gtk.css
```

## Quick Start

If you have a GNOME/XFCE theme you want to include:

```bash
# Copy your theme
cp -r /path/to/your/theme theme/Arcanus

# Verify structure
ls -R theme/Arcanus
```

## Building Your Own Theme

Create minimal theme files:

### `theme/Arcanus/index.theme`

```ini
[Desktop Entry]
Type=X-GNOME-Metatheme
Name=Arcanus
Comment=Arcanus Finance Dark Theme

[X-GNOME-Metatheme]
GtkTheme=Arcanus
IconTheme=Arcanus-Icons
CursorTheme=Adwaita
```

### `theme/Arcanus/gtk-3.0/settings.ini`

```ini
[Settings]
gtk-button-images = false
gtk-menu-images = false
gtk-toolbar-icon-size = GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-font-name = Ubuntu 10
gtk-theme-name = Arcanus
gtk-icon-theme-name = Arcanus-Icons
```

## Arcanus Color Palette

Reference colors from your branding:

```css
/* Primary Purple */
@define-color arcanus-purple #8B5CF6;
@define-color arcanus-dark-purple #6D28D9;

/* Dark Background */
@define-color arcanus-bg #0F0F1E;
@define-color arcanus-surface #1A1A2E;

/* Highlights */
@define-color arcanus-cyan #06B6D4;
@define-color arcanus-neon #A78BFA;
```

## Testing Theme

```bash
# Copy theme to system
mkdir -p ~/.local/share/themes
cp -r theme/Arcanus ~/.local/share/themes/

# In Linux Mint: Settings > Appearance > Themes
# Select "Arcanus" from dropdown
```

## Resources

- **GNOME Theme Documentation:** https://wiki.gnome.org/Attic/GnomeArt/Themes
- **GTK CSS Reference:** https://docs.gtk.org/gtk3/css-overview.html
- **Icon Theme Spec:** https://specifications.freedesktop.org/icon-theme-spec/

## Notes

- Themes in this folder are **optional** – the build works without them
- If you don't provide a theme, Linux Mint's default theme is used
- Custom themes will be auto-installed to `/usr/share/themes/` in the ISO

---

Leave this folder empty if you prefer to use Linux Mint's default Mint-X theme.
