#!/bin/bash
set -e

# --- Configuration ---
REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")

echo "--- Phase 0: System Sync ---"
apt update
apt install -y curl gpg wget git build-essential wmctrl xdotool xinput libglib2.0-bin x11-utils

# Phase 1: WezTerm Repository
if [ ! -f "/etc/apt/sources.list.d/wezterm.list" ]; then
    curl -fsSL https://apt.fury.io/wez/gpg.key | gpg --yes --dearmor -o /usr/share/keyrings/packages.wezterm.gpg
    echo 'deb [signed-by=/usr/share/keyrings/packages.wezterm.gpg] https://apt.fury.io/wez/ * *' | tee /etc/apt/sources.list.d/wezterm.list
fi

# Essential Packages
DEBIAN_PKGS="xserver-xorg xinit openbox obconf lightdm lightdm-gtk-greeter geany fastfetch nitrogen picom rofi lxterminal arc-theme papirus-icon-theme pipewire pipewire-pulse wireplumber alsa-utils network-manager network-manager-gnome polybar jgmenu nautilus gnome-sushi arandr"

echo "--- Phase 2: Core Installation ---"
apt update
apt install -y $DEBIAN_PKGS wezterm

echo "--- Phase 3: The 'Zero-Desktop' Edge Snapper ---"
cat <<'EOF' > /usr/local/bin/edge-snapper
#!/bin/bash
T=3
MARGIN=28
while true; do
    eval $(xdotool getmouselocation --shell)
    WIDTH=$(xwininfo -root | grep 'Width' | awk '{print $2}')

    if [ "$X" -le "$T" ] || [ "$X" -ge "$((WIDTH - T))" ] || [ "$Y" -le "$T" ]; then
        # Wait for physical button release
        while xinput --query-state "$(xinput list --name-only | grep -i 'mouse' | head -n1)" | grep -q "button\[1\]=down"; do
            sleep 0.05
        done

        # Warp mouse away from edge to force Openbox to drop the window grab
        if [ "$X" -le "$T" ]; then xdotool mousemove_relative 25 0
        elif [ "$X" -ge "$((WIDTH - T))" ]; then xdotool mousemove_relative -- -25 0
        fi

        eval $(xdotool getmouselocation --shell)
        HEIGHT=$(xwininfo -root | grep 'Height' | awk '{print $2}')
        SNAP_HEIGHT=$((HEIGHT - MARGIN))

        if [ "$X" -le "$((T + 30))" ]; then
            # Snap Left: y=MARGIN ensures it's below Polybar
            wmctrl -r :ACTIVE: -b remove,maximized_vert,maximized_horz
            wmctrl -r :ACTIVE: -e 0,0,$MARGIN,$((WIDTH/2)),$SNAP_HEIGHT
        elif [ "$X" -ge "$((WIDTH - T - 30))" ]; then
            # Snap Right
            wmctrl -r :ACTIVE: -b remove,maximized_vert,maximized_horz
            wmctrl -r :ACTIVE: -e 0,$((WIDTH/2)),$MARGIN,$((WIDTH/2)),$SNAP_HEIGHT
        elif [ "$Y" -le "$((T + 5))" ]; then
            # Snap Top (Maximize)
            wmctrl -r :ACTIVE: -b add,maximized_vert,maximized_horz
        fi
        sleep 0.4
    fi
    sleep 0.1
done
EOF
chmod +x /usr/local/bin/edge-snapper

echo "--- Phase 4: Config Deployment ---"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/openbox/polybar" "$USER_HOME/.config/rofi"
[ -d "./config/polybar" ] && cp -r ./config/polybar/. "$USER_HOME/.config/openbox/polybar/"
[ -d "./config/rofi" ] && cp -r ./config/rofi/. "$USER_HOME/.config/rofi/"
[ -f "$USER_HOME/.config/openbox/polybar/polybar-ob" ] && chmod +x "$USER_HOME/.config/openbox/polybar/polybar-ob"

RC_XML="$USER_HOME/.config/openbox/rc.xml"
[ ! -f "$RC_XML" ] && cp /etc/xdg/openbox/rc.xml "$RC_XML"

echo "--- Phase 5: Openbox Hardening ---"
# Disable all virtual desktop switching and edge warping
sed -i 's/<number>.*<\/number>/<number>1<\/number>/' "$RC_XML"
sed -i 's/<wrap>.*<\/wrap>/<wrap>no<\/wrap>/' "$RC_XML"
sed -i 's/<screenEdgeWarpTime>.*<\/screenEdgeWarpTime>/<screenEdgeWarpTime>0<\/screenEdgeWarpTime>/' "$RC_XML"

# GTK Theming for Nautilus
sudo -u "$REAL_USER" gsettings set org.gnome.desktop.interface gtk-theme 'Arc-Dark'
sudo -u "$REAL_USER" gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'

# Clean and Inject Smooth Tiling Bindings
sed -i '/window tiling/I,+45d' "$RC_XML"
TEMP_BINDINGS=$(mktemp)
cat <<EOF > "$TEMP_BINDINGS"
    <keybind key="W-Left">
      <action name="Unmaximize"/><action name="MoveResizeTo"><x>0</x><y>28</y><width>50%</width><height>100%</height></action>
    </keybind>
    <keybind key="W-Right">
      <action name="Unmaximize"/><action name="MoveResizeTo"><x>-0</x><y>28</y><width>50%</width><height>100%</height></action>
    </keybind>
    <keybind key="W-Up">
      <action name="Unmaximize"/><action name="MoveResizeTo"><x>0</x><y>28</y><width>100%</width><height>50%</height></action>
    </keybind>
    <keybind key="W-Down">
      <action name="Unmaximize"/><action name="MoveResizeTo"><x>0</x><y>-0</y><width>100%</width><height>50%</height></action>
    </keybind>
    <keybind key="W-End">
      <action name="MoveResizeTo"><width>25%</width><height>35%</height></action>
    </keybind>
    <keybind key="W-space">
      <action name="Execute"><command>rofi -show drun -show-icons</command></action>
    </keybind>
EOF
sed -i "/<\/keyboard>/e cat $TEMP_BINDINGS" "$RC_XML"
rm "$TEMP_BINDINGS"

# Set Top Margin
sed -i 's/<top>0<\/top>/<top>28<\/top>/' "$RC_XML"

echo "--- Phase 6: Autostart ---"
cat <<EOF > "$USER_HOME/.config/openbox/autostart"
[ -f "$USER_HOME/.screenlayout/monitor.sh" ] && sh "$USER_HOME/.screenlayout/monitor.sh" &
/usr/lib/x86_64-linux-gnu/gsd-xsettings &
picom --backend glx --vsync &
nitrogen --restore &
nm-applet &
edge-snapper &
"$USER_HOME/.config/openbox/polybar/polybar-ob" &
EOF

chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.config"
echo "--- SUCCESS: Single Desktop Environment Deployed ---"
