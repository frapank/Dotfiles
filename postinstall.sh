#!/usr/bin/env bash

set -Eeuo pipefail
umask 022
export LC_ALL=C

readonly G0WM_URL=https://github.com/frapank/g0wm.git
readonly FONT_URL=https://github.com/supercomputra/SF-Mono-Font.git
readonly SFPRO_URL=https://github.com/sahibjotsaggu/San-Francisco-Pro-Fonts.git
readonly ICONS_URL=https://gitlab.gnome.org/GNOME/adwaita-icon-theme-legacy.git
readonly ICONS_TAG=46.2
readonly ICONS_DIR=/usr/share/icons/AdwaitaLegacy
readonly RAR_PAGE=https://www.rarlab.com/download.htm
readonly TS=$(date +%Y%m%d-%H%M%S)
readonly LOG=/var/log/void-postinstall-$TS.log
readonly BAK=/var/backups/void-postinstall/$TS
readonly LOCK=/run/void-postinstall.lock
readonly SVDIR=/var/service

PKG_CORE=(git base-devel)
PKG_CLI=(bash bash-completion vim-huge neovim tmux ctags fzf fd ripgrep bat
	xxd lesspipe binutils gdb ncurses-term wl-clipboard)
PKG_LSP=(clang-tools-extra rust-analyzer taplo zls bash-language-server
	yaml-language-server)
PKG_HARDEN=(nftables openssh)
PKG_NET=(NetworkManager dnscrypt-proxy chrony dbus)
PKG_BOOT=(dracut plymouth plymouth-data)
PKG_DESKTOP=(
	# g0wm build
	pkg-config wlroots0.20-devel wayland-devel wayland-protocols
	libxkbcommon-devel libinput-devel pixman-devel fcft-devel tllist
	dbus-devel libxcb-devel xcb-util-wm-devel gdk-pixbuf-devel
	# session
	dbus elogind polkit mesa-dri xorg-server-xwayland pipewire wireplumber
	xdg-utils xdg-user-dirs fontconfig
	# apps
	foot Thunar grim slurp swappy swayidle gtklock wmenu
	brightnessctl playerctl dejavu-fonts-ttf adwaita-icon-theme
)
PKG_MEDIA=(pipewire wireplumber alsa-pipewire xdg-desktop-portal
	xdg-desktop-portal-wlr xdg-desktop-portal-gtk slurp dbus)
PKG_APPS=(
	librewolf foot gtklock swaylock swayidle pavucontrol
	loupe showtime papers libreoffice qt6-wayland
	# thunar
	Thunar thunar-volman thunar-archive-plugin tumbler ffmpegthumbnailer
	gvfs gvfs-mtp udisks2 xarchiver
	# default apps
	xdg-utils gtk+3 desktop-file-utils shared-mime-info
	# screen recording
	wf-recorder libnotify
	# terminal tools
	tree bat htop unzip zip 7zip wget curl rsync jq file lsof strace psmisc
	ncdu fastfetch
	# archives
	tar gzip bzip2 xz zstd lz4 lzip bsdtar cpio unrar gnupg age
)
PKG_SESSION=(gnome-keyring libsecret polkit-gnome network-manager-applet
	bluez blueman libspa-bluetooth)
PKG_THEME=(gnome-themes-extra gnome-themes-extra-gtk adwaita-icon-theme gsettings-desktop-schemas
	dconf glib adwaita-qt adwaita-qt6 git gtk+3 librsvg)
PKG_FONTS=(fontconfig nerd-fonts noto-fonts-ttf noto-fonts-emoji noto-fonts-cjk)
PKG_LOCALE=(glibc-locales)
PKG_HW=(fwupd)
PKG_POWER=(power-profiles-daemon)
PKG_LOGS=(socklog-void pulseaudio-utils)
PKG_DIRS=(xdg-user-dirs)
PKG_SWAP=(zramen)
XDG_DEFAULT_DIRS=(Desktop Documents Downloads Music Pictures Public Templates Videos)
HOME_CLI=(bash ctags nvim vim tmux)
HOME_DESKTOP=(foot g0wm gtklock)
HOME_APPS=(thunar mime bin)
HOME_THEME=(gtk)
HOME_FONTS=(fontconfig)
HOME_MEDIA=(portal)
HOME_DIRS=(xdg)
USER_GROUPS=(wheel video network)
SECTIONS=(update locale cli lsp harden net boot hw power logs swap dirs desktop media apps session theme fonts doas)
SF_DIR=/usr/local/share/fonts/SF-Mono
MIME_DEFAULTS=(
	application/pdf=org.gnome.Papers.desktop
	image/png=org.gnome.Loupe.desktop
	image/jpeg=org.gnome.Loupe.desktop
	image/gif=org.gnome.Loupe.desktop
	image/webp=org.gnome.Loupe.desktop
	video/mp4=org.gnome.Showtime.desktop
	video/x-matroska=org.gnome.Showtime.desktop
	video/webm=org.gnome.Showtime.desktop
	video/x-msvideo=org.gnome.Showtime.desktop
	image/apng=org.gnome.Loupe.desktop
	image/bmp=org.gnome.Loupe.desktop
	image/jp2=org.gnome.Loupe.desktop
	image/qoi=org.gnome.Loupe.desktop
	image/tiff=org.gnome.Papers.desktop
	image/vnd.microsoft.icon=org.gnome.Loupe.desktop
	image/x-dds=org.gnome.Loupe.desktop
	image/x-exr=org.gnome.Loupe.desktop
	image/x-portable-anymap=org.gnome.Loupe.desktop
	image/x-portable-bitmap=org.gnome.Loupe.desktop
	image/x-portable-graymap=org.gnome.Loupe.desktop
	image/x-portable-pixmap=org.gnome.Loupe.desktop
	image/x-qoi=org.gnome.Loupe.desktop
	image/x-tga=org.gnome.Loupe.desktop
	image/x-win-bitmap=org.gnome.Loupe.desktop
	image/x-xbitmap=org.gnome.Loupe.desktop
	image/x-xpixmap=org.gnome.Loupe.desktop
	image/svg+xml=org.gnome.Loupe.desktop
	image/svg+xml-compressed=org.gnome.Loupe.desktop
	image/avif=org.gnome.Loupe.desktop
	image/heic=org.gnome.Loupe.desktop
	image/jxl=org.gnome.Loupe.desktop
	video/3gp=org.gnome.Showtime.desktop
	video/3gpp=org.gnome.Showtime.desktop
	video/3gpp2=org.gnome.Showtime.desktop
	video/dv=org.gnome.Showtime.desktop
	video/divx=org.gnome.Showtime.desktop
	video/fli=org.gnome.Showtime.desktop
	video/flv=org.gnome.Showtime.desktop
	video/mp2t=org.gnome.Showtime.desktop
	video/mp4v-es=org.gnome.Showtime.desktop
	video/mpeg=org.gnome.Showtime.desktop
	video/mpeg-system=org.gnome.Showtime.desktop
	video/msvideo=org.gnome.Showtime.desktop
	video/ogg=org.gnome.Showtime.desktop
	video/quicktime=org.gnome.Showtime.desktop
	video/vivo=org.gnome.Showtime.desktop
	video/vnd.divx=org.gnome.Showtime.desktop
	video/vnd.mpegurl=org.gnome.Showtime.desktop
	video/vnd.rn-realvideo=org.gnome.Showtime.desktop
	video/vnd.vivo=org.gnome.Showtime.desktop
	video/x-anim=org.gnome.Showtime.desktop
	video/x-avi=org.gnome.Showtime.desktop
	video/x-flc=org.gnome.Showtime.desktop
	video/x-fli=org.gnome.Showtime.desktop
	video/x-flic=org.gnome.Showtime.desktop
	video/x-flv=org.gnome.Showtime.desktop
	video/x-m4v=org.gnome.Showtime.desktop
	video/x-mjpeg=org.gnome.Showtime.desktop
	video/x-mpeg=org.gnome.Showtime.desktop
	video/x-mpeg2=org.gnome.Showtime.desktop
	video/x-ms-asf=org.gnome.Showtime.desktop
	video/x-ms-asf-plugin=org.gnome.Showtime.desktop
	video/x-ms-asx=org.gnome.Showtime.desktop
	video/x-ms-wm=org.gnome.Showtime.desktop
	video/x-ms-wmv=org.gnome.Showtime.desktop
	video/x-ms-wvx=org.gnome.Showtime.desktop
	video/x-nsv=org.gnome.Showtime.desktop
	video/x-ogm+ogg=org.gnome.Showtime.desktop
	video/x-theora=org.gnome.Showtime.desktop
	video/x-theora+ogg=org.gnome.Showtime.desktop
	application/vnd.comicbook-rar=org.gnome.Papers.desktop
	application/vnd.comicbook+zip=org.gnome.Papers.desktop
	application/x-cb7=org.gnome.Papers.desktop
	application/x-cbr=org.gnome.Papers.desktop
	application/x-cbt=org.gnome.Papers.desktop
	application/x-cbz=org.gnome.Papers.desktop
	application/x-ext-cb7=org.gnome.Papers.desktop
	application/x-ext-cbr=org.gnome.Papers.desktop
	application/x-ext-cbt=org.gnome.Papers.desktop
	application/x-ext-cbz=org.gnome.Papers.desktop
	application/x-ext-djv=org.gnome.Papers.desktop
	application/x-ext-djvu=org.gnome.Papers.desktop
	image/vnd.djvu=org.gnome.Papers.desktop
	image/vnd.djvu+multipage=org.gnome.Papers.desktop
	application/x-bzpdf=org.gnome.Papers.desktop
	application/x-ext-pdf=org.gnome.Papers.desktop
	application/x-gzpdf=org.gnome.Papers.desktop
	application/x-xzpdf=org.gnome.Papers.desktop
	application/illustrator=org.gnome.Papers.desktop
	text/html=librewolf.desktop
	application/xhtml+xml=librewolf.desktop
	x-scheme-handler/http=librewolf.desktop
	x-scheme-handler/https=librewolf.desktop
	x-scheme-handler/about=librewolf.desktop
	x-scheme-handler/unknown=librewolf.desktop
	inode/directory=thunar.desktop
	application/zip=xarchiver.desktop
	application/x-tar=xarchiver.desktop
	application/x-compressed-tar=xarchiver.desktop
	application/x-bzip2-compressed-tar=xarchiver.desktop
	application/x-xz-compressed-tar=xarchiver.desktop
	application/x-zstd-compressed-tar=xarchiver.desktop
	application/gzip=xarchiver.desktop
	application/x-xz=xarchiver.desktop
	application/x-bzip2=xarchiver.desktop
	application/zstd=xarchiver.desktop
	application/x-7z-compressed=xarchiver.desktop
	application/vnd.rar=xarchiver.desktop
	application/x-rar=xarchiver.desktop
	application/vnd.oasis.opendocument.text=libreoffice-writer.desktop
	application/vnd.openxmlformats-officedocument.wordprocessingml.document=libreoffice-writer.desktop
	application/msword=libreoffice-writer.desktop
	application/rtf=libreoffice-writer.desktop
	application/vnd.oasis.opendocument.spreadsheet=libreoffice-calc.desktop
	application/vnd.openxmlformats-officedocument.spreadsheetml.sheet=libreoffice-calc.desktop
	application/vnd.ms-excel=libreoffice-calc.desktop
	text/csv=libreoffice-calc.desktop
	application/vnd.oasis.opendocument.presentation=libreoffice-impress.desktop
	application/vnd.openxmlformats-officedocument.presentationml.presentation=libreoffice-impress.desktop
	application/vnd.ms-powerpoint=libreoffice-impress.desktop
	text/plain=nvim-foot.desktop
	text/markdown=nvim-foot.desktop
	text/x-c=nvim-foot.desktop
	text/x-csrc=nvim-foot.desktop
	text/x-chdr=nvim-foot.desktop
	text/x-c++src=nvim-foot.desktop
	text/x-rust=nvim-foot.desktop
	text/x-python=nvim-foot.desktop
	text/x-shellscript=nvim-foot.desktop
	application/x-shellscript=nvim-foot.desktop
	application/json=nvim-foot.desktop
	application/toml=nvim-foot.desktop
	application/x-yaml=nvim-foot.desktop
	text/x-log=nvim-foot.desktop
)
SFPRO_DIR=/usr/local/share/fonts/SF-Pro

YES=0 ABORT=0 STAGE=preflight TUSER= TGID= THOME= REPO= UBAK=
AS_USER=()
HW_PKGS=() HW_DESC=() NONFREE=0 NEW_PKGS=() REGEN=0 ZRAM_PCT=0 ZRAM_MIB=0
declare -A DO=()

# output

if [[ -t 1 ]]; then
	C_R=$'\e[31m' C_G=$'\e[32m' C_Y=$'\e[33m' C_B=$'\e[1m' C_D=$'\e[2m' C_0=$'\e[0m'
	C_CL=$'\r\e[K'
else
	C_R= C_G= C_Y= C_B= C_D= C_0= C_CL=
fi

log() { [[ -w $LOG ]] && printf '%s %s\n' "$(date +%T)" "$*" >>"$LOG" || true; }
say() { printf '%s\n' "$*"; log "$*"; }
ok() { printf '%s  %s✓%s %s\n' "$C_CL" "$C_G" "$C_0" "$*"; log "ok: $*"; }
busy() { [[ -z $C_CL ]] || printf '  %s… %s%s' "$C_D" "$1" "$C_0"; }
skip() { printf '  %s· %s (already done)%s\n' "$C_D" "$*" "$C_0"; log "skip: $*"; }
warn() { printf '  %s! %s%s\n' "$C_Y" "$*" "$C_0" >&2; log "warn: $*"; }
step() {
	check_abort
	STAGE=$*
	printf '\n%s==> %s%s\n' "$C_B" "$*" "$C_0"
	log "=== $*"
}

die() {
	[[ $BASHPID == "$$" ]] || exit 1
	trap - ERR
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
		  pull the repo and run this again: unchanged files are skipped, changed
		  ones replaced after the old copy goes to ~/_backup/<date>.
		Log in /var/log/void-postinstall-*.log, backups in /var/backups/void-postinstall.
	EOF
	exit "${1:-0}"
}

# signals

on_signal() {
	ABORT=1
	printf '\n%sinterrupted: finishing the current step, then rolling back%s\n' "$C_Y" "$C_0" >&2
}
check_abort() { ((ABORT == 0)) || die "interrupted during: $STAGE"; }
on_err() { die "unexpected failure at line $1 during: $STAGE (see $LOG)"; }

run() {
	local desc=$1 rc=0
	shift
	[[ $1 == as_user ]] && set -- "${AS_USER[@]}" "${@:2}"
	log "\$ $*"
	busy "$desc"
	setsid -w "$@" </dev/null >>"$LOG" 2>&1 || rc=$?
	if ((rc)); then
		printf '%s  %s✗%s %s\n' "$C_CL" "$C_R" "$C_0" "$desc" >&2
		tail -n 15 "$LOG" | sed 's/^/    | /' >&2
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

# journal

jot() {
	local IFS=$'\t'
	printf '%s\n' "$*" >>"$BAK/journal"
}

rollback() {
	trap '' INT TERM HUP
	[[ -s $BAK/journal ]] || return 0
	printf '\n%s==> rolling back %d change(s)%s\n' "$C_B" "$(wc -l <"$BAK/journal")" "$C_0" >&2
	log "=== rollback"
	local op a b c p pk reset=0
	while IFS=$'\t' read -r op a b c; do
		log "undo: $op $a $b"
		case $op in
		restore) rm -rf -- "$a" && cp -a -- "$BAK/files$a" "$a" ;;
		remove) rm -rf -- "$a" ;;
		rmdir) rmdir -- "$a" ;;
		sv-off) rm -f -- "$SVDIR/$a" ;;
		sv-on) ln -sfn -- "$b" "$SVDIR/$a" ;;
		group) gpasswd -d "$b" "$a" ;;
		shell) usermod -s "$b" "$a" ;;
		pkgs)
			pk=()
			for p in $a; do installed "$p" && pk+=("$p"); done
			((${#pk[@]} == 0)) || xbps-remove -Ry -- "${pk[@]}"
			;;
		sudo) for p in 1 2 3; do xbps-install -Sy sudo && break; sleep 5; done ;;
		sysctl) reset=1; sysctl -p "$BAK/sysctl.orig" ;;
		initramfs) cp -a -- "$BAK/boot/." /boot/ ;;
		hrestore) as_user rm -rf -- "$a" && as_user cp -a -- "$UBAK$a" "$a" ;;
		hremove) as_user rm -rf -- "$a" ;;
		hmove) as_user rm -rf -- "$a" && as_user mv -- "$UBAK$a" "$a" ;;
		hrmdir) as_user rmdir -- "$a" ;;
		pkgback) read -ra a <<<"$a"; xbps-install -y -- "${a[@]}" ;;
		gset) as_user dbus-run-session gsettings set "${c:-org.gnome.desktop.interface}" "$a" "$b" ;;
		esac >>"$LOG" 2>&1 || printf '  %s! could not undo: %s %s%s\n' "$C_Y" "$op" "$a" "$C_0" >&2
	done < <(tac -- "$BAK/journal")
	: >"$BAK/journal"
	printf '%srolled back.%s backups: %s  log: %s\n' "$C_B" "$C_0" "$BAK" "$LOG" >&2
	((reset == 0)) || printf 'reboot to be sure every kernel setting is back.\n' >&2
	return 0
}

# system files

backup() {
	local dst=$1
	if [[ -e $dst || -L $dst ]]; then
		mkdir -p -- "$BAK/files${dst%/*}"
		cp -a -- "$dst" "$BAK/files$dst"
		jot restore "$dst"
	else
		jot remove "$dst"
	fi
}

mkdirs() {
	local d=$1 missing=()
	while [[ -n $d && ! -d $d ]]; do
		missing=("$d" "${missing[@]}")
		d=${d%/*}
	done
	for d in "${missing[@]}"; do
		install -d -o root -g root -m 0755 -- "$d"
		jot rmdir "$d"
	done
}

put() {
	local src=$1 dst=$2 mode=$3
	if [[ -f $dst && ! -L $dst ]] && cmp -s -- "$src" "$dst" &&
		[[ $(stat -c '%a %U %G' -- "$dst") == "${mode#0} root root" ]]; then
		skip "$dst"
		return 0
	fi
	mkdirs "${dst%/*}"
	backup "$dst"
	install -o root -g root -m "$mode" -- "$src" "$dst.pi-new"
	mv -f -- "$dst.pi-new" "$dst"
	ok "$dst ($mode)"
}

put_text() {
	local tmp
	tmp=$(mktemp -p "$BAK")
	cat >"$tmp"
	put "$tmp" "$1" "$2"
	rm -f -- "$tmp"
}

put_link() {
	local target=$1 dst=$2
	[[ -e $target ]] || die "$target does not exist"
	if [[ -L $dst && $(readlink -- "$dst") == "$target" ]]; then
		skip "$dst"
		return 0
	fi
	mkdirs "${dst%/*}"
	backup "$dst"
	ln -sfn -- "$target" "$dst.pi-new"
	mv -Tf -- "$dst.pi-new" "$dst"
	ok "$dst -> $target"
}

mode_for() {
	case $1 in
	/etc/nftables/* | /etc/sysctl.d/*) echo 0600 ;;
	/etc/sv/*/run | /etc/sv/*/finish) echo 0755 ;;
	*) echo 0644 ;;
	esac
}

put_tree() {
	local src dst
	while IFS= read -r -d '' src; do
		dst=/${src#"$REPO/root/$1/"}
		put "$src" "$dst" "$(mode_for "$dst")"
	done < <(find "$REPO/root/$1" -type f -print0 | sort -z)
}

# user files

stash() {
	if [[ -e $1 || -L $1 ]]; then
		as_user mkdir -p -m 0700 -- "$THOME/_backup"
		as_user mkdir -p -m 0700 -- "$UBAK"
		as_user mkdir -p -- "$UBAK${1%/*}"
		as_user cp -a -- "$1" "$UBAK$1"
		jot hrestore "$1"
	else
		jot hremove "$1"
	fi
}

move_aside() {
	[[ -e $1 || -L $1 ]] || return 0
	[[ -L $1 || $(readlink -f -- "$1") != "$REPO"/* ]] || die "$1 resolves into the repo, refusing to move it"
	as_user mkdir -p -m 0700 -- "$THOME/_backup"
	as_user mkdir -p -m 0700 -- "$UBAK"
	as_user mkdir -p -- "$UBAK${1%/*}"
	jot hmove "$1"
	as_user mv -- "$1" "$UBAK$1"
	ok "moved ${1/#$THOME/\~} to ${UBAK/#$THOME/\~}"
}

umkdir() {
	local d=$1 missing=()
	while [[ $d == "$THOME"/* && ! -d $d ]]; do
		missing=("$d" "${missing[@]}")
		d=${d%/*}
	done
	for d in "${missing[@]}"; do
		jot hrmdir "$d"
		as_user mkdir -m 0700 -- "$d"
	done
}

# services

sv_enable() {
	[[ -d /etc/sv/$1 ]] || die "service $1 not found in /etc/sv"
	if [[ -L $SVDIR/$1 ]]; then
		skip "service $1"
		return 0
	fi
	jot sv-off "$1"
	ln -s -- "/etc/sv/$1" "$SVDIR/$1"
	ok "service $1 enabled"
}

sv_disable() {
	local s
	for s in "$@"; do
		[[ -L $SVDIR/$s ]] || continue
		jot sv-on "$s" "$(readlink -- "$SVDIR/$s")"
		rm -f -- "$SVDIR/$s"
		ok "service $s disabled"
	done
}

# checks

installed() { xbps-query -- "$1" >/dev/null 2>&1; }
in_group() { [[ " $(id -nG -- "$TUSER") " == *" $1 "* ]]; }
join() { local IFS=$1; shift; echo "$*"; }

preflight() {
	[[ " $* " != *" -h "* && " $* " != *" --help "* ]] || usage 0

	((BASH_VERSINFO[0] >= 4)) || { echo "error: bash 4 or newer needed" >&2; exit 1; }

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
	for c in setsid setpriv flock tac stat install; do
		command -v "$c" >/dev/null || { echo "error: $c not found" >&2; exit 1; }
	done
}

resolve_user() {
	TUSER=${TUSER:-${DOAS_USER:-${SUDO_USER:-}}}
	[[ -n $TUSER ]] || { echo "error: cannot tell who you are, pass -u USER" >&2; exit 1; }
	[[ $TUSER != root ]] || { echo "error: the target user must not be root" >&2; exit 1; }
	getent passwd "$TUSER" >/dev/null || { echo "error: no such user: $TUSER" >&2; exit 1; }
	THOME=$(getent passwd "$TUSER" | cut -d: -f6)
	TGID=$(id -g -- "$TUSER")
	[[ -d $THOME && $(stat -c %U -- "$THOME") == "$TUSER" ]] ||
		{ echo "error: $THOME missing or not owned by $TUSER" >&2; exit 1; }
	UBAK=$THOME/_backup/$TS
	AS_USER=(setpriv --reuid="$TUSER" --regid="$TGID" --init-groups --
		env -i -C "$THOME" HOME="$THOME" USER="$TUSER" LOGNAME="$TUSER" SHELL=/bin/bash
		PATH="$THOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
		LANG="${LANG:-C.UTF-8}" TERM=dumb GIT_TERMINAL_PROMPT=0)
}

check_repo() {
	REPO=$(dirname -- "$(readlink -f -- "$0")")
	[[ -d $REPO/home && -d $REPO/root ]] || die "$REPO does not look like the dotfiles repo"

	local d=$REPO o bad
	while :; do
		o=$(stat -c %U -- "$d")
		[[ $o == root || $o == "$TUSER" ]] || die "$d is owned by $o, not by $TUSER or root"
		[[ $(stat -c %A -- "$d") != ????????w? ]] || die "$d is world-writable"
		[[ $d == / ]] && break
		d=$(dirname -- "$d")
	done

	bad=$(find "$REPO/home" "$REPO/root" \( -perm /022 -o \( ! -user "$TUSER" ! -user root \) \) -print -quit)
	[[ -z $bad ]] || die "unsafe owner or permissions: $bad (fix: chmod -R go-w '$REPO')"
	bad=$(find "$REPO/home" "$REPO/root" -type l -print -quit)
	[[ -z $bad ]] || die "symlink in the repo, refusing: $bad"
}

detect_hw() {
	local cpu d ven
	cpu=$(awk -F': ' '/^vendor_id/ { print $2; exit }' /proc/cpuinfo)
	case $cpu in
	GenuineIntel) HW_DESC+=("Intel CPU"); HW_PKGS+=(intel-ucode); NONFREE=1 ;;
	AuthenticAMD) HW_DESC+=("AMD CPU"); HW_PKGS+=(linux-firmware-amd) ;;
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
	if ((mib <= 4096)); then ZRAM_PCT=100
	elif ((mib <= 8192)); then ZRAM_PCT=75
	elif ((mib <= 16384)); then ZRAM_PCT=50
	else ZRAM_PCT=25
	fi
	ZRAM_MIB=$((mib * ZRAM_PCT / 100))
	((ZRAM_MIB <= 16384)) || ZRAM_MIB=16384
}

# plan

section() {
	printf '\n%s[%s]%s\n' "$C_B" "$2" "$C_0"
	sed 's/^/  /'
	if ask "  apply?"; then DO[$1]=1; else DO[$1]=0; fi
}

plan() {
	say "${C_B}Void post-install${C_0}  user: $TUSER  home: $THOME  repo: $REPO"
	say "Nothing changes until you confirm the plan at the end."

	section update "System upgrade" <<-EOF
		xbps-install -Su for the whole system. Recommended: Void is rolling and
		  installing onto an outdated system can fail on library versions.
		The only step a rollback cannot undo. (xbps itself is always updated:
		  the repos refuse an old xbps.)
	EOF
	section locale "English everywhere" <<-EOF
		/etc/locale.conf: LANG=en_US.UTF-8, LC_COLLATE=C (every app in English),
		  en_US.UTF-8 enabled in /etc/default/libc-locales and generated.
	EOF
	section cli "Shell and editors" <<-EOF
		Packages: ${PKG_CLI[*]}
		Copies home/{$(join , "${HOME_CLI[@]}")} into $THOME (real files, not links).
		Files in the way, and ~/.vimrc ~/.tmux.conf which would shadow the new
		  ones, are moved to ~/_backup/$TS.
		~/.bash_profile (from home/bash): sources ~/.bashrc, sets the Qt dark style
		  and on tty1 runs start-g0wm, so boot goes grub -> plymouth/LUKS ->
		  agetty with the cat in /etc/issue -> login -> g0wm.
		Login shell /bin/bash.
	EOF
	section lsp "Language servers for nvim" <<-EOF
		Packages: ${PKG_LSP[*]}
	EOF
	section harden "Kernel and firewall hardening" <<-EOF
		Packages: ${PKG_HARDEN[*]}
		/etc/sysctl.d/{10,20,30,40}-*.conf (0600), applied now with sysctl -p.
		/etc/nftables/nft_base_desktop.conf (0600), included by /etc/nftables.conf:
		  input and forward dropped, output allowed. Checked with nft -c.
		/etc/ssh/ssh_config.d/10-local.conf, plus the Include line that Void's
		  /etc/ssh/ssh_config lacks (without it the file is ignored).
		Service: nftables.
	EOF
	section net "Network, DNS and time" <<-EOF
		Packages: ${PKG_NET[*]}
		NetworkManager conf.d: dns=none, random MAC on wifi and ethernet.
		dnscrypt-proxy on 127.0.0.1:53 (DNSSEC, no-log), checked with -check;
		  /etc/resolv.conf -> nameserver 127.0.0.1.
		chrony with NTS servers.
		Services: dbus NetworkManager dnscrypt-proxy chronyd on;
		  dhcpcd* wpa_supplicant ntpd off. Done last: the network may drop for
		  a moment, it is fully up after the reboot.
	EOF
	section boot "Boot: initramfs, splash, login screen" <<-EOF
		Packages: ${PKG_BOOT[*]}
		/etc/dracut.conf.d/00-hostonly.conf, plymouth theme void-minimal,
		  /etc/issue, tty1 agetty conf (clean login, plymouth quits there).
		GRUB: adds 'quiet splash' if missing, then update-grub.
		Rebuilds the initramfs of every installed kernel; the old images are
		  backed up and put back if anything fails.
	EOF
	detect_hw
	section hw "Hardware: microcode, GPU drivers, firmware updates" <<-EOF
		Found: $(join , "${HW_DESC[@]}")
		Packages: $(printf '%s\n' "${HW_PKGS[@]}" | sort -u | tr '\n' ' ')fwupd
		$( ((NONFREE)) && echo "Adds the Void nonfree repo (void-repo-nonfree): intel-ucode lives there." )
		New microcode needs a new initramfs: rebuilt for every kernel.
		fwupd is started by D-Bus on demand (no runit service); its metadata
		  is fetched once at the end: 'fwupdmgr get-updates' to check.
	EOF
	section power "Power: power-profiles-daemon (as in GNOME), balanced" <<-EOF
		Removes tlp and tlp-rdw if installed and disables their service
		  (they fight power-profiles-daemon over the same knobs).
		Packages: ${PKG_POWER[*]}; service power-profiles-daemon on, profile
		  set to balanced ('powerprofilesctl set performance' to change it).
	EOF
	section logs "System logs: socklog" <<-EOF
		Packages: ${PKG_LOGS[*]}; services socklog-unix and nanoklogd on: logs in
		  /var/log/socklog (kernel, daemons, firewall drops). $TUSER in the socklog
		  group, read them with 'svlogtail'.
		Service watchdog: notifications to the g0wm session for crashes, disk and
		  filesystem errors, overheating, USB plug/unplug/errors (kernel log, a
		  click opens it in foot), runit services restarting in a loop, batteries
		  at 20%/10%, disks over 90%, microphone and webcam in use.
		  /etc/sysctl.d/60-watchdog.conf: print-fatal-signals=1, so crashes that
		  a program catches and re-raises get logged too.
	EOF
	zram_size
	section swap "Swap in compressed RAM (zramen)" <<-EOF
		Packages: ${PKG_SWAP[*]}; service zramen on.
		This machine: $(($(awk '/^MemTotal:/ { print $2 }' /proc/meminfo) / 1024)) MiB RAM -> ${ZRAM_PCT}% = ${ZRAM_MIB} MiB of zstd zram
		  (about 3x that once compressed; <=4G 100%, <=8G 75%, <=16G 50%, else 25%,
		  at most 16 GiB). /etc/sv/zramen/conf, kept by xbps on updates; a log
		  service sends its messages to syslog instead of tty1 under /etc/issue.
		/etc/sysctl.d/50-zram.conf: swappiness 180, page-cluster 0 (the usual
		  tuning when swap is RAM, not disk).
	EOF
	section dirs "Home folders (custom user-dirs)" <<-EOF
		Copies home/{$(join , "${HOME_DIRS[@]}")}: ~/.config/user-dirs.dirs and user-dirs.locale
		  from this machine (Get, Random, Media/{Music,Pictures,Videos}...), and
		  creates those folders. Standard ones not used by it
		  ($(join ' ' "${XDG_DEFAULT_DIRS[@]}")) are moved to ~/_backup/$TS.
	EOF
	section desktop "Desktop: g0wm" <<-EOF
		Packages: g0wm build deps, the session (dbus elogind polkit pipewire
		  xwayland) and what settings.json runs (foot Thunar grim slurp swappy
		  swayidle gtklock wmenu brightnessctl playerctl; librewolf is in apps).
		Services: dbus elogind polkitd on, acpid off (elogind replaces it).
		Groups for $TUSER: ${USER_GROUPS[*]}.
		Copies home/{$(join , "${HOME_DESKTOP[@]}")} (gtklock theme too), clones $G0WM_URL
		  into ~/.local/src/g0wm: ./configure, make, make test, make install
		  (into ~/.local/bin). Start it from tty1 with start-g0wm.
	EOF
	section media "Screen sharing and audio (Wayland)" <<-EOF
		Packages: ${PKG_MEDIA[*]}
		PipeWire starts wireplumber and pipewire-pulse itself: links
		  /etc/pipewire/pipewire.conf.d/{10-wireplumber,20-pipewire-pulse}.conf,
		  ALSA apps go through PipeWire (alsa-pipewire).
		Screen sharing: copies home/{$(join , "${HOME_MEDIA[@]}")}:
		  ~/.config/xdg-desktop-portal/g0wm-portals.conf picks the wlr portal
		  (wlr.portal only lists sway, river... so on g0wm nothing is found),
		  ~/.config/xdg-desktop-portal-wlr/config picks the output with slurp.
		  g0wm's settings.json already imports WAYLAND_DISPLAY into D-Bus.
	EOF
	section apps "User apps, Thunar, default apps, shortcuts" <<-EOF
		Adds the librewolf repo (index-0/librewolf-void, prebuilt) with its
		  signing key pinned from the repo: no key prompt, and a changed key fails.
		Adds the Void nonfree repo (void-repo-nonfree): unrar lives there.
		Installs rar (trial) from rarlab.com into /usr/local/bin: not in the repos.
		Packages: ${PKG_APPS[*]}
		Copies home/{$(join , "${HOME_APPS[@]}")}:
		  Thunar: 'Open Terminal Here' runs foot, thunar-volman automounts drives;
		  nvim-foot.desktop, so text files open nvim inside foot;
		  ~/.local/bin: photo video pdf office browser files audio wifi bluetooth
		    record extract compress open (the xdg ones start the default app, or
		    open the files given; wifi/bluetooth on|off switch the radio; Super+Print
		    runs record; extract/compress wrap tar 7z unrar gpg age; open FILE...
		    picks the app from the extension: Loupe, Showtime, Papers, LibreOffice,
		    xarchiver, librewolf, Thunar, vim for text, xxd | less for binaries).
		Writes ~/.config/mimeapps.list in place (${#MIME_DEFAULTS[@]} types: images Loupe,
		  video Showtime, PDF Papers, web librewolf, folders Thunar, archives
		  xarchiver, documents LibreOffice, text nvim); entries it does not set
		  and other sections are kept. Read by xdg-open, xdg-mime, gio, Thunar
		  and the portal alike; checked with xdg-mime afterwards.
	EOF
	section session "Keyring, polkit, network and bluetooth tray" <<-EOF
		Packages: ${PKG_SESSION[*]}
		/etc/pam.d/login and passwd get pam_gnome_keyring (optional lines): the
		  keyring unlocks with your login password and follows password changes.
		g0wm starts the keyring on D-Bus and the polkit agent. No tray icons:
		  'wifi' and 'bluetooth' open nm-connection-editor and blueman-manager,
		  and blueman's tray plugin is switched off in gsettings.
		Service bluetoothd on, $TUSER in the bluetooth group if it exists.
	EOF
	section theme "GTK theme: Adwaita dark" <<-EOF
		Packages: ${PKG_THEME[*]}
		Copies home/{$(join , "${HOME_THEME[@]}")}: ~/.gtkrc-2.0 and GTK 3/4 settings.ini.
		gsettings for GTK 4/libadwaita (and the portal): color-scheme prefer-dark,
		  gtk-theme Adwaita-dark, Adwaita icons and cursor, SF Mono 10 fonts.
		Qt 5/6: adwaita-qt, Adwaita-Dark style via QT_STYLE_OVERRIDE (~/.bash_profile).
		AdwaitaLegacy $ICONS_TAG from GNOME into $ICONS_DIR: the full-color icons
		  Adwaita inherits but Void does not package (pavucontrol, Thunar... show
		  blanks without them).
	EOF
	section fonts "Fonts: SF Mono everywhere, Nerd Fonts, emoji, CJK" <<-EOF
		Packages: ${PKG_FONTS[*]}
		  nerd-fonts is the full set: about 15 GB once installed.
		SF Mono into $SF_DIR, SF Pro into $SFPRO_DIR (root, 0644),
		  cloned from $FONT_URL and $SFPRO_URL.
		Copies home/{$(join , "${HOME_FONTS[@]}")}: fontconfig makes SF Mono the monospace,
		  sans-serif and serif font (Nerd symbols, emoji and CJK as fallback).
	EOF
	section doas "doas instead of sudo" <<-EOF
		Installs opendoas, writes /etc/doas.conf 'permit persist :wheel' (root:root
		  0400, the password is remembered for a few minutes),
		  puts $TUSER in wheel and checks doas really lets $TUSER in.
		ignorepkg=sudo in /etc/xbps.d, then removes sudo and /etc/sudoers*.
		Refused if $TUSER has no usable password: that would lock you out.
	EOF

	if ((DO[doas])); then
		local st
		st=$(passwd -S -- "$TUSER" | awk '{print $2}')
		[[ $st == P ]] || die "$TUSER has no usable password (passwd -S: $st), run 'passwd $TUSER' first"
	fi

	local k any=0
	for k in "${SECTIONS[@]}"; do ((DO[$k])) && any=1; done
	((any)) || { say "nothing selected."; exit 0; }

	local need=6 avail
	((DO[fonts])) && need=$((need + 16))
	((DO[apps])) && need=$((need + 2))
	avail=$(df --output=avail -BG / | tail -n1 | tr -dc 0-9)
	((avail >= need)) || die "about ${need} GB needed on /, only ${avail} GB free"

	if [[ -n ${SSH_CONNECTION:-} ]] && ((DO[net])); then
		warn "you are on SSH: the network step at the end may drop this connection"
	fi
	printf '\n'
	ask "Proceed with the selected steps?" || { say "nothing changed."; exit 0; }
}

# steps

do_update() {
	step "System upgrade"
	run "update the system" xbps-install -Suy
}

do_packages() {
	step "Packages"
	local want=("${PKG_CORE[@]}") new=() old=() p
	if ((DO[power])); then
		for p in tlp-rdw tlp; do installed "$p" && old+=("$p"); done
		if ((${#old[@]})); then
			sv_disable tlp
			jot pkgback "${old[*]}"
			run "remove ${old[*]}" xbps-remove -y -- "${old[@]}"
		fi
	fi
	((DO[cli])) && want+=("${PKG_CLI[@]}")
	((DO[lsp])) && want+=("${PKG_LSP[@]}")
	((DO[harden])) && want+=("${PKG_HARDEN[@]}")
	((DO[net])) && want+=("${PKG_NET[@]}")
	((DO[boot])) && want+=("${PKG_BOOT[@]}")
	((DO[desktop])) && want+=("${PKG_DESKTOP[@]}")
	((DO[media])) && want+=("${PKG_MEDIA[@]}")
	((DO[apps])) && want+=("${PKG_APPS[@]}")
	((DO[session])) && want+=("${PKG_SESSION[@]}")
	((DO[theme])) && want+=("${PKG_THEME[@]}")
	((DO[locale])) && want+=("${PKG_LOCALE[@]}")
	((DO[hw])) && want+=("${PKG_HW[@]}" "${HW_PKGS[@]}")
	((DO[power])) && want+=("${PKG_POWER[@]}")
	((DO[logs])) && want+=("${PKG_LOGS[@]}")
	((DO[dirs])) && want+=("${PKG_DIRS[@]}")
	((DO[swap])) && want+=("${PKG_SWAP[@]}")
	((DO[fonts])) && want+=("${PKG_FONTS[@]}" git)
	((DO[doas])) && want+=(opendoas)
	for p in $(printf '%s\n' "${want[@]}" | sort -u); do
		installed "$p" || new+=("$p")
	done
	if ((${#new[@]} == 0)); then
		skip "all ${#want[@]} packages installed"
		return 0
	fi
	NEW_PKGS=("${new[@]}")
	jot pkgs "${new[*]}"
	run "install ${#new[@]} packages: ${new[*]}" xbps-install -y -- "${new[@]}"
	for p in "${new[@]}"; do
		installed "$p" || die "$p is not installed after xbps-install"
	done
}

save_sysctl() {
	local f key v
	for f in "$@"; do
		while IFS='=' read -r key _; do
			key=${key//[[:space:]]/}
			[[ -n $key && $key != \#* ]] || continue
			v=$(sysctl -n "$key" 2>/dev/null || true)
			[[ -z $v ]] || printf '%s = %s\n' "$key" "$v" >>"$BAK/sysctl.orig"
		done <"$f"
	done
	jot sysctl
}

do_harden() {
	step "Kernel and firewall hardening"
	local f
	save_sysctl "$REPO"/root/sysctl/etc/sysctl.d/*.conf
	put_tree sysctl
	for f in "$REPO"/root/sysctl/etc/sysctl.d/*.conf; do
		try "sysctl -p ${f##*/}" sysctl -p "/etc/sysctl.d/${f##*/}"
	done

	put_tree nftables
	put_text /etc/nftables.conf 0600 <<-'EOF'
		include "/etc/nftables/nft_base_desktop.conf"
	EOF
	run "nftables ruleset is valid" nft -c -f /etc/nftables.conf

	put_tree ssh
	if grep -qE '^[[:space:]]*Include[[:space:]]+/etc/ssh/ssh_config\.d/' /etc/ssh/ssh_config; then
		skip "ssh_config includes ssh_config.d"
	else
		put_text /etc/ssh/ssh_config 0644 < <(
			echo 'Include /etc/ssh/ssh_config.d/*.conf'
			cat /etc/ssh/ssh_config
		)
	fi
	run "ssh config parses" ssh -G localhost
}

do_net_files() {
	step "Network, DNS and time: config"
	put_tree networkmanager
	put_tree dnscrypt
	put_tree chrony
	run "dnscrypt-proxy config is valid" dnscrypt-proxy -config /etc/dnscrypt-proxy/dnscrypt-proxy.toml -check
	try "chrony config parses" chronyd -p -f /etc/chrony.conf
	run "NetworkManager config parses" NetworkManager --print-config
}

do_boot() {
	step "Boot"
	put_tree dracut
	put_tree agetty
	put_tree plymouth
	run "agetty run script parses" sh -n /etc/sv/agetty-generic/run
	[[ -f /usr/lib/plymouth/two-step.so ]] || die "plymouth two-step module missing"
	[[ $(plymouth-set-default-theme) == void-minimal ]] || die "plymouth does not pick void-minimal"
	ok "plymouth theme void-minimal"

	if [[ -f /etc/default/grub ]]; then
		local line w add=()
		line=$(grep -E '^GRUB_CMDLINE_LINUX(_DEFAULT)?=' /etc/default/grub || true)
		for w in quiet splash; do
			[[ " $line " =~ [\"\'[:space:]]$w[\"\'[:space:]] ]] || add+=("$w")
		done
		if ((${#add[@]})); then
			backup /etc/default/grub
			if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT="' /etc/default/grub; then
				sed -i -E "s/^(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*)\"/\1 ${add[*]}\"/" /etc/default/grub
			else
				echo "GRUB_CMDLINE_LINUX_DEFAULT=\"${add[*]}\"" >>/etc/default/grub
			fi
			grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=\".*${add[-1]}\"" /etc/default/grub ||
				die "could not edit GRUB_CMDLINE_LINUX_DEFAULT"
			ok "GRUB: added ${add[*]}"
		else
			skip "GRUB has quiet splash"
		fi
		[[ -f /boot/grub/grub.cfg ]] && backup /boot/grub/grub.cfg
		run "update-grub" update-grub
	else
		warn "no /etc/default/grub: add 'quiet splash' to the kernel command line yourself"
	fi

	regen_initramfs
}

regen_initramfs() {
	((REGEN < 2)) || return 0
	local kvers=() k
	for k in /usr/lib/modules/*/modules.dep; do
		[[ -e $k ]] || continue
		k=${k%/modules.dep}
		kvers+=("${k##*/}")
	done
	((${#kvers[@]})) || die "no installed kernel found in /usr/lib/modules"
	install -d -m 0700 -- "$BAK/boot"
	if compgen -G '/boot/initramfs-*.img' >/dev/null; then
		cp -a /boot/initramfs-*.img "$BAK/boot/" || die "cannot back up /boot/initramfs-*.img (disk full?)"
	fi
	jot initramfs
	for k in "${kvers[@]}"; do
		run "initramfs for $k" dracut -q --force "/boot/initramfs-$k.img" "$k"
		[[ -s /boot/initramfs-$k.img ]] || die "/boot/initramfs-$k.img is empty"
	done
	REGEN=2
}

do_hw() {
	step "Hardware"
	local p
	for p in intel-ucode linux-firmware-amd; do
		[[ " ${NEW_PKGS[*]} " == *" $p "* ]] && REGEN=1
	done
	((REGEN)) && ok "new microcode: the initramfs gets rebuilt" || skip "microcode in the initramfs"
	[[ -e /dev/dri/renderD128 ]] && ok "GPU render node present" || warn "no /dev/dri/renderD128 yet, check after the reboot"
	return 0
}

do_dirs() {
	step "Home folders"
	do_home "${HOME_DIRS[@]}"
	local conf=$THOME/.config/user-dirs.dirs line path targets=() d t used
	while IFS= read -r line; do
		[[ $line =~ ^XDG_[A-Z]+_DIR=\"(.*)\"$ ]] || continue
		path=${BASH_REMATCH[1]}
		path=${path/#\$HOME/$THOME}
		[[ $path == "$THOME"/* ]] || { warn "$path is outside $THOME, not created"; continue; }
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
		((used)) || move_aside "$d"
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

do_swap() {
	step "Swap"
	put_text /etc/sv/zramen/conf 0644 <<-EOF
		export ZRAM_COMP_ALGORITHM=zstd
		export ZRAM_SIZE=$ZRAM_PCT
		export ZRAM_MAX_SIZE=$ZRAM_MIB
		export ZRAM_PRIORITY=32767
		exec 2>&1
	EOF
	grep -qw zstd /sys/block/zram0/comp_algorithm 2>/dev/null ||
		modprobe -n zram 2>/dev/null || die "the kernel has no zram module"
	save_sysctl "$REPO"/root/zram/etc/sysctl.d/*.conf
	put_tree zram
	try "sysctl -p 50-zram.conf" sysctl -p /etc/sysctl.d/50-zram.conf
}

do_post() {
	step "Final settings"
	local i
	if ((DO[power])); then
		for ((i = 0; i < 15; i++)); do
			powerprofilesctl get >/dev/null 2>&1 && break
			sleep 1
		done
		try "power profile balanced" powerprofilesctl set balanced
	fi
	if ((DO[hw])); then
		try "fwupd metadata" fwupdmgr refresh --force
	fi
	if ((DO[swap])); then
		for ((i = 0; i < 10; i++)); do
			grep -q '^/dev/zram' /proc/swaps && break
			sleep 1
		done
		if grep -q '^/dev/zram' /proc/swaps; then ok "zram swap active"; else warn "zram swap not up yet, check 'sv status zramen'"; fi
	fi
	if ((REGEN == 1)); then
		regen_initramfs
	fi
	return 0
}

do_groups() {
	step "Groups"
	local g groups=()
	((DO[desktop])) && groups+=("${USER_GROUPS[@]}")
	((DO[doas])) && groups+=(wheel)
	((DO[session])) && groups+=(bluetooth)
	((DO[logs])) && groups+=(socklog)
	((${#groups[@]})) || return 0
	for g in $(printf '%s\n' "${groups[@]}" | sort -u); do
		getent group "$g" >/dev/null || { warn "group $g does not exist"; continue; }
		if in_group "$g"; then
			skip "$TUSER in $g"
			continue
		fi
		jot group "$g" "$TUSER"
		gpasswd -a "$TUSER" "$g" >>"$LOG" 2>&1 || die "cannot add $TUSER to $g"
		ok "$TUSER added to $g"
	done
}

do_home() {
	local pkg src rel dst mode part p parts n=0
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
			done
			mode=0600
			[[ -x $src ]] && mode=0700
			if [[ -f $dst && ! -L $dst ]] && cmp -s -- "$src" "$dst" &&
				[[ $(stat -c %a -- "$dst") == "${mode#0}" ]]; then
				continue
			fi
			umkdir "${dst%/*}"
			if [[ -e $dst || -L $dst ]]; then
				move_aside "$dst"
			else
				jot hremove "$dst"
			fi
			as_user install -m "$mode" -- "$src" "$dst"
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

do_g0wm() {
	step "Desktop: g0wm"
	do_home "${HOME_DESKTOP[@]}"

	local src=$THOME/.local/src/g0wm bin=$THOME/.local/bin before= rev out f
	if [[ -d $src/.git ]]; then
		[[ $(as_user git -C "$src" remote get-url origin) == "$G0WM_URL" ]] ||
			die "$src is not a clone of $G0WM_URL"
		[[ -z $(as_user git -C "$src" status --porcelain --untracked-files=no) ]] ||
			die "$src has local changes, commit or stash them first"
		before=$(as_user git -C "$src" rev-parse HEAD)
		try "update g0wm source" as_user git -C "$src" pull --ff-only
	else
		as_user mkdir -p -- "$THOME/.local/src"
		jot hremove "$src"
		run "clone g0wm" as_user git clone --depth 1 -- "$G0WM_URL" "$src"
	fi
	rev=$(as_user git -C "$src" rev-parse HEAD)
	log "g0wm at $rev"
	if [[ $before == "$rev" && -x $bin/g0wm ]]; then
		skip "g0wm ${rev:0:12} installed"
		return 0
	fi

	run "configure g0wm" as_user sh -c 'cd "$1" && exec ./configure' _ "$src"
	run "build g0wm" as_user make -C "$src" -j"$(nproc)"
	run "test g0wm" as_user make -C "$src" test
	for f in g0wm start-g0wm g0wm-status.sh; do stash "$bin/$f"; done
	run "install g0wm into ~/.local/bin" as_user make -C "$src" install
	out=$(as_user "$bin/g0wm" -v 2>&1 || true)
	[[ $out == g0wm\ * ]] || die "the installed g0wm does not run: $out"
	ok "${out%%$'\n'*}"

	local wp
	wp=$(grep -o '"wallpaper": *"[^"]*"' "$REPO/home/g0wm/.config/g0wm/settings.json" | cut -d'"' -f4 || true)
	[[ -z $wp || -f $wp ]] || warn "wallpaper $wp does not exist, set it in settings.json"
}

font_repo() {
	local tmp f n=0
	tmp=$(as_user mktemp -d)
	run "clone ${1##*/}" as_user git clone --depth 1 -- "$1" "$tmp/f"
	while IFS= read -r -d '' f; do
		put "$f" "$2/${f##*/}" 0644
		n=$((n + 1))
	done < <(find "$tmp/f" -type f \( -name '*.otf' -o -name '*.ttf' \) -print0 | sort -z)
	as_user rm -rf -- "$tmp"
	((n)) || die "no font files in $1"
}

do_fonts() {
	step "Fonts"
	local f
	font_repo "$FONT_URL" "$SF_DIR"
	font_repo "$SFPRO_URL" "$SFPRO_DIR"
	run "refresh the font cache" fc-cache -f
	do_home "${HOME_FONTS[@]}"
	f=$(as_user fc-match -f '%{family}' monospace 2>/dev/null || true)
	[[ $f == *"SF Mono"* ]] || die "monospace resolves to '$f', not SF Mono"
	ok "monospace is SF Mono"
}

gset() {
	local old schema=${3:-org.gnome.desktop.interface}
	old=$(as_user dbus-run-session gsettings get "$schema" "$1")
	if [[ $old == "$2" ]]; then
		skip "gsettings $1"
		return 0
	fi
	jot gset "$1" "$old" "$schema"
	run "gsettings $1 $2" as_user dbus-run-session gsettings set "$schema" "$1" "$2"
}

legacy_icons() {
	local tmp stage
	tmp=$(as_user mktemp -d)
	run "clone AdwaitaLegacy $ICONS_TAG" as_user git -c advice.detachedHead=false clone --depth 1 --branch "$ICONS_TAG" -- "$ICONS_URL" "$tmp/src"
	[[ -f $tmp/src/index.theme && -d $tmp/src/AdwaitaLegacy/48x48 ]] || die "unexpected layout in $ICONS_URL"
	[[ -z $(find "$tmp/src/AdwaitaLegacy" -type l -print -quit) ]] || die "symlinks in $ICONS_URL, refusing"
	stage=$(mktemp -d -p "${ICONS_DIR%/*}" .AdwaitaLegacy.XXXXXX)
	cp -r -- "$tmp/src/AdwaitaLegacy/." "$stage/"
	cp -- "$tmp/src/index.theme" "$stage/index.theme"
	as_user rm -rf -- "$tmp"
	rm -rf -- "$stage/cursors"
	chown -R root:root "$stage"
	find "$stage" -type d -exec chmod 0755 {} +
	find "$stage" -type f -exec chmod 0644 {} +
	if [[ -d $ICONS_DIR ]] && diff -rq -x icon-theme.cache "$stage" "$ICONS_DIR" >/dev/null; then
		rm -rf -- "$stage"
		skip "$ICONS_DIR"
		return 0
	fi
	backup "$ICONS_DIR"
	rm -rf -- "$ICONS_DIR"
	mv -T -- "$stage" "$ICONS_DIR"
	ok "$ICONS_DIR ($ICONS_TAG)"
	try "icon cache" gtk-update-icon-cache -f -q "$ICONS_DIR"
}

do_theme() {
	step "GTK theme"
	legacy_icons
	do_home "${HOME_THEME[@]}"
	[[ -d /usr/share/themes/Adwaita-dark/gtk-2.0 && -d /usr/share/themes/Adwaita-dark/gtk-3.0 ]] ||
		die "Adwaita-dark for GTK 2/3 missing (gnome-themes-extra, -gtk)"
	[[ -f /usr/lib/qt6/plugins/styles/adwaita.so && -f /usr/lib/qt5/plugins/styles/adwaita.so ]] ||
		die "adwaita-qt style plugins missing"
	as_user dbus-run-session gsettings get org.gnome.desktop.interface color-scheme >/dev/null 2>&1 ||
		die "gsettings cannot read org.gnome.desktop.interface"
	gset color-scheme "'prefer-dark'"
	gset gtk-theme "'Adwaita-dark'"
	gset icon-theme "'Adwaita'"
	gset cursor-theme "'Adwaita'"
	gset font-name "'SF Mono 10'"
	gset document-font-name "'SF Mono 10'"
	gset monospace-font-name "'SF Mono 10'"
}

do_locale() {
	step "Locale"
	local f=/etc/default/libc-locales
	put_tree locale
	if grep -qE '^en_US\.UTF-8 UTF-8' "$f"; then
		skip "en_US.UTF-8 enabled"
	else
		grep -qE '^#[[:space:]]*en_US\.UTF-8 UTF-8' "$f" || die "en_US.UTF-8 is not listed in $f"
		put_text "$f" 0644 < <(sed -E 's/^#[[:space:]]*(en_US\.UTF-8 UTF-8)/\1/' "$f")
		run "generate locales" xbps-reconfigure -f glibc-locales
	fi
	[[ $(locale -a 2>/dev/null) == *en_US.utf8* ]] || die "en_US.UTF-8 locale not available"
	ok "en_US.UTF-8 available"
}

write_mimeapps() {
	local mf=$THOME/.config/mimeapps.list new ours
	ours=$(mktemp -p "$BAK")
	new=$(mktemp -p "$BAK")
	printf '%s\n' "${MIME_DEFAULTS[@]}" >"$ours"
	{
		echo '[Default Applications]'
		cat "$ours"
		if [[ -f $mf ]]; then
			awk -F= 'NR == FNR { k[$1]; next }
				/^\[/ { s = $0; next }
				s == "[Default Applications]" && NF && !($1 in k)' "$ours" "$mf"
			awk '/^\[/ { s = $0 } s != "" && s != "[Default Applications]"' "$mf"
		fi
	} >"$new"
	if [[ -f $mf && ! -L $mf ]] && cmp -s "$new" "$mf"; then
		skip "~/.config/mimeapps.list"
	else
		stash "$mf"
		as_user rm -f -- "$mf"
		as_user mkdir -p -- "$THOME/.config"
		as_user sh -c 'umask 077 && cat >"$1"' _ "$mf" <"$new"
		ok "~/.config/mimeapps.list (${#MIME_DEFAULTS[@]} defaults)"
	fi
	rm -f -- "$ours" "$new"
}

# rar (to create .rar) is not in the Void repos: take the rarlab build
do_rar() {
	local tmp page url
	if [[ -x /usr/local/bin/rar ]]; then
		skip "/usr/local/bin/rar"
		return 0
	fi
	page=$(curl -fsSL "$RAR_PAGE") || die "cannot fetch $RAR_PAGE"
	url=$(grep -m 1 -o 'rar/rarlinux-x64-[0-9]*\.tar\.gz' <<<"$page") ||
		die "no rarlinux-x64 download on $RAR_PAGE"
	tmp=$(mktemp -d)
	run "download ${url##*/}" curl -fsSLo "$tmp/rar.tar.gz" "https://www.rarlab.com/$url"
	run "unpack ${url##*/}" tar -xzf "$tmp/rar.tar.gz" -C "$tmp"
	put "$tmp/rar/rar" /usr/local/bin/rar 0755
	rm -rf -- "$tmp"
}
do_apps() {
	step "User apps"
	do_rar
	do_home "${HOME_APPS[@]}"
	write_mimeapps
	local mime want got
	for mime in image/png=org.gnome.Loupe.desktop video/mp4=org.gnome.Showtime.desktop \
		application/pdf=org.gnome.Papers.desktop inode/directory=thunar.desktop \
		x-scheme-handler/https=librewolf.desktop text/plain=nvim-foot.desktop; do
		want=${mime#*=}
		got=$(as_user xdg-mime query default "${mime%%=*}" 2>/dev/null || true)
		[[ $got == "$want" ]] || die "xdg-mime: ${mime%%=*} opens '$got', expected $want"
		[[ -f /usr/share/applications/$want || -f $THOME/.local/share/applications/$want ]] ||
			die "$want is not installed"
	done
	ok "xdg-mime defaults answer as mimeapps.list says"
}

pam_keyring() {
	local f=$1
	shift
	[[ -f $f ]] || die "$f missing"
	if grep -q pam_gnome_keyring "$f"; then
		skip "$f has pam_gnome_keyring"
		return 0
	fi
	put_text "$f" 0644 < <(cat -- "$f"; printf '%s\n' "$@")
}

do_session() {
	step "Session: keyring, polkit, bluetooth"
	[[ -f /usr/lib/security/pam_gnome_keyring.so ]] || die "pam_gnome_keyring.so missing"
	[[ -x /usr/libexec/polkit-gnome-authentication-agent-1 ]] || die "polkit-gnome agent missing"
	pam_keyring /etc/pam.d/login \
		'auth       optional     pam_gnome_keyring.so' \
		'session    optional     pam_gnome_keyring.so auto_start'
	pam_keyring /etc/pam.d/passwd \
		'password   optional     pam_gnome_keyring.so'
	gset plugin-list "['!StatusNotifierItem', '!StatusIcon']" org.blueman.general
}

do_media() {
	step "Screen sharing and audio"
	put_link /usr/share/examples/wireplumber/10-wireplumber.conf \
		/etc/pipewire/pipewire.conf.d/10-wireplumber.conf
	put_link /usr/share/examples/pipewire/20-pipewire-pulse.conf \
		/etc/pipewire/pipewire.conf.d/20-pipewire-pulse.conf
	[[ -f /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf ]] ||
		die "alsa-pipewire did not install its ALSA config"
	[[ -f /usr/share/xdg-desktop-portal/portals/wlr.portal ]] ||
		die "xdg-desktop-portal-wlr did not install wlr.portal"
	ok "PipeWire ALSA config and wlr portal present"
	do_home "${HOME_MEDIA[@]}"
}

do_repos() {
	step "Repositories"
	((DO[apps])) && put_tree librewolf
	run "sync repository index (network check)" xbps-install -S
	try "update xbps itself" xbps-install -uy xbps
	if ((DO[hw] && NONFREE || DO[apps])); then
		if installed void-repo-nonfree; then
			skip "nonfree repo"
		else
			jot pkgs void-repo-nonfree
			run "add the nonfree repo" xbps-install -y void-repo-nonfree
			run "sync the nonfree index" xbps-install -S
		fi
	fi
}

do_services() {
	step "Services"
	[[ -d $SVDIR ]] || die "$SVDIR does not exist, is this system running runit?"
	if ((DO[desktop] || DO[session] || DO[power] || DO[hw] || DO[media])); then
		sv_enable dbus
	fi
	if ((DO[desktop])); then
		sv_disable acpid
		sv_enable elogind
		sv_enable polkitd
		[[ -L $SVDIR/seatd ]] && warn "seatd and elogind are both enabled, consider: rm $SVDIR/seatd"
	fi
	((DO[harden])) && sv_enable nftables
	((DO[session])) && sv_enable bluetoothd
	if ((DO[power])); then
		sv_disable tlp
		sv_enable power-profiles-daemon
	fi
	((DO[swap])) && sv_enable zramen
	if ((DO[logs])); then
		sv_enable socklog-unix
		sv_enable nanoklogd
		save_sysctl "$REPO"/root/watchdog/etc/sysctl.d/*.conf
		put_tree watchdog
		try "sysctl -p 60-watchdog.conf" sysctl -p /etc/sysctl.d/60-watchdog.conf
		sv_enable watchdog
	fi
	return 0
}

do_doas() {
	step "doas instead of sudo"
	local doas tmp f
	doas=$(command -v doas) || die "doas not installed"
	[[ $(stat -c %u -- "$doas") == 0 && -u $doas ]] || die "$doas is not setuid root"

	put_text /etc/doas.conf 0400 <<-'EOF'
		permit persist :wheel
	EOF

	tmp=$(mktemp -d)
	install -m 0444 /etc/doas.conf "$tmp/doas.conf"
	chmod 0711 "$tmp"
	if as_user doas -C "$tmp/doas.conf" true >>"$LOG" 2>&1; then
		rm -rf -- "$tmp"
		ok "doas lets $TUSER in"
	else
		rm -rf -- "$tmp"
		die "doas.conf does not let $TUSER in, keeping sudo"
	fi

	if grep -rhsqE '^[[:space:]]*ignorepkg[[:space:]]*=[[:space:]]*sudo[[:space:]]*$' /etc/xbps.d; then
		skip "xbps ignores sudo"
	else
		put_text /etc/xbps.d/90-ignore-sudo.conf 0644 <<-'EOF'
			ignorepkg=sudo
		EOF
	fi

	if installed sudo; then
		jot sudo
		run "remove sudo" xbps-remove -y sudo
	else
		skip "sudo not installed"
	fi
	for f in /etc/sudoers /etc/sudoers.d /etc/sudoers.new-*; do
		[[ -e $f ]] || continue
		backup "$f"
		rm -rf -- "$f"
		ok "removed $f"
	done
	hash -r
	if installed sudo || command -v sudo >/dev/null; then
		die "sudo is still there"
	fi
	ok "sudo is gone"
}

do_net_services() {
	step "Network, DNS and time: services"
	local s i
	trap '' HUP
	if [[ -n ${SSH_CONNECTION:-} ]]; then
		say "  on SSH: the rest goes to $LOG only"
		exec >>"$LOG" 2>&1
	fi
	sv_disable ntpd isc-ntpd openntpd wpa_supplicant
	for s in "$SVDIR"/dhcpcd*; do
		[[ -L $s ]] && sv_disable "${s##*/}"
	done
	sv_enable chronyd
	sv_enable dbus
	sv_enable NetworkManager
	sv_enable dnscrypt-proxy
	put_text /etc/resolv.conf 0644 <<-'EOF'
		nameserver 127.0.0.1
		options edns0
	EOF
	for ((i = 0; i < 15; i++)); do
		[[ $(sv status dnscrypt-proxy 2>/dev/null || true) == run:* ]] && break
		sleep 1
	done
	if ((i < 15)); then ok "dnscrypt-proxy running"; else warn "dnscrypt-proxy not running yet, check it after the reboot"; fi
}

verify() {
	step "Final check"
	local bad=0 c
	if ((DO[cli])); then
		for c in vim nvim tmux fzf rg; do
			command -v "$c" >/dev/null || { warn "$c missing"; bad=1; }
		done
		cmp -s "$REPO/home/bash/.bashrc" "$THOME/.bashrc" && [[ ! -L $THOME/.bashrc ]] ||
			{ warn "~/.bashrc is not the repo's copy"; bad=1; }
	fi
	if ((DO[desktop])); then
		[[ -x $THOME/.local/bin/g0wm ]] || { warn "g0wm missing"; bad=1; }
		[[ -f $THOME/.config/g0wm/settings.json && ! -L $THOME/.config/g0wm/settings.json ]] ||
			{ warn "g0wm settings not installed"; bad=1; }
	fi
	if ((DO[apps])); then
		for c in librewolf loupe papers showtime soffice pavucontrol swaylock tree thunar xdg-open gtk-launch; do
			command -v "$c" >/dev/null || { warn "$c missing"; bad=1; }
		done
		[[ -x $THOME/.local/bin/open ]] || { warn "~/.local/bin/open missing"; bad=1; }
	fi
	if ((DO[power])); then
		command -v tlp >/dev/null && { warn "tlp still installed"; bad=1; }
		[[ -L $SVDIR/power-profiles-daemon ]] || { warn "power-profiles-daemon not enabled"; bad=1; }
	fi
	if ((DO[swap])); then
		[[ -L $SVDIR/zramen ]] || { warn "zramen not enabled"; bad=1; }
	fi
	if ((DO[logs])); then
		[[ -L $SVDIR/socklog-unix && -L $SVDIR/nanoklogd ]] || { warn "socklog not enabled"; bad=1; }
		[[ -L $SVDIR/watchdog ]] || { warn "watchdog not enabled"; bad=1; }
	fi
	if ((DO[session])); then
		for c in nm-connection-editor blueman-manager gnome-keyring-daemon; do
			command -v "$c" >/dev/null || { warn "$c missing"; bad=1; }
		done
		grep -q pam_gnome_keyring /etc/pam.d/login || { warn "keyring not in /etc/pam.d/login"; bad=1; }
	fi
	if ((DO[media])); then
		[[ -f $THOME/.config/xdg-desktop-portal/g0wm-portals.conf ]] || { warn "portal config not installed"; bad=1; }
	fi
	if ((DO[harden])); then
		[[ $(stat -c '%a %U' /etc/nftables.conf) == '600 root' ]] || { warn "/etc/nftables.conf permissions"; bad=1; }
	fi
	if ((DO[doas])); then
		[[ $(stat -c '%a %U %G' /etc/doas.conf) == '400 root root' ]] || { warn "/etc/doas.conf permissions"; bad=1; }
		command -v sudo >/dev/null && { warn "sudo still present"; bad=1; }
	fi
	((bad == 0)) || die "final check failed"
	ok "all good"
}

main() {
	while (($#)); do
		case $1 in
		-y | --yes) YES=1 ;;
		-u | --user) TUSER=${2:-}; shift ;;
		-h | --help) usage 0 ;;
		*) echo "unknown option: $1" >&2; usage 1 >&2 ;;
		esac
		shift
	done

	resolve_user
	[[ -t 0 ]] || ((YES)) || { echo "error: no terminal for the questions, use -y" >&2; exit 1; }

	exec 9>"$LOCK"
	flock -n 9 || { echo "error: postinstall.sh is already running" >&2; exit 1; }

	install -d -o root -g root -m 0700 -- "$BAK"
	install -o root -g root -m 0600 /dev/null "$LOG"
	: >"$BAK/journal"
	local k
	for k in "${SECTIONS[@]}"; do DO[$k]=0; done

	trap on_signal INT TERM HUP
	trap 'on_err $LINENO' ERR

	check_repo
	plan

	do_repos
	((DO[update])) && do_update
	do_packages
	((DO[hw])) && do_hw
	((DO[locale])) && do_locale
	((DO[harden])) && do_harden
	((DO[net])) && do_net_files
	do_groups
	((DO[swap])) && do_swap
	((DO[dirs])) && do_dirs
	((DO[cli])) && do_home_cli
	((DO[desktop])) && do_g0wm
	((DO[media])) && do_media
	((DO[apps])) && do_apps
	((DO[session])) && do_session
	((DO[fonts])) && do_fonts
	((DO[theme])) && do_theme
	((DO[boot])) && do_boot
	do_services
	do_post
	((DO[doas])) && do_doas
	((DO[net])) && do_net_services
	verify

	trap - ERR INT TERM HUP
	rm -rf -- "$BAK/boot"
	printf '\n%sdone.%s reboot now.\n' "$C_G" "$C_0"
	printf '  log:        %s\n  backups:    %s\n' "$LOG" "$BAK"
	[[ ! -d $UBAK ]] || printf '  your files: %s\n' "$UBAK"
	((DO[desktop] == 0)) || printf '  desktop:    log in on tty1, g0wm starts by itself\n'
	log "done"
}

preflight "$@"
main "$@"
