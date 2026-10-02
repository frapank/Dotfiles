# shellcheck shell=bash
# kernel and firewall hardening

save_sysctl() {
    local f key v
    for f in "$@"; do
        while IFS='=' read -r key _; do
            key=${key//[[:space:]]/}
            [[ -n $key && $key != \#* ]] || continue
            v=$(sysctl -n "$key" 2>/dev/null || true)
            [[ -z $v ]] || printf '%s = %s\n' "$key" "$v" >>"$BAK/sysctl.orig"
        done <"$f"
    done
    jot sysctl
}

nft_apply() {
    local nft_on=0 n f
    [[ $(sv status nftables 2>/dev/null) == run:* ]] && nft_on=1 && jot nft
    n=$(njot)
    "$@"
    put_text /etc/nftables.conf 0600 < <(
        for f in /etc/nftables/nft_base_desktop.conf /etc/nftables/nft_dns_desktop.conf; do
            [[ -f $f ]] || continue
            printf 'include "%s"\n' "$f"
        done
    )
    run "nftables ruleset is valid" nft -c -f /etc/nftables.conf
    if ((nft_on && n != $(njot))); then
        run "load the new nftables ruleset" nft -f /etc/nftables.conf
    fi
}

do_harden() {
    step "Kernel and firewall hardening"
    local f
    save_sysctl "$REPO"/root/sysctl/etc/sysctl.d/*.conf
    put_tree sysctl
    for f in "$REPO"/root/sysctl/etc/sysctl.d/*.conf; do
        try "sysctl -p ${f##*/}" sysctl -p "/etc/sysctl.d/${f##*/}"
    done

    nft_apply put_tree nftables

    put_tree ssh
    if grep -qE '^[[:space:]]*Include[[:space:]]+/etc/ssh/ssh_config\.d/' /etc/ssh/ssh_config; then
        skip "ssh_config includes ssh_config.d"
    else
        put_text /etc/ssh/ssh_config 0644 < <(
            echo 'Include /etc/ssh/ssh_config.d/*.conf'
            cat /etc/ssh/ssh_config
        )
    fi
    run "ssh config parses" ssh -G localhost
    ssh_dir

    put_tree modprobe
    put_tree machineid
    run "machine ID script parses" sh -n /etc/runit/core-services/06-machine-id.sh
    grub_words "${HARDEN_CMDLINE[@]}"
    boot_mask
    tmp_mount
    hide_pids
    no_suid
}

hide_pids() {
    local u
    put_tree hidepid
    run "hidepid script parses" sh -n /etc/runit/core-services/01-hidepid.sh
    if getent group proc >/dev/null; then
        skip "group proc"
    else
        jot grpdel proc
        groupadd -r proc >>"$LOG" 2>&1 || die "cannot create the group proc"
        ok "group proc created"
    fi
    # need to see other users' processes
    for u in polkitd rtkit; do
        getent passwd "$u" >/dev/null || continue
        if [[ " $(id -nG -- "$u") " == *" proc "* ]]; then
            skip "$u in proc"
            continue
        fi
        jot group proc "$u"
        gpasswd -a "$u" proc >>"$LOG" 2>&1 || die "cannot add $u to proc"
        ok "$u added to proc"
    done
}

no_suid() {
    local f m n=0
    put_tree nosuid
    run "nosuid parses" sh -n /usr/local/sbin/nosuid
    run "nosuid boot script parses" sh -n /etc/runit/core-services/05-nosuid.sh
    while IFS= read -r f; do
        m=$(stat -c '%a %u:%g' -- "$f")
        jot perm "$f" "${m% *}" "${m#* }"
        chmod ug-s -- "$f"
        ok "$f ${m% *} -> $(stat -c %a -- "$f")"
        n=$((n + 1))
    done < <(/usr/local/sbin/nosuid -n)
    ((n)) || skip "no setuid on su pkexec passwd and the others"
}

boot_mask() {
    local mnt new
    mnt=$(awk '$3 == "vfat" && ($2 == "/boot" || $2 == "/boot/efi") { print $2; exit }' /etc/fstab)
    if [[ -z $mnt ]]; then
        skip "no vfat /boot in /etc/fstab"
        return 0
    fi
    new=$(awk -v m="$mnt" '
		!/^[[:space:]]*#/ && $2 == m && $3 == "vfat" {
			n = split($4, o, ","); $4 = ""
			for (i = 1; i <= n; i++)
				if (o[i] !~ /^(fmask|dmask|umask)=/) $4 = $4 o[i] ","
			$4 = $4 "fmask=0077,dmask=0077"
		}
		{ print }' /etc/fstab)
    if [[ $new == "$(cat /etc/fstab)" ]]; then
        skip "$mnt fmask=0077,dmask=0077"
        return 0
    fi
    put_text /etc/fstab 0644 <<<"$new"
    run "fstab is valid" findmnt --verify
    try "remount $mnt" mount -o remount "$mnt"
    [[ $(stat -c %a -- "$mnt") == 700 ]] || warn "$mnt is readable by everyone until the reboot"
}

tmp_mount() {
    local cur new
    cur=$(awk '!/^[[:space:]]*#/ && $2 == "/tmp" { print $3; exit }' /etc/fstab)
    if [[ -n $cur && $cur != tmpfs ]]; then
        warn "/tmp is $cur in /etc/fstab, left alone"
        return 0
    fi
    if [[ -z $cur ]]; then
        new=$(
            cat /etc/fstab
            printf 'tmpfs /tmp tmpfs defaults,nosuid,nodev,mode=1777 0 0\n'
        )
    else
        new=$(awk '
			!/^[[:space:]]*#/ && $2 == "/tmp" && $3 == "tmpfs" {
				o = "," $4 ","
				if (o !~ /,nosuid,/) $4 = $4 ",nosuid"
				if (o !~ /,nodev,/) $4 = $4 ",nodev"
			}
			{ print }' /etc/fstab)
    fi
    if [[ $new == "$(cat /etc/fstab)" ]]; then
        skip "/tmp tmpfs nosuid,nodev"
        return 0
    fi
    put_text /etc/fstab 0644 <<<"$new"
    run "fstab is valid" findmnt --verify
    if [[ $(findmnt -no FSTYPE /tmp) == tmpfs ]]; then
        try "remount /tmp" mount -o remount /tmp
    else
        ok "/tmp becomes a tmpfs after the reboot"
    fi
}

ssh_dir() {
    local d=$THOME/.ssh m
    [[ ! -L $d ]] || die "$d is a symlink, refusing"
    if [[ ! -e $d ]]; then
        umkdir "$d"
        ok "created ~/.ssh (700)"
        return 0
    fi
    [[ -d $d ]] || die "$d exists and is not a directory"
    own "$d"
    m=$(stat -c %a -- "$d")
    if [[ $m == 700 ]]; then
        skip "~/.ssh (700)"
        return 0
    fi
    jot hchmod "$d" "$m"
    as_user chmod 0700 -- "$d"
    ok "~/.ssh $m -> 700"
}
