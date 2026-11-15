#!/usr/bin/env python3
"""The palette outside the session: the console and the cursors (script/config.sh),
GRUB (GRUB_COLORS, put in its theme by script/boot.sh), plymouth and the
wallpaper of g0wm.

Not run by itself: script/g0wm-theme.py calls run() with itself, for the
palette and for read, write and sub.
"""

import os
import struct
import zlib


def config_sh(t):
    p = os.path.join(t.REPO, "script/config.sh")
    hexes = [t.ANSI[f"{kind}{n}"].lstrip("#") for kind in ("regular", "bright") for n in range(8)]
    vt = f"readonly VT_PALETTE=({' '.join(hexes[:8])}\n    {' '.join(hexes[8:])})"
    # cursor-recolor.py: dark, light, then the accents it maps each hue to
    cursor = [t.BG, t.FG, t.RED, t.ACCENT, t.ANSI["regular3"], t.ANSI["bright2"], t.ANSI["bright6"],
              t.LINK, t.VISITED]
    # the keys of minimal-grub-theme's theme.txt
    grub = {"desktop-color": t.BG, "item_color": t.SOFT, "selected_item_color": t.FG, "color": t.DIM}
    text = t.read(p)
    text = t.sub(p, text, r"^readonly VT_PALETTE=\([^)]*\)$", lambda m: vt)
    text = t.sub(p, text, r"^readonly CURSOR_COLORS='.*'$",
                 lambda m: "readonly CURSOR_COLORS='" + " ".join(c.lstrip("#") for c in cursor) + "'")
    text = t.sub(p, text, r"^readonly GRUB_COLORS=\(.*\)$",
                 lambda m: "readonly GRUB_COLORS=(" + " ".join(f"{k}={v}" for k, v in grub.items()) + ")")
    t.write(p, text)


def png(width, height, pixel):
    """An RGBA PNG; pixel(x, y) gives (r, g, b, a)."""
    rows = b"".join(b"\0" + bytes(v for x in range(width) for v in pixel(x, y)) for y in range(height))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b""))


def inside(x, y, x0, y0, x1, y1, r):
    """Whether the point is in the rectangle with corners of radius r."""
    if not (x0 <= x < x1 and y0 <= y < y1):
        return False
    cx = min(max(x, x0 + r), x1 - r)
    cy = min(max(y, y0 + r), y1 - r)
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def entry(t):
    """The password box: gtklock's, focused (1px FG border, radius 8)."""
    w, h, r, n = 380, 46, 8, 4
    fill, line = (t.hexrgb(t.POPUP), t.hexrgb(t.FG))
    subs = [(i + 0.5) / n for i in range(n)]

    def pixel(x, y):
        outer = inner = 0
        for sy in subs:
            for sx in subs:
                if inside(x + sx, y + sy, 0, 0, w, h, r):
                    outer += 1
                    inner += inside(x + sx, y + sy, 1, 1, w - 1, h - 1, r - 1)
        if not outer:
            return (0, 0, 0, 0)
        rgb = tuple(round((inner * f + (outer - inner) * b) / outer) for f, b in zip(fill, line))
        return (*rgb, round(255 * outer / (n * n)))

    p = os.path.join(t.REPO, "root/plymouth/usr/share/plymouth/themes/g0wm/entry.png")
    data = png(w, h, pixel)
    if not t.CHECK:
        with open(p, "wb") as f:
            f.write(data)
    else:
        with open(p, "rb") as f:
            if f.read() != data:
                t.STALE.append(os.path.relpath(p, t.REPO))


def plymouth(t):
    p = os.path.join(t.REPO, "root/plymouth/usr/share/plymouth/themes/g0wm/g0wm.plymouth")
    text = t.read(p)
    for k in ("BackgroundStartColor", "BackgroundEndColor", "ProgressBarBackgroundColor"):
        text = t.sub(p, text, rf"^({k}=)0x\w+$", lambda m: m[1] + "0x" + t.BG.lstrip("#"))
    t.write(p, text)
    entry(t)


def wallpaper(t):
    p = os.path.join(t.REPO, "home/g0wm/.config/g0wm/wallpaper.svg")
    text = t.read(p)
    for k, v in {"bg": t.DESK, "g": t.ACCENT, "o": t.FG}.items():
        text = t.sub(p, text, rf"^(\s*\.{k} \{{ fill: )#\w+(; \}})$", lambda m, v=v: m[1] + v + m[2])
    t.write(p, text)


def run(t):
    config_sh(t)
    plymouth(t)
    wallpaper(t)
