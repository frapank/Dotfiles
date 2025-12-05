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

./configure \
  --with-features=huge \
  --enable-gui=gtk3 \
  --enable-multibyte \
  --enable-clipboard \
  --enable-cscope \
  --enable-terminal \
  --enable-luainterp \
  --enable-fail-if-missing \
  --prefix=/usr/local

make -j"$(nproc)"
sudo make install

echo "Done! Installed in: /usr/local/bin/vim"
