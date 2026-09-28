[ -d /sys/fs/pstore ] || return 0
mountpoint -q /sys/fs/pstore ||
    mount -t pstore -o nosuid,nodev,noexec pstore /sys/fs/pstore 2>/dev/null || return 0

_dir=
for _f in /sys/fs/pstore/*; do
    [ -f "$_f" ] || continue
    if [ -z "$_dir" ]; then
        msg "Saving the kernel crash log of the last boot..."
        _dir=/var/log/pstore/$(date +%Y%m%d-%H%M%S)
        mkdir -p "$_dir" || { _dir=; break; }
        chgrp socklog /var/log/pstore "$_dir" 2>/dev/null
        chmod 2750 /var/log/pstore "$_dir"
    fi
    _to=$_dir/${_f##*/}
    if cp -- "$_f" "$_to"; then
        chgrp socklog "$_to" 2>/dev/null
        chmod 0640 "$_to"
        rm -f -- "$_f"
    fi
done
[ -z "$_dir" ] || echo "$_dir" >/run/pstore-new
unset _dir _f _to
