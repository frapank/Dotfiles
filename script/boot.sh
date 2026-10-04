# shellcheck shell=bash
# boot, grub, initramfs, hardware

grub_words() {
    local line w add=() stale=0
    if [[ ! -f /etc/default/grub ]]; then
        warn "no /etc/default/grub: add '$*' to the kernel command line yourself"
        return 0
    fi
    if grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub | grep -qv '^GRUB_CMDLINE_LINUX_DEFAULT="[^"]*"[[:space:]]*$'; then
        die "GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub is not a plain \"...\" value, add '$*' to it yourself"
    fi
    line=$(grep -E '^GRUB_CMDLINE_LINUX(_DEFAULT)?=' /etc/default/grub || true)
    for w in "$@"; do
        [[ " $line " =~ [\"\'[:space:]]"$w"[\"\'[:space:]] ]] || add+=("$w")
        grep -qsF -- "$w" /boot/grub/grub.cfg || stale=1
    done
    if ((${#add[@]})); then
        backup /etc/default/grub
        if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT="' /etc/default/grub; then
            sed -i -E "s/^(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*)\"/\1 ${add[*]}\"/" /etc/default/grub
        else
            echo "GRUB_CMDLINE_LINUX_DEFAULT=\"${add[*]}\"" >>/etc/default/grub
        fi
        grep '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub | grep -qF -- "${add[-1]}\"" || die "could not edit GRUB_CMDLINE_LINUX_DEFAULT"
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

grub_snaps() {
    local home
    if [[ ! -f /etc/default/grub ]] || ! command -v update-grub >/dev/null; then
        warn "no GRUB here, the snapshots of / are not in the boot menu"
        return 0
    fi
    [[ -x /etc/grub.d/41_snapshots-btrfs ]] || die "grub-btrfs did not install /etc/grub.d/41_snapshots-btrfs"
    # /etc/default/grub-btrfs/config is not a conf file for xbps, 41_snapshots-btrfs reads /etc/default/grub after it
    grub_set GRUB_BTRFS_SUBMENUNAME "Snapshots before updates"
    grub_set GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS rd.overlay=1
    if [[ $(findmnt -no UUID -T /home) == "$(findmnt -no UUID -T /)" ]]; then
        home=$(btrfs subvolume show /home | head -n1)
        [[ -z $home || $home == / ]] || grub_set GRUB_BTRFS_IGNORE_PREFIX_PATH "$home"
    fi
    grep -qs snapshots-btrfs /boot/grub/grub.cfg || GRUB_STALE=1
    if ((GRUB_STALE)); then
        grub_update
    else
        skip "boot menu has the snapshots of /"
    fi
}

grub_check() {
    local need root a l n=0 bad=0
    need=$(tr ' ' '\n' </proc/cmdline | grep -E '^(root|rootflags|rootfstype|rd\.luks\.[a-z.]+|rd\.lvm\.[a-z.]+|rd\.md\.[a-z.]+|cryptdevice|cryptkey|resume|resume_offset)=' | sort -u || true)
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
    local k=$1 v=$2 n
    grep -qxF -- "$k=\"$v\"" /etc/default/grub && return 0
    n=$(grep -c "^$k=" /etc/default/grub || true)
    ((n <= 1)) || die "$n $k= lines in /etc/default/grub, keep one"
    backup /etc/default/grub
    if ((n)); then
        sed -i "s|^$k=.*|$k=\"$v\"|" /etc/default/grub
    else
        [[ -z $(tail -c1 /etc/default/grub) ]] || echo >>/etc/default/grub
        printf '%s="%s"\n' "$k" "$v" >>/etc/default/grub
    fi
    grep -qxF -- "$k=\"$v\"" /etc/default/grub || die "could not set $k in /etc/default/grub"
    ok "GRUB: $k=\"$v\""
    GRUB_STALE=1
}

grub_gfx() {
    local out
    out=$(sed -nE 's/^GRUB_TERMINAL=//p; s/^GRUB_TERMINAL_OUTPUT=//p' /etc/default/grub | tail -n1 | tr -d "\"'")
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
        [[ -f $tmp/src/minimal/theme.txt && -f $tmp/src/minimal/icons/void.png ]] ||
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
        warn "GRUB_TERMINAL_OUTPUT in /etc/default/grub is not gfxterm, the GRUB theme stays hidden"
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
    src=$(printf '%s\n' "$f".new-* | sort -V | tail -n1)
    [[ -f $src ]] || src=$f
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
    for src in "$f".new-*; do
        [[ -f $src ]] || continue
        backup "$src"
        rm -f -- "$src"
    done
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
    put_tree dracut
    put_tree plymouth
    ((n == $(njot))) || REGEN=1
    for p in "${PKG_BOOT[@]}"; do
        [[ " ${NEW_PKGS[*]} " == *" $p "* ]] && REGEN=1
    done
    initramfs_stale && REGEN=1
    put_tree agetty
    run "agetty run script parses" sh -n /etc/sv/agetty-generic/run
    put_tree console
    run "console font script parses" sh -n /etc/runit/core-services/04-console-font.sh
    [[ -f /usr/share/kbd/consolefonts/ter-v16n.psf.gz && -f /usr/share/kbd/consolefonts/ter-v32n.psf.gz ]] ||
        die "terminus-font did not install ter-v16n and ter-v32n"
    [[ -f /usr/lib/plymouth/two-step.so ]] || die "plymouth two-step module missing"
    [[ $(plymouth-set-default-theme) == void-minimal ]] || die "plymouth does not pick void-minimal"
    ok "plymouth theme void-minimal"

    grub_theme
    grub_quiet
    grub_words quiet splash

    if ((REGEN)); then
        regen_initramfs
    else
        skip "initramfs up to date"
    fi
}

initramfs_stale() {
    local k img
    for k in /usr/lib/modules/*/modules.dep; do
        [[ -e $k ]] || continue
        k=${k%/modules.dep}
        compgen -G "/boot/vmlinu[xz]-${k##*/}" >/dev/null || continue
        img=/boot/initramfs-${k##*/}.img
        [[ -s $img ]] || return 0
        if command -v lsinitrd >/dev/null; then
            lsinitrd "$img" 2>/dev/null | grep plymouth >/dev/null || return 0
        fi
    done
    return 1
}

regen_initramfs() {
    ((REGEN < 2)) || return 0
    local kvers=() k
    for k in /usr/lib/modules/*/modules.dep; do
        [[ -e $k ]] || continue
        k=${k%/modules.dep}
        compgen -G "/boot/vmlinu[xz]-${k##*/}" >/dev/null || continue
        kvers+=("${k##*/}")
    done
    ((${#kvers[@]})) || die "no kernel in /usr/lib/modules with a /boot/vmlinuz"
    install -d -m 0700 -- "$BAK/boot"
    if compgen -G '/boot/initramfs-*.img' >/dev/null; then
        cp -a /boot/initramfs-*.img "$BAK/boot/" || die "cannot back up /boot/initramfs-*.img (disk full?)"
    fi
    jot initramfs
    for k in "${kvers[@]}"; do
        run "initramfs for $k" dracut -q --force "/boot/initramfs-$k.img" "$k"
        [[ -s /boot/initramfs-$k.img ]] || die "/boot/initramfs-$k.img is empty"
    done
    REGEN=2
}

do_hw() {
    step "Hardware"
    local p
    for p in intel-ucode linux-firmware-amd; do
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
