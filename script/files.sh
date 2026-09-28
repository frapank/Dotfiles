# shellcheck shell=bash
# system files

backup() {
	local dst=$1
	[[ -z ${BACKED[$dst]:-} ]] || return 0
	BACKED[$dst]=1
	if [[ -e $dst || -L $dst ]]; then
		mkdir -p -- "$BAK/files${dst%/*}"
		cp -a -- "$dst" "$BAK/files$dst"
		jot restore "$dst"
	else
		jot remove "$dst"
	fi
}

mkdirs() {
	local d=$1 missing=()
	while [[ -n $d && ! -d $d ]]; do
		missing=("$d" "${missing[@]}")
		d=${d%/*}
	done
	for d in "${missing[@]}"; do
		install -d -o root -g root -m 0755 -- "$d"
		jot rmdir "$d"
	done
}

put() {
	local src=$1 dst=$2 mode=$3
	if [[ -f $dst && ! -L $dst ]] && cmp -s -- "$src" "$dst" &&
		[[ $(stat -c '%a %U %G' -- "$dst") == "${mode#0} root root" ]]; then
		skip "$dst"
		return 0
	fi
	mkdirs "${dst%/*}"
	backup "$dst"
	install -o root -g root -m "$mode" -- "$src" "$dst.pi-new"
	mv -f -- "$dst.pi-new" "$dst"
	ok "$dst ($mode)"
}

put_text() {
	local tmp
	tmp=$(mktemp -p "$BAK")
	cat >"$tmp"
	put "$tmp" "$1" "$2"
	rm -f -- "$tmp"
}

put_link() {
	local target=$1 dst=$2
	[[ -e $target ]] || die "$target does not exist"
	if [[ -L $dst && $(readlink -- "$dst") == "$target" ]]; then
		skip "$dst"
		return 0
	fi
	mkdirs "${dst%/*}"
	backup "$dst"
	ln -sfn -- "$target" "$dst.pi-new"
	mv -Tf -- "$dst.pi-new" "$dst"
	ok "$dst -> $target"
}

fix_perm() {
	local p=$1 mode=$2 cur
	cur=$(stat -c '%a %u:%g' -- "$p")
	[[ $cur != "${mode#0} 0:0" ]] || return 0
	jot perm "$p" "${cur% *}" "${cur#* }"
	chown root:root -- "$p"
	chmod "$mode" -- "$p"
	ok "$p ${cur% *} -> ${mode#0} root:root"
}

mode_for() {
	case $1 in
	/etc/nftables/* | /etc/sysctl.d/*) echo 0600 ;;
	/etc/sv/*/run | /etc/sv/*/finish | /usr/local/sbin/* | /usr/local/bin/* | /usr/local/libexec/*) echo 0755 ;;
	*) echo 0644 ;;
	esac
}

put_tree() {
	local src dst
	while IFS= read -r -d '' src; do
		dst=/${src#"$REPO/root/$1/"}
		put "$src" "$dst" "$(mode_for "$dst")"
	done < <(find "$REPO/root/$1" -type f -print0 | sort -z)
	while IFS= read -r -d '' src; do
		dst=/${src#"$REPO/root/$1/"}
		case $dst in
		/etc/sv/?* | /usr/share/plymouth/themes/?*) fix_perm "$dst" 0755 ;;
		esac
	done < <(find "$REPO/root/$1" -mindepth 1 -type d -print0 | sort -z)
}

# user files

stash() {
	if [[ -e $1 || -L $1 ]]; then
		as_user mkdir -p -m 0700 -- "$THOME/_backup"
		as_user mkdir -p -m 0700 -- "$UBAK"
		as_user mkdir -p -- "$UBAK${1%/*}"
		as_user cp -a -- "$1" "$UBAK$1"
		jot hrestore "$1"
	else
		jot hremove "$1"
	fi
}

move_aside() {
	[[ -e $1 || -L $1 ]] || return 0
	[[ -L $1 || $(readlink -f -- "$1") != "$REPO"/* ]] || die "$1 resolves into the repo, refusing to move it"
	as_user mkdir -p -m 0700 -- "$THOME/_backup"
	as_user mkdir -p -m 0700 -- "$UBAK"
	as_user mkdir -p -- "$UBAK${1%/*}"
	jot hmove "$1"
	as_user mv -- "$1" "$UBAK$1"
	ok "moved ${1/#$THOME/\~} to ${UBAK/#$THOME/\~}"
}

own() {
	[[ $(stat -c %U -- "$1") != "$TUSER" ]] || return 0
	jot hown "$1" "$(stat -c %u:%g -- "$1")"
	chown -- "$TUSER:$TGID" "$1"
	ok "${1/#$THOME/\~} now owned by $TUSER"
}

umkdir() {
	local d=$1 missing=()
	while [[ $d == "$THOME"/* && ! -d $d ]]; do
		missing=("$d" "${missing[@]}")
		d=${d%/*}
	done
	for d in "${missing[@]}"; do
		jot hrmdir "$d"
		as_user mkdir -m 0700 -- "$d"
	done
}

# services

sv_enable() {
	[[ -d /etc/sv/$1 ]] || die "service $1 not found in /etc/sv"
	if [[ -L $SVDIR/$1 && $(readlink -f -- "$SVDIR/$1") == "$(readlink -f -- "/etc/sv/$1")" ]] ||
		[[ -d $SVDIR/$1 && ! -L $SVDIR/$1 ]]; then
		skip "service $1"
		return 0
	fi
	if [[ -L $SVDIR/$1 ]]; then
		jot sv-on "$1" "$(readlink -- "$SVDIR/$1")"
		rm -f -- "$SVDIR/$1"
		warn "service $1 pointed elsewhere, relinked to /etc/sv/$1"
	fi
	jot sv-off "$1"
	ln -s -- "/etc/sv/$1" "$SVDIR/$1"
	ok "service $1 enabled"
}

sv_disable() {
	local s
	for s in "$@"; do
		[[ -L $SVDIR/$s ]] || continue
		jot sv-on "$s" "$(readlink -- "$SVDIR/$s")"
		rm -f -- "$SVDIR/$s"
		ok "service $s disabled"
	done
}

sv_refresh() {
	local s=$1 n on=0
	shift
	[[ $(sv status "$s" 2>/dev/null) == run:* ]] && on=1 && jot svr "$s"
	n=$(njot)
	"$@"
	((on && n != $(njot))) || return 0
	try "restart $s (files changed)" sv restart "$s"
}
