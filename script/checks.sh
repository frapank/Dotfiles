# shellcheck shell=bash
# checks

installed() { xbps-query -- "$1" >/dev/null 2>&1; }
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

    local id=
    [[ -r /etc/os-release ]] && id=$(. /etc/os-release && echo "${ID:-}")
    if [[ $id != void ]] || ! command -v xbps-install >/dev/null; then
        echo "error: this script is for Void Linux only" >&2
        exit 1
    fi

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

    bad=$(find "$REPO/home" "$REPO/root" "$REPO/src" "$REPO/script" \( -perm /022 -o \( ! -user "$TUSER" ! -user root \) \) -print -quit)
    [[ -z $bad ]] || die "unsafe owner or permissions: $bad (fix: chmod -R go-w '$REPO')"
    bad=$(find "$REPO/home" "$REPO/root" "$REPO/src" "$REPO/script" -type l -print -quit)
    [[ -z $bad ]] || die "symlink in the repo, refusing: $bad"
}

detect_hw() {
    local cpu d ven
    cpu=$(awk -F': ' '/^vendor_id/ { print $2; exit }' /proc/cpuinfo)
    case $cpu in
    GenuineIntel)
        HW_DESC+=("Intel CPU")
        HW_PKGS+=(intel-ucode)
        NONFREE=1
        ;;
    AuthenticAMD)
        HW_DESC+=("AMD CPU")
        HW_PKGS+=(linux-firmware-amd)
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
            HW_PKGS+=(mesa-dri vulkan-loader mesa-vulkan-intel intel-media-driver
                libva-intel-driver linux-firmware-intel)
            ;;
        0x1002)
            HW_DESC+=("AMD GPU")
            HW_PKGS+=(mesa-dri vulkan-loader mesa-vulkan-radeon mesa-vaapi linux-firmware-amd)
            ;;
        0x10de)
            HW_DESC+=("NVIDIA GPU (nouveau; the proprietary driver is not set up)")
            HW_PKGS+=(mesa-dri vulkan-loader mesa-vulkan-nouveau mesa-vaapi linux-firmware-nvidia)
            ;;
        *)
            HW_DESC+=("GPU vendor $ven (virtual or unknown): generic mesa")
            HW_PKGS+=(mesa-dri)
            ;;
        esac
    done
    HW_PKGS+=(libva-utils)
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

sig_check() {
    local t m
    m=$(awk '{ print $1; exit }' /proc/modules)
    [[ -z $m || -n $(modinfo -F sig_id -- "$m" 2>/dev/null) ]] ||
        die "harden: kernel modules are not signed, module.sig_enforce=1 would block them all"
    t=$(</proc/sys/kernel/tainted)
    ((!(t & 8192))) || die "harden: an unsigned module is loaded (tainted $t), module.sig_enforce=1 would block it"
    while IFS= read -r -d '' m; do
        [[ -n $(modinfo -F sig_id -- "$m" 2>/dev/null) ]] ||
            die "harden: ${m#/usr/lib/modules/} is not signed, module.sig_enforce=1 would block it"
    done < <(find /usr/lib/modules -name '*.ko*' \( -path '*/updates/*' -o -path '*/extra/*' \) -print0)
}

aa_on() { [[ ,$(cat /sys/kernel/security/lsm 2>/dev/null), == *,apparmor,* ]]; }

aa_lsm() {
    local l=
    [[ -r /sys/kernel/security/lsm ]] && l=$(</sys/kernel/security/lsm)
    [[ -n $l ]] || l=landlock,lockdown,yama,integrity,bpf
    l=,$l,
    l=${l//,capability,/,}
    l=${l//,apparmor,/,}
    l=${l#,}
    l=${l%,}
    echo "lsm=${l:+$l,}apparmor"
}

aa_check() {
    local line w lsm= n=0 bad
    bad=$(grep -oE '(^|,)(selinux|smack|tomoyo)(,|$)' /sys/kernel/security/lsm 2>/dev/null | tr -d , || true)
    [[ -z $bad ]] || die "apparmor: $bad is running, it cannot run next to AppArmor"
    [[ -f /etc/default/grub ]] || return 0
    line=$(grep -E '^GRUB_CMDLINE_LINUX(_DEFAULT)?=' /etc/default/grub || true)
    for w in $(grep -oE '(^|["[:space:]])(lsm|security|apparmor)=[^"[:space:]]*' <<<"$line" | tr -d '"' || true); do
        case $w in
        apparmor=1 | security=apparmor) ;;
        lsm=*) lsm=$w n=$((n + 1)) ;;
        *) die "apparmor: $w in /etc/default/grub, remove it first" ;;
        esac
    done
    ((n <= 1)) || die "apparmor: $n lsm= in /etc/default/grub, keep one"
    [[ -z $lsm || ,${lsm#lsm=}, == *,apparmor,* ]] && return 0
    grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub | grep -qE "[\"[:space:]]${lsm}[\"[:space:]]" ||
        die "apparmor: $lsm is in GRUB_CMDLINE_LINUX, add ',apparmor' to it yourself"
}
