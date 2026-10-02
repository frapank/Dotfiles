# shellcheck shell=bash
# change journal and rollback

jot() {
    local IFS=$'\t'
    printf '%s\n' "$*" >>"$BAK/journal"
}

njot() { grep -vcE '^(sysctl|nft|svr|aaload)' -- "$BAK/journal" || true; }

rollback() {
    trap '' INT TERM HUP
    [[ -s $BAK/journal ]] || return 0
    head_line "Rolling back" "$(wc -l <"$BAK/journal") change(s)" >&2
    log "=== rollback"
    local op a b c p pk reset=0 keepdoas=0
    while IFS=$'\t' read -r op a b c; do
        log "undo: $op $a $b"
        case $op in
        restore)
            [[ $a == /etc/doas.conf ]] && ((keepdoas)) && continue
            rm -rf -- "$a" && cp -a -- "$BAK/files$a" "$a"
            ;;
        remove)
            [[ $a == /etc/doas.conf ]] && ((keepdoas)) && continue
            rm -rf -- "$a"
            ;;
        rmdir) rmdir -- "$a" ;;
        sv-off) rm -f -- "$SVDIR/$a" ;;
        sv-on) ln -sfn -- "$b" "$SVDIR/$a" ;;
        group)
            [[ $a == wheel ]] && ((keepdoas)) && continue
            gpasswd -d "$b" "$a"
            ;;
        grpdel) groupdel "$a" ;;
        shell) usermod -s "$b" "$a" ;;
        pkgs)
            pk=()
            for p in $a; do
                [[ $p == opendoas ]] && ((keepdoas)) && continue
                installed "$p" && pk+=("$p")
            done
            ((${#pk[@]} == 0)) || xbps-remove -Ry -- "${pk[@]}"
            ;;
        sudo)
            for p in 1 2 3; do
                xbps-install -Sy sudo && break
                sleep 5
            done
            installed sudo || {
                keepdoas=1
                false
            }
            ;;
        sysctl)
            reset=1
            sysctl -p "$BAK/sysctl.orig"
            ;;
        nft) nft -f /etc/nftables.conf ;;
        svr) sv restart "$a" ;;
        initramfs) cp -a -- "$BAK/boot/." /boot/ ;;
        aaload) aa-remove-unknown && apparmor_parser -r -- /etc/apparmor.d ;;
        subvol-rm) [[ ! -e $a ]] || btrfs subvolume delete -- "$a" ;;
        subvol-swap)
            [[ -e $b ]] || continue
            [[ ! -e $a ]] || btrfs subvolume delete -- "$a"
            mv -T -- "$b" "$a"
            ;;
        unsubvol)
            install -d -m 0700 -- "$a.pi-dir" &&
                cp -a --reflink=always -- "$a/." "$a.pi-dir/" &&
                chown --reference="$a" -- "$a.pi-dir" && chmod --reference="$a" -- "$a.pi-dir" &&
                btrfs subvolume delete -- "$a" && mv -T -- "$a.pi-dir" "$a"
            ;;
        hrestore) as_user rm -rf -- "$a" && as_user cp -a -- "$UBAK$a" "$a" ;;
        hremove) as_user rm -rf -- "$a" ;;
        hmove) as_user rm -rf -- "$a" && as_user mv -- "$UBAK$a" "$a" ;;
        hrmdir) as_user rmdir -- "$a" ;;
        hchmod) as_user chmod -- "$b" "$a" ;;
        hown) chown -- "$b" "$a" ;;
        perm) chown -- "$c" "$a" && chmod -- "$b" "$a" ;;
        pkgback)
            read -ra pk <<<"$a"
            xbps-install -y -- "${pk[@]}"
            ;;
        pkgauto)
            read -ra pk <<<"$a"
            xbps-pkgdb -m auto "${pk[@]}"
            ;;
        gset) as_user dbus-run-session gsettings set "${c:-org.gnome.desktop.interface}" "$a" "$b" ;;
        esac >>"$LOG" 2>&1 || printf '   %s! could not undo: %s %s%s\n' "$C_Y" "$op" "$a" "$C_0" >&2
    done < <(tac -- "$BAK/journal")
    : >"$BAK/journal"
    ((keepdoas == 0)) || printf '   %s! sudo could not be reinstalled: doas, /etc/doas.conf and wheel were kept%s\n' "$C_Y" "$C_0" >&2
    printf '\n%sRolled back.%s\n   log      %s\n   backups  %s\n' "$C_B" "$C_0" "$LOG" "$BAK" >&2
    ((reset == 0)) || printf '   reboot to be sure every kernel setting is back\n' >&2
    return 0
}
