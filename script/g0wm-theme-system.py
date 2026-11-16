#!/usr/bin/env python3
"""The palette outside the session: the console and the cursors (script/config.sh),
GRUB (GRUB_COLORS, put in its theme by script/boot.sh), plymouth and the
wallpapers of g0wm (the rules one is drawn with the deny rules of the AppArmor
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


def fastfetch_logo(t):
    """The logo in half blocks for fastfetch, 38 columns: each cell is the g, the dog
    or empty (the strokes and the gaps)."""
    n = 38
    cov = {k: coverage(t, k, n, 8) for k in LAYERS}

    def cell(x, y):
        if cov["fur"][y][x] + cov["prompt"][y][x] > 0.22 or cov["g"][y][x] < 0.5:
            return None
        return t.TAN if cov["dog"][y][x] >= 0.5 else t.ACCENT

    def fg(c):
        return "\\u001b[38;2;" + ";".join(map(str, t.hexrgb(c))) + "m"

    def bg(c):
        return "\\u001b[48;2;" + ";".join(map(str, t.hexrgb(c))) + "m"
    rows = []
    for y in range(0, n, 2):
        row, cur = "", None

        def put(color, ch):
            nonlocal row, cur
            if color != cur:
                row += fg(color)
                cur = color
            row += ch
        for x in range(n):
            top, bot = cell(x, y), cell(x, y + 1)
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
    while rows and not rows[0].replace("\\u001b[0m", "").strip():
        rows.pop(0)
    while rows and not rows[-1].replace("\\u001b[0m", "").strip():
        rows.pop()
    p = t.FASTFETCH
    text = t.read(p)
    logo = (f'    "logo": {{\n        "type": "data-raw",\n        "source": "{"\\n".join(rows)}",\n'
            f'        "width": {n},\n        "height": {len(rows)},\n'
            '        "padding": { "top": 2, "left": 2, "right": 4 }\n    },\n')
    text = t.sub(p, text, r'^    "logo": \{\n(?:.*\n)*?    \},\n', lambda m: logo)
    t.write(p, text)


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
    return svg("The logo, tone on tone, 88% of the screen height.",
               at(t, 1900, {"g": fill(t.SEL), "dog": fill(t.PRESS), "fur": fill(t.DESK), "prompt": fill(t.DESK)}), t.DESK)


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
    fastfetch_logo(t)
    wallpaper(t)
