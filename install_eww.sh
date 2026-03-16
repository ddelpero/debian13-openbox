#!/bin/bash

# --- CONFIGURATION ---
# Set to "x11" or "wayland" depending on your display server
FEATURE="x11" 
INSTALL_DIR="$HOME/eww"

set -e # Exit on error

echo "--- Phase 1: Installing System Dependencies ---"
sudo apt update
sudo apt install -y \
    libgtk-3-dev \
    libgdk-pixbuf2.0-dev \
    libglib2.0-dev \
    libcairo2-dev \
    libpango1.0-dev \
    libatk1.0-dev \
    libdbusmenu-gtk3-dev \
    libgtk-layer-shell-dev \
    pkg-config \
    git \
    build-essential

echo "--- Phase 2: Installing Rust (via rustup) ---"
if ! command -v cargo &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
else
    echo "Rust is already installed."
fi

echo "--- Phase 3: Cloning Eww Repository ---"
if [ -d "$INSTALL_DIR" ]; then
    echo "Directory $INSTALL_DIR already exists. Pulling latest changes..."
    cd "$INSTALL_DIR"
    git pull
else
    git clone https://github.com/elkowar/eww "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

echo "--- Phase 4: Building Eww ---"
# Build the release binary without default features to specify x11/wayland
cargo build --release --no-default-features --features "$FEATURE"

echo "--- Phase 5: Finalizing Installation ---"
# Move binary to a location in your PATH
sudo install -m 755 "$INSTALL_DIR/target/release/eww" -t /usr/local/bin/

echo "--- SUCCESS ---"
echo "Eww has been installed to /usr/local/bin/eww"
echo "To get started, create your config directory: mkdir -p ~/.config/eww"