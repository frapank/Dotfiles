# shellcheck shell=bash
# network, dns and time

do_net_files() {
    step "Network, DNS and time: config"
    local n list=/etc/dnscrypt-proxy/blocked-names.txt
    put_tree networkmanager
    id -u _dnscrypt-proxy >/dev/null 2>&1 || die "no _dnscrypt-proxy user (the dnscrypt-proxy package creates it)"
    n=$(njot)
    put_tree dnscrypt
    if [[ ! -s $list ]]; then
        backup "$list"
        try "download the DNS blocklist" /usr/local/sbin/dns-blocklist
        [[ -f $list ]] || install -o root -g root -m 0644 /dev/null "$list"
    fi
    ((n == $(njot))) || DNS_NEW=1
    put_tree chrony
    run "dnscrypt-proxy config is valid" env -C / -u PWD dnscrypt-proxy -config /etc/dnscrypt-proxy/dnscrypt-proxy.toml -check
    try "chrony config parses" env -C / -u PWD chronyd -p -f /etc/chrony/chrony.conf
    run "NetworkManager config parses" env -C / -u PWD NetworkManager --print-config
}

do_net_services() {
    step "Network, DNS and time: services"
    local s i
    trap '' HUP
    if [[ -n ${SSH_CONNECTION:-} ]]; then
        say "  on SSH: the rest goes to $LOG only"
        exec >>"$LOG" 2>&1
    fi
    # chrony replaced systemd-timesyncd when it was installed
    svc_disable ntpsec.service openntpd.service systemd-timesyncd.service
    svc_enable chrony.service
    svc_enable NetworkManager.service
    svc_enable dnscrypt-proxy.socket
    svc_enable dnscrypt-proxy.service
    ifupdown_handover
    # Debian's dnscrypt-proxy.socket
    put_text /etc/resolv.conf 0644 <<-'EOF'
		nameserver 127.0.2.1
		options edns0
	EOF
    if ((DNS_NEW)) && systemctl -q is-active dnscrypt-proxy.service; then
        jot svr dnscrypt-proxy.service
        try "restart dnscrypt-proxy (files changed)" systemctl restart dnscrypt-proxy.service
    fi
    for ((i = 0; i < 30; i++)); do
        pgrep -xu _dnscrypt-proxy dnscrypt-proxy >/dev/null && break
        sleep 1
    done
    if ((i < 30)); then ok "dnscrypt-proxy running as _dnscrypt-proxy"; else warn "dnscrypt-proxy not running yet, check it after the reboot"; fi
    if grep -qsF nft_base_desktop.conf /etc/nftables.conf; then
        nft_apply dns_lock
    else
        warn "/etc/nftables.conf is not this script's (harden section): DNS lock not installed"
    fi
}

# the installer's network: NetworkManager leaves alone what /etc/network/interfaces has
ifupdown_handover() {
    local f=/etc/network/interfaces ifs i ssid psk sec
    [[ -f $f ]] || return 0
    ifs=$(awk '$1 == "iface" && $2 != "lo" { print $2 }' "$f" | sort -u)
    if [[ -z $ifs ]]; then
        skip "no interface in $f"
        return 0
    fi
    for i in $ifs; do
        ssid=$(ifupdown_get "$f" "$i" wpa-ssid)
        psk=$(ifupdown_get "$f" "$i" wpa-psk)
        [[ -n $ssid ]] || continue
        if nmcli -g NAME connection show 2>/dev/null | grep -qxF -- "$ssid"; then
            skip "Wi-Fi $ssid in NetworkManager"
            continue
        fi
        sec=()
        [[ -z $psk ]] || sec=(wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$psk")
        jot nmcon "$ssid"
        # not with run: the passphrase would end up in the log
        if nmcli connection add type wifi ifname "$i" con-name "$ssid" ssid "$ssid" "${sec[@]}" >>"$LOG" 2>&1; then
            ok "Wi-Fi $ssid moved to NetworkManager"
        else
            warn "could not move Wi-Fi $ssid to NetworkManager: connect again with 'wifi'"
        fi
    done
    for i in $ifs; do
        try "$i down for NetworkManager" ifdown --force "$i"
    done
    put_text "$f" 0644 < <(awk '
		$1 ~ /^(auto|allow-[a-z]+|iface|mapping|source|source-directory)$/ { s = ($1 == "iface" ? $2 != "lo" : $1 ~ /^(auto|allow-)/ ? $NF != "lo" : 0) }
		s && !/^[[:space:]]*#/ { print "# " $0; next }
		{ print }' "$f")
    try "NetworkManager takes over $(echo "$ifs" | tr '\n' ' ')" systemctl restart NetworkManager.service
}

# the value of KEY in the stanza of interface $2, without the quotes
ifupdown_get() {
    awk -v i="$2" -v k="$3" '
		$1 == "iface" { c = ($2 == i) }
		c && $1 == k { sub(/^[[:space:]]*[^[:space:]]+[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); gsub(/^"|"$/, ""); print; exit }' "$1"
}

dns_lock() {
    local uid
    uid=$(id -u _dnscrypt-proxy)
    put_text /etc/nftables/nft_dns_desktop.conf 0600 <<-EOF
		table inet dns {
		    chain output {
		        type filter hook output priority filter;
		        policy accept;

		        oif lo accept
		        ct state established,related accept

		        meta l4proto { tcp, udp } th dport 853 counter reject
		        meta skuid $uid accept
		        meta l4proto { tcp, udp } th dport 53 limit rate 5/minute log prefix "nft-dns-bypass: "
		        meta l4proto { tcp, udp } th dport 53 counter reject
		    }
		}
	EOF
}
