# G0 Dotfiles

These are my personal dotfiles, made for my PC and for the way I use it, not meant to be a thing for others. I do not recommend anyone install them: the installer changes quite a lot of the system and takes my choices for granted. If something interests you take inspiration and copy just that piece.

This repo contains my dotfiles and the installer of them, for Debian 13 (trixie). My dotfiles aim to guarantee an environment that is consistent, secure and that gives priority to privacy.
The script provides a pre-installation of several programs, among which:
- G0wm, my personal window manager, originally based on dwl.
- Several utils scripts: open, extract, compress, metadata-remover, traces, conns, isolate, snap, forget, logs etc.
- There are several custom services, among them watchdog that checks crashes, errors and various problems and maint that handles the maintenance of the system automatically. All integrated with the G0wm notification system.
- Many of these scripts are tied to g0wm keybinds and to the statusbar icons, for example awake that keeps gtklock from starting and nightlight that is the blue light filter. This comes with record, screenshot, volume manager etc.
- Many programs, especially the ones that open files, are completely sandboxed through AppArmor and dbus-filter.

## Install

Debian from the netinst image, in the text installer:
- in "Software selection" only "standard system utilities": no desktop, g0wm is the desktop.
- partitioning "Guided - use entire disk and set up encrypted LVM", or by hand LUKS with btrfs on it: / has to be btrfs for the snapshots. The installer puts / in a @rootfs subvolume, the script makes /home a subvolume of its own.
- a password for your user. A root password is not needed: doas replaces sudo.

Then on tty1, from the cloned repo: `doas ./install.sh`, or `sudo ./install.sh` the first time. It asks what to apply, shows the plan and rolls everything back if a step fails.

What Debian does not have is built or downloaded at fixed commits and checksums: wlroots 0.20 with the newer wayland, libdrm, xkbcommon, wayland-protocols and pixman it needs and libscfg for the g0wm config, in /usr/local/lib/wlroots-0.20 (only g0wm uses them, by its rpath), grub-btrfs, hardened_malloc, the Geist and Nerd symbols fonts, the cursor and icon themes. LibreWolf comes from its own repository, with the key Debian's extrepo lists for it.

## Maint

maint is the service that handles the maintenance of the system automatically. Every hour it checks what there is to do and does it:
- every day: snapshot of /home (it keeps 14), cleanup of old thumbnails and trash, update of the system and of the DNS blocklist.
- every week: old kernels and orphan packages (apt autoremove; the kernels a snapshot of / boots are kept), firmware and Vesktop, a .deb apt does not update (notification only), disk health, the integrity of the package files (debsums).
- every month: btrfs scrub, only with the PC plugged in.

The update starts only if you are logged in, with the battery above 20% and enough free disk. First it takes a snapshot of / that can be booted from GRUB, then it installs. Every phase sends a notification. apt takes the same snapshot when you run it by hand, before dpkg changes anything. A snapshot boots with a throwaway overlay in RAM (overlayroot).
For the snapshots there are snap, that shows and restores the versions of a file, and forget, that deletes it from all the snapshots.

## Sandbox

One of the blocks is dbus-filter. dbus-filter is a simple sh script. Basically it combines xdg-dbus-proxy and bwrap in order to create a protected environment, where the filtered application can send only the necessary requests to the dbus filter (the proxy), with bwrap acting as a block on the process, so that it cannot access the main bus.
The applications affected by dbus-filter are in /usr/local/bin/{applications} and they include librewolf, papers, libreoffice, soffice, showtime, xarchiver and vesktop (if installed, /usr/local/share/applications has its launcher).
All this comes with some .service files in /usr/local/share/dbus-1/services/ that open with the filter also the apps started by dbus, that is tumblerd and showtime. Loupe, which is not in the sandbox (glycin already sandboxes the decoding), starts from there and from /usr/local/bin/loupe without gvfs: the filtered apps can ask it over dbus to open a URI, and gvfs would fetch an http one for an app without network.

dbus-filter-open is a dbus service in python that runs outside the sandbox. When a filtered app wants to open another one, for example papers opening a link, the request goes through it: it checks the arguments and opens the right app with its filter. If an app without network wants to open a link in the browser, it first asks for confirmation with a notification, so it cannot get data out.

xdg-dbus-proxy and bubblewrap are external programs, the same ones Flatpak uses. The proxy acts as a fake bus and lets through only portals, dconf and little else. The apps write dconf in a database of their own, ~/.config/dconf/sandbox, and read the user's under it: a setting they write never reaches the programs outside, some of which run what they find there (virt-manager connects to the libvirt URIs in its settings, and a URI can run a command). bwrap instead gives the app an empty runtime dir (/run/user/UID) with only dconf, the document portal, its own filtered bus and Wayland socket, and audio for the apps that have it: the rest of that dir runs commands outside the sandbox (the foot server, systemd, nvim) or holds keys (ssh, gpg, keyring). It also hides tmux and ssh-agent in /tmp, the real bus and X11, and takes the network away from the apps without network. The system bus goes through the proxy too: polkit lets anything in the session change the network or power off without a password, so the apps with audio reach only RealtimeKit there, the others nothing.

wl-sandbox is a small program in C that creates a "sandbox" Wayland socket: this way g0wm knows it is a confined app and does not let it read the screen or send fake input. Without that socket the app has no display, it never gets the real compositor. The clipboard is not restricted: as on any Wayland desktop, the focused app is told what was copied last.

landlock-scope is another small program in C. bwrap hides the sockets of the session, but it cannot hide an abstract unix socket from an app with the host network (librewolf), and Xwayland listens on one. landlock-scope runs the app under Landlock: no abstract unix socket and no signal outside the sandbox, and with Landlock ABI 9 (kernel 7, from trixie-backports) of the pathname unix sockets only the few the app uses (its filtered bus, the system bus, audio); the 6.12 kernel of Debian 13 stops at ABI 6, there bwrap hiding the sockets is what holds. This is done by the kernel and does not depend on AppArmor: the 6.12 kernel does not mediate unix sockets, and the newer ones offer them as network_v9/af_unix, which the parser of AppArmor 4.1 does not compile, so the rules on socket paths in the profiles do not stop connect(). The comments in the abstractions say so.

Another protection present is GrapheneOS's hardened_malloc in the light variant, which is a hardened memory allocator that if it detects a memory bug makes the app crash instead of becoming a hole. It is used by papers, showtime, xarchiver and tumblerd.

Then there is isolate to run a command by hand in a sandbox: read-only system, empty home and no network. With -n it has the host network, 127.0.0.1 included.

Another system put there is AppArmor with profiles and abstractions. Among the abstractions we have these:
- app-read: the base, reading the system and using the GPU.
- app: reading the files in the home, but writing only to ~/Get, ~/Random, ~/Media and /tmp.
- secrets: never ~/.ssh, gpg, keyring, credentials, histories and core dumps.
- persist: never writing things that run code later, like bashrc, PATH and autostart.
- setuid: never launching doas, su, pkexec etc.
- browser-data: never the browser profile.
- no-av: no microphone and webcam.
- pipewire-manager: the PipeWire control socket only for pipewire and wireplumber.
- root-secrets: for the root services, no /home, passwords and keys.

The profiles instead are these:
- librewolf: network, audio and webcam, but never ~/Private.
- vesktop: the same, and its own login in ~/.config/vesktop that no other profile reads. No keyring, which would give it every secret in it.
- papers, libreoffice, xarchiver: no network, audio and webcam.
- showtime: no network, but with audio.
- tumblerd: read only, it writes only the thumbnails and its temporary files.
- foot: the terminal is confined, the shell inside is not. It keeps foot itself from reading the secrets, not an exploit in foot, which can start a shell.
- pipewire, wireplumber: only audio and video.
- NetworkManager, dnscrypt-proxy, bluetoothd, fwupd, wpa_supplicant: only what they use.
- chronyd: the profile of Debian, with the certificates for NTS and the root secrets added in local/.
- steam, lutris: everything except secrets, browser and setuid, only if you install them.

The other profiles of Debian stay. The ones for the same programs are disabled in /etc/apparmor.d/disable: those of papers and LibreOffice, which let the app write all of the home, and the unconfined steam, librewolf and vesktop profiles. Their postinst load them again at every update (vesktop's over the one here, it has the same name): after each apt run aa-packages unloads them and puts the ones here back.

There are hardened kernel options that prevent several exploits:
- memory zeroed when it is allocated and freed.
- lockdown at the confidentiality level and only signed modules.
- no kexec, SysRq and io_uring.
- ASLR at max and kernel addresses hidden.
- ptrace, perf and BPF restricted.
- a program cannot type into the terminal that launched it.
- many rare modules blocked, like firewire and old filesystems, part of them from the list of Kicksecure.
- from Kicksecure too: no IOMMU passthrough and every device isolated in the IOMMU, KFENCE, the random pool not trusted to the CPU or the bootloader alone, no writes to the disk under a mounted filesystem, TSX off, Intel ME, msr and optical drives blocked.
- the CPU mitigations stay the kernel's defaults: the stricter ones of Kicksecure turn off SMT or AVX, too much for gaming.

The kernel arguments go in /etc/default/grub.d, /etc/default/grub stays the one of Debian. The sysctl files sort after the 50-default.conf of Debian, which would undo part of them.

## systemd

The services of the dotfiles are systemd units: maint, watchdog, usbguard-notify, journal-prune. Those of the session are user units bound to g0wm-session.target, with the PipeWire and ssh-agent units of Debian, and 'services' starts and stops them. On top of the units of Debian, drop-ins add the sandbox of systemd to NetworkManager, dnscrypt-proxy and bluetoothd.

The logs are in the journal, on disk and capped: logs reads it. Nothing is written on the terminals (ForwardToWall).

## Users, permissions and processes

- the processes of other users are invisible to the users of the daemons (hidepid in fstab). Your user is in the proc group, which the polkit agent needs, and sees them all, and so does librewolf, which has no PID namespace of its own; systemd-logind and polkitd are in it too.
- nosuid removes setuid from su, pkexec, passwd etc., since doas is enough, and from pppd, which NetworkManager runs as root, and the file capabilities of cdrecord and the other cdrtools programs. dpkg-statoverride keeps it across updates.
- doas instead of sudo, with the password every time (no persist). sudo is pinned away, polkit asks the password of the wheel group.
- a new machine-id at every boot: /etc/machine-id is empty on disk and systemd puts a random one over it in RAM.
- /boot and /boot/efi readable only by root and nosuid,nodev,noexec.
- core dumps are dropped, only the one of g0wm is kept for debugging it.

## Network and privacy

- firewall with nftables: nothing incoming and no announcements on the LAN.
- dnscrypt-proxy: all the DNS encrypted, with a blocklist, and the firewall blocks the DNS of the others. It runs on the socket of Debian's unit, 127.0.2.1.
- chrony with authenticated time (NTS).
- NetworkManager with random MAC and no hostname in DHCP. It takes over the interfaces the Debian installer set.
- apt only over https, its downloads under seccomp, never from an unsigned repository.

## USB

With usbguard new devices stay blocked. When you plug one in a notification arrives that asks Allow or Block and warns if it can also "type" (BadUSB). It is managed with the usb command.

## Checks and monitoring

- watchdog: sends notifications for crashes, disk errors, temperature, battery, microphone and webcam in use, AppArmor denials etc.
- logs: to read the logs, like logs apparmor or logs firewall.
- privacy-check: checks in one go that network, DNS, AppArmor and the rest are fine.
- conns: shows the open connections with the program and its AppArmor profile.
- traces: shows or deletes recent files, histories, thumbnails, trash and clipboard.

## AI Disclaimer

This repository may contain AI-assisted code and documentation. Not every commit is AI-generated, and all AI-generated commits are reviewed and supervised by humans.

## License

GPL-3.0, see [LICENSE](LICENSE).
