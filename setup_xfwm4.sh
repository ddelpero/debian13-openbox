#!/bin/bash
set -e

# --- Configuration ---
REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")

echo "--- Phase 1: Core Installation (XFCE Minimal) ---"
apt update
# We install xfwm4 and xfce4-settings but NOT the whole desktop environment
DEBIAN_PKGS="xserver-xorg xinit xfwm4 xfce4-settings xfce4-appfinder lightdm lightdm-gtk-greeter nitrogen picom rofi lxterminal arc-theme papirus-icon-theme polybar nautilus gnome-sushi arandr x11-xserver-utils"

apt install -y $DEBIAN_PKGS wezterm

echo "--- Phase 2: Deploying YOUR Configs ---"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/polybar"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/rofi"

# Copy your existing files
[ -d "./config/polybar" ] && cp -r ./config/polybar/. "$USER_HOME/.config/polybar/"
[ -d "./config/rofi" ] && cp -r ./config/rofi/. "$USER_HOME/.config/rofi/"

echo "--- Phase 3: Enabling Native Snapping ---"
# This tells XFWM4 to enable edge snapping and the "ghost" preview
sudo -u "$REAL_USER" xfconf-query -c xfwm4 -p /general/tile_on_move -n -t bool -s true
sudo -u "$REAL_USER" xfconf-query -c xfwm4 -p /general/snap_to_border -n -t bool -s true

echo "--- Phase 4: Setting up the X Session ---"
# Instead of Openbox, we start XFWM4 and your bar
cat <<EOF > "$USER_HOME/.xinitrc"
# Load monitor layout if exists
[ -f "$USER_HOME/.screenlayout/monitor.sh" ] && sh "$USER_HOME/.screenlayout/monitor.sh" &

xfsettingsd &  # Handles themes and snapping
picom --backend glx &
nitrogen --restore &
"$USER_HOME/.config/polybar/polybar-ob" &
exec xfwm4
EOF

chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.config" "$USER_HOME/.xinitrc"
echo "--- SUCCESS: XFWM4 Deployed ---"
