#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root or using sudo"
  exit
fi

echo "Updating system repositories..."
apt update && apt upgrade -y

echo "Installing Openbox, LightDM, and Xorg..."
apt install -y xserver-xorg x11-xserver-utils xinit \
    openbox obconf obmenu \
    lightdm lightdm-gtk-greeter \
    geany fastfetch git wget curl unzip \
    lxappearance nitrogen picom rofi lxterminal

# 1. Install Min Browser
echo "Installing Min browser..."
MIN_VERSION=$(curl -s https://api.github.com/repos/minbrowser/min/releases/latest | grep -Po '"tag_name": "v\K[^"]*')
wget https://github.com/minbrowser/min/releases/download/v${MIN_VERSION}/min_${MIN_VERSION}_amd64.deb
apt install -y ./min_${MIN_VERSION}_amd64.deb
rm min_${MIN_VERSION}_amd64.deb

# 2. Install Aether LightDM Theme
echo "Installing Aether LightDM Theme..."
apt install -y lightdm-webkit2-greeter || echo "Note: lightdm-webkit2-greeter might require manual repo for Debian 13 if not in main"
git clone https://github.com/NoiSek/Aether.git /usr/share/lightdm-webkit/themes/Aether
# Set Aether as the default theme in the greeter config
sed -i 's/^webkit_theme.*/webkit_theme = Aether/' /etc/lightdm/lightdm-webkit2-greeter.conf
sed -i 's/^#greeter-session=.*/greeter-session=lightdm-webkit2-greeter/' /etc/lightdm/lightdm.conf

# 3. Install a Dark, Modern Minimal Openbox Theme (Arc-Dark)
echo "Installing Arc-Dark Theme..."
apt install -y arc-theme papirus-icon-theme

# 4. Configure Openbox Autostart
USER_HOME=$(eval echo "~$SUDO_USER")
mkdir -p "$USER_HOME/.config/openbox"
cat <<EOF > "$USER_HOME/.config/openbox/autostart"
# Compositor for transparency and rounded corners
picom &
# Wallpaper setter
nitrogen --restore &
# Launch panel (optional, Tint2 is a common minimal choice)
# tint2 &
EOF
chown -R $SUDO_USER:$SUDO_USER "$USER_HOME/.config"

echo "Installation complete. Please reboot."
