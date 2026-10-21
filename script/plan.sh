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
    say "${C_B}Debian post-install${C_0}"
    say "   user  $TUSER ($THOME)"
    say "   repo  $REPO"
    say "   apt   ${SOURCES##*/}: $COMPONENTS; packages without their Recommends"
    say "   ${C_D}Nothing changes until you confirm the plan at the end.${C_0}"

    section update "System upgrade" <<-EOF
		Upgrades the whole system (apt-get full-upgrade). Recommended.
		On btrfs it first takes a read-only snapshot of / in /.snapshots, like maint does, so a bad upgrade can be booted away from GRUB.
	EOF
    section locale "English everywhere" <<-EOF
		LANG=en_US.UTF-8 and LC_COLLATE=C in /etc/default/locale, generates the locale.
	EOF
    section cli "Shell and editors" <<-EOF
		Installs ${PKG_CLI[*]}
		fd and bat in /usr/local/bin: Debian names them fdfind and batcat.
		Copies home/{$(join , "${HOME_CLI[@]}")}, login shell bash.
		~/.bashrc and ~/.bash_profile get one line on top that sources ~/.bashrc_dotfile and ~/.bash_profile_dotfile, what programs add under it stays.
		Files in the way, ~/.vimrc and ~/.tmux.conf go to ~/_backup/$TS.
		No phoning home: DO_NOT_TRACK, Go downloads straight from the source instead of Google's proxy and never fetches a toolchain, no pip and npm update checks, no npm audit. wget and curl send no version and wget keeps no list of sites (HSTS) and no download URL on files.
	EOF
    section lsp "Language servers for nvim" <<-EOF
		Installs ${PKG_LSP[*]}
		taplo, zls, bash-language-server and yaml-language-server are not in Debian: nvim uses them once they are in PATH.
	EOF
    section harden "Kernel and firewall hardening" <<-EOF
		sysctl: /etc/sysctl.d/5{1..5}-*.conf, after the 50-default.conf of Debian that would undo some, TCP timestamps off.
		Firewall (nftables): drops input and forward, allows output. ICMP only errors, rate limited ping from the LAN only (the internet cannot see the machine is up, IPv6 included), neighbor discovery, router adverts, MLD. Nothing goes out that announces the machine on the LAN (mDNS, LLMNR, SSDP, NetBIOS, WS-Discovery, Steam).
		SSH client: offers only configured keys, hashed known_hosts, no agent forwarding, keys stay in the agent for an hour. ~/.ssh gets mode 0700, no keys are generated.
		Blocks rarely used kernel modules with a history of bugs: rds tipc atm n_hdlc n_gsm sctp appletalk psnap llc2 phonet ax25 netrom rose x25 can ieee802154 firewire floppy cramfs hfs befs qnx6 adfs ufs hpfs jfs gfs2 ocfs2 vivid kcm rxrpc nfc nilfs2 zonefs cuse userio hci_vhci. hfsplus udf exfat ntfs3 still work.
		Kernel command line, active after reboot: freed memory is zeroed (a few % slower), no DMA attacks over PCI and Thunderbolt, only signed modules, no /dev/mem, kexec or hibernation, no reading of kernel memory through /proc/kcore, tracing or BPF (lockdown confidentiality), no writing into a program's memory through /proc but by a debugger. The recovery entry boots without them.
		  ${HARDEN_CMDLINE[*]}
		New machine ID at every boot, so apps cannot track this machine by it: /etc/machine-id is empty on disk, systemd puts a random one over it in RAM and never saves it. The journals of the old IDs are kept up to 400 MB.
		fstab: /boot and /boot/efi nosuid,nodev,noexec and readable by root only, /tmp a nosuid,nodev tmpfs unless a partition, /home nosuid,nodev.
		Core dumps: a dump is the memory of the program, keys and passwords included. Only the one of g0wm is kept (~/.local/state/g0wm, for debugging it), the others are dropped (core-keep).
		/proc, after reboot (fstab): the daemons' users see only their own processes. Group proc sees all: polkitd, rtkit, systemd-logind, $TUSER (the polkit agent needs it).
		No setuid on su pkexec passwd chsh chfn chage expiry gpasswd newgrp sg mount umount newuidmap newgidmap fusermount (the old one, fusermount3 stays for the FUSE mounts of the desktop) ssh-keysign wall write Xorg.wrap firejail lxc-user-nic qemu-bridge-helper spice-client-glib-usb-acl-helper: doas does it ('doas passwd $TUSER').
		No file capabilities on cdrecord readcd cdda2wav (dac_override and sys_admin on programs anyone can run).
		  dpkg-statoverride keeps the modes across updates; apt runs nosuid after each run, for what a new package brings.
	EOF
    section usb "USB devices: usbguard" <<-EOF
		The devices plugged in now are allowed. Later a new one stays blocked, and a notification asks: Allow or Block, what the device says it is and a warning when a storage or network device can also type.
		With the screen locked it waits for the unlock, then asks. Hubs are allowed by themselves, what is plugged into them is asked about.
		Allowed devices are remembered in any port and after reboots, blocked ones are asked about again.
		'usb' lists the devices, 'usb allow|block PORT', 'usb rules', 'usb forget N'.
		Without a keyboard and a mouse here now it asks before going on, also with -y.
	EOF
    section apparmor "AppArmor: confine the apps that parse untrusted input" <<-EOF
		Apps keep working, but an exploit cannot read the hidden files of the home but the few GTK and the fonts need (~/.ssh ~/.gnupg keyrings histories and the data and logins of every other app, also of those installed later), reach what runs commands outside (nvim, tmux, the session services), write files that run code later (shell startup, autostart, PATH, configs, git hooks, this repo) or use setuid programs.
		  librewolf: keeps network, camera, mic and screen sharing, but not ~/Private (to upload a file from there, copy it to ~/Get).
		  papers libreoffice xarchiver: offline, no mic or camera.
		  showtime offline. tumblerd offline, writes only to ~/.cache and its temporary files.
		  foot: no network, no secrets. The shell inside is not confined, so neither is a program an exploit in foot starts.
		  dnscrypt-proxy chronyd bluetoothd NetworkManager pipewire wireplumber fwupd: only what they use.
		  wpa_supplicant: the profile of Void, Debian has none; it reads certificates, so eduroam works.
		  steam lutris, if you install them: all but secrets, the browser's data, shell startup and setuid programs.
		  Loupe is left to glycin, which already sandboxes image decoding. It starts without gvfs (GIO_USE_VFS=local), also over D-Bus: the sandboxed apps can ask it to open a URI, gvfs would fetch an http one for them.
		Sandbox: these apps start in bwrap via dbus-filter, with a filtered session bus (portals, dconf, notifications, media keys; their dconf writes go to ~/.config/dconf/sandbox, the programs outside never see them), no X11, no user namespaces, no other process in sight and no network (librewolf keeps the network and its namespaces).
		  landlock-scope closes in the kernel what bwrap cannot: abstract unix sockets (Xwayland listens on one, and librewolf has the host network) and signals to processes outside; with Landlock ABI 9 (kernel 7, trixie-backports) also every pathname unix socket but the few the app uses, Debian's 6.12 stops at ABI 6. AppArmor does not do this here: the 6.12 kernel does not mediate unix sockets, the newer ones offer network_v9/af_unix that AppArmor 4.1 does not compile.
		  The apps get a Wayland socket of their own (wp_security_context_v1 in g0wm): no screen, no input injection, no clipboard managers. Without that socket they have no display at all, never the real compositor.
		  The clipboard is not restricted: as on any Wayland desktop, the focused app is told what was copied last.
		hardened_malloc (GrapheneOS) in papers tumblerd showtime xarchiver: heap bugs in file parsers crash instead of being exploitable.
		Debian's own profiles stay. Disabled (/etc/apparmor.d/disable) where one here confines the same program: the Ubuntu ones of papers and LibreOffice (they let it write all of the home), the unconfined steam and the unconfined librewolf of its package. Debian's chrony profile gets the certificates for NTS and the root secrets in local/.
		Kernel command line, active after reboot: $(aa_lsm)
		Blocks go to the kernel log, local changes in /etc/apparmor.d/local/.
	EOF
    section net "Network, DNS and time" <<-EOF
		Installs ${PKG_NET[*]}
		NetworkManager: random MAC on wifi and ethernet, no hostname over DHCP, IPv6 temporary addresses, no DHCP identifier fixed across networks.
		  Wi-Fi turns off while a cable is connected and back on when it goes: an idle card keeps scanning, and its scans can be recognized even with a random MAC.
		DNS: dnscrypt-proxy on 127.0.2.1 (the socket of Debian's unit, it runs as _dnscrypt-proxy), DNSSEC, no-log servers, always via an Anonymized DNS relay: no server sees both your IP and your queries.
		  Bootstrap through Quad9. HaGeZi Multi PRO blocklist, updated daily with maint.
		  With harden, any other DNS (ports 53 and 853) is blocked. Captive portal: 'doas nft delete table inet dns' until the next boot.
		Time: chrony with NTS, no UDP command port, its seccomp filter (-F 1 in Debian). Replaces systemd-timesyncd.
		NetworkManager takes over the interfaces the Debian installer set in /etc/network/interfaces: their lines are commented out, the Wi-Fi network goes into NetworkManager.
		No connectivity check: NetworkManager never calls a fixed URL that tells which system this is.
		Runs near the end, the network may drop for a moment.
	EOF
    section boot "Boot: initramfs, splash, login screen" <<-EOF
		Installs ${PKG_BOOT[*]}
		initramfs-tools with MODULES=dep, plymouth g0wm, 'quiet splash' in GRUB.
		Kernel arguments go in /etc/default/grub.d, /etc/default/grub stays as it is. / on LUKS: checked that cryptsetup-initramfs and /etc/crypttab unlock it, an initramfs without it is not kept.
		GRUB theme minimal (tomdewildt, fixed commit): GRUB_THEME in /etc/default/grub.d, the arguments the system booted with (root, subvolume, resume) are checked in grub.cfg.
		No 'Loading Linux ...' lines after the menu (10_linux patched; dpkg keeps it and leaves the new one of a grub update as 10_linux.dpkg-dist, maint patches that and puts it in place).
		Clean tty1 login and /etc/issue. Terminus font on every tty (console-setup), larger on screens 1440 pixels tall or more.
		Rebuilds the initramfs when needed, old images restored on failure.
	EOF
    detect_hw
    section hw "Hardware: microcode, GPU drivers, firmware updates" <<-EOF
		Found: $(join , "${HW_DESC[@]}")
		Installs $(printf '%s\n' "${HW_PKGS[@]}" | sort -u | tr '\n' ' ')fwupd
		Microcode goes into the initramfs. Firmware: 'fwupdmgr get-updates'.
		The airplane mode key does nothing (udev rule).
	EOF
    section power "Power profiles (as in GNOME)" <<-EOF
		power-profiles-daemon on balanced, replaces tlp.
		Change it with 'powerprofilesctl set performance'.
	EOF
    section logs "System logs, crash reports, the logs command" <<-EOF
		The journal on disk, capped at 200 MB, every boot also with another machine ID: logs reads them all. Nothing goes on to a syslog daemon, emergencies are not written on the terminals (ForwardToWall).
		Adds $TUSER to systemd-journal: the journal, login and doas messages included, reads without doas.
		logs             live           logs errors    since boot
		logs boot        this boot      logs crashes   segfaults, OOM
		logs since 2h    or today, 3d   logs apparmor  blocks per app
		logs service X   one service    logs firewall  drops per source
		logs grep RE     search all     logs auth      logins, doas
		logs status      disk, history  logs panics    kernel crashes
		Kernel panics are kept by UEFI pstore and saved at the next boot (systemd-pstore). After a panic or an oops it reboots in 10 seconds.
		Notifications for crashes, kernel bugs and lockups, GPU hangs, CPU and RAM errors, disks not answering, filesystem errors, overheating, USB events, failed services, battery at 20% and 10%, disks over 90%, mic and webcam in use, AppArmor blocks, a kernel crash last boot.
		No core dumps from setuid programs.
	EOF
    zram_size
    section swap "Swap in compressed RAM, earlyoom" <<-EOF
		zram-generator: ${ZRAM_PCT}% of $(($(awk '/^MemTotal:/ { print $2 }' /proc/meminfo) / 1024)) MiB RAM = ${ZRAM_MIB} MiB of zstd zram (max 16 GiB).
		swappiness 180, page-cluster 0.
		earlyoom closes the program using the most memory under 10% free RAM and 10% free swap, before the desktop freezes. Browser tabs, Steam web views and Windows games go first; g0wm, foot, PipeWire and the network last; gtklock and systemd never. The watchdog notifies it.
	EOF
    section maint "Maintenance: snapshots, updates, cleanup" <<-EOF
		A service runs these hourly, catches up on missed ones and notifies failures. Needs / and /home on btrfs.
		  The Debian installer leaves /home in the subvolume of /: it becomes a subvolume of its own (reflinks, no extra space), out of the snapshots of /.
		Daily: read-only snapshot of /home, last 14 kept (3 under 10% free). Same disk, not a backup.
		  Downloads, ~/Private, ~/.cache, ~/Games, ~/.local/share/Steam and the librewolf profile are left out: what you delete there is gone.
		Daily: system update while you are logged in, with battery over 20% and 10% free on /. Flatpak apps too, if there are any.
		  Downloads first, snapshots / (last 3 kept), then installs. Sleep and shutdown wait for it. Notifies every stage.
		  Waits for a good connection: postponed when requests to the mirror fail or hang, under 100 KB/s, or when the download would take over 30 minutes. A notification after 3 days, 'doas maint update' updates anyway.
		  The snapshots of / are in the GRUB menu (grub-btrfs from its repository at a fixed commit, Debian has no package; 'Snapshots before updates'), the daily ones of /home are not.
		  A snapshot boots with a throwaway overlay in RAM (overlayroot): changes are lost, /home is the live one.
		  Pick its kernel in the menu: /boot is not in the snapshot, the kernels it was taken with are kept while it exists.
		Daily: deletes thumbnails of deleted files and what has been in the trash for 30 days, updates the DNS blocklist.
		Weekly: old kernels (never the running one or one of a snapshot of /), orphans, package cache. Packages installed here are never orphans.
		Weekly: checks for firmware updates (fwupd) and notifies, installing is 'doas fwupdmgr update'.
		  fwupd never sends reports on failed or successful updates (the report address is emptied).
		Weekly: disk health with smartmontools (SMART, NVMe wear and media errors), notifies what got worse since last week. Errors as they happen come from the logs notifications.
		Monthly: btrfs scrub, on AC power only.
		'snap FILE' lists the versions of a file in the snapshots of /home, 'snap -r DATE FILE' copies one back, 'snap -d DATE' lists what changed in your home since then.
		'forget FILE' deletes a file from all the snapshots of /home, 'traces -cs' does it for histories and recent files.
		'doas maint status', 'doas maint home|update', 'logs service maint'.
	EOF
    section dirs "Home folders" <<-EOF
		Custom user-dirs from home/{$(join , "${HOME_DIRS[@]}")}, creates those folders.
		Empty unused standard folders go to ~/_backup/$TS, others stay.
	EOF
    section desktop "Desktop: g0wm" <<-EOF
		Session: dbus elogind polkit pipewire xwayland (elogind replaces acpid).
		The power key opens a menu (sleep, reboot, shut down) instead of turning off the PC, the lid suspends. No hibernation.
		Apps: foot Thunar grim slurp swappy swayidle gtklock brightnessctl playerctl.
		Adds $TUSER to ${USER_GROUPS[*]}. Copies home/{$(join , "${HOME_DESKTOP[@]}")} with the default wallpaper.
		Builds, tests and installs g0wm into ~/.local/bin, again only on new commits. A g0wm built elsewhere is left alone.
		  Debian 13 has wlroots 0.18: wlroots 0.20.2 is built into $WLR_PREFIX at fixed commits, with the wayland, libdrm, xkbcommon and wayland-protocols it needs. Only g0wm uses them (rpath), the system keeps its own.
		Log in on tty1 and g0wm starts.
		'services': systemd user units keep the polkit agent, Thunar, the idle lock and the nightlight running while g0wm runs (g0wm-session.target), with the PipeWire and ssh-agent units of Debian. g0wm uses the user bus of dbus-user-session.
	EOF
    section media "Screen sharing and audio" <<-EOF
		PipeWire with wireplumber and pipewire-pulse, ALSA through PipeWire. The services command runs them.
		Screen sharing via the wlr portal, pick the output with slurp.
	EOF
    section apps "Apps, Thunar, default apps, shortcuts" <<-EOF
		librewolf (own repo, signing key pinned), Loupe, Showtime, Papers, LibreOffice, Thunar, xarchiver, pavucontrol and CLI tools. unrar comes from non-free.
		~/.local/bin: photo video pdf office browser files audio wifi bluetooth screenshot record osd indicator nightlight awake extract compress open metadata-remover privacy-check traces conns isolate dotfiles.
		Thunar: side pane with only home, Desktop, Trash, Random, Pictures, Videos, Music, Games, Private and File System. 'Open Terminal Here', automount, Remove and Show Metadata (camera, GPS, author data; runs offline in a sandbox), Restore a Previous Version and Delete from the Snapshots.
		Print: region, Shift: screen, Ctrl: edit in swappy. Saved to Pictures and the clipboard.
		Super+Print: record, Shift: region, Ctrl: no audio.
		Super+= nightlight. Super+- always on: no lock or blank until off.
		Default apps: images Loupe, video Showtime, PDF Papers, web librewolf, folders Thunar, archives xarchiver, documents LibreOffice, text vim (nvim in Open With).
		GTK apps keep no list of recently used files.
		LibreWolf: letterboxing on, so the window size the tiling layout gives it does not identify it (~/.config/librewolf/librewolf/librewolf.overrides.cfg).
	EOF
    section games "Games: Steam and Lutris work once you install them" <<-EOF
		vm.max_map_count 1048576 as on SteamOS: many Proton games crash with the default 65530.
		Steam and Lutris are not installed. Once you install them AppArmor confines them (apparmor) and ~/Games and ~/.local/share/Steam stay out of the snapshots (maint).
	EOF
    section session "Keyring, polkit, network and bluetooth" <<-EOF
		The keyring unlocks with your login password. Polkit agent in g0wm.
		No tray icons: 'wifi' and 'bluetooth' open their managers.
		Bluetooth is off at every boot: 'bluetooth on' or 'bluetooth off'.
		Bluetooth shows itself as 'Computer' instead of the hostname, uses a random address that changes (Privacy=device) and stays discoverable 30 seconds.
	EOF
    section theme "Theme: Adwaita dark" <<-EOF
		GTK 2, 3, 4 and Qt 5, 6 in Adwaita dark, Geist 11 as UI font, Geist Mono 11 for code.
		Bibata-Modern-Classic cursor (sha256 checked) in the palette, size $CURSOR_SIZE.
		AdwaitaLegacy $ICONS_TAG for full color icons in pavucontrol and Thunar.
	EOF
    section fonts "Fonts: Geist and Geist Mono" <<-EOF
		Geist for text, Geist Mono for terminal, code and g0wm, from the v1.7.2 release (sha256 checked). Nerd symbols (v3.4.0 release, sha256 checked: Debian has no package), emoji and CJK as fallback.
		Removes SF Mono and SF Pro from /usr/local/share/fonts.
	EOF
    section doas "doas instead of sudo" <<-EOF
		'permit :wheel', adds $TUSER to wheel, removes and blocks sudo.
		The password is asked every time (no persist): a program in the same terminal cannot be root for the minutes after one.
		Needs a password for $TUSER. Runs last, a rollback always leaves you with doas or sudo.
	EOF

    if ((SEL[maint])); then
        [[ $(stat -f -c %T /) == btrfs ]] || die "maint: / is not btrfs"
        if [[ $(stat -c %i /home) != 256 ]]; then
            [[ $(stat -f -c %T /home) == btrfs && $(findmnt -no TARGET -T /home) == / ]] ||
                die "maint: /home is not a btrfs subvolume, it cannot be snapshotted"
            ! pgrep -u "$TUSER" -x g0wm >/dev/null || die "maint: /home moves into a subvolume of its own, log out of g0wm and run this from a tty"
            note "/home becomes a subvolume of its own (maint)"
        fi
    fi
    if ((SEL[doas])); then
        local st
        st=$(passwd -S -- "$TUSER" | awk '{print $2}')
        [[ $st == P ]] || die "$TUSER has no usable password (passwd -S: $st), run 'passwd $TUSER' first"
    fi
    if ((SEL[harden])); then
        sig_check
        command -v doas >/dev/null || command -v sudo >/dev/null || ((SEL[doas])) ||
            die "harden: su loses setuid, install doas or sudo first or select doas"
    fi
    ((SEL[apparmor] == 0)) || aa_check
    ((SEL[usb] == 0)) || usb_check

    local k on=() off=()
    for k in "${SECTIONS[@]}"; do
        if ((SEL[$k])); then on+=("$k"); else off+=("$k"); fi
    done
    ((${#on[@]})) || {
        say "nothing selected."
        exit 0
    }

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
    ask "Proceed?" || {
        say "nothing changed."
        exit 0
    }
}
