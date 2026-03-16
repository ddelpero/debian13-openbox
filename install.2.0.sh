
su -
apt install -y sudo git xfce4 xfce4-goodies

# This finds the username for UID 1000 and adds them to sudo
usermod -aG sudo $(id -un 1000)

sudo apt install cryptsetup-initramfs
sudo update-initramfs -u

git clone https://github.com/leomarcov/debian-openbox.git
cd debian-openbox/30_script_loginfetch
sudo ./install