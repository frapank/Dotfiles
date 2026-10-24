# shellcheck shell=bash
# boot, grub, initramfs, hardware

# Debian's drop-ins: /etc/default/grub stays the package's and the installer's,
# GRUB_CMDLINE_LINUX_DEFAULT leaves the recovery entry without them
grub_words() {
    local f=$GRUB_D/40_debian-postinstall.cfg base have w add=() stale=0
    if [[ ! -f /etc/default/grub ]]; then
        warn "no /etc/default/grub: add '$*' to the kernel command line yourself"
        return 0
    fi
    base=$(grep -hE '^GRUB_CMDLINE_LINUX(_DEFAULT)?=' /etc/default/grub || true)
    have=$(sed -n 's/^GRUB_CMDLINE_LINUX_DEFAULT="\$GRUB_CMDLINE_LINUX_DEFAULT \(.*\)"$/\1/p' "$f" 2>/dev/null || true)
    for w in "$@"; do
        grep -qsF -- "$w" /boot/grub/grub.cfg || stale=1
        [[ " $have " == *" $w "* || " $base " =~ [\"\'[:space:]]"$w"[\"\'[:space:]] ]] && continue
        add+=("$w")
        have="${have:+$have }$w"
    done
    if ((${#add[@]})); then
        put_text "$f" 0644 <<-EOF
			# the kernel arguments of the dotfiles, the recovery entry boots without them
			GRUB_CMDLINE_LINUX_DEFAULT="\$GRUB_CMDLINE_LINUX_DEFAULT $have"
		EOF
        ok "GRUB: added ${add[*]}"
        stale=1
    else
        skip "GRUB has $*"
    fi
    ((stale || GRUB_STALE)) && grub_update
    return 0
}

grub_update() {
    [[ -f /boot/grub/grub.cfg ]] && backup /boot/grub/grub.cfg
    run "update-grub" update-grub
    grub_check
    GRUB_STALE=0
}

# Debian has no package: 41_snapshots-btrfs from the repository, at a fixed commit
grub_btrfs() {
    local tmp mark=$STATE/grub-btrfs f=/etc/grub.d/41_snapshots-btrfs
    if [[ -x $f && $(cat -- "$mark" 2>/dev/null) == "$GRUB_BTRFS_REV" ]]; then
        skip "grub-btrfs ${GRUB_BTRFS_REV:0:12}"
        return 0
    fi
    tmp=$(mktemp -d)
    git_at "$tmp/src" "$GRUB_BTRFS_URL" "$GRUB_BTRFS_REV"
    [[ -f $tmp/src/41_snapshots-btrfs ]] || die "unexpected layout in $GRUB_BTRFS_URL"
    run "41_snapshots-btrfs parses" bash -n "$tmp/src/41_snapshots-btrfs"
    put "$tmp/src/41_snapshots-btrfs" "$f" 0755
    rm -rf -- "$tmp"
    put_text "$mark" 0644 <<<"$GRUB_BTRFS_REV"
    GRUB_STALE=1
}

grub_snaps() {
    local home= n
    if [[ ! -f /etc/default/grub ]] || ! command -v update-grub >/dev/null; then
        warn "no GRUB here, the snapshots of / are not in the boot menu"
        return 0
    fi
    grub_btrfs
    if [[ $(findmnt -no UUID -T /home) == "$(findmnt -no UUID -T /)" ]]; then
        home=$(btrfs subvolume show /home | head -n1)
        [[ $home != / ]] || home=
    fi
    # no package owns it: the whole file is this script's
    n=$(njot)
    put_text /etc/default/grub-btrfs/config 0644 <<-EOF
		GRUB_BTRFS_SUBMENUNAME="Snapshots before updates"
		GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS="overlayroot=tmpfs:recurse=0"
		GRUB_BTRFS_IGNORE_SPECIFIC_PATH=("@")
		GRUB_BTRFS_IGNORE_PREFIX_PATH=("var/lib/docker" "@var/lib/docker" "@/var/lib/docker" "var/lib/containers" "@var/lib/containers" "@/var/lib/containers"${home:+ \"$home\"})
	EOF
    ((n == $(njot))) || GRUB_STALE=1
    grep -qs snapshots-btrfs /boot/grub/grub.cfg || GRUB_STALE=1
    if ((GRUB_STALE)); then
        grub_update
    else
        skip "boot menu has the snapshots of /"
    fi
}

grub_check() {
    local need root a l n=0 bad=0
    need=$(tr ' ' '\n' </proc/cmdline | grep -E '^(root|rootflags|rootfstype|cryptopts|rd\.luks\.[a-z.]+|resume|resume_offset)=' | sort -u || true)
    root=$(grep -m1 '^root=' <<<"$need" || true)
    [[ -n $root ]] || {
        warn "no root= on /proc/cmdline, grub.cfg not checked"
        return 0
    }
    while IFS= read -r l; do
        n=$((n + 1))
        for a in $need; do
            [[ " $l " == *" $a "* ]] || {
                warn "grub.cfg lacks $a in: $l"
                bad=1
            }
        done
    done < <(awk -v r="$root" '$1 == "linux" { $1 = ""; if (index($0 " ", " " r " ")) print }' /boot/grub/grub.cfg)
    ((n > 0)) || die "grub.cfg has no entry with $root, the system booted with"
    ((bad == 0)) || die "grub.cfg lost boot arguments the system booted with"
    ok "grub.cfg: $n entries keep $(tr '\n' ' ' <<<"$need")"
}

grub_set() {
    local k=$1 v=$2 n f=$GRUB_D/41_debian-postinstall-${1#GRUB_}.cfg
    f=${f,,}
    n=$(njot)
    put_text "$f" 0644 <<<"$k=\"$v\""
    ((n == $(njot))) || GRUB_STALE=1
}

grub_gfx() {
    local out
    out=$(sed -nE 's/^GRUB_TERMINAL=//p; s/^GRUB_TERMINAL_OUTPUT=//p' /etc/default/grub "$GRUB_D"/*.cfg 2>/dev/null | tail -n1 | tr -d "\"'")
    [[ -z $out || $out == *gfxterm* ]]
}

grub_theme() {
    local tmp stage perm clean=0 dir=$GRUB_THEME_DIR mark=$STATE/grub-theme
    if [[ ! -f /etc/default/grub || ! -d /boot/grub ]] || ! command -v update-grub >/dev/null; then
        warn "no GRUB here, theme not installed"
        return 0
    fi
    # on a vfat /boot the mount options set the modes and chmod fails
    perm=(-perm /022)
    [[ $(stat -f -c %T /boot/grub) != msdos ]] || perm=(-false)
    [[ -d $dir && ! -L $dir && -z $(find "$dir" \( -type l -o ! -user root -o "${perm[@]}" \) -print -quit) ]] && clean=1
    if ((clean)) && [[ -f $dir/theme.txt && $(cat -- "$mark" 2>/dev/null) == "$GRUB_THEME_REV" ]]; then
        skip "$dir"
    else
        tmp=$(mktemp -d)
        git_at "$tmp/src" "$GRUB_THEME_URL" "$GRUB_THEME_REV"
        [[ -f $tmp/src/minimal/theme.txt && -f $tmp/src/minimal/icons/debian.png ]] ||
            die "unexpected layout in $GRUB_THEME_URL"
        find "$tmp/src/minimal" -type d -exec chmod 0755 {} +
        find "$tmp/src/minimal" -type f -exec chmod 0644 {} +
        if [[ ! -d ${dir%/*} ]]; then
            mkdir -- "${dir%/*}"
            jot rmdir "${dir%/*}"
        fi
        stage=$(mktemp -d -p "${dir%/*}" ".${dir##*/}.XXXXXX")
        if ! cp -r -- "$tmp/src/minimal/." "$stage/"; then
            rm -rf -- "$stage" "$tmp"
            die "cannot copy the GRUB theme to ${dir%/*} (full?)"
        fi
        rm -rf -- "$tmp"
        [[ ${perm[0]} == -false ]] || chmod 0755 -- "$stage"
        if ((clean)) && diff -rq --no-dereference "$stage" "$dir" >/dev/null; then
            rm -rf -- "$stage"
            skip "$dir"
        else
            backup "$dir"
            rm -rf -- "$dir"
            mv -T -- "$stage" "$dir"
            ok "$dir (${GRUB_THEME_REV:0:12})"
        fi
        put_text "$mark" 0644 <<<"$GRUB_THEME_REV"
    fi
    grub_set GRUB_THEME "$dir/theme.txt"
    if ! grub_gfx; then
        warn "GRUB_TERMINAL_OUTPUT is not gfxterm, the GRUB theme stays hidden"
    elif ! grep -qE '^[[:space:]]*set theme=' /boot/grub/grub.cfg 2>/dev/null; then
        GRUB_STALE=1
    fi
}

grub_quiet() {
    local f=/etc/grub.d/10_linux src n tmp
    [[ -f $f ]] || {
        warn "no $f, GRUB keeps its Loading messages"
        return 0
    }
    # dpkg keeps the edited one and leaves the new one of a grub update next to it
    src=$f
    [[ ! -f $f.dpkg-dist ]] || src=$f.dpkg-dist
    tmp=$(mktemp -p "$BAK")
    sed -E -e '/^[[:space:]]*echo[[:space:]].*"\$message" \| grub_quote/d' \
        -e "/^$GRUB_QUIET_MARK\$/d" -e "1a $GRUB_QUIET_MARK" -- "$src" >"$tmp"
    if grep -qE '^[[:space:]]*echo[[:space:]].*\$message' "$tmp" || ! grep -q '^[[:space:]]linux' "$tmp"; then
        warn "$src has a new layout, GRUB keeps its Loading messages"
        cp -- "$src" "$tmp"
    fi
    run "10_linux parses" sh -n "$tmp"
    n=$(njot)
    put "$tmp" "$f" 0755
    rm -f -- "$tmp"
    if [[ -f $f.dpkg-dist ]]; then
        backup "$f.dpkg-dist"
        rm -f -- "$f.dpkg-dist"
    fi
    ((n == $(njot))) || GRUB_STALE=1
    if grep -qx "$GRUB_QUIET_MARK" "$f" && grep -q '^[[:space:]]*echo.*Loading' /boot/grub/grub.cfg 2>/dev/null; then
        GRUB_STALE=1
    fi
    return 0
}

do_boot() {
    step "Boot"
    local n p
    n=$(njot)
    put_tree initramfs
    put_tree plymouth
    ((n == $(njot))) || REGEN=1
    for p in "${PKG_BOOT[@]}"; do
        [[ " ${NEW_PKGS[*]} " == *" $p "* ]] && REGEN=1
    done
    initramfs_stale && REGEN=1
    put_tree agetty
    svc_reload
    console_font
    [[ -f $(plymouth --get-splash-plugin-path)two-step.so ]] || die "plymouth two-step module missing (plymouth-themes)"
    [[ $(plymouth-set-default-theme) == g0wm ]] || die "plymouth does not pick the g0wm theme"
    ok "plymouth theme g0wm"

    grub_theme
    grub_quiet
    # loglevel=3: the kernel errors of drivers go to the journal, not over the login
    grub_words quiet splash loglevel=3 "$(vt_palette red)" "$(vt_palette grn)" "$(vt_palette blu)"
    login_defs
    login_faillock
    luks_check

    if ((REGEN)); then
        regen_initramfs
    else
        skip "initramfs up to date"
    fi
}

# vt.default_red=7,204,... from VT_PALETTE: the console keeps it across resets
vt_palette() {
    local c v=() shift=16
    case $1 in grn) shift=8 ;; blu) shift=0 ;; esac
    for c in "${VT_PALETTE[@]}"; do v+=($(((16#$c >> shift) & 255))); done
    printf 'vt.default_%s=%s' "$1" "$(join , "${v[@]}")"
}

# one try per login: a wrong password ends login(1), agetty starts again and
# g0wm-login draws the error. pam_faildelay still waits 3 seconds on it,
# FAIL_DELAY 0 drops the "Login incorrect" of login(1) at once
login_defs() {
    local f=/etc/login.defs
    [[ -f $f ]] || die "$f missing (login.defs)"
    put_text "$f" 0644 < <(awk '
		BEGIN { v["LOGIN_RETRIES"] = 1; v["FAIL_DELAY"] = 0 }
		match($0, /^#?[ \t]*[A-Z_]+[ \t]/) {
			k = $0
			sub(/^#?[ \t]*/, "", k)
			sub(/[ \t].*/, "", k)
			if (k in v) {
				if (!(k in done)) printf "%s\t\t%s\n", k, v[k]
				done[k] = 1
				next
			}
		}
		{ print }
		END { for (k in v) if (!(k in done)) printf "%s\t\t%s\n", k, v[k] }' "$f")
}

# pam_faillock in common-auth (login, gtklock, doas, su): 5 wrong passwords in
# 15 minutes lock the account for 10, root never. authsucc clears them in auth,
# not in account, which cron runs too
login_faillock() {
    local f=/etc/security/faillock.conf p=/etc/pam.d/common-auth
    [[ -f $f ]] || die "$f missing (libpam-modules)"
    command -v faillock >/dev/null || die "faillock missing (libpam-modules)"
    put_text "$f" 0644 < <(awk '
		BEGIN { v["deny"] = 5; v["fail_interval"] = 900; v["unlock_time"] = 600 }
		match($0, /^#?[ \t]*[a-z_]+[ \t]*=/) {
			k = $0
			sub(/^#?[ \t]*/, "", k)
			sub(/[ \t]*=.*/, "", k)
			if (k in v) {
				if (!(k in done)) printf "%s = %s\n", k, v[k]
				done[k] = 1
				next
			}
		}
		{ print }
		END { for (k in v) if (!(k in done)) printf "%s = %s\n", k, v[k] }' "$f")
    if faillock_on "$p"; then
        skip "$p has pam_faillock"
        return 0
    fi
    # backed up together: pam-auth-update compares them
    backup "$p"
    backup /var/lib/pam/auth
    backup /var/lib/pam/seen
    run "pam_faillock in $p" pam-auth-update --package \
        --enable dotfiles-faillock-preauth dotfiles-faillock dotfiles-faillock-reset
    # it leaves a common-auth edited by hand as it is
    faillock_on "$p" || die "pam-auth-update did not put pam_faillock in $p (edited by hand?)"
}

faillock_on() {
    grep -qE '^auth[[:space:]]+requisite[[:space:]]+pam_faillock\.so preauth' "$1" &&
        grep -qE '^auth[[:space:]]+\[default=die\][[:space:]]+pam_faillock\.so authfail' "$1" &&
        grep -qE '^auth[[:space:]]+optional[[:space:]]+pam_faillock\.so authsucc' "$1"
}

# console-setup: Terminus on every tty, larger on screens 1440 pixels tall or more
console_font() {
    local f=/etc/default/console-setup size=8x16 h= n font
    [[ -f $f ]] || die "$f missing (console-setup)"
    [[ -r /sys/class/graphics/fb0/virtual_size ]] && h=$(cut -d, -f2 /sys/class/graphics/fb0/virtual_size)
    [[ $h =~ ^[0-9]+$ ]] && ((h >= 1440)) && size=16x32
    # 8x16 is Uni2-Terminus16, 16x32 Uni3-Terminus32x16
    [[ $size == 8x16 ]] && font=Terminus16 || font=Terminus32x16
    compgen -G "/usr/share/consolefonts/Uni?-$font.psf.gz" >/dev/null || die "console-setup-linux has no $font font"
    n=$(njot)
    put_text "$f" 0644 < <(awk -v face=Terminus -v size="$size" '
		/^[[:space:]]*FONTFACE=/ { print "FONTFACE=\"" face "\""; f = 1; next }
		/^[[:space:]]*FONTSIZE=/ { print "FONTSIZE=\"" size "\""; s = 1; next }
		{ print }
		END {
			if (!f) print "FONTFACE=\"" face "\""
			if (!s) print "FONTSIZE=\"" size "\""
		}' "$f")
    ((n == $(njot))) && return 0
    # the initramfs has it too, for the LUKS prompt
    REGEN=1
    try "console font Terminus $size" setupcon --force --save
}

# Debian unlocks the root in the initramfs from /etc/crypttab (cryptsetup-initramfs),
# not from rd.luks arguments; GRUB reads /boot, unencrypted unless it is told otherwise
luks_check() {
    local src
    src=$(findmnt -no SOURCE / | sed 's/\[.*//')
    lsblk -no TYPE -s -- "$src" 2>/dev/null | grep -qx crypt || return 0
    installed cryptsetup-initramfs || die "/ is on LUKS but cryptsetup-initramfs is not installed: the initramfs could not unlock it"
    grep -qE '^[[:space:]]*[^#[:space:]]' /etc/crypttab 2>/dev/null || die "/ is on LUKS but /etc/crypttab is empty"
    if [[ $(findmnt -no SOURCE -T /boot | sed 's/\[.*//') == "$src" ]] &&
        ! grep -hqsE '^GRUB_ENABLE_CRYPTODISK=["]?y' /etc/default/grub "$GRUB_D"/*.cfg; then
        warn "/boot is on the encrypted /, and GRUB_ENABLE_CRYPTODISK is not set: GRUB cannot read it"
    fi
    ok "/ on LUKS: unlocked by the initramfs from /etc/crypttab"
}

initramfs_stale() {
    local k img
    for k in /usr/lib/modules/*/modules.dep; do
        [[ -e $k ]] || continue
        k=${k%/modules.dep}
        [[ -e /boot/vmlinuz-${k##*/} ]] || continue
        img=/boot/initrd.img-${k##*/}
        [[ -s $img ]] || return 0
        lsinitramfs "$img" 2>/dev/null | grep plymouth >/dev/null || return 0
    done
    return 1
}

regen_initramfs() {
    ((REGEN < 2)) || return 0
    local kvers=() k crypt=0 list
    for k in /usr/lib/modules/*/modules.dep; do
        [[ -e $k ]] || continue
        k=${k%/modules.dep}
        [[ -e /boot/vmlinuz-${k##*/} ]] || continue
        kvers+=("${k##*/}")
    done
    ((${#kvers[@]})) || die "no kernel in /usr/lib/modules with a /boot/vmlinuz"
    install -d -m 0700 -- "$BAK/boot"
    if compgen -G '/boot/initrd.img-*' >/dev/null; then
        cp -a /boot/initrd.img-* "$BAK/boot/" || die "cannot back up /boot/initrd.img-* (disk full?)"
    fi
    jot initramfs
    lsblk -no TYPE -s -- "$(findmnt -no SOURCE / | sed 's/\[.*//')" 2>/dev/null | grep -qx crypt && crypt=1
    for k in "${kvers[@]}"; do
        if [[ -e /boot/initrd.img-$k ]]; then
            run "initramfs for $k" update-initramfs -u -k "$k"
        else
            run "initramfs for $k" update-initramfs -c -k "$k"
        fi
        [[ -s /boot/initrd.img-$k ]] || die "/boot/initrd.img-$k is empty"
        ((crypt)) || continue
        # the whole list first: grep -q would stop reading, and zstd would fail on the closed pipe
        list=$(lsinitramfs "/boot/initrd.img-$k") || die "cannot list /boot/initrd.img-$k"
        grep -qx 'cryptroot/crypttab' <<<"$list" ||
            die "/boot/initrd.img-$k cannot unlock the LUKS root, the old one is restored on rollback"
    done
    REGEN=2
}

do_hw() {
    step "Hardware"
    local p
    for p in intel-microcode amd64-microcode; do
        [[ " ${NEW_PKGS[*]} " == *" $p "* ]] && REGEN=1
    done
    ((REGEN)) && ok "new microcode: the initramfs gets rebuilt" || skip "microcode in the initramfs"
    [[ -e /dev/dri/renderD128 ]] && ok "GPU render node present" || warn "no /dev/dri/renderD128 yet, check after the reboot"
    put_tree udev
    try "udev rules reload" udevadm control --reload
    try "airplane key off" udevadm trigger --action=change --subsystem-match=input
    fwupd_noreport
    return 0
}

# no report address: even a click on "send report" sends nothing about the hardware
fwupd_noreport() {
    local f
    for f in /etc/fwupd/remotes.d/*.conf; do
        grep -q '^ReportURI=.' "$f" || continue
        put_text "$f" 0644 < <(ini_set "$f" 'fwupd Remote/ReportURI=')
    done
}
