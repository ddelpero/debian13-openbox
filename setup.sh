#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to check if a package exists in the repo before trying to install
check_pkg() {
    if ! apt-cache show "$1" > /dev/null 2>&1; then
        echo "ERROR: Package '$1' not found in repositories. Aborting."
        exit 1
    fi
}

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or using sudo"
  exit 1
fi

REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")

echo "--- Phase 1: System Update ---"
apt update || { echo "Update failed. Check your internet/sources.list"; exit 1; }

echo "--- Phase 2: Validating and Installing Core Packages ---"
CORE_PKGS="xserver-xorg x11-xserver-utils xinit openbox obconf lightdm geany fastfetch git wget curl unzip lxappearance nitrogen picom rofi lxterminal arc-theme papirus-icon-theme pipewire pipewire-pulse wireplumber alsa-utils network-manager network-manager-gnome polybar perl libgtk3-perl liblinux-desktopfiles-perl build-essential"

for pkg in $CORE_PKGS; do
    check_pkg "$pkg"
done

apt install -y $CORE_PKGS

echo "--- Phase 3: WezTerm (Manual Download & Verify) ---"
WEZ_URL=$(curl -s https://api.github.com/repos/wez/wezterm/releases/latest | grep -Po '"browser_download_url": "\K.*Ubuntu24.04\.deb' | head -n 1)
if [ -z "$WEZ_URL" ]; then echo "Could not find WezTerm download URL"; exit 1; fi
wget -O wezterm.deb "$WEZ_URL" || exit 1
apt install -y ./wezterm.deb || exit 1
rm wezterm.deb

echo "--- Phase 4: Min Browser (Manual Download & Verify) ---"
# Note: Min browser releases sometimes change naming schemes. We check the URL existence first.
MIN_VERSION=$(curl -s https://api.github.com/repos/minbrowser/min/releases/latest | grep -Po '"tag_name": "v\K[^"]*')
MIN_URL="https://github.com/minbrowser/min/releases/download/v${MIN_VERSION}/min_${MIN_VERSION}_amd64.deb"
wget --spider "$MIN_URL" || { echo "Min Browser URL is invalid for v$MIN_VERSION"; exit 1; }
wget -O min.deb "$MIN_URL"
apt install -y ./min.deb
rm min.deb

echo "--- Phase 5: LightDM Webkit2 & Aether ---"
# VALIDATION: lightdm-webkit2-greeter is often removed from Debian Stable/Testing.
if apt-cache show lightdm-webkit2-greeter > /dev/null 2>&1; then
    apt install -y lightdm-webkit2-greeter
    git clone https://github.com/NoiSek/Aether.git /usr/share/lightdm-webkit/themes/Aether || true
    sed -i 's/^webkit_theme.*/webkit_theme = Aether/' /etc/lightdm/lightdm-webkit2-greeter.conf
    sed -i 's/^#greeter-session=.*/greeter-session=lightdm-webkit2-greeter/' /etc/lightdm/lightdm.conf
else
    echo "WARNING: lightdm-webkit2-greeter not found. Falling back to default GTK greeter."
    apt install -y lightdm-gtk-greeter
fi

echo "--- Phase 6: Obmenu-Generator ---"
git clone https://github.com/trizen/obmenu-generator.git || exit 1
cp obmenu-generator/obmenu-generator /usr/local/bin/
chmod +x /usr/local/bin/obmenu-generator
sudo -u $REAL_USER /usr/local/bin/obmenu-generator -p -i || echo "Menu generation skipped, will need manual run."
rm -rf obmenu-generator

echo "--- Phase 7: Final Configurations ---"
# [Logic for Polybar copy and Openbox autostart remains here...]
# Ensure you run the script from the directory containing your 'config' folder

echo "SUCCESS: System is ready. Rebooting is recommended."
