# shellcheck shell=bash
# apparmor

do_apparmor() {
    step "AppArmor"
    local n f prof=()
    [[ -f /etc/runit/core-services/09-apparmor.sh ]] || die "runit-void-apparmor did not install 09-apparmor.sh"
    aa_on && jot aaload
    n=$(njot)
    put_tree apparmor
    # dotfiles-repo is left by older versions
    for f in /etc/apparmor.d/local/dotfiles-repo /etc/apparmor.d/abstractions/dotfiles/*; do
        [[ -e $f && ! -e $REPO/root/apparmor$f ]] || continue
        backup "$f"
        rm -f -- "$f"
        ok "removed $f (no longer in the repo)"
    done
    for f in "$REPO"/root/apparmor/etc/apparmor.d/*; do
        [[ -f $f ]] && prof+=("/etc/apparmor.d/${f##*/}")
    done
    run "AppArmor profiles compile" apparmor_parser -QK -- "${prof[@]}" /etc/apparmor.d/usr.bin.wpa_supplicant
    aa_wlsandbox
    aa_hmalloc
    aa_prune
    aa_cache
    if ! aa_on; then
        ok "profiles load at the next boot (AppArmor is not running yet)"
    elif ((n == $(njot))); then
        skip "AppArmor profiles loaded"
    else
        run "load the AppArmor profiles" apparmor_parser -r -- "${prof[@]}" /etc/apparmor.d/usr.bin.wpa_supplicant
        run "unload the profiles removed from /etc/apparmor.d" aa-remove-unknown
        try "compile the profile cache" apparmor_parser -QW -- /etc/apparmor.d
    fi
    aa_grub
}

aa_prune() {
    local f keep=" ${AA_KEEP[*]} " noext=() n=0
    while IFS= read -r f; do
        f=${f%% -> *}
        [[ $f == /etc/apparmor.d/* && $f != /etc/apparmor.d/*/* ]] || continue
        [[ $keep == *" ${f##*/} "* || ${f##*/} == README ]] && continue
        # the repo has its own steam
        [[ ! -e $REPO/root/apparmor$f ]] || continue
        noext+=("noextract=$f")
        [[ -e $f ]] || continue
        backup "$f"
        rm -f -- "$f"
        n=$((n + 1))
    done < <(xbps-query -f apparmor)
    ((${#noext[@]})) || die "no profiles listed for the apparmor package"
    for f in "$REPO"/root/apparmor/etc/apparmor.d/*; do
        [[ -f $f ]] && noext+=("noextract=/etc/apparmor.d/${f##*/}")
    done
    if ((n)); then ok "removed $n profiles of programs not installed"; else skip "unused profiles removed"; fi
    put_text /etc/xbps.d/30-apparmor-noextract.conf 0644 < <(printf '%s\n' "${noext[@]}")
}

aa_wlsandbox() {
    local tmp xml=/usr/share/wayland-protocols/staging/security-context/security-context-v1.xml
    [[ -f $xml ]] || die "$xml missing (wayland-protocols)"
    tmp=$(mktemp -d)
    run "build wl-sandbox" sh -c '
		cd "$1" &&
		wayland-scanner client-header "$2" security-context-v1-client-protocol.h &&
		wayland-scanner private-code "$2" security-context-v1-protocol.c &&
		cc -O2 -Wall -Wextra -Werror -I. -o wl-sandbox "$3" security-context-v1-protocol.c \
			$(pkg-config --cflags --libs wayland-client)' _ "$tmp" "$xml" "$REPO/src/wl-sandbox.c"
    put "$tmp/wl-sandbox" /usr/local/libexec/wl-sandbox 0755
    rm -rf -- "$tmp"
}

aa_hmalloc() {
    local tmp mark=$STATE/hardened-malloc
    if [[ -f $HMALLOC_LIB && ! -L $HMALLOC_LIB && $(cat -- "$mark" 2>/dev/null) == "$HMALLOC_REV" ]] &&
        [[ $(stat -c '%a %U %G' -- "$HMALLOC_LIB") == '755 root root' ]]; then
        skip "$HMALLOC_LIB (${HMALLOC_REV:0:12})"
        return 0
    fi
    tmp=$(mktemp -d)
    git_at "$tmp/src" "$HMALLOC_URL" "$HMALLOC_REV"
    run "build hardened_malloc (light)" make -C "$tmp/src" -j"$(nproc)" VARIANT=light CONFIG_WERROR=false
    run "hardened_malloc runs a program" env LD_PRELOAD="$tmp/src/out-light/${HMALLOC_LIB##*/}" /bin/true
    put "$tmp/src/out-light/${HMALLOC_LIB##*/}" "$HMALLOC_LIB" 0755
    rm -rf -- "$tmp"
    put_text "$mark" 0644 <<<"$HMALLOC_REV"
}

aa_cache() {
    local f=/etc/apparmor/parser.conf
    [[ -f $f ]] || die "$f missing"
    if grep -qE '^[[:space:]]*write-cache[[:space:]]*$' "$f"; then
        skip "$f: write-cache"
    else
        put_text "$f" 0644 < <(
            cat -- "$f"
            echo write-cache
        )
    fi
    install -d -m 0755 /var/cache/apparmor
}

aa_grub() {
    local cur
    cur=$(grep -E '^GRUB_CMDLINE_LINUX(_DEFAULT)?=' /etc/default/grub 2>/dev/null |
        grep -oE '["[:space:]]lsm=[a-z0-9_,]*' | tr -d '"[:space:]' || true)
    if [[ -n $cur && ,${cur#lsm=}, != *,apparmor,* ]]; then
        backup /etc/default/grub
        sed -i -E "/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/([\"[:space:]])$cur([\"[:space:]])/\1$cur,apparmor\2/" /etc/default/grub
        cur+=,apparmor
        grep '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub | grep -qF -- "$cur" || die "could not add apparmor to lsm= in /etc/default/grub"
        ok "GRUB: lsm= now ends in apparmor"
    fi
    grub_words "${cur:-$(aa_lsm)}"
}
