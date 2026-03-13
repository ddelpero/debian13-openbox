#!/bin/bash
set -e

# --- Configuration ---
REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")

echo "--- Phase 0: Bootstrapping ---"
apt update
apt install -y curl gpg wget git build-essential

# Phase 1: WezTerm Repository
if [ ! -f "/etc/apt/sources.list.d/wezterm.list" ]; then
    curl -fsSL https://apt.fury.io/wez/gpg.key | gpg --yes --dearmor -o /usr/share/keyrings/packages.wezterm.gpg
    echo 'deb [signed-by=/usr/share/keyrings/packages.wezterm.gpg] https://apt.fury.io/wez/ * *' | tee /etc/apt/sources.list.d/wezterm.list
fi

# Essential Packages
DEBIAN_PKGS="xserver-xorg x11-xserver-utils xinit openbox obconf lightdm lightdm-gtk-greeter geany fastfetch unzip lxappearance nitrogen picom rofi lxterminal arc-theme papirus-icon-theme pipewire pipewire-pulse wireplumber alsa-utils network-manager network-manager-gnome polybar jgmenu gsimplecal xfce4-appfinder xdotool"

echo "--- Phase 2: Core Installation ---"
apt update
apt install -y $DEBIAN_PKGS wezterm

# Min Browser
MIN_FILE="min-1.35.4-amd64.deb"
[ ! -f "$MIN_FILE" ] && wget -O "$MIN_FILE" "https://github.com/minbrowser/min/releases/download/v1.35.4/$MIN_FILE"
apt install -y "./$MIN_FILE"

echo "--- Phase 3: Edge-Snapping Daemon ---"
cat <<'EOF' > /usr/local/bin/edge-snapper
#!/bin/bash
# Edge Snapping for Openbox
T=2
while true; do
    eval $(xdotool getmouselocation --shell)
    WIDTH=$(xwininfo -root | grep 'Width' | awk '{print $2}')

    # Use windowstate to remove maximization before resizing
    if [ "$X" -le "$T" ]; then
        ID=$(xdotool getactivewindow)
        xdotool windowstate --remove MAXIMIZED_VERT,MAXIMIZED_HORZ $ID
        xdotool windowsize $ID 50% 100% windowmove $ID 0 0
        sleep 0.5
    elif [ "$X" -ge "$((WIDTH - T))" ]; then
        ID=$(xdotool getactivewindow)
        xdotool windowstate --remove MAXIMIZED_VERT,MAXIMIZED_HORZ $ID
        xdotool windowsize $ID 50% 100% windowmove $ID 50% 0
        sleep 0.5
    elif [ "$Y" -le "$T" ]; then
        ID=$(xdotool getactivewindow)
        xdotool windowmaximize $ID
        sleep 0.5
    fi
    sleep 0.1
done
EOF
chmod +x /usr/local/bin/edge-snapper

echo "--- Phase 4: Config Deployment ---"
# Create the CORRECT nested structure
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/openbox/polybar"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/jgmenu"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/gtk-3.0"

# Polybar: Deploying YOUR files to .config/openbox/polybar/
if [ -d "./config/polybar" ]; then
    echo "Deploying your Polybar configuration to Openbox directory..."
    cp -r ./config/polybar/. "$USER_HOME/.config/openbox/polybar/"
    [ -f "$USER_HOME/.config/openbox/polybar/polybar-ob" ] && chmod +x "$USER_HOME/.config/openbox/polybar/polybar-ob"
fi

# Openbox rc.xml: Using YOUR exact tiling bindings
RC_XML="$USER_HOME/.config/openbox/rc.xml"
[ ! -f "$RC_XML" ] && cp /etc/xdg/openbox/rc.xml "$RC_XML"

if ! grep -q "window tiling" "$RC_XML"; then
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
EOF
    sed -i "/<\/keyboard>/e cat $TEMP_BINDINGS" "$RC_XML"
    rm "$TEMP_BINDINGS"
fi

# Set Polybar Margin
sed -i 's/<top>0<\/top>/<top>28<\/top>/' "$RC_XML"

echo "--- Phase 5: Final Autostart & Systemd ---"
# Updated to point to the correct Polybar launch path
cat <<EOF > "$USER_HOME/.config/openbox/autostart"
picom &
nitrogen --restore &
nm-applet &
jgmenu_run --pretend &
edge-snapper &
"$USER_HOME/.config/openbox/polybar/polybar-ob" &
EOF

systemctl enable lightdm
systemctl set-default graphical.target

# Permissions Cleanup
chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.config"

echo "--- SUCCESS ---"
