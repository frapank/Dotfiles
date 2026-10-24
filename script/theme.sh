# shellcheck shell=bash
# fonts and theme

fonts_ok() {
    [[ -d $1 && ! -L $1 ]] || return 1
    [[ -n $(find "$1" -type f \( -name '*.otf' -o -name '*.ttf' \) -print -quit) ]] || return 1
    [[ -z $(find "$1" \( -type l -o ! -user root -o ! -group root -o \
        -type f ! -perm 0644 -o -type d ! -perm 0755 \) -print -quit) ]]
}

# $4 links: symlinks are fine, the tree is only built
git_at() {
    run "download ${2##*/} at ${3:0:12}" env GIT_TERMINAL_PROMPT=0 sh -c '
		git init -q "$1" && cd "$1" &&
		git fetch -q --depth 1 -- "$2" "$3" &&
		git -c advice.detachedHead=false checkout -q FETCH_HEAD' _ "$1" "$2" "$3"
    [[ $(git -C "$1" rev-parse HEAD) == "$3" ]] || die "$2 did not give commit $3"
    [[ ${4:-} == links || -z $(find "$1" -path "$1/.git" -prune -o -type l -print -quit) ]] ||
        die "symlinks in $2, refusing"
}

font_dir() {
    local src=$1 dir=$2 ext=${3:-otf} f n=0
    [[ -d $dir && ! -L $dir ]] && fix_perm "$dir" 0755
    while IFS= read -r -d '' f; do
        put "$f" "$dir/${f##*/}" 0644
        n=$((n + 1))
    done < <(find "$src" -maxdepth 1 -type f -name "*.$ext" -print0 | sort -z)
    ((n)) || die "no .$ext font files in ${src##*/}"
}

geist() {
    local tmp j mark=$STATE/fonts-geist
    if fonts_ok "$GEIST_DIR" && fonts_ok "$GEIST_MONO_DIR" && [[ $(cat -- "$mark" 2>/dev/null) == "$GEIST_SHA256" ]]; then
        skip "Geist fonts"
        return 0
    fi
    tmp=$(mktemp -d)
    run "download ${GEIST_URL##*/}" curl -fsSLo "$tmp/geist.zip" "$GEIST_URL"
    [[ $(sha256sum -- "$tmp/geist.zip" | cut -d' ' -f1) == "$GEIST_SHA256" ]] ||
        die "${GEIST_URL##*/} does not match its sha256"
    run "unpack ${GEIST_URL##*/}" unzip -q "$tmp/geist.zip" 'geist-font/Geist/otf/*' 'geist-font/GeistMono/otf/*' -d "$tmp"
    j=$(njot)
    font_dir "$tmp/geist-font/Geist/otf" "$GEIST_DIR"
    font_dir "$tmp/geist-font/GeistMono/otf" "$GEIST_MONO_DIR"
    rm -rf -- "$tmp"
    ((j == $(njot))) || FONTS_NEW=1
    put_text "$mark" 0644 <<<"$GEIST_SHA256"
}

# not in Debian: the symbols only build of the Nerd Fonts release
nerd_symbols() {
    local tmp j mark=$STATE/fonts-nerd-symbols
    if fonts_ok "$NERD_DIR" && [[ $(cat -- "$mark" 2>/dev/null) == "$NERD_SHA256" ]]; then
        skip "Nerd Font symbols"
        return 0
    fi
    tmp=$(mktemp -d)
    run "download ${NERD_URL##*/}" curl -fsSLo "$tmp/nerd.tar.xz" "$NERD_URL"
    [[ $(sha256sum -- "$tmp/nerd.tar.xz" | cut -d' ' -f1) == "$NERD_SHA256" ]] ||
        die "${NERD_URL##*/} does not match its sha256"
    install -d -m 0700 "$tmp/nerd"
    run "unpack ${NERD_URL##*/}" tar -xJf "$tmp/nerd.tar.xz" -C "$tmp/nerd" --no-same-owner --no-same-permissions \
        SymbolsNerdFont-Regular.ttf SymbolsNerdFontMono-Regular.ttf
    j=$(njot)
    font_dir "$tmp/nerd" "$NERD_DIR" ttf
    rm -rf -- "$tmp"
    ((j == $(njot))) || FONTS_NEW=1
    put_text "$mark" 0644 <<<"$NERD_SHA256"
}

old_fonts() {
    local d
    for d in "${OLD_FONT_DIRS[@]}"; do
        [[ -e $d || -L $d ]] || continue
        backup "$d"
        rm -rf -- "$d"
        rm -f -- "$STATE/fonts-${d##*/}"
        ok "removed $d"
        FONTS_NEW=1
    done
}

font_is() {
    local f
    f=$(as_user fc-match -f '%{family[0]}' "$1" 2>/dev/null || true)
    [[ $f == "$2" ]] || die "$1 resolves to '$f', not $2"
    ok "$1 is $2"
}

do_fonts() {
    step "Fonts"
    geist
    nerd_symbols
    old_fonts
    if ((FONTS_NEW)); then
        run "refresh the font cache" fc-cache -f
    else
        skip "font cache"
    fi
    do_home "${HOME_FONTS[@]}"
    font_is monospace 'Geist Mono'
    font_is sans-serif Geist
    font_is serif Geist
    [[ -n $(as_user fc-list 'Symbols Nerd Font Mono' family 2>/dev/null) ]] ||
        die "Symbols Nerd Font Mono is not installed"
    ok "Nerd Font symbols available"
}

gset() {
    local old schema=${3:-org.gnome.desktop.interface}
    old=$(as_user dbus-run-session gsettings get "$schema" "$1")
    if [[ $old == "$2" ]]; then
        skip "gsettings $1"
        return 0
    fi
    jot gset "$1" "$old" "$schema"
    run "gsettings $1 $2" as_user dbus-run-session gsettings set "$schema" "$1" "$2"
}

# dpkg puts back the blue folders at every upgrade, the apt hook sets them again
papirus_icons() {
    local tmp places=${ICONS_DIR%/*}/Papirus/48x48/places keep=/var/lib/papirus-folders/keep
    [[ -f $ICONS_DIR/index.theme && -f $places/folder-$ICONS_COLOR.svg ]] ||
        die "Papirus-Dark or its $ICONS_COLOR folders missing (papirus-icon-theme)"
    if [[ -f $FOLDERS_BIN && $(stat -c '%a %U %G' -- "$FOLDERS_BIN") == '755 root root' &&
        $(cat -- "$STATE/papirus-folders" 2>/dev/null) == "$FOLDERS_REV" ]]; then
        skip "$FOLDERS_BIN ($FOLDERS_TAG)"
    else
        tmp=$(mktemp -d)
        git_at "$tmp/src" "$FOLDERS_URL" "$FOLDERS_REV"
        [[ -f $tmp/src/papirus-folders ]] || die "unexpected layout in $FOLDERS_URL"
        put "$tmp/src/papirus-folders" "$FOLDERS_BIN" 0755
        rm -rf -- "$tmp"
        put_text "$STATE/papirus-folders" 0644 <<<"$FOLDERS_REV"
    fi
    put_text /etc/apt/apt.conf.d/80-papirus-folders 0644 <<-EOF
		// the $ICONS_COLOR folders of Papirus again after dpkg
		DPkg::Post-Invoke { "if [ -x $FOLDERS_BIN ]; then $FOLDERS_BIN -R >/dev/null || true; fi"; };
	EOF
    if [[ $(readlink -- "$places/folder.svg") == "folder-$ICONS_COLOR.svg" &&
        $(cat -- "$keep" 2>/dev/null) == "theme=${ICONS_DIR##*/}"$'\n'"color=$ICONS_COLOR" ]]; then
        skip "folders in $ICONS_COLOR"
    else
        run "folders in $ICONS_COLOR" "$FOLDERS_BIN" -t "$ICONS_DIR" -C "$ICONS_COLOR"
    fi
    [[ $(readlink -- "$places/folder.svg") == "folder-$ICONS_COLOR.svg" ]] ||
        die "papirus-folders did not set $ICONS_COLOR"
    if [[ -e $OLD_ICONS_DIR || -L $OLD_ICONS_DIR ]]; then
        backup "$OLD_ICONS_DIR"
        rm -rf -- "$OLD_ICONS_DIR"
        rm -f -- "$STATE/adwaita-legacy"
        ok "removed $OLD_ICONS_DIR"
    fi
}

cursor_theme() {
    local tmp stage l name=${CURSOR_DIR##*/} mark=$STATE/cursor-${CURSOR_DIR##*/}
    if [[ -f $CURSOR_DIR/index.theme && ! -L $CURSOR_DIR && $(cat -- "$mark" 2>/dev/null) == "$CURSOR_SHA256 $CURSOR_COLORS" ]] &&
        [[ -z $(find "$CURSOR_DIR" \( ! -user root -o ! -group root -o \
            -type f ! -perm 0644 -o -type d ! -perm 0755 \) -print -quit) ]]; then
        skip "$CURSOR_DIR"
        return 0
    fi
    tmp=$(mktemp -d)
    run "download ${CURSOR_URL##*/}" curl -fsSLo "$tmp/cursor.tar.xz" "$CURSOR_URL"
    [[ $(sha256sum -- "$tmp/cursor.tar.xz" | cut -d' ' -f1) == "$CURSOR_SHA256" ]] ||
        die "${CURSOR_URL##*/} does not match its sha256"
    run "unpack ${CURSOR_URL##*/}" tar -xJf "$tmp/cursor.tar.xz" -C "$tmp" --no-same-owner --no-same-permissions
    [[ -f $tmp/$name/index.theme && -f $tmp/$name/cursors/left_ptr ]] || die "unexpected layout in ${CURSOR_URL##*/}"
    while IFS= read -r -d '' l; do
        [[ $(readlink -- "$l") =~ ^[A-Za-z0-9_-]+$ && -f ${l%/*}/$(readlink -- "$l") ]] ||
            die "symlink out of the theme in ${CURSOR_URL##*/}: ${l#"$tmp/"}"
    done < <(find "$tmp/$name" -type l -print0)
    run "recolor the cursors in the palette" python3 "$REPO/script/cursor-recolor.py" "$tmp/$name/cursors" "$CURSOR_COLORS"
    stage=$(mktemp -d -p "${CURSOR_DIR%/*}" ".$name.XXXXXX")
    cp -a -- "$tmp/$name/." "$stage/"
    rm -rf -- "$tmp"
    chown -Rh root:root "$stage"
    find "$stage" -type d -exec chmod 0755 {} +
    find "$stage" -type f -exec chmod 0644 {} +
    if [[ -d $CURSOR_DIR ]] && diff -rq --no-dereference "$stage" "$CURSOR_DIR" >/dev/null; then
        rm -rf -- "$stage"
        skip "$CURSOR_DIR"
    else
        backup "$CURSOR_DIR"
        rm -rf -- "$CURSOR_DIR"
        mv -T -- "$stage" "$CURSOR_DIR"
        ok "$CURSOR_DIR"
    fi
    put_text "$mark" 0644 <<<"$CURSOR_SHA256 $CURSOR_COLORS"
}

do_theme() {
    step "GTK theme"
    papirus_icons
    cursor_theme
    do_home "${HOME_THEME[@]}"
    [[ -d /usr/share/themes/Adwaita-dark/gtk-2.0 ]] ||
        die "Adwaita-dark for GTK 2 missing (gnome-themes-extra)"
    [[ -f $THOME/.local/share/themes/G0wm/gtk-3.0/gtk.css && -f $THOME/.local/share/themes/G0wm/gtk-4.0/gtk.css ]] ||
        die "G0wm GTK theme missing in ~/.local/share/themes"
    [[ -f /usr/lib/x86_64-linux-gnu/qt6/plugins/styles/libkvantum.so && -f /usr/lib/x86_64-linux-gnu/qt5/plugins/styles/libkvantum.so ]] ||
        die "Kvantum style plugins missing (kvantum)"
    [[ -f $THOME/.config/Kvantum/G0wm/G0wm.svg ]] || die "G0wm Kvantum theme missing in ~/.config/Kvantum"
    [[ -f /usr/lib/x86_64-linux-gnu/qt6/plugins/platformthemes/libqt6ct.so ]] || die "qt6ct platform theme missing (qt6ct)"
    as_user dbus-run-session gsettings get org.gnome.desktop.interface color-scheme >/dev/null 2>&1 ||
        die "gsettings cannot read org.gnome.desktop.interface"
    gset color-scheme "'prefer-dark'"
    gset gtk-theme "'G0wm'"
    gset icon-theme "'${ICONS_DIR##*/}'"
    gset cursor-theme "'Bibata-Modern-Classic'"
    gset cursor-size "$CURSOR_SIZE"
    gset font-name "'Geist 11'"
    gset document-font-name "'Geist 11'"
    gset monospace-font-name "'Geist Mono 11'"
}
