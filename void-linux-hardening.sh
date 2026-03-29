#!/usr/bin/env bash
set -e

SYSCTL_CONF="/etc/sysctl.d/99-custom-hardening.conf"
DOAS_CONF="/etc/doas.conf"
XBPS_IGNORE_CONF="/etc/xbps.d/ignore.conf"
NM_MAC_RANDOMIZE_CONF="/etc/NetworkManager/conf.d/00-macrandomize.conf"

log_info()      { echo -e "[\e[34m*\e[0m] $1"; }
log_success()   { echo -e "[\e[32m+\e[0m] $1"; }
log_error()     { echo -e "[\e[31m!\e[0m] $1" >&2; }

require_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        log_error "Root privileges are required to run this script."
        exit 1
    fi
}

require_void() {
    if ! grep -q "Void" /etc/os-release; then
        log_error "This script is designed for Void Linux."
        exit 1
    fi
}

require_connection() {
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_error "Internet required to run this script"
        exit 1
    fi
}

install_package() {
    local package="$1"

    if xbps-query -S "$package" >/dev/null 2>&1; then
        log_info "$package already installed."
    else
        log_info "Installing $package..."
        if ! xbps-install -y "$package" >/dev/null; then
            log_error "Failed to install $package"
            exit 1
        fi
        log_success "$package installed successfully."
    fi
}

init_system() {
    log_info "Updating system packages..."
    xbps-install -Suvy >/dev/null
}

apply_sysctl_patches() {
    log_info "Applying system hardening patches..."

    sysctl -w kernel.randomize_va_space=2 >/dev/null
    sysctl -w net.ipv4.ip_forward=0 >/dev/null
    sysctl -w net.ipv6.conf.all.forwarding=0 >/dev/null
    sysctl -w net.ipv4.tcp_syncookies=1 >/dev/null
    sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=1 >/dev/null

    mkdir -p "$(dirname "$SYSCTL_CONF")"

    cat > "$SYSCTL_CONF" << 'EOF'
kernel.randomize_va_space=2
net.ipv4.ip_forward=0
net.ipv6.conf.all.forwarding=0
net.ipv4.tcp_syncookies=1
net.ipv4.icmp_echo_ignore_broadcasts=1
EOF

    sysctl --system >/dev/null
    log_success "Patches applied and made permanent."
}

setup_ufw() {
    log_info "Configuring UFW..."

    install_package ufw
    install_package gufw

    ufw disable >/dev/null
    yes | ufw reset >/dev/null

    ufw default deny incoming >/dev/null
    ufw default allow outgoing >/dev/null

    ufw allow 53/tcp >/dev/null
    ufw allow 53/udp >/dev/null
    ufw allow 67:68/udp >/dev/null

    if ! ufw status | grep -q "Status: active"; then
        log_info "Enabling UFW..."
        ufw --force enable >/dev/null
    fi

    ufw logging low >/dev/null
    log_success "UFW firewall configured and active."
}

configure_network() {
    log_info "Configuring MAC randomization in NetworkManager..."
    mkdir -p "$(dirname "$NM_MAC_RANDOMIZE_CONF")"

    cat > "$NM_MAC_RANDOMIZE_CONF" << 'EOF'
[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
EOF
    log_success "MAC randomization configured."
}

replace_sudo_with_doas() {
    log_info "Installing and configuring doas..."
    install_package opendoas

    if [[ -f "$DOAS_CONF" ]]; then
        cp "$DOAS_CONF" "${DOAS_CONF}.bak"
    fi

    cat > "$DOAS_CONF" << 'EOF'
permit :wheel
EOF

    if ! doas -C "$DOAS_CONF"; then
        log_error "Configuration error in doas.conf"
        exit 1
    fi

    chown root:root "$DOAS_CONF"
    chmod 0400 "$DOAS_CONF"
    log_success "Doas installed and configured."


    if xbps-query -S sudo >/dev/null 2>&1; then
        mkdir -p "$(dirname "$XBPS_IGNORE_CONF")"
        cat > "$XBPS_IGNORE_CONF" << 'EOF'
ignorepkg=sudo
EOF

        xbps-remove -y sudo
        log_success "Sudo successfully removed."
    else
        log_info "Sudo is not installed, skipping removal."
    fi
}

app_armor() {
    if apparmor_status >/dev/null; then
        log_info "apparmor already enabled"       
    else
        install_package apparmor
        log_info "Add parameter 'apparmor=1 security=apparmor' to '/etc/default/grub' at section 'GRUB_CMDLINE_LINUX_DEFAULT'. Then type 'update-grub' and restart"
    fi
}

main() {
    require_root
    require_void
    require_connection

    init_system
    apply_sysctl_patches
    setup_ufw
    configure_network
    replace_sudo_with_doas
    app_armor
}

main
