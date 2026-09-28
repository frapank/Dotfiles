# shellcheck shell=bash
# fonts and theme

fonts_ok() {
	[[ -d $1 && ! -L $1 ]] || return 1
	[[ -n $(find "$1" -type f \( -name '*.otf' -o -name '*.ttf' \) -print -quit) ]] || return 1
	[[ -z $(find "$1" \( -type l -o ! -user root -o ! -group root -o \
		-type f ! -perm 0644 -o -type d ! -perm 0755 \) -print -quit) ]]
}

git_at() {
	run "download ${2##*/} at ${3:0:12}" env GIT_TERMINAL_PROMPT=0 sh -c '
		git init -q "$1" && cd "$1" &&
		git fetch -q --depth 1 -- "$2" "$3" &&
		git -c advice.detachedHead=false checkout -q FETCH_HEAD' _ "$1" "$2" "$3"
	[[ $(git -C "$1" rev-parse HEAD) == "$3" ]] || die "$2 did not give commit $3"
	[[ -z $(find "$1" -path "$1/.git" -prune -o -type l -print -quit) ]] || die "symlinks in $2, refusing"
}

font_repo() {
	local url=$1 rev=$2 dir=$3 tmp f n=0 j mark=$STATE/fonts-${3##*/}
	if fonts_ok "$dir" && [[ $(cat -- "$mark" 2>/dev/null) == "$rev" ]]; then
		skip "$dir (${rev:0:12})"
		return 0
	fi
	[[ -d $dir && ! -L $dir ]] && fix_perm "$dir" 0755
	tmp=$(mktemp -d)
	git_at "$tmp/f" "$url" "$rev"
	j=$(njot)
	while IFS= read -r -d '' f; do
		put "$f" "$dir/${f##*/}" 0644
		n=$((n + 1))
	done < <(find "$tmp/f" -path "$tmp/f/.git" -prune -o -type f \( -name '*.otf' -o -name '*.ttf' \) -print0 | sort -z)
	rm -rf -- "$tmp"
	((n)) || die "no font files in $url"
	((j == $(njot))) || FONTS_NEW=1
	put_text "$mark" 0644 <<<"$rev"
}

do_fonts() {
	step "Fonts"
	local f
	font_repo "$FONT_URL" "$FONT_REV" "$SF_DIR"
	font_repo "$SFPRO_URL" "$SFPRO_REV" "$SFPRO_DIR"
	if ((FONTS_NEW)); then
		run "refresh the font cache" fc-cache -f
	else
		skip "font cache"
	fi
	do_home "${HOME_FONTS[@]}"
	f=$(as_user fc-match -f '%{family}' monospace 2>/dev/null || true)
	[[ $f == *"SF Mono"* ]] || die "monospace resolves to '$f', not SF Mono"
	ok "monospace is SF Mono"
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

legacy_icons() {
	local tmp stage mark=$STATE/adwaita-legacy
	if [[ -f $ICONS_DIR/index.theme && ! -L $ICONS_DIR && $(cat -- "$mark" 2>/dev/null) == "$ICONS_REV" ]] &&
		[[ -z $(find "$ICONS_DIR" \( -type l -o ! -user root -o ! -group root -o \
			-type f ! -perm 0644 -o -type d ! -perm 0755 \) -print -quit) ]]; then
		skip "$ICONS_DIR ($ICONS_TAG)"
		return 0
	fi
	tmp=$(mktemp -d)
	git_at "$tmp/src" "$ICONS_URL" "$ICONS_REV"
	[[ -f $tmp/src/index.theme && -d $tmp/src/AdwaitaLegacy/48x48 ]] || die "unexpected layout in $ICONS_URL"
	stage=$(mktemp -d -p "${ICONS_DIR%/*}" .AdwaitaLegacy.XXXXXX)
	cp -r -- "$tmp/src/AdwaitaLegacy/." "$stage/"
	cp -- "$tmp/src/index.theme" "$stage/index.theme"
	rm -rf -- "$tmp"
	rm -rf -- "$stage/cursors"
	chown -R root:root "$stage"
	find "$stage" -type d -exec chmod 0755 {} +
	find "$stage" -type f -exec chmod 0644 {} +
	if [[ -d $ICONS_DIR ]] && diff -rq -x icon-theme.cache "$stage" "$ICONS_DIR" >/dev/null; then
		rm -rf -- "$stage"
		skip "$ICONS_DIR"
	else
		backup "$ICONS_DIR"
		rm -rf -- "$ICONS_DIR"
		mv -T -- "$stage" "$ICONS_DIR"
		ok "$ICONS_DIR ($ICONS_TAG)"
		try "icon cache" gtk-update-icon-cache -f -q "$ICONS_DIR"
	fi
	put_text "$mark" 0644 <<<"$ICONS_REV"
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
	legacy_icons
	cursor_theme
	do_home "${HOME_THEME[@]}"
	[[ -d /usr/share/themes/Adwaita-dark/gtk-2.0 && -d /usr/share/themes/Adwaita-dark/gtk-3.0 ]] ||
		die "Adwaita-dark for GTK 2/3 missing (gnome-themes-extra, -gtk)"
	[[ -f /usr/lib/qt6/plugins/styles/adwaita.so && -f /usr/lib/qt5/plugins/styles/adwaita.so ]] ||
		die "adwaita-qt style plugins missing"
	as_user dbus-run-session gsettings get org.gnome.desktop.interface color-scheme >/dev/null 2>&1 ||
		die "gsettings cannot read org.gnome.desktop.interface"
	gset color-scheme "'prefer-dark'"
	gset gtk-theme "'Adwaita-dark'"
	gset icon-theme "'Adwaita'"
	gset cursor-theme "'Bibata-Modern-Classic'"
	gset cursor-size "$CURSOR_SIZE"
	gset font-name "'SF Mono 10'"
	gset document-font-name "'SF Mono 10'"
	gset monospace-font-name "'SF Mono 10'"
}
