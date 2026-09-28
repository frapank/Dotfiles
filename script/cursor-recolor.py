#!/usr/bin/env python3
# recolors Xcursor files in a directory: cursor-recolor.py DIR "DARK LIGHT ACCENT..."

import collections, colorsys, os, struct, sys

def rgb(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))

dark, light, *accents = [rgb(h) for h in sys.argv[2].split()]
hues = [colorsys.rgb_to_hsv(*c)[0] for c in accents]

def images(d, f):
    if d[:4] != b'Xcur':
        sys.exit(f + ': not an Xcursor file')
    for i in range(struct.unpack_from('<I', d, 12)[0]):
        typ, _, pos = struct.unpack_from('<III', d, 16 + 12 * i)
        if typ == 0xfffd0002:
            w, h = struct.unpack_from('<II', d, pos + 16)
            yield pos + 36, w * h

def unpremultiply(v):
    a = v >> 24
    return [min(1.0, ((v >> s) & 255) / a) for s in (16, 8, 0)]

def nearest(h):
    return min(range(len(hues)), key=lambda i: min(abs(hues[i] - h), 1 - abs(hues[i] - h)))

def recolor(f):
    d = bytearray(open(f, 'rb').read())
    count = [collections.Counter() for _ in accents]
    for pos, n in images(d, f):
        for v in struct.unpack_from('<%dI' % n, d, pos):
            if v >> 24 == 255:
                h, s, val = colorsys.rgb_to_hsv(*unpremultiply(v))
                if s * val >= 0.1:
                    count[nearest(h)][v] += 1
    fill = [colorsys.rgb_to_hsv(*unpremultiply(c.most_common(1)[0][0]))[1:] if c else None for c in count]
    cache = {}

    def pixel(v):
        a = v >> 24
        if a == 0:
            return v
        if v not in cache:
            src = unpremultiply(v)
            h, s, val = colorsys.rgb_to_hsv(*src)
            i = nearest(h)
            if s * val < 0.1 or fill[i] is None:
                t = sum(src) / 3
                out = [dk + (lt - dk) * t for dk, lt in zip(dark, light)]
            else:
                ts = min(1.0, s / fill[i][0])
                tv = min(1.0, val / fill[i][1])
                out = [dk + (lt + (c - lt) * ts - dk) * tv for dk, lt, c in zip(dark, light, accents[i])]
            r, g, b = [round(c * a) for c in out]
            cache[v] = (a << 24) | (r << 16) | (g << 8) | b
        return cache[v]

    for pos, n in images(d, f):
        px = struct.unpack_from('<%dI' % n, d, pos)
        struct.pack_into('<%dI' % n, d, pos, *map(pixel, px))
    open(f, 'wb').write(d)

top = sys.argv[1]
for f in sorted(os.listdir(top)):
    f = os.path.join(top, f)
    if os.path.isfile(f) and not os.path.islink(f):
        recolor(f)
