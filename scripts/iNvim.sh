#!/usr/bin/env bash
set -e

CACHE_DIR="cache/neovim"

mkdir -p cache/

if [ ! -d "$CACHE_DIR" ]; then
    git clone https://github.com/neovim/neovim.git "$CACHE_DIR"
else
    git -C "$CACHE_DIR" fetch --all --prune
    git -C "$CACHE_DIR" pull
fi

cd "$CACHE_DIR"

export CFLAGS="-O3 -march=native -pipe"
export CXXFLAGS="-O3 -march=native -pipe"

git fetch
git checkout release-0.11
git pull

make distclean || true
rm -rf build/

make CMAKE_BUILD_TYPE=RelWithDebInfo

sudo make install
