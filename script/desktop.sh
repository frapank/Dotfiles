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

# in a prefix of its own, with what it needs newer than Debian: only g0wm finds it, by its rpath
wlroots_build() {
    local tmp d name url rev stage mark=$STATE/wlroots
    if [[ -f $WLR_PREFIX/lib/pkgconfig/wlroots-0.20.pc && -f $WLR_PREFIX/lib/pkgconfig/scfg.pc && ! -L $WLR_PREFIX &&
        $(cat -- "$mark" 2>/dev/null) == "$WLR_REV ${WLR_DEPS[*]} $SCFG_REV" ]]; then
        skip "wlroots 0.20 and libscfg in $WLR_PREFIX"
        return 0
    fi
    tmp=$(mktemp -d)
    git_at "$tmp/wlroots" "$WLR_URL" "$WLR_REV"
    for d in "${WLR_DEPS[@]}"; do
        read -r name url rev <<<"$d"
        git_at "$tmp/wlroots/subprojects/$name" "$url" "$rev" links
    done
    # the libdrm of the drivers stays the system one, Mesa loads it; Debian's pixman
    # 0.44 passes the check of wlroots' top meson.build, not the 0.46 of its pixman renderer
    run "configure wlroots 0.20" env LDFLAGS="-Wl,-rpath,$WLR_PREFIX/lib" \
        meson setup "$tmp/build" "$tmp/wlroots" --prefix="$WLR_PREFIX" --libdir=lib \
        --buildtype=release --wrap-mode=nodownload -Dwerror=false \
        --force-fallback-for=wayland,libdrm,libxkbcommon,wayland-protocols,pixman \
        -Dexamples=false -Dbackends=drm,libinput -Dxwayland=enabled -Dicon_directory=/usr/share/icons \
        -Dwayland:dtd_validation=false -Dlibxkbcommon:xkb-config-root=/usr/share/X11/xkb \
        -Dlibxkbcommon:x-locale-root=/usr/share/X11/locale -Dlibdrm:intel=disabled \
        -Dlibdrm:radeon=disabled -Dlibdrm:amdgpu=disabled -Dlibdrm:nouveau=disabled -Dlibdrm:vmwgfx=disabled \
        -Dpixman:tests=disabled -Dpixman:demos=disabled -Dpixman:gtk=disabled -Dpixman:libpng=disabled \
        -Dpixman:openmp=disabled
    run "build wlroots 0.20" meson compile -C "$tmp/build"
    run "install wlroots 0.20 into a staging folder" meson install -C "$tmp/build" --destdir "$tmp/root" --quiet
    [[ -f $tmp/root$WLR_PREFIX/lib/pkgconfig/wlroots-0.20.pc ]] || die "the wlroots build left no wlroots-0.20.pc"
    git_at "$tmp/scfg" "$SCFG_URL" "$SCFG_REV"
    run "configure libscfg" env LDFLAGS="-Wl,-rpath,$WLR_PREFIX/lib" \
        meson setup "$tmp/scfg-build" "$tmp/scfg" --prefix="$WLR_PREFIX" --libdir=lib \
        --buildtype=release --wrap-mode=nodownload
    run "build libscfg" meson compile -C "$tmp/scfg-build"
    run "install libscfg into the staging folder" meson install -C "$tmp/scfg-build" --destdir "$tmp/root" --quiet
    [[ -f $tmp/root$WLR_PREFIX/lib/pkgconfig/scfg.pc ]] || die "the libscfg build left no scfg.pc"
    mkdirs "${WLR_PREFIX%/*}"
    stage=$(mktemp -d -p "${WLR_PREFIX%/*}" ".${WLR_PREFIX##*/}.XXXXXX")
    cp -a -- "$tmp/root$WLR_PREFIX/." "$stage/"
    rm -rf -- "$tmp"
    chown -R root:root "$stage"
    chmod 0755 "$stage"
    if [[ -e $WLR_PREFIX || -L $WLR_PREFIX ]]; then
        backup "$WLR_PREFIX"
        rm -rf -- "$WLR_PREFIX"
    else
        jot remove "$WLR_PREFIX"
    fi
    mv -T -- "$stage" "$WLR_PREFIX"
    ok "$WLR_PREFIX (wlroots ${WLR_REV:0:12}, libscfg ${SCFG_REV:0:12})"
    put_text "$mark" 0644 <<<"$WLR_REV ${WLR_DEPS[*]} $SCFG_REV"
    WLR_NEW=1
}

# what systemctl --user enable does, also when the user manager is not running
user_units() {
    local n w=$THOME/.config/systemd/user/g0wm-session.target.wants
    umkdir "$w"
    for n in "${USER_UNITS[@]}"; do
        if [[ -L $w/$n.service ]]; then
            skip "user unit $n enabled"
            continue
        fi
        [[ -e $w/$n.service ]] && move_aside "$w/$n.service"
        jot hremove "$w/$n.service"
        as_user ln -s -- "../$n.service" "$w/$n.service"
        ok "user unit $n starts with g0wm"
    done
    [[ ! -S /run/user/$(id -u -- "$TUSER")/systemd/private ]] ||
        try "the user manager reads the units" as_user env XDG_RUNTIME_DIR="/run/user/$(id -u -- "$TUSER")" systemctl --user daemon-reload
}

do_g0wm() {
    step "Desktop: g0wm"
    do_home "${HOME_DESKTOP[@]}"
    user_units
    put_tree logind

    local wp
    wp=$(awk '$1 == "wallpaper" { sub(/^[[:space:]]*wallpaper[[:space:]]*/, ""); gsub(/"/, ""); print; exit }' \
        "$THOME/.config/g0wm/config" 2>/dev/null || true)
    [[ -z $wp || -f $wp ]] || warn "wallpaper $wp does not exist, set it in ~/.config/g0wm/config"

    local src=$THOME/.local/src/g0wm bin=$THOME/.local/bin before= rev out where=
    wlroots_build
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
    if [[ -n $where && $before == "$rev" ]] && ((WLR_NEW == 0)); then
        skip "g0wm ${rev:0:12} installed"
        return 0
    fi

    # DT_RPATH, not RUNPATH: it also holds for the libraries wlroots and Mesa load
    run "configure g0wm" as_user sh -c 'cd "$1" && exec ./configure --wlroots-prefix="$2" --ldflags=-Wl,--disable-new-dtags' \
        _ "$src" "$WLR_PREFIX"
    # the Makefile asks pkg-config for libscfg and the rest itself, they are in the prefix too
    local pc=PKG_CONFIG_PATH=$WLR_PREFIX/lib/pkgconfig
    run "build g0wm" as_user env "$pc" make -C "$src" -j"$(nproc)"
    run "test g0wm" as_user env "$pc" make -C "$src" test
    stash "$bin/g0wm"
    run "install g0wm into ~/.local/bin" as_user env "$pc" make -C "$src" install
    do_home g0wm
    out=$(as_user "$bin/g0wm" -v 2>&1 || true)
    [[ $out == g0wm\ * ]] || die "the installed g0wm does not run: $out"
    ok "${out%%$'\n'*}"
}

do_media() {
    step "Screen sharing and audio"
    # Debian's user units start them, with the session
    [[ -f /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf ]] ||
        die "pipewire-alsa did not install its ALSA config"
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

write_thunar_prefs() {
    local tx=$THOME/.config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml new u
    new=$(mktemp -p "$BAK")
    {
        if [[ -f $tx ]]; then
            awk '/<property name="hidden-bookmarks"/ { if ($0 !~ /\/>/) skip = 1; next }
				skip { if (/<\/property>/) skip = 0; next }
				/<\/channel>/ { exit } { print }' "$tx"
        else
            printf '<?xml version="1.1" encoding="UTF-8"?>\n\n<channel name="thunar" version="1.0">\n'
        fi
        echo '  <property name="hidden-bookmarks" type="array">'
        for u in "${THUNAR_HIDDEN[@]}"; do
            printf '    <value type="string" value="%s"/>\n' "$u"
        done
        echo '  </property>'
        echo '</channel>'
    } >"$new"
    if [[ -f $tx && ! -L $tx ]] && cmp -s "$new" "$tx" &&
        [[ $(stat -c '%a %U' -- "$tx") == "600 $TUSER" ]]; then
        skip "${tx/#$THOME/\~}"
    else
        stash "$tx"
        as_user rm -f -- "$tx"
        umkdir "${tx%/*}"
        as_user sh -c 'umask 077 && cat >"$1"' _ "$tx" <"$new"
        ok "Thunar side pane hides ${THUNAR_HIDDEN[*]}"
    fi
    rm -f -- "$new"
}

# link the chrome folder of each profile to the theme
librewolf_chrome() {
    local base=$THOME/.config/librewolf/librewolf rel path dir n=0
    if [[ ! -f $base/profiles.ini ]]; then
        warn "no LibreWolf profile yet: start it once and run the apps section again for its theme"
        return 0
    fi
    while IFS=$'\t' read -r rel path; do
        [[ $rel == 1 ]] && path=$base/$path
        dir=$(readlink -f -- "$path") || continue
        [[ $dir == "$base"/* && -d $dir ]] || {
            warn "LibreWolf profile ${path/#$THOME/\~} is not in ${base/#$THOME/\~}, no theme there"
            continue
        }
        n=$((n + 1))
        if [[ -L $dir/chrome && $(readlink -- "$dir/chrome") == ../chrome ]]; then
            skip "${dir/#$THOME/\~}/chrome"
            continue
        fi
        if [[ -e $dir/chrome || -L $dir/chrome ]]; then
            move_aside "$dir/chrome"
        else
            jot hremove "$dir/chrome"
        fi
        as_user ln -s ../chrome "$dir/chrome"
        ok "${dir/#$THOME/\~}/chrome -> ../chrome"
    done < <(awk -F= '
		/^\[/ { if (p != "") print r "\t" p; p = ""; r = 0; prof = /^\[Profile[0-9]+\]/; next }
		prof && $1 == "IsRelative" { r = $2 }
		prof && $1 == "Path" { p = substr($0, 6) }
		END { if (p != "") print r "\t" p }' "$base/profiles.ini")
    ((n)) || warn "no LibreWolf profile in ${base/#$THOME/\~}/profiles.ini"
}

do_apps() {
    step "User apps"
    do_home "${HOME_APPS[@]}"
    librewolf_chrome
    write_mimeapps
    write_thunar_prefs
    # GTK reads it from gsettings, not settings.ini
    gset remember-recent-files false org.gnome.desktop.privacy
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
    [[ -f /usr/lib/x86_64-linux-gnu/security/pam_gnome_keyring.so ]] || die "pam_gnome_keyring.so missing"
    [[ -x /usr/libexec/polkit-mate-authentication-agent-1 ]] || die "mate-polkit agent missing"
    # the console login: the display managers of Debian have it, login does not
    pam_keyring /etc/pam.d/login \
        'auth       optional     pam_gnome_keyring.so' \
        'session    optional     pam_gnome_keyring.so auto_start'
    # the password change: pam-auth-update put it in common-password
    grep -q pam_gnome_keyring /etc/pam.d/common-password ||
        run "keyring follows password changes" pam-auth-update --package --enable gnome-keyring
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
