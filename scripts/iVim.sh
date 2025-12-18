#!/usr/bin/env bash
set -e

CACHE_DIR="cache/vim"

mkdir -p cache/

if [ ! -d "$CACHE_DIR" ]; then
  git clone https://github.com/vim/vim.git "$CACHE_DIR"
else
  git -C "$CACHE_DIR" pull
fi

cd "$CACHE_DIR"

export CFLAGS="-O3 -march=native -pipe"
export CXXFLAGS="-O3 -march=native -pipe"

./configure \
  --with-features=huge \
  --with-x \
  --enable-gui=gtk3 \
  --enable-clipboard \
  --enable-xterm_clipboard \
  --enable-multibyte \
  --enable-terminal \
  --enable-xim \
  --enable-fontset \
  --enable-cscope \
  --enable-socketserver \
  --enable-autoservername \
  --enable-luainterp=dynamic \
  --with-luajit \
  --enable-python3interp=dynamic \
  --enable-perlinterp=dynamic \
  --enable-rubyinterp=dynamic \
  --enable-tclinterp=dynamic \
  --enable-fail-if-missing \

make -j"$(nproc)"
sudo make install
