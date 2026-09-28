# shellcheck shell=bash
# network, dns and time

do_net_files() {
	step "Network, DNS and time: config"
	local n f cache=/var/cache/dnscrypt-proxy list=/etc/dnscrypt-proxy/blocked-names.txt
	put_tree networkmanager
	id -u dnscrypt_proxy >/dev/null 2>&1 || die "no dnscrypt_proxy user (the dnscrypt-proxy package creates it)"
	n=$(njot)
	put_tree dnscrypt
	if [[ ! -d $cache ]]; then
		install -d -o dnscrypt_proxy -g dnscrypt_proxy -m 0755 -- "$cache"
		jot remove "$cache"
		for f in public-resolvers.md relays.md; do
			[[ -f /etc/dnscrypt-proxy/$f && -f /etc/dnscrypt-proxy/$f.minisig ]] || continue
			install -o dnscrypt_proxy -g dnscrypt_proxy -m 0644 -- "/etc/dnscrypt-proxy/$f" "/etc/dnscrypt-proxy/$f.minisig" "$cache/"
		done
		ok "$cache (dnscrypt_proxy)"
	fi
	if [[ ! -s $list ]]; then
		backup "$list"
		try "download the DNS blocklist" /usr/local/sbin/dns-blocklist
		[[ -f $list ]] || install -o root -g root -m 0644 /dev/null "$list"
	fi
	((n == $(njot))) || DNS_NEW=1
	put_tree chrony
	run "dnscrypt-proxy config is valid" env -C / -u PWD dnscrypt-proxy -config /etc/dnscrypt-proxy/dnscrypt-proxy.toml -check
	try "chrony config parses" env -C / -u PWD chronyd -p -f /etc/chrony.conf
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
	sv_disable ntpd isc-ntpd openntpd wpa_supplicant
	for s in "$SVDIR"/dhcpcd*; do
		[[ -L $s ]] && sv_disable "${s##*/}"
	done
	sv_enable chronyd
	sv_enable dbus
	sv_enable NetworkManager
	sv_enable dnscrypt-proxy
	put_text /etc/resolv.conf 0644 <<-'EOF'
		nameserver 127.0.0.1
		options edns0
	EOF
	if ((DNS_NEW)) && [[ $(sv status dnscrypt-proxy 2>/dev/null || true) == run:* ]]; then
		jot svr dnscrypt-proxy
		try "restart dnscrypt-proxy (files changed)" sv restart dnscrypt-proxy
	fi
	for ((i = 0; i < 30; i++)); do
		pgrep -xu dnscrypt_proxy dnscrypt-proxy >/dev/null && break
		sleep 1
	done
	if ((i < 30)); then ok "dnscrypt-proxy running as dnscrypt_proxy"; else warn "dnscrypt-proxy not running yet, check it after the reboot"; fi
	if grep -qsF nft_base_desktop.conf /etc/nftables.conf; then
		nft_apply dns_lock
	else
		warn "/etc/nftables.conf is not this script's (harden section): DNS lock not installed"
	fi
}

dns_lock() {
	local uid
	uid=$(id -u dnscrypt_proxy)
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
