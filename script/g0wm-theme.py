#!/usr/bin/env python3
"""Generate colors.css, the GTK base.css files, the Kvantum theme and the colors of
foot, fastfetch, fzf, LibreWolf, Vesktop, g0wm, its status bar, gtklock, tmux, lazygit, git, vim
and nvim from the palette.

GTK: Adwaita's greys are mapped onto the palette and :backdrop is dropped.
Kvantum: frame pieces are s x s, scaled to half of frame.expansion.

--check writes nothing: it lists the files whose colors are not the palette's
and exits 1. It skips the GTK base.css files, which follow the installed GTK.
"""

import colorsys
import glob
import importlib.util
import math
import os
import re
import subprocess
import sys

# OKLab, the space where equal numbers look equally light: the rules below are in it
def _lin(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _gamma(c):
    c = max(0.0, min(1.0, c))
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def oklab(c):
    r, g, b = (_lin(int(c[i:i + 2], 16)) for i in (1, 3, 5))
    l, m, s = (v ** (1 / 3) for v in (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b,
                                      0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b,
                                      0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b))
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


def oklch(lightness, chroma, hue):
    a, b = chroma * math.cos(math.radians(hue)), chroma * math.sin(math.radians(hue))
    l, m, s = ((lightness + x * a + y * b) ** 3 for x, y in ((0.3963377774, 0.2158037573),
                                                            (-0.1055613458, -0.0638541728),
                                                            (-0.0894841775, -1.2914855480)))
    rgb = (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
           -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
           -0.0041960771 * l - 0.7034186147 * m + 1.7076147010 * s)
    return "#" + "".join(f"{round(_gamma(v) * 255):02x}" for v in rgb)


def contrast(a, b):
    """WCAG contrast ratio: 4.5 for text, 3 for borders and focus."""
    def lum(c):
        r, g, b = (_lin(int(c[i:i + 2], 16)) for i in (1, 3, 5))
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    x, y = sorted((lum(a), lum(b)))
    return (y + 0.05) / (x + 0.05)


# Surfaces, one step of OKLab lightness (about 0.035) from each other
BG = "#0a0a0a"
POPUP = "#121212"
HOVER = "#191919"
SEL = "#222222"
PRESS = "#2a2a2a"
LINE = "#333333"
SIDE = BG
CTRL = BG
CTRL_OFF = BG
SEP = HOVER
TROUGH = LINE
# the bar of g0wm and the lock screen, the notifications and the runner float over it
BAR = BG
# the desktop under the windows: a step lighter than the bar and the titles, or they melt into it
DESK = HOVER

# Greys for text, all 4.5:1 on POPUP and BG but MUTE, which is only for what is
# disabled, scrollbars and borders
MUTE = "#555555"
FAINT = "#7d7d7d"
DIM = "#8a8a8a"
# the accent of the terminal apps (tmux, vim, nvim): grey, the amber is the desktop's
MONO = "#9d9d9d"
SOFT = "#b1b1b1"
FG = "#e9e9e9"

# Colors: the accent sets the lightness, the others share it with a lower chroma.
# Red is darker and stronger on purpose, it is the one for alarms.
ACCENT = "#e0a86a"
ON_ACCENT = BG
RED = "#d8625e"
HUE_CHROMA = 0.07
GREEN = oklch(oklab(ACCENT)[0], HUE_CHROMA, 153)
LINK = oklch(oklab(ACCENT)[0], HUE_CHROMA, 234)
VISITED = oklch(oklab(ACCENT)[0], HUE_CHROMA, 324)
# the dog of the logo: the accent a step darker, a little redder
TAN = oklch(oklab(ACCENT)[0] - 0.14, 0.09, 64)

# The terminal's 16 colors: the six hues at one lightness, the bright ones one
# step lighter; black and white from the greys. Yellow and green take the hues of
# the accent and of GREEN, so a warning in the terminal is the amber of the
# notifications and a success their green.
ANSI_HUES = {1: 22, 2: 153, 3: round(math.degrees(math.atan2(oklab(ACCENT)[2], oklab(ACCENT)[1])) % 360),
             4: 235, 5: 330, 6: 195}
ANSI = {"regular0": BG, "regular7": MONO, "bright0": FAINT, "bright7": "#ffffff"}
for n, h in ANSI_HUES.items():
    ANSI[f"regular{n}"] = oklch(0.72, HUE_CHROMA, h)
    ANSI[f"bright{n}"] = oklch(0.84, HUE_CHROMA, h)
# red keeps the exception here too: errors in the terminal are the desktop's red
ANSI["regular1"] = RED
ANSI["bright1"] = oklch(0.78, 0.12, ANSI_HUES[1])

# vim and nvim: their names, onto the greys above; only the diff tints are their own
EDITOR = {
    "BG": BG, "FG": FG, "ACCENT": MONO, "MUTED": SOFT, "NOISE": FAINT, "DIM": DIM,
    "SPLIT": SEP, "PMENU_BG": POPUP, "PMENU_FG": FG, "PMENU_SE": SOFT, "WILD_BG": LINE,
    "SBAR_BG": MUTE, "THUMB_BG": SOFT, "CURSOR_BG": HOVER, "STATUS_BG": SEP,
    "DIFF_ADD_BG": "#1a231a", "DIFF_CHG_BG": "#1a1a23", "DIFF_DEL_BG": "#231a1a",
}

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
THEME = os.path.join(REPO, "home/gtk/.local/share/themes/G0wm")
KVANTUM = os.path.join(REPO, "home/qt/.config/Kvantum/G0wm")
FOOT = os.path.join(REPO, "home/foot/.config/foot/foot.ini")
FASTFETCH = os.path.join(REPO, "home/fastfetch/.config/fastfetch/config.jsonc")
BASHRC = os.path.join(REPO, "home/bash/.bashrc_dotfile")
LIBREWOLF = os.path.join(REPO, "home/librewolf/.config/librewolf/librewolf")
VESKTOP = os.path.join(REPO, "home/vesktop/.config/vesktop/themes/g0wm.theme.css")
G0WM = os.path.join(REPO, "home/g0wm/.config/g0wm/config")
STATUS = os.path.join(REPO, "home/g0wm/.config/g0wm/status.conf")
GTKLOCK = os.path.join(REPO, "home/gtklock/.config/gtklock/style.css")
TMUX = os.path.join(REPO, "home/tmux/.config/tmux/tmux.conf")
LAZYGIT = os.path.join(REPO, "home/lazygit/.config/lazygit/config.yml")
GIT = os.path.join(REPO, "home/git/.config/git/config")
NVIM = os.path.join(REPO, "home/nvim/.config/nvim/colors/dot.lua")
VIM = os.path.join(REPO, "home/vim/.vim/colors/dot.vim")

CHECK = False
STALE = []


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def write(path, text):
    if not CHECK:
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
    elif read(path) != text:
        STALE.append(os.path.relpath(path, REPO))


def sub(path, text, pattern, repl, count=1):
    """re.sub on the lines of path, which must match count times."""
    text, n = re.subn(pattern, repl, text, flags=re.M)
    assert n == count, f"{pattern} matches {n} times in {path}, not {count}"
    return text

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
    write(out, head + css)


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
    write(os.path.join(THEME, "colors.css"), "\n".join(out) + "\n")


def kvantum_colors():
    p = os.path.join(KVANTUM, "G0wm.kvconfig")
    text = read(p)
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
    write(p, text)


def foot_colors():
    # color= is the one of [cursor]
    keys = {"background": BG, "foreground": FG, "color": f"{ON_ACCENT} {ACCENT}",
            "selection-foreground": ON_ACCENT, "selection-background": ACCENT,
            "urls": LINK, "jump-labels": f"{ON_ACCENT} {ACCENT}", "search-box-match": f"{ON_ACCENT} {ACCENT}",
            "search-box-no-match": f"{ON_ACCENT} {RED}", **ANSI}
    text = read(FOOT)
    for k, v in keys.items():
        text, n = re.subn(rf"^{k}=.*$", f"{k}={v.replace('#', '')}", text, count=1, flags=re.M)
        assert n == 1, f"{k}= missing in {FOOT}"
    write(FOOT, text)


def fastfetch_colors():
    """The keys in amber, the three groups in the accent and the colors of private and
    public windows. The logo is written by g0wm-theme-system.py."""
    def esc(c):
        return "38;2;" + ";".join(str(v) for v in hexrgb(c))
    groups = {"system": ACCENT, "maint": VISITED, "hardware": LINK}
    text = read(FASTFETCH)
    for k, v in (("title", ACCENT), ("keys", ACCENT), ("separator", FAINT), ("output", FG)):
        text = sub(FASTFETCH, text, rf'^(\s+"{k}": )"[\d;]+"', lambda m, v=v: f'{m[1]}"{esc(v)}"')
    # 2.40 paints the rest of the bar white: the char brings its own color
    text = sub(FASTFETCH, text, r'^(\s+"charTotal": "\\u001b\[)[\d;]+(m)', lambda m: m[1] + esc(LINE) + m[2])
    pct = f'"green": "{esc(GREEN)}", "yellow": "{esc(ACCENT)}", "red": "{esc(RED)}"'
    text = sub(FASTFETCH, text, r'^(\s+"color": \{ )"green".*?( \}\s*)$', lambda m: m[1] + pct + m[2])
    text = sub(FASTFETCH, text, r'(\{user-name-colored\}\\u001b\[)[\d;]+(m@\\u001b\[)[\d;]+(m)',
               lambda m: m[1] + esc(FAINT) + m[2] + esc(ACCENT) + m[3])
    # the header of each group, then its keys, until the next header
    out, color = [], ACCENT
    for line in text.split("\n"):
        h = re.search(r'"format": "\\u001b\[([\d;]+)m[╭├╰]─+ ?(\w*)"', line)
        if h:
            color = groups.get(h[2], color)
            line = line.replace(h[1], esc(color), 1)
        line = re.sub(r'("keyColor": )"[\d;]+"', lambda m: f'{m[1]}"{esc(color)}"', line)
        out.append(line)
    text = "\n".join(out)
    text = sub(FASTFETCH, text, r"^(\s*// ).*fastfetch 2\.40 \(Debian 13\) keys$",
               lambda m: m[1] + "the colors and the logo are written by script/g0wm-theme.py; fastfetch 2.40 (Debian 13) keys")
    write(FASTFETCH, text)


# fzf: the same in bash, vim and nvim (which set FZF_DEFAULT_OPTS for the fzf they run)
FZF = [("fg", FG), ("bg", BG), ("hl", ACCENT), ("fg+", FG), ("bg+", SEL), ("hl+", ACCENT),
       ("border", SEP), ("header", DIM), ("gutter", BG), ("spinner", DIM), ("info", DIM),
       ("pointer", ACCENT), ("marker", ACCENT), ("prompt", DIM), ("query", FG), ("separator", SEP),
       ("scrollbar", MUTE), ("label", DIM), ("disabled", MUTE), ("preview-fg", FG), ("preview-bg", POPUP)]


def fzf_colors():
    c = FZF
    rows = "".join("        " + " ".join(f"{k}:{v}" for k, v in c[i:i + 6]) + "\n" for i in range(0, len(c), 6))
    text = read(BASHRC)
    text, n = re.subn(r"(    local _colors=\(\n).*?(    \)\n)", lambda m: m[1] + rows + m[2], text, count=1, flags=re.S)
    assert n == 1, f"_colors=( missing in {BASHRC}"
    write(BASHRC, text)


def librewolf_colors():
    # only the --g0-* lines and the color prefs
    css = {"bg": BG, "side": SIDE, "popup": POPUP, "hover": HOVER, "press": PRESS, "sel": SEL,
           "trough": TROUGH, "sep": SEP, "line": LINE, "fg": FG, "dim": DIM, "mute": MUTE,
           "accent": ACCENT, "on-accent": ON_ACCENT, "green": GREEN, "red": RED, "link": LINK,
           "visited": VISITED}
    # userContent.css has only some
    pages = {}
    for name, every in (("g0wm.css", True), ("userContent.css", False)):
        p = os.path.join(LIBREWOLF, "chrome", name)
        text = read(p)
        pages[name] = re.search(r"@-moz-document([^{]*)\{", text)[1].split()
        for k, v in css.items():
            text, n = re.subn(rf"^(\s*--g0-{k}: ).*;$", lambda m, v=v: f"{m[1]}{v};", text, flags=re.M)
            assert n or not every, f"--g0-{k} missing in {p}"
        write(p, text)
    assert pages["g0wm.css"] == pages["userContent.css"], "g0wm.css and userContent.css list other pages"

    prefs = {"ui.accentcolor": ACCENT, "ui.accentcolortext": ON_ACCENT, "ui.highlight": ACCENT,
             "ui.highlighttext": ON_ACCENT, "ui.selecteditem": SEL, "ui.selecteditemtext": FG,
             "browser.display.background_color.dark": BG, "browser.display.foreground_color.dark": FG,
             "reader.custom_colors.background": BG, "reader.custom_colors.foreground": FG,
             "reader.custom_colors.unvisited-links": LINK, "reader.custom_colors.visited-links": VISITED,
             "reader.custom_colors.selection-highlight": ACCENT, "ui.textSelectAttentionBackground": ACCENT,
             "ui.textSelectAttentionForeground": ON_ACCENT, "ui.textHighlightBackground": GREEN,
             "ui.textHighlightForeground": ON_ACCENT, "pdfjs.pageColorsBackground": BG,
             "pdfjs.pageColorsForeground": FG}
    p = os.path.join(LIBREWOLF, "librewolf.overrides.cfg")
    text = read(p)
    for k, v in prefs.items():
        text, n = re.subn(rf'^defaultPref\("{re.escape(k)}", ".*"\);$', f'defaultPref("{k}", "{v}");',
                          text, count=1, flags=re.M)
        assert n == 1, f"{k} missing in {p}"
    write(p, text)


def vesktop_colors():
    css = {"bg": BG, "side": SIDE, "popup": POPUP, "hover": HOVER, "press": PRESS, "sel": SEL,
           "trough": TROUGH, "sep": SEP, "line": LINE, "fg": FG, "dim": DIM, "mute": MUTE,
           "accent": ACCENT, "on-accent": ON_ACCENT, "green": GREEN, "red": RED, "link": LINK,
           "visited": VISITED}
    text = read(VESKTOP)
    for k, v in css.items():
        text, n = re.subn(rf"^(\s*--g0-{k}: ).*;$", lambda m, v=v: f"{m[1]}{v};", text, flags=re.M)
        assert n == 1, f"--g0-{k} missing in {VESKTOP}"
    write(VESKTOP, text)


def g0wm_colors():
    # fg bg border, with the alpha g0wm wants
    rows = {"norm": (DIM, BAR, BAR), "sel": (FG, BAR, BAR), "urg": (ACCENT, BAR, ACCENT),
            "title": (DIM, BAR, BAR), "titlesel": (FG, BAR, BAR), "status": (DIM, BAR, BAR),
            # the notifications and the runner are part of the bar: its background too
            "notify": (FG, BAR, ACCENT), "notifylow": (FG, BAR, GREEN), "notifycrit": (FG, BAR, RED),
            "runner": (FG, BAR, BAR), "runnersuggest": (DIM, BAR, BAR), "runnersel": (BAR, FG, FG),
            "runnericon": (FG, LINE, MUTE)}
    text = read(G0WM)
    for k, cs in rows.items():
        text = sub(G0WM, text, rf"^(\s+{k} )#\S+ #\S+ #\S+$",
                   lambda m, cs=cs: m[1] + " ".join(c + "ff" for c in cs))
    # behind the wallpaper while it loads, and around fullscreen windows
    for k, v in (("rootcolor", DESK), ("fullscreen_bg", BG), ("titleclosecolor", RED),
                 ("privatecolor", VISITED), ("publiccolor", LINK),
                 ("notification_privatecolor", VISITED), ("notification_publiccolor", LINK),
                 # the placeholder of private windows in screen sharing
                 ("color", BG), ("textcolor", DIM)):
        text = sub(G0WM, text, rf"^(\s+{k} )#\S+$", lambda m, v=v: m[1] + v + "ff")
    write(G0WM, text)


def status_colors():
    # the icons that warn: recording, DNS down, a failed maint job and a low battery
    # in red, mic and camera in use in amber
    colors = {"rec": RED, "dns": RED, "maint": RED, "mic": ACCENT, "cam": ACCENT, "battery_low": RED}
    text = read(STATUS)
    for k, v in colors.items():
        text = sub(STATUS, text, rf'^(color_{k} = )".*"$', lambda m, v=v: f'{m[1]}"{v}"')
    write(STATUS, text)


def gtklock_colors():
    # GTK 3 CSS: the rest of style.css uses them as @g0_<name>
    names = {"bar": BAR, "field": POPUP, "press": PRESS, "line": LINE, "fg": FG, "dim": DIM,
             "accent": ACCENT, "red": RED}
    text = read(GTKLOCK)
    for k, v in names.items():
        text = sub(GTKLOCK, text, rf"^(@define-color g0_{k} ).*;$", lambda m, v=v: f"{m[1]}{v};")
    write(GTKLOCK, text)


def tmux_colors():
    # everything from ### APPEARANCE on is written here
    look = f"""### APPEARANCE
# the colors are written by script/g0wm-theme.py, grey like vim and nvim
set -g status-position top
set -g status-justify left
set -g status-interval 5

set -g status-style "bg={BG},fg={FG}"
set -g pane-border-style "fg={MUTE}"
set -g pane-active-border-style "fg={MONO}"
set -g message-style "bg={BG},fg={MONO}"
set -g mode-style "bg={MONO},fg={BG}"

setw -g window-status-style "fg={FAINT}"
setw -g window-status-current-style "fg={MONO}"
# activity and bell: a ! after the name, not the whole name reversed
setw -g monitor-activity on
set -g visual-activity off
setw -g window-status-activity-style "fg={FAINT}"
setw -g window-status-bell-style "fg={FAINT}"
# + zoomed, ! activity or bell: amber as the warnings of the desktop
setw -g window-status-format " #I:#W#{{?window_zoomed_flag,+,}}#{{?#{{||:#{{window_activity_flag}},#{{window_bell_flag}}}},#[fg={ACCENT}]!,}} "
setw -g window-status-current-format " #I:#W#{{?window_zoomed_flag,+,}} "

# a dot while the prefix is down, copy in copy mode
set -g status-left "#{{?client_prefix,#[fg={ACCENT}]● ,}}#{{?pane_in_mode,#[fg={DIM}]copy ,}}"
set -g status-left-style "fg={FG}"
# the git branch of the pane, the host only over ssh
set -g status-right "#(git -C #{{q:pane_current_path}} branch --show-current 2>/dev/null) "
if-shell '[ -n "$SSH_CONNECTION" ]' 'set -ga status-right "#H "'
set -g status-right-style "fg={DIM}"

set -g clock-mode-colour "{MONO}"
"""
    text = read(TMUX)
    text = sub(TMUX, text, r"^### APPEARANCE\n(?:.*\n)*.*\Z", lambda m: look)
    write(TMUX, text)


def lazygit_colors():
    # the diffs come from delta, in git_colors()
    keys = {"activeBorderColor": ACCENT, "inactiveBorderColor": MUTE, "searchingActiveBorderColor": ACCENT,
            "selectedLineBgColor": SEL, "inactiveViewSelectedLineBgColor": HOVER, "optionsTextColor": DIM,
            "defaultFgColor": FG, "unstagedChangesColor": RED, "cherryPickedCommitFgColor": ON_ACCENT,
            "cherryPickedCommitBgColor": VISITED, "markedBaseCommitFgColor": ON_ACCENT,
            "markedBaseCommitBgColor": LINK}
    text = read(LAZYGIT)
    for k, v in keys.items():
        text = sub(LAZYGIT, text, rf'^(\s+{k}:\n\s+- )"#\w+"$', lambda m, v=v: f'{m[1]}"{v}"')
    write(LAZYGIT, text)


def git_colors():
    """The [delta] pager (git and lazygit) and the colors of git itself: green and red as
    the terminal, the changed words on the diff tints of vim and nvim, moved lines lilac."""
    e = EDITOR
    blocks = {
        "[delta]": [("navigate", "true"), ("line-numbers", "true"), ("syntax-theme", "ansi"),
                    ("file-style", f"{LINK} bold"), ("file-decoration-style", f"{LINE} ul"),
                    ("hunk-header-style", "omit"),
                    ("minus-style", RED), ("plus-style", GREEN),
                    ("minus-emph-style", f"bold {RED} {e['DIFF_DEL_BG']}"),
                    ("plus-emph-style", f"bold {GREEN} {e['DIFF_ADD_BG']}"),
                    ("line-numbers-minus-style", RED), ("line-numbers-plus-style", GREEN),
                    ("line-numbers-zero-style", MUTE), ("line-numbers-left-style", LINE),
                    ("line-numbers-right-style", LINE),
                    # git's colorMoved=default: magenta and blue old, cyan and yellow new
                    ("map-styles", ", ".join(f"bold {c} => {VISITED}" for c in ("purple", "blue", "cyan", "yellow")))],
        '[color "status"]': [("header", DIM), ("branch", ACCENT), ("localBranch", ACCENT),
                             ("remoteBranch", LINK), ("added", GREEN), ("updated", GREEN),
                             ("changed", RED), ("untracked", RED), ("nobranch", RED)],
        '[color "decorate"]': [("HEAD", f"{ACCENT} bold"), ("branch", GREEN), ("remoteBranch", LINK),
                               ("tag", ACCENT), ("stash", VISITED)],
    }
    text = read(GIT)
    for head, keys in blocks.items():
        # quoted: a # outside quotes starts a comment in git's config
        body = "".join(f'    {k} = "{v}"\n' if "#" in v else f"    {k} = {v}\n" for k, v in keys)
        text = sub(GIT, text, rf"^{re.escape(head)}\n(?:[ \t]+.*\n)*", lambda m, h=head, b=body: f"{h}\n{b}")
    write(GIT, text)


def editor_colors():
    # the 16 colors of :terminal are foot's, in its order
    ansi = [ANSI[f"{kind}{n}"] for kind in ("regular", "bright") for n in range(8)]
    rows = "".join("    " + ", ".join(f"'{c}'" for c in ansi[i:i + 4]) + ",\n" for i in range(0, 16, 4))
    fzf = "".join(f"  '{k}:{v}," + ("' ..\n" if i < len(FZF) - 1 else "'\n")
                  for i, (k, v) in enumerate(FZF)).replace(",'\n", "'\n")
    terminal = {NVIM: ("-- Terminal colors: foot's, written by script/g0wm-theme.py\n"
                       f"local term_colors = {{\n{rows}}}\n"),
                VIM: ("# Terminal colors: foot's, written by script/g0wm-theme.py\n"
                      f"g:terminal_ansi_colors = [\n{rows}]\n")}
    ends = {NVIM: r"^local term_colors = \{\n(?:.*\n)*?\}\n", VIM: r"^g:terminal_ansi_colors = \[\n(?:.*\n)*?\]\n"}
    for path, decl, mark, var in ((NVIM, "local", "--", "vim.env.FZF_DEFAULT_OPTS"), (VIM, "const", "#", "$FZF_DEFAULT_OPTS")):
        text = read(path)
        for k, v in EDITOR.items():
            text = sub(path, text, rf"^({decl} {k}\s*= )'#\w+'$", lambda m, v=v: f"{m[1]}'{v}'")
        text = sub(path, text, rf"^{re.escape(mark)} Terminal colors.*\n(?:.*\n)*?" + ends[path][1:],
                   lambda m, s=terminal[path]: s)
        text = sub(path, text, rf"^({re.escape(mark)} FZF.*\n{re.escape(var)} =\n  '--color=' \.\.\n)(?:  '.*\n)+",
                   lambda m: m[1] + fzf)
        write(path, text)


def readability():
    """The rules of the palette: a color that breaks one stops the script."""
    bad = []
    text = {"FG": FG, "FAINT": FAINT, "DIM": DIM, "MONO": MONO, "SOFT": SOFT, "ACCENT": ACCENT,
            "RED": RED, "GREEN": GREEN, "LINK": LINK, "VISITED": VISITED}
    pairs = [(f, b, 4.5) for f in text for b in ("BG", "POPUP")]
    pairs += [("FG", b, 4.5) for b in ("HOVER", "SEL", "PRESS")]
    pairs += [("ON_ACCENT", b, 4.5) for b in ("ACCENT", "RED", "GREEN")]
    # the selection of tmux, vim and nvim
    pairs += [("BG", "MONO", 4.5)]
    names = {**text, "BG": BG, "POPUP": POPUP, "HOVER": HOVER, "SEL": SEL, "PRESS": PRESS,
             "ON_ACCENT": ON_ACCENT}
    for f, b, need in pairs:
        if contrast(names[f], names[b]) < need:
            bad.append(f"{f} on {b}: {contrast(names[f], names[b]):.2f}, needs {need}")
    for k, v in ANSI.items():
        if k != "regular0" and contrast(v, BG) < 4.5:
            bad.append(f"{k} on BG: {contrast(v, BG):.2f}, needs 4.5")
    # each step lighter than the one before, enough to be seen
    for ladder, step in (((BG, POPUP, HOVER, SEL, PRESS, LINE), 0.03),
                         ((MUTE, FAINT, DIM, MONO, SOFT, FG), 0.03)):
        for a, b in zip(ladder, ladder[1:]):
            if oklab(b)[0] - oklab(a)[0] < step:
                bad.append(f"{b} is not {step} lighter than {a}")
    if oklab(DESK)[0] - oklab(BAR)[0] < 0.05:
        bad.append(f"DESK {DESK} is not 0.05 lighter than BAR {BAR}: the bar melts into the desktop")
    if bad:
        raise SystemExit("the palette breaks its rules:\n  " + "\n  ".join(bad))


def system():
    """script/g0wm-theme-system.py: the console, cursors, GRUB, plymouth, wallpaper."""
    # install.sh refuses a __pycache__ in script/
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("g0wm_theme_system",
                                                  os.path.join(REPO, "script/g0wm-theme-system.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def lib(name):
    # /usr/lib/<triplet> on Debian, /usr/lib elsewhere
    for p in sorted(glob.glob(f"/usr/lib/*-linux-gnu/{name}")) + [f"/usr/lib/{name}"]:
        if os.path.exists(p):
            return p
    raise SystemExit(f"{name} not found")


def main():
    global CHECK
    if sys.argv[1:] not in ([], ["--check"]):
        raise SystemExit("usage: g0wm-theme.py [--check]")
    CHECK = sys.argv[1:] == ["--check"]
    readability()

    colors_css()
    foot_colors()
    fastfetch_colors()
    fzf_colors()
    librewolf_colors()
    vesktop_colors()
    g0wm_colors()
    status_colors()
    gtklock_colors()
    tmux_colors()
    lazygit_colors()
    git_colors()
    editor_colors()
    system().run(sys.modules[__name__])
    if not CHECK:
        gtk_base(lib("libgtk-3.so.0"), "/org/gtk/libgtk/theme/Adwaita/gtk-contained-dark.css",
                 "/org/gtk/libgtk/theme/Adwaita/assets", os.path.join(THEME, "gtk-3.0/base.css"))
        gtk_base(lib("libgtk-4.so.1"), "/org/gtk/libgtk/theme/Default/Default-dark.css",
                 "/org/gtk/libgtk/theme/Default/assets", os.path.join(THEME, "gtk-4.0/base.css"))
    kvantum_svg()
    write(os.path.join(KVANTUM, "G0wm.svg"), C.svg())
    kvantum_colors()

    if STALE:
        print("not the colors of script/g0wm-theme.py, run it:", *STALE, sep="\n  ", file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
