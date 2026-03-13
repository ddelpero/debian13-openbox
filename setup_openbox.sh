#!/bin/bash
set -e

# --- Configuration ---
REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")

echo "--- Phase 1: Package Sync ---"
apt update
# Restored the full suite including Min dependencies
DEBIAN_PKGS="xserver-xorg xinit openbox obconf lightdm lightdm-gtk-greeter nitrogen picom rofi lxterminal arc-theme papirus-icon-theme polybar jgmenu nautilus gnome-sushi arandr x11-xserver-utils dbus-x11 wmctrl xdotool xinput"
apt install -y $DEBIAN_PKGS wezterm

# Min Browser - Restored
MIN_FILE="min-1.35.4-amd64.deb"
if [ ! -f "$MIN_FILE" ]; then
    wget -O "$MIN_FILE" "https://github.com/minbrowser/min/releases/download/v1.35.4/$MIN_FILE"
fi
apt install -y "./$MIN_FILE"

echo "--- Phase 2: Directory & Config Deployment ---"
# Strictly using .config/openbox/polybar/ as requested
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/openbox/polybar"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/rofi"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/jgmenu"

[ -d "./config/polybar" ] && cp -r ./config/polybar/. "$USER_HOME/.config/openbox/polybar/"
[ -d "./config/rofi" ] && cp -r ./config/rofi/. "$USER_HOME/.config/rofi/"
[ -f "$USER_HOME/.config/openbox/polybar/polybar-ob" ] && chmod +x "$USER_HOME/.config/openbox/polybar/polybar-ob"

# Initialize rc.xml if it doesn't exist
RC_XML="$USER_HOME/.config/openbox/rc.xml"
if [ ! -f "$RC_XML" ]; then
    sudo -u "$REAL_USER" cp /etc/xdg/openbox/rc.xml "$RC_XML"
fi

echo "--- Phase 3: Restoring YOUR Exact Shortcuts ---"
# Clean previous attempts
sed -i '/window tiling/I,+55d' "$RC_XML"

TEMP_BINDINGS=$(mktemp)
cat <<EOF > "$TEMP_BINDINGS"
    <keybind key="W-Left">
      <action name="UnmaximizeFull"/>
      <action name="MoveResizeTo"><x>0</x><y>0</y><height>100%</height><width>50%</width></action>
    </keybind>
    <keybind key="W-Right">
      <action name="UnmaximizeFull"/>
      <action name="MoveResizeTo"><x>-0</x><y>0</y><height>100%</height><width>50%</width></action>
    </keybind>
    <keybind key="W-Up">
      <action name="UnmaximizeFull"/>
      <action name="MoveResizeTo"><x>0</x><y>0</y><width>100%</width><height>50%</height></action>
    </keybind>
    <keybind key="W-Down">
      <action name="UnmaximizeFull"/>
      <action name="MoveResizeTo"><x>0</x><y>-0</y><width>100%</width><height>50%</height></action>
    </keybind>
    <keybind key="W-End">
      <action name="UnmaximizeFull"/>
      <action name="MoveResizeTo"><width>25%</width><height>35%</height></action>
    </keybind>
    <keybind key="W-space">
      <action name="Execute"><command>rofi -show drun</command></action>
    </keybind>
EOF
sed -i "/<\/keyboard>/e cat $TEMP_BINDINGS" "$RC_XML"
rm "$TEMP_BINDINGS"

# Openbox Behavior Hardening
sed -i 's/<number>.*<\/number>/<number>1<\/number>/' "$RC_XML"
sed -i 's/<screenEdgeWarpTime>.*<\/screenEdgeWarpTime>/<screenEdgeWarpTime>0<\/screenEdgeWarpTime>/' "$RC_XML"
sed -i 's/<top>0<\/top>/<top>28<\/top>/' "$RC_XML"

echo "--- Phase 4: The Clean Snapper (Mouse Only) ---"
cat <<'EOF' > /usr/local/bin/edge-snapper
#!/bin/bash
T=2
MARGIN=28
while true; do
    eval $(xdotool getmouselocation --shell)
    WIDTH=$(xwininfo -root | grep 'Width' | awk '{print $2}')
    if [ "$X" -le "$T" ] || [ "$X" -ge "$((WIDTH - T))" ]; then
        # Wait for release to prevent snapping back
        while xinput --query-state "$(xinput list --name-only | grep -i 'mouse' | head -n1)" | grep -q "button\[1\]=down"; do
            sleep 0.1
        done
        # Apply snap
        if [ "$X" -le "$T" ]; then
            wmctrl -r :ACTIVE: -b remove,maximized_vert,maximized_horz
            wmctrl -r :ACTIVE: -e 0,0,0,$((WIDTH/2)),-1
        elif [ "$X" -ge "$((WIDTH - T))" ]; then
            wmctrl -r :ACTIVE: -b remove,maximized_vert,maximized_horz
            wmctrl -r :ACTIVE: -e 0,$((WIDTH/2)),0,$((WIDTH/2)),-1
        fi
    fi
    sleep 0.2
done
EOF
chmod +x /usr/local/bin/edge-snapper

echo "--- Phase 5: Autostart ---"
cat <<EOF > "$USER_HOME/.config/openbox/autostart"
/usr/lib/x86_64-linux-gnu/gsd-xsettings &
picom --backend glx --vsync &
nitrogen --restore &
nm-applet &
edge-snapper &
bash "$USER_HOME/.config/openbox/polybar/polybar-ob" &
EOF

chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.config"
echo "--- SUCCESS: Config Restored & Hardened ---"
