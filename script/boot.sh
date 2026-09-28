# shellcheck shell=bash
# boot, grub, initramfs, hardware

grub_words() {
	local line w add=() stale=0
	if [[ ! -f /etc/default/grub ]]; then
		warn "no /etc/default/grub: add '$*' to the kernel command line yourself"
		return 0
	fi
	if grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub | grep -qv '^GRUB_CMDLINE_LINUX_DEFAULT="[^"]*"[[:space:]]*$'; then
		die "GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub is not a plain \"...\" value, add '$*' to it yourself"
	fi
	line=$(grep -E '^GRUB_CMDLINE_LINUX(_DEFAULT)?=' /etc/default/grub || true)
	for w in "$@"; do
		[[ " $line " =~ [\"\'[:space:]]"$w"[\"\'[:space:]] ]] || add+=("$w")
		grep -qsF -- "$w" /boot/grub/grub.cfg || stale=1
	done
	if ((${#add[@]})); then
		backup /etc/default/grub
		if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT="' /etc/default/grub; then
			sed -i -E "s/^(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*)\"/\1 ${add[*]}\"/" /etc/default/grub
		else
			echo "GRUB_CMDLINE_LINUX_DEFAULT=\"${add[*]}\"" >>/etc/default/grub
		fi
		grep '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub | grep -qF -- "${add[-1]}\"" || die "could not edit GRUB_CMDLINE_LINUX_DEFAULT"
		ok "GRUB: added ${add[*]}"
		stale=1
	else
		skip "GRUB has $*"
	fi
	if ((stale)); then
		[[ -f /boot/grub/grub.cfg ]] && backup /boot/grub/grub.cfg
		run "update-grub" update-grub
		grub_check
	fi
}

grub_check() {
	local need root a l n=0 bad=0
	need=$(tr ' ' '\n' </proc/cmdline | grep -E '^(root|rootflags|rootfstype|rd\.luks\.[a-z.]+|rd\.lvm\.[a-z.]+|rd\.md\.[a-z.]+|cryptdevice|cryptkey|resume|resume_offset)=' | sort -u || true)
	root=$(grep -m1 '^root=' <<<"$need" || true)
	[[ -n $root ]] || { warn "no root= on /proc/cmdline, grub.cfg not checked"; return 0; }
	while IFS= read -r l; do
		n=$((n + 1))
		for a in $need; do
			[[ " $l " == *" $a "* ]] || { warn "grub.cfg lacks $a in: $l"; bad=1; }
		done
	done < <(awk -v r="$root" '$1 == "linux" { $1 = ""; if (index($0 " ", " " r " ")) print }' /boot/grub/grub.cfg)
	((n > 0)) || die "grub.cfg has no entry with $root, the system booted with"
	((bad == 0)) || die "grub.cfg lost boot arguments the system booted with"
	ok "grub.cfg: $n entries keep $(tr '\n' ' ' <<<"$need")"
}

do_boot() {
	step "Boot"
	local n p
	n=$(njot)
	put_tree dracut
	put_tree plymouth
	((n == $(njot))) || REGEN=1
	for p in "${PKG_BOOT[@]}"; do
		[[ " ${NEW_PKGS[*]} " == *" $p "* ]] && REGEN=1
	done
	initramfs_stale && REGEN=1
	put_tree agetty
	run "agetty run script parses" sh -n /etc/sv/agetty-generic/run
	put_tree console
	run "console font script parses" sh -n /etc/runit/core-services/04-console-font.sh
	[[ -f /usr/share/kbd/consolefonts/ter-v16n.psf.gz && -f /usr/share/kbd/consolefonts/ter-v32n.psf.gz ]] ||
		die "terminus-font did not install ter-v16n and ter-v32n"
	[[ -f /usr/lib/plymouth/two-step.so ]] || die "plymouth two-step module missing"
	[[ $(plymouth-set-default-theme) == void-minimal ]] || die "plymouth does not pick void-minimal"
	ok "plymouth theme void-minimal"

	grub_words quiet splash

	if ((REGEN)); then
		regen_initramfs
	else
		skip "initramfs up to date"
	fi
}

initramfs_stale() {
	local k img
	for k in /usr/lib/modules/*/modules.dep; do
		[[ -e $k ]] || continue
		k=${k%/modules.dep}
		compgen -G "/boot/vmlinu[xz]-${k##*/}" >/dev/null || continue
		img=/boot/initramfs-${k##*/}.img
		[[ -s $img ]] || return 0
		if command -v lsinitrd >/dev/null; then
			lsinitrd "$img" 2>/dev/null | grep plymouth >/dev/null || return 0
		fi
	done
	return 1
}

regen_initramfs() {
	((REGEN < 2)) || return 0
	local kvers=() k
	for k in /usr/lib/modules/*/modules.dep; do
		[[ -e $k ]] || continue
		k=${k%/modules.dep}
		compgen -G "/boot/vmlinu[xz]-${k##*/}" >/dev/null || continue
		kvers+=("${k##*/}")
	done
	((${#kvers[@]})) || die "no kernel in /usr/lib/modules with a /boot/vmlinuz"
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
