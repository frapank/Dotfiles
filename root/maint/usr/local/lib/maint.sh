# shellcheck shell=sh

JOBS='home thumbs trash update disks kernels packages firmware integrity cves vesktop scrub blocklist'

valid_job() {
    case " $JOBS " in *" $1 "*) return 0 ;; esac
    return 1
}

interval() {
    case $1 in
    disks | kernels | packages | firmware | integrity | cves) echo $((7 * DAY)) ;;
    scrub) echo $((30 * DAY)) ;;
    *) echo "$DAY" ;;
    esac
}

process_start() {
    [ -r "/proc/$1/stat" ] || return 1
    awk '{ sub(/^.*\) /, ""); print $20 }' "/proc/$1/stat"
}

load_job() {
    m_state=never m_attempt=0 m_success=0 m_finished=0 m_duration=0 m_pid=0 m_start=0 m_boot= m_reason=
    if [ -r "$STATE/jobs/$1/state" ]; then
        while IFS='=' read -r key value; do
            case $key in
            state) case $value in running | ok | postponed | failed | interrupted) m_state=$value ;; esac ;;
            attempt | success | finished | duration | pid | start)
                case $value in '' | *[!0-9]*) continue ;; esac
                [ "${#value}" -le 12 ] || continue
                case $key in
                attempt) m_attempt=$value ;;
                success) m_success=$value ;;
                finished) m_finished=$value ;;
                duration) m_duration=$value ;;
                pid) m_pid=$value ;;
                start) m_start=$value ;;
                esac
                ;;
            boot) m_boot=$value ;;
            reason) m_reason=$value ;;
            esac
        done <"$STATE/jobs/$1/state"
    elif [ -e "$STATE/$1.failed" ]; then
        m_state=failed
        m_attempt=$(stat -c %Y "$STATE/$1.failed")
        m_finished=$m_attempt
        m_reason='Previous run failed; last success is unknown'
    elif [ -e "$STATE/$1" ]; then
        m_state=ok
        m_success=$(stat -c %Y "$STATE/$1")
        m_attempt=$m_success m_finished=$m_success
        m_reason='Imported previous successful run'
    fi
    if [ "$m_state" = running ]; then
        if [ "$m_pid" = 0 ] || [ "$m_boot" != "$(cat /proc/sys/kernel/random/boot_id)" ] ||
            [ "$m_start" != "$(process_start "$m_pid" 2>/dev/null)" ]; then
            m_state=interrupted m_reason='Previous run was interrupted'
        fi
    fi
    if [ "$m_state" = running ]; then
        m_duration=$(($(date +%s) - m_attempt))
        [ "$m_duration" -ge 0 ] || m_duration=0
        m_next=0
    elif [ "$m_state" = interrupted ] || [ "$m_attempt" = 0 ]; then
        m_next=0
    elif [ "$m_state" = ok ]; then
        m_next=$((m_success + $(interval "$1") - 1800))
        [ "$m_success" -le "$(date +%s)" ] || m_next=0
    else
        m_next=$((m_finished + 3600))
        [ "$m_finished" -le "$(date +%s)" ] || m_next=0
    fi
}

save_job() {
    m_tmp=$(mktemp "$STATE/jobs/$1/state.XXXXXX") || return 1
    {
        printf 'state=%s\nattempt=%s\nsuccess=%s\nfinished=%s\nduration=%s\n' \
            "$m_state" "$m_attempt" "$m_success" "$m_finished" "$m_duration"
        printf 'pid=%s\nstart=%s\nboot=%s\nreason=%s\n' \
            "$m_pid" "$m_start" "$m_boot" "$m_reason"
    } >"$m_tmp" && mv -f -- "$m_tmp" "$STATE/jobs/$1/state"
}

postpone() {
    log "${MAINT_JOB:-update}: $*"
    if valid_job "${MAINT_JOB:-}"; then
        printf '%s\n' "$*" >"$STATE/jobs/$MAINT_JOB/reason"
    fi
}

ready() {
    case $1 in
    thumbs | trash | update | vesktop)
        if ! pgrep -xo g0wm >/dev/null; then
            echo 'No desktop session'
            return 2
        fi
        ;;
    esac
    case $1 in
    update | kernels | packages | integrity)
        if apt_busy; then
            echo 'APT is running'
            return 2
        fi
        ;;
    esac
    case $1 in
    home)
        if [ "$(stat -f -c %T /home)" != btrfs ] || ! btrfs subvolume show /home >/dev/null 2>&1; then
            echo 'Home is not a Btrfs subvolume'
            return 1
        fi
        ;;
    update)
        b=$(battery)
        if [ -n "$b" ] && [ "$b" -le "$BATTERY_MIN" ]; then
            echo "Battery at $b%"
            return 2
        fi
        used=$(df --output=pcent / | tail -n1 | tr -dc 0-9)
        case $used in '' | *[!0-9]*)
            echo 'Cannot read free disk space'
            return 1
            ;;
        esac
        if [ "$((100 - used))" -lt "$MIN_FREE" ]; then
            echo "Root filesystem is $used% full"
            return 1
        fi
        ;;
    scrub)
        if ! on_ac; then
            echo 'On battery'
            return 2
        fi
        if btrfs scrub status / 2>/dev/null | grep -q 'Status:.*running'; then
            echo 'Scrub is already running'
            return 2
        fi
        ;;
    blocklist)
        if [ ! -x /usr/local/sbin/dns-blocklist ]; then
            echo 'DNS blocklist helper is not installed'
            return 2
        fi
        ;;
    esac
    return 0
}

due() {
    if [ "$1" = netwait ]; then
        [ -e "$STATE/netwait" ] || return 0
        [ "$(($(date +%s) - $(stat -c %Y "$STATE/netwait")))" -ge "$(($2 - 1800))" ]
        return $?
    fi
    load_job "$1"
    [ "$m_state" != running ] && [ "$m_next" -le "$(date +%s)" ]
}

public() (
    mkdir -p "$STATE" || exit 1
    exec 8>"$STATE/public.lock"
    flock 8 || exit 1
    pubtmp=$(mktemp "$PUBLIC.XXXXXX") || exit 1
    trap 'rm -f -- "$pubtmp"' EXIT
    pubfail= pubrunning= pubpostponed=
    {
        for pubj in $JOBS; do
            load_job "$pubj"
            case $m_state in
            failed | interrupted) pubfail="$pubfail $pubj" ;;
            running) pubrunning="$pubrunning $pubj" ;;
            postponed) pubpostponed="$pubpostponed $pubj" ;;
            esac
            case $pubj in update | scrub) [ "$m_success" = 0 ] || printf '%s=%s\n' "$pubj" "$m_success" ;; esac
            printf 'job_%s_state=%s\njob_%s_success=%s\njob_%s_attempt=%s\n' \
                "$pubj" "$m_state" "$pubj" "$m_success" "$pubj" "$m_attempt"
            printf 'job_%s_next=%s\njob_%s_duration=%s\n' "$pubj" "$m_next" "$pubj" "$m_duration"
        done
        printf 'home=%s\n' "$(snapshots "$SNAPDIR" home 2>/dev/null | wc -l)"
        printf 'root=%s\n' "$(snapshots "$ROOTSNAP" root 2>/dev/null | wc -l)"
        printf 'failed=%s\nrunning=%s\npostponed=%s\n' "${pubfail# }" "${pubrunning# }" "${pubpostponed# }"
    } >"$pubtmp" && chmod 0644 "$pubtmp" && mv -f -- "$pubtmp" "$PUBLIC"
)

job() {
    j_name=$1
    mkdir -p "$STATE/jobs/$j_name" || return 1
    load_job "$j_name"
    m_attempt=$(date +%s) m_finished=0 m_duration=0 m_state=running m_reason=
    : >"$STATE/jobs/$j_name/reason"
    : >"$STATE/jobs/$j_name/log"
    m_pid=$(exec sh -c 'printf "%s" "$PPID"')
    m_start=$(process_start "$m_pid") || return 1
    m_boot=$(cat /proc/sys/kernel/random/boot_id)
    save_job "$j_name" || return 1
    public || return 1
    log "$j_name: start"
    (
        MAINT_JOB=$j_name
        export MAINT_JOB
        reason=$(ready "$j_name")
        check=$?
        if [ "$check" != 0 ]; then
            postpone "$reason"
            exit "$check"
        fi
        "job_$j_name"
    ) >"$STATE/jobs/$j_name/log" 2>&1 &
    j_worker=$!
    tail --pid="$j_worker" -s 0.1 -n +1 -f "$STATE/jobs/$j_name/log" &
    j_tail=$!
    wait "$j_worker"
    j_rc=$?
    wait "$j_tail" || :
    m_finished=$(date +%s)
    m_duration=$((m_finished - m_attempt))
    [ "$m_duration" -ge 0 ] || m_duration=0
    m_reason=$(cat "$STATE/jobs/$j_name/reason")
    if [ -z "$m_reason" ]; then
        m_reason=$(tail -n 1 "$STATE/jobs/$j_name/log")
    fi
    m_reason=$(printf '%s' "$m_reason" | tr '\n\r\t' '   ' | tr -cd '[:print:]' | cut -c 1-240)
    case $j_rc in
    0)
        m_state=ok m_success=$m_finished
        rm -f -- "$STATE/$j_name.failed"
        log "$j_name: ok"
        ;;
    2)
        m_state=postponed
        [ -n "$m_reason" ] || m_reason='Waiting for prerequisites'
        rm -f -- "$STATE/$j_name.failed"
        log "$j_name: postponed, retry in one hour"
        ;;
    129 | 130 | 137 | 143)
        m_state=interrupted m_reason="Interrupted (exit status $j_rc)"
        date >"$STATE/$j_name.failed"
        log "$j_name: interrupted ($j_rc)"
        ;;
    *)
        m_state=failed
        [ -n "$m_reason" ] || m_reason="Exited with status $j_rc"
        date >"$STATE/$j_name.failed"
        log "$j_name: FAILED ($j_rc)"
        ;;
    esac
    save_job "$j_name" || return 1
    # Keep only the latest log, capped at 256 KiB after the job finishes.
    j_log=$(mktemp "$STATE/jobs/$j_name/log.XXXXXX") || return 1
    tail -c 262144 "$STATE/jobs/$j_name/log" >"$j_log" && mv -f -- "$j_log" "$STATE/jobs/$j_name/log"
    public || return 1
    case $j_rc in
    0 | 2) return 0 ;;
    *)
        [ "$j_rc" = 3 ] || notify_job "$j_name"
        return 1
        ;;
    esac
}

locked() {
    mkdir -p "$STATE" || return 1
    exec 9>"$STATE/lock"
    flock -n 9 || {
        log 'maint is already running'
        return 1
    }
}

run_due() {
    run_rc=0
    public || return 1
    grub_quiet || run_rc=1
    for run_job in $JOBS; do
        [ "$run_job" != blocklist ] || [ -x /usr/local/sbin/dns-blocklist ] || continue
        if due "$run_job"; then job "$run_job" || run_rc=1; fi
    done
    public || run_rc=1
    return "$run_rc"
}

retry() (
    retry_explicit=$*
    mkdir -p "$STATE" || exit 1
    exec 9>"$STATE/lock"
    if ! flock -n 9; then
        log 'Retry queued; waiting for the current maintenance run.'
        flock 9 || exit 1
    fi
    retry_jobs=$retry_explicit
    if [ -z "$retry_jobs" ]; then
        for retry_job in $JOBS; do
            load_job "$retry_job"
            case $m_state in failed | interrupted) retry_jobs="$retry_jobs $retry_job" ;; esac
        done
    fi
    [ -n "$retry_jobs" ] || {
        log 'No failed jobs to retry.'
        exit 0
    }
    retry_rc=0
    for retry_job in $retry_jobs; do
        FORCE=1 job "$retry_job" || retry_rc=1
    done
    exit "$retry_rc"
)

when() {
    if [ "$1" = 0 ]; then printf never; else date -d "@$1" '+%F %R'; fi
}

status() {
    status_jobs=${1:-$JOBS}
    printf '%-10s %-12s %-16s %-16s %s\n' JOB STATE 'LAST SUCCESS' 'NEXT DUE' DETAILS
    for status_job in $status_jobs; do
        load_job "$status_job"
        if [ "$m_state" = running ]; then next=running; elif [ "$m_next" -le "$(date +%s)" ]; then next=now; else next=$(when "$m_next"); fi
        printf '%-10s %-12s %-16s %-16s %s\n' "$status_job" "$m_state" "$(when "$m_success")" "$next" "$m_reason"
        if [ $# -gt 0 ]; then
            printf 'Last attempt: %s\nFinished: %s\nDuration: %ss\n' "$(when "$m_attempt")" "$(when "$m_finished")" "$m_duration"
        fi
    done
    if [ $# -eq 0 ]; then
        printf '\nSnapshots of %s\n' "$SNAPDIR"
        snapshots "$SNAPDIR" home 2>/dev/null || :
        printf '\nSnapshots of %s\n' "$ROOTSNAP"
        snapshots "$ROOTSNAP" root 2>/dev/null || :
        if command -v btrfs >/dev/null; then
            printf '\n'
            btrfs scrub status / 2>/dev/null | grep -E '^(Scrub started|Status|Error summary)' || :
        fi
    fi
    return 0
}

plan() {
    printf '%-10s %-12s %s\n' JOB ACTION REASON
    for plan_job in ${1:-$JOBS}; do
        load_job "$plan_job"
        if [ "$plan_job" = blocklist ] && [ ! -x /usr/local/sbin/dns-blocklist ]; then
            printf '%-10s %-12s %s\n' "$plan_job" unavailable 'DNS blocklist helper is not installed'
        elif [ "$m_state" = running ]; then
            printf '%-10s %-12s %s\n' "$plan_job" running 'Already running'
        elif [ "$m_next" -gt "$(date +%s)" ]; then
            printf '%-10s %-12s %s\n' "$plan_job" wait "Next due: $(when "$m_next")"
        else
            plan_reason=$(ready "$plan_job")
            plan_code=$?
            case $plan_code in 0)
                plan_action=run
                plan_reason='Due; network and package checks happen during execution'
                ;;
            2) plan_action=postpone ;; *) plan_action=blocked ;; esac
            printf '%-10s %-12s %s\n' "$plan_job" "$plan_action" "$plan_reason"
        fi
    done
}

job_logs() {
    if [ $# = 0 ]; then exec /usr/local/bin/logs service maint; fi
    if [ -r "$STATE/jobs/$1/log" ]; then
        if [ -t 1 ]; then less +G -- "$STATE/jobs/$1/log"; else cat -- "$STATE/jobs/$1/log"; fi
    else
        printf 'No saved log for %s yet. See logs service maint for older runs.\n' "$1"
    fi
}
