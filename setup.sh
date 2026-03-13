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
    curl -fsSL https://apt.fury.io/wez/gpg.key | gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | tee /etc/apt/sources.list.d/wezterm.list
    chmod 644 /usr/share/keyrings/wezterm-fury.gpg
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

echo "--- Phase 3: User Config Deployment ---"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/openbox" "$USER_HOME/.config/jgmenu" "$USER_HOME/.config/polybar" "$USER_HOME/.config/gtk-3.0"

# jgmenu Init
[ ! -f "$USER_HOME/.config/jgmenu/jgmenurc" ] && sudo -u "$REAL_USER" jgmenu_run init

# Polybar: Direct copy of YOUR files
if [ -d "./config/polybar" ]; then
    echo "Deploying your Polybar configuration..."
    cp -r ./config/polybar/. "$USER_HOME/.config/polybar/"
    [ -f "$USER_HOME/.config/polybar/polybar-ob" ] && chmod +x "$USER_HOME/.config/polybar/polybar-ob"
fi

echo "--- Phase 3.5: Building Bunsen-Snapper (Edge-Drag Snapping) ---"
# Install specific dev headers for Bunsen-Snapper
apt install -y libx11-dev libxinerama-dev libxrandr-dev

if [ ! -f "/usr/local/bin/bunsen-snapper" ]; then
    [ -d "bunsen-snapper" ] && rm -rf bunsen-snapper
    git clone https://github.com/wellcorps/bunsen-snapper.git
    cd bunsen-snapper
    # Simple make and install
    make
    cp bunsen-snapper /usr/local/bin/
    chmod +x /usr/local/bin/bunsen-snapper
    cd ..
    rm -rf bunsen-snapper
fi

# Create the configuration for snapper to match your tile preferences
# This ensures dragging to edges behaves like your Super+Arrow keys
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/bunsen-snapper"
cat <<EOF > "$USER_HOME/.config/bunsen-snapper/bunsen-snapper.conf"
# Snapping zones (left, right, top)
# Format: <edge> <width_pct> <height_pct>
left 50 100
right 50 100
top 100 100
EOF

# Add to Openbox Autostart
if ! grep -q "bunsen-snapper" "$USER_HOME/.config/openbox/autostart"; then
    # Insert it before the polybar launch
    sed -i '/polybar-ob/i bunsen-snapper &' "$USER_HOME/.config/openbox/autostart"
fi

# --- Phase 4: Openbox Keybindings (rc.xml) ---
RC_XML="$USER_HOME/.config/openbox/rc.xml"
[ ! -f "$RC_XML" ] && cp /etc/xdg/openbox/rc.xml "$RC_XML"

# Inject YOUR exact tiling bindings
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

# Standard Openbox Margin fix for Polybar
sed -i 's/<top>0<\/top>/<top>28<\/top>/' "$RC_XML"

echo "--- Phase 5: Systemd & Autostart ---"
systemctl enable lightdm
systemctl set-default graphical.target

# Openbox Autostart
cat <<EOF > "$USER_HOME/.config/openbox/autostart"
picom &
nitrogen --restore &
nm-applet &
jgmenu_run --pretend &
"$USER_HOME/.config/polybar/polybar-ob" &
EOF

chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.config"

echo "--- SUCCESS ---"
