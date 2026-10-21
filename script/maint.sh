# shellcheck shell=bash
# swap, logs, maintenance, snapshots

do_swap() {
    step "Swap"
    local n
    grep -qw zstd /sys/block/zram0/comp_algorithm 2>/dev/null ||
        modprobe -n zram 2>/dev/null || die "the kernel has no zram module"
    n=$(njot)
    put_text /etc/systemd/zram-generator.conf 0644 <<-EOF
		[zram0]
		zram-size = min(ram * $ZRAM_PCT / 100, 16384)
		compression-algorithm = zstd
		swap-priority = 32767
	EOF
    svc_reload
    if ((n != $(njot))); then
        try "restart the zram swap" systemctl restart systemd-zram-setup@zram0.service dev-zram0.swap
    fi
    save_sysctl "$REPO"/root/zram/etc/sysctl.d/*.conf
    put_tree zram
    try "sysctl -p 50-zram.conf" sysctl -p /etc/sysctl.d/50-zram.conf
    svc_refresh earlyoom.service put_tree earlyoom
    run "earlyoom args parse" sh -n /etc/default/earlyoom
    run "earlyoom-closed parses" sh -n /usr/local/libexec/earlyoom-closed
}

do_logs() {
    step "System logs"
    svc_refresh systemd-journald.service put_tree logs
    # watchdog needs it
    put_tree session
    run "logs parses" sh -n /usr/local/bin/logs
    if [[ -d /sys/firmware/efi ]]; then
        svc_enable systemd-pstore.service
        grub_words efi_pstore.pstore_disable=0
    else
        warn "booted without UEFI: no pstore, a kernel panic leaves no log"
    fi
}

do_maint() {
    step "Maintenance"
    home_subvol
    [[ " ${NEW_PKGS[*]} " != *" overlayroot "* ]] || REGEN=1
    # overlayroot only acts on the overlayroot= of a snapshot entry
    if [[ -f /etc/overlayroot.conf ]] && grep -qE '^[[:space:]]*overlayroot="[^"]' /etc/overlayroot.conf; then
        die "/etc/overlayroot.conf sets overlayroot: every boot would be in RAM"
    fi
    put_tree session
    svc_refresh maint.service put_tree maint
    run "maint parses" sh -n /usr/local/sbin/maint
    run "thumbs-clean parses" python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' /usr/local/libexec/thumbs-clean
    run "trash-clean parses" python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' /usr/local/libexec/trash-clean
    run "disk-health parses" python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' /usr/local/libexec/disk-health
    run "snap parses" python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' /usr/local/bin/snap
    run "snap-ui parses" sh -n /usr/local/libexec/snap-ui
    grub_snaps
}

# Debian's installer makes only @rootfs: a subvolume of /home can be snapshotted, and the
# snapshots of / leave it out
home_subvol() {
    local new=/home.pi-subvol prev=/home.pi-old
    if [[ $(stat -c %i /home) == 256 ]]; then
        skip "/home is a subvolume"
        return 0
    fi
    [[ ! -e $new && ! -e $prev ]] || die "$new or $prev exists, move it away"
    jot subvol-rm "$new"
    run "create the subvolume for /home" btrfs subvolume create -- "$new"
    chmod 0755 "$new"
    run "copy /home into it (reflinks, no extra space)" cp -a --reflink=always -- /home/. "$new/"
    jot subvol-swap /home "$prev"
    mv -T -- /home "$prev"
    mv -T -- "$new" /home
    ok "/home is a subvolume; $prev holds the old copy until maint deletes it after the reboot"
}

do_nosnap() {
    step "Folders kept out of the snapshots"
    local dl
    dl=$(as_user xdg-user-dir DOWNLOAD 2>/dev/null) || dl=
    if [[ $dl == "$THOME"/?* ]]; then
        nosnap "$dl"
    else
        warn "no download folder in user-dirs.dirs, it stays in the snapshots"
    fi
    nosnap "$THOME/Private"
    nosnap "$THOME/.cache"
    nosnap "$THOME/Games"
    nosnap "$THOME/.local/share/Steam" steam
    nosnap "$THOME/.config/librewolf" librewolf
}

nosnap() {
    local d=$1 new=$1.pi-subvol prev=$1.pi-old mode=0700 t=${1/#$THOME/\~}
    if [[ -d $d && ! -L $d && $(stat -c %i -- "$d") == 256 ]]; then
        skip "$t is a subvolume, not in the snapshots"
        return 0
    fi
    [[ ! -L $d ]] || die "$d is a symlink, refusing"
    [[ ! -e $d || -d $d ]] || die "$d exists and is not a directory"
    if [[ -n ${2:-} ]] && pgrep -u "$TUSER" -x "$2" >/dev/null; then
        warn "$2 is running, close it and run this again to keep $t out of the snapshots"
        return 0
    fi
    if [[ $REPO/ == "$d"/* ]]; then
        warn "$t holds this repo, left in the snapshots"
        return 0
    fi
    umkdir "${d%/*}"
    [[ $(stat -f -c %T -- "${d%/*}") == btrfs ]] || {
        warn "$t is not on btrfs, left alone"
        return 0
    }
    if [[ -d $d && $(findmnt -no TARGET -T "$d") == "$d" ]]; then
        warn "$t is a mount point, left alone"
        return 0
    fi
    [[ ! -e $new && ! -e $prev ]] || die "$new or $prev exists, move it away"
    [[ -d $d ]] && mode=$(stat -c %a -- "$d")
    jot subvol-rm "$new"
    run "create the subvolume for $t" btrfs subvolume create -- "$new"
    chown -- "$TUSER:$TGID" "$new"
    chmod -- "$mode" "$new"
    if [[ -d $d ]]; then
        run "copy $t into it (reflinks, no extra space)" cp -a --reflink=always -- "$d/." "$new/"
        jot subvol-swap "$d" "$prev"
        mv -T -- "$d" "$prev"
        mv -T -- "$new" "$d"
        jot unsubvol "$d"
        rm -rf -- "$prev"
    else
        mv -T -- "$new" "$d"
        jot subvol-rm "$d"
    fi
    ok "$t is a subvolume, kept out of the snapshots"
}
