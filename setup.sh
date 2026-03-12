#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or using sudo"
  exit
fi

REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")

echo "Updating system repositories..."
apt update && apt upgrade -y

echo "Installing Core (Openbox, LightDM, Xorg)..."
# Removed obmenu-generator from here as it's not in the apt repo
apt install -y xserver-xorg x11-xserver-utils xinit \
    openbox obconf \
    lightdm lightdm-gtk-greeter \
    geany fastfetch git wget curl unzip \
    lxappearance nitrogen picom rofi lxterminal

# 1. Themes (Arc-Dark & Papirus)
echo "Installing Themes..."
apt install -y arc-theme papirus-icon-theme

# 2. Sound (PipeWire) & Network (NetworkManager)
echo "Installing Sound and Network Management..."
apt install -y pipewire pipewire-pulse wireplumber alsa-utils \
    network-manager network-manager-gnome

# 3. Install WezTerm (via GitHub .deb)
echo "Installing WezTerm..."
WEZ_URL=$(curl -s https://api.github.com/repos/wez/wezterm/releases/latest | grep -Po '"browser_download_url": "\K.*Ubuntu24.04\.deb' | head -n 1)
wget -O wezterm.deb "$WEZ_URL"
apt install -y ./wezterm.deb
rm wezterm.deb

# 4. Install Polybar
echo "Installing Polybar..."
apt install -y polybar

# 5. Install Min Browser
echo "Installing Min browser..."
MIN_VERSION=$(curl -s https://api.github.com/repos/minbrowser/min/releases/latest | grep -Po '"tag_name": "v\K[^"]*')
wget https://github.com/minbrowser/min/releases/download/v${MIN_VERSION}/min_${MIN_VERSION}_amd64.deb
apt install -y ./min_${MIN_VERSION}_amd64.deb
rm min_${MIN_VERSION}_amd64.deb

# 6. Install Aether LightDM Theme
echo "Installing Aether LightDM Theme..."
# Note: if lightdm-webkit2-greeter is missing in Trixie, this line will skip but the script continues
apt install -y lightdm-webkit2-greeter || echo "Skipping Aether: webkit2-greeter not found."
if [ -d "/usr/share/lightdm-webkit/themes" ]; then
    git clone https://github.com/NoiSek/Aether.git /usr/share/lightdm-webkit/themes/Aether
    sed -i 's/^webkit_theme.*/webkit_theme = Aether/' /etc/lightdm/lightdm-webkit2-greeter.conf
    sed -i 's/^#greeter-session=.*/greeter-session=lightdm-webkit2-greeter/' /etc/lightdm/lightdm.conf
fi

# 7. Install obmenu-generator (Manual Install for Debian 13)
echo "Installing obmenu-generator and dependencies..."
apt install -y perl libgtk3-perl liblinux-desktopfiles-perl build-essential
git clone https://github.com/trizen/obmenu-generator.git
cp obmenu-generator/obmenu-generator /usr/local/bin/
chmod +x /usr/local/bin/obmenu-generator
# Generate initial menu for the user
sudo -u $REAL_USER /usr/local/bin/obmenu-generator -p -i
rm -rf obmenu-generator

# 8. Configuration Deployment (Polybar & Openbox)
echo "Deploying configs..."
mkdir -p "$USER_HOME/.config/polybar"
if [ -d "./config/polybar" ]; then
    cp ./config/polybar/config.ini "$USER_HOME/.config/polybar/"
    cp ./config/polybar/polybar-ob "$USER_HOME/.config/polybar/"
    chmod +x "$USER_HOME/.config/polybar/polybar-ob"
fi

# Auto-set Dark Theme for GTK apps
mkdir -p "$USER_HOME/.config/gtk-3.0"
cat <<EOF > "$USER_HOME/.config/gtk-3.0/settings.ini"
[Settings]
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Sans 10
EOF

mkdir -p "$USER_HOME/.config/openbox"
cat <<EOF > "$USER_HOME/.config/openbox/autostart"
# Background processes
picom &
nitrogen --restore &
nm-applet &

# Launch Polybar
"$USER_HOME/.config/polybar/polybar-ob" &
EOF

# Fix permissions
chown -R $REAL_USER:$REAL_USER "$USER_HOME/.config"

echo "Setup finished. Reboot to enjoy your new environment!"
