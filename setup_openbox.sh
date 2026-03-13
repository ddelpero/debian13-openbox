#!/bin/bash
set -e

# --- Configuration ---
REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")

# Phase 1: WezTerm Repository
if [ ! -f "/etc/apt/sources.list.d/wezterm.list" ]; then
    curl -fsSL https://apt.fury.io/wez/gpg.key | gpg --yes --dearmor -o /usr/share/keyrings/packages.wezterm.gpg
    echo 'deb [signed-by=/usr/share/keyrings/packages.wezterm.gpg] https://apt.fury.io/wez/ * *' | tee /etc/apt/sources.list.d/wezterm.list
fi

echo "--- Phase 1: Package Sync (The Essentials) ---"
apt update
# Replaced gsd-xsettings with xsettingsd (lighter/more reliable for Openbox)
DEBIAN_PKGS="xserver-xorg xinit openbox obconf lightdm lightdm-gtk-greeter nitrogen picom rofi lxterminal arc-theme papirus-icon-theme polybar jgmenu nautilus gnome-sushi arandr x11-xserver-utils dbus-x11 wmctrl xdotool xinput xsettingsd"
apt install -y $DEBIAN_PKGS wezterm

# Min Browser Restore
MIN_FILE="min-1.35.4-amd64.deb"
[ ! -f "$MIN_FILE" ] && wget -O "$MIN_FILE" "https://github.com/minbrowser/min/releases/download/v1.35.4/$MIN_FILE"
apt install -y "./$MIN_FILE"

echo "--- Phase 2: Deploying Configs ---"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/openbox/polybar"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/rofi"

[ -d "./config/polybar" ] && cp -r ./config/polybar/. "$USER_HOME/.config/openbox/polybar/"
[ -d "./config/rofi" ] && cp -r ./config/rofi/. "$USER_HOME/.config/rofi/"
[ -f "$USER_HOME/.config/openbox/polybar/polybar-ob" ] && chmod +x "$USER_HOME/.config/openbox/polybar/polybar-ob"

# Set the GTK Theme for Nautilus via xsettingsd
cat <<EOF > "$USER_HOME/.xsettingsd"
Net/ThemeName "Arc-Dark"
Net/IconThemeName "Papirus-Dark"
Gtk/CursorThemeName "Adwaita"
EOF

echo "--- Phase 3: The 'Aero-Snap' Final Logic ---"
# We add a 'force release' by simulating a mouse-up event to X11 directly
cat <<'EOF' > /usr/local/bin/edge-snapper
#!/bin/bash
T=3
MARGIN=28
while true; do
    eval $(xdotool getmouselocation --shell)
    WIDTH=$(xwininfo -root | grep 'Width' | awk '{print $2}')

    if [ "$X" -le "$T" ] || [ "$X" -ge "$((WIDTH - T))" ]; then
        # Wait for release
        while xinput --query-state "$(xinput list --name-only | grep -i 'mouse' | head -n1)" | grep -q "button\[1\]=down"; do
            sleep 0.05
        done

        # THE FIX: We 'click' the root window to force Openbox to release the window grab
        xdotool click 1

        eval $(xdotool getmouselocation --shell)
        HEIGHT=$(xwininfo -root | grep 'Height' | awk '{print $2}')
        SNAP_HEIGHT=$((HEIGHT - MARGIN))

        if [ "$X" -le "$T" ]; then
            wmctrl -r :ACTIVE: -b remove,maximized_vert,maximized_horz
            wmctrl -r :ACTIVE: -e 0,0,$MARGIN,$((WIDTH/2)),$SNAP_HEIGHT
        elif [ "$X" -ge "$((WIDTH - T))" ]; then
            wmctrl -r :ACTIVE: -b remove,maximized_vert,maximized_horz
            wmctrl -r :ACTIVE: -e 0,$((WIDTH/2)),$MARGIN,$((WIDTH/2)),$SNAP_HEIGHT
        fi
        sleep 0.5
    fi
    sleep 0.1
done
EOF
chmod +x /usr/local/bin/edge-snapper

echo "--- Phase 4: Openbox rc.xml (Restored Shortcuts) ---"
RC_XML="$USER_HOME/.config/openbox/rc.xml"
[ ! -f "$RC_XML" ] && cp /etc/xdg/openbox/rc.xml "$RC_XML"

# Re-injecting your exact CBPP shortcuts
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

# Standard Openbox tuning
sed -i 's/<number>.*<\/number>/<number>1<\/number>/' "$RC_XML"
sed -i 's/<top>0<\/top>/<top>28<\/top>/' "$RC_XML"

echo "--- Phase 5: Autostart ---"
cat <<EOF > "$USER_HOME/.config/openbox/autostart"
xsettingsd &
picom --backend glx --vsync &
nitrogen --restore &
nm-applet &
edge-snapper &
bash "$USER_HOME/.config/openbox/polybar/polybar-ob" &
EOF

chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME"
echo "--- SUCCESS ---"
