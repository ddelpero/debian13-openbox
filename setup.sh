#!/bin/bash
set -e

# --- Configuration ---
REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")

# Verified Debian 13 Packages
DEBIAN_PKGS="xserver-xorg x11-xserver-utils xinit openbox obconf lightdm geany fastfetch git wget curl unzip lxappearance nitrogen picom rofi lxterminal arc-theme papirus-icon-theme pipewire pipewire-pulse wireplumber alsa-utils network-manager network-manager-gnome polybar perl libgtk3-perl build-essential libfile-which-perl libconfig-tiny-perl"

echo "--- Phase 1: Pre-Flight Validation ---"

# 1. Check Package Existence in Debian Repos
for pkg in $DEBIAN_PKGS; do
    apt-cache show "$pkg" > /dev/null 2>&1 || { echo "ERROR: $pkg not found in repos. Aborting."; exit 1; }
done

# 2. Setup WezTerm Repository (Official Fury.io)
echo "Adding WezTerm official repository..."
curl -fsSL https://apt.fury.io/wez/gpg.key | gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | tee /etc/apt/sources.list.d/wezterm.list
chmod 644 /usr/share/keyrings/wezterm-fury.gpg

# 3. Official Stable Links (No Scraping)
MIN_URL="https://github.com/minbrowser/min/releases/download/v1.33.1/min_1.33.1_amd64.deb"
WEB_GREETER_URL="https://github.com/JezerM/web-greeter/releases/download/3.5.0/web-greeter-3.5.0-ubuntu.deb"

# Validate URLs exist before proceeding
wget --spider -q "$MIN_URL" || { echo "ERROR: Official Min Browser link 404."; exit 1; }
wget --spider -q "$WEB_GREETER_URL" || { echo "ERROR: Official Web-Greeter link 404."; exit 1; }

echo "--- Phase 2: Installation ---"
apt update
apt install -y $DEBIAN_PKGS wezterm

# Install External .debs from Official Release Pages
wget -O min.deb "$MIN_URL" && apt install -y ./min.deb && rm min.deb
wget -O web-greeter.deb "$WEB_GREETER_URL" && apt install -y ./web-greeter.deb && rm web-greeter.deb

echo "--- Phase 3: Perl & obmenu-generator ---"
# Using CPAN for the missing Debian 13 dependency
perl -MCPAN -e 'my $c = CPAN::HandleConfig; $c->load; $c->set("prerequisites_policy", "follow"); $c->set("build_requires_install_policy", "yes"); CPAN::Shell->install("Linux::DesktopFiles")'

if [ ! -d "obmenu-generator" ]; then
    git clone https://github.com/trizen/obmenu-generator.git
    cp obmenu-generator/obmenu-generator /usr/local/bin/
    chmod +x /usr/local/bin/obmenu-generator
    rm -rf obmenu-generator
fi

echo "--- Phase 4: Themes & Custom Configs ---"
# Aether setup for web-greeter
mkdir -p /usr/share/web-greeter/themes/Aether
git clone https://github.com/NoiSek/Aether.git /tmp/Aether
cp -r /tmp/Aether/* /usr/share/web-greeter/themes/Aether/
sed -i 's/^#greeter-session=.*/greeter-session=web-greeter/' /etc/lightdm/lightdm.conf

# Deploy your local Polybar files
if [ -d "./config/polybar" ]; then
    mkdir -p "$USER_HOME/.config/polybar"
    cp ./config/polybar/config.ini "$USER_HOME/.config/polybar/"
    cp ./config/polybar/polybar-ob "$USER_HOME/.config/polybar/"
    chmod +x "$USER_HOME/.config/polybar/polybar-ob"
fi

# Set System-wide Dark Theme
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
