"""Winter versions of the buildings: the same picture with the roof under snow.

Pixflux won't paint snow (DECISIONS 030), so, as for the farmhouse's first
winter roof (DECISIONS 034), the roof is recoloured to the palette's snow
whites by this script. Stage 23 (DECISIONS 069) makes it one rule for every
building instead of a hand-made mask each:

- The roof's colours are the ones found (almost) only in the top part of the
  picture: a colour that's also common lower down is a wall, a window or a
  door, and keeps its colour (so dormer windows and chimneys stay as they are).
- Each roof colour becomes snow by how bright it is: the roof's main colour
  and anything brighter white, darker shades pale blue, its outline the
  snow's shadow blue.

Run from the project folder:  python art/build_winter_roofs.py
It writes <name>_winter.png next to each picture listed below.
"""
from collections import Counter
from pathlib import Path

from PIL import Image

SNOW_SHADOW = (114, 149, 174, 255)
SNOW_MID = (212, 231, 245, 255)
SNOW_LIGHT = (247, 253, 255, 255)

# Picture: how far down it the roof reaches at most (a fraction of the
# height), and what share of a colour's pixels must be above that line for it
# to count as roof. The share is lower where the roof's colour is also the
# door's or the walls' (Wren's brown, Tam's tar, the lighthouse's red), since
# only pixels above the line are ever changed.
BUILDINGS = {
    "farm/farmhouse": (0.55, 0.5),
    "farm/greenhouse": (0.6, 0.85),
    "town/seed_shop": (0.6, 0.85),
    "town/general_store": (0.6, 0.85),
    "town/blacksmith": (0.6, 0.85),
    "town/bakery": (0.55, 0.85),
    "town/tavern": (0.5, 0.85),
    "town/town_hall": (0.5, 0.85),
    "town/mayor_house": (0.45, 0.6),
    "town/wren_cottage": (0.5, 0.3),
    "lane/pip_cottage": (0.6, 0.85),
    "lane/dot_yard": (0.55, 0.85),
    "lane/ivy_cottage": (0.55, 0.85),
    "cove/tam_shed": (0.45, 0.2),
    "cove/rosa_cottage": (0.55, 0.85),
    "cove/lighthouse": (0.12, 0.2),
}
# A roof colour darker than this is its outline, and stays a dark line: the
# snow's shadow.
OUTLINE_BRIGHTNESS = 60
MIN_PIXELS = 12

SPRITES = Path(__file__).resolve().parent.parent / "assets" / "sprites"


def brightness(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def winter(picture: Image.Image, roof_fraction: float, roof_share: float) -> Image.Image:
    im = picture.convert("RGBA")
    w, h = im.size
    line = int(h * roof_fraction)
    above, total = Counter(), Counter()
    for y in range(h):
        for x in range(w):
            c = im.getpixel((x, y))
            if c[3] == 0:
                continue
            total[c] += 1
            if y < line:
                above[c] += 1
    roof = [c for c in total if total[c] >= MIN_PIXELS and above[c] / total[c] >= roof_share]
    if not roof:
        return im.copy()
    # The roof's main colour (the one with most pixels above the line) and
    # anything brighter becomes white; darker shades pale blue; the outline
    # the shadow blue.
    main = max(roof, key=lambda c: above[c])
    mapping = {}
    for c in roof:
        if c != main and brightness(c) < OUTLINE_BRIGHTNESS:
            mapping[c] = SNOW_SHADOW
        elif brightness(c) >= brightness(main):
            mapping[c] = SNOW_LIGHT
        else:
            mapping[c] = SNOW_MID
    out = im.copy()
    for y in range(line):
        for x in range(w):
            c = im.getpixel((x, y))
            if c in mapping:
                out.putpixel((x, y), mapping[c])
    return out


def main():
    for name, (fraction, share) in BUILDINGS.items():
        src = SPRITES / f"{name}.png"
        winter(Image.open(src), fraction, share).save(SPRITES / f"{name}_winter.png")
        print("wrote", f"{name}_winter.png")


if __name__ == "__main__":
    main()
