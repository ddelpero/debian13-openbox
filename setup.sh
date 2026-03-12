#!/bin/bash
set -e

# --- Configuration ---
REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")

# 1. BOOTSTRAP: Install only what's needed for the repo/binary fetching
echo "--- Phase 0: Bootstrapping Fetch Tools ---"
apt update
apt install -y curl gpg wget

# 2. REPOSITORIES: WezTerm (using your verified method)
echo "--- Phase 1: Repositories ---"
if [ ! -f "/etc/apt/sources.list.d/wezterm.list" ]; then
    echo "Adding WezTerm repository..."
    curl -fsSL https://apt.fury.io/wez/gpg.key | gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | tee /etc/apt/sources.list.d/wezterm.list
    chmod 644 /usr/share/keyrings/wezterm-fury.gpg
fi

# Comprehensive dependency list for Debian 13 (Trixie)
# Removed git (already present) and obmenu-generator (using jgmenu)
DEBIAN_PKGS="xserver-xorg x11-xserver-utils xinit openbox obconf lightdm geany fastfetch unzip lxappearance nitrogen picom rofi lxterminal arc-theme papirus-icon-theme pipewire pipewire-pulse wireplumber alsa-utils network-manager network-manager-gnome polybar nodejs npm acpi gobject-introspection liblightdm-gobject-1-0 liblightdm-gobject-dev libgirepository1.0-dev libcairo2 libcairo2-dev libxcb1-dev libx11-dev jgmenu libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libgtk-3-0 libgbm1 libasound2 libxshmfence1 libx11-xcb1"

echo "--- Phase 2: Core Installation ---"
apt update
apt install -y $DEBIAN_PKGS wezterm

# Min Browser: Skip download if exists locally
MIN_FILE="min-1.35.4-amd64.deb"
[ ! -f "$MIN_FILE" ] && wget -O "$MIN_FILE" "https://github.com/minbrowser/min/releases/download/v1.35.4/$MIN_FILE"
apt install -y "./$MIN_FILE"

echo "--- Phase 3: Nody-Greeter Build & Segfault Validation ---"
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

# Validation: Check for the segfault you encountered
echo "Testing nody-greeter for stability..."
if ! nody-greeter --test-mode --headless > /dev/null 2>&1; then
    echo "Validation failed. Refreshing shared library cache..."
    ldconfig
    if ! nody-greeter --test-mode --headless > /dev/null 2>&1; then
        echo "CRITICAL: nody-greeter is still segfaulting."
        echo "Updating Electron Sandbox permissions for LightDM..."
        # Electron occasionally segfaults as root/lightdm without this
        [ -f "/usr/share/xgreeters/nody-greeter.desktop" ] && \
        sed -i 's/Exec=nody-greeter/Exec=nody-greeter --no-sandbox/' /usr/share/xgreeters/nody-greeter.desktop
    fi
fi

echo "--- Phase 4: Hardware & Systemd ---"
usermod -a -G video lightdm
systemctl enable lightdm
systemctl set-default graphical.target

# Theme Setup
AETHER_PATH="/usr/share/nody-greeter/themes/Aether"
if [ ! -d "$AETHER_PATH" ]; then
    mkdir -p /usr/share/nody-greeter/themes
    git clone https://github.com/NoiSek/Aether.git "$AETHER_PATH"
fi

# Config Force-Apply
sed -i 's/^#greeter-session=.*/greeter-session=nody-greeter/' /etc/lightdm/lightdm.conf
sed -i 's/^greeter-session=.*/greeter-session=nody-greeter/' /etc/lightdm/lightdm.conf

for f in /etc/nody-greeter.conf /etc/lightdm/nody-greeter.yml; do
    [ -f "$f" ] && sed -i 's/theme: .*/theme: Aether/' "$f"
done

echo "--- Phase 5: User Environment ---"
mkdir -p "$USER_HOME/.config/openbox" "$USER_HOME/.config/jgmenu" "$USER_HOME/.config/gtk-3.0"
[ ! -f "$USER_HOME/.config/jgmenu/jgmenurc" ] && sudo -u $REAL_USER jgmenu_run init
echo -e "[Settings]\ngtk-theme-name=Arc-Dark\ngtk-icon-theme-name=Papirus-Dark" > "$USER_HOME/.config/gtk-3.0/settings.ini"

# Polybar Sync
if [ -d "./config/polybar" ]; then
    cp -r ./config/polybar/* "$USER_HOME/.config/polybar/"
    chmod +x "$USER_HOME/.config/polybar/polybar-ob"
fi

# Openbox Autostart
cat <<EOF > "$USER_HOME/.config/openbox/autostart"
picom &
nitrogen --restore &
nm-applet &
jgmenu_run --pretend &
"$USER_HOME/.config/polybar/polybar-ob" &
EOF

chown -R $REAL_USER:$REAL_USER "$USER_HOME/.config"
echo "--- SUCCESS: Reboot to start your Openbox session ---"
