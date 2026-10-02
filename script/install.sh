#!/usr/bin/env bash

set -Eeuo pipefail
umask 022
export LC_ALL=C
# run from /: children (dracut via zgrep, kernel hooks) are confined and cannot enter the user's 0700 home
[[ $PWD == / ]] || exec env -C / -u PWD "$(readlink -f -- "$0")" "$@"

# root sources the files next to this one: refuse them if someone else can change them
HERE=$(dirname -- "$(readlink -f -- "$0")")
if [[ -n $(find "$HERE" \( -perm /022 -o -type l -o \( ! -user root ! -uid "$(stat -c %u -- "$HERE")" \) \) -print -quit) ]]; then
    echo "error: files in $HERE are writable by others, owned by someone else or symlinks" >&2
    exit 1
fi
for f in config ui journal files checks plan system harden apparmor net boot maint home desktop theme; do
    # shellcheck source=/dev/null
    . "$HERE/$f.sh"
done
unset f

main() {
    while (($#)); do
        case $1 in
        -y | --yes) YES=1 ;;
        -u | --user)
            [[ -n ${2:-} ]] || {
                echo "error: $1 needs a USER" >&2
                exit 1
            }
            TUSER=$2
            shift
            ;;
        -h | --help) usage 0 ;;
        *)
            echo "unknown option: $1" >&2
            usage 1 >&2
            ;;
        esac
        shift
    done

    resolve_user
    [[ -t 0 ]] || ((YES)) || {
        echo "error: no terminal for the questions, use -y" >&2
        exit 1
    }

    exec 9>"$LOCK"
    flock -n 9 || {
        echo "error: ${0##*/} is already running" >&2
        exit 1
    }

    install -d -o root -g root -m 0700 -- "$BAK"
    install -o root -g root -m 0600 /dev/null "$LOG"
    : >"$BAK/journal"
    local k
    for k in "${SECTIONS[@]}"; do SEL[$k]=0; done

    trap on_signal INT TERM HUP
    trap 'on_err $LINENO "${BASH_SOURCE[0]##*/}"' ERR

    check_repo
    plan

    do_repos
    ((SEL[update])) && do_update
    do_packages
    ((SEL[hw])) && do_hw
    ((SEL[locale])) && do_locale
    ((SEL[harden])) && do_harden
    ((SEL[usb])) && do_usb
    ((SEL[apparmor])) && do_apparmor
    ((SEL[net])) && do_net_files
    do_groups
    ((SEL[logs])) && do_logs
    ((SEL[swap])) && do_swap
    ((SEL[maint])) && do_maint
    ((SEL[dirs])) && do_dirs
    ((SEL[maint])) && do_nosnap
    ((SEL[cli])) && do_home_cli
    ((SEL[desktop])) && do_g0wm
    ((SEL[media])) && do_media
    ((SEL[apps])) && do_apps
    ((SEL[games])) && do_games
    ((SEL[session])) && do_session
    ((SEL[fonts])) && do_fonts
    ((SEL[theme])) && do_theme
    ((SEL[boot])) && do_boot
    do_services
    do_post
    ((SEL[net])) && do_net_services
    verify
    ((SEL[doas])) && do_doas

    trap - ERR INT TERM HUP
    flush_skips
    rm -rf -- "${BAK:?}/boot"
    local n
    n=$(njot)
    if ((n == 0)); then
        rm -rf -- "$BAK"
        printf '\n%sDone.%s Nothing to change, already up to date.\n' "$C_G$C_B" "$C_0"
        printf '   log      %s\n' "$LOG"
        log "done, no changes"
        return 0
    fi
    printf '\n%sDone.%s %d change(s), reboot now.\n' "$C_G$C_B" "$C_0" "$n"
    printf '   log      %s\n   backups  %s\n' "$LOG" "$BAK"
    [[ ! -d $UBAK ]] || printf '   files    %s\n' "$UBAK"
    ((SEL[desktop] == 0)) || printf '   desktop  log in on tty1, g0wm starts by itself\n'
    ((SEL[apparmor] == 0)) || aa_on || printf '   apparmor on after the reboot, check with doas aa-status\n'
    log "done"
}

preflight "$@"
main "$@"
