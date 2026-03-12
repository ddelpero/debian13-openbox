#!/bin/bash
set -e

# --- Configuration ---
REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")

# EXACT Dependencies for nody-greeter, jgmenu, and system tools
DEBIAN_PKGS="xserver-xorg x11-xserver-utils xinit openbox obconf lightdm geany fastfetch git wget curl unzip lxappearance nitrogen picom rofi lxterminal arc-theme papirus-icon-theme pipewire pipewire-pulse wireplumber alsa-utils network-manager network-manager-gnome polybar nodejs npm acpi gobject-introspection liblightdm-gobject-1-0 liblightdm-gobject-dev libgirepository1.0-dev libcairo2 libcairo2-dev libxcb1-dev libx11-dev jgmenu"

echo "--- Phase 1: Pre-Flight Validation ---"

# 1. Check Package Existence
for pkg in $DEBIAN_PKGS; do
    apt-cache show "$pkg" > /dev/null 2>&1 || { echo "ERROR: $pkg not found in repos. Aborting."; exit 1; }
done

# 2. Setup WezTerm Repository
echo "Adding WezTerm repository..."
curl -fsSL https://apt.fury.io/wez/gpg.key | gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | tee /etc/apt/sources.list.d/wezterm.list
chmod 644 /usr/share/keyrings/wezterm-fury.gpg

# 3. Direct Min Link (v1.35.4)
MIN_URL="https://github.com/minbrowser/min/releases/download/v1.35.4/min-1.35.4-amd64.deb"
wget --spider -q "$MIN_URL" || { echo "ERROR: Min Browser link 404."; exit 1; }

echo "--- Phase 2: Core Installation ---"
apt update
apt install -y $DEBIAN_PKGS wezterm

# Install Min Browser
wget -O min.deb "$MIN_URL" && apt install -y ./min.deb && rm min.deb

echo "--- Phase 3: Building Nody-Greeter ---"
if [ ! -d "nody-greeter" ]; then
    git clone --recursive https://github.com/JezerM/nody-greeter.git
    cd nody-greeter
    npm install
    npm run rebuild
    npm run build
    node make install
    cd ..
    rm -rf nody-greeter
fi

# Permissions for Brightness Control
usermod -a -G video lightdm

echo "--- Phase 4: jgmenu Configuration ---"
# Create jgmenu config directory for the user
mkdir -p "$USER_HOME/.config/jgmenu"
# Generate a default configuration that looks dark and minimal
sudo -u $REAL_USER jgmenu_run init

# Update Openbox to use jgmenu instead of the default menu
mkdir -p "$USER_HOME/.config/openbox"
cat <<EOF > "$USER_HOME/.config/openbox/rc.xml"
<openbox_config>
  <mouse>
    <context name="Root">
      <mousebind button="Right" action="Press">
        <action name="Execute">
          <command>jgmenu_run</command>
        </action>
      </mousebind>
    </context>
  </mouse>
</openbox_config>
EOF

echo "--- Phase 5: Themes & Configs ---"
# Setup Aether for nody-greeter
mkdir -p /usr/share/nody-greeter/themes/Aether
git clone https://github.com/NoiSek/Aether.git /tmp/Aether
cp -r /tmp/Aether/* /usr/share/nody-greeter/themes/Aether/

# Configure LightDM for Nody
sed -i 's/^#greeter-session=.*/greeter-session=nody-greeter/' /etc/lightdm/lightdm.conf

# Deploy local Polybar files
if [ -d "./config/polybar" ]; then
    mkdir -p "$USER_HOME/.config/polybar"
    cp ./config/polybar/config.ini "$USER_HOME/.config/polybar/"
    cp ./config/polybar/polybar-ob "$USER_HOME/.config/polybar/"
    chmod +x "$USER_HOME/.config/polybar/polybar-ob"
fi

# Set Dark Theme defaults
mkdir -p "$USER_HOME/.config/gtk-3.0"
echo -e "[Settings]\ngtk-theme-name=Arc-Dark\ngtk-icon-theme-name=Papirus-Dark" > "$USER_HOME/.config/gtk-3.0/settings.ini"

# Openbox Autostart
cat <<EOF > "$USER_HOME/.config/openbox/autostart"
picom &
nitrogen --restore &
nm-applet &
# Pre-load jgmenu for faster response
jgmenu_run --pretend &
"$USER_HOME/.config/polybar/polybar-ob" &
EOF

chown -R $REAL_USER:$REAL_USER "$USER_HOME/.config"

echo "--- SUCCESS: Installation Complete ---"
