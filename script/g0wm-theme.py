#!/usr/bin/env python3
"""Generate colors.css, the GTK base.css files and the Kvantum theme from the palette.

GTK: Adwaita's greys are mapped onto the palette and :backdrop is dropped.
Kvantum: frame pieces are s x s, scaled to half of frame.expansion.
"""

import colorsys
import os
import re
import subprocess

BG = "#0a0a0a"
SIDE = BG
POPUP = "#0e0e0e"
CTRL = BG
CTRL_OFF = BG
HOVER = "#121212"
PRESS = "#1c1c1c"
SEL = PRESS
TROUGH = "#2a2a2a"
SEP = "#1a1a1a"
LINE = "#2a2a2a"
FG = "#e9e9e9"
DIM = "#8a8a8a"
MUTE = "#555555"
ACCENT = "#e0a86a"
ON_ACCENT = "#0a0a0a"
GREEN = "#7fa88a"
RED = "#d8625e"
LINK = "#8ab0c6"
VISITED = "#c59dc8"

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
THEME = os.path.join(REPO, "home/gtk/.local/share/themes/G0wm")
KVANTUM = os.path.join(REPO, "home/qt/.config/Kvantum/G0wm")

PARTS = ("topleft", "top", "topright", "left", "", "right", "bottomleft", "bottom", "bottomright")


class Canvas:
    def __init__(self):
        self.out = []
        self.x = 0
        self.y = 0
        self.row = 0
        self.width = 0

    def place(self, w, h):
        if self.x + w > 600:
            self.x = 0
            self.y += self.row + 4
            self.row = 0
        x, y = self.x, self.y
        self.x += w + 4
        self.row = max(self.row, h)
        self.width = max(self.width, self.x)
        return x, y

    def add(self, s):
        self.out.append(s)

    def svg(self):
        h = self.y + self.row
        return (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.width}" height="{h}" '
            f'viewBox="0 0 {self.width} {h}">\n' + "\n".join(self.out) + "\n</svg>\n"
        )


C = Canvas()


def paint(color):
    if color is None:
        return 'fill="none"'
    if len(color) == 9:
        return f'fill="{color[:7]}" fill-opacity="{int(color[7:], 16) / 255:.3f}"'
    return f'fill="{color}"'


def rect(id_, x, y, w, h, color, rx=0):
    r = f' rx="{rx}"' if rx else ""
    return f'<rect id="{id_}" x="{x}" y="{y}" width="{w}" height="{h}"{r} {paint(color)}/>'


def corner(cx, cy, dx, dy, r, bw, fill, line):
    """quarter circle around (cx, cy), towards (dx, dy)"""
    out = []
    sweep = 0 if dx * dy > 0 else 1
    if line and bw:
        ri = r - bw
        out.append(
            f'<path d="M{cx},{cy + dy * r} A{r},{r} 0 0 {sweep} {cx + dx * r},{cy} '
            f'L{cx + dx * ri},{cy} A{ri},{ri} 0 0 {1 - sweep} {cx},{cy + dy * ri} Z" {paint(line)}/>'
        )
        r = ri
    if fill:
        out.append(
            f'<path d="M{cx},{cy} L{cx},{cy + dy * r} A{r},{r} 0 0 {sweep} {cx + dx * r},{cy} Z" {paint(fill)}/>'
        )
    return out


def frame(name, s=8, fill=CTRL, line=LINE, bw=1, round_=(1, 1, 1, 1), extra=None, center=True):
    """the nine pieces of <name>, round_ is (topleft, topright, bottomleft, bottomright)"""
    x0, y0 = C.place(3 * s, 3 * s)
    g = []
    corners = {"topleft": (0, -1, -1), "topright": (1, 1, -1), "bottomleft": (2, -1, 1), "bottomright": (3, 1, 1)}
    for i, part in enumerate(PARTS):
        px, py = x0 + (i % 3) * s, y0 + (i // 3) * s
        id_ = f"{name}-{part}" if part else name
        if not part and not center:
            continue
        shapes = []
        if part in corners:
            k, dx, dy = corners[part]
            cx = px + (s if dx < 0 else 0)
            cy = py + (s if dy < 0 else 0)
            if round_[k]:
                shapes += corner(cx, cy, dx, dy, s, bw, fill, line)
            else:
                if fill:
                    shapes.append(rect("", px, py, s, s, fill))
                if line and bw:
                    ex = px if dx < 0 else px + s - bw
                    ey = py if dy < 0 else py + s - bw
                    shapes.append(rect("", px, ey, s, bw, line))
                    shapes.append(rect("", ex, py, bw, s, line))
        else:
            if fill:
                shapes.append(rect("", px, py, s, s, fill))
            if line and bw:
                if part == "top":
                    shapes.append(rect("", px, py, s, bw, line))
                elif part == "bottom":
                    shapes.append(rect("", px, py + s - bw, s, bw, line))
                elif part == "left":
                    shapes.append(rect("", px, py, bw, s, line))
                elif part == "right":
                    shapes.append(rect("", px + s - bw, py, bw, s, line))
        if extra:
            shapes += extra(part, px, py, s)
        # keeps the piece bounds when partly empty
        shapes.insert(0, rect("", px, py, s, s, "#00000000"))
        g.append(f'<g id="{id_}">' + "".join(x.replace(' id=""', "") for x in shapes) + "</g>")
    C.add("\n".join(g))


def marker(name):
    x, y = C.place(2, 2)
    C.add(rect(name, x, y, 2, 2, "#00000000"))


def blank(name, w=8, h=8):
    """so Kvantum does not fall back to its default element"""
    x, y = C.place(w, h)
    C.add(rect(name, x, y, w, h, "#00000000"))


def icon(name, body, size=16):
    x, y = C.place(size, size)
    C.add(f'<g id="{name}">' + rect("", x, y, size, size, "#00000000").replace(' id=""', "") + body(x, y) + "</g>")


def stroke(d, color, w=1.5):
    return f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>'


STATES = {"normal": DIM, "focused": FG, "pressed": FG, "toggled": FG, "disabled": MUTE}

CHEVRONS = {
    "up": "M{a},{c} L8,{b} L{d},{c}",
    "down": "M{a},{b} L8,{c} L{d},{b}",
    "left": "M{c},{a} L{b},8 L{c},{d}",
    "right": "M{b},{a} L{c},8 L{b},{d}",
}


def chevron(direction, color, x, y):
    d = CHEVRONS[direction].format(a=4, b=6, c=10, d=12)
    d = " ".join(_shift(tok, x, y) for tok in d.split(" "))
    return stroke(d, color)


def _shift(tok, x, y):
    cmd = tok[0] if tok[0].isalpha() else ""
    px, py = tok[len(cmd):].split(",")
    return f"{cmd}{float(px) + x:g},{float(py) + y:g}"


def plus(color, x, y, minus=False):
    out = stroke(f"M{x + 4},{y + 8} L{x + 12},{y + 8}", color)
    if not minus:
        out += stroke(f"M{x + 8},{y + 4} L{x + 8},{y + 12}", color)
    return out


def cross(color, x, y):
    return stroke(f"M{x + 5},{y + 5} L{x + 11},{y + 11} M{x + 11},{y + 5} L{x + 5},{y + 11}", color)


def kvantum_svg():
    # buttons
    for state, fill, line in (
        ("normal", None, LINE),
        ("focused", None, FG),
        ("pressed", PRESS, LINE),
        ("toggled", PRESS, LINE),
        ("disabled", None, SEP),
    ):
        frame(f"button-{state}", fill=fill, line=line)
    marker("expand-button-normal")
    blank("button-default-indicator")

    # tool buttons
    for state, fill in (("normal", None), ("focused", None), ("pressed", PRESS), ("toggled", PRESS)):
        frame(f"tbutton-{state}", fill=fill, line=None)
    marker("expand-tbutton-normal")

    # entries
    for state, line in (("normal", LINE), ("focused", FG), ("disabled", SEP)):
        frame(f"lineedit-{state}", fill=None, line=line)
    marker("expand-lineedit-normal")
    for state, line in (("normal", LINE), ("focused", FG), ("pressed", FG)):
        frame(f"spin-{state}", fill=None, line=line)
    marker("expand-spin-normal")

    # frames
    for state, line in (("normal", LINE), ("focused", LINE)):
        frame(f"common-{state}", s=3, fill=None, line=line)
    frame("group-normal", s=4, fill=None, line=LINE)
    frame("dock-normal", s=4, fill=None, line=SEP)
    frame("focus", s=8, fill=None, line="#e9e9e94d", center=False)
    marker("expand-focus")

    # views
    frame("itemview-normal", s=3, fill=None, line=None)
    for state, fill in (("focused", HOVER), ("pressed", SEL), ("toggled", SEL)):
        frame(f"itemview-{state}", s=3, fill=fill, line=None)

    # tabs
    for state, fill in (("normal", None), ("focused", None), ("toggled", PRESS)):
        frame(f"tab-{state}", s=8, fill=fill, line=None)
    marker("expand-tab-normal")
    frame("tabframe-normal", s=4, fill=None, line=SEP)
    frame("tabBarFrame-normal", s=4, fill=None, line=None)
    blank("tab-tear")
    for state, color in (("normal", DIM), ("focused", FG), ("pressed", RED), ("disabled", MUTE)):
        icon(f"tab-close-{state}", lambda x, y, c=color: cross(c, x, y))

    # headers
    def baseline(part, x, y, s):
        if part.startswith("bottom"):
            return [rect("", x, y + s - 1, s, 1, SEP)]
        return []

    for state, fill in (("normal", BG), ("focused", HOVER), ("pressed", PRESS), ("toggled", BG)):
        frame(f"header-{state}", s=3, fill=fill, line=None, round_=(0, 0, 0, 0), extra=baseline)
    x, y = C.place(3, 16)
    C.add(f'<g id="header-separator">{rect("", x, y, 3, 16, "#00000000")}{rect("", x + 1, y + 3, 1, 10, LINE)}</g>'.replace(' id=""', ""))

    # menus, tool bars, tool tips
    frame("menu-normal", s=6, fill=POPUP, line=LINE)
    frame("menuitem-normal", s=4, fill=None, line=None)
    for state in ("focused", "pressed", "toggled"):
        frame(f"menuitem-{state}", s=4, fill=PRESS, line=None)
    for state in ("normal", "focused"):
        x, y = C.place(16, 4)
        C.add(f'<g id="menuitem-tearoff-{state}">' + rect("", x, y + 1, 16, 2, LINE).replace(' id=""', "") + "</g>")

    frame("menubar-normal", s=2, fill=BG, line=None, round_=(0, 0, 0, 0), extra=baseline)
    frame("menubaritem-normal", s=4, fill=None, line=None)
    frame("menubaritem-focused", s=4, fill=None, line=None)
    for state in ("pressed", "toggled"):
        frame(f"menubaritem-{state}", s=4, fill=PRESS, line=None)
    frame("toolbar-normal", s=2, fill=BG, line=None, round_=(0, 0, 0, 0))
    icon("toolbar-handle", lambda x, y: "".join(
        f'<circle cx="{x + 8}" cy="{y + 4 + 4 * i}" r="1" fill="{MUTE}"/>' for i in range(3)))
    icon("toolbar-separator", lambda x, y: rect("", x + 7.5, y + 2, 1, 12, LINE).replace(' id=""', ""))
    frame("tooltip-normal", s=6, fill=POPUP, line=LINE)
    frame("titlebar-normal", s=2, fill=BG, line=None, round_=(0, 0, 0, 0))
    frame("titlebar-focused", s=2, fill=BG, line=None, round_=(0, 0, 0, 0))
    frame("window-normal", s=2, fill=BG, line=None, round_=(0, 0, 0, 0))

    # progress bars and sliders
    frame("progress-normal", s=8, fill=TROUGH, line=None)
    marker("expand-progress-normal")
    frame("progress-pattern-normal", s=8, fill=ACCENT, line=None)
    frame("progress-pattern-disabled", s=8, fill=MUTE, line=None)
    marker("expand-progress-pattern-normal")
    frame("slider-normal", s=3, fill=TROUGH, line=None)
    frame("slider-toggled", s=3, fill=ACCENT, line=None)
    marker("expand-slider-normal")
    for state, fill in (("normal", FG), ("focused", "#ffffff"), ("pressed", "#ffffff"), ("disabled", MUTE)):
        icon(f"slidercursor-{state}", lambda x, y, f=fill: f'<circle cx="{x + 8}" cy="{y + 8}" r="7" fill="{f}"/>')
    x, y = C.place(1, 4)
    C.add(rect("slider-tick-normal", x, y, 1, 4, MUTE))
    for glow in ("slider-topglow-normal", "slider-bottomglow-normal"):
        blank(glow)

    # scroll bars
    for state, fill in (("normal", "#8a8a8a73"), ("focused", DIM), ("pressed", FG)):
        frame(f"scrollbarslider-{state}", s=4, fill=fill, line=None)
    marker("expand-scrollbarslider-normal")
    for state in ("normal", "focused", "pressed"):
        blank(f"grip-{state}")
        blank(f"splitter-grip-{state}")
    # no shadows
    for kind in ("menu", "tooltip"):
        for part in PARTS[:4] + PARTS[5:]:
            blank(f"{kind}-shadow-{part}")
        for side in ("top", "bottom", "left", "right"):
            blank(f"{kind}-shadow-hint-{side}")
    blank("sizegrip-normal")
    blank("resize-grip-normal")

    # checks
    def box(radio, fill, line, mark=None):
        def body(x, y):
            if radio:
                out = f'<circle cx="{x + 8}" cy="{y + 8}" r="7" {paint(line)}/>'
                out += f'<circle cx="{x + 8}" cy="{y + 8}" r="6" {paint(fill)}/>'
            else:
                out = rect("", x + 1, y + 1, 14, 14, line, rx=4).replace(' id=""', "")
                out += rect("", x + 2, y + 2, 12, 12, fill, rx=3).replace(' id=""', "")
            if mark == "check":
                out += stroke(f"M{x + 4.5},{y + 8.5} L{x + 7},{y + 11} L{x + 11.5},{y + 5.5}", ON_ACCENT, 2)
            elif mark == "dot":
                out += f'<circle cx="{x + 8}" cy="{y + 8}" r="3" fill="{ON_ACCENT}"/>'
            elif mark == "dash":
                out += stroke(f"M{x + 5},{y + 8} L{x + 11},{y + 8}", ON_ACCENT, 2)
            return out
        return body

    for kind, radio, on in (("checkbox", False, "check"), ("radio", True, "dot")):
        icon(f"{kind}-normal", box(radio, BG, LINE))
        icon(f"{kind}-focused", box(radio, BG, FG))
        icon(f"{kind}-pressed", box(radio, PRESS, FG))
        icon(f"{kind}-disabled", box(radio, BG, SEP))
        icon(f"{kind}-checked-normal", box(radio, ACCENT, ACCENT, on))
        icon(f"{kind}-checked-focused", box(radio, ACCENT, ACCENT, on))
        icon(f"{kind}-checked-pressed", box(radio, ACCENT, ACCENT, on))
        icon(f"{kind}-checked-disabled", box(radio, MUTE, MUTE, on))
        icon(f"{kind}-tristate-normal", box(radio, ACCENT, ACCENT, "dash"))
        icon(f"{kind}-tristate-focused", box(radio, ACCENT, ACCENT, "dash"))
        icon(f"{kind}-tristate-pressed", box(radio, ACCENT, ACCENT, "dash"))
        icon(f"{kind}-tristate-disabled", box(radio, MUTE, MUTE, "dash"))

    # indicators
    for state, color in STATES.items():
        for direction in ("up", "down", "left", "right"):
            icon(f"arrow-{direction}-{state}", lambda x, y, d=direction, c=color: chevron(d, c, x, y))
        icon(f"arrow-plus-{state}", lambda x, y, c=color: plus(c, x, y))
        icon(f"arrow-minus-{state}", lambda x, y, c=color: plus(c, x, y, True))
        icon(f"spin-plus-{state}", lambda x, y, c=color: plus(c, x, y))
        icon(f"spin-minus-{state}", lambda x, y, c=color: plus(c, x, y, True))
        icon(f"spin-up-{state}", lambda x, y, c=color: chevron("up", c, x, y))
        icon(f"spin-down-{state}", lambda x, y, c=color: chevron("down", c, x, y))
        icon(f"tree-plus-{state}", lambda x, y, c=color: chevron("right", c, x, y))
        icon(f"tree-minus-{state}", lambda x, y, c=color: chevron("down", c, x, y))
        icon(f"carrow-{state}", lambda x, y, c=color: chevron("down", c, x, y))

    # MDI buttons, dials
    glyphs = {
        "close": lambda c, x, y: cross(c, x, y),
        "minimize": lambda c, x, y: stroke(f"M{x + 4},{y + 11} L{x + 12},{y + 11}", c),
        "maximize": lambda c, x, y: f'<rect x="{x + 4.5}" y="{y + 4.5}" width="7" height="7" rx="1.5" fill="none" stroke="{c}" stroke-width="1.5"/>',
        "restore": lambda c, x, y: f'<rect x="{x + 4.5}" y="{y + 6.5}" width="5" height="5" rx="1" fill="none" stroke="{c}" stroke-width="1.5"/>'
        + stroke(f"M{x + 7},{y + 4.5} L{x + 11.5},{y + 4.5} L{x + 11.5},{y + 9}", c),
        "shade": lambda c, x, y: chevron("up", c, x, y),
    }
    for g, draw in glyphs.items():
        for state, color in (("normal", DIM), ("focused", FG), ("pressed", FG), ("disabled", MUTE)):
            icon(f"mdi-{g}-{state}", lambda x, y, d=draw, c=color: d(c, x, y))
    icon("mdi-menu-normal", lambda x, y: chevron("down", DIM, x, y))
    icon("dial", lambda x, y: f'<circle cx="{x + 16}" cy="{y + 16}" r="15" fill="none" stroke="{LINE}" stroke-width="1"/>', 32)
    icon("dial-handle", lambda x, y: f'<circle cx="{x + 8}" cy="{y + 8}" r="4" fill="{ACCENT}"/>')
    icon("dial-notches", lambda x, y: f'<circle cx="{x + 16}" cy="{y + 16}" r="15.5" fill="none" stroke="{MUTE}" stroke-width="1" stroke-dasharray="1 5"/>', 32)



# GTK

def hexrgb(c):
    return tuple(int(c[i:i + 2], 16) for i in (1, 3, 5))


def rgbhex(r, g, b):
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(v))) for v in (r, g, b))


def lighten(color, d):
    h, l, s = colorsys.rgb_to_hls(*(v / 255 for v in hexrgb(color)))
    r, g, b = colorsys.hls_to_rgb(h, max(0.0, min(1.0, l + d)), s)
    return rgbhex(r * 255, g * 255, b * 255)


# Adwaita's greys by role
GREYS = {
    0x00: "#000000",
    0x02: SEP,
    0x07: LINE,
    0x11: LINE,
    0x14: LINE,
    0x1a: LINE,
    0x1b: LINE,
    0x1e: BG,
    0x20: SEP,
    0x22: SEP,
    0x23: PRESS,
    0x25: PRESS,
    0x26: PRESS,
    0x28: TROUGH,
    0x2a: PRESS,
    0x2b: PRESS,
    0x2d: BG,
    0x2e: BG,
    0x2f: POPUP,
    0x30: BG,
    0x31: SIDE,
    0x32: CTRL_OFF,
    0x35: BG,
    0x36: POPUP,
    0x37: CTRL,
    0x3a: CTRL,
    0x3c: HOVER,
    0x3f: HOVER,
    0x40: HOVER,
    0x42: CTRL,
    0x5b: "#48484a",
    0x8a: DIM,
    0x8e: DIM,
    0x91: MUTE,
    0xee: FG,
    0xf7: FG,
    0xff: "#ffffff",
}

RAMP = [(0x40, 0x1e), (0x5b, 0x48), (0x80, 0x6a), (0xa4, 0x80), (0xd6, 0xc8), (0xee, 0xe9), (0xff, 0xff)]


def grey(v):
    near = min(GREYS, key=lambda k: abs(k - v))
    if abs(near - v) <= 2:
        return GREYS[near]
    if v < RAMP[0][0]:
        return GREYS[min((k for k in GREYS if k < 0x45), key=lambda k: abs(k - v))]
    for (a, x), (b, y) in zip(RAMP, RAMP[1:]):
        if a <= v <= b:
            w = x + (y - x) * (v - a) / (b - a)
            return rgbhex(w, w, w)
    return rgbhex(v, v, v)


def recolor(c):
    r, g, b = hexrgb(c)
    if max(r, g, b) - min(r, g, b) <= 12:
        return grey(round((r + g + b) / 3))
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    h *= 360
    if s < 0.2:
        return grey(round((r + g + b) / 3))
    if 180 <= h < 260:  # Adwaita's blue
        if l >= 0.8:
            return FG
        if l >= 0.5:
            return LINK
        if l < 0.2:
            return LINE
        return lighten(SEL, (l - 0.35) * 0.3)
    if h < 15 or h >= 340:
        return lighten(RED, l - 0.4)
    if h < 70:
        return lighten(ACCENT, l - 0.48)
    if h < 180:
        return lighten(GREEN, l - 0.36)
    return lighten(VISITED, l - 0.5)


def recolor_css(css):
    css = re.sub(r"#[0-9a-fA-F]{6}\b", lambda m: recolor(m.group(0).lower()), css)

    def rgba(m):
        r, g, b = (int(v) for v in m.group(2, 3, 4))
        if (r, g, b) in ((0, 0, 0), (255, 255, 255)):
            return m.group(0)
        c = hexrgb(recolor(rgbhex(r, g, b)))
        alpha = f", {m.group(5)}" if m.group(5) else ""
        return f"{m.group(1)}({c[0]}, {c[1]}, {c[2]}{alpha})"

    return re.sub(r"\b(rgba?)\(\s*(\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\s*\)", rgba, css, flags=re.I)


def split_top(text, sep):
    out, depth, cur = [], 0, ""
    for ch in text:
        depth += ch == "("
        depth -= ch == ")"
        if ch == sep and depth == 0:
            out.append(cur)
            cur = ""
        else:
            cur += ch
    return out + [cur]


def drop_backdrop(css):
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    out, i = [], 0
    while i < len(css):
        brace = css.find("{", i)
        semi = css.find(";", i)
        if brace < 0:
            out.append(css[i:])
            break
        if 0 <= semi < brace:
            out.append(css[i:semi + 1])
            i = semi + 1
            continue
        depth, j = 1, brace + 1
        while depth:
            depth += {"{": 1, "}": -1}.get(css[j], 0)
            j += 1
        prelude, body = css[i:brace].strip(), css[brace + 1:j - 1]
        i = j
        if prelude.startswith("@media"):
            out.append(f"{prelude} {{ {drop_backdrop(body)} }}")
        elif prelude.startswith("@"):
            out.append(f"{prelude} {{{body}}}")
        else:
            sels = [x.strip() for x in split_top(prelude, ",") if ":backdrop" not in x]
            if sels:
                out.append(f"{', '.join(sels)} {{{body}}}")
    return "\n".join(x.strip() for x in out if x.strip()) + "\n"


def gtk_base(lib, resource, assets, out):
    css = subprocess.run(["gresource", "extract", lib, resource], check=True,
                         capture_output=True, text=True).stdout
    css = recolor_css(drop_backdrop(css))
    css = css.replace('url("assets/', f'url("resource://{assets}/')
    head = f"/* generated by script/g0wm-theme.py from {resource} */\n\n"
    with open(out, "w", encoding="utf-8") as f:
        f.write(head + css)


def colors_css():
    names = {
        "bg": BG, "side": SIDE, "popup": POPUP, "ctrl": CTRL, "ctrl_off": CTRL_OFF,
        "hover": HOVER, "press": PRESS, "sel": SEL, "trough": TROUGH, "sep": SEP,
        "line": LINE, "fg": FG, "dim": DIM, "mute": MUTE, "accent": ACCENT,
        "on_accent": ON_ACCENT, "green": GREEN, "red": RED, "link": LINK,
    }
    out = ["/* generated by script/g0wm-theme.py */", ""]
    out += [f"@define-color g0_{k} {v};" for k, v in names.items()]
    aliases = """
theme_bg_color bg; theme_fg_color fg; theme_base_color bg; theme_text_color fg
theme_selected_bg_color sel; theme_selected_fg_color fg
insensitive_bg_color ctrl_off; insensitive_fg_color mute; insensitive_base_color bg
theme_unfocused_bg_color bg; theme_unfocused_fg_color fg; theme_unfocused_base_color bg
theme_unfocused_text_color fg; theme_unfocused_selected_bg_color sel
theme_unfocused_selected_fg_color fg; unfocused_insensitive_color mute
borders line; unfocused_borders line; warning_color accent; error_color red
success_color green; content_view_bg bg; text_view_bg bg
accent_bg_color accent; accent_fg_color on_accent; accent_color accent
destructive_bg_color red; destructive_fg_color on_accent; destructive_color red
success_bg_color green; success_fg_color on_accent; warning_bg_color accent
warning_fg_color on_accent; error_bg_color red; error_fg_color on_accent
window_bg_color bg; window_fg_color fg; view_bg_color bg; view_fg_color fg
headerbar_bg_color bg; headerbar_fg_color fg; headerbar_border_color sep
headerbar_backdrop_color bg; headerbar_shade_color sep; headerbar_darker_shade_color sep
sidebar_bg_color side; sidebar_fg_color fg; sidebar_backdrop_color side
sidebar_border_color sep; sidebar_shade_color sep
secondary_sidebar_bg_color bg; secondary_sidebar_fg_color fg
secondary_sidebar_backdrop_color bg; secondary_sidebar_border_color sep
secondary_sidebar_shade_color sep; card_bg_color ctrl; card_fg_color fg
card_shade_color sep; dialog_bg_color popup; dialog_fg_color fg
popover_bg_color popup; popover_fg_color fg; popover_shade_color sep
thumbnail_bg_color ctrl; thumbnail_fg_color fg; shade_color sep
scrollbar_outline_color bg"""
    out.append("")
    for pair in re.split(r"[;\n]", aliases):
        if pair.strip():
            name, value = pair.split()
            out.append(f"@define-color {name} @g0_{value};")
    with open(os.path.join(THEME, "colors.css"), "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")


def kvantum_colors():
    p = os.path.join(KVANTUM, "G0wm.kvconfig")
    with open(p, encoding="utf-8") as f:
        text = f.read()
    colors = f"""[GeneralColors]
window.color={BG}
base.color={BG}
alt.base.color={SIDE}
button.color={CTRL}
light.color={LINE}
mid.light.color={PRESS}
dark.color=#000000
mid.color={HOVER}
shadow.color=#000000
highlight.color={ACCENT}
inactive.highlight.color={ACCENT}
text.color={FG}
window.text.color={FG}
button.text.color={FG}
disabled.text.color={MUTE}
tooltip.base.color={POPUP}
tooltip.text.color={FG}
highlight.text.color={ON_ACCENT}
link.color={LINK}
link.visited.color={VISITED}
progress.indicator.text.color={FG}

"""
    text = re.sub(r"\[GeneralColors\]\n.*?\n\n", lambda m: colors, text, count=1, flags=re.S)
    with open(p, "w", encoding="utf-8") as f:
        f.write(text)


def main():
    colors_css()
    gtk_base("/usr/lib/libgtk-3.so.0", "/org/gtk/libgtk/theme/Adwaita/gtk-contained-dark.css",
             "/org/gtk/libgtk/theme/Adwaita/assets", os.path.join(THEME, "gtk-3.0/base.css"))
    gtk_base("/usr/lib/libgtk-4.so.1", "/org/gtk/libgtk/theme/Default/Default-dark.css",
             "/org/gtk/libgtk/theme/Default/assets", os.path.join(THEME, "gtk-4.0/base.css"))
    kvantum_svg()
    with open(os.path.join(KVANTUM, "G0wm.svg"), "w", encoding="utf-8") as f:
        f.write(C.svg())
    kvantum_colors()


if __name__ == "__main__":
    main()
