[ -n "$IS_CONTAINER" ] && return 0

_font=ter-v16n
_size=
[ -r /sys/class/graphics/fb0/virtual_size ] && read -r _size </sys/class/graphics/fb0/virtual_size
[ "${_size#*,}" -ge 1440 ] 2>/dev/null && _font=ter-v32n

msg "Setting up TTYs font to '${_font}'..."
_i=0
while [ "$_i" -le "${TTYS:-12}" ]; do
    setfont "$_font" -C "/dev/tty$_i" 2>/dev/null
    _i=$((_i + 1))
done
unset _font _size _i
