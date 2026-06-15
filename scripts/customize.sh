#!/bin/bash
# Post-install script for Arcanus OS (Debian 12)
set -euo pipefail

# Define source paths (expects files to be staged in /tmp by the host script)
BRANDING_DIR="/tmp/arcanus-branding"
LEDGER_TAR="/tmp/arcanus-ledger-linux.tar.gz"

echo "🎨 [1/4] Applying Arcanus OS visual identity..."

# Install essential UI packages
# Ensure the chroot has an active network or that these are pre-cached
apt-get update
apt-get install -y \
    plymouth-theme-ubuntu-text \
    xfce4-themes \
    xfce4-whiskermenu-plugin \
    fonts-liberation2

# Branding application
if [ -d "${BRANDING_DIR}" ]; then
    [ -f "${BRANDING_DIR}/arcanus-logo.png" ] && cp "${BRANDING_DIR}/arcanus-logo.png" /usr/share/pixmaps/
    if [ -f "${BRANDING_DIR}/wallpaper.png" ]; then
        mkdir -p /usr/share/backgrounds/xfce
        cp "${BRANDING_DIR}/wallpaper.png" /usr/share/backgrounds/arcanus-wallpaper.png
        cp "${BRANDING_DIR}/wallpaper.png" /usr/share/backgrounds/xfce/
    fi
fi

echo "🎨 [2/4] Configuring Bootloader..."
# Append Arcanus branding to GRUB configuration
if ! grep -q "Arcanus OS" /etc/default/grub; then
    cat >> /etc/default/grub << 'EOF'

# Arcanus OS Branding
GRUB_COLOR_NORMAL="white/black"
GRUB_COLOR_HIGHLIGHT="black/light-cyan"
GRUB_BACKGROUND_IMAGE="/usr/share/backgrounds/arcanus-wallpaper.png"
EOF
fi
update-grub 2>/dev/null || true

echo "🎨 [3/4] Deploying Arcanus Ledger..."
if [ -f "${LEDGER_TAR}" ]; then
    mkdir -p /opt/arcanus-ledger
    tar -xzf "${LEDGER_TAR}" -C /opt/arcanus-ledger/
    
    # Desktop integration
    cat > /usr/share/applications/arcanus-ledger.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Arcanus Ledger
Comment=Secure business ledger and finance management
Exec=/opt/arcanus-ledger/arcanus_ledger
Icon=arcanus-logo
Categories=Finance;Office;
Terminal=false
EOF
fi

echo "🎨 [4/4] Finalizing and cleaning environment..."
# Clean up build artifacts and cache to reduce ISO size
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/arcanus-branding
rm -f "${LEDGER_TAR}"

echo "✅ Arcanus OS customization complete"