# .bash_profile

[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

export QT_STYLE_OVERRIDE=Adwaita-Dark

if [ -n "${XDG_RUNTIME_DIR:-}" ] && command -v ssh-agent >/dev/null 2>&1; then
    export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
    ssh-add -l >/dev/null 2>&1
    if [ $? -eq 2 ]; then
        rm -f "$SSH_AUTH_SOCK"
        ssh-agent -a "$SSH_AUTH_SOCK" >/dev/null
    fi
fi

if [ "$(tty)" = /dev/tty1 ] && [ -z "${WAYLAND_DISPLAY:-}" ] &&
    command -v start-g0wm >/dev/null 2>&1; then
    exec start-g0wm
fi
