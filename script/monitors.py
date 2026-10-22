#!/usr/bin/env python3
# Fill the "@MONITOR@" line of a g0wm config: the monitor blocks of the installed
# copy when one has a name, else one block per connected output.
# usage: monitors.py RENDERED INSTALLED
import glob
import re
import sys


def block(name, scale, w, h, hz):
    lines = ["monitor {", "\tname" + (" " + name if name else ""), "\tmfact 0.55", "\tnmaster 1",
             f"\tscale {scale}", '\tlayout "[ ]"', "\ttransform normal", "\tx -1", "\ty -1",
             f"\twidth {w}", f"\theight {h}", f"\trefresh {hz}", "}"]
    return "\n".join(lines) + "\n"


def blocks(text):
    """The top-level monitor blocks of a config, as they are written."""
    out = []
    i = 0
    for m in re.finditer(r"^monitor[ \t]*\{", text, re.M):
        if m.start() < i:
            continue
        depth, quote, esc = 0, False, False
        for j in range(m.end() - 1, len(text)):
            c = text[j]
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                quote = not quote
            elif quote:
                continue
            elif c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    i = j + 1
                    out.append(text[m.start():i] + "\n")
                    break
    return out


def kept(path):
    try:
        with open(path) as f:
            found = blocks(f.read())
    except OSError:
        return None
    # only the catch-all one: written before the outputs were detected
    named = [b for b in found if re.search(r"^[ \t]*name[ \t]+\S", b, re.M)]
    return found if named else None


def detected():
    rules = []
    for c in glob.glob("/sys/class/drm/card*-*"):
        try:
            with open(c + "/status") as f:
                if f.read().strip() != "connected":
                    continue
            with open(c + "/modes") as f:
                mode = re.match(r"(\d+)x(\d+)", f.readline())
        except OSError:
            continue
        if not mode:
            continue
        w, h = int(mode[1]), int(mode[2])
        # the mode closest to 1000 Hz is the fastest at that resolution
        rules.append((c.split("-", 1)[1], 2 if h > 1080 else 1, w, h, 1000))
    # g0wm matches names as substrings: eDP-1 before DP-1, DP-10 before DP-1
    rules.sort(key=lambda r: (-len(r[0]), r[0]))
    return [block(*r) for r in rules] + [block(None, 1, 0, 0, 0)]


def main():
    out, installed = sys.argv[1:]
    mons = kept(installed) or detected()
    with open(out) as f:
        text = f.read()
    text = re.sub(r"^@MONITOR@\n", lambda _: "".join(mons), text, flags=re.M)
    with open(out, "w") as f:
        f.write(text)


if __name__ == "__main__":
    main()
