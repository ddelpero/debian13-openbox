#!/bin/bash
set -e

# --- Configuration ---
REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")

echo "--- Phase 0: System Sync ---"
apt update
apt install -y curl gpg wget git build-essential wmctrl xdotool xinput libglib2.0-bin x11-utils dbus-x11

# Phase 1: WezTerm Repository
if [ ! -f "/etc/apt/sources.list.d/wezterm.list" ]; then
    curl -fsSL https://apt.fury.io/wez/gpg.key | gpg --yes --dearmor -o /usr/share/keyrings/packages.wezterm.gpg
    echo 'deb [signed-by=/usr/share/keyrings/packages.wezterm.gpg] https://apt.fury.io/wez/ * *' | tee /etc/apt/sources.list.d/wezterm.list
fi

# Essential Packages
DEBIAN_PKGS="xserver-xorg xinit openbox obconf lightdm lightdm-gtk-greeter geany fastfetch nitrogen picom rofi lxterminal arc-theme papirus-icon-theme pipewire pipewire-pulse wireplumber alsa-utils network-manager network-manager-gnome polybar jgmenu nautilus gnome-sushi arandr lxappearance"

echo "--- Phase 2: Core Installation ---"
apt update
apt install -y $DEBIAN_PKGS wezterm

# Min Browser
MIN_FILE="min-1.35.4-amd64.deb"
[ ! -f "$MIN_FILE" ] && wget -O "$MIN_FILE" "https://github.com/minbrowser/min/releases/download/v1.35.4/$MIN_FILE"
apt install -y "./$MIN_FILE"

echo "--- Phase 3: Config Deployment ---"
# Strictly using .config/openbox/polybar/ as requested
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/openbox/polybar"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/rofi"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/jgmenu"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/gtk-3.0"

# Deploy YOUR configs
[ -d "./config/polybar" ] && cp -r ./config/polybar/. "$USER_HOME/.config/openbox/polybar/"
[ -d "./config/rofi" ] && cp -r ./config/rofi/. "$USER_HOME/.config/rofi/"
[ -f "$USER_HOME/.config/openbox/polybar/polybar-ob" ] && chmod +x "$USER_HOME/.config/openbox/polybar/polybar-ob"

# Deploy rc.xml before we try to sed it
RC_XML="$USER_HOME/.config/openbox/rc.xml"
if [ ! -f "$RC_XML" ]; then
    sudo -u "$REAL_USER" cp /etc/xdg/openbox/rc.xml "$RC_XML"
fi

echo "--- Phase 4: GTK Theming (The Manual Way) ---"
# GTK2
cat <<EOF > "$USER_HOME/.gtkrc-2.0"
gtk-theme-name="Arc-Dark"
gtk-icon-theme-name="Papirus-Dark"
EOF

# GTK3
cat <<EOF > "$USER_HOME/.config/gtk-3.0/settings.ini"
[Settings]
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-application-prefer-dark-theme=1
EOF

echo "--- Phase 5: Openbox Hardening ---"
# Single Desktop, No Edge Warping
sed -i 's/<number>.*<\/number>/<number>1<\/number>/' "$RC_XML"
sed -i 's/<screenEdgeWarpTime>.*<\/screenEdgeWarpTime>/<screenEdgeWarpTime>0<\/screenEdgeWarpTime>/' "$RC_XML"
sed -i 's/<top>0<\/top>/<top>28<\/top>/' "$RC_XML"

# Inject Smooth Tiling Bindings (Your exact cbpp style)
sed -i '/window tiling/I,+45d' "$RC_XML"
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

echo "--- Phase 6: Autostart ---"
cat <<EOF > "$USER_HOME/.config/openbox/autostart"
# Monitor Setup
[ -f "$USER_HOME/.screenlayout/monitor.sh" ] && sh "$USER_HOME/.screenlayout/monitor.sh" &

# Theming Environment Variable (Best for Nautilus GTK4)
export GTK_THEME=Arc-Dark

# Background Services
picom --backend glx --vsync &
nitrogen --restore &
nm-applet &
bash "$USER_HOME/.config/openbox/polybar/polybar-ob" &
EOF

chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.config" "$USER_HOME/.gtkrc-2.0"
echo "--- SUCCESS ---"
