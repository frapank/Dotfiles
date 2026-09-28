# shellcheck shell=bash
# output, signals and prompts

if [[ -t 1 ]]; then
	C_R=$'\e[31m' C_G=$'\e[32m' C_Y=$'\e[33m' C_C=$'\e[36m' C_B=$'\e[1m' C_D=$'\e[2m' C_0=$'\e[0m'
	C_CL=$'\r\e[K'
	COLS=$(stty size </dev/tty 2>/dev/null | cut -d' ' -f2) || COLS=
else
	C_R= C_G= C_Y= C_C= C_B= C_D= C_0= C_CL= COLS=
fi
[[ $COLS =~ ^[0-9]+$ ]] && ((COLS >= 40)) || COLS=80
((COLS <= 80)) || COLS=80
# the Linux console font has no ✓ ✗ · …
if [[ ${TERM:-} == linux ]]; then
	S_OK=+ S_ERR=x S_DOT=- S_MORE=...
else
	S_OK=✓ S_ERR=✗ S_DOT=· S_MORE=…
fi
SKIPS=0

log() { [[ -w $LOG ]] && printf '%s %s\n' "$(date +%T)" "$*" >>"$LOG" || true; }
say() { printf '%s\n' "$*"; log "$*"; }
ok() { printf '%s   %s%s%s %s\n' "$C_CL" "$C_G" "$S_OK" "$C_0" "$*"; log "ok: $*"; }
note() { printf '   %s%s %s%s\n' "$C_D" "$S_DOT" "$*" "$C_0"; log "note: $*"; }
skip() { SKIPS=$((SKIPS + 1)); log "skip: $*"; }
warn() { printf '   %s! %s%s\n' "$C_Y" "$*" "$C_0" >&2; log "warn: $*"; }
head_line() { printf '\n%s%s::%s %s%s%s%s\n' "$C_B" "$C_C" "$C_0" "$C_B" "$1" "$C_0" "${2:+  $C_D$2$C_0}"; }

# wraps lines longer than $1, continuations indented by two more spaces;
# lines with aligned columns (two spaces inside) are left as they are
wrap() {
	awk -v w="$1" '
		!NF { next }
		length($0) <= w || /[^ ]  +[^ ]/ { print; next }
		{
			match($0, /^ */); ind = substr($0, 1, RLENGTH)
			n = split($0, word, " "); line = ind word[1]
			for (i = 2; i <= n; i++) {
				if (length(line) + 1 + length(word[i]) > w) { print line; line = ind "  " word[i] }
				else line = line " " word[i]
			}
			print line
		}'
}

# one row only, or \r cannot clear it
busy() {
	[[ -n $C_CL ]] || return 0
	local s=$1 w=$((COLS - 6))
	((${#s} <= w)) || s=${s:0:w-${#S_MORE}}$S_MORE
	printf '   %s%s %s%s' "$C_D" "$S_MORE" "$s" "$C_0"
}

flush_skips() {
	((SKIPS)) || return 0
	printf '   %s%s %d already in place%s\n' "$C_D" "$S_DOT" "$SKIPS" "$C_0"
	SKIPS=0
}

step() {
	check_abort
	flush_skips
	STAGE=$*
	head_line "$*"
	log "=== $*"
}

die() {
	[[ $BASHPID == "$$" ]] || exit 1
	trap - ERR
	flush_skips
	printf '\n%serror:%s %s\n' "$C_R" "$C_0" "$*" >&2
	log "error: $*"
	rollback
	exit 1
}

usage() {
	cat <<-EOF
		usage: doas ${0##*/} [-y] [-u USER]

		Turns a fresh Void Linux install into this dotfiles setup: asks what to
		apply, then does it, and rolls everything back if a step fails.

		  -y, --yes      answer yes to every question
		  -u, --user     configure USER's home (default: whoever ran doas/sudo)
		  -h, --help     this message

		Files are copied, not linked: the repo can move or go away. To update,
		  pull the repo and run this again: what is already in place is left
		  alone, wrong owners and modes are fixed, changed files are replaced
		  after the old copy goes to ~/_backup/<date>.
		Log in /var/log/void-postinstall-*.log, backups in /var/backups/void-postinstall.
	EOF
	exit "${1:-0}"
}

# signals

on_signal() {
	if [[ $STAGE == preflight ]]; then
		printf '\n%sinterrupted: nothing changed%s\n' "$C_Y" "$C_0" >&2
		exit 130
	fi
	ABORT=1
	printf '\n%sinterrupted: finishing the current step, then rolling back%s\n' "$C_Y" "$C_0" >&2
}

check_abort() { ((ABORT == 0)) || die "interrupted during: $STAGE"; }
on_err() { die "unexpected failure at $2:$1 during: $STAGE (see $LOG)"; }

run() {
	local desc=$1 rc=0
	shift
	[[ $1 == as_user ]] && set -- "${AS_USER[@]}" "${@:2}"
	log "\$ $*"
	busy "$desc"
	setsid -w "$@" </dev/null >>"$LOG" 2>&1 || rc=$?
	if ((rc)); then
		printf '%s   %s%s%s %s\n' "$C_CL" "$C_R" "$S_ERR" "$C_0" "$desc" >&2
		tail -n 15 "$LOG" | sed 's/^/     | /' >&2
		die "$desc failed (exit $rc)"
	fi
	ok "$desc"
	check_abort
}

try() {
	local desc=$1
	shift
	[[ $1 == as_user ]] && set -- "${AS_USER[@]}" "${@:2}"
	log "\$ $*"
	busy "$desc"
	if setsid -w "$@" </dev/null >>"$LOG" 2>&1; then
		ok "$desc"
	else
		printf '%s' "$C_CL"
		warn "$desc failed, see $LOG"
	fi
	check_abort
}

as_user() { "${AS_USER[@]}" "$@"; }

ask() {
	local a
	if ((YES)); then
		printf '%s [y/n] y\n' "$1"
		return 0
	fi
	while :; do
		printf '%s%s%s [y/n] ' "$C_B" "$1" "$C_0"
		read -r a </dev/tty || { check_abort; die "no input"; }
		check_abort
		case ${a,,} in
		y | yes) log "ask: $1 -> y"; return 0 ;;
		n | no) log "ask: $1 -> n"; return 1 ;;
		esac
	done
}
