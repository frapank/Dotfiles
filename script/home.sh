# shellcheck shell=bash
# home files and folders

# replace @HOME@ for programs that do not expand ~
home_render() {
    local esc=$THOME tmp
    grep -qF '@HOME@' -- "$1" || {
        echo "$1"
        return 0
    }
    esc=${esc//\\/\\\\}
    esc=${esc//&/\\&}
    esc=${esc//|/\\|}
    tmp=$(mktemp -p "$BAK")
    sed "s|@HOME@|$esc|g" -- "$1" >"$tmp"
    echo "$tmp"
}

do_home() {
    local pkg src rel dst mode part p parts out n=0
    for pkg in "$@"; do
        while IFS= read -r -d '' src; do
            rel=${src#"$REPO/home/$pkg/"}
            dst=$THOME/$rel
            p=$THOME
            parts=()
            [[ $rel == */* ]] && IFS=/ read -ra parts <<<"${rel%/*}"
            for part in "${parts[@]}"; do
                p=$p/$part
                [[ -L $p ]] && move_aside "$p"
                if [[ -d $p ]]; then own "$p"; fi
            done
            mode=0600
            [[ -x $src ]] && mode=0700
            out=$(home_render "$src")
            if [[ -f $dst && ! -L $dst ]] && cmp -s -- "$out" "$dst" &&
                [[ $(stat -c '%a %U' -- "$dst") == "${mode#0} $TUSER" ]]; then
                [[ $out == "$src" ]] || rm -f -- "$out"
                continue
            fi
            umkdir "${dst%/*}"
            if [[ -e $dst || -L $dst ]]; then
                move_aside "$dst"
            else
                jot hremove "$dst"
            fi
            if [[ $out == "$src" ]]; then
                as_user install -m "$mode" -- "$src" "$dst"
            else
                # root only file, passed on stdin
                as_user sh -c 'umask 077 && cat >"$1" && chmod "$2" -- "$1"' _ "$dst" "$mode" <"$out"
                rm -f -- "$out"
            fi
            n=$((n + 1))
        done < <(find "$REPO/home/$pkg" -type f -print0 | sort -z)
    done
    if ((n)); then ok "home: $* ($n file(s) installed)"; else skip "home: $*"; fi
}

do_home_cli() {
    step "Home: shell and editors"
    move_aside "$THOME/.vimrc"
    move_aside "$THOME/.tmux.conf"
    do_home "${HOME_CLI[@]}"
    bashrc_hook

    local sh
    sh=$(getent passwd "$TUSER" | cut -d: -f7)
    if [[ $sh == /bin/bash || $sh == /usr/bin/bash ]]; then
        skip "login shell bash"
    else
        jot shell "$TUSER" "$sh"
        usermod -s /bin/bash "$TUSER" >>"$LOG" 2>&1 || die "usermod -s failed"
        ok "login shell $sh -> /bin/bash"
    fi
}

# ~/.bashrc is left to the programs that add to it, it only sources ~/.bashrc_dotfile
bashrc_hook() {
    local rc=$THOME/.bashrc new
    if [[ -f $rc && ! -L $rc ]] && grep -qxF -- "$BASHRC_LINE" "$rc"; then
        skip "~/.bashrc sources ~/.bashrc_dotfile"
        return 0
    fi
    new=$(mktemp -p "$BAK")
    {
        printf '%s\n' "$BASHRC_LINE"
        if [[ -f $rc && ! -L $rc ]]; then
            # the old copy of the repo is now ~/.bashrc_dotfile, what came after it stays
            if grep -q '^unset -f _setup_history ' "$rc"; then
                awk 'done; /^unset -f _setup_history / { done = 1 }' "$rc"
            else
                cat -- "$rc"
            fi
        fi
    } >"$new"
    stash "$rc"
    as_user rm -f -- "$rc"
    as_user sh -c 'umask 077 && cat >"$1"' _ "$rc" <"$new"
    rm -f -- "$new"
    ok "~/.bashrc sources ~/.bashrc_dotfile"
}

do_dirs() {
    step "Home folders"
    do_home "${HOME_DIRS[@]}"
    local conf=$THOME/.config/user-dirs.dirs line path targets=() d t used
    while IFS= read -r line; do
        [[ $line =~ ^XDG_[A-Z]+_DIR=\"(.*)\"$ ]] || continue
        path=${BASH_REMATCH[1]}
        path=${path/#\$HOME/$THOME}
        [[ $path == "$THOME"/* ]] || {
            warn "$path is outside $THOME, not created"
            continue
        }
        targets+=("$path")
    done <"$conf"
    ((${#targets[@]})) || die "no folders in $conf"
    for d in "${XDG_DEFAULT_DIRS[@]}"; do
        d=$THOME/$d
        [[ -e $d || -L $d ]] || continue
        used=0
        for t in "${targets[@]}"; do
            [[ $t == "$d" || $t == "$d"/* ]] && used=1
        done
        ((used)) && continue
        if [[ -d $d && ! -L $d && -n $(ls -A -- "$d") ]]; then
            warn "${d/#$THOME/\~} is not empty, left where it is"
        else
            move_aside "$d"
        fi
    done
    for t in $(printf '%s\n' "${targets[@]}" | sort -u); do
        if [[ -d $t ]]; then
            skip "${t/#$THOME/\~}"
        else
            umkdir "$t"
            ok "created ${t/#$THOME/\~}"
        fi
    done
    [[ $(as_user xdg-user-dir PICTURES) == "$THOME"/* ]] || die "xdg-user-dir does not read the new user-dirs.dirs"
}
