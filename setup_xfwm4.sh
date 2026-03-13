#!/bin/bash
set -e

# --- Configuration ---
REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")

echo "--- Phase 1: Package Sync (Ensuring D-Bus & Xfwm4) ---"
apt update
DEBIAN_PKGS="xserver-xorg xinit xfwm4 xfce4-settings xfce4-appfinder lightdm lightdm-gtk-greeter nitrogen picom rofi lxterminal arc-theme papirus-icon-theme polybar nautilus gnome-sushi arandr x11-xserver-utils dbus-x11"
apt install -y $DEBIAN_PKGS wezterm

echo "--- Phase 2: Session Entry for LightDM ---"
# This creates the option in the LightDM login menu
cat <<EOF > /usr/share/xsessions/xfwm4-custom.desktop
[Desktop Entry]
Name=Xfwm4 (Custom)
Comment=Minimal Xfwm4 Session
Exec=$USER_HOME/.xinitrc
Type=Application
DesktopNames=XFCE
EOF

echo "--- Phase 3: Setting up the X Session (.xinitrc) ---"
cat <<EOF > "$USER_HOME/.xinitrc"
#!/bin/bash
# Ensure D-Bus session is started
if [ -z "\$DBUS_SESSION_BUS_ADDRESS" ]; then
  eval \$(dbus-launch --sh-syntax --exit-with-session)
fi

# Load monitor layout
[ -f "$USER_HOME/.screenlayout/monitor.sh" ] && sh "$USER_HOME/.screenlayout/monitor.sh" &

xfsettingsd &
picom --backend glx &
nitrogen --restore &
"$USER_HOME/.config/polybar/polybar-ob" &

exec xfwm4
EOF

chmod +x "$USER_HOME/.xinitrc"

echo "--- Phase 4: Enabling Native Snapping ---"
# Setting these via dbus-launch so they apply even if not logged in
sudo -u "$REAL_USER" dbus-launch xfconf-query -c xfwm4 -p /general/tile_on_move -n -t bool -s true
sudo -u "$REAL_USER" dbus-launch xfconf-query -c xfwm4 -p /general/snap_to_border -n -t bool -s true
# Margin for Polybar (Xfwm4 uses margins slightly differently)
sudo -u "$REAL_USER" dbus-launch xfconf-query -c xfwm4 -p /general/margin_top -n -t int -s 28

chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.config" "$USER_HOME/.xinitrc"

echo "--- SUCCESS ---"
echo "Reboot or restart LightDM. Select 'Xfwm4 (Custom)' from the session menu."
