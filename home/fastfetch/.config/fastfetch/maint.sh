#!/bin/sh
# a line of the maint group of fastfetch, from what maint leaves readable
set -u

f=/var/lib/maint-status
[ -r "$f" ] || {
    echo "no run yet"
    exit 0
}

get() { sed -n "s/^$1=//p" "$f"; }

ago() {
    [ -n "$1" ] || {
        echo never
        return
    }
    s=$(($(date +%s) - $1))
    if [ "$s" -lt 3600 ]; then
        echo "$((s / 60)) min ago"
    elif [ "$s" -lt 172800 ]; then
        echo "$((s / 3600)) h ago"
    else
        echo "$((s / 86400)) days ago"
    fi
}

case ${1:-} in
update) ago "$(get update)" ;;
scrub) ago "$(get scrub)" ;;
snapshots) echo "$(get home) of /home · $(get root) of /" ;;
status)
    failed=$(get failed)
    if [ -n "$failed" ]; then
        echo "failed: $failed"
    else
        echo "all jobs ok"
    fi
    ;;
esac
