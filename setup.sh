#!/bin/bash
set -e

# --- Configuration ---
REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")

# Phase 0: Bootstrap
echo "--- Phase 0: Bootstrapping ---"
apt update
apt install -y curl gpg wget

# Phase 1: WezTerm Repo
if [ ! -f "/etc/apt/sources.list.d/wezterm.list" ]; then
    curl -fsSL https://apt.fury.io/wez/gpg.key | gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | tee /etc/apt/sources.list.d/wezterm.list
    chmod 644 /usr/share/keyrings/wezterm-fury.gpg
fi

# DEBIAN_PKGS: Added gsimplecal and xfce4-appfinder (used in your config)
DEBIAN_PKGS="xserver-xorg x11-xserver-utils xinit openbox obconf lightdm lightdm-gtk-greeter geany fastfetch unzip lxappearance nitrogen picom rofi lxterminal arc-theme papirus-icon-theme pipewire pipewire-pulse wireplumber alsa-utils network-manager network-manager-gnome polybar jgmenu gsimplecal xfce4-appfinder"

echo "--- Phase 2: Core Installation ---"
apt update
apt install -y $DEBIAN_PKGS wezterm

# Min Browser
MIN_FILE="min-1.35.4-amd64.deb"
[ ! -f "$MIN_FILE" ] && wget -O "$MIN_FILE" "https://github.com/minbrowser/min/releases/download/v1.35.4/$MIN_FILE"
apt install -y "./$MIN_FILE"

# Phase 2.5: Install Nerd Fonts (Required by your Polybar Config)
echo "--- Phase 2.5: Installing Nerd Fonts ---"
FONT_DIR="$USER_HOME/.local/share/fonts"
sudo -u "$REAL_USER" mkdir -p "$FONT_DIR"
if [ ! -f "$FONT_DIR/JetBrainsMonoNerdFont-Medium.ttf" ]; then
    wget -P /tmp/ https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/JetBrainsMono.zip
    unzip -o /tmp/JetBrainsMono.zip -d "$FONT_DIR"
    rm /tmp/JetBrainsMono.zip
    sudo -u "$REAL_USER" fc-cache -f
fi

echo "--- Phase 3: Systemd & Login ---"
systemctl enable lightdm
systemctl set-default graphical.target

# Greeter Config
cat <<EOF > /etc/lightdm/lightdm-gtk-greeter.conf
[greeter]
theme-name = Arc-Dark
icon-theme-name = Papirus-Dark
background = #2f343f
EOF

echo "--- Phase 4: User Environment ---"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/openbox" "$USER_HOME/.config/jgmenu" "$USER_HOME/.config/polybar" "$USER_HOME/.config/gtk-3.0"

# Polybar Config Deployment
if [ -d "./config/polybar" ]; then
    cp -r ./config/polybar/. "$USER_HOME/.config/polybar/"
fi

# Create the Polybar Launch Script (matching your [bar/example])
cat <<EOF > "$USER_HOME/.config/polybar/polybar-ob"
#!/bin/bash
killall -q polybar
while pgrep -u \$UID -x polybar >/dev/null; do sleep 1; done
polybar example > "$USER_HOME/polybar.log" 2>&1 &
EOF
chmod +x "$USER_HOME/.config/polybar/polybar-ob"

# GTK Settings
echo -e "[Settings]\ngtk-theme-name=Arc-Dark\ngtk-icon-theme-name=Papirus-Dark" > "$USER_HOME/.config/gtk-3.0/settings.ini"

# Openbox Autostart
cat <<EOF > "$USER_HOME/.config/openbox/autostart"
picom &
nitrogen --restore &
nm-applet &
jgmenu_run --pretend &
"$USER_HOME/.config/polybar/polybar-ob" &
EOF

chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.config"
echo "--- SUCCESS: Reboot and your bar should appear ---"
