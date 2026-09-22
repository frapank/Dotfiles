# .bash_profile

[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

export QT_STYLE_OVERRIDE=Adwaita-Dark

if [ "$(tty)" = /dev/tty1 ] && [ -z "${WAYLAND_DISPLAY:-}" ] &&
    command -v start-g0wm >/dev/null 2>&1; then
    exec start-g0wm
fi
