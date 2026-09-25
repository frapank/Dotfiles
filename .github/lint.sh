#!/usr/bin/env bash

set -Eeuo pipefail
cd -- "$(dirname -- "$(readlink -f -- "$0")")/.."

bad=0
fail() { printf '  ✗ %s\n' "$*"; bad=1; }
pass() { printf '  ✓ %s\n' "$*"; }

for c in bash dash shellcheck python3 apparmor_parser cc pkg-config wayland-scanner; do
	command -v "$c" >/dev/null || { echo "missing: $c" >&2; exit 2; }
done

py_files=() sh_files=() bash_files=(home/bash/.bashrc home/bash/.bash_profile)
while IFS= read -r -d '' f; do
	case $(head -n1 -- "$f") in
	'#!/bin/sh'*) sh_files+=("$f") ;;
	'#!'*bash*) bash_files+=("$f") ;;
	'#!'*python3*) py_files+=("$f") ;;
	esac
done < <(find postinstall.sh home root src -type f ! -name '*.png' -print0 | sort -z)

echo "syntax"
for f in "${bash_files[@]}"; do
	bash -n -- "$f" 2>&1 || fail "$f"
done
for f in "${sh_files[@]}"; do
	dash -n -- "$f" 2>&1 || fail "$f"
done
for f in "${py_files[@]}"; do
	python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read(), sys.argv[1])' "$f" || fail "$f"
done
((bad)) || pass "${#bash_files[@]} bash, ${#sh_files[@]} sh, ${#py_files[@]} python"

echo "shellcheck $(shellcheck --version | awk '/^version:/ { print $2 }')"
if shellcheck --rcfile .github/shellcheckrc -x -s bash -- "${bash_files[@]}" && shellcheck --rcfile .github/shellcheckrc -s sh -- "${sh_files[@]}"; then
	pass "no warnings"
else
	fail "shellcheck"
fi

echo "files"
while IFS= read -r -d '' f; do
	python3 -m json.tool -- "$f" >/dev/null || fail "$f is not valid JSON"
done < <(find home root -type f -name '*.json' -print0)
for f in postinstall.sh home/*/.local/bin/* root/*/etc/sv/*/run root/*/etc/sv/*/*/run root/*/usr/local/sbin/* root/*/usr/local/bin/* root/*/usr/local/libexec/*; do
	[[ -x $f ]] || fail "$f is not executable"
done
l=$(find home root src -type l)
[[ -z $l ]] || fail "symlinks, postinstall.sh refuses them: $l"
((bad)) || pass "json, modes, no symlinks"

echo "c"
xml=/usr/share/wayland-protocols/staging/security-context/security-context-v1.xml
wl=$(mktemp -d)
read -ra wlflags <<<"$(pkg-config --cflags --libs wayland-client)"
if wayland-scanner client-header "$xml" "$wl/security-context-v1-client-protocol.h" &&
	wayland-scanner private-code "$xml" "$wl/security-context-v1-protocol.c" &&
	cc -O2 -Wall -Wextra -Werror -I"$wl" -o "$wl/wl-sandbox" src/wl-sandbox.c \
		"$wl/security-context-v1-protocol.c" "${wlflags[@]}"; then
	pass "src/wl-sandbox.c builds with -Werror"
else
	fail "src/wl-sandbox.c"
fi
rm -rf -- "$wl"

echo "apparmor $(apparmor_parser --version | awk 'NR == 1 { print $NF }')"
aa=$(mktemp -d)
trap 'rm -rf "$aa"' EXIT
cp -a /etc/apparmor.d/. root/apparmor/etc/apparmor.d/. "$aa/"
aa_files=("$aa/usr.bin.wpa_supplicant")
for f in root/apparmor/etc/apparmor.d/*; do
	[[ -f $f ]] && aa_files+=("$aa/${f##*/}")
done
if out=$(apparmor_parser --base "$aa" -QK -- "${aa_files[@]}" 2>&1); then
	pass "$((${#aa_files[@]} - 1)) profiles compile"
else
	grep -v '^Cache read/write disabled' <<<"$out"
	fail "apparmor profiles"
fi

exit "$bad"
