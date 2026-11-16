# shellcheck shell=bash
# checks

# one line per architecture (multiarch packages like libgl1-mesa-dri:i386), any installed counts
installed() { grep -qx installed <<<"$(dpkg-query -W -f='${db:Status-Status}\n' -- "$1" 2>/dev/null)"; }
# Include unpacked/half-configured packages too: a failed apt run can leave them.
package_list() {
    dpkg-query -W -f='${binary:Package}\t${db:Status-Status}\n' |
        awk '$2 != "not-installed" && $2 != "config-files" { print $1 }' | sort -u
}
in_group() { [[ " $(id -nG -- "$TUSER") " == *" $1 "* ]]; }
join() {
    local IFS=$1
    shift
    echo "$*"
}

preflight() {
    [[ " $* " != *" -h "* && " $* " != *" --help "* ]] || usage 0

    ((BASH_VERSINFO[0] >= 4)) || {
        echo "error: bash 4 or newer needed" >&2
        exit 1
    }

    local id= ver=
    [[ -r /etc/os-release ]] && read -r id ver < <(. /etc/os-release && echo "${ID:-} ${VERSION_ID:-0}")
    if [[ $id != debian ]] || ! command -v apt-get >/dev/null; then
        echo "error: this script is for Debian only" >&2
        exit 1
    fi
    ((${ver%%.*} >= 13)) 2>/dev/null || {
        echo "error: Debian 13 (trixie) or newer needed" >&2
        exit 1
    }

    if ((EUID != 0)); then
        local self
        self=$(readlink -f -- "$0")
        if command -v doas >/dev/null; then exec doas -- "$self" "$@"; fi
        if command -v sudo >/dev/null; then exec sudo -- "$self" "$@"; fi
        echo "error: needs root, and neither doas nor sudo is installed." >&2
        echo "       as root: su -c '$self -u $(id -un)'" >&2
        exit 1
    fi

    local c
    for c in setsid setpriv flock tac stat install fold; do
        command -v "$c" >/dev/null || {
            echo "error: $c not found" >&2
            exit 1
        }
    done
}

resolve_user() {
    TUSER=${TUSER:-${DOAS_USER:-${SUDO_USER:-}}}
    [[ -n $TUSER ]] || {
        echo "error: cannot tell who you are, pass -u USER" >&2
        exit 1
    }
    [[ $TUSER != root ]] || {
        echo "error: the target user must not be root" >&2
        exit 1
    }
    getent passwd "$TUSER" >/dev/null || {
        echo "error: no such user: $TUSER" >&2
        exit 1
    }
    THOME=$(getent passwd "$TUSER" | cut -d: -f6)
    TGID=$(id -g -- "$TUSER")
    [[ -d $THOME && $(stat -c %U -- "$THOME") == "$TUSER" ]] ||
        {
            echo "error: $THOME missing or not owned by $TUSER" >&2
            exit 1
        }
    UBAK=$THOME/_backup/$TS
    AS_USER=(setpriv --reuid="$TUSER" --regid="$TGID" --init-groups --
        env -i -C "$THOME" HOME="$THOME" USER="$TUSER" LOGNAME="$TUSER" SHELL=/bin/bash
        PATH="$THOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
        LANG="${LANG:-C.UTF-8}" TERM=dumb GIT_TERMINAL_PROMPT=0)
}

check_repo() {
    REPO=$(dirname -- "$(dirname -- "$(readlink -f -- "$0")")")
    [[ -d $REPO/home && -d $REPO/root && -d $REPO/src && -d $REPO/script ]] || die "$REPO does not look like the dotfiles repo"
    # folders confined apps can write to, see abstractions/dotfiles/app
    local w
    for w in Get Random Media; do
        [[ $REPO/ != "$THOME/$w"/* ]] ||
            die "$REPO is in ~/$w, where a sandboxed app could have changed it: clone it somewhere else"
    done

    local d=$REPO o bad
    while :; do
        o=$(stat -c %U -- "$d")
        [[ $o == root || $o == "$TUSER" ]] || die "$d is owned by $o, not by $TUSER or root"
        [[ $(stat -c %A -- "$d") != ????????w? ]] || die "$d is world-writable"
        [[ $d == / ]] && break
        d=$(dirname -- "$d")
    done

    bad=$(unsafe "$(id -u -- "$TUSER")" "$REPO/home" "$REPO/root" "$REPO/src" "$REPO/script")
    [[ -z $bad ]] || die "unsafe owner or permissions: $bad (fix: chmod -R go-w '$REPO')"
    bad=$(find "$REPO/home" "$REPO/root" "$REPO/src" "$REPO/script" -type l -print -quit)
    [[ -z $bad ]] || die "symlink in the repo, refusing: $bad"
    bad=$(find "$REPO/home" "$REPO/root" "$REPO/src" "$REPO/script" \( -name __pycache__ -o -name '*.pyc' \) -print -quit)
    [[ -z $bad ]] || die "python cache in the repo, it would be installed: $bad"
}

detect_hw() {
    local cpu d ven
    cpu=$(awk -F': ' '/^vendor_id/ { print $2; exit }' /proc/cpuinfo)
    case $cpu in
    GenuineIntel)
        HW_DESC+=("Intel CPU")
        HW_PKGS+=(intel-microcode)
        ;;
    AuthenticAMD)
        HW_DESC+=("AMD CPU")
        HW_PKGS+=(amd64-microcode)
        ;;
    *) HW_DESC+=("CPU ${cpu:-unknown}: no microcode") ;;
    esac
    for d in /sys/bus/pci/devices/*; do
        [[ -r $d/class ]] || continue
        [[ $(<"$d/class") == 0x03* ]] || continue
        ven=$(<"$d/vendor")
        case $ven in
        0x8086)
            HW_DESC+=("Intel GPU")
            HW_PKGS+=(libgl1-mesa-dri mesa-vulkan-drivers intel-media-va-driver
                i965-va-driver firmware-intel-graphics)
            ;;
        0x1002)
            HW_DESC+=("AMD GPU")
            HW_PKGS+=(libgl1-mesa-dri mesa-vulkan-drivers mesa-va-drivers firmware-amd-graphics)
            ;;
        0x10de)
            HW_DESC+=("NVIDIA GPU (nouveau; the proprietary driver is not set up)")
            HW_PKGS+=(libgl1-mesa-dri mesa-vulkan-drivers mesa-va-drivers firmware-nvidia-graphics)
            ;;
        *)
            HW_DESC+=("GPU vendor $ven (virtual or unknown): generic mesa")
            HW_PKGS+=(libgl1-mesa-dri)
            ;;
        esac
    done
    HW_PKGS+=(vainfo)
}

zram_size() {
    local kib mib
    kib=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)
    mib=$((kib / 1024))
    if ((mib <= 4096)); then
        ZRAM_PCT=100
    elif ((mib <= 8192)); then
        ZRAM_PCT=75
    elif ((mib <= 16384)); then
        ZRAM_PCT=50
    else
        ZRAM_PCT=25
    fi
    ZRAM_MIB=$((mib * ZRAM_PCT / 100))
    ((ZRAM_MIB <= 16384)) || ZRAM_MIB=16384
}

# why module.sig_enforce=1 would block a module, nothing if it would not
sig_problem() {
    local t m
    m=$(awk '{ print $1; exit }' /proc/modules)
    if [[ -n $m && -z $(modinfo -F sig_id -- "$m" 2>/dev/null) ]]; then
        echo "kernel modules are not signed, module.sig_enforce=1 would block them all"
        return 0
    fi
    t=$(</proc/sys/kernel/tainted)
    if ((t & 8192)); then
        echo "an unsigned module is loaded (tainted $t), module.sig_enforce=1 would block it"
        return 0
    fi
    while IFS= read -r -d '' m; do
        if [[ -z $(modinfo -F sig_id -- "$m" 2>/dev/null) ]]; then
            echo "${m#/usr/lib/modules/} is not signed, module.sig_enforce=1 would block it"
            return 0
        fi
    done < <(find /usr/lib/modules -name '*.ko*' \( -path '*/updates/*' -o -path '*/extra/*' \) -print0)
}

aa_on() { [[ ,$(cat /sys/kernel/security/lsm 2>/dev/null), == *,apparmor,* ]]; }

aa_lsm() {
    local l=
    [[ -r /sys/kernel/security/lsm ]] && l=$(</sys/kernel/security/lsm)
    [[ -n $l ]] || l=landlock,lockdown,yama,integrity,bpf
    l=,$l,
    # TOMOYO is in the Debian list, unused
    for x in capability apparmor selinux smack tomoyo; do l=${l//,$x,/,}; done
    l=${l#,}
    l=${l%,}
    echo "lsm=${l:+$l,}apparmor"
}

# why AppArmor cannot be turned on, nothing if it can; an lsm= of the user goes
# before the drop-in's, the last one wins
aa_problem() {
    local line w bad
    bad=$(grep -oE '(^|,)(selinux|smack)(,|$)' /sys/kernel/security/lsm 2>/dev/null | tr -d , || true)
    if [[ -n $bad ]]; then
        echo "$bad is running, it cannot run next to AppArmor"
        return 0
    fi
    [[ -f /etc/default/grub ]] || return 0
    line=$(grep -hE '^GRUB_CMDLINE_LINUX(_DEFAULT)?=' /etc/default/grub "$GRUB_D"/*.cfg 2>/dev/null || true)
    for w in $(grep -oE '(^|["[:space:]])(security|apparmor)=[^"[:space:]]*' <<<"$line" | tr -d '"' || true); do
        case $w in
        apparmor=1 | security=apparmor) ;;
        *)
            echo "$w on the kernel command line (/etc/default/grub), remove it first"
            return 0
            ;;
        esac
    done
}

# BLOCK[K]: why section K cannot be applied on this system
find_blocks() {
    local st r
    BLOCK=()
    if [[ $(stat -f -c %T /) != btrfs ]]; then
        BLOCK[maint]="/ is not btrfs"
    elif [[ $(stat -c %i /home) != 256 ]]; then
        if [[ $(stat -f -c %T /home) != btrfs || $(findmnt -no TARGET -T /home) != / ]]; then
            BLOCK[maint]="/home is not a btrfs subvolume, it cannot be snapshotted"
        elif pgrep -u "$TUSER" -x g0wm >/dev/null; then
            BLOCK[maint]="/home moves into a subvolume of its own: log out of g0wm, run this from a tty"
        fi
    fi
    st=$(passwd -S -- "$TUSER" | awk '{print $2}')
    [[ $st == P ]] || BLOCK[doas]="$TUSER has no usable password (passwd -S: $st), run 'passwd $TUSER' first"
    r=$(sig_problem)
    [[ -z $r ]] || BLOCK[harden]=$r
    if [[ -z ${BLOCK[harden]:-} && -n ${BLOCK[doas]:-} ]] && ! command -v doas >/dev/null && ! command -v sudo >/dev/null; then
        BLOCK[harden]="su loses setuid, and there is no doas or sudo to take its place"
    fi
    r=$(aa_problem)
    [[ -z $r ]] || BLOCK[apparmor]=$r
    return 0
}

usb_check() {
    [[ ! -e $STATE/usbguard ]] || return 0
    local kbd ptr miss
    read -r kbd ptr < <(awk '
		/^H: Handlers=/ {
			h = " " substr($0, 13) " "
			if (h ~ / kbd / && h ~ / leds /) k++
			if (h ~ / mouse[0-9]+ /) m++
		}
		END { print k + 0, m + 0 }' /proc/bus/input/devices)
    ((kbd && ptr)) && return 0
    if ((kbd == 0 && ptr == 0)); then
        miss="no keyboard and no mouse"
    elif ((kbd == 0)); then
        miss="no keyboard"
    else
        miss="no mouse or touchpad"
    fi
    warn "usb: $miss found. Once usbguard is on, one plugged in later stays blocked until allowed from the notification (with the mouse) or with 'doas usb allow' (with the keyboard)"
    ask_always "   turn usbguard on anyway?" && return 0
    SEL[usb]=0
    note "usb skipped"
}
