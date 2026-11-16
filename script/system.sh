# shellcheck shell=bash
# repositories, packages, locale, groups, services, doas

do_repos() {
    step "Repositories"
    local codename
    codename=$(. /etc/os-release && echo "${VERSION_CODENAME:-}")
    [[ -n $codename ]] || die "no VERSION_CODENAME in /etc/os-release"
    # microcode, firmware and unrar are in contrib, non-free and non-free-firmware
    # https needs the certificates, the installer's list can bring them
    if ! installed ca-certificates; then
        run "sync repository index" "${APT[@]}" update
        jot pkgs ca-certificates
        run "install ca-certificates, for https" "${APT[@]}" install ca-certificates
    fi
    put_tree apt
    put_text "$SOURCES" 0644 <<-EOF
		Types: deb
		URIs: https://deb.debian.org/debian
		Suites: $codename $codename-updates
		Components: $COMPONENTS
		Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

		Types: deb
		URIs: https://security.debian.org/debian-security
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
    local want=("${PKG_CORE[@]}") new=() old=() auto=() p k showauto
    if ((SEL[power])); then
        for p in tlp-rdw tlp; do installed "$p" && old+=("$p"); done
        if ((${#old[@]})); then
            svc_disable tlp.service
            jot pkgback "${old[*]}"
            run "remove ${old[*]}" "${APT[@]}" remove "${old[@]}"
        fi
    fi
    for k in "${SECTIONS[@]}"; do
        ((SEL[$k])) || continue
        p="PKG_${k^^}[@]"
        want+=("${!p}")
    done
    ((SEL[hw])) && want+=("${HW_PKGS[@]}")
    ((SEL[maint])) && [[ -f /etc/default/grub ]] && want+=("${PKG_SNAPBOOT[@]}")
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
    # debsecan: no daily mail to root, maint checks it weekly
    if [[ " ${new[*]} " == *" debsecan "* ]]; then
        debconf-set-selections <<<'debsecan debsecan/report boolean false' >>"$LOG" 2>&1 ||
            die "debconf-set-selections failed for debsecan"
    fi
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

# the final state, past what put, run and svc_enable already made sure of:
# warn MESSAGE when the rest of the arguments, run as a command, fails
expect() {
    "${@:2}" </dev/null >/dev/null 2>&1 || {
        warn "$1"
        VERIFY_BAD=1
    }
}
sysctl_is() { [[ $(<"/proc/sys/$1") == "$2" ]]; }
subvol() { [[ $(stat -c %i -- "$1" 2>/dev/null) == 256 ]]; }
first_line() { [[ $(head -n1 -- "$1" 2>/dev/null) == "$2" ]]; }
journal_on_disk() { [[ $(systemd-analyze cat-config systemd/journald.conf | grep -E '^Storage=' | tail -n1) == Storage=persistent ]]; }
login_draws() { TERM=linux G0WM_LOGIN_CAT=${2:-} sh /usr/local/libexec/g0wm-login "$1"; }
not() { ! "$@"; }

verify() {
    step "Final check"
    local u c
    VERIFY_BAD=0
    for u in "${ENABLED[@]}"; do expect "$u is not enabled" systemctl -q is-enabled -- "$u"; done
    if ((SEL[cli])); then
        expect "~/.bashrc does not source ~/.bashrc_dotfile in its first line" first_line "$THOME/.bashrc" "$BASHRC_LINE"
        expect "~/.bash_profile does not source ~/.bash_profile_dotfile in its first line" \
            first_line "$THOME/.bash_profile" "$PROFILE_LINE"
    fi
    if ((SEL[desktop])); then
        expect "g0wm or start-g0wm missing from $TUSER's PATH" g0wm_where
        expect "wlroots 0.20 missing from $WLR_PREFIX" test -f "$WLR_PREFIX/lib/libwlroots-0.20.so"
    fi
    if ((SEL[maint])); then
        for c in Private .cache Games .local/share/Steam; do expect "~/$c is not a subvolume" subvol "$THOME/$c"; done
    fi
    ((SEL[games] == 0)) || expect "vm.max_map_count is not 1048576" sysctl_is vm/max_map_count 1048576
    if ((SEL[logs])); then
        expect "the kernel does not reboot after a panic" sysctl_is kernel/panic 10
        expect "the kernel does not reboot after an oops" sysctl_is kernel/panic_on_oops 1
        expect "the journal is not kept on disk" journal_on_disk
    fi
    if ((SEL[session])); then
        for c in login common-password; do expect "keyring not in /etc/pam.d/$c" grep -q pam_gnome_keyring "/etc/pam.d/$c"; done
        expect "bluetooth still turns on at boot" grep -qx AutoEnable=false /etc/bluetooth/main.conf
        expect "bluetooth uses the fixed address of the card" grep -qx Privacy=device /etc/bluetooth/main.conf
    fi
    ((SEL[hw] == 0)) || expect "fwupd can still send reports" not grep -qs '^ReportURI=.' /etc/fwupd/remotes.d/*.conf
    ((SEL[harden] == 0)) || expect "modprobe does not block hfs" grep -q false <(modprobe -n -v hfs 2>/dev/null)
    if ((SEL[boot])); then
        # agetty on tty1 runs it as root: a broken one leaves tty1 without a login
        expect "g0wm-login does not draw: tty1 has no login, use tty2" login_draws --preview
        expect "g0wm-login --starting does not draw: a blank screen until g0wm" login_draws --starting
        for c in awake grumpy; do expect "g0wm-login does not draw the $c dog" login_draws --preview "$c"; done
        expect "login.defs: LOGIN_RETRIES is not 1, a wrong password breaks the tty1 screen" \
            grep -qE '^LOGIN_RETRIES[[:space:]]+1$' /etc/login.defs
        expect "common-auth has no pam_faillock: no lock out, no \"Login incorrect\" on tty1" faillock_on /etc/pam.d/common-auth
        expect "faillock.conf: deny is not 5" grep -qE '^deny = 5$' /etc/security/faillock.conf
        if [[ -f /etc/default/grub && -f /boot/grub/grub.cfg ]] && grub_gfx; then
            expect "grub.cfg does not load the minimal theme" \
                grep -qE '^[[:space:]]*set theme=.*/themes/minimal/theme\.txt' /boot/grub/grub.cfg
        fi
    fi
    if ((SEL[apparmor])); then
        expect "/usr/local/libexec/wl-sandbox missing" test -x /usr/local/libexec/wl-sandbox
        expect "$HMALLOC_LIB missing" test -f "$HMALLOC_LIB"
        if [[ -f /etc/default/grub && -f /boot/grub/grub.cfg ]]; then
            expect "grub.cfg has no lsm= with apparmor" grep -qE '[[:space:]]lsm=[a-z0-9_,]*apparmor' /boot/grub/grub.cfg
        fi
    fi
    ((VERIFY_BAD == 0)) || die "final check failed"
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
