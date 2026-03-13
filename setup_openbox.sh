#!/bin/bash
set -e

# --- Configuration ---
REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")

echo "--- Phase 1: Package Sync ---"
apt update
# We are back to Openbox. Adding 'wmctrl' for the snapping logic.
DEBIAN_PKGS="xserver-xorg xinit openbox obconf lightdm lightdm-gtk-greeter nitrogen picom rofi lxterminal arc-theme papirus-icon-theme polybar jgmenu nautilus gnome-sushi arandr x11-xserver-utils dbus-x11 wmctrl xdotool xinput"
apt install -y $DEBIAN_PKGS wezterm

echo "--- Phase 2: Correcting Directory Structure ---"
# Polybar MUST be in .config/openbox/polybar per your requirement
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/openbox/polybar"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/rofi"

# Deploy YOUR configs
[ -d "./config/polybar" ] && cp -r ./config/polybar/. "$USER_HOME/.config/openbox/polybar/"
[ -d "./config/rofi" ] && cp -r ./config/rofi/. "$USER_HOME/.config/rofi/"
[ -f "$USER_HOME/.config/openbox/polybar/polybar-ob" ] && chmod +x "$USER_HOME/.config/openbox/polybar/polybar-ob"

# Get the base rc.xml
RC_XML="$USER_HOME/.config/openbox/rc.xml"
if [ ! -f "$RC_XML" ]; then
    sudo -u "$REAL_USER" cp /etc/xdg/openbox/rc.xml "$RC_XML"
fi

echo "--- Phase 3: Fixing the rc.xml (Smooth Shortcuts) ---"
# Remove old broken tiling logic
sed -i '/window tiling/I,+50d' "$RC_XML"

# Inject NATIVE shortcuts (No script required for keyboard)
# This is what makes it smooth like CBPP.
TEMP_BINDINGS=$(mktemp)
cat <<EOF > "$TEMP_BINDINGS"
    <keybind key="W-Left">
      <action name="Unmaximize"/><action name="MoveResizeTo"><x>0</x><y>0</y><width>50%</width><height>100%</height></action>
    </keybind>
    <keybind key="W-Right">
      <action name="Unmaximize"/><action name="MoveResizeTo"><x>-0</x><y>0</y><width>50%</width><height>100%</height></action>
    </keybind>
    <keybind key="W-Up">
      <action name="Maximize"/>
    </keybind>
    <keybind key="W-space">
      <action name="Execute"><command>rofi -show drun</command></action>
    </keybind>
EOF
sed -i "/<\/keyboard>/e cat $TEMP_BINDINGS" "$RC_XML"
rm "$TEMP_BINDINGS"

# Set Polybar Margin
sed -i 's/<top>0<\/top>/<top>28<\/top>/' "$RC_XML"
# Disable virtual desktop switching at edges
sed -i 's/<number>.*<\/number>/<number>1<\/number>/' "$RC_XML"
sed -i 's/<screenEdgeWarpTime>.*<\/screenEdgeWarpTime>/<screenEdgeWarpTime>0<\/screenEdgeWarpTime>/' "$RC_XML"

echo "--- Phase 4: The 'Non-Wonky' Snapper ---"
# This only handles MOUSE dragging.
cat <<'EOF' > /usr/local/bin/edge-snapper
#!/bin/bash
T=2
MARGIN=28
while true; do
    # Only act if mouse is at edge AND button is released
    eval $(xdotool getmouselocation --shell)
    WIDTH=$(xwininfo -root | grep 'Width' | awk '{print $2}')
    if [ "$X" -le "$T" ] || [ "$X" -ge "$((WIDTH - T))" ]; then
        # Wait for button release
        while xinput --query-state "$(xinput list --name-only | grep -i 'mouse' | head -n1)" | grep -q "button\[1\]=down"; do
            sleep 0.1
        done
        # Snap Left/Right
        if [ "$X" -le "$T" ]; then wmctrl -r :ACTIVE: -b remove,maximized_vert,maximized_horz; wmctrl -r :ACTIVE: -e 0,0,0,$((WIDTH/2)),-1
        elif [ "$X" -ge "$((WIDTH - T))" ]; then wmctrl -r :ACTIVE: -b remove,maximized_vert,maximized_horz; wmctrl -r :ACTIVE: -e 0,$((WIDTH/2)),0,$((WIDTH/2)),-1
        fi
    fi
    sleep 0.2
done
EOF
chmod +x /usr/local/bin/edge-snapper

echo "--- Phase 5: Autostart ---"
cat <<EOF > "$USER_HOME/.config/openbox/autostart"
# Theming for Nautilus
/usr/lib/x86_64-linux-gnu/gsd-xsettings &
picom --backend glx --vsync &
nitrogen --restore &
nm-applet &
edge-snapper &
bash "$USER_HOME/.config/openbox/polybar/polybar-ob" &
EOF

chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.config"
echo "--- DONE: Back to Openbox ---"
