#!/bin/bash
set -e

# --- Configuration ---
REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")

# Phase 0: Bootstrap
echo "--- Phase 0: Bootstrapping Fetch Tools ---"
apt update
apt install -y curl gpg wget

# Phase 1: WezTerm Repo
if [ ! -f "/etc/apt/sources.list.d/wezterm.list" ]; then
    curl -fsSL https://apt.fury.io/wez/gpg.key | gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | tee /etc/apt/sources.list.d/wezterm.list
    chmod 644 /usr/share/keyrings/wezterm-fury.gpg
fi

# Verified Debian 13 Packages (Cleaned up for stability)
DEBIAN_PKGS="xserver-xorg x11-xserver-utils xinit openbox obconf lightdm lightdm-gtk-greeter geany fastfetch unzip lxappearance nitrogen picom rofi lxterminal arc-theme papirus-icon-theme pipewire pipewire-pulse wireplumber alsa-utils network-manager network-manager-gnome polybar jgmenu"

echo "--- Phase 2: Core Installation ---"
apt update
apt install -y $DEBIAN_PKGS wezterm

# Min Browser: Skip download if exists
MIN_FILE="min-1.35.4-amd64.deb"
if [ ! -f "$MIN_FILE" ]; then
    wget -O "$MIN_FILE" "https://github.com/minbrowser/min/releases/download/v1.35.4/$MIN_FILE"
fi
apt install -y "./$MIN_FILE"

echo "--- Phase 3: Systemd & Login Config ---"
systemctl enable lightdm
systemctl set-default graphical.target

# Configure the "Boring" Greeter to use your Dark Theme
cat <<EOF > /etc/lightdm/lightdm-gtk-greeter.conf
[greeter]
theme-name = Arc-Dark
icon-theme-name = Papirus-Dark
background = #2f343f
screensaver-timeout = 60
EOF

# Ensure LightDM points to the GTK greeter
cat <<EOF > /etc/lightdm/lightdm.conf
[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=openbox
EOF

echo "--- Phase 4: User Environment (Strict Permission Handling) ---"
# Create directories AS THE USER to prevent "Permission Denied"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/openbox"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/jgmenu"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/polybar"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/gtk-3.0"

# Initialize jgmenu as the user
if [ ! -f "$USER_HOME/.config/jgmenu/jgmenurc" ]; then
    sudo -u "$REAL_USER" jgmenu_run init
fi

# Polybar Sync
if [ -d "./config/polybar" ]; then
    echo "Deploying Polybar configs..."
    cp -r ./config/polybar/. "$USER_HOME/.config/polybar/"
    chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.config/polybar"
    [ -f "$USER_HOME/.config/polybar/polybar-ob" ] && chmod +x "$USER_HOME/.config/polybar/polybar-ob"
fi

# GTK Settings
echo -e "[Settings]\ngtk-theme-name=Arc-Dark\ngtk-icon-theme-name=Papirus-Dark" > "$USER_HOME/.config/gtk-3.0/settings.ini"

# Openbox Autostart
cat <<EOF > "$USER_HOME/.config/openbox/autostart"
picom &
nitrogen --restore &
nm-applet &
jgmenu_run --pretend &
[ -x "$USER_HOME/.config/polybar/polybar-ob" ] && "$USER_HOME/.config/polybar/polybar-ob" &
EOF

# Final cleanup of home permissions
chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.config"

echo "--- SUCCESS: System is ready ---"
echo "Reboot now. You will see the standard LightDM login themed in Arc-Dark."
