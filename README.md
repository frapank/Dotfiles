# G0 Dotfiles

These are my personal dotfiles, made for my PC and for the way I use it, not meant to be a thing for others. I do not recommend anyone install them: the installer changes quite a lot of the system and takes my choices for granted. If something interests you take inspiration and copy just that piece.

This repo contains my dotfiles and the installer of them. My dotfiles aim to guarantee an environment that is consistent, secure and that gives priority to privacy.
The script provides a pre-installation of several programs, among which:
- G0wm, my personal window manager, originally based on dwl.
- Several utils scripts: open, extract, compress, metadata-remover, traces, conns, isolate, snap, forget, logs etc.
- There are several custom services, among them watchdog that checks crashes, errors and various problems and maint that handles the maintenance of the system automatically. All integrated with the G0wm notification system.
- Many of these scripts are tied to g0wm keybinds and to the statusbar icons, for example awake that keeps gtklock from starting and nightlight that is the blue light filter. This comes with record, screenshot, volume manager etc.
- Many programs, especially the ones that open files, are completely sandboxed through AppArmor and dbus-filter.

## Maint

maint is the service that handles the maintenance of the system automatically. Every hour it checks what there is to do and does it:
- every day: snapshot of /home (it keeps 14), cleanup of old thumbnails and trash, update of the system and of the DNS blocklist.
- every week: old kernels, orphan packages, firmware (notification only), disk health.
- every month: btrfs scrub, only with the PC plugged in.

The update starts only if you are logged in, with the battery above 20% and enough free disk. First it takes a snapshot of / that can be booted from GRUB, then it installs. Every phase sends a notification.
For the snapshots there are snap, that shows and restores the versions of a file, and forget, that deletes it from all the snapshots.

## Sandbox

One of the blocks is dbus-filter. dbus-filter is a simple sh script. Basically it combines xdg-dbus-proxy and bwrap in order to create a protected environment, where the filtered application can send only the necessary requests to the dbus filter (the proxy), with bwrap acting as a block on the process, so that it cannot access the main bus.
The applications affected by dbus-filter are in /usr/local/bin/{applications} and they include librewolf, papers, libreoffice, soffice, showtime and xarchiver.
All this comes with some .service files in /usr/local/share/dbus-1/services/ that open with the filter also the apps started by dbus, that is tumblerd and showtime.

dbus-filter-open is a dbus service in python that runs outside the sandbox. When a filtered app wants to open another one, for example papers opening a link, the request goes through it: it checks the arguments and opens the right app with its filter. If an app without network wants to open a link in the browser, it first asks for confirmation with a notification, so it cannot get data out.

xdg-dbus-proxy and bubblewrap are external programs, the same ones Flatpak uses. The proxy acts as a fake bus and lets through only portals, dconf and little else. The apps write dconf in a database of their own, ~/.config/dconf/sandbox, and read the user's under it: a setting they write never reaches the programs outside, some of which run what they find there (virt-manager connects to the libvirt URIs in its settings, and a URI can run a command). bwrap instead hides the real bus, ssh-agent, gpg, keyring and X11 and takes the network away from the apps without network.

wl-sandbox is a small program in C that creates a "sandbox" Wayland socket: this way g0wm knows it is a confined app and does not let it read the screen or send fake input. Without that socket the app has no display, it never gets the real compositor. The clipboard is not restricted: as on any Wayland desktop, the focused app is told what was copied last.

landlock-scope is another small program in C. bwrap hides the sockets of the session, but it cannot hide an abstract unix socket from an app with the host network (librewolf), and Xwayland listens on one. landlock-scope runs the app under Landlock: no abstract unix socket and no signal outside the sandbox, and of the pathname unix sockets only the few the app uses (its filtered bus, the system bus, audio). This is done by the kernel and does not depend on AppArmor: AppArmor 4.1 knows the unix sockets as network/af_unix, this kernel offers them as network_v9/af_unix, so its parser does not compile the unix rules and the rules on socket paths in the profiles do not stop connect(). The comments in the abstractions say so.

Another protection present is GrapheneOS's hardened_malloc in the light variant, which is a hardened memory allocator that if it detects a memory bug makes the app crash instead of becoming a hole. It is used by papers, showtime, xarchiver and tumblerd.

Then there is isolate to run a command by hand in a sandbox: read-only system, empty home and no network.

Another system put there is AppArmor with profiles and abstractions. Among the abstractions we have these:
- app-read: the base, reading the system and using the GPU.
- app: reading the files in the home, but writing only to ~/Get, ~/Random, ~/Media and /tmp.
- secrets: never ~/.ssh, gpg, keyring, credentials and histories.
- persist: never writing things that run code later, like bashrc, PATH and autostart.
- setuid: never launching doas, su, pkexec etc.
- browser-data: never the browser profile.
- no-av: no microphone and webcam.
- pipewire-manager: the PipeWire control socket only for pipewire and wireplumber.
- root-secrets: for the root services, no /home, passwords and keys.

The profiles instead are these:
- librewolf: network, audio and webcam.
- papers, libreoffice, xarchiver: no network, audio and webcam.
- showtime: no network, but with audio.
- tumblerd: read only, it writes only the thumbnails.
- foot: the terminal is confined, the shell inside is not.
- pipewire, wireplumber: only audio and video.
- NetworkManager, dnscrypt-proxy, chronyd, bluetoothd, fwupd: only what they use.
- steam, lutris: everything except secrets, browser and setuid, only if you install them.

There are hardened kernel options that prevent several exploits:
- memory zeroed when it is allocated and freed.
- lockdown and only signed modules.
- no kexec, SysRq and io_uring.
- ASLR at max and kernel addresses hidden.
- ptrace, perf and BPF restricted.
- a program cannot type into the terminal that launched it.
- many rare modules blocked, like firewire and old filesystems.

## Users, permissions and processes

- the processes of other users are invisible.
- nosuid removes setuid from su, pkexec, passwd etc., since doas is enough.
- doas instead of sudo.
- a new machine-id at every boot.
- /boot readable only by root and umask 077.

## Network and privacy

- firewall with nftables: nothing incoming and no announcements on the LAN.
- dnscrypt-proxy: all the DNS encrypted, with a blocklist, and the firewall blocks the DNS of the others.
- chrony with authenticated time (NTS).
- NetworkManager with random MAC and no hostname in DHCP.

## USB

With usbguard new devices stay blocked. When you plug one in a notification arrives that asks Allow or Block and warns if it can also "type" (BadUSB). It is managed with the usb command.

## Checks and monitoring

- watchdog: sends notifications for crashes, disk errors, temperature, battery, microphone and webcam in use, AppArmor denials etc.
- logs: to read the logs, like logs apparmor or logs firewall.
- privacy-check: checks in one go that network, DNS, AppArmor and the rest are fine.
- conns: shows the open connections with the program and its AppArmor profile.
- traces: shows or deletes recent files, histories, thumbnails, trash and clipboard.
