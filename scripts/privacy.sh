#!/bin/bash
set -e

# Check root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

#!/bin/bash
set -e

# Check root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# NetworkManager MAC randomization
echo "[+] Configuring NetworkManager MAC randomization"
mkdir -p /etc/NetworkManager/conf.d
tee /etc/NetworkManager/conf.d/00-mac-randomization.conf > /dev/null <<EOF
[device]
wifi.scan-rand-mac-address=yes
ethernet.cloned-mac-address=random
wifi.cloned-mac-address=random

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
EOF

# Disable Avahi
echo "[+] Disabling Avahi"
systemctl disable --now avahi-daemon || true
systemctl mask avahi-daemon || true

# Install privacy tools
echo "[+] Installing Tor, torsocks, firewall"

if [[ "$DISTRO" == "arch" || "$DISTRO" == "manjaro" ]]; then
    pacman -S --needed --noconfirm tor torsocks firewalld
elif [[ "$DISTRO" == "fedora" || "$DISTRO" == "rhel" || "$DISTRO" == "centos" ]]; then
    dnf install -y tor torsocks firewalld
else
    echo "Unsupported Linux distribution for package installation"
    exit 1
fi

# Enable Tor
systemctl enable --now tor
systemctl is-active --quiet tor && echo "[+] Tor is running"

# Restart NetworkManager
systemctl restart NetworkManager

echo "[+] Done. Reconnect to network to apply new MAC."

# NetworkManager MAC randomization
echo "[+] Configuring NetworkManager MAC randomization"
mkdir -p /etc/NetworkManager/conf.d
tee /etc/NetworkManager/conf.d/00-mac-randomization.conf > /dev/null <<EOF
[device]
wifi.scan-rand-mac-address=yes
ethernet.cloned-mac-address=random
wifi.cloned-mac-address=random

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
EOF

# Disable Avahi
echo "[+] Disabling Avahi"
systemctl disable --now avahi-daemon || true
systemctl mask avahi-daemon || true

# Install privacy tools
echo "[+] Installing Tor, torsocks, firewall"
pacman -S --needed --noconfirm tor torsocks

# Enable Tor
systemctl enable --now tor
systemctl is-active --quiet tor && echo "[+] Tor is running"

# Restart NetworkManager
systemctl restart NetworkManager

echo "[+] Done. Reconnect to network to apply new MAC."
