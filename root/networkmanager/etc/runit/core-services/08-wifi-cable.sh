# Wi-Fi turned off by NetworkManager/dispatcher.d/50-wifi-cable: on again, the
# cable may be gone
_m=/var/lib/NetworkManager/wifi-off-by-cable
_s=/var/lib/NetworkManager/NetworkManager.state
if [ -e "$_m" ]; then
    [ -f "$_s" ] && sed -i 's/^WirelessEnabled=false$/WirelessEnabled=true/' "$_s"
    rm -f "$_m"
fi
unset _m _s
