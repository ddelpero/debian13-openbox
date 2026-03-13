#!/bin/bash
set -e

# --- Configuration ---
REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo ./development.sh)"
  exit 1
fi

echo "--- Phase 0: Repositories & Bootstrap ---"
apt update
apt install -y curl gpg wget software-properties-common apt-transport-https

# VS Code Repository
if [ ! -f "/etc/apt/sources.list.d/vscode.list" ]; then
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
fi

# Docker Repository
if [ ! -f "/etc/apt/sources.list.d/docker.list" ]; then
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
fi

echo "--- Phase 1: Native Package Installation ---"
apt update
apt install -y \
    docker-ce docker-ce-cli containerd.io \
    virt-manager qemu-system qemu-utils libvirt-daemon-system libvirt-clients bridge-utils \
    code \
    default-jdk libcanberra-gtk-module libnss3 libasound2

# Add user to groups
usermod -aG docker "$REAL_USER"
usermod -aG libvirt "$REAL_USER"
usermod -aG kvm "$REAL_USER"

echo "--- Phase 2: Manual .deb & Tarball Installs (Pinned Versions) ---"

# 1. Sublime Text 3 (Build 3211 - Final Stable ST3)
ST3_FILE="sublime-text_build-3211_amd64.deb"
if [ ! -f "$ST3_FILE" ]; then
    wget -O "$ST3_FILE" "https://download.sublimetext.com/$ST3_FILE"
fi
apt install -y "./$ST3_FILE"
apt-mark hold sublime-text

# 2. Dropbox (Your Verified 2026.01.15 Link)
DROPBOX_FILE="dropbox_2026.01.15_amd64.deb"
[ ! -f "$DROPBOX_FILE" ] && wget -O "$DROPBOX_FILE" "https://www.dropbox.com/download?dl=packages/ubuntu/$DROPBOX_FILE"
apt install -y "./$DROPBOX_FILE"

# 3. Android Studio (Panda 2 - 2025.3.2.6)
AS_FILE="android-studio-panda2-linux.tar.gz"
AS_URL="https://edgedl.me.gvt1.com/android/studio/ide-zips/2025.3.2.6/$AS_FILE"
AS_DIR="/opt/android-studio"

if [ ! -d "$AS_DIR" ]; then
    [ ! -f "$AS_FILE" ] && wget -O "$AS_FILE" "$AS_URL"
    mkdir -p "$AS_DIR"
    tar -xzf "$AS_FILE" -C /opt/
    ln -sf /opt/android-studio/bin/studio.sh /usr/local/bin/android-studio
fi

# 4. Zed Editor
if ! command -v zed &> /dev/null; then
    sudo -u "$REAL_USER" curl -f https://zed.dev/install.sh | sudo -u "$REAL_USER" sh
fi

# 5. DBeaver CE
DBEAVER_FILE="dbeaver-ce_latest_amd64.deb"
[ ! -f "$DBEAVER_FILE" ] && wget -O "$DBEAVER_FILE" https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb
apt install -y "./$DBEAVER_FILE"

# 6. Joplin
if [ ! -f "$USER_HOME/.joplin/Joplin.AppImage" ]; then
    sudo -u "$REAL_USER" wget -O - https://raw.githubusercontent.com/laurent22/joplin/dev/Joplin_install_and_update.sh | sudo -u "$REAL_USER" bash
fi

echo "--- Phase 3: Desktop Entry for Android Studio ---"
cat <<EOF > /usr/share/applications/android-studio.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Android Studio
Icon=/opt/android-studio/bin/studio.svg
Exec="/opt/android-studio/bin/studio.sh" %f
Comment=Android Studio Panda 2
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-studio
EOF

echo "--- Phase 4: Service Management ---"
systemctl enable docker
systemctl enable libvirtd
systemctl start docker
systemctl start libvirtd

chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME"

echo "--- SUCCESS: Dev environment deployed ---"
