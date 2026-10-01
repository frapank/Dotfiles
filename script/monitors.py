#!/usr/bin/env python3
# Fill "@MONITOR@" in a g0wm settings.json: the monitors of the installed
# copy when it has some, else one rule per connected output.
# usage: monitors.py RENDERED INSTALLED
import glob
import json
import re
import sys


def rule(name, scale, w, h, hz):
    return {"name": name, "mfact": 0.55, "nmaster": 1, "scale": scale,
            "layout": "[ ]", "transform": "normal", "x": -1, "y": -1,
            "width": w, "height": h, "refresh": hz}


def kept(path):
    try:
        with open(path) as f:
            m = json.load(f)["monitors"]
    except (OSError, ValueError, KeyError, TypeError):
        return None
    return m if isinstance(m, list) and m else None


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
        rules.append(rule(c.split("-", 1)[1], 2 if h > 1080 else 1, w, h, 1000))
    # g0wm matches names as substrings: eDP-1 before DP-1, DP-10 before DP-1
    rules.sort(key=lambda r: (-len(r["name"]), r["name"]))
    return rules + [rule(None, 1, 0, 0, 0)]


def main():
    out, installed = sys.argv[1:]
    mons = kept(installed) or detected()
    with open(out) as f:
        text = f.read()
    text = text.replace('"@MONITOR@"', json.dumps(mons, indent=4).replace("\n", "\n    "))
    with open(out, "w") as f:
        f.write(text)


if __name__ == "__main__":
    main()
