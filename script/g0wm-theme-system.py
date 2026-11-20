#!/usr/bin/env python3
"""The palette outside the session: the console and the cursors (script/config.sh),
GRUB (GRUB_COLORS, put in its theme by script/boot.sh), plymouth, the dog of
the login on tty1 and the wallpapers of g0wm (the rules one is drawn with the deny rules of the AppArmor
abstractions, so it changes with them).

Not run by itself: script/g0wm-theme.py calls run() with itself, for the
palette and for read, write and sub.
"""

import html
import os
import re
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
    """gtklock's password field: flat POPUP fill, radius 8, no visible border."""
    w, h, r, n = 380, 46, 8, 4
    fill = t.hexrgb(t.POPUP)
    subs = [(i + 0.5) / n for i in range(n)]

    def pixel(x, y):
        outer = 0
        for sy in subs:
            for sx in subs:
                if inside(x + sx, y + sy, 0, 0, w, h, r):
                    outer += 1
        if not outer:
            return (0, 0, 0, 0)
        return (*fill, round(255 * outer / (n * n)))

    write_png(t, f"{PLYMOUTH}/entry.png", png(w, h, pixel))

    # Plymouth repeats the whole tile: transparent space separates the dots,
    # like gtklock's letter-spacing, without the stock beveled bullet.
    fg = t.hexrgb(t.FG)

    def bullet(x, y):
        covered = sum((x + sx - 8.5) ** 2 + (y + sy - 8.5) ** 2 <= 5.5 ** 2
                      for sy in subs for sx in subs)
        return (*fg, round(255 * covered / (n * n)))

    write_png(t, f"{PLYMOUTH}/bullet.png", png(17, 17, bullet))


# The logo of g0wm: four layers in script/g0wm-logo.svg, painted in this order.
# g is the whole mark, dog the head, fur the strokes, prompt the >_.
LOGO = "script/g0wm-logo.svg"
LAYERS = ("g", "dog", "fur", "prompt")
_layers = {}
_coverage = {}


def logo_layers(t):
    if not _layers:
        found = dict(re.findall(r'<path id="(\w+)"[^>]*?\sd="([^"]+)"', t.read(os.path.join(t.REPO, LOGO))))
        assert set(found) == set(LAYERS), f"{LOGO} needs the paths {', '.join(LAYERS)}"
        _layers.update(found)
    return _layers


def segments(d, s):
    """The path as straight segments, scaled by s; each quadratic in four."""
    toks = re.findall(r"[MLQZ]|-?\d+(?:\.\d+)?", d)
    out, i, cur, start = [], 0, None, None

    def point():
        nonlocal i
        i += 2
        return (float(toks[i - 2]) * s, float(toks[i - 1]) * s)
    while i < len(toks):
        c = toks[i]
        i += 1
        if c == "M":
            cur = start = point()
        elif c == "L":
            p = point()
            out.append((cur, p))
            cur = p
        elif c == "Q":
            c1, p = point(), point()
            prev = cur
            for k in range(1, 5):
                u = k / 4
                q = tuple((1 - u) ** 2 * cur[j] + 2 * (1 - u) * u * c1[j] + u * u * p[j] for j in (0, 1))
                out.append((prev, q))
                prev = q
            cur = p
        elif c == "Z":
            out.append((cur, start))
            cur = start
    return out


def coverage(t, layer, size, ss=4):
    """How much of each pixel the layer covers, 0 to 1: even-odd scanlines, ss per pixel
    vertically and exact horizontally."""
    key = (layer, size)
    if key in _coverage:
        return _coverage[key]
    edges = sorted(((min(a[1], b[1]), max(a[1], b[1]), a, b) for a, b in segments(logo_layers(t)[layer], size / 512)
                    if a[1] != b[1]), key=lambda e: e[0])
    cov = [[0.0] * size for _ in range(size)]
    active, nxt = [], 0
    for sy in range(size * ss):
        y = (sy + 0.5) / ss
        while nxt < len(edges) and edges[nxt][0] <= y:
            active.append(edges[nxt])
            nxt += 1
        active = [e for e in active if e[1] > y]
        xs = sorted(a[0] + (y - a[1]) * (b[0] - a[0]) / (b[1] - a[1]) for y0, y1, a, b in active if y0 <= y)
        row = cov[int(y)]
        for j in range(0, len(xs) - 1, 2):
            x0, x1 = max(xs[j], 0.0), min(xs[j + 1], float(size))
            if x0 >= x1:
                continue
            i0, i1 = int(x0), int(x1)
            if i0 == i1:
                row[i0] += (x1 - x0) / ss
                continue
            row[i0] += (i0 + 1 - x0) / ss
            for k in range(i0 + 1, i1):
                row[k] += 1 / ss
            if i1 < size:
                row[i1] += (x1 - i1) / ss
    _coverage[key] = cov
    return cov


def logo_png(t, size, colors):
    """The logo as a size x size RGBA PNG, colors[layer] or None to leave it out."""
    paint = [(coverage(t, k, size), t.hexrgb(colors[k])) for k in LAYERS if colors.get(k)]

    def pixel(x, y):
        r = g = b = a = 0.0
        for cov, (cr, cg, cb) in paint:
            c = min(1.0, cov[y][x])
            if c > 0:
                r, g, b, a = cr * c + r * (1 - c), cg * c + g * (1 - c), cb * c + b * (1 - c), c + a * (1 - c)
        if a <= 0:
            return (0, 0, 0, 0)
        return (round(r / a), round(g / a), round(b / a), round(a * 255))
    return png(size, size, pixel)


def write_png(t, rel, data):
    p = os.path.join(t.REPO, rel)
    if t.CHECK:
        if not os.path.exists(p) or open(p, "rb").read() != data:
            t.STALE.append(rel)
    elif not os.path.exists(p) or open(p, "rb").read() != data:
        with open(p, "wb") as f:
            f.write(data)


def logo_svg(t, colors, x=0, y=0, size=512, extra=""):
    """The logo as an SVG group, centered on x, y if size is given that way by the caller."""
    paths = "".join(f'<path fill-rule="evenodd" {colors[k]} d="{logo_layers(t)[k]}"/>' for k in LAYERS if colors.get(k))
    return f'<g transform="translate({x:g} {y:g}) scale({size / 512:g})"{extra}>{paths}</g>'


def fill(c):
    return f'fill="{c}"'


# The variants of the logo. tone is for the dark surfaces: the strokes take the
# color under them, only the >_ is lit.
def variants(t):
    return {"": {"g": t.ACCENT, "dog": t.TAN, "fur": t.BG, "prompt": t.BG},
            "-mono": {"g": t.FG, "dog": t.SOFT, "fur": t.BG, "prompt": t.BG},
            "-tone": {"g": t.SEL, "dog": t.PRESS, "fur": t.BG, "prompt": t.ACCENT}}


ICONS = "home/g0wm/.config/g0wm/icons"
ICON_SIZES = (512, 256, 128, 64, 48, 32)
HICOLOR = "home/g0wm/.local/share/icons/hicolor/128x128/apps"


def icons(t):
    if not t.CHECK:
        os.makedirs(os.path.join(t.REPO, ICONS), exist_ok=True)
    for name, colors in variants(t).items():
        body = logo_svg(t, {k: fill(v) for k, v in colors.items()})
        t.write(os.path.join(t.REPO, ICONS, f"g0wm{name}.svg"),
                '<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">\n'
                f"  <!-- written by script/g0wm-theme.py from {LOGO}, do not edit -->\n  {body}\n</svg>\n")
        for size in ICON_SIZES:
            write_png(t, f"{ICONS}/g0wm{name}-{size}.png", logo_png(t, size, colors))
    # what screen sharing shows in place of a private window: the tone one
    write_png(t, "home/g0wm/.config/g0wm/private.png", logo_png(t, 512, variants(t)["-tone"]))
    # the icon of the system's notifications (-i g0wm), in its colors: the tone one
    # melts into the bar. g0wm looks names up in hicolor, from 24 px up, and draws
    # them at 64; 128 stays sharp at scale 2
    if not t.CHECK:
        os.makedirs(os.path.join(t.REPO, HICOLOR), exist_ok=True)
    write_png(t, f"{HICOLOR}/g0wm.png", logo_png(t, 128, variants(t)[""]))




# A family of icons, scalable in hicolor (g0wm looks for the pngs first, then
# scalable/apps/NAME.svg, and draws the svg at the size it needs). Two looks:
# - tiles: a rounded square of a palette color, the symbol in BG. For the
#   notifications, where they have to stand out in the bar
# - glyphs: the symbol alone in SOFT, no square. For the runner, quiet next to
#   the icons of the apps
# The symbols are drawn on 64 x 64 with a stroke; {c} stands for their color.
SCALABLE = "home/g0wm/.local/share/icons/hicolor/scalable/apps"
SYMBOLS = {
    "ok": '<path d="M18 33l9 9 19-20"/>',
    "failed": '<path d="M21 21l22 22M43 21L21 43"/>',
    "timer": '<path d="M22 15h20M22 49h20M25 15c0 10 14 12 14 17s-14 7-14 17M39 15c0 10-14 12-14 17s14 7 14 17"/>',
    "mic": '<path d="M32 13a6 6 0 0 1 6 6v11a6 6 0 0 1-12 0V19a6 6 0 0 1 6-6zM20 29a12 12 0 0 0 24 0M32 41v9M25 50h14"/>',
    "cam": '<path d="M14 22h24a3 3 0 0 1 3 3v14a3 3 0 0 1-3 3H14a3 3 0 0 1-3-3V25a3 3 0 0 1 3-3zM41 29l11-7v20l-11-7"/>',
    "usb": '<path d="M32 45V13M28 17l4-4 4 4M32 41l-10-6v-5M32 36l10-6v-3"/><circle cx="22" cy="27" r="3"/>'
           '<path d="M39 21h6v6h-6z"/><circle cx="32" cy="49" r="3.5" fill="{c}" stroke="none"/>',
    "reboot": '<path d="M46 34a14 14 0 1 1-4-12M46 14v9h-9"/>',
    "restart": '<path d="M46 34a14 14 0 1 1-4-12M46 14v9h-9"/>',
    "shutdown": '<path d="M32 13v18M21 20a15 15 0 1 0 22 0"/>',
    "screenshot": '<path d="M14 24v-8a2 2 0 0 1 2-2h8M40 14h8a2 2 0 0 1 2 2v8M50 40v8a2 2 0 0 1-2 2h-8M24 50h-8a2 2 0 0 1-2-2v-8"/>'
                  '<circle cx="32" cy="32" r="6"/>',
    "record": '<circle cx="32" cy="32" r="17"/><circle cx="32" cy="32" r="7" fill="{c}" stroke="none"/>',
    "volume": '<path d="M14 26h8l11-9v30l-11-9h-8zM40 25a9 9 0 0 1 0 14M45 19a17 17 0 0 1 0 26"/>',
}
# the name of each icon, its look and, for a tile, its color
TILES = {"ok": "GREEN", "failed": "RED", "timer": "ACCENT", "mic": "ACCENT", "cam": "ACCENT",
         "usb": "LINK", "reboot": "ACCENT"}
GLYPHS = ("restart", "shutdown", "screenshot", "record", "volume")


def icon_family(t):
    if not t.CHECK:
        os.makedirs(os.path.join(t.REPO, SCALABLE), exist_ok=True)
    head = '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">'
    stroke = 'fill="none" stroke-linecap="round" stroke-linejoin="round"'
    for name, color in TILES.items():
        fg = t.BG
        body = (f'<rect x="2" y="2" width="60" height="60" rx="12" fill="{getattr(t, color)}"/>'
                f'<g {stroke} stroke="{fg}" stroke-width="5">{SYMBOLS[name].replace("{c}", fg)}</g>')
        t.write(os.path.join(t.REPO, SCALABLE, f"g0wm-{name}.svg"), f"{head}{body}</svg>\n")
    for name in GLYPHS:
        fg = t.SOFT
        body = f'<g {stroke} stroke="{fg}" stroke-width="4">{SYMBOLS[name].replace("{c}", fg)}</g>'
        t.write(os.path.join(t.REPO, SCALABLE, f"g0wm-{name}.svg"), f"{head}{body}</svg>\n")


LIBREWOLF_LOGO = "home/librewolf/.config/librewolf/librewolf/chrome/g0wm-logo.svg"


def librewolf_logo(t):
    """The new tab of LibreWolf: the tone logo, userContent.css puts it above the search."""
    body = logo_svg(t, {k: fill(v) for k, v in variants(t)["-tone"].items()})
    t.write(os.path.join(t.REPO, LIBREWOLF_LOGO),
            '<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">\n'
            f"  <!-- written by script/g0wm-theme.py from {LOGO}, do not edit -->\n  {body}\n</svg>\n")



VESKTOP = "home/vesktop/.config/vesktop/themes/g0wm.theme.css"


def vesktop_logo(t):
    """--g0-logo of the Vesktop theme: the logo as a data: mask, the gaps, the strokes
    and the >_ cut out, so the home button paints it in its own color."""
    L = logo_layers(t)
    svg = ("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 512 512'><mask id='m'>"
           f"<path fill='white' fill-rule='evenodd' d='{L['g']}'/>"
           f"<path fill='black' fill-rule='evenodd' d='{L['fur']}'/>"
           f"<path fill='black' fill-rule='evenodd' d='{L['prompt']}'/>"
           "</mask><rect width='512' height='512' fill='white' mask='url(#m)'/></svg>")
    uri = "data:image/svg+xml," + "".join({"%": "%25", "#": "%23", "<": "%3C", ">": "%3E"}.get(c, c) for c in svg)
    p = os.path.join(t.REPO, VESKTOP)
    text = t.sub(p, t.read(p), r'^(\s*--g0-logo: url\(").*("\);)$', lambda m: m[1] + uri + m[2])
    t.write(p, text)


PLYMOUTH = "root/plymouth/usr/share/plymouth/themes/g0wm"


def plymouth(t):
    p = os.path.join(t.REPO, PLYMOUTH, "g0wm.plymouth")
    text = t.read(p)
    for k in ("BackgroundStartColor", "BackgroundEndColor"):
        text = t.sub(p, text, rf"^({k}=)0x\w+$", lambda m: m[1] + "0x" + t.BG.lstrip("#"))
    # the thin line under the logo: SEL, filled with the accent
    text = t.sub(p, text, r"^(ProgressBarBackgroundColor=)0x\w+$", lambda m: m[1] + "0x" + t.SEL.lstrip("#"))
    text = t.sub(p, text, r"^(ProgressBarForegroundColor=)0x\w+$", lambda m: m[1] + "0x" + t.ACCENT.lstrip("#"))
    t.write(p, text)
    write_png(t, f"{PLYMOUTH}/watermark.png", logo_png(t, 260, variants(t)[""]))
    entry(t)


HALF = 38


def half_blocks(t):
    """The logo in half blocks, HALF columns: rows of (top, bottom) cells, each "g",
    "dog" or None (the strokes and the gaps), the empty rows around it dropped."""
    n = HALF
    cov = {k: coverage(t, k, n, 8) for k in LAYERS}

    def cell(x, y):
        if cov["fur"][y][x] + cov["prompt"][y][x] > 0.22 or cov["g"][y][x] < 0.5:
            return None
        return "dog" if cov["dog"][y][x] >= 0.5 else "g"
    rows = [[(cell(x, y), cell(x, y + 1)) for x in range(n)] for y in range(0, n, 2)]
    while rows and not any(a or b for a, b in rows[0]):
        rows.pop(0)
    while rows and not any(a or b for a, b in rows[-1]):
        rows.pop()
    return rows


def fastfetch_logo(t):
    """The logo in half blocks for fastfetch, in the accent and TAN."""
    n = HALF
    color = {"g": t.ACCENT, "dog": t.TAN, None: None}

    def fg(c):
        return "\\u001b[38;2;" + ";".join(map(str, t.hexrgb(c))) + "m"

    def bg(c):
        return "\\u001b[48;2;" + ";".join(map(str, t.hexrgb(c))) + "m"
    rows = []
    for cells in half_blocks(t):
        row, cur = "", None

        def put(color, ch):
            nonlocal row, cur
            if color != cur:
                row += fg(color)
                cur = color
            row += ch
        for a, b in cells:
            top, bot = color[a], color[b]
            if not top and not bot:
                row += " "
            elif top == bot:
                put(top, "█")
            elif not bot:
                put(top, "▀")
            elif not top:
                put(bot, "▄")
            else:
                put(top, bg(bot) + "▀\\u001b[49m")
        rows.append(row + "\\u001b[0m")
    p = t.FASTFETCH
    text = t.read(p)
    logo = (f'    "logo": {{\n        "type": "data-raw",\n        "source": "{"\\n".join(rows)}",\n'
            f'        "width": {n},\n        "height": {len(rows)},\n'
            '        "padding": { "top": 2, "left": 2, "right": 4 }\n    },\n')
    text = t.sub(p, text, r'^    "logo": \{\n(?:.*\n)*?    \},\n', lambda m: logo)
    t.write(p, text)


# The dog of the login on tty1, in the 16 colors of the console with the color
# names of agetty: asleep in /etc/issue, awake for the password, grumpy after a
# wrong one. g0wm-login puts the last two in place of the first block of the issue
# and centers that block in the frame.
ISSUE = "root/agetty/etc/issue"
LOGIN_ART = "root/agetty/etc/g0wm-login"
MOODS = {"sleep": ("darkgray", "darkgray", "lightcyan", "zzz"),
         "awake": ("brown", "lightgray", "brown", "woof?"),
         "grumpy": ("red", "lightgray", "lightred", "grrr!")}
# the background of a half block: only the 8 dark ones exist
BACKGROUND = {"brown": 43, "red": 41, "lightgray": 47}


def login_dog(t, mood):
    g, dog, wc, word = MOODS[mood]
    name = {"g": g, "dog": dog}
    lines = []
    for cells in half_blocks(t):
        row, cur = "", None
        for a, b in cells:
            top, bot = name.get(a), name.get(b)
            if not top and not bot:
                row += " "
                continue
            c, ch, under = (top, "▀", None) if top == bot or not bot else \
                (bot, "▄", None) if not top else (top, "▀", bot)
            if top == bot:
                ch = "█"
            if c != cur:
                row += "\\e{%s}" % c
                cur = c
            row += f"\\e[{BACKGROUND[under]}m{ch}\\e[49m" if under else ch
        lines.append(row + "\\e{reset}")
    # the word under the middle of what is drawn, not of the HALF columns
    used = [x for cells in half_blocks(t) for x, (a, b) in enumerate(cells) if a or b]
    pad = max(0, min(HALF - len(word), round((min(used) + max(used) + 1 - len(word)) / 2)))
    lines.append(" " * pad + "\\e{%s}%s\\e{reset}" % (wc, word) + " " * (HALF - pad - len(word)))
    return lines


def login(t):
    for mood in ("awake", "grumpy"):
        t.write(os.path.join(t.REPO, LOGIN_ART, mood), "\n".join(login_dog(t, mood)) + "\n")
    p = os.path.join(t.REPO, ISSUE)
    lines = t.read(p).split("\n")
    i = next(k for k, l in enumerate(lines) if l.strip())
    j = next(k for k in range(i, len(lines)) if not lines[k].strip())
    t.write(p, "\n".join(lines[:i] + login_dog(t, "sleep") + lines[j:]))


# The wallpapers: 3840 x 2160, g0wm scales them to cover the screen and crops the
# middle, so a 3:2 or 16:10 screen loses only the sides. The desk is HOVER; one
# thing is lit in each, the rest the greys around it.
W, H = 3840, 2160
WALLPAPERS = "home/g0wm/.config/g0wm/wallpapers"
FONT = "Geist Mono, monospace"


def svg(comment, body, bg):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">\n'
            f"  <!-- G0: written by script/g0wm-theme.py, do not edit. {comment} -->\n"
            f'  <rect width="{W}" height="{H}" fill="{bg}"/>\n{body}</svg>\n')


def at(t, size, colors, cx=W / 2, cy=H / 2, extra=""):
    return "  " + logo_svg(t, colors, cx - size / 2, cy - size / 2, size, extra) + "\n"


def wp_tone(t):
    colors = {"g": fill(t.SEL), "dog": fill(t.PRESS), "fur": fill(t.DESK), "prompt": fill(t.DESK)}
    body = at(t, 1900, colors)
    dog = logo_layers(t)["dog"]
    head = dog[dog.index("M", 1):]
    body = body.replace(f'd="{dog}"', f'd="{head}"')
    return svg("The logo, tone on tone, 88% of the screen height.",
               body, t.DESK)


def wp_portrait(t):
    return svg("The logo in its colors, 40% of the screen height.",
               at(t, 900, {"g": fill(t.ACCENT), "dog": fill(t.TAN), "fur": fill(t.DESK), "prompt": fill(t.DESK)}), t.DESK)


def wp_pack(t):
    # small marks one step above the desk and one lit, right of the middle, inside
    # what a 3:2 screen still shows: windows cover it most of the time
    sx = sy = 300
    cols, rows = W // sx, H // sy
    x0, y0 = (W - (cols - 1) * sx) / 2, (H - (rows - 1) * sy) / 2
    lit = (cols // 2 + 2, rows // 2 - 1)
    dim = {"g": fill(t.SEL), "dog": fill(t.SEL), "fur": fill(t.DESK), "prompt": fill(t.DESK)}
    on = {"g": fill(t.ACCENT), "dog": fill(t.TAN), "fur": fill(t.DESK), "prompt": fill(t.DESK)}
    size = 150
    body = (f'  <defs>\n    <g id="dim">{logo_svg(t, dim, 0, 0, size)}</g>\n'
            f'    <g id="on">{logo_svg(t, on, 0, 0, size)}</g>\n  </defs>\n')
    body += "".join(f'  <use href="#{"on" if (c, r) == lit else "dim"}" x="{x0 + c * sx - size / 2:g}" '
                    f'y="{y0 + r * sy - size / 2:g}"/>\n' for r in range(rows) for c in range(cols))
    return svg("Small marks, one of them lit.", body, t.DESK)


def wp_line(t):
    # the outlines only, the >_ filled
    line = f'fill="none" stroke="{t.MUTE}" stroke-width="1.1"'
    return svg("The logo as a line drawing, the prompt filled.",
               at(t, 1300, {"g": line, "dog": line, "fur": line, "prompt": fill(t.ACCENT)}), t.DESK)


def deny_rules(t):
    """The deny rules of the AppArmor abstractions, the short ones."""
    d = os.path.join(t.REPO, "root/apparmor/etc/apparmor.d/abstractions/dotfiles")
    rules = []
    for name in ("secrets", "persist", "setuid", "no-av", "root-secrets"):
        p = os.path.join(d, name)
        if os.path.exists(p):
            for line in t.read(p).splitlines():
                line = line.strip()
                if re.match(r"(audit )?deny ", line) and len(line) <= 56 and line not in rules:
                    rules.append(line)
    return rules or ["audit deny @{HOME}/.ssh/{,**} mrwkl,"]


def wp_rules(t):
    # the field is the deny rules of the sandbox: inside the G they turn amber,
    # inside the dog light grey, the strokes stay empty. librsvg drops a mask on
    # text, so clip paths and covers instead
    rules = deny_rules(t)
    size, step, chars = 30, 38, 214
    lines = []
    for r in range(H // step + 1):
        line, k = "", r * 3
        while len(line) < chars + 40:
            line += rules[k % len(rules)] + "  "
            k += 1
        lines.append(html.escape(line[(r * 17) % 40:][:chars]))

    def field(color, weight):
        return (f'  <g fill="{color}" font-family="{FONT}" font-size="{size}" font-weight="{weight}" xml:space="preserve">\n'
                + "".join(f'    <text x="0" y="{30 + r * step}">{s}</text>\n' for r, s in enumerate(lines)) + "  </g>\n")
    big = 1500
    x0, y0 = W / 2 - big / 2, H / 2 - big / 2
    tr = f'translate({x0:g} {y0:g}) scale({big / 512:g})'

    def shape(k, c):
        return f'  <path fill-rule="evenodd" fill="{c}" transform="{tr}" d="{logo_layers(t)[k]}"/>\n'

    def clip(n, k):
        return f'  <clipPath id="{n}"><path clip-rule="evenodd" transform="{tr}" d="{logo_layers(t)[k]}"/></clipPath>\n'
    body = (f"  <defs>\n{clip('cg', 'g')}{clip('cd', 'dog')}  </defs>\n" + field(t.SEL, 400)
            + shape("g", t.DESK) + f'  <g clip-path="url(#cg)">\n{field(t.ACCENT, 600)}  </g>\n'
            + shape("dog", t.DESK) + f'  <g clip-path="url(#cd)">\n{field(t.SOFT, 600)}  </g>\n'
            + shape("fur", t.DESK) + shape("prompt", t.DESK))
    return svg("The deny rules of the AppArmor abstractions, the logo drawn in them.", body, t.DESK)


def wallpaper(t):
    for name, make in (("tone", wp_tone), ("portrait", wp_portrait), ("pack", wp_pack), ("line", wp_line),
                       ("rules", wp_rules)):
        p = os.path.join(t.REPO, WALLPAPERS, f"{name}.svg")
        if t.CHECK and not os.path.exists(p):
            t.STALE.append(os.path.relpath(p, t.REPO))
            continue
        t.write(p, make(t))


def run(t):
    config_sh(t)
    plymouth(t)
    icons(t)
    icon_family(t)
    librewolf_logo(t)
    vesktop_logo(t)
    fastfetch_logo(t)
    login(t)
    wallpaper(t)
