#!/bin/bash
set -e

# --- Configuration ---
REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")

echo "--- Phase 1: Core Installation (XFCE Minimal + D-Bus) ---"
apt update
# dbus-x11 is the key missing piece here
DEBIAN_PKGS="xserver-xorg xinit xfwm4 xfce4-settings xfce4-appfinder lightdm lightdm-gtk-greeter nitrogen picom rofi lxterminal arc-theme papirus-icon-theme polybar nautilus gnome-sushi arandr x11-xserver-utils dbus-x11"

apt install -y $DEBIAN_PKGS wezterm

echo "--- Phase 2: Deploying YOUR Configs ---"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/polybar"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/rofi"

[ -d "./config/polybar" ] && cp -r ./config/polybar/. "$USER_HOME/.config/polybar/"
[ -d "./config/rofi" ] && cp -r ./config/rofi/. "$USER_HOME/.config/rofi/"

echo "--- Phase 3: Enabling Native Snapping (via D-Bus) ---"
# We wrap this in dbus-launch so the script can set settings without a running desktop
sudo -u "$REAL_USER" dbus-launch xfconf-query -c xfwm4 -p /general/tile_on_move -n -t bool -s true
sudo -u "$REAL_USER" dbus-launch xfconf-query -c xfwm4 -p /general/snap_to_border -n -t bool -s true
# Set your theme natively for XFWM4
sudo -u "$REAL_USER" dbus-launch xfconf-query -c xfwm4 -p /general/theme -n -t string -s "Arc-Dark"

echo "--- Phase 4: Setting up the X Session ---"
# We use dbus-launch in the .xinitrc to wrap the whole session
cat <<EOF > "$USER_HOME/.xinitrc"
# Ensure D-Bus session is started
if [ -z "\$DBUS_SESSION_BUS_ADDRESS" ]; then
  eval \$(dbus-launch --sh-syntax --exit-with-session)
fi

[ -f "$USER_HOME/.screenlayout/monitor.sh" ] && sh "$USER_HOME/.screenlayout/monitor.sh" &

xfsettingsd &
picom --backend glx &
nitrogen --restore &
"$USER_HOME/.config/polybar/polybar-ob" &

exec xfwm4
EOF

chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.config" "$USER_HOME/.xinitrc"
echo "--- SUCCESS: XFWM4 Deployed with D-Bus fixes ---"
