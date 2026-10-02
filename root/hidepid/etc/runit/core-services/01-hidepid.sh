# /proc is mounted before fstab is read
_gid=$(getent group proc | cut -d: -f3)
if [ -n "$_gid" ]; then
    msg "Hiding the processes of other users..."
    mount -o remount,hidepid=invisible,gid="$_gid" /proc || msg_warn "/proc: hidepid failed"
fi
unset _gid
