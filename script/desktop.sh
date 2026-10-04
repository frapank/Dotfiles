# shellcheck shell=bash
# desktop, media, apps, session

g0wm_where() {
    local g out
    g=$(as_user sh -c 'PATH=$PATH:$HOME/bin; command -v start-g0wm >/dev/null && command -v g0wm') ||
        return 1
    out=$(as_user timeout 5 "$g" -v 2>&1) || true
    [[ $out == g0wm\ * ]] || return 1
    echo "${g%/*}"
}

g0wm_clone() {
    [[ -d $1/.git ]] &&
        [[ $(as_user git -C "$1" remote get-url origin 2>/dev/null) == "$G0WM_URL" ]] &&
        [[ -z $(as_user git -C "$1" status --porcelain --untracked-files=no 2>&1) ]]
}

do_g0wm() {
    step "Desktop: g0wm"
    do_home "${HOME_DESKTOP[@]}"
    put_tree elogind

    local wp
    wp=$(grep -o '"wallpaper": *"[^"]*"' "$THOME/.config/g0wm/settings.json" | cut -d'"' -f4 || true)
    [[ -z $wp || -f $wp ]] || warn "wallpaper $wp does not exist, set it in settings.json"

    local src=$THOME/.local/src/g0wm bin=$THOME/.local/bin before= rev out f where=
    where=$(g0wm_where) || where=
    if [[ -n $where ]] && ! g0wm_clone "$src"; then
        note "g0wm in ${where/#$THOME/\~}, built elsewhere: not cloned nor rebuilt"
        return 0
    fi
    if [[ -d $src/.git ]]; then
        [[ $(as_user git -C "$src" remote get-url origin) == "$G0WM_URL" ]] ||
            die "$src is not a clone of $G0WM_URL"
        [[ -z $(as_user git -C "$src" status --porcelain --untracked-files=no) ]] ||
            die "$src has local changes, commit or stash them first"
        before=$(as_user git -C "$src" rev-parse HEAD)
        try "update g0wm source" as_user git -C "$src" pull --ff-only
    elif [[ -e $src || -L $src ]]; then
        die "$src exists and is not a git clone, move it away"
    else
        as_user mkdir -p -- "$THOME/.local/src"
        jot hremove "$src"
        run "clone g0wm" as_user git clone --depth 1 -- "$G0WM_URL" "$src"
    fi
    rev=$(as_user git -C "$src" rev-parse HEAD)
    log "g0wm at $rev"
    if [[ -n $where && $before == "$rev" ]]; then
        skip "g0wm ${rev:0:12} installed"
        return 0
    fi

    run "configure g0wm" as_user sh -c 'cd "$1" && exec ./configure' _ "$src"
    run "build g0wm" as_user make -C "$src" -j"$(nproc)"
    run "test g0wm" as_user make -C "$src" test
    for f in g0wm start-g0wm g0wm-status.sh; do stash "$bin/$f"; done
    run "install g0wm into ~/.local/bin" as_user make -C "$src" install
    do_home g0wm
    out=$(as_user "$bin/g0wm" -v 2>&1 || true)
    [[ $out == g0wm\ * ]] || die "the installed g0wm does not run: $out"
    ok "${out%%$'\n'*}"
}

do_media() {
    step "Screen sharing and audio"
    # services starts them
    local f
    for f in /etc/pipewire/pipewire.conf.d/{10-wireplumber,20-pipewire-pulse}.conf; do
        [[ -e $f || -L $f ]] || continue
        backup "$f"
        rm -f -- "$f"
        ok "removed $f"
    done
    [[ -f /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf ]] ||
        die "alsa-pipewire did not install its ALSA config"
    [[ -f /usr/share/xdg-desktop-portal/portals/wlr.portal ]] ||
        die "xdg-desktop-portal-wlr did not install wlr.portal"
    ok "PipeWire ALSA config and wlr portal present"
    do_home "${HOME_MEDIA[@]}"
}

write_mimeapps() {
    local mf=$THOME/.config/mimeapps.list new ours
    ours=$(mktemp -p "$BAK")
    new=$(mktemp -p "$BAK")
    printf '%s\n' "${MIME_DEFAULTS[@]}" >"$ours"
    {
        echo '[Default Applications]'
        cat "$ours"
        if [[ -f $mf ]]; then
            awk -F= 'NR == FNR { k[$1]; next }
				/^\[/ { s = $0; next }
				s == "[Default Applications]" && NF && !($1 in k)' "$ours" "$mf"
            awk '/^\[/ { s = $0 } s != "" && s != "[Default Applications]"' "$mf"
        fi
    } >"$new"
    if [[ -f $mf && ! -L $mf ]] && cmp -s "$new" "$mf" &&
        [[ $(stat -c '%a %U' -- "$mf") == "600 $TUSER" ]]; then
        skip "~/.config/mimeapps.list"
    else
        stash "$mf"
        as_user rm -f -- "$mf"
        as_user mkdir -p -- "$THOME/.config"
        as_user sh -c 'umask 077 && cat >"$1"' _ "$mf" <"$new"
        ok "~/.config/mimeapps.list (${#MIME_DEFAULTS[@]} defaults)"
    fi
    rm -f -- "$ours" "$new"
}

do_apps() {
    step "User apps"
    do_home "${HOME_APPS[@]}"
    write_mimeapps
    local mime want got
    for mime in image/png=org.gnome.Loupe.desktop video/mp4=org.gnome.Showtime.desktop \
        application/pdf=org.gnome.Papers.desktop inode/directory=thunar.desktop \
        x-scheme-handler/https=librewolf.desktop text/plain=vim-foot.desktop; do
        want=${mime#*=}
        got=$(as_user xdg-mime query default "${mime%%=*}" 2>/dev/null || true)
        [[ $got == "$want" ]] || die "xdg-mime: ${mime%%=*} opens '$got', expected $want"
        [[ -f /usr/share/applications/$want || -f $THOME/.local/share/applications/$want ]] ||
            die "$want is not installed"
    done
    ok "xdg-mime defaults answer as mimeapps.list says"
}

do_games() {
    step "Games"
    save_sysctl "$REPO"/root/games/etc/sysctl.d/*.conf
    put_tree games
    try "sysctl -p 70-games.conf" sysctl -p /etc/sysctl.d/70-games.conf
}

pam_keyring() {
    local f=$1
    shift
    [[ -f $f ]] || die "$f missing"
    if grep -q pam_gnome_keyring "$f"; then
        skip "$f has pam_gnome_keyring"
        return 0
    fi
    put_text "$f" 0644 < <(
        cat -- "$f"
        printf '%s\n' "$@"
    )
}

do_session() {
    step "Session: keyring, polkit, bluetooth"
    [[ -f /usr/lib/security/pam_gnome_keyring.so ]] || die "pam_gnome_keyring.so missing"
    [[ -x /usr/libexec/polkit-gnome-authentication-agent-1 ]] || die "polkit-gnome agent missing"
    pam_keyring /etc/pam.d/login \
        'auth       optional     pam_gnome_keyring.so' \
        'session    optional     pam_gnome_keyring.so auto_start'
    pam_keyring /etc/pam.d/passwd \
        'password   optional     pam_gnome_keyring.so'
    gset plugin-list "['!StatusNotifierItem', '!StatusIcon']" org.blueman.general
    bt_conf
}

bt_conf() {
    local f=/etc/bluetooth/main.conf
    [[ -f $f ]] || die "$f missing (bluez)"
    # Name: shown to every device that scans, instead of the hostname
    # Privacy: a random address that changes, instead of the fixed one of the card
    put_text "$f" 0644 < <(ini_set "$f" \
        General/Name=Computer \
        General/Privacy=device \
        General/DiscoverableTimeout=30 \
        Policy/AutoEnable=false)
}
