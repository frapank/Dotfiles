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
    [[ $dst != /etc/systemd/* ]] || SD_RELOAD=1
    ok "$dst ($mode)"
}

put_text() {
    local tmp
    tmp=$(mktemp -p "$BAK")
    cat >"$tmp"
    put "$tmp" "$1" "$2"
    rm -f -- "$tmp"
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

# print the ini FILE with each SECTION/KEY=VALUE set: the first line with KEY in
# [SECTION], even commented out, becomes KEY=VALUE and the others are dropped;
# a missing KEY goes at the end of its section, a missing section at the end
ini_set() {
    local f=$1
    shift
    awk -v sets="$(printf '%s\n' "$@")" '
		BEGIN {
			n = split(sets, l, "\n")
			for (i = 1; i <= n; i++) {
				if (l[i] == "") continue
				j = index(l[i], "/")
				e = index(l[i], "=")
				sec = "[" substr(l[i], 1, j - 1) "]"
				key = substr(l[i], j + 1, e - j - 1)
				line[sec, key] = key "=" substr(l[i], e + 1)
				order[++m] = sec SUBSEP key
			}
		}
		function flush(sec, all,   i, k, hdr) {
			for (i = 1; i <= m; i++) {
				if (order[i] in done) continue
				split(order[i], k, SUBSEP)
				if (!all && k[1] != sec) continue
				if (all && !(k[1] in hdr)) {
					print "\n" k[1]
					hdr[k[1]] = 1
				}
				print line[order[i]]
				done[order[i]] = 1
			}
		}
		/^\[/ {
			flush(s, 0)
			s = $0
		}
		/^#?[[:space:]]*[A-Za-z0-9]+[[:space:]]*=/ {
			k = $0
			sub(/^#?[[:space:]]*/, "", k)
			sub(/[[:space:]]*=.*/, "", k)
			if ((s, k) in line) {
				if (!((s, k) in done)) print line[s, k]
				done[s, k] = 1
				next
			}
		}
		{ print }
		END {
			flush(s, 0)
			flush("", 1)
		}' "$f"
}

mode_for() {
    case $1 in
    /etc/nftables/* | /etc/sysctl.d/* | /etc/usbguard/*) echo 0600 ;;
    /etc/NetworkManager/dispatcher.d/* | /usr/local/sbin/* | /usr/local/bin/* | /usr/local/libexec/*) echo 0755 ;;
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
        /usr/share/plymouth/themes/?*) fix_perm "$dst" 0755 ;;
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

svc_reload() {
    ((SD_RELOAD)) || return 0
    run "systemd reads the changed units" systemctl daemon-reload
    SD_RELOAD=0
}

svc_enable() {
    local u=$1
    svc_reload
    [[ -n $(systemctl list-unit-files --no-legend -- "$u" 2>/dev/null) ]] || die "unit $u not found"
    if systemctl -q is-enabled -- "$u" 2>/dev/null; then
        skip "service $u"
    else
        jot svc-off "$u"
        run "enable $u" systemctl enable -- "$u"
    fi
    systemctl -q is-active -- "$u" && return 0
    jot svc-stop "$u"
    try "start $u" systemctl start -- "$u"
}

svc_disable() {
    local u
    for u in "$@"; do
        systemctl -q is-enabled -- "$u" 2>/dev/null || systemctl -q is-active -- "$u" || continue
        jot svc-on "$u"
        run "disable $u" systemctl disable --now -- "$u"
    done
}

svc_refresh() {
    local u=$1 n on=0
    shift
    systemctl -q is-active -- "$u" && on=1 && jot svr "$u"
    n=$(njot)
    "$@"
    svc_reload
    ((on && n != $(njot))) || return 0
    try "restart $u (files changed)" systemctl restart -- "$u"
}
