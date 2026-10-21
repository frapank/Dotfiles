# shellcheck shell=bash disable=SC2034
# settings

readonly G0WM_URL=https://github.com/frapank/g0wm.git
# wlroots 0.20.2, with the newer wayland 1.25.0, libdrm 2.4.131, xkbcommon 1.13.1 and
# wayland-protocols 1.47 it needs: Debian 13 has none of them
readonly WLR_URL=https://gitlab.freedesktop.org/wlroots/wlroots.git
readonly WLR_REV=d783533489e1f75d6886c2ab5c5960090ef268f8
readonly WLR_PREFIX=/usr/local/lib/wlroots-0.20
readonly WLR_DEPS=(
    'wayland https://gitlab.freedesktop.org/wayland/wayland.git 3e673a438b0a9749e3bdf5cac4befac86333024c'
    'libdrm https://gitlab.freedesktop.org/mesa/drm.git 6bfcfc725fbe0ece0918535556d61ee567b1ffff'
    'libxkbcommon https://github.com/xkbcommon/libxkbcommon.git 6f76d19db72b5d450e927b41e1e96cbe3252aba8'
    'wayland-protocols https://gitlab.freedesktop.org/wayland/wayland-protocols.git 88223018d1b578d0d8869866da66d9608e05f928'
)
readonly GEIST_URL=https://github.com/vercel/geist-font/releases/download/v1.7.2/geist-font-v1.7.2.zip
readonly GEIST_SHA256=7fc800d2ac6b92844895196e5041aca55d814c15db70c44f79b3b83ab82b04e2
readonly NERD_URL=https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/NerdFontsSymbolsOnly.tar.xz
readonly NERD_SHA256=7f8c090da3b0eaa7108646bf34cbbb6ed13d5358a72460522108b06c7ecd716a
readonly ICONS_URL=https://gitlab.gnome.org/GNOME/adwaita-icon-theme-legacy.git
readonly ICONS_TAG=46.2
readonly ICONS_REV=7642b102c4a7c4088f170f548ae37960f2443522
readonly ICONS_DIR=/usr/share/icons/AdwaitaLegacy
readonly CURSOR_URL=https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Classic.tar.xz
readonly CURSOR_SHA256=7d3495864e5bbef02f5e77de760b2905903b63c71495a78ef6306d19a3b556d8
readonly CURSOR_DIR=/usr/share/icons/Bibata-Modern-Classic
readonly CURSOR_COLORS='0a0a0a e9e9e9 cc6666 e0a86a ffee8f afd7af 8cc8c7 8ab0c6 c59dc8'
readonly CURSOR_SIZE=20
readonly GRUB_THEME_URL=https://github.com/tomdewildt/minimal-grub-theme.git
readonly GRUB_THEME_REV=1f3fe66561f5e1f88e1467e0eb189117fd09e79c
readonly GRUB_THEME_DIR=/boot/grub/themes/minimal
readonly GRUB_QUIET_MARK='# debian-postinstall: no Loading messages'
readonly GRUB_BTRFS_URL=https://github.com/Antynea/grub-btrfs.git
readonly GRUB_BTRFS_REV=2fcfbe967637166b88dadd49c834807243a941bf
readonly HMALLOC_URL=https://github.com/GrapheneOS/hardened_malloc.git
readonly HMALLOC_REV=01df350c62441e163a8b9324fb7e156acdad2c1e
readonly HMALLOC_LIB=/usr/local/lib/libhardened_malloc-light.so
readonly TS=$(date +%Y%m%d-%H%M%S)
readonly LOG=/var/log/debian-postinstall-$TS.log
readonly BAK=/var/backups/debian-postinstall/$TS
readonly LOCK=/run/debian-postinstall.lock
readonly STATE=/var/lib/debian-postinstall
readonly BASHRC_LINE='[ -f "$HOME/.bashrc_dotfile" ] && . "$HOME/.bashrc_dotfile"'
readonly PROFILE_LINE='[ -f "$HOME/.bash_profile_dotfile" ] && . "$HOME/.bash_profile_dotfile"'
readonly SOURCES=/etc/apt/sources.list.d/debian.sources
readonly COMPONENTS='main contrib non-free non-free-firmware'
# conffiles keep the local copy, the rest takes the package default
APT=(env DEBIAN_FRONTEND=noninteractive UCF_FORCE_CONFFOLD=1 NEEDRESTART_MODE=l apt-get -y -q
    -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold -o APT::Install-Recommends=false)

PKG_CORE=(git build-essential ca-certificates)
PKG_CLI=(bash bash-completion vim-nox neovim tmux universal-ctags fzf fd-find ripgrep bat
    xxd less binutils gdb ncurses-term wl-clipboard)
# taplo, zls, bash-language-server and yaml-language-server are not in Debian
PKG_LSP=(clangd rust-analyzer)
PKG_HARDEN=(nftables openssh-client)
PKG_USB=(usbguard libnotify-bin)
HARDEN_CMDLINE=(init_on_alloc=1 init_on_free=1 slab_nomerge page_alloc.shuffle=1
    randomize_kstack_offset=on vsyscall=none debugfs=off iommu.strict=1
    efi=disable_early_pci_dma lockdown=confidentiality module.sig_enforce=1 proc_mem.force_override=ptrace)
PKG_APPARMOR=(apparmor apparmor-utils xdg-dbus-proxy bubblewrap python3-gi gir1.2-glib-2.0
    libwayland-dev wayland-protocols pkgconf)
AA_KEEP=(bin.ping unix-chkpwd usr.bin.wpa_supplicant usr.sbin.dnsmasq zgrep loupe chromium cam
    libcamerify usr.bin.dhcpcd usr.sbin.ntpd usr.sbin.traceroute usr.bin.uuidd)
PKG_NET=(network-manager wpasupplicant wireless-regdb dnscrypt-proxy chrony dbus curl)
PKG_BOOT=(plymouth plymouth-themes console-setup)
PKG_DESKTOP=(
    # g0wm build
    pkgconf libwayland-dev wayland-protocols
    libxkbcommon-dev libinput-dev libpixman-1-dev libfcft-dev libtllist-dev
    libdbus-1-dev libxcb1-dev libxcb-icccm4-dev libgdk-pixbuf-2.0-dev
    # wlroots build
    meson ninja-build libegl-dev libgles-dev libgbm-dev libvulkan-dev glslang-tools libseat-dev
    libudev-dev libdisplay-info-dev libliftoff-dev hwdata liblcms2-dev libxcb-composite0-dev
    libxcb-ewmh-dev libxcb-render0-dev libxcb-res0-dev libxcb-xfixes0-dev libxcb-errors-dev
    libffi-dev libexpat1-dev bison xkb-data
    # session
    dbus dbus-user-session libpam-systemd polkitd libgl1-mesa-dri xwayland pipewire wireplumber
    xdg-utils xdg-user-dirs fontconfig
    # settings.json monitors
    python3
    # apps
    foot thunar grim slurp swappy swayidle gtklock
    brightnessctl playerctl fonts-dejavu-core adwaita-icon-theme
)
PKG_MEDIA=(pipewire pipewire-pulse pipewire-alsa wireplumber rtkit xdg-desktop-portal
    xdg-desktop-portal-wlr xdg-desktop-portal-gtk librsvg2-common slurp dbus)
PKG_APPS=(
    librewolf foot gtklock swayidle pavucontrol
    loupe showtime papers libreoffice-writer libreoffice-calc libreoffice-impress libreoffice-gtk3 qt6-wayland
    # thunar
    thunar thunar-volman thunar-archive-plugin tumbler ffmpegthumbnailer
    gvfs gvfs-backends udisks2 xarchiver
    # default apps
    xdg-utils libgtk-3-bin gtk-update-icon-cache desktop-file-utils shared-mime-info
    gsettings-desktop-schemas dconf-gsettings-backend dconf-service libglib2.0-bin librsvg2-common
    # screenshots, screen recording, night light
    grim slurp swappy wl-clipboard wf-recorder libnotify-bin wlsunset
    # terminal tools
    tree bat htop unzip zip 7zip wget curl rsync jq file lsof strace psmisc
    ncdu fastfetch
    # archives
    tar gzip bzip2 xz-utils zstd lz4 lzip libarchive-tools cpio unrar gnupg age
    # metadata-remover
    mat2 libimage-exiftool-perl ffmpeg bubblewrap
)
PKG_SESSION=(gnome-keyring libsecret-1-0 libpam-gnome-keyring mate-polkit network-manager-gnome
    bluez blueman libspa-0.2-bluetooth)
PKG_THEME=(gnome-themes-extra adwaita-icon-theme gsettings-desktop-schemas dconf-gsettings-backend
    libglib2.0-bin qt-style-kvantum qt6ct git libgtk-3-bin gtk-update-icon-cache librsvg2-bin curl tar xz-utils python3)
PKG_FONTS=(fontconfig curl unzip xz-utils fonts-noto-core fonts-noto-color-emoji fonts-noto-cjk)
PKG_LOCALE=(locales)
PKG_HW=(fwupd fwupd-amd64-signed)
PKG_POWER=(power-profiles-daemon)
PKG_LOGS=(pulseaudio-utils gawk less)
PKG_DIRS=(xdg-user-dirs)
PKG_SWAP=(systemd-zram-generator earlyoom)
PKG_MAINT=(btrfs-progs util-linux python3 smartmontools curl)
XDG_DEFAULT_DIRS=(Desktop Documents Downloads Music Pictures Public Templates Videos)
HOME_CLI=(bash ctags nvim vim tmux ripgrep fetch)
HOME_DESKTOP=(foot g0wm gtklock services)
HOME_APPS=(thunar mime bin fastfetch librewolf)
HOME_THEME=(gtk qt)
HOME_FONTS=(fontconfig)
HOME_MEDIA=(portal)
HOME_DIRS=(xdg)
USER_GROUPS=(wheel video)
SECTIONS=(update locale cli lsp harden usb apparmor net boot hw power logs swap maint dirs desktop media apps games session theme fonts doas)
GEIST_DIR=/usr/local/share/fonts/Geist
GEIST_MONO_DIR=/usr/local/share/fonts/GeistMono
NERD_DIR=/usr/local/share/fonts/NerdFontsSymbolsOnly
OLD_FONT_DIRS=(/usr/local/share/fonts/SF-Mono /usr/local/share/fonts/SF-Pro)
# Thunar side pane: only home, Desktop, Trash, the bookmarks and File System
THUNAR_HIDDEN=(computer:/// recent:/// network:///)
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
    text/plain=vim-foot.desktop
    text/markdown=vim-foot.desktop
    text/x-c=vim-foot.desktop
    text/x-csrc=vim-foot.desktop
    text/x-chdr=vim-foot.desktop
    text/x-c++src=vim-foot.desktop
    text/x-rust=vim-foot.desktop
    text/x-python=vim-foot.desktop
    text/x-shellscript=vim-foot.desktop
    application/x-shellscript=vim-foot.desktop
    application/json=vim-foot.desktop
    application/toml=vim-foot.desktop
    application/x-yaml=vim-foot.desktop
    text/x-log=vim-foot.desktop
)

YES=0 ABORT=0 STAGE=preflight TUSER= TGID= THOME= REPO= UBAK=
AS_USER=()
HW_PKGS=() HW_DESC=() NEW_PKGS=() REGEN=0 WLR_NEW=0 ZRAM_PCT=0 ZRAM_MIB=0 FONTS_NEW=0 DNS_NEW=0 GRUB_STALE=0 USB_NEW=0 SD_RELOAD=0
declare -A SEL=() BACKED=()
