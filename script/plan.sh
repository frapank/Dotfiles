# shellcheck shell=bash
# plan

section() {
	local i n=0
	for i in "${!SECTIONS[@]}"; do [[ ${SECTIONS[i]} == "$1" ]] && n=$((i + 1)); done
	head_line "$2" "$n/${#SECTIONS[@]}"
	wrap $((COLS - 4)) | sed 's/^/   /'
	if ask "   apply?"; then SEL[$1]=1; else SEL[$1]=0; fi
}

plan() {
	say "${C_B}Void post-install${C_0}"
	say "   user  $TUSER ($THOME)"
	say "   repo  $REPO"
	say "   ${C_D}Nothing changes until you confirm the plan at the end.${C_0}"

	section update "System upgrade" <<-EOF
		Upgrades the whole system (xbps-install -Su). Recommended.
	EOF
	section locale "English everywhere" <<-EOF
		LANG=en_US.UTF-8 and LC_COLLATE=C in /etc/locale.conf, generates the locale.
	EOF
	section cli "Shell and editors" <<-EOF
		Installs ${PKG_CLI[*]}
		Copies home/{$(join , "${HOME_CLI[@]}")}, login shell bash.
		Files in the way, ~/.vimrc and ~/.tmux.conf go to ~/_backup/$TS.
	EOF
	section lsp "Language servers for nvim" <<-EOF
		Installs ${PKG_LSP[*]}
	EOF
	section harden "Kernel and firewall hardening" <<-EOF
		sysctl: /etc/sysctl.d/{10,20,30,40}-*.conf, TCP timestamps off.
		Firewall (nftables): drops input and forward, allows output. ICMP only errors, rate limited ping, neighbor discovery, router adverts, MLD.
		SSH client: offers only configured keys, hashed known_hosts, no agent forwarding. ~/.ssh gets mode 0700, no keys are generated.
		Blocks rarely used kernel modules with a history of bugs: rds tipc atm n_hdlc n_gsm sctp appletalk psnap llc2 phonet ax25 netrom rose x25 can ieee802154 firewire floppy cramfs hfs befs qnx6 adfs ufs hpfs jfs gfs2 ocfs2 vivid. hfsplus udf exfat ntfs3 still work.
		Kernel command line, active after reboot: freed memory is zeroed (a few % slower), no DMA attacks over PCI and Thunderbolt, only signed modules, no /dev/mem, kexec or hibernation. The recovery entry boots without them.
		  ${HARDEN_CMDLINE[*]}
		New machine ID at every boot, so apps cannot track this machine by it.
		fstab: /boot root only, /tmp a nosuid,nodev tmpfs unless a partition.
	EOF
	section apparmor "AppArmor: confine the apps that parse untrusted input" <<-EOF
		Apps keep working, but an exploit cannot read secrets (~/.ssh ~/.gnupg keyrings history), write files that run code later (shell startup, autostart, PATH, configs, git hooks, this repo) or use setuid programs.
		  librewolf: keeps network, camera, mic and screen sharing.
		  papers libreoffice xarchiver: offline, no mic or camera.
		  showtime offline. tumblerd offline, writes only to ~/.cache.
		  foot: no network, no secrets. The shell inside is not confined.
		  dnscrypt-proxy chronyd bluetoothd NetworkManager pipewire wireplumber fwupd: only what they use.
		  wpa_supplicant reads certificates, so eduroam works.
		  Loupe is left to glycin, which already sandboxes image decoding.
		Sandbox: these apps start in bwrap via dbus-filter, with a filtered session bus (portals, dconf, gvfs, notifications, media keys), no X11, no user namespaces and no network (librewolf keeps both).
		  With wp_security_context_v1 in g0wm they also cannot read the clipboard or screen or inject input. Copy and paste still work.
		hardened_malloc (GrapheneOS) in papers tumblerd showtime xarchiver: heap bugs in file parsers crash instead of being exploitable.
		Removes about 150 unused Void profiles, also on updates.
		Kernel command line, active after reboot: $(aa_lsm)
		Blocks go to the kernel log, local changes in /etc/apparmor.d/local/.
	EOF
	section net "Network, DNS and time" <<-EOF
		Installs ${PKG_NET[*]}
		NetworkManager: random MAC on wifi and ethernet, no hostname over DHCP, IPv6 temporary addresses, no DHCP identifier fixed across networks.
		DNS: dnscrypt-proxy on 127.0.0.1, DNSSEC, no-log servers, always via an Anonymized DNS relay: no server sees both your IP and your queries.
		  Bootstrap through Quad9. HaGeZi Multi PRO blocklist, updated daily with maint.
		  With harden, any other DNS (ports 53 and 853) is blocked. Captive portal: 'doas nft delete table inet dns' until the next boot.
		Time: chrony with NTS. Replaces dhcpcd, wpa_supplicant and ntpd.
		Runs near the end, the network may drop for a moment.
	EOF
	section boot "Boot: initramfs, splash, login screen" <<-EOF
		Installs ${PKG_BOOT[*]}
		dracut hostonly, plymouth void-minimal, 'quiet splash' in GRUB.
		GRUB theme minimal (tomdewildt, fixed commit): only GRUB_THEME changes in /etc/default/grub, LUKS and kernel arguments are kept and checked in grub.cfg.
		No 'Loading Linux ...' lines after the menu (10_linux patched, redone by maint after grub updates).
		Clean tty1 login and /etc/issue. Terminus font on every tty, larger on screens 1440 pixels tall or more.
		Rebuilds the initramfs when needed, old images restored on failure.
	EOF
	detect_hw
	section hw "Hardware: microcode, GPU drivers, firmware updates" <<-EOF
		Found: $(join , "${HW_DESC[@]}")
		Installs $(printf '%s\n' "${HW_PKGS[@]}" | sort -u | tr '\n' ' ')fwupd
		$( ((NONFREE)) && echo "Adds the Void nonfree repo for intel-ucode." )
		Microcode goes into the initramfs. Firmware: 'fwupdmgr get-updates'.
	EOF
	section power "Power profiles (as in GNOME)" <<-EOF
		power-profiles-daemon on balanced, replaces tlp.
		Change it with 'powerprofilesctl set performance'.
	EOF
	section logs "System logs, crash reports, the logs command" <<-EOF
		socklog in /var/log/socklog, one folder per kind, more history but capped (60 MB everything and kernel, 20 MB the rest).
		Login and doas messages readable by root only. Adds $TUSER to socklog.
		logs             live           logs errors    since boot
		logs boot        this boot      logs crashes   segfaults, OOM
		logs since 2h    or today, 3d   logs apparmor  blocks per app
		logs service X   one service    logs firewall  drops per source
		logs grep RE     search all     logs auth      logins, doas
		logs status      disk, history  logs panics    kernel crashes
		Kernel panics are kept by UEFI pstore and saved at the next boot.
		Notifications for crashes, disk and filesystem errors, overheating, USB events, looping services, battery at 20% and 10%, disks over 90%, mic and webcam in use, AppArmor blocks, a kernel crash last boot.
		No core dumps from setuid programs.
	EOF
	zram_size
	section swap "Swap in compressed RAM" <<-EOF
		zramen: ${ZRAM_PCT}% of $(($(awk '/^MemTotal:/ { print $2 }' /proc/meminfo) / 1024)) MiB RAM = ${ZRAM_MIB} MiB of zstd zram (max 16 GiB).
		swappiness 180, page-cluster 0.
	EOF
	section maint "Maintenance: snapshots, updates, cleanup" <<-EOF
		A service runs these hourly, catches up on missed ones and notifies failures. Needs / and /home on btrfs.
		Daily: read-only snapshot of /home, last 14 kept (3 under 10% free). Same disk, not a backup.
		  Downloads, ~/Private, ~/.cache and the librewolf profile are left out: what you delete there is gone.
		Daily: system update while you are logged in, with battery over 20% and 10% free on /.
		  Downloads first, snapshots / (last 3 kept), then installs. Sleep and shutdown wait for it. Notifies every stage.
		  The snapshots of / are in the GRUB menu (grub-btrfs, 'Snapshots before updates'), the daily ones of /home are not.
		  A snapshot boots with a throwaway overlay in RAM (dracut overlayfs): changes are lost, /home is the live one.
		  Pick its kernel in the menu: /boot is not in the snapshot, the kernels it was taken with are kept while it exists.
		Daily: deletes thumbnails of deleted files and what has been in the trash for 30 days, updates the DNS blocklist.
		Weekly: old kernels (never the running one or one of a snapshot of /), orphans, package cache. Packages installed here are never orphans.
		Weekly: checks for firmware updates (fwupd) and notifies, installing is 'doas fwupdmgr update'.
		Monthly: btrfs scrub, on AC power only.
		'snap FILE' lists the versions of a file in the snapshots of /home, 'snap -r DATE FILE' copies one back.
		'forget FILE' deletes a file from all the snapshots of /home, 'traces -cs' does it for histories and recent files.
		'doas maint status', 'doas maint home|update', 'svlogtail cron'.
	EOF
	section dirs "Home folders" <<-EOF
		Custom user-dirs from home/{$(join , "${HOME_DIRS[@]}")}, creates those folders.
		Empty unused standard folders go to ~/_backup/$TS, others stay.
	EOF
	section desktop "Desktop: g0wm" <<-EOF
		Session: dbus elogind polkit pipewire xwayland (elogind replaces acpid).
		Apps: foot Thunar grim slurp swappy swayidle gtklock brightnessctl playerctl.
		Adds $TUSER to ${USER_GROUPS[*]}. Copies home/{$(join , "${HOME_DESKTOP[@]}")} with the default wallpaper.
		Builds, tests and installs g0wm into ~/.local/bin, again only on new commits. A g0wm built elsewhere is left alone.
		Log in on tty1 and g0wm starts.
		'services': runit keeps the polkit agent, Thunar, the idle lock and the nightlight running while g0wm runs.
	EOF
	section media "Screen sharing and audio" <<-EOF
		PipeWire with wireplumber and pipewire-pulse, ALSA through PipeWire.
		Screen sharing via the wlr portal, pick the output with slurp.
	EOF
	section apps "Apps, Thunar, default apps, shortcuts" <<-EOF
		librewolf (own repo, signing key pinned), Loupe, Showtime, Papers, LibreOffice, Thunar, xarchiver, pavucontrol and CLI tools. unrar comes from the Void nonfree repo.
		~/.local/bin: photo video pdf office browser files audio wifi bluetooth screenshot record nightlight awake extract compress open metadata-remover privacy-check traces conns isolate dotfiles.
		Thunar: 'Open Terminal Here', automount, Remove and Show Metadata (camera, GPS, author data; runs offline in a sandbox), Restore a Previous Version and Delete from the Snapshots.
		Print: region, Shift: screen, Ctrl: edit in swappy. Saved to Pictures and the clipboard.
		Super+Print: record, Shift: region, Ctrl: no audio.
		Super+= nightlight. Super+- always on: no lock or blank until off.
		Default apps: images Loupe, video Showtime, PDF Papers, web librewolf, folders Thunar, archives xarchiver, documents LibreOffice, text nvim.
	EOF
	section session "Keyring, polkit, network and bluetooth" <<-EOF
		The keyring unlocks with your login password. Polkit agent in g0wm.
		No tray icons: 'wifi' and 'bluetooth' open their managers.
		Bluetooth is off at every boot: 'bluetooth on' or 'bluetooth off'.
	EOF
	section theme "Theme: Adwaita dark" <<-EOF
		GTK 2, 3, 4 and Qt 5, 6 in Adwaita dark, Geist 10 as UI font, Geist Mono 10 for code.
		Bibata-Modern-Classic cursor (sha256 checked) in the palette, size $CURSOR_SIZE.
		AdwaitaLegacy $ICONS_TAG for full color icons in pavucontrol and Thunar.
	EOF
	section fonts "Fonts: Geist and Geist Mono" <<-EOF
		Geist for text, Geist Mono for terminal, code and g0wm, from the v1.7.2 release (sha256 checked). Nerd symbols, emoji and CJK as fallback.
		Removes SF Mono and SF Pro from /usr/local/share/fonts.
		Removes the full Nerd Fonts (about 8 GB).
	EOF
	section doas "doas instead of sudo" <<-EOF
		'permit persist :wheel', adds $TUSER to wheel, removes and blocks sudo.
		Needs a password for $TUSER. Runs last, a rollback always leaves you with doas or sudo.
	EOF

	if ((SEL[maint])); then
		[[ $(stat -f -c %T /) == btrfs ]] || die "maint: / is not btrfs"
		[[ $(stat -f -c %T /home) == btrfs && $(stat -c %i /home) == 256 ]] ||
			die "maint: /home is not a btrfs subvolume, it cannot be snapshotted"
		compgen -G '/usr/lib/dracut/modules.d/[0-9]*overlayfs/module-setup.sh' >/dev/null ||
			die "maint: dracut has no overlayfs module, snapshots of / could not boot"
	fi
	if ((SEL[doas])); then
		local st
		st=$(passwd -S -- "$TUSER" | awk '{print $2}')
		[[ $st == P ]] || die "$TUSER has no usable password (passwd -S: $st), run 'passwd $TUSER' first"
	fi
	((SEL[harden] == 0)) || sig_check
	((SEL[apparmor] == 0)) || aa_check

	local k on=() off=()
	for k in "${SECTIONS[@]}"; do
		if ((SEL[$k])); then on+=("$k"); else off+=("$k"); fi
	done
	((${#on[@]})) || { say "nothing selected."; exit 0; }

	local need=6 avail
	((SEL[fonts])) && need=$((need + 1))
	((SEL[apps])) && need=$((need + 2))
	avail=$(df --output=avail -BG / | tail -n1 | tr -dc 0-9)
	((avail >= need)) || die "about ${need} GB needed on /, only ${avail} GB free"

	head_line "Plan" "${#on[@]} of ${#SECTIONS[@]}"
	printf 'apply  %s\n' "${on[*]}" | fold -s -w $((COLS - 11)) | sed '1!s/^/       /; s/^/   /'
	((${#off[@]} == 0)) || printf 'skip   %s\n' "${off[*]}" | fold -s -w $((COLS - 11)) | sed '1!s/^/       /; s/^/   /'
	if [[ -n ${SSH_CONNECTION:-} ]] && ((SEL[net])); then
		warn "you are on SSH: the network step at the end may drop this connection"
	fi
	printf '\n'
	ask "Proceed?" || { say "nothing changed."; exit 0; }
}
