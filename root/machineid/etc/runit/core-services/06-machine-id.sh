[ -x /usr/bin/dbus-uuidgen ] || return 0

msg "Generating a new machine ID..."
_id=$(dbus-uuidgen)
for _f in /var/lib/dbus/machine-id /etc/machine-id; do
    [ "$_f" = /var/lib/dbus/machine-id ] || [ -f "$_f" ] || continue
    [ -L "$_f" ] && continue
    printf '%s\n' "$_id" > "$_f.new" && chmod 0644 "$_f.new" && mv -f "$_f.new" "$_f"
done
unset _id _f
