#!/bin/bash
set -e

# --- Configuration ---
REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")

# Verified Debian 13 Packages
# Added the web-greeter build dependencies you found
DEBIAN_PKGS="xserver-xorg x11-xserver-utils xinit openbox obconf lightdm geany fastfetch git wget curl unzip lxappearance nitrogen picom rofi lxterminal arc-theme papirus-icon-theme pipewire pipewire-pulse wireplumber alsa-utils network-manager network-manager-gnome polybar perl libgtk3-perl build-essential libfile-which-perl libconfig-tiny-perl liblightdm-gobject-1-dev python3-gi python3-pyqt5 python3-pyqt5.qtwebengine python3-ruamel.yaml python3-pyinotify libqt5webengine5 gobject-introspection libxcb1-dev libx11-dev rsync make node-typescript"

echo "--- Phase 1: Pre-Flight Validation ---"

# 1. Check Package Existence
for pkg in $DEBIAN_PKGS; do
    apt-cache show "$pkg" > /dev/null 2>&1 || { echo "ERROR: $pkg not found in repos."; exit 1; }
done

# 2. Setup WezTerm Repository
echo "Adding WezTerm official repository..."
curl -fsSL https://apt.fury.io/wez/gpg.key | gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | tee /etc/apt/sources.list.d/wezterm.list
chmod 644 /usr/share/keyrings/wezterm-fury.gpg

# 3. Direct Min Link
MIN_URL="https://github.com/minbrowser/min/releases/download/v1.35.4/min-1.35.4-amd64.deb"
wget --spider -q "$MIN_URL" || { echo "ERROR: Min Browser link 404."; exit 1; }

echo "--- Phase 2: Installation ---"
apt update
apt install -y $DEBIAN_PKGS wezterm

# Install Min Browser
wget -O min.deb "$MIN_URL" && apt install -y ./min.deb && rm min.deb

echo "--- Phase 3: Building Web-Greeter from Source ---"
if [ ! -d "web-greeter" ]; then
    git clone --recursive https://github.com/JezerM/web-greeter.git
    cd web-greeter
    make install
    cd ..
    rm -rf web-greeter
fi

echo "--- Phase 4: Perl & obmenu-generator ---"
# Install Linux::DesktopFiles via CPAN for Debian 13 compatibility
perl -MCPAN -e 'my $c = CPAN::HandleConfig; $c->load; $c->set("prerequisites_policy", "follow"); $c->set("build_requires_install_policy", "yes"); CPAN::Shell->install("Linux::DesktopFiles")'

if [ ! -d "obmenu-generator" ]; then
    git clone https://github.com/trizen/obmenu-generator.git
    cp obmenu-generator/obmenu-generator /usr/local/bin/
    chmod +x /usr/local/bin/obmenu-generator
    rm -rf obmenu-generator
fi

echo "--- Phase 5: Themes & Configs ---"
# Setup Aether
mkdir -p /usr/share/web-greeter/themes/Aether
git clone https://github.com/NoiSek/Aether.git /tmp/Aether
cp -r /tmp/Aether/* /usr/share/web-greeter/themes/Aether/

# Configure LightDM
sed -i 's/^#greeter-session=.*/greeter-session=web-greeter/' /etc/lightdm/lightdm.conf

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
mkdir -p "$USER_HOME/.config/openbox"
cat <<EOF > "$USER_HOME/.config/openbox/autostart"
picom &
nitrogen --restore &
nm-applet &
"$USER_HOME/.config/polybar/polybar-ob" &
EOF

chown -R $REAL_USER:$REAL_USER "$USER_HOME/.config"

echo "--- SUCCESS: Installation Complete ---"
