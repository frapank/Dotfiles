#!/usr/bin/env bash
set -e

CACHE_DIR="cache/tmux"

mkdir -p cache/

if [ ! -d "$CACHE_DIR" ]; then
    git clone https://github.com/tmux/tmux.git "$CACHE_DIR"
else
    git -C "$CACHE_DIR" fetch --all --prune
    git -C "$CACHE_DIR" pull
fi

cd "$CACHE_DIR"

export CFLAGS="-O3 -march=native -pipe"
export CXXFLAGS="-O3 -march=native -pipe"

git checkout 3.6

sh autogen.sh

./configure --prefix=/usr/local

make -j"$(nproc)"

sudo make install
