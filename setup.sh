#!/bin/bash
set -e

# --- Configuration ---
REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")

# Verified Debian 13 Packages
DEBIAN_PKGS="xserver-xorg x11-xserver-utils xinit openbox obconf lightdm geany fastfetch git wget curl unzip lxappearance nitrogen picom rofi lxterminal arc-theme papirus-icon-theme pipewire pipewire-pulse wireplumber alsa-utils network-manager network-manager-gnome polybar perl libgtk3-perl build-essential libfile-which-perl libconfig-tiny-perl"

echo "--- Phase 1: Pre-Flight Validation ---"

# 1. Check Package Existence
for pkg in $DEBIAN_PKGS; do
    apt-cache show "$pkg" > /dev/null 2>&1 || { echo "ERROR: $pkg not found in repos. Aborting."; exit 1; }
done

# 2. Validate External URLs
WEZ_URL=$(curl -s https://api.github.com/repos/wez/wezterm/releases/latest | grep -Po '"browser_download_url": "\K.*Ubuntu24.04\.deb' | head -n 1)
MIN_VERSION=$(curl -s https://api.github.com/repos/minbrowser/min/releases/latest | grep -Po '"tag_name": "v\K[^"]*')
MIN_URL="https://github.com/minbrowser/min/releases/download/v${MIN_VERSION}/min_${MIN_VERSION}_amd64.deb"
WEB_GREETER_URL="https://github.com/JezerM/web-greeter/releases/download/3.5.0/web-greeter-3.5.0-ubuntu.deb"

[[ -z "$WEZ_URL" ]] && { echo "ERROR: WezTerm URL failed."; exit 1; }
wget --spider -q "$MIN_URL" || { echo "ERROR: Min Browser URL 404."; exit 1; }

echo "--- Phase 2: Core Installation ---"
apt update && apt install -y $DEBIAN_PKGS

# Install External .debs
wget -O wezterm.deb "$WEZ_URL" && apt install -y ./wezterm.deb && rm wezterm.deb
wget -O min.deb "$MIN_URL" && apt install -y ./min.deb && rm min.deb
wget -O web-greeter.deb "$WEB_GREETER_URL" && apt install -y ./web-greeter.deb && rm web-greeter.deb

echo "--- Phase 3: Perl & obmenu-generator ---"
# Install the specific missing Perl module via CPAN
perl -MCPAN -e 'my $c = CPAN::HandleConfig; $c->load; $c->set("prerequisites_policy", "follow"); $c->set("build_requires_install_policy", "yes"); CPAN::Shell->install("Linux::DesktopFiles")'

git clone https://github.com/trizen/obmenu-generator.git
cp obmenu-generator/obmenu-generator /usr/local/bin/
chmod +x /usr/local/bin/obmenu-generator
rm -rf obmenu-generator

echo "--- Phase 4: Theme & Config Setup ---"
# Setup Aether for web-greeter
mkdir -p /usr/share/web-greeter/themes/Aether
git clone https://github.com/NoiSek/Aether.git /tmp/Aether
cp -r /tmp/Aether/* /usr/share/web-greeter/themes/Aether/

# Configure LightDM to use web-greeter
sed -i 's/^#greeter-session=.*/greeter-session=web-greeter/' /etc/lightdm/lightdm.conf

# Deployment of your custom Polybar files
if [ -d "./config/polybar" ]; then
    mkdir -p "$USER_HOME/.config/polybar"
    cp ./config/polybar/config.ini "$USER_HOME/.config/polybar/"
    cp ./config/polybar/polybar-ob "$USER_HOME/.config/polybar/"
    chmod +x "$USER_HOME/.config/polybar/polybar-ob"
fi

# Openbox Autostart & GTK Dark Theme
mkdir -p "$USER_HOME/.config/openbox" "$USER_HOME/.config/gtk-3.0"
echo -e "[Settings]\ngtk-theme-name=Arc-Dark\ngtk-icon-theme-name=Papirus-Dark" > "$USER_HOME/.config/gtk-3.0/settings.ini"

cat <<EOF > "$USER_HOME/.config/openbox/autostart"
picom &
nitrogen --restore &
nm-applet &
"$USER_HOME/.config/polybar/polybar-ob" &
EOF

chown -R $REAL_USER:$REAL_USER "$USER_HOME/.config"
echo "--- SUCCESS ---"
