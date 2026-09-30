# shellcheck shell=bash
# repositories, packages, locale, groups, services, doas

do_repos() {
    step "Repositories"
    ((SEL[apps])) && put_tree librewolf
    run "sync repository index (network check)" xbps-install -S
    try "update xbps itself" xbps-install -uy xbps
    if ((SEL[hw] && NONFREE || SEL[apps])); then
        if installed void-repo-nonfree; then
            skip "nonfree repo"
        else
            jot pkgs void-repo-nonfree
            run "add the nonfree repo" xbps-install -y void-repo-nonfree
            run "sync the nonfree index" xbps-install -S
        fi
    fi
}

do_update() {
    step "System upgrade"
    run "update the system" xbps-install -Suy
}

do_packages() {
    step "Packages"
    local want=("${PKG_CORE[@]}") new=() old=() auto=() p
    if ((SEL[power])); then
        for p in tlp-rdw tlp; do installed "$p" && old+=("$p"); done
        if ((${#old[@]})); then
            sv_disable tlp
            jot pkgback "${old[*]}"
            run "remove ${old[*]}" xbps-remove -y -- "${old[@]}"
        fi
    fi
    if ((SEL[fonts])); then
        old=()
        for p in "${NERD_FULL[@]}"; do installed "$p" && old+=("$p"); done
        if ((${#old[@]})); then
            jot pkgback "${old[*]}"
            run "remove the full Nerd Fonts set: ${old[*]}" xbps-remove -y -- "${old[@]}"
        fi
    fi
    ((SEL[cli])) && want+=("${PKG_CLI[@]}")
    ((SEL[lsp])) && want+=("${PKG_LSP[@]}")
    ((SEL[harden])) && want+=("${PKG_HARDEN[@]}")
    ((SEL[apparmor])) && want+=("${PKG_APPARMOR[@]}")
    ((SEL[net])) && want+=("${PKG_NET[@]}")
    ((SEL[boot])) && want+=("${PKG_BOOT[@]}")
    ((SEL[desktop])) && want+=("${PKG_DESKTOP[@]}")
    ((SEL[media])) && want+=("${PKG_MEDIA[@]}")
    ((SEL[apps])) && want+=("${PKG_APPS[@]}")
    ((SEL[session])) && want+=("${PKG_SESSION[@]}")
    ((SEL[theme])) && want+=("${PKG_THEME[@]}")
    ((SEL[locale])) && want+=("${PKG_LOCALE[@]}")
    ((SEL[hw])) && want+=("${PKG_HW[@]}" "${HW_PKGS[@]}")
    ((SEL[power])) && want+=("${PKG_POWER[@]}")
    ((SEL[logs])) && want+=("${PKG_LOGS[@]}")
    ((SEL[dirs])) && want+=("${PKG_DIRS[@]}")
    ((SEL[swap])) && want+=("${PKG_SWAP[@]}")
    ((SEL[maint])) && want+=("${PKG_MAINT[@]}")
    ((SEL[maint])) && [[ -f /etc/default/grub ]] && want+=("${PKG_SNAPBOOT[@]}")
    ((SEL[fonts])) && want+=("${PKG_FONTS[@]}")
    ((SEL[doas])) && want+=(opendoas)
    for p in $(printf '%s\n' "${want[@]}" | sort -u); do
        if ! installed "$p"; then
            new+=("$p")
        elif [[ $(xbps-query -p automatic-install "$p") == yes ]]; then
            auto+=("$p")
        fi
    done
    if ((${#auto[@]})); then
        jot pkgauto "${auto[*]}"
        log "manual: ${auto[*]}"
        run "mark ${#auto[@]} packages manual" xbps-pkgdb -m manual "${auto[@]}"
    fi
    if ((${#new[@]} == 0)); then
        skip "all ${#want[@]} packages installed"
        return 0
    fi
    NEW_PKGS=("${new[@]}")
    jot pkgs "${new[*]}"
    log "new: ${new[*]}"
    run "install ${#new[@]} packages" xbps-install -y -- "${new[@]}"
    for p in "${new[@]}"; do
        installed "$p" || die "$p is not installed after xbps-install"
    done
}

do_locale() {
    step "Locale"
    local f=/etc/default/libc-locales
    put_tree locale
    if grep -qE '^en_US\.UTF-8 UTF-8' "$f"; then
        skip "en_US.UTF-8 enabled"
    else
        grep -qE '^#[[:space:]]*en_US\.UTF-8 UTF-8' "$f" || die "en_US.UTF-8 is not listed in $f"
        put_text "$f" 0644 < <(sed -E 's/^#[[:space:]]*(en_US\.UTF-8 UTF-8)/\1/' "$f")
        run "generate locales" xbps-reconfigure -f glibc-locales
    fi
    [[ $(locale -a 2>/dev/null) == *en_US.utf8* ]] || die "en_US.UTF-8 locale not available"
    ok "en_US.UTF-8 available"
}

do_groups() {
    step "Groups"
    local g groups=()
    ((SEL[desktop])) && groups+=("${USER_GROUPS[@]}")
    ((SEL[doas])) && groups+=(wheel)
    ((SEL[session])) && groups+=(bluetooth)
    ((SEL[logs])) && groups+=(socklog)
    ((${#groups[@]})) || return 0
    for g in $(printf '%s\n' "${groups[@]}" | sort -u); do
        getent group "$g" >/dev/null || {
            warn "group $g does not exist"
            continue
        }
        if in_group "$g"; then
            skip "$TUSER in $g"
            continue
        fi
        jot group "$g" "$TUSER"
        gpasswd -a "$TUSER" "$g" >>"$LOG" 2>&1 || die "cannot add $TUSER to $g"
        ok "$TUSER added to $g"
    done
}

do_services() {
    step "Services"
    [[ -d $SVDIR ]] || die "$SVDIR does not exist, is this system running runit?"
    if ((SEL[desktop] || SEL[session] || SEL[power] || SEL[hw] || SEL[media])); then
        sv_enable dbus
    fi
    if ((SEL[desktop])); then
        sv_disable acpid
        sv_enable elogind
        sv_enable polkitd
        [[ -L $SVDIR/seatd ]] && warn "seatd and elogind are both enabled, consider: rm $SVDIR/seatd"
    fi
    ((SEL[harden])) && sv_enable nftables
    ((SEL[session])) && sv_enable bluetoothd
    if ((SEL[power])); then
        sv_disable tlp
        sv_enable power-profiles-daemon
    fi
    ((SEL[swap])) && sv_enable zramen
    ((SEL[maint])) && sv_enable maint
    if ((SEL[logs])); then
        sv_enable socklog-unix
        sv_enable nanoklogd
        save_sysctl "$REPO"/root/watchdog/etc/sysctl.d/*.conf
        sv_refresh watchdog put_tree watchdog
        try "sysctl -p 60-watchdog.conf" sysctl -p /etc/sysctl.d/60-watchdog.conf
        sv_enable watchdog
    fi
    return 0
}

do_post() {
    step "Final settings"
    local i
    if ((SEL[power])); then
        for ((i = 0; i < 15; i++)); do
            powerprofilesctl get >/dev/null 2>&1 && break
            sleep 1
        done
        try "power profile balanced" powerprofilesctl set balanced
    fi
    if ((SEL[hw])); then
        try "fwupd metadata" fwupdmgr refresh --force
    fi
    if ((SEL[swap])); then
        for ((i = 0; i < 10; i++)); do
            grep -q '^/dev/zram' /proc/swaps && break
            sleep 1
        done
        if grep -q '^/dev/zram' /proc/swaps; then ok "zram swap active"; else warn "zram swap not up yet, check 'sv status zramen'"; fi
    fi
    if ((REGEN == 1)); then
        regen_initramfs
    fi
    return 0
}

do_doas() {
    step "doas instead of sudo"
    local doas tmp f
    doas=$(command -v doas) || die "doas not installed"
    [[ $(stat -c %u -- "$doas") == 0 && -u $doas ]] || die "$doas is not setuid root"

    put_text /etc/doas.conf 0400 <<-'EOF'
		permit persist :wheel
	EOF

    tmp=$(mktemp -d)
    install -m 0444 /etc/doas.conf "$tmp/doas.conf"
    chmod 0711 "$tmp"
    if as_user doas -C "$tmp/doas.conf" true >>"$LOG" 2>&1; then
        rm -rf -- "$tmp"
        ok "doas lets $TUSER in"
    else
        rm -rf -- "$tmp"
        die "doas.conf does not let $TUSER in, keeping sudo"
    fi

    if grep -rhsqE '^[[:space:]]*ignorepkg[[:space:]]*=[[:space:]]*sudo[[:space:]]*$' /etc/xbps.d; then
        skip "xbps ignores sudo"
    else
        put_text /etc/xbps.d/90-ignore-sudo.conf 0644 <<-'EOF'
			ignorepkg=sudo
		EOF
    fi

    if installed sudo; then
        jot sudo
        run "remove sudo" xbps-remove -y sudo
    else
        skip "sudo not installed"
    fi
    for f in /etc/sudoers /etc/sudoers.d /etc/sudoers.new-*; do
        [[ -e $f ]] || continue
        backup "$f"
        rm -rf -- "$f"
        ok "removed $f"
    done
    hash -r
    if installed sudo || command -v sudo >/dev/null; then
        die "sudo is still there"
    fi
    ok "sudo is gone"
}

verify() {
    step "Final check"
    local bad=0 c
    if ((SEL[cli])); then
        for c in vim nvim tmux fzf rg; do
            command -v "$c" >/dev/null || {
                warn "$c missing"
                bad=1
            }
        done
        for c in .bashrc:"$BASHRC_LINE" .bash_profile:"$PROFILE_LINE"; do
            cmp -s "$REPO/home/bash/${c%%:*}_dotfile" "$THOME/${c%%:*}_dotfile" && [[ ! -L $THOME/${c%%:*}_dotfile ]] ||
                {
                    warn "~/${c%%:*}_dotfile is not the repo's copy"
                    bad=1
                }
            [[ $(head -n1 -- "$THOME/${c%%:*}" 2>/dev/null) == "${c#*:}" ]] ||
                {
                    warn "~/${c%%:*} does not source ~/${c%%:*}_dotfile in its first line"
                    bad=1
                }
        done
    fi
    if ((SEL[desktop])); then
        g0wm_where >/dev/null || {
            warn "g0wm or start-g0wm missing from $TUSER's PATH"
            bad=1
        }
        [[ -f $THOME/.config/g0wm/settings.json && ! -L $THOME/.config/g0wm/settings.json ]] ||
            {
                warn "g0wm settings not installed"
                bad=1
            }
    fi
    if ((SEL[apps])); then
        for c in librewolf loupe papers showtime soffice pavucontrol gtklock tree thunar xdg-open gtk-launch; do
            command -v "$c" >/dev/null || {
                warn "$c missing"
                bad=1
            }
        done
        [[ -x $THOME/.local/bin/open ]] || {
            warn "~/.local/bin/open missing"
            bad=1
        }
    fi
    if ((SEL[power])); then
        command -v tlp >/dev/null && {
            warn "tlp still installed"
            bad=1
        }
        [[ -L $SVDIR/power-profiles-daemon ]] || {
            warn "power-profiles-daemon not enabled"
            bad=1
        }
    fi
    if ((SEL[swap])); then
        [[ -L $SVDIR/zramen ]] || {
            warn "zramen not enabled"
            bad=1
        }
    fi
    if ((SEL[maint] || SEL[logs])); then
        [[ $(stat -c '%a %U' /usr/local/libexec/as-session-user) == '755 root' ]] || {
            warn "/usr/local/libexec/as-session-user permissions"
            bad=1
        }
    fi
    if ((SEL[maint])); then
        [[ -L $SVDIR/maint ]] || {
            warn "maint not enabled"
            bad=1
        }
        [[ $(stat -c '%a %U' /usr/local/sbin/maint) == '755 root' ]] || {
            warn "/usr/local/sbin/maint permissions"
            bad=1
        }
        [[ $(stat -c %i "$THOME/Private" 2>/dev/null) == 256 ]] || {
            warn "~/Private is not a subvolume"
            bad=1
        }
        [[ $(stat -c %i "$THOME/.cache" 2>/dev/null) == 256 ]] || {
            warn "~/.cache is not a subvolume"
            bad=1
        }
        for c in Games .local/share/Steam; do
            [[ $(stat -c %i "$THOME/$c" 2>/dev/null) == 256 ]] || {
                warn "~/$c is not a subvolume"
                bad=1
            }
        done
        [[ $(stat -c '%a %U' /usr/local/libexec/thumbs-clean) == '755 root' ]] || {
            warn "/usr/local/libexec/thumbs-clean permissions"
            bad=1
        }
        [[ $(stat -c '%a %U' /usr/local/libexec/trash-clean) == '755 root' ]] || {
            warn "/usr/local/libexec/trash-clean permissions"
            bad=1
        }
        [[ $(stat -c '%a %U' /usr/local/bin/snap) == '755 root' ]] || {
            warn "/usr/local/bin/snap permissions"
            bad=1
        }
        [[ $(stat -c '%a %U' /usr/local/bin/forget) == '755 root' ]] || {
            warn "/usr/local/bin/forget permissions"
            bad=1
        }
    fi
    if ((SEL[games])); then
        [[ $(</proc/sys/vm/max_map_count) == 1048576 ]] || {
            warn "vm.max_map_count is not 1048576"
            bad=1
        }
    fi
    if ((SEL[logs])); then
        [[ -L $SVDIR/socklog-unix && -L $SVDIR/nanoklogd ]] || {
            warn "socklog not enabled"
            bad=1
        }
        [[ -L $SVDIR/watchdog ]] || {
            warn "watchdog not enabled"
            bad=1
        }
        [[ -x /usr/local/bin/logs ]] || {
            warn "/usr/local/bin/logs missing"
            bad=1
        }
        [[ $(stat -c '%a %U %G' /var/log/socklog/secure) == '2700 root root' ]] ||
            {
                warn "/var/log/socklog/secure is readable by others"
                bad=1
            }
        grep -qx s4000000 /var/log/socklog/everything/config || {
            warn "socklog keeps the default history"
            bad=1
        }
    fi
    if ((SEL[session])); then
        for c in nm-connection-editor blueman-manager gnome-keyring-daemon; do
            command -v "$c" >/dev/null || {
                warn "$c missing"
                bad=1
            }
        done
        grep -q pam_gnome_keyring /etc/pam.d/login || {
            warn "keyring not in /etc/pam.d/login"
            bad=1
        }
        grep -qx AutoEnable=false /etc/bluetooth/main.conf || {
            warn "bluetooth still turns on at boot"
            bad=1
        }
    fi
    if ((SEL[media])); then
        [[ -f $THOME/.config/xdg-desktop-portal/g0wm-portals.conf ]] || {
            warn "portal config not installed"
            bad=1
        }
    fi
    if ((SEL[harden])); then
        [[ $(stat -c '%a %U' /etc/nftables.conf) == '600 root' ]] || {
            warn "/etc/nftables.conf permissions"
            bad=1
        }
        [[ $(stat -c '%a %U' "$THOME/.ssh") == "700 $TUSER" ]] || {
            warn "~/.ssh permissions"
            bad=1
        }
        [[ -f /etc/modprobe.d/30-harden.conf ]] || {
            warn "modprobe blocklist missing"
            bad=1
        }
        modprobe -n -v hfs 2>/dev/null | grep -q false || {
            warn "modprobe does not block hfs"
            bad=1
        }
    fi
    if ((SEL[boot])) && [[ -f /etc/default/grub && -f /boot/grub/grub.cfg ]] && grub_gfx; then
        grep -qE '^[[:space:]]*set theme=.*/themes/minimal/theme\.txt' /boot/grub/grub.cfg || {
            warn "grub.cfg does not load the minimal theme"
            bad=1
        }
    fi
    if ((SEL[apparmor])); then
        [[ -f /etc/runit/core-services/09-apparmor.sh ]] || {
            warn "AppArmor boot script missing"
            bad=1
        }
        for c in librewolf foot dnscrypt-proxy abstractions/dotfiles/app; do
            [[ -f /etc/apparmor.d/$c ]] || {
                warn "/etc/apparmor.d/$c missing"
                bad=1
            }
        done
        [[ -x /usr/local/libexec/wl-sandbox ]] || {
            warn "/usr/local/libexec/wl-sandbox missing"
            bad=1
        }
        [[ -f $HMALLOC_LIB ]] || {
            warn "$HMALLOC_LIB missing"
            bad=1
        }
        if [[ -f /etc/default/grub && -f /boot/grub/grub.cfg ]]; then
            grep -qE '[[:space:]]lsm=[a-z0-9_,]*apparmor' /boot/grub/grub.cfg || {
                warn "grub.cfg has no lsm= with apparmor"
                bad=1
            }
        fi
    fi
    ((bad == 0)) || die "final check failed"
    ok "all good"
}
