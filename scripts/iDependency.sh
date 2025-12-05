#!/usr/bin/env bash
set -e

if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo "Can't detect distro"
    exit 1
fi

echo "Detected: $DISTRO"

case "$DISTRO" in
    ubuntu|debian)
        sudo apt update
        sudo apt install -y \
            build-essential git curl wget cmake ninja-build gettext unzip \
            libtool libtool-bin autoconf automake pkg-config bison \
            libncurses-dev libevent-dev libgtk-3-dev lua5.4 lua5.4-dev \
            ruby-dev perl libperl-dev tcl-dev python3-dev python3-pip \
            doxygen
        ;;
    arch)
        sudo pacman -Syu --noconfirm
        sudo pacman -S --needed --noconfirm \
            base-devel git cmake ninja gettext unzip \
            libtool autoconf automake pkgconf bison \
            ncurses libevent gtk3 lua lua52 lua-lpeg \
            ruby perl tcl python python-pip doxygen
        ;;
    fedora)
        sudo dnf update -y
        sudo dnf install -y \
            gcc gcc-c++ make git cmake ninja-build gettext unzip \
            libtool autoconf automake pkgconfig bison \
            ncurses-devel libevent-devel gtk3-devel lua lua-devel \
            ruby-devel perl perl-ExtUtils-Embed tcl-devel python3-devel \
            doxygen
        ;;
    *)
        echo "Distro not supported"
        exit 1
        ;;
esac

