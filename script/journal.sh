# shellcheck shell=bash
# change journal and rollback

jot() {
    local IFS=$'\t'
    printf '%s\n' "$*" >>"$BAK/journal"
}

njot() { grep -vcE '^(sysctl|nft|svr|svc-stop|aaload|usbopen)' -- "$BAK/journal" || true; }

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
        svc-off) systemctl disable --now -- "$a" ;;
        svc-stop) systemctl stop -- "$a" ;;
        svc-on) systemctl enable --now -- "$a" ;;
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
            ((${#pk[@]} == 0)) || "${APT[@]}" purge --autoremove "${pk[@]}"
            ;;
        sudo)
            for p in 1 2 3; do
                "${APT[@]}" install sudo && break
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
        svr) systemctl restart -- "$a" ;;
        usbopen)
            # usbguard left the kernel blocking new devices
            systemctl stop usbguard-notify.service usbguard.service || true
            for p in /sys/bus/usb/devices/usb*/authorized_default /sys/bus/usb/devices/*/authorized; do
                [[ $(<"$p") == 1 ]] || echo 1 >"$p"
            done
            ;;
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
        cap) setcap "$b" "$a" ;;
        pkgback)
            read -ra pk <<<"$a"
            "${APT[@]}" install "${pk[@]}"
            ;;
        pkgauto)
            read -ra pk <<<"$a"
            apt-mark auto "${pk[@]}"
            ;;
        gset) as_user dbus-run-session gsettings set "${c:-org.gnome.desktop.interface}" "$a" "$b" ;;
        esac >>"$LOG" 2>&1 || printf '   %s! could not undo: %s %s%s\n' "$C_Y" "$op" "$a" "$C_0" >&2
    done < <(tac -- "$BAK/journal")
    : >"$BAK/journal"
    systemctl daemon-reload >>"$LOG" 2>&1 || true
    ((keepdoas == 0)) || printf '   %s! sudo could not be reinstalled: doas, /etc/doas.conf and wheel were kept%s\n' "$C_Y" "$C_0" >&2
    printf '\n%sRolled back.%s\n   log      %s\n   backups  %s\n' "$C_B" "$C_0" "$LOG" "$BAK" >&2
    ((reset == 0)) || printf '   reboot to be sure every kernel setting is back\n' >&2
    return 0
}
