#!/bin/bash
set -e

# --- Configuration ---
REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")

# Verified Debian 13 Packages
DEBIAN_PKGS="xserver-xorg x11-xserver-utils xinit openbox obconf lightdm geany fastfetch git wget curl unzip lxappearance nitrogen picom rofi lxterminal arc-theme papirus-icon-theme pipewire pipewire-pulse wireplumber alsa-utils network-manager network-manager-gnome polybar nodejs npm acpi gobject-introspection liblightdm-gobject-1-0 liblightdm-gobject-dev libgirepository1.0-dev libcairo2 libcairo2-dev libxcb1-dev libx11-dev jgmenu"

echo "--- Phase 1: Pre-Flight Validation ---"
for pkg in $DEBIAN_PKGS; do
    apt-cache show "$pkg" > /dev/null 2>&1 || { echo "ERROR: $pkg not found. Aborting."; exit 1; }
done

# WezTerm Repo
curl -fsSL https://apt.fury.io/wez/gpg.key | gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | tee /etc/apt/sources.list.d/wezterm.list
chmod 644 /usr/share/keyrings/wezterm-fury.gpg

# Min Link
MIN_URL="https://github.com/minbrowser/min/releases/download/v1.35.4/min-1.35.4-amd64.deb"

echo "--- Phase 2: Core Installation ---"
apt update
apt install -y $DEBIAN_PKGS wezterm
wget -O min.deb "$MIN_URL" && apt install -y ./min.deb && rm min.deb

echo "--- Phase 3: Nody-Greeter Build & Desktop File Fix ---"
if [ ! -d "nody-greeter" ]; then
    git clone --recursive https://github.com/JezerM/nody-greeter.git
    cd nody-greeter
    npm install
    npm run rebuild
    npm run build
    node make install

    # Ensure the .desktop file is in the right place for LightDM to see it
    if [ ! -f "/usr/share/xgreeters/nody-greeter.desktop" ]; then
        mkdir -p /usr/share/xgreeters
        cp ./packaging/nody-greeter.desktop /usr/share/xgreeters/ || echo "Manual desktop file copy failed."
    fi
    cd ..
    rm -rf nody-greeter
fi

# Permissions
usermod -a -G video lightdm

echo "--- Phase 4: jgmenu & Configs ---"
mkdir -p "$USER_HOME/.config/jgmenu"
sudo -u $REAL_USER jgmenu_run init

# Setup Aether
mkdir -p /usr/share/nody-greeter/themes/Aether
git clone https://github.com/NoiSek/Aether.git /tmp/Aether
cp -r /tmp/Aether/* /usr/share/nody-greeter/themes/Aether/

# --- Phase 5: SYSTEMD & LIGHTDM FIXES ---
echo "Configuring System Boot and LightDM..."
# Enable LightDM and set boot to Graphical
systemctl enable lightdm
systemctl set-default graphical.target

# Update LightDM config to use Nody
sed -i 's/^#greeter-session=.*/greeter-session=nody-greeter/' /etc/lightdm/lightdm.conf
sed -i 's/^greeter-session=.*/greeter-session=nody-greeter/' /etc/lightdm/lightdm.conf

# Deployment of Polybar & Autostart
if [ -d "./config/polybar" ]; then
    mkdir -p "$USER_HOME/.config/polybar"
    cp ./config/polybar/config.ini "$USER_HOME/.config/polybar/"
    cp ./config/polybar/polybar-ob "$USER_HOME/.config/polybar/"
    chmod +x "$USER_HOME/.config/polybar/polybar-ob"
fi

mkdir -p "$USER_HOME/.config/openbox" "$USER_HOME/.config/gtk-3.0"
echo -e "[Settings]\ngtk-theme-name=Arc-Dark\ngtk-icon-theme-name=Papirus-Dark" > "$USER_HOME/.config/gtk-3.0/settings.ini"

cat <<EOF > "$USER_HOME/.config/openbox/autostart"
picom &
nitrogen --restore &
nm-applet &
jgmenu_run --pretend &
"$USER_HOME/.config/polybar/polybar-ob" &
EOF

chown -R $REAL_USER:$REAL_USER "$USER_HOME/.config"

echo "--- DONE! Run 'sudo reboot' to launch the UI ---"
