#!/bin/bash
set -e

# --- Configuration ---
REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")

# Phase 0: Bootstrap Fetch Tools
echo "--- Phase 0: Bootstrapping ---"
apt update
apt install -y curl gpg wget git build-essential

# Phase 1: WezTerm Repository
if [ ! -f "/etc/apt/sources.list.d/wezterm.list" ]; then
    echo "Adding WezTerm repository..."
    curl -fsSL https://apt.fury.io/wez/gpg.key | gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | tee /etc/apt/sources.list.d/wezterm.list
    chmod 644 /usr/share/keyrings/wezterm-fury.gpg
fi

# Comprehensive Dependencies (Added libx11-dev and libxtst-dev for opensnap)
DEBIAN_PKGS="xserver-xorg x11-xserver-utils xinit openbox obconf lightdm lightdm-gtk-greeter geany fastfetch unzip lxappearance nitrogen picom rofi lxterminal arc-theme papirus-icon-theme pipewire pipewire-pulse wireplumber alsa-utils network-manager network-manager-gnome polybar jgmenu gsimplecal xfce4-appfinder libx11-dev libxtst-dev"

echo "--- Phase 2: Core Installation ---"
apt update
apt install -y $DEBIAN_PKGS wezterm

# Min Browser (Skip if exists)
MIN_FILE="min-1.35.4-amd64.deb"
[ ! -f "$MIN_FILE" ] && wget -O "$MIN_FILE" "https://github.com/minbrowser/min/releases/download/v1.35.4/$MIN_FILE"
apt install -y "./$MIN_FILE"

echo "--- Phase 3: Building Opensnap (Edge Snapping) ---"
if [ ! -f "/usr/local/bin/opensnap" ]; then
    sudo apt-get install build-essential libx11-dev libgtk-3-dev wmctrl
    [ -d "opensnap" ] && rm -rf opensnap
    git clone https://github.com/lawl/opensnap.git
    cd opensnap
    make
    sudo make install
    cp opensnap /usr/local/bin/
    chmod +x /usr/local/bin/opensnap
    cd ..
    rm -rf opensnap
fi

echo "--- Phase 4: User Environment & Permissions ---"
# Create directories AS USER
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/openbox" "$USER_HOME/.config/jgmenu" "$USER_HOME/.config/polybar" "$USER_HOME/.config/gtk-3.0" "$USER_HOME/.config/opensnap"

# Configure Opensnap (Mouse drag triggers)
cat <<EOF > "$USER_HOME/.config/opensnap/left"
0 0 50 100
EOF
cat <<EOF > "$USER_HOME/.config/opensnap/right"
50 0 50 100
EOF
cat <<EOF > "$USER_HOME/.config/opensnap/top"
0 0 100 100
EOF

# jgmenu Init
[ ! -f "$USER_HOME/.config/jgmenu/jgmenurc" ] && sudo -u "$REAL_USER" jgmenu_run init

# Polybar Deployment
if [ -d "./config/polybar" ]; then
    cp -r ./config/polybar/. "$USER_HOME/.config/polybar/"
    # Create launch script matching [bar/example]
    cat <<EOF > "$USER_HOME/.config/polybar/polybar-ob"
#!/bin/bash
killall -q polybar
while pgrep -u \$UID -x polybar >/dev/null; do sleep 1; done
polybar example &
EOF
    chmod +x "$USER_HOME/.config/polybar/polybar-ob"
fi

# --- Phase 5: Openbox Keybindings (rc.xml) ---
RC_XML="$USER_HOME/.config/openbox/rc.xml"
[ ! -f "$RC_XML" ] && cp /etc/xdg/openbox/rc.xml "$RC_XML"

# Inject Window Snapping & Movement Shortcuts
# We use 'W' (Super/Windows key) for all of these
if ! grep -q "Window Movement" "$RC_XML"; then
    TEMP_BINDINGS=$(mktemp)
    cat <<EOF > "$TEMP_BINDINGS"
    <keybind key="W-Left">
      <action name="UnmaximizeFull"/><action name="MaximizeVert"/>
      <action name="MoveResizeTo"><x>0</x><y>0</y><width>50%</width></action>
    </keybind>
    <keybind key="W-Right">
      <action name="UnmaximizeFull"/><action name="MaximizeVert"/>
      <action name="MoveResizeTo"><x>-0</x><y>0</y><width>50%</width></action>
    </keybind>
    <keybind key="W-Up"><action name="Maximize"/></keybind>
    <keybind key="W-Down"><action name="Unmaximize"/></keybind>

    <keybind key="W-S-Left"><action name="MoveRelative"><x>-20</x><y>0</y></action></keybind>
    <keybind key="W-S-Right"><action name="MoveRelative"><x>20</x><y>0</y></action></keybind>
    <keybind key="W-S-Up"><action name="MoveRelative"><x>0</x><y>-20</y></action></keybind>
    <keybind key="W-S-Down"><action name="MoveRelative"><x>0</x><y>20</y></action></keybind>
EOF
    sed -i "/<\/keyboard>/e cat $TEMP_BINDINGS" "$RC_XML"
    rm "$TEMP_BINDINGS"
fi
