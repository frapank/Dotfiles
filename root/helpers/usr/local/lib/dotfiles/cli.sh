# shellcheck shell=sh

CLI_PROG=${0##*/}
CLI_USAGE_STATUS=2

help() {
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
        usage | awk -v b="$(printf '\033[1m')" -v u="$(printf '\033[4m')" \
            -v d="$(printf '\033[2m')" -v n="$(printf '\033[0m')" '
            function ul(s, r) {
                while (match(s, /[A-Z][A-Z0-9_]+/)) {
                    r = r substr(s, 1, RSTART - 1) u substr(s, RSTART, RLENGTH) n
                    s = substr(s, RSTART + RLENGTH)
                }
                return r s
            }
            /^$/ { ex = 0 }
            ex { print d $0 n; next }
            /^(Usage|  or):/ {
                i = index($0, ":")
                print b substr($0, 1, i) n ul(substr($0, i + 1))
                next
            }
            /^[A-Z][A-Za-z]*( [a-z]+)?:/ {
                i = index($0, ":")
                ex = $0 == "Examples:"
                print b substr($0, 1, i) n substr($0, i + 1)
                next
            }
            /^  [^ ]/ && match(substr($0, 3), /   *|$/) {
                i = RSTART
                print "  " ul(substr($0, 3, i - 1)) substr($0, i + 2)
                next
            }
            { print }'
    else
        usage
    fi
}

cli_error() {
    if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
        printf '\033[1;31m%s:\033[0m %s\n' "$CLI_PROG" "$*" >&2
    else
        printf '%s: %s\n' "$CLI_PROG" "$*" >&2
    fi
}

err() { cli_error "$*"; }

bad() {
    err "$*"
    if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
        printf "\033[2mTry '%s --help' for more information.\033[0m\n" "$CLI_PROG" >&2
    else
        printf "Try '%s --help' for more information.\n" "$CLI_PROG" >&2
    fi
    exit "${CLI_USAGE_STATUS:-2}"
}

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    o_ok=$(printf '\033[32m') o_warn=$(printf '\033[33m') o_fail=$(printf '\033[31m')
    o_dim=$(printf '\033[2m') o_off=$(printf '\033[0m')
else
    o_ok= o_warn= o_fail= o_dim= o_off=
fi

row() {
    case $1 in
    ok) printf '  %s%-4s%s  %s\n' "$o_ok" ok "$o_off" "$2" ;;
    warn) printf '  %s%-4s%s  %s\n' "$o_warn" warn "$o_off" "$2" ;;
    fail) printf '  %s%-4s%s  %s\n' "$o_fail" fail "$o_off" "$2" ;;
    *) printf '  %s%-4s  %s%s\n' "$o_dim" info "$2" "$o_off" ;;
    esac
}

dim() { printf '%s%s%s\n' "$o_dim" "$*" "$o_off"; }
