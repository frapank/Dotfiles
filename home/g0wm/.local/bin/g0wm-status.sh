#!/bin/sh
# shellcheck disable=SC2034,SC2154
set -u

warn() { printf 'g0wm-status.sh: %s\n' "$*" >&2; }

options() {
    while [ $# -gt 0 ]; do
        case $1 in
        -c | --config)
            shift
            [ $# -gt 0 ] || {
                warn '-c needs a file'
                exit 1
            }
            conf=$1
            ;;
        -1 | --once) once=1 ;;
        -h | --help)
            cat <<EOF
Usage: g0wm-status.sh [-1] [-c FILE] [SECONDS]

Prints the bar status line when it changes. The modules shown, their format
and how often each one is read (<module>_interval, in seconds) come from \$G0WM_STATUS_CONF, or from
\${XDG_CONFIG_HOME:-\$HOME/.config}/g0wm/status.conf, and fall back to the
built-in clock and battery when that file is missing. Run ./status_gen to
write it.

  -1, --once      print one line and exit
  -c, --config    read another config file
  SECONDS         seconds between battery reads (same as battery_interval)
EOF
            exit 0
            ;;
        -*)
            warn "unknown option '$1'"
            exit 1
            ;;
        *)
            case $1 in
            '' | *[!0-9]*)
                warn "unknown argument '$1'"
                exit 1
                ;;
            esac
            arg_battery_interval=$1
            ;;
        esac
        shift
    done
}

defaults() {
    all_modules='date time battery cpu ram netdown netup rec mic cam dns nightlight awake'
    modules='date time battery'
    module_defaults='date:60 time:1 battery:30 cpu:2 ram:2 net:2 rec:0.5 mic:1 cam:1 dns:5 nightlight:0.5 awake:0.5'
    interval=
    for m in $module_defaults; do eval "${m%%:*}_interval="; done
    prefix=' '
    separator=' '
    suffix=' '
    date_format='%a %d %b'
    time_format='%H:%M:%S'
    battery_format='%v%'
    cpu_format='cpu %v%'
    ram_format='ram %v%'
    netdown_format='down %v'
    netup_format='up %v'
    rec_format='%i'
    mic_format='%i'
    cam_format='%i'
    dns_format='%i'
    nightlight_format='%i'
    awake_format='%i'
    net_interface=
    icon_date=
    icon_time=
    icon_battery=
    icon_cpu=
    icon_ram=
    icon_netdown=
    icon_netup=
    icon_rec=
    icon_mic=
    icon_cam=
    icon_dns=
    icon_nightlight=
    icon_awake=
    all_colors='color_date color_time color_battery color_cpu color_ram
color_netdown color_netup color_battery_low color_battery_charging
color_rec color_mic color_cam color_dns color_nightlight color_awake'
    color_date=
    color_time=
    color_battery=
    color_cpu=
    color_ram=
    color_netdown=
    color_netup=
    color_rec=
    color_mic=
    color_cam=
    color_dns=
    color_nightlight=
    color_awake=
    battery_low=20
    color_battery_low=
    color_battery_charging=
}

is_color() { # true when the value is #RRGGBB or #RRGGBBAA
    case $1 in
    '#'[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) return 0 ;;
    '#'[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) return 0 ;;
    esac
    return 1
}

trim() {
    tr_s=$1
    while :; do
        case $tr_s in ' '* | '	'*) tr_s=${tr_s#?} ;; *) break ;; esac
    done
    while :; do
        case $tr_s in *' ' | *'	') tr_s=${tr_s%?} ;; *) break ;; esac
    done
}

read_config() { # reads $conf if present, then finalizes the timing settings
    if [ -f "$conf" ]; then
        lineno=0
        while IFS= read -r line || [ -n "$line" ]; do
            lineno=$((lineno + 1))
            trim "$line"
            line=$tr_s
            case $line in
            '' | '#'*) continue ;;
            *=*) ;;
            *)
                warn "$conf:$lineno: not a key=value line"
                continue
                ;;
            esac
            trim "${line%%=*}"
            key=$tr_s
            # quotes keep the spaces around a value, which the separator needs
            trim "${line#*=}"
            val=$tr_s
            case $val in
            '"'*'"') val=${val#\"} val=${val%\"} ;;
            esac
            case $key in
            modules | interval | battery_interval | prefix | separator | suffix | \
                date_interval | time_interval | cpu_interval | ram_interval | net_interval | \
                rec_interval | mic_interval | cam_interval | dns_interval | \
                nightlight_interval | awake_interval | \
                date_format | time_format | battery_format | cpu_format | ram_format | \
                netdown_format | netup_format | net_interface | icon_date | icon_time | \
                icon_battery | icon_cpu | icon_ram | icon_netdown | icon_netup | \
                color_date | color_time | color_battery | color_cpu | color_ram | \
                color_netdown | color_netup | battery_low | color_battery_low | \
                color_battery_charging | \
                rec_format | mic_format | cam_format | dns_format | nightlight_format | awake_format | \
                icon_rec | icon_mic | icon_cam | icon_dns | icon_nightlight | icon_awake | \
                color_rec | color_mic | color_cam | color_dns | color_nightlight | color_awake)
                # the name is one of the above, and the value is never re-parsed
                eval "$key=\$val"
                ;;
            *) warn "$conf:$lineno: unknown setting '$key'" ;;
            esac
        done <"$conf"
    fi

    [ -n "$arg_battery_interval" ] && battery_interval=$arg_battery_interval
    # interval sets every module without its own
    for rc_d in $module_defaults; do
        rc_m=${rc_d%%:*}
        eval "rc_v=\${${rc_m}_interval}"
        [ -n "$rc_v" ] || rc_v=${interval:-${rc_d#*:}}
        to_ms "$rc_v"
        if [ "$ms" -le 0 ]; then
            warn "${rc_m}_interval '$rc_v' is not a positive number, using ${rc_d#*:}"
            to_ms "${rc_d#*:}"
        fi
        eval "ivl_$rc_m=\$ms"
    done
    case $battery_low in
    '' | *[!0-9]*)
        warn "battery_low '$battery_low' is not a number, using 20"
        battery_low=20
        ;;
    esac

    # a colour the bar would not parse would be drawn as the literal ^c...^
    for rc_k in $all_colors; do
        eval "rc_v=\$$rc_k"
        [ -n "$rc_v" ] || continue
        is_color "$rc_v" ||
            {
                warn "$rc_k: '$rc_v' is not #RRGGBB or #RRGGBBAA"
                eval "$rc_k="
            }
    done

    # these are the user's own text, escaped here and not on every tick
    esc "$prefix"
    prefix=$ec
    esc "$separator"
    separator=$ec
    esc "$suffix"
    suffix=$ec
}

to_ms() { # seconds to ms, 0 when not a number
    case $1 in
    '' | .* | *. | *[!0-9.]* | *.*.*) ms=0 ;;
    *)
        tm_i=${1%%.*} tm_f=${1#"$tm_i"}
        tm_f=${tm_f#.}000
        tm_f=${tm_f%"${tm_f#???}"}
        while :; do
            case $tm_i in 0?*) tm_i=${tm_i#0} ;; *) break ;; esac
        done
        # the leading 1 keeps a fraction like 080 from being read as octal
        ms=$((tm_i * 1000 + 1$tm_f - 1000))
        ;;
    esac
}

now_ms() { # ms since boot into now
    read -r nm_u nm_rest </proc/uptime
    nm_i=${nm_u%.*} nm_f=${nm_u#*.}
    now=$((nm_i * 1000 + 1$nm_f * 10 - 1000))
}

esc() { # text -> ec, with every caret doubled so the bar draws it as one
    subst "$1" '^' '^^'
    ec=$sb
}

paint() { # text colour -> r, the text wrapped in a colour escape
    if [ -n "$2" ]; then
        r="^c$2^$1^d^"
    else
        r=$1
    fi
}

detect() { # have_date, battery_method, cpu_method, ram_method, net_method
    have_date=0
    command -v date >/dev/null 2>&1 && have_date=1

    battery_method=none
    bats=
    case $(uname -s 2>/dev/null) in
    Linux)
        for bat in /sys/class/power_supply/BAT*; do
            [ -d "$bat" ] && bats="$bats $bat/capacity"
        done
        [ -n "$bats" ] && battery_method=linux
        ;;
    FreeBSD)
        command -v sysctl >/dev/null 2>&1 && battery_method=freebsd
        ;;
    OpenBSD)
        if command -v apm >/dev/null 2>&1; then
            battery_method=openbsd
        else
            warn 'apm not found, battery status unavailable'
        fi
        ;;
    esac

    cpu_method=none
    if [ -r /proc/stat ]; then
        cpu_method=linux
    elif command -v sysctl >/dev/null 2>&1 &&
        [ -n "$(sysctl -n kern.cp_time 2>/dev/null)" ]; then
        cpu_method=sysctl
    fi

    ram_method=none
    [ -r /proc/meminfo ] && ram_method=linux

    net_method=none
    for f in /sys/class/net/*/statistics/rx_bytes; do
        [ -r "$f" ] && net_method=linux
        break
    done
    have_proc=0
    [ -r /proc/self/comm ] && have_proc=1
    have_uptime=0
    [ -r /proc/uptime ] && have_uptime=1

    # 127.0.0.1:53 is 0100007F:0035 in /proc/net/udp
    dns_sock=
    if [ -r /etc/resolv.conf ] && [ -r /proc/net/udp ]; then
        while read -r dt_k dt_v dt_rest; do
            [ "$dt_k" = nameserver ] || continue
            case $dt_v in
            127.*.*.*)
                dt_ifs=$IFS IFS=.
                # shellcheck disable=SC2086
                set -- $dt_v
                IFS=$dt_ifs
                dns_sock=$(printf '%02X%02X%02X%02X:0035' "$4" "$3" "$2" "$1")
                ;;
            esac
            break
        done </etc/resolv.conf
    fi

    if [ "$net_method" = none ] && command -v netstat >/dev/null 2>&1; then
        # FreeBSD reports byte counters here, OpenBSD lists packets only
        netstat -ibn 2>/dev/null | awk 'NR == 1 {
			for (i = 1; i <= NF; i++) {
				if ($i == "Ibytes") ib = i
				if ($i == "Obytes") ob = i
			}
			exit !(ib && ob)
		}' && net_method=netstat
    fi
}

# a module whose source is missing is dropped, so no field goes stale or empty
filter_modules() { # -> modules trimmed to what is available, and want_*
    kept=
    for m in $modules; do
        case $m in
        date | time)
            [ "$have_date" = 1 ] ||
                {
                    warn "'date' not found, $m disabled"
                    continue
                }
            ;;
        battery)
            [ "$battery_method" != none ] ||
                {
                    warn 'no battery found, battery disabled'
                    continue
                }
            ;;
        cpu)
            [ "$cpu_method" != none ] ||
                {
                    warn 'no cpu usage counter on this system, cpu disabled'
                    continue
                }
            ;;
        ram)
            [ "$ram_method" != none ] ||
                {
                    warn 'no memory counter on this system, ram disabled'
                    continue
                }
            ;;
        netdown | netup)
            [ "$net_method" != none ] ||
                {
                    warn "no network counters on this system, $m disabled"
                    continue
                }
            ;;
        rec | mic | cam | nightlight | awake)
            [ "$have_proc" = 1 ] ||
                {
                    warn "no /proc on this system, $m disabled"
                    continue
                }
            ;;
        dns)
            [ -n "$dns_sock" ] ||
                {
                    warn 'the resolver in /etc/resolv.conf is not local, dns disabled'
                    continue
                }
            ;;
        *)
            warn "unknown module '$m', known ones are: $all_modules"
            continue
            ;;
        esac
        if [ "$m" = rec ]; then
            kept="rec $kept"
        else
            kept="$kept $m"
        fi
    done
    modules=${kept# }
    modules=${modules% }
    [ -n "$modules" ] || warn 'no module left to show'

    groups=
    for m in $modules; do
        group_of "$m"
        case " $groups " in *" $grp "*) ;; *) groups="$groups $grp" ;; esac
    done

    want_battery=0 want_cpu=0 want_ram=0 want_net=0 want_date=0 want_time=0
    for m in $modules; do
        case $m in
        date) want_date=1 ;;
        time) want_time=1 ;;
        battery) want_battery=1 ;;
        cpu) want_cpu=1 ;;
        ram) want_ram=1 ;;
        netdown | netup) want_net=1 ;;
        esac
    done
}

group_of() { # modules read together share a group
    case $1 in
    date | time) grp=clock ;;
    netdown | netup) grp=net ;;
    *) grp=$1 ;;
    esac
}

subst() { # string token replacement -> sb
    sb= sb_rest=$1
    while :; do
        case $sb_rest in
        *"$2"*)
            sb=$sb${sb_rest%%"$2"*}$3
            sb_rest=${sb_rest#*"$2"}
            ;;
        *)
            sb=$sb$sb_rest
            return
            ;;
        esac
    done
}

human() { # bytes -> hu, as 1.2M with the unit appended
    if [ "$1" -ge 1073741824 ]; then
        hu=$(($1 * 10 / 1073741824)) hu_u=G
    elif [ "$1" -ge 1048576 ]; then
        hu=$(($1 * 10 / 1048576)) hu_u=M
    elif [ "$1" -ge 1024 ]; then
        hu=$(($1 * 10 / 1024)) hu_u=K
    else
        hu=${1}B
        return
    fi
    [ "$hu" -lt 10 ] && hu=0$hu
    hu=${hu%?}.${hu#"${hu%?}"}$hu_u
}

bat_caps= bat_charging=0
read_battery() {
    bat_caps= bat_charging=0
    case $battery_method in
    linux)
        for cap_file in $bats; do
            read -r cap <"$cap_file" 2>/dev/null &&
                bat_caps="$bat_caps $cap"
            read -r state <"${cap_file%capacity}status" 2>/dev/null &&
                [ "$state" = Charging ] && bat_charging=1
        done
        ;;
    freebsd)
        cap=$(sysctl -n hw.acpi.battery.life 2>/dev/null)
        [ -n "$cap" ] && [ "$cap" -ge 0 ] 2>/dev/null && bat_caps=$cap
        # bit 1 of the ACPI state word is the one set while it charges
        state=$(sysctl -n hw.acpi.battery.state 2>/dev/null)
        case ${state:-x} in
        '' | *[!0-9]*) ;;
        *) [ $((state & 2)) -ne 0 ] && bat_charging=1 ;;
        esac
        ;;
    openbsd)
        cap=$(apm -l 2>/dev/null)
        [ -n "$cap" ] && bat_caps=$cap
        # apm -a is 1 while the machine runs on mains
        [ "$(apm -a 2>/dev/null)" = 1 ] && bat_charging=1
        ;;
    esac
    bat_caps=${bat_caps# }
    return 0
}

bat_color() { # capacity -> bc, the colour its level and its state ask for
    bc=$color_battery
    if [ "$bat_charging" = 1 ]; then
        # charging outranks low: the level is on its way back up
        [ -n "$color_battery_charging" ] && bc=$color_battery_charging
    elif [ "$1" -le "$battery_low" ] 2>/dev/null; then
        [ -n "$color_battery_low" ] && bc=$color_battery_low
    fi
    return 0
}

bat_icon() { # capacity -> bi, picked out of icon_battery by level
    bi= bi_n=0
    for bi_g in $icon_battery; do bi_n=$((bi_n + 1)); done
    [ "$bi_n" -gt 0 ] || return 0
    bi_k=$(($1 * bi_n / 100 + 1))
    [ "$bi_k" -gt "$bi_n" ] && bi_k=$bi_n
    bi_i=0
    for bi_g in $icon_battery; do
        bi_i=$((bi_i + 1))
        [ "$bi_i" = "$bi_k" ] && {
            bi=$bi_g
            return
        }
    done
}

cpu_tot=0 cpu_idl=0 cpu_tot_prev=0 cpu_idl_prev=0 cpu_pct=0
cpu_sample() {
    case $cpu_method in
    linux)
        read -r cs_n cs_a cs_b cs_c cs_d cs_e cs_f cs_g cs_h cs_rest \
            </proc/stat || return 1
        : "${cs_e:=0}" "${cs_f:=0}" "${cs_g:=0}" "${cs_h:=0}"
        cpu_tot=$((cs_a + cs_b + cs_c + cs_d + cs_e + cs_f + cs_g + cs_h))
        cpu_idl=$((cs_d + cs_e))
        ;;
    sysctl)
        # idle is the last field of kern.cp_time on every BSD that has it
        # The split into fields is the point of the call.
        # shellcheck disable=SC2046
        set -- $(sysctl -n kern.cp_time 2>/dev/null)
        [ $# -gt 0 ] || return 1
        cpu_tot=0
        for cs_v in "$@"; do cpu_tot=$((cpu_tot + cs_v)); done
        eval "cpu_idl=\${$#}"
        ;;
    esac
}

read_cpu() {
    cpu_sample || return
    cs_dt=$((cpu_tot - cpu_tot_prev)) cs_di=$((cpu_idl - cpu_idl_prev))
    cpu_tot_prev=$cpu_tot cpu_idl_prev=$cpu_idl
    if [ "$cs_dt" -gt 0 ]; then
        cpu_pct=$(((cs_dt - cs_di) * 100 / cs_dt))
    else
        cpu_pct=0
    fi
    [ "$cpu_pct" -lt 0 ] && cpu_pct=0
    [ "$cpu_pct" -gt 100 ] && cpu_pct=100
    return 0
}

ram_pct=0 ram_used=0 ram_total=0
read_ram() {
    rm_t= rm_a= rm_f=
    while read -r rm_k rm_v rm_rest; do
        case $rm_k in
        MemTotal:) rm_t=$rm_v ;;
        MemAvailable:) rm_a=$rm_v ;;
        MemFree:) rm_f=$rm_v ;;
        esac
        [ -n "$rm_t" ] && [ -n "$rm_a" ] && break
    done </proc/meminfo
    # MemAvailable is missing on kernels older than 3.14
    [ -n "$rm_a" ] || rm_a=$rm_f
    [ -n "$rm_t" ] && [ -n "$rm_a" ] && [ "$rm_t" -gt 0 ] || return 1
    rm_u=$((rm_t - rm_a))
    ram_pct=$((rm_u * 100 / rm_t))
    human $((rm_u * 1024))
    ram_used=$hu
    human $((rm_t * 1024))
    ram_total=$hu
}

net_rx=0 net_tx=0 net_rx_prev=0 net_tx_prev=0 net_down=0B net_up=0B
net_sample() {
    net_rx=0 net_tx=0
    case $net_method in
    linux)
        for ns_d in /sys/class/net/*; do
            ns_i=${ns_d##*/}
            [ "$ns_i" = lo ] && continue
            if [ -n "$net_interface" ]; then
                case " $net_interface " in
                *" $ns_i "*) ;;
                *) continue ;;
                esac
            fi
            read -r ns_v <"$ns_d/statistics/rx_bytes" 2>/dev/null &&
                net_rx=$((net_rx + ns_v))
            read -r ns_v <"$ns_d/statistics/tx_bytes" 2>/dev/null &&
                net_tx=$((net_tx + ns_v))
        done
        ;;
    netstat)
        # one row per address, so only the first row of an interface counts
        eval "$(netstat -ibn 2>/dev/null | awk -v want="$net_interface" '
		NR == 1 {
			for (i = 1; i <= NF; i++) {
				if ($i == "Ibytes") ib = i
				if ($i == "Obytes") ob = i
			}
			next
		}
		!ib || !ob { next }
		$1 ~ /^lo/ { next }
		want != "" {
			ok = 0; n = split(want, w, " ")
			for (i = 1; i <= n; i++) if (w[i] == $1) ok = 1
			if (!ok) next
		}
		seen[$1]++ { next }
		{ rx += $ib; tx += $ob }
		END { printf "net_rx=%d net_tx=%d\n", rx, tx }')"
        ;;
    esac
}

read_net() {
    net_sample
    ns_drx=$((net_rx - net_rx_prev)) ns_dtx=$((net_tx - net_tx_prev))
    net_rx_prev=$net_rx net_tx_prev=$net_tx
    # a counter that went backwards wrapped, or its interface is gone
    [ "$ns_drx" -lt 0 ] && ns_drx=0
    [ "$ns_dtx" -lt 0 ] && ns_dtx=0
    rn_ms=$((now - net_at))
    [ "$rn_ms" -gt 0 ] || rn_ms=$ivl_net
    net_at=$now
    human $((ns_drx * 1000 / rn_ms))
    net_down=$hu
    human $((ns_dtx * 1000 / rn_ms))
    net_up=$hu
}

runs() {
    [ -r "$1" ] || return 1
    { read -r rs_p <"$1"; } 2>/dev/null || return 1
    case $rs_p in '' | *[!0-9]*) return 1 ;; esac
    { read -r rs_c <"/proc/$rs_p/comm"; } 2>/dev/null || return 1
    [ "$rs_c" = "$2" ]
}

mic_on() {
    for mo_f in /proc/asound/card*/pcm*c/sub*/status; do
        [ -r "$mo_f" ] || continue
        { read -r mo_k mo_v <"$mo_f"; } 2>/dev/null || continue
        [ "$mo_v" = RUNNING ] && return 0
    done
    return 1
}

dns_up() {
    while read -r du_n du_l du_r du_s du_rest; do
        [ "$du_l" = "$dns_sock" ] && [ "$du_s" = 07 ] && return 0
    done </proc/net/udp
    return 1
}

clk_date= clk_time= clk_ns=
read_clock() { # the last line is %N to wake just after the second
    case $want_date$want_time in
    11)
        subst "$date_format" '%i' "$icon_date"
        rk_d=$sb
        subst "$time_format" '%i' "$icon_time"
        rk=$(date "+$rk_d%n$sb%n%N")
        clk_date=${rk%%"$nl"*} rk=${rk#*"$nl"}
        clk_time=${rk%%"$nl"*} clk_ns=${rk#*"$nl"}
        ;;
    10)
        subst "$date_format" '%i' "$icon_date"
        rk=$(date "+$sb%n%N")
        clk_date=${rk%%"$nl"*} clk_ns=${rk#*"$nl"}
        ;;
    01)
        subst "$time_format" '%i' "$icon_time"
        rk=$(date "+$sb%n%N")
        clk_time=${rk%%"$nl"*} clk_ns=${rk#*"$nl"}
        ;;
    esac
}

update() { # read a group and set when it is due again
    case $1 in
    clock)
        read_clock
        ivl=$ivl_date
        [ "$want_time" = 1 ] && ivl=$ivl_time
        ;;
    battery)
        read_battery
        ivl=$ivl_battery
        ;;
    cpu)
        read_cpu
        ivl=$ivl_cpu
        ;;
    ram)
        read_ram
        ivl=$ivl_ram
        ;;
    net)
        read_net
        ivl=$ivl_net
        ;;
    *) eval "ivl=\$ivl_$1" ;;
    esac
    if [ "$1" != clock ]; then
        eval "nxt=\$((due_$1 + ivl))"
        [ "$nxt" -gt "$now" ] || nxt=$((now + ivl))
        eval "due_$1=\$nxt"
        return 0
    fi
    nxt=$((now + ivl))
    if [ "$ivl" -ge 1000 ]; then
        # BSD date prints N for %N
        case $clk_ns in
        [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]) nxt=$((nxt - 1${clk_ns%??????} + 1000 + 5)) ;;
        esac
    fi
    eval "due_$1=\$nxt"
}

fmt() {
    subst "$1" '%v' "$2"
    r=$sb
    subst "$r" '%i' "$3"
    r=$sb
}

render() {
    r=
    case $1 in
    date) r=$clk_date ;;
    time) r=$clk_time ;;
    battery)
        rn_all=
        for rn_c in $bat_caps; do
            bat_icon "$rn_c"
            fmt "$battery_format" "$rn_c" "$bi"
            esc "$r"
            bat_color "$rn_c"
            paint "$ec" "$bc"
            rn_all=${rn_all:+$rn_all }$r
        done
        r=$rn_all
        return 0
        ;;
    cpu) fmt "$cpu_format" "$cpu_pct" "$icon_cpu" ;;
    ram)
        fmt "$ram_format" "$ram_pct" "$icon_ram"
        subst "$r" '%u' "$ram_used"
        r=$sb
        subst "$r" '%t' "$ram_total"
        r=$sb
        ;;
    netdown) fmt "$netdown_format" "$net_down" "$icon_netdown" ;;
    netup) fmt "$netup_format" "$net_up" "$icon_netup" ;;
    rec) runs "$run_dir/record.pid" wf-recorder &&
        fmt "$rec_format" '' "$icon_rec" ;;
    mic) mic_on && fmt "$mic_format" '' "$icon_mic" ;;
    cam) [ -e /run/watchdog/cam ] && fmt "$cam_format" '' "$icon_cam" ;;
    dns) dns_up || fmt "$dns_format" '' "$icon_dns" ;;
    nightlight) runs "$run_dir/nightlight.pid" wlsunset &&
        fmt "$nightlight_format" '' "$icon_nightlight" ;;
    awake) runs "$run_dir/awake.pid" swayidle &&
        fmt "$awake_format" '' "$icon_awake" ;;
    esac
    [ -n "$r" ] || return 0
    eval "rn_col=\$color_$1"
    esc "$r"
    paint "$ec" "$rn_col"
}

main() {
    conf=${G0WM_STATUS_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/g0wm/status.conf}
    run_dir=${XDG_RUNTIME_DIR:-/tmp}
    nl='
'
    once=0
    arg_battery_interval=

    options "$@"
    defaults
    read_config
    detect
    filter_modules

    [ "$want_cpu" = 1 ] && cpu_sample && { cpu_tot_prev=$cpu_tot cpu_idl_prev=$cpu_idl; }
    [ "$want_net" = 1 ] && {
        net_sample
        net_rx_prev=$net_rx net_tx_prev=$net_tx
    }

    now=0
    [ "$have_uptime" = 1 ] && now_ms
    net_at=$now
    if [ "$once" = 1 ] && { [ "$want_cpu" = 1 ] || [ "$want_net" = 1 ]; }; then
        sleep 1
        now=$((now + 1000))
        [ "$have_uptime" = 1 ] && now_ms
    fi

    due_clock=
    for g in $groups; do eval "due_$g=\$now"; done
    last=
    while :; do
        for g in $groups; do
            # read groups due soon now so they share a wake
            early=0
            [ "$g" = clock ] || eval "early=\$((ivl_$g / 5))"
            eval "gd=\$due_$g"
            [ "$now" -ge "$((gd - early))" ] || continue
            update "$g"
            for m in $modules; do
                group_of "$m"
                [ "$grp" = "$g" ] || continue
                render "$m"
                eval "out_$m=\$r"
            done
        done

        # align the other groups to the clock
        if [ -z "$last" ] && [ -n "$due_clock" ]; then
            for g in $groups; do eval "due_$g=\$due_clock"; done
        fi

        line=
        for m in $modules; do
            eval "r=\$out_$m"
            [ -n "$r" ] || continue
            line=${line:+$line$separator}$r
        done
        # g0wm redraws the bar for every line
        if [ "$once" = 1 ] || [ "$line" != "$last" ]; then
            printf '%s%s%s\n' "$prefix" "$line" "$suffix"
            last=$line
        fi
        [ "$once" = 1 ] && break

        wait=
        for g in $groups; do
            eval "gd=\$due_$g"
            [ -z "$wait" ] || [ "$((gd - now))" -lt "$wait" ] && wait=$((gd - now))
        done
        [ -n "$wait" ] || wait=1000
        [ "$wait" -gt 10 ] || wait=10
        ws=$((wait % 1000))
        case $ws in ?) ws=00$ws ;; ??) ws=0$ws ;; esac
        sleep "$((wait / 1000)).$ws"
        now=$((now + wait))
        [ "$have_uptime" = 1 ] && now_ms
    done
}

main "$@"
