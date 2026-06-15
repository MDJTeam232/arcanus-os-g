#!/bin/bash
# ==============================================================================
#              ARCANUS OS IMAGE CUSTOMIZATION INJECTOR (DEBIAN 12 CHROOT)
# ==============================================================================
export DEBIAN_FRONTEND=noninteractive

echo "⏳ 1. Initializing system package lookup hooks..."
apt-get update

echo "⏳ 2. Injecting lightweight XFCE display managers & server wrappers..."
apt-get install -y --no-install-recommends \
    xfce4 \
    xfce4-goodies \
    lightdm \
    lightdm-gtk-greeter \
    arc-theme \
    nginx \
    ufw \
    python3-pip \
    python3-venv \
    wkhtmltopdf \
    curl \
    sqlite3

echo "⏳ 3. Designing system-wide Arcanus user environment parameters..."
# Add the core unprivileged runtime user account
if ! id -u arcanus >/dev/null 2>&1; then
    useradd -m -s /bin/bash -p "$(openssl passwd -1 arcanuspassword)" arcanus
fi

echo "⏳ 4. Compiling localized Python Flask environments for Arcanus Reports..."
mkdir -p /usr/share/arcanus/report-engine
python3 -m venv /usr/share/arcanus/report-env
/usr/share/arcanus/report-env/bin/pip install --upgrade pip
/usr/share/arcanus/report-env/bin/pip install gunicorn flask reportlab

echo "⏳ 5. Establishing global dconf desktop parameters and theme locks..."
# Generate internal configuration files directly from script strings
cat <<EOF > /etc/dconf/profile/user
user-db:user
system-db:arcanus
EOF

mkdir -p /etc/dconf/db/arcanus.d/locks
cat <<EOF > /etc/dconf/db/arcanus.d/00-arcanus-branding
[org/xfce/desktop/background]
image-path='/usr/share/backgrounds/arcanus/wallpaper.png'
style=5

[org/gnome/desktop/interface]
icon-theme='Arcanus'
gtk-theme='Arc-Dark'
font-name='Inter Regular 10'
EOF

cat <<EOF > /etc/dconf/db/arcanus.d/locks/00-branding-lock
/org/xfce/desktop/background/image-path
/org/gnome/desktop/interface/icon-theme
/org/gnome/desktop/interface/gtk-theme
EOF

# Update binary database maps to lock themes permanently
dconf update

echo "⏳ 6. Securing network interfaces via strict UFW profiles..."
ufw --force reset
ufw default deny incoming
ufw default deny outgoing
ufw allow in on lo
ufw allow out on lo
ufw deny in from any to 127.0.0.0/8
ufw deny out from any to 127.0.0.0/8
ufw --force enable

echo "⏳ 7. Purging transient build-layer footprints and logs..."
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

echo "🏁 Image customization layer tasks complete."
