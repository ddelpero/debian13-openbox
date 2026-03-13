#!/bin/bash
set -e

# --- Configuration ---
REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")

echo "--- Phase 0: Cleanup & Setup ---"
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

echo "--- Phase 3: Edge-Snapping Daemon with Preview ---"
cat <<'EOF' > /usr/local/bin/edge-snapper
#!/bin/bash
T=3
MARGIN=28
while true; do
    eval $(xdotool getmouselocation --shell)
    WIDTH=$(xwininfo -root | grep 'Width' | awk '{print $2}')

    if [ "$X" -le "$T" ] || [ "$X" -ge "$((WIDTH - T))" ] || [ "$Y" -le "$T" ]; then
        # GNOME-style Preview: We change the border color or flash a hint
        # For a minimal setup, we can use xsetroot to flash the background
        # or just wait for the release to finalize.

        while xinput --query-state "$(xinput list --name-only | grep -i 'mouse' | head -n1)" | grep -q "button\[1\]=down"; do
            # Visual Feedback: You could add a small transparent overlay here
            sleep 0.05
        done

        eval $(xdotool getmouselocation --shell)
        HEIGHT=$(xwininfo -root | grep 'Height' | awk '{print $2}')
        SNAP_HEIGHT=$((HEIGHT - MARGIN))

        if [ "$X" -le "$T" ]; then
            wmctrl -r :ACTIVE: -b remove,maximized_vert,maximized_horz
            wmctrl -r :ACTIVE: -e 0,0,$MARGIN,$((WIDTH/2)),$SNAP_HEIGHT
        elif [ "$X" -ge "$((WIDTH - T))" ]; then
            wmctrl -r :ACTIVE: -b remove,maximized_vert,maximized_horz
            wmctrl -r :ACTIVE: -e 0,$((WIDTH/2)),$MARGIN,$((WIDTH/2)),$SNAP_HEIGHT
        elif [ "$Y" -le "$T" ]; then
            wmctrl -r :ACTIVE: -b add,maximized_vert,maximized_horz
        fi
        sleep 0.5
    fi
    sleep 0.1
done
EOF
chmod +x /usr/local/bin/edge-snapper

echo "--- Phase 4: File Deployment ---"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/openbox/polybar"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/rofi"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/jgmenu"

[ -d "./config/polybar" ] && cp -r ./config/polybar/. "$USER_HOME/.config/openbox/polybar/"
[ -d "./config/rofi" ] && cp -r ./config/rofi/. "$USER_HOME/.config/rofi/"
[ -f "$USER_HOME/.config/openbox/polybar/polybar-ob" ] && chmod +x "$USER_HOME/.config/openbox/polybar/polybar-ob"

RC_XML="$USER_HOME/.config/openbox/rc.xml"
if [ ! -f "$RC_XML" ]; then
    cp /etc/xdg/openbox/rc.xml "$RC_XML"
fi

echo "--- Phase 5: Configuration Tweaks ---"
# Nautilus Theming
sudo -u "$REAL_USER" gsettings set org.gnome.desktop.interface gtk-theme 'Arc-Dark'
sudo -u "$REAL_USER" gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'

# Keybindings
sed -i '/window tiling/I,+40d' "$RC_XML"
TEMP_BINDINGS=$(mktemp)
cat <<EOF > "$TEMP_BINDINGS"
    <keybind key="W-Left">
      <action name="Unmaximize"/><action name="MoveResizeTo"><x>0</x><y>0</y><width>50%</width><height>100%</height></action>
    </keybind>
    <keybind key="W-Right">
      <action name="Unmaximize"/><action name="MoveResizeTo"><x>-0</x><y>0</y><width>50%</width><height>100%</height></action>
    </keybind>
    <keybind key="W-Up">
      <action name="Unmaximize"/><action name="MoveResizeTo"><x>0</x><y>0</y><width>100%</width><height>50%</height></action>
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

# Margin for Polybar
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
echo "--- SUCCESS ---"
