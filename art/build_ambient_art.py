"""Draw our own little moving things (DECISIONS 088).

    python art/build_ambient_art.py

Writes assets/sprites/ambient/: the few animation strips the bought packs
don't have, drawn here pixel by pixel in colours from art/palette.png, so
they're ours and are kept in git:

- fish_jump_8f.png   a small fish leaping out of the water and back in, with
                     a ring and a splash (24 x 20 frames). The Cove's sea and
                     the town's pond play it now and then.
- songbird_fly_2f.png one small bird, wings up then down (8 x 8 frames).
                     Ambience flies two or three across the sky together.
- window_glow.png    a soft warm dot, for a lamp-lit window's halo at night
                     (16 x 16; drawn additive, so it lightens what's under it).

The rest (chimney smoke, sparkles, leaves, butterflies, gulls, fireflies) come
from the packs, by way of art/build_scenery_library.py.
"""
import math
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites", "ambient")


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# All from art/palette.png.
OUTLINE = hexc("#22222b")
FISH_BACK = hexc("#7295ae")
FISH_BELLY = hexc("#dfe2e8")
FISH_FIN = hexc("#43547a")
WATER_LIGHT = hexc("#b5ecf5")
WATER_WHITE = hexc("#f7fdff")
BIRD = hexc("#3a2b45")
BIRD_LIGHT = hexc("#785853")


def put(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


FISH_ROWS = [
    "...OOO...",
    "O.OBBBOO.",
    "OOBBBBBEO",
    "O.OWWWWO.",
    "...OOOO..",
]


def fish(img, cx, cy, angle):
    """A 9 x 5 fish, tail on the left, turned to `angle` (radians, nose up
    is negative) and centred on (cx, cy)."""
    colours = {"O": OUTLINE, "B": FISH_BACK, "W": FISH_BELLY, "E": OUTLINE}
    small = Image.new("RGBA", (9, 5))
    for y, row in enumerate(FISH_ROWS):
        for x, ch in enumerate(row):
            if ch in colours:
                small.putpixel((x, y), colours[ch])
    turned = small.rotate(-math.degrees(angle), resample=Image.NEAREST, expand=True)
    img.alpha_composite(turned, (round(cx - turned.width / 2), round(cy - turned.height / 2)))


def ring(img, cx, cy, rx, ry, c, gap=0):
    steps = 32
    for i in range(steps):
        if gap and i % gap == 0:
            continue
        a = 2 * math.pi * i / steps
        put(img, round(cx + rx * math.cos(a)), round(cy + ry * math.sin(a)), c)


def fish_jump():
    w, h, n = 24, 20, 8
    strip = Image.new("RGBA", (w * n, h))
    water_y = 16
    for f in range(n):
        frame = Image.new("RGBA", (w, h))
        if f == 0:
            ring(frame, 7, water_y, 2, 1, WATER_LIGHT)
            put(frame, 7, water_y - 1, WATER_WHITE)
        elif 1 <= f <= 5:
            # Up and over, left to right, a parabola from x 6 to x 18.
            t = (f - 1) / 4.0
            x = 6 + 12 * t
            y = water_y - 2 - 12 * (1 - (2 * t - 1) ** 2)
            slope = -24 * (1 - 2 * t) / 12.0
            fish(frame, x, y, math.atan2(slope, 1))
            if f == 1:
                ring(frame, 6, water_y, 3, 1, WATER_LIGHT, gap=4)
                put(frame, 4, water_y - 2, WATER_WHITE)
                put(frame, 8, water_y - 3, WATER_WHITE)
            if f == 5:
                put(frame, 18, water_y - 1, WATER_WHITE)
        elif f == 6:
            for x, y in ((16, 13), (18, 11), (20, 13), (17, 14), (19, 14)):
                put(frame, x, y, WATER_WHITE)
            ring(frame, 18, water_y, 3, 1, WATER_LIGHT)
        else:
            ring(frame, 18, water_y, 5, 2, WATER_LIGHT, gap=3)
        strip.paste(frame, (f * w, 0))
    return strip


def songbird():
    w, h = 8, 8
    strip = Image.new("RGBA", (w * 2, h))
    up = ["#.....#.", ".#...#..", "..###...", "...#....", "........"]
    down = ["........", "..###...", ".#.#.#..", "#..#..#.", "........"]
    for f, rows in enumerate((up, down)):
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch == "#":
                    strip.putpixel((f * w + x, y + 2), BIRD)
        strip.putpixel((f * w + 3, 4 if f == 0 else 3), BIRD_LIGHT)
    return strip


def window_glow():
    size = 16
    img = Image.new("RGBA", (size, size))
    c = (size - 1) / 2.0
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c) / (size / 2.0)
            a = max(0.0, 1.0 - d) ** 1.6
            # Stepped, so it stays pixel art rather than a smooth airbrush.
            a = round(a * 4) / 4.0
            if a > 0:
                img.putpixel((x, y), (255, 255, 255, int(a * 255)))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    fish_jump().save(os.path.join(OUT, "fish_jump_8f.png"))
    songbird().save(os.path.join(OUT, "songbird_fly_2f.png"))
    window_glow().save(os.path.join(OUT, "window_glow.png"))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
