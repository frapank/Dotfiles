# shellcheck shell=bash
# swap, logs, maintenance, snapshots

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

do_logs() {
	step "System logs"
	local d=/var/log/socklog
	[[ -d $d/everything && -d $d/kernel && -d $d/secure ]] || die "socklog-void did not create $d"
	sv_refresh socklog-unix/log put_tree logs
	fix_perm "$d/secure" 2700
	run "logs parses" sh -n /usr/local/bin/logs
	run "pstore script parses" sh -n /etc/runit/core-services/07-pstore.sh
	if [[ -d /sys/firmware/efi ]]; then
		grub_words efi_pstore.pstore_disable=0
	else
		warn "booted without UEFI: no pstore, a kernel panic leaves no log"
	fi
}

do_maint() {
	step "Maintenance"
	local conf=etc/dracut.conf.d/40-snapshots.conf
	cmp -s -- "$REPO/root/maint/$conf" "/$conf" || REGEN=1
	sv_refresh maint put_tree maint
	run "maint parses" sh -n /usr/local/sbin/maint
	run "thumbs-clean parses" python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' /usr/local/libexec/thumbs-clean
	run "trash-clean parses" python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' /usr/local/libexec/trash-clean
	run "snap parses" python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' /usr/local/bin/snap
	grub_snaps
}

do_nosnap() {
	step "Folders kept out of the snapshots"
	local dl
	dl=$(as_user xdg-user-dir DOWNLOAD 2>/dev/null) || dl=
	if [[ $dl == "$THOME"/?* ]]; then
		nosnap "$dl"
	else
		warn "no download folder in user-dirs.dirs, it stays in the snapshots"
	fi
	nosnap "$THOME/Private"
	nosnap "$THOME/.cache"
	nosnap "$THOME/.config/librewolf" librewolf
}

nosnap() {
	local d=$1 new=$1.pi-subvol prev=$1.pi-old mode=0700 t=${1/#$THOME/\~}
	if [[ -d $d && ! -L $d && $(stat -c %i -- "$d") == 256 ]]; then
		skip "$t is a subvolume, not in the snapshots"
		return 0
	fi
	[[ ! -L $d ]] || die "$d is a symlink, refusing"
	[[ ! -e $d || -d $d ]] || die "$d exists and is not a directory"
	if [[ -n ${2:-} ]] && pgrep -u "$TUSER" -x "$2" >/dev/null; then
		warn "$2 is running, close it and run this again to keep $t out of the snapshots"
		return 0
	fi
	if [[ $REPO/ == "$d"/* ]]; then
		warn "$t holds this repo, left in the snapshots"
		return 0
	fi
	umkdir "${d%/*}"
	[[ $(stat -f -c %T -- "${d%/*}") == btrfs ]] || { warn "$t is not on btrfs, left alone"; return 0; }
	if [[ -d $d && $(findmnt -no TARGET -T "$d") == "$d" ]]; then
		warn "$t is a mount point, left alone"
		return 0
	fi
	[[ ! -e $new && ! -e $prev ]] || die "$new or $prev exists, move it away"
	[[ -d $d ]] && mode=$(stat -c %a -- "$d")
	jot subvol-rm "$new"
	run "create the subvolume for $t" btrfs subvolume create -- "$new"
	chown -- "$TUSER:$TGID" "$new"
	chmod -- "$mode" "$new"
	if [[ -d $d ]]; then
		run "copy $t into it (reflinks, no extra space)" cp -a --reflink=always -- "$d/." "$new/"
		jot subvol-swap "$d" "$prev"
		mv -T -- "$d" "$prev"
		mv -T -- "$new" "$d"
		jot unsubvol "$d"
		rm -rf -- "$prev"
	else
		mv -T -- "$new" "$d"
		jot subvol-rm "$d"
	fi
	ok "$t is a subvolume, kept out of the snapshots"
}
