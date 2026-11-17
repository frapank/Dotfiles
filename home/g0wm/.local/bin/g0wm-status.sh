#!/bin/bash
# The status line of g0wm's bar: one line on stdout each time it changes.
#
# bash for its builtins: the clock (printf %()T), the epoch, the waits (read -t)
# and the formatting need no process, so a tick starts none. Processes are left
# to the modules that have to ask another program (wpctl, pactl, pgrep,
# bluetoothctl), at their own interval or on an event.
set -u
shopt -s nullglob

warn() { printf 'g0wm-status.sh: %s\n' "$*" >&2; }

usage() {
    cat <<EOF
Usage: g0wm-status.sh [-1] [-c FILE] [SECONDS]

Prints the bar status line when it changes. The modules shown, their format
and how often each one is read (<module>_interval, in seconds) come from
\$G0WM_STATUS_CONF, or from \${XDG_CONFIG_HOME:-\$HOME/.config}/g0wm/status.conf,
and fall back to the built-in clock and battery when that file is missing.

  -1, --once      print one line and exit
  -c, --config    read another config file
  SECONDS         seconds between battery reads (same as battery_interval)

In a format %v is the value and %i the icon; ram has %u and %t too, date and
time are strftime formats. <module>_click_left, _click_middle, _click_right,
_scroll_up and _scroll_down run a command when the module is clicked or
scrolled in the bar. SIGUSR1 reads volume, mic, rec, timer, usbwait,
nightlight and awake again at once: osd, record, timer and the nightlight and
idle services send it after a change. With pactl, a change of the volume, the
output or the microphone is read at once too.
EOF
}

# ---- the modules ------------------------------------------------------------

# in the order of the help; rec is drawn first, whatever the order of modules
ALL=(date time battery volume cpu ram netdown netup rec mic cam dns maint timer
    reboot btbattery usbwait nightlight awake)
# default interval in seconds, per group: modules read together share one
declare -A IVL=([clock]=1 [battery]=30 [volume]=2 [cpu]=2 [ram]=2 [net]=2
    [rec]=1 [mic]=1 [cam]=1 [dns]=5 [maint]=60 [timer]=1 [reboot]=300
    [btbattery]=60 [usbwait]=5 [nightlight]=0.5 [awake]=0.5)
group() {
    case $1 in
    date | time) g=clock ;;
    netdown | netup) g=net ;;
    *) g=$1 ;;
    esac
}
# read again at once on SIGUSR1
KICKED=(volume mic rec timer usbwait nightlight awake)

# every setting status.conf may hold, with its default: a key not here is
# unknown. date_interval and time_interval both set the clock group
declare -A C=([modules]='date time battery' [interval]='' [prefix]=' '
    [separator]=' ' [suffix]=' ' [net_interface]='' [battery_low]=20
    [date_format]='%a %d %b' [time_format]='%H:%M:%S' [battery_format]='%v%'
    [volume_format]='%i %v%' [cpu_format]='cpu %v%' [ram_format]='ram %v%'
    [netdown_format]='down %v' [netup_format]='up %v' [timer_format]='%i %v'
    [btbattery_format]='%i %v%' [color_battery_low]='' [color_battery_charging]=''
    [icon_battery_charging]='' [icon_volume_muted]='' [icon_volume_phones]=''
    [icon_mic_muted]='')
for m in "${ALL[@]}"; do
    : "${C[${m}_format]:=%i}"
    C[icon_$m]='' C[color_$m]=''
    for b in click_left click_middle click_right scroll_up scroll_down; do C[${m}_$b]=''; done
done
for g in "${!IVL[@]}" date time; do C[${g}_interval]=''; done
unset 'C[clock_interval]'
# g0wm's numbers for the buttons of a ^sN!command^ area, 4 and 5 the wheel
BUTTONS=([1]=click_left [2]=click_right [3]=click_middle [4]=scroll_up [5]=scroll_down)

# ---- settings ---------------------------------------------------------------

to_ms() { # seconds -> ms, 0 when not a number
    ms=0
    [[ $1 =~ ^([0-9]+)(\.([0-9]{1,3}))?[0-9]*$ ]] || return 0
    local f=${BASH_REMATCH[3]}000
    ms=$((10#${BASH_REMATCH[1]} * 1000 + 10#${f:0:3}))
}

read_config() {
    local n=0 line k v
    if [[ -f $conf ]]; then
        while IFS= read -r line || [[ -n $line ]]; do
            ((n++))
            line=${line#"${line%%[![:space:]]*}"} line=${line%"${line##*[![:space:]]}"}
            [[ -z $line || $line == '#'* ]] && continue
            if [[ $line != *=* ]]; then
                warn "$conf:$n: not a key=value line"
                continue
            fi
            k=${line%%=*} v=${line#*=}
            k=${k%"${k##*[![:space:]]}"} v=${v#"${v%%[![:space:]]*}"}
            # quotes keep the spaces around a value, which the separator needs
            [[ $v == \"*\" ]] && v=${v:1:-1}
            if [[ ! -v C[$k] ]]; then
                warn "$conf:$n: unknown setting '$k'"
            elif [[ $k == *_click_* || $k == *_scroll_* ]] && [[ $v == *^* ]]; then
                # a caret would end the command early in the bar
                warn "$conf:$n: $k cannot contain '^'"
            else
                C[$k]=$v
            fi
        done <"$conf"
    fi
    [[ -n $arg_battery ]] && C[battery_interval]=$arg_battery

    # interval sets every group without its own; the clock follows time, else date
    local g d key def
    for g in "${!IVL[@]}"; do
        key=${g}_interval def=${IVL[$g]}
        if [[ $g == clock && " ${C[modules]} " == *" time "* ]]; then
            key=time_interval def=1
        elif [[ $g == clock ]]; then
            key=date_interval def=60
        fi
        v=${C[$key]:-${C[interval]:-$def}}
        to_ms "$v"
        if ((ms <= 0)); then
            warn "$key '$v' is not a positive number, using $def"
            to_ms "$def"
        fi
        ivl[$g]=$ms
    done
    if [[ ! ${C[battery_low]} =~ ^[0-9]+$ ]]; then
        warn "battery_low '${C[battery_low]}' is not a number, using 20"
        C[battery_low]=20
    fi
    # a colour the bar could not parse would be drawn as the literal ^c...^
    for k in "${!C[@]}"; do
        [[ $k == color_* && -n ${C[$k]} ]] || continue
        [[ ${C[$k]} =~ ^#([[:xdigit:]]{6}|[[:xdigit:]]{8})$ ]] && continue
        warn "$k: '${C[$k]}' is not #RRGGBB or #RRGGBBAA"
        C[$k]=
    done
    # the user's own text: escaped once here, not on every tick
    for k in prefix separator suffix; do C[$k]=${C[$k]//'^'/'^^'}; done
    # the clickable area of each module, closed by render
    for m in "${ALL[@]}"; do
        area[$m]=
        for b in "${!BUTTONS[@]}"; do
            d=${C[${m}_${BUTTONS[$b]}]}
            [[ -n $d ]] && area[$m]+="^s$b!$d^"
        done
    done
}

# ---- what this system has ---------------------------------------------------

detect() {
    bats=()
    local p t
    local s
    for p in /sys/class/power_supply/*; do
        { read -r t <"$p/type"; } 2>/dev/null && [[ $t == Battery && -r $p/capacity ]] || continue
        # the battery of a mouse or a keyboard is a Device one, not the system's
        s=System && { read -r s <"$p/scope"; } 2>/dev/null
        [[ $s == Device ]] || bats+=("$p")
    done
    have_wpctl=0 have_pactl=0
    command -v wpctl >/dev/null && have_wpctl=1
    command -v pactl >/dev/null && have_pactl=1
    modules_dir=
    for p in /usr/lib/modules /lib/modules; do [[ -d $p ]] && modules_dir=$p && break; done
    # 127.0.0.1:53 is 0100007F:0035 in /proc/net/udp
    dns_sock=
    local k v
    if [[ -r /etc/resolv.conf && -r /proc/net/udp ]]; then
        while read -r k v _; do
            [[ $k == nameserver ]] || continue
            if [[ $v =~ ^127\.([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
                printf -v dns_sock '%02X%02X%02X7F:0035' "${BASH_REMATCH[3]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[1]}"
            fi
            break
        done </etc/resolv.conf
    fi
}

# a module whose source is missing is dropped, so no field goes stale or empty
filter_modules() {
    local m why kept=() first=()
    for m in ${C[modules]}; do
        why=
        case $m in
        date | time | cpu | ram | maint | timer | usbwait) ;;
        battery) ((${#bats[@]})) || why='no battery found' ;;
        volume) ((have_wpctl || have_pactl)) || why='neither wpctl nor pactl found' ;;
        netdown | netup) [[ -d /sys/class/net ]] || why='no /sys/class/net' ;;
        rec | mic | cam | nightlight | awake) [[ -r /proc/self/comm ]] || why='no /proc' ;;
        btbattery) command -v bluetoothctl >/dev/null || why='no bluetoothctl' ;;
        reboot) [[ -n $modules_dir ]] || why='no /usr/lib/modules' ;;
        dns) [[ -n $dns_sock ]] || why='the resolver in /etc/resolv.conf is not local' ;;
        *) why="unknown, the known ones are: ${ALL[*]}" ;;
        esac
        if [[ -n $why ]]; then
            warn "$m: $why, left out"
        elif [[ $m == rec ]]; then
            first=(rec)
        else
            kept+=("$m")
        fi
    done
    modules=("${first[@]}" "${kept[@]}")
    ((${#modules[@]})) || warn 'no module left to show'
    groups=()
    declare -gA members=()
    for m in "${modules[@]}"; do
        group "$m"
        [[ -v members[$g] ]] || groups+=("$g")
        members[$g]+=" $m"
    done
}

# ---- helpers ----------------------------------------------------------------

now_ms() { # ms since boot: the uptime goes on during a suspend, as the timers
    local u
    if read -r u _ </proc/uptime 2>/dev/null; then
        now=$((${u%.*} * 1000 + 10#${u#*.} * 10))
    else
        now=$((${EPOCHREALTIME/./} / 1000))
    fi
}

human() { # bytes -> hu, as 1.2M
    local b=$1 u
    if ((b >= 1 << 30)); then
        u=G b=$((b * 10 >> 30))
    elif ((b >= 1 << 20)); then
        u=M b=$((b * 10 >> 20))
    elif ((b >= 1 << 10)); then
        u=K b=$((b * 10 >> 10))
    else
        hu=${b}B
        return
    fi
    hu=$((b / 10)).$((b % 10))$u
}

clock_text() { # seconds -> ct, as 4:32 or 1:02:03
    if (($1 >= 3600)); then
        printf -v ct '%d:%02d:%02d' $(($1 / 3600)) $(($1 % 3600 / 60)) $(($1 % 60))
    else
        printf -v ct '%d:%02d' $(($1 / 60)) $(($1 % 60))
    fi
}

level_icon() { # "icons" percent [round] -> bi, the icon of that level
    local -a set
    read -ra set <<<"$1"
    local n=${#set[@]} k
    bi=
    ((n)) || return 0
    # equal bands, or with round the nearest of the levels 0..100
    if [[ ${3:-} == round ]]; then
        k=$((($2 * (n - 1) + 50) / 100))
    else
        k=$(($2 * n / 100))
    fi
    ((k >= n)) && k=$((n - 1))
    bi=${set[k]}
}

runs() { # pidfile comm: true while the pid in it is that program -> rs_p
    rs_p=
    local c
    { read -r rs_p <"$1" && read -r c <"/proc/$rs_p/comm"; } 2>/dev/null && [[ $c == "$2" ]]
}

# ---- readers ----------------------------------------------------------------

read_clock() {
    local t=$EPOCHSECONDS f
    f=${C[date_format]//'%i'/${C[icon_date]}}
    printf -v clk_date "%($f)T" "$t"
    f=${C[time_format]//'%i'/${C[icon_time]}}
    printf -v clk_time "%($f)T" "$t"
}

read_battery() {
    bat_caps=() bat_charging=0
    local p v s
    for p in "${bats[@]}"; do
        { read -r v <"$p/capacity"; } 2>/dev/null && [[ $v =~ ^[0-9]+$ ]] && bat_caps+=("$v")
        { read -r s <"$p/status"; } 2>/dev/null && [[ $s == Charging ]] && bat_charging=1
    done
}

# the default sink is headphones: the active port of the jack, or the form
# factor of a bluetooth one. Asked on a pactl event (plugging them in changes
# the card), else every phones_every ms
read_phones() {
    phones_at=$now vol_phones=0
    ((have_pactl)) && [[ -n ${C[icon_volume_phones]} ]] || return 0
    local sink line mine=0
    sink=$(pactl get-default-sink 2>/dev/null) || return 0
    while IFS= read -r line; do
        case $line in
        'Sink #'*) mine=0 ;;
        *'Name: '*) [[ ${line#*Name: } == "$sink" ]] && mine=1 ;;
        *'Active Port: '*[Hh]ead[ps]* | *'device.form_factor = "head'[ps]*)
            ((mine)) && vol_phones=1
            ;;
        esac
    done < <(pactl list sinks 2>/dev/null)
}

read_volume() { # "Volume: 0.53 [MUTED]" -> vol_pct 53, vol_muted 1
    vol_pct= vol_muted=0
    ((now - phones_at >= phones_every)) && read_phones
    local v
    if ((have_wpctl)); then
        v=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null) || return 0
        [[ $v =~ ^Volume:\ ([0-9]+)\.([0-9]{1,2}) ]] || return 0
        local f=${BASH_REMATCH[2]}0
        vol_pct=$((10#${BASH_REMATCH[1]} * 100 + 10#${f:0:2}))
        [[ $v == *MUTED* ]] && vol_muted=1
    else
        # pactl: "Volume: front-left: 34734 /  53% / ..." and "Mute: yes"
        v=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null) || return 0
        [[ $v =~ ([0-9]+)% ]] && vol_pct=${BASH_REMATCH[1]}
        [[ $(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null) == *yes* ]] && vol_muted=1
    fi
}

cpu_prev_t=0 cpu_prev_i=0
read_cpu() {
    local _ a b c d e f g h t i
    read -r _ a b c d e f g h _ </proc/stat || return 0
    t=$((a + b + c + d + ${e:-0} + ${f:-0} + ${g:-0} + ${h:-0})) i=$((d + ${e:-0}))
    local dt=$((t - cpu_prev_t)) di=$((i - cpu_prev_i))
    cpu_prev_t=$t cpu_prev_i=$i
    cpu_pct=0
    ((dt > 0)) && cpu_pct=$(((dt - di) * 100 / dt))
    ((cpu_pct < 0)) && cpu_pct=0
    ((cpu_pct > 100)) && cpu_pct=100
}

read_ram() {
    local k v t= a= fr=
    while read -r k v _; do
        case $k in
        MemTotal:) t=$v ;;
        MemAvailable:) a=$v ;;
        MemFree:) fr=$v ;;
        esac
        [[ -n $t && -n $a ]] && break
    done </proc/meminfo
    # MemAvailable is missing on kernels older than 3.14
    a=${a:-$fr}
    [[ -n $t && -n $a ]] && ((t > 0)) || return 0
    ram_pct=$(((t - a) * 100 / t))
    human $(((t - a) * 1024)) && ram_used=$hu
    human $((t * 1024)) && ram_total=$hu
}

net_prev_rx=0 net_prev_tx=0 net_at=0
read_net() {
    local d i v rx=0 tx=0
    for d in /sys/class/net/*; do
        i=${d##*/}
        [[ $i == lo ]] && continue
        [[ -n ${C[net_interface]} && " ${C[net_interface]} " != *" $i "* ]] && continue
        { read -r v <"$d/statistics/rx_bytes"; } 2>/dev/null && rx=$((rx + v))
        { read -r v <"$d/statistics/tx_bytes"; } 2>/dev/null && tx=$((tx + v))
    done
    # a counter that went backwards wrapped, or its interface is gone
    local drx=$((rx - net_prev_rx)) dtx=$((tx - net_prev_tx)) dms=$((now - net_at))
    net_prev_rx=$rx net_prev_tx=$tx net_at=$now
    ((drx < 0)) && drx=0
    ((dtx < 0)) && dtx=0
    ((dms > 0)) || dms=${ivl[net]}
    human $((drx * 1000 / dms)) && net_down=$hu
    human $((dtx * 1000 / dms)) && net_up=$hu
}

# the timer shown (every timer runs as "timer --until EPOCH ..."): the one
# picked by scrolling (timer -n/-p write its pid to timer.sel), else the one
# that rings first; " 2/3" after it while there are more. Looked for when
# timer sends USR1, when one of them ends and every minute, counted down in
# between
timer_scan=-60000 timer_end= timer_next= timer_pos=
timer_left() {
    timer_text=
    if ((now - timer_scan >= 60000)) || { [[ -n $timer_next ]] && ((now >= timer_next)); }; then
        timer_scan=$now timer_end= timer_next= timer_pos=
        local -a w pids=() ends=()
        local i n sel= soon=0 show= rank=1
        { read -r sel <"$run_dir/timer.sel"; } 2>/dev/null
        while read -ra w; do
            for ((i = 1; i < ${#w[@]} - 1; i++)); do
                [[ ${w[i]} == --until && ${w[i + 1]} =~ ^[0-9]+$ ]] || continue
                pids+=("${w[0]}") ends+=("${w[i + 1]}")
                break
            done
        done < <(pgrep -u "$UID" -af -- '/timer --until [0-9]' 2>/dev/null)
        n=${#pids[@]}
        ((n)) || return 0
        # in the order they ring, the pid between two that ring together, as
        # timer -n/-p go through them
        for ((i = 0; i < n; i++)); do
            ((ends[i] < ends[soon] || (ends[i] == ends[soon] && pids[i] < pids[soon]))) && soon=$i
            [[ ${pids[i]} == "$sel" ]] && show=$i
        done
        show=${show:-$soon}
        for ((i = 0; i < n; i++)); do
            ((ends[i] < ends[show] || (ends[i] == ends[show] && pids[i] < pids[show]))) && rank=$((rank + 1))
        done
        timer_end=$((now + (ends[show] - EPOCHSECONDS) * 1000))
        timer_next=$((now + (ends[soon] - EPOCHSECONDS) * 1000))
        ((n > 1)) && timer_pos=" $rank/$n"
    fi
    [[ -n $timer_end ]] && ((timer_end > now)) || return 0
    clock_text $(((timer_end - now + 999) / 1000)) && timer_text=$ct$timer_pos
}

# the newest kernel installed (/boot is root's only), when it is not the one
# running. sort -V only when the list of kernels changes
kernels= kernel_new=
reboot_kernel() {
    local d list= run
    for d in "$modules_dir"/*/modules.dep; do d=${d%/modules.dep} && list+="${d##*/}"$'\n'; done
    [[ $list == "$kernels" ]] && return 0
    kernels=$list kernel_new=
    read -r run </proc/sys/kernel/osrelease
    local top
    top=$(sort -V <<<"$list" | tail -n 1)
    [[ -n $top && $top != "$run" ]] && kernel_new=$top
}

# the lowest battery of the bluetooth audio devices connected (Icon audio-*).
# Nothing to run while nothing is connected: the kernel makes an hciN:HANDLE
# entry for each connection. timeout: bluetoothctl waits for bluetoothd forever
# when it is not running
read_btbattery() {
    bt_pct=
    local h=(/sys/class/bluetooth/hci*:*)
    ((${#h[@]})) || return 0
    local mac line audio pct
    for mac in $(timeout 2 bluetoothctl devices Connected 2>/dev/null | while read -r w m _; do [[ $w == Device ]] && echo "$m"; done); do
        audio=0 pct=
        while IFS= read -r line; do
            [[ $line =~ Icon:\ audio- ]] && audio=1
            [[ $line =~ Battery\ Percentage:.*\(([0-9]+)\) ]] && pct=${BASH_REMATCH[1]}
        done < <(timeout 2 bluetoothctl info "$mac" 2>/dev/null)
        ((audio)) && [[ -n $pct ]] || continue
        [[ -z $bt_pct ]] || ((pct < bt_pct)) && bt_pct=$pct
    done
}

# the USB devices usb left blocked with no answer ("ID PORT NAME"), less the
# ones dismissed with a right click
read_usbwait() {
    usb_n=0
    [[ -r /run/usb-pending ]] || return 0
    local -A gone=()
    local id
    if [[ -r $run_dir/usb-dismissed ]]; then
        while read -r id; do gone[$id]=1; done <"$run_dir/usb-dismissed"
    fi
    while read -r id _; do
        [[ -n $id && ! -v gone[$id] ]] && ((usb_n++))
    done </run/usb-pending
}

read_maint() { # the jobs that failed at their last run, nothing while all went fine
    maint_failed=
    local l
    [[ -r /var/lib/maint-status ]] || return 0
    while IFS= read -r l; do [[ $l == failed=?* ]] && maint_failed=${l#failed=}; done </var/lib/maint-status
}

mic_on() {
    local f k v
    for f in /proc/asound/card*/pcm*c/sub*/status; do
        { read -r k v <"$f"; } 2>/dev/null && [[ $v == RUNNING ]] && return 0
    done
    return 1
}

dns_up() {
    local _ l s
    while read -r _ l _ s _; do [[ $l == "$dns_sock" && $s == 07 ]] && return 0; done </proc/net/udp
    return 1
}

# rec %v: how long, from the start time of wf-recorder in /proc (in clock ticks
# since boot, as the uptime): no stat, no date
rec_text() {
    local st
    read -r st </proc/"$rs_p"/stat 2>/dev/null || return 0
    st=${st##*) } && read -ra st <<<"$st"
    clock_text $(((now - st[19] * 1000 / hz) / 1000)) && rec_t=$ct
}

update() { # read a group, and when it is due again
    case $1 in
    clock) read_clock ;;
    battery) read_battery ;;
    volume) read_volume ;;
    cpu) read_cpu ;;
    ram) read_ram ;;
    net) read_net ;;
    maint) read_maint ;;
    timer) timer_left ;;
    reboot) reboot_kernel ;;
    btbattery) read_btbattery ;;
    usbwait) read_usbwait ;;
    esac
    local next=$((due[$1] + ivl[$1]))
    ((next > now)) || next=$((now + ivl[$1]))
    # the clock wakes just after the second turns
    if [[ $1 == clock ]] && ((ivl[clock] >= 1000)); then
        local us=${EPOCHREALTIME#*.}
        next=$((now + ivl[clock] - 10#${us:0:3} + 5))
    fi
    due[$1]=$next
}

# ---- drawing ----------------------------------------------------------------

fmt() { # format value icon -> r
    r=${1//'%v'/$2}
    r=${r//'%i'/$3}
}

render() { # module -> r, escaped, coloured and in its area; empty when hidden
    local m=$1 col=${C[color_$1]} low=${C[battery_low]}
    r=
    case $m in
    date) r=$clk_date ;;
    time) r=$clk_time ;;
    battery)
        local icons=${C[icon_battery]} c all=
        ((bat_charging)) && [[ -n ${C[icon_battery_charging]} ]] && icons=${C[icon_battery_charging]}
        for c in "${bat_caps[@]}"; do
            level_icon "$icons" "$c" round
            fmt "${C[battery_format]}" "$c" "$bi"
            r=${r//'^'/'^^'} col=${C[color_battery]}
            # charging outranks low: the level is on its way back up
            if ((bat_charging)); then
                col=${C[color_battery_charging]:-$col}
            elif ((c <= low)); then
                col=${C[color_battery_low]:-$col}
            fi
            [[ -n $col ]] && r="^c$col^$r^d^"
            all+=${all:+ }$r
        done
        r=$all
        [[ -n $r && -n ${area[battery]} ]] && r="${area[battery]}$r^e^"
        return 0
        ;;
    volume)
        [[ -n $vol_pct ]] || return 0
        if ((vol_muted)); then
            bi=${C[icon_volume_muted]}
        elif ((vol_phones)) && [[ -n ${C[icon_volume_phones]} ]]; then
            bi=${C[icon_volume_phones]}
        else
            level_icon "${C[icon_volume]}" "$vol_pct"
        fi
        fmt "${C[volume_format]}" "$vol_pct" "$bi"
        ;;
    cpu) fmt "${C[cpu_format]}" "$cpu_pct" "${C[icon_cpu]}" ;;
    ram)
        fmt "${C[ram_format]}" "$ram_pct" "${C[icon_ram]}"
        r=${r//'%u'/$ram_used} r=${r//'%t'/$ram_total}
        ;;
    netdown) fmt "${C[netdown_format]}" "$net_down" "${C[icon_netdown]}" ;;
    netup) fmt "${C[netup_format]}" "$net_up" "${C[icon_netup]}" ;;
    rec)
        runs "$run_dir/record.pid" wf-recorder || return 0
        rec_t= && rec_text
        fmt "${C[rec_format]}" "$rec_t" "${C[icon_rec]}"
        ;;
    mic)
        mic_on || return 0
        bi=${C[icon_mic]}
        # one wpctl a tick, and only while something records
        if [[ -n ${C[icon_mic_muted]} ]] && ((have_wpctl)) &&
            [[ $(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null) == *MUTED* ]]; then
            bi=${C[icon_mic_muted]}
        fi
        fmt "${C[mic_format]}" '' "$bi"
        ;;
    cam) [[ -e /run/watchdog/cam ]] && fmt "${C[cam_format]}" '' "${C[icon_cam]}" ;;
    dns) dns_up || fmt "${C[dns_format]}" '' "${C[icon_dns]}" ;;
    maint) [[ -n $maint_failed ]] && fmt "${C[maint_format]}" "$maint_failed" "${C[icon_maint]}" ;;
    timer) [[ -n $timer_text ]] && fmt "${C[timer_format]}" "$timer_text" "${C[icon_timer]}" ;;
    reboot) [[ -n $kernel_new ]] && fmt "${C[reboot_format]}" "$kernel_new" "${C[icon_reboot]}" ;;
    usbwait) ((usb_n)) && fmt "${C[usbwait_format]}" "$usb_n" "${C[icon_usbwait]}" ;;
    btbattery)
        [[ -n $bt_pct ]] || return 0
        fmt "${C[btbattery_format]}" "$bt_pct" "${C[icon_btbattery]}"
        # red below the threshold of the battery, as the battery module
        ((bt_pct <= low)) && col=${C[color_battery_low]:-$col}
        ;;
    nightlight) runs "$run_dir/nightlight.pid" wlsunset && fmt "${C[nightlight_format]}" '' "${C[icon_nightlight]}" ;;
    awake) runs "$run_dir/awake.pid" swayidle && fmt "${C[awake_format]}" '' "${C[icon_awake]}" ;;
    esac
    [[ -n $r ]] || return 0
    r=${r//'^'/'^^'}
    [[ -n $col ]] && r="^c$col^$r^d^"
    [[ -n ${area[$m]} ]] && r="${area[$m]}$r^e^"
    return 0
}

# ---- waiting ----------------------------------------------------------------

# pactl subscribe: a change of the volume, of the default output or of a card
# reads the volume at once, one of a source the microphone. Without pactl, or
# after it ends, the waits read from an fd that never gets a line
events() {
    ev_fd=$idle_fd phones_every=10000
    ((have_pactl)) && [[ -v members[volume] || -v members[mic] ]] || return 0
    coproc EV { exec pactl subscribe 2>/dev/null; }
    ev_fd=${EV[0]} phones_every=300000
}

wait_for() { # ms: until then, a SIGUSR1 or a pactl event
    local s=$(($1 / 1000)) f line rc
    printf -v f '%03d' $(($1 % 1000))
    # in posix mode a trapped signal cuts read short, as it does wait
    set -o posix
    IFS= read -r -t "$s.$f" -u "$ev_fd" line
    rc=$?
    set +o posix
    if ((rc == 0)); then
        case $line in
        *"' on sink #"* | *"' on server"* | *"' on card #"*)
            [[ -v due[volume] ]] && due[volume]=0
            phones_at=-1000000000
            ;;
        *"' on source #"*) [[ -v due[mic] ]] && due[mic]=0 ;;
        esac
    elif ((rc == 1)); then
        # pactl ended (PipeWire restarted): back to the intervals alone
        ev_fd=$idle_fd phones_every=10000
    fi
}

# ---- main -------------------------------------------------------------------

conf=${G0WM_STATUS_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/g0wm/status.conf}
run_dir=${XDG_RUNTIME_DIR:-/tmp}
once=0 arg_battery=
while (($#)); do
    case $1 in
    -c | --config)
        (($# > 1)) || { warn '-c needs a file' && exit 1; }
        conf=$2
        shift
        ;;
    -1 | --once) once=1 ;;
    -h | --help) usage && exit 0 ;;
    -*) warn "unknown option '$1'" && exit 1 ;;
    *)
        [[ $1 =~ ^[0-9]+$ ]] || { warn "unknown argument '$1'" && exit 1; }
        arg_battery=$1
        ;;
    esac
    shift
done

declare -A ivl=() area=() due=() out=()
# osd asks for the volume and the microphone after changing them: set first,
# USR1 kills by default
kick=0
trap 'kick=1' USR1
# ended by g0wm: the EXIT trap closes pactl subscribe too
trap 'exit 0' TERM INT HUP
trap '[[ -v EV_PID ]] && kill "$EV_PID" 2>/dev/null' EXIT
read_config
detect
filter_modules

hz=100
[[ -v members[rec] ]] && hz=$(getconf CLK_TCK 2>/dev/null || echo 100)
exec {idle_fd}<> <(:)
now=0 phones_at=-1000000000 phones_every=10000 vol_phones=0
clk_date= clk_time= bat_caps=() bat_charging=0 vol_pct= vol_muted=0 cpu_pct=0
ram_pct=0 ram_used=0 ram_total=0 net_down=0B net_up=0B maint_failed= timer_text=
bt_pct= usb_n=0 rec_t= ct= hu= bi= r= g=
now_ms
[[ -v members[cpu] ]] && read_cpu
[[ -v members[net] ]] && read_net
# cpu and net are a difference: one second between the two reads
((once)) && [[ -v members[cpu] || -v members[net] ]] && read -r -t 1 -u "$idle_fd" && :
now_ms
((once)) || events

for g in "${groups[@]}"; do due[$g]=$now; done
last= aligned=0
while :; do
    if ((kick)); then
        kick=0
        for g in "${KICKED[@]}"; do [[ -v due[$g] ]] && due[$g]=$now; done
        timer_scan=-60000
    fi
    for g in "${groups[@]}"; do
        # read the groups due soon now, so they share a wake
        early=0
        [[ $g == clock ]] || early=$((ivl[$g] / 5))
        ((now >= due[$g] - early)) || continue
        update "$g"
        for m in ${members[$g]}; do
            render "$m"
            out[$m]=$r
        done
    done
    # the other groups follow the clock, once
    if ((!aligned)) && [[ -v due[clock] ]]; then
        for g in "${groups[@]}"; do due[$g]=${due[clock]}; done
    fi
    aligned=1

    line=
    for m in "${modules[@]}"; do
        [[ -n ${out[$m]} ]] && line+=${line:+${C[separator]}}${out[$m]}
    done
    # g0wm redraws the bar for every line
    if ((once)) || [[ $line != "$last" ]]; then
        printf '%s%s%s\n' "${C[prefix]}" "$line" "${C[suffix]}"
        last=$line
    fi
    ((once)) && break

    wait=
    for g in "${groups[@]}"; do [[ -z $wait ]] || ((due[$g] - now < wait)) && wait=$((due[$g] - now)); done
    wait=${wait:-1000}
    ((wait < 10)) && wait=10
    # a USR1 that came while reading skips the wait
    ((kick)) || wait_for "$wait"
    now_ms
done
