# shellcheck shell=bash
# repositories, packages, locale, groups, services, doas

do_repos() {
    step "Repositories"
    local codename
    codename=$(. /etc/os-release && echo "${VERSION_CODENAME:-}")
    [[ -n $codename ]] || die "no VERSION_CODENAME in /etc/os-release"
    # microcode, firmware and unrar are in contrib, non-free and non-free-firmware
    put_text "$SOURCES" 0644 <<-EOF
		Types: deb
		URIs: http://deb.debian.org/debian
		Suites: $codename $codename-updates
		Components: $COMPONENTS
		Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

		Types: deb
		URIs: http://security.debian.org/debian-security
		Suites: $codename-security
		Components: $COMPONENTS
		Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
	EOF
    # the lines of the installer, now in debian.sources
    if grep -qE '^[[:space:]]*deb(-src)?[[:space:]].*(debian\.org|/debian(-security)?/?[[:space:]]|cdrom:)' /etc/apt/sources.list 2>/dev/null; then
        put_text /etc/apt/sources.list 0644 < <(
            sed -E 's,^([[:space:]]*deb(-src)?[[:space:]].*(debian\.org|/debian(-security)?/?[[:space:]]|cdrom:)),# \1,' /etc/apt/sources.list
        )
    fi
    # LibreWolf: its own repository, the key is the one Debian's extrepo lists for it
    ((SEL[apps])) && put_tree librewolf
    run "sync repository index (network check)" "${APT[@]}" update
}

do_update() {
    step "System upgrade"
    root_snapshot
    run "update the system" "${APT[@]}" full-upgrade
}

# the same read-only snapshot of / that maint takes before its updates, listed in the GRUB menu
root_snapshot() {
    local dir=/.snapshots snap
    if ! command -v btrfs >/dev/null || [[ $(stat -f -c %T /) != btrfs ]] || ! btrfs subvolume show / >/dev/null 2>&1; then
        skip "/ is not a btrfs subvolume, no snapshot before the upgrade"
        return 0
    fi
    if [[ ! -e $dir && ! -L $dir ]]; then
        run "create $dir" btrfs subvolume create "$dir"
        chmod 0700 "$dir"
    fi
    if [[ -L $dir || ! -d $dir || $(stat -c %u -- "$dir") != 0 ]]; then
        warn "$dir is not a folder owned by root, no snapshot before the upgrade"
        return 0
    fi
    snap=root-$(date +%Y-%m-%d_%H%M)
    if [[ -e $dir/$snap ]]; then
        skip "$dir/$snap"
        return 0
    fi
    run "snapshot of / before the upgrade" btrfs subvolume snapshot -r / "$dir/$snap"
    note "$dir/$snap can be booted from GRUB (Snapshots before updates), maint deletes the old ones"
}

do_packages() {
    step "Packages"
    local want=("${PKG_CORE[@]}") new=() old=() auto=() p showauto
    if ((SEL[power])); then
        for p in tlp-rdw tlp; do installed "$p" && old+=("$p"); done
        if ((${#old[@]})); then
            svc_disable tlp.service
            jot pkgback "${old[*]}"
            run "remove ${old[*]}" "${APT[@]}" remove "${old[@]}"
        fi
    fi
    ((SEL[cli])) && want+=("${PKG_CLI[@]}")
    ((SEL[lsp])) && want+=("${PKG_LSP[@]}")
    ((SEL[harden])) && want+=("${PKG_HARDEN[@]}")
    ((SEL[usb])) && want+=("${PKG_USB[@]}")
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
    ((SEL[fonts])) && want+=("${PKG_FONTS[@]}")
    ((SEL[doas])) && want+=(opendoas)
    showauto=" $(apt-mark showauto | tr '\n' ' ') "
    for p in $(printf '%s\n' "${want[@]}" | sort -u); do
        if ! installed "$p"; then
            new+=("$p")
        elif [[ $showauto == *" $p "* ]]; then
            auto+=("$p")
        fi
    done
    if ((${#auto[@]})); then
        jot pkgauto "${auto[*]}"
        log "manual: ${auto[*]}"
        run "mark ${#auto[@]} packages manual" apt-mark manual "${auto[@]}"
    fi
    if ((${#new[@]} == 0)); then
        skip "all ${#want[@]} packages installed"
        return 0
    fi
    NEW_PKGS=("${new[@]}")
    jot pkgs "${new[*]}"
    log "new: ${new[*]}"
    run "install ${#new[@]} packages" "${APT[@]}" install "${new[@]}"
    for p in "${new[@]}"; do
        installed "$p" || die "$p is not installed after apt-get install"
    done
}

do_locale() {
    step "Locale"
    local f=/etc/locale.gen
    put_tree locale
    if grep -qE '^en_US\.UTF-8 UTF-8' "$f"; then
        skip "en_US.UTF-8 enabled"
    else
        grep -qE '^#[[:space:]]*en_US\.UTF-8 UTF-8' "$f" || die "en_US.UTF-8 is not listed in $f"
        put_text "$f" 0644 < <(sed -E 's/^#[[:space:]]*(en_US\.UTF-8 UTF-8)/\1/' "$f")
        run "generate locales" locale-gen
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
    ((SEL[logs])) && groups+=(systemd-journal)
    ((${#groups[@]})) || return 0
    for g in $(printf '%s\n' "${groups[@]}" | sort -u); do
        # Debian has no wheel: doas and polkit use it here
        if [[ $g == wheel ]] && ! getent group wheel >/dev/null; then
            jot grpdel wheel
            groupadd -r wheel >>"$LOG" 2>&1 || die "cannot create the group wheel"
            ok "group wheel created"
        fi
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
    ((SEL[harden])) && svc_enable nftables.service
    if ((SEL[usb])); then
        svc_enable usbguard.service
        svc_enable usbguard-notify.service
    fi
    ((SEL[session])) && svc_enable bluetooth.service
    if ((SEL[power])); then
        svc_disable tlp.service
        svc_enable power-profiles-daemon.service
    fi
    ((SEL[swap])) && svc_enable earlyoom.service
    ((SEL[maint])) && svc_enable maint.service
    if ((SEL[logs])); then
        save_sysctl "$REPO"/root/watchdog/etc/sysctl.d/*.conf
        svc_refresh watchdog.service put_tree watchdog
        try "sysctl -p 60-watchdog.conf" sysctl -p /etc/sysctl.d/60-watchdog.conf
        svc_enable watchdog.service
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
        if grep -q '^/dev/zram' /proc/swaps; then ok "zram swap active"; else warn "zram swap not up yet, check 'systemctl status systemd-zram-setup@zram0'"; fi
    fi
    ((SEL[usb] == 0)) || usb_up
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

    # no persist: the terminal would stay root after a password
    put_text /etc/doas.conf 0400 <<-'EOF'
		permit :wheel
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

    # admin password prompts of polkit: wheel, not the sudo group of Debian
    put_text /etc/polkit-1/rules.d/30-wheel.rules 0644 <<-'EOF'
		polkit.addAdminRule(function(action, subject) {
		    return ["unix-group:wheel"];
		});
	EOF

    # dpkg refuses when another package needs it, apt would remove that too
    if installed sudo; then
        jot sudo
        run "remove sudo" dpkg --purge sudo
    else
        skip "sudo not installed"
    fi
    # after the removal: a rollback takes the pin away before it installs sudo again
    put_text /etc/apt/preferences.d/90-no-sudo 0644 <<-'EOF'
		Package: sudo sudo-ldap sudo-rs
		Pin: release *
		Pin-Priority: -1
	EOF
    for f in /etc/sudoers /etc/sudoers.d /etc/sudoers.dpkg-*; do
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
        for c in vim nvim tmux fzf rg fd bat; do
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
        [[ -f $WLR_PREFIX/lib/libwlroots-0.20.so ]] || {
            warn "wlroots 0.20 missing from $WLR_PREFIX"
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
        systemctl -q is-enabled power-profiles-daemon.service || {
            warn "power-profiles-daemon not enabled"
            bad=1
        }
    fi
    if ((SEL[swap])); then
        [[ -f /etc/systemd/zram-generator.conf ]] || {
            warn "zram-generator not configured"
            bad=1
        }
        systemctl -q is-enabled earlyoom.service || {
            warn "earlyoom not enabled"
            bad=1
        }
        [[ $(stat -c '%a %U' /usr/local/libexec/earlyoom-closed) == '755 root' ]] || {
            warn "/usr/local/libexec/earlyoom-closed permissions"
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
        systemctl -q is-enabled maint.service || {
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
    if ((SEL[usb])); then
        systemctl -q is-enabled usbguard.service && systemctl -q is-enabled usbguard-notify.service || {
            warn "usbguard or usbguard-notify not enabled"
            bad=1
        }
        [[ $(stat -c '%a %U' /usr/local/bin/usb) == '755 root' ]] || {
            warn "/usr/local/bin/usb permissions"
            bad=1
        }
        for c in /etc/usbguard/rules.conf /etc/usbguard/usbguard-daemon.conf; do
            [[ $(stat -c '%a %U' "$c") == '600 root' ]] || {
                warn "$c permissions, usbguard refuses it"
                bad=1
            }
        done
    fi
    if ((SEL[games])); then
        [[ $(</proc/sys/vm/max_map_count) == 1048576 ]] || {
            warn "vm.max_map_count is not 1048576"
            bad=1
        }
    fi
    if ((SEL[logs])); then
        systemctl -q is-enabled watchdog.service || {
            warn "watchdog not enabled"
            bad=1
        }
        [[ $(</proc/sys/kernel/panic) == 10 && $(</proc/sys/kernel/panic_on_oops) == 1 ]] || {
            warn "the kernel does not reboot after a panic"
            bad=1
        }
        [[ -x /usr/local/bin/logs ]] || {
            warn "/usr/local/bin/logs missing"
            bad=1
        }
        [[ $(systemd-analyze cat-config systemd/journald.conf 2>/dev/null | grep -E '^Storage=' | tail -n1) == Storage=persistent ]] || {
            warn "the journal is not kept on disk"
            bad=1
        }
        [[ ! -d /sys/firmware/efi ]] || systemctl -q is-enabled systemd-pstore.service || {
            warn "systemd-pstore not enabled: a kernel panic leaves no log"
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
        grep -qx Privacy=device /etc/bluetooth/main.conf || {
            warn "bluetooth uses the fixed address of the card"
            bad=1
        }
    fi
    if ((SEL[media])); then
        [[ -f $THOME/.config/xdg-desktop-portal/g0wm-portals.conf ]] || {
            warn "portal config not installed"
            bad=1
        }
    fi
    if ((SEL[hw])); then
        ! grep -qs '^ReportURI=.' /etc/fwupd/remotes.d/*.conf || {
            warn "fwupd can still send reports"
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

usb_up() {
    local i bad
    for ((i = 0; i < 15; i++)); do
        usbguard list-rules >/dev/null 2>&1 && systemctl -q is-active usbguard-notify.service && break
        sleep 1
    done
    usbguard list-rules >/dev/null 2>&1 || die "usbguard did not start, see 'logs service usbguard'"
    ok "usbguard running"
    systemctl -q is-active usbguard-notify.service ||
        warn "usbguard-notify is not running, nothing asks about new devices: 'logs service usbguard-notify'"
    ((USB_NEW)) || return 0
    bad=$(usbguard list-devices -b | grep -E ' with-interface .*03:01:0[12]' |
        sed -n 's/.* name "\([^"]*\)".*/\1/p' | paste -sd, -) || true
    [[ -z $bad ]] || die "usbguard blocked $bad, a keyboard or mouse plugged in after the rules were made: run this again with it plugged in"
}
