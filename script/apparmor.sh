# shellcheck shell=bash
# apparmor

do_apparmor() {
    step "AppArmor"
    local n f prof=()
    [[ -n $(systemctl list-unit-files --no-legend apparmor.service) ]] || die "apparmor did not install apparmor.service"
    svc_enable apparmor.service
    aa_on && jot aaload
    n=$(njot)
    put_tree apparmor
    for f in /etc/apparmor.d/abstractions/dotfiles/*; do
        [[ -e $f && ! -e $REPO/root/apparmor$f ]] || continue
        backup "$f"
        rm -f -- "$f"
        ok "removed $f (no longer in the repo)"
    done
    aa_disable
    for f in "$REPO"/root/apparmor/etc/apparmor.d/*; do
        [[ -f $f ]] && prof+=("/etc/apparmor.d/${f##*/}")
    done
    # Debian's chrony profile, with what local/usr.sbin.chronyd adds
    [[ ! -f /etc/apparmor.d/usr.sbin.chronyd ]] || prof+=(/etc/apparmor.d/usr.sbin.chronyd)
    run "AppArmor profiles compile" apparmor_parser -QK -- "${prof[@]}"
    run "aa-packages parses" sh -n /usr/local/libexec/aa-packages
    aa_wlsandbox
    aa_landlock
    aa_hmalloc
    aa_cache
    if ! aa_on; then
        ok "profiles load at the next boot (AppArmor is not running yet)"
    elif ((n == $(njot))); then
        skip "AppArmor profiles loaded"
    else
        run "load the AppArmor profiles" apparmor_parser -r -- "${prof[@]}"
        run "unload the disabled and removed profiles" aa-remove-unknown
        try "compile the profile cache" apparmor_parser -QW -- /etc/apparmor.d
    fi
    aa_grub
}

# the profiles of Debian and of the packages for the programs confined here: they attach
# to the same paths, or have the same name. disable/ is how Debian turns one off.
aa_disable() {
    local p
    for p in "${AA_DISABLE[@]}"; do
        [[ -f /etc/apparmor.d/$p ]] || continue
        if [[ -L /etc/apparmor.d/disable/$p ]]; then
            skip "AppArmor: Debian's $p disabled"
            continue
        fi
        mkdirs /etc/apparmor.d/disable
        jot remove "/etc/apparmor.d/disable/$p"
        ln -sfn -- "../$p" "/etc/apparmor.d/disable/$p"
        ok "AppArmor: Debian's $p disabled, the one here confines it"
    done
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

aa_landlock() {
    local tmp
    tmp=$(mktemp -d)
    run "build landlock-scope" cc -O2 -Wall -Wextra -Werror -o "$tmp/landlock-scope" "$REPO/src/landlock-scope.c"
    run "landlock-scope runs a program" "$tmp/landlock-scope" /bin/true
    put "$tmp/landlock-scope" /usr/local/libexec/landlock-scope 0755
    rm -rf -- "$tmp"
    [[ ,$(cat /sys/kernel/security/lsm 2>/dev/null), == *,landlock,* ]] ||
        warn "Landlock is not active now: landlock-scope works after a reboot with landlock in lsm="
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

# the last lsm= wins: the one of the drop-in, after /etc/default/grub
aa_grub() {
    grub_words "$(aa_lsm)"
}
