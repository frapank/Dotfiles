#!/usr/bin/env bash

set -Eeuo pipefail
cd -- "$(dirname -- "$(readlink -f -- "$0")")/.."

bad=0
fail() { printf '  ✗ %s\n' "$*"; bad=1; }
pass() { printf '  ✓ %s\n' "$*"; }

for c in bash dash shellcheck python3; do
	command -v "$c" >/dev/null || { echo "missing: $c" >&2; exit 2; }
done

sh_files=() bash_files=(home/bash/.bashrc home/bash/.bash_profile)
while IFS= read -r -d '' f; do
	case $(head -n1 -- "$f") in
	'#!/bin/sh'*) sh_files+=("$f") ;;
	'#!'*bash*) bash_files+=("$f") ;;
	esac
done < <(find postinstall.sh home root -type f ! -name '*.png' -print0 | sort -z)

echo "syntax"
for f in "${bash_files[@]}"; do
	bash -n -- "$f" 2>&1 || fail "$f"
done
for f in "${sh_files[@]}"; do
	dash -n -- "$f" 2>&1 || fail "$f"
done
((bad)) || pass "${#bash_files[@]} bash, ${#sh_files[@]} sh"

echo "shellcheck $(shellcheck --version | awk '/^version:/ { print $2 }')"
if shellcheck -x -s bash -- "${bash_files[@]}" && shellcheck -s sh -- "${sh_files[@]}"; then
	pass "no warnings"
else
	fail "shellcheck"
fi

echo "files"
while IFS= read -r -d '' f; do
	python3 -m json.tool -- "$f" >/dev/null || fail "$f is not valid JSON"
done < <(find home root -type f -name '*.json' -print0)
for f in postinstall.sh home/*/.local/bin/* root/*/etc/sv/*/run root/*/etc/sv/*/*/run root/*/usr/local/sbin/*; do
	[[ -x $f ]] || fail "$f is not executable"
done
l=$(find home root -type l)
[[ -z $l ]] || fail "symlinks, postinstall.sh refuses them: $l"
((bad)) || pass "json, modes, no symlinks"

exit "$bad"
