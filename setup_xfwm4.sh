#!/bin/bash
set -e

# --- Configuration ---
REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")

echo "--- Phase 1: Package Verification ---"
apt update
# Added 'xterm' as the ultimate fallback terminal
DEBIAN_PKGS="xserver-xorg xinit xfwm4 xfce4-settings xfce4-appfinder lightdm lightdm-gtk-greeter nitrogen picom rofi lxterminal arc-theme papirus-icon-theme polybar nautilus gnome-sushi arandr x11-xserver-utils dbus-x11 xterm"
apt install -y $DEBIAN_PKGS wezterm

echo "--- Phase 2: The Bulletproof .xinitrc ---"
cat <<EOF > "$USER_HOME/.xinitrc"
#!/bin/bash

# 1. Start D-Bus and export variables
if [ -z "\$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval \$(dbus-launch --sh-syntax --exit-with-session)
fi

# 2. Tell apps they are in an XFCE-based environment
export XDG_CURRENT_DESKTOP=XFCE
export DESKTOP_SESSION=XFCE

# 3. Start the Settings Daemon (Handles themes/shortcuts)
xfsettingsd --replace &

# 4. Failsafe: Open a terminal immediately so you aren't stuck
# If everything else fails, you'll at least have this window.
wezterm &

# 5. Background Services
picom --backend glx --vsync &
nitrogen --restore &
nm-applet &

# 6. Polybar - Using the full path to your script
if [ -f "$USER_HOME/.config/polybar/polybar-ob" ]; then
    bash "$USER_HOME/.config/polybar/polybar-ob" &
fi

# 7. Start the Window Manager (This MUST be the last command)
exec xfwm4
EOF

# Ensure permissions are correct
chmod +x "$USER_HOME/.xinitrc"
chown "$REAL_USER":"$REAL_USER" "$USER_HOME/.xinitrc"

echo "--- Phase 3: Creating the LightDM Session ---"
# This ensures LightDM knows exactly how to launch your .xinitrc
cat <<EOF > /usr/share/xsessions/xfwm4-custom.desktop
[Desktop Entry]
Name=Xfwm4-Custom
Comment=Minimal Xfwm4 Session
Exec=$USER_HOME/.xinitrc
Type=Application
DesktopNames=XFCE
EOF

echo "--- Phase 4: Native Snapping Settings ---"
# We force these settings into the Xfconf database
sudo -u "$REAL_USER" dbus-launch xfconf-query -c xfwm4 -p /general/tile_on_move -n -t bool -s true
sudo -u "$REAL_USER" dbus-launch xfconf-query -c xfwm4 -p /general/snap_to_border -n -t bool -s true
sudo -u "$REAL_USER" dbus-launch xfconf-query -c xfwm4 -p /general/margin_top -n -t int -s 28

echo "--- DONE ---"
echo "Reboot and select 'Xfwm4-Custom' from the LightDM menu."
