#!/bin/bash
set -e

# --- Configuration ---
REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")

# Phase 0: Bootstrap Fetch Tools
echo "--- Phase 0: Bootstrapping Fetch Tools ---"
apt update
apt install -y curl gpg wget

# Phase 1: WezTerm Repository
if [ ! -f "/etc/apt/sources.list.d/wezterm.list" ]; then
    echo "Adding WezTerm repository..."
    curl -fsSL https://apt.fury.io/wez/gpg.key | gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | tee /etc/apt/sources.list.d/wezterm.list
    chmod 644 /usr/share/keyrings/wezterm-fury.gpg
fi

# Comprehensive Packages
DEBIAN_PKGS="xserver-xorg x11-xserver-utils xinit openbox obconf lightdm geany fastfetch unzip lxappearance nitrogen picom rofi lxterminal arc-theme papirus-icon-theme pipewire pipewire-pulse wireplumber alsa-utils network-manager network-manager-gnome polybar nodejs npm acpi gobject-introspection liblightdm-gobject-1-0 liblightdm-gobject-dev libgirepository1.0-dev libcairo2 libcairo2-dev libxcb1-dev libx11-dev jgmenu libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libgtk-3-0 libgbm1 libasound2 libxshmfence1 libx11-xcb1"

echo "--- Phase 2: Core Installation ---"
apt update
apt install -y $DEBIAN_PKGS wezterm

# Min Browser
MIN_FILE="min-1.35.4-amd64.deb"
[ ! -f "$MIN_FILE" ] && wget -O "$MIN_FILE" "https://github.com/minbrowser/min/releases/download/v1.35.4/$MIN_FILE"
apt install -y "./$MIN_FILE"

echo "--- Phase 3: Nody-Greeter Build ---"
if [ ! -f "/usr/bin/nody-greeter" ]; then
    [ -d "nody-greeter" ] && rm -rf nody-greeter
    git clone --recursive https://github.com/JezerM/nody-greeter.git
    cd nody-greeter
    npm install --unsafe-perm
    npm run rebuild
    npm run build
    node make install
    cd ..
fi

# Segfault Check & Fix
if ! nody-greeter --test-mode --headless > /dev/null 2>&1; then
    ldconfig
    if ! nody-greeter --test-mode --headless > /dev/null 2>&1; then
        [ -f "/usr/share/xgreeters/nody-greeter.desktop" ] && \
        sed -i 's/Exec=nody-greeter/Exec=nody-greeter --no-sandbox/' /usr/share/xgreeters/nody-greeter.desktop
    fi
fi

echo "--- Phase 4: System Configs ---"
usermod -a -G video lightdm
systemctl enable lightdm
systemctl set-default graphical.target

# Aether Theme
mkdir -p /usr/share/nody-greeter/themes
[ ! -d "/usr/share/nody-greeter/themes/Aether" ] && git clone https://github.com/NoiSek/Aether.git /usr/share/nody-greeter/themes/Aether

# LightDM/Nody Settings
sed -i 's/^#greeter-session=.*/greeter-session=nody-greeter/' /etc/lightdm/lightdm.conf
sed -i 's/^greeter-session=.*/greeter-session=nody-greeter/' /etc/lightdm/lightdm.conf
for f in /etc/nody-greeter.conf /etc/lightdm/nody-greeter.yml; do
    [ -f "$f" ] && sed -i 's/theme: .*/theme: Aether/' "$f"
done

echo "--- Phase 5: User Environment ---"
# Create directories first
mkdir -p "$USER_HOME/.config/openbox"
mkdir -p "$USER_HOME/.config/jgmenu"
mkdir -p "$USER_HOME/.config/polybar"
mkdir -p "$USER_HOME/.config/gtk-3.0"

# Fix Permission Denied: Run jgmenu init correctly as the user
if [ ! -f "$USER_HOME/.config/jgmenu/jgmenurc" ]; then
    sudo -u "$REAL_USER" jgmenu_run init
fi

# Restored Polybar Sync
if [ -d "./config/polybar" ]; then
    echo "Copying local Polybar configs..."
    cp -r ./config/polybar/. "$USER_HOME/.config/polybar/"
    [ -f "$USER_HOME/.config/polybar/polybar-ob" ] && chmod +x "$USER_HOME/.config/polybar/polybar-ob"
else
    echo "WARNING: ./config/polybar source directory not found!"
fi

# GTK Theme
echo -e "[Settings]\ngtk-theme-name=Arc-Dark\ngtk-icon-theme-name=Papirus-Dark" > "$USER_HOME/.config/gtk-3.0/settings.ini"

# Autostart
cat <<EOF > "$USER_HOME/.config/openbox/autostart"
picom &
nitrogen --restore &
nm-applet &
jgmenu_run --pretend &
[ -f "$USER_HOME/.config/polybar/polybar-ob" ] && "$USER_HOME/.config/polybar/polybar-ob" &
EOF

# Nuclear permission fix for the user's home config
chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.config"

echo "--- SUCCESS ---"
