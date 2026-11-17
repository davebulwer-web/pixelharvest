"""Placeholder art for Stage 19 session 1 (DECISIONS 060), drawn in the palette
until Pixellab replaces it (Stage 23): the farm's debris (stones, a stump,
brambles, nettles), the stone item, three hedgerow forage icons (sloes,
rosehips, wild raspberries) and the Lane's signpost.

Run from the project folder:  python art/build_stage19_placeholders.py
"""
from PIL import Image, ImageDraw
import random

OUT = "assets/sprites/"
C = {
    "outline": (46, 31, 26, 255), "dark": (34, 34, 43, 255),
    "stone_d": (68, 68, 79, 255), "stone": (113, 113, 126, 255), "stone_l": (212, 231, 245, 255),
    "stone_m": (114, 149, 174, 255),
    "wood_d": (74, 47, 34, 255), "wood": (107, 74, 47, 255), "wood_l": (138, 99, 64, 255),
    "ring": (200, 153, 123, 255),
    "leaf_dd": (30, 58, 31, 255), "leaf_d": (47, 90, 43, 255), "leaf": (74, 127, 58, 255),
    "leaf_l": (111, 191, 74, 255), "leaf_ll": (168, 224, 107, 255),
    "berry_d": (59, 54, 75, 255), "berry": (63, 78, 113, 255), "bloom": (79, 184, 172, 255),
    "red_d": (96, 41, 52, 255), "red": (172, 59, 70, 255), "red_l": (196, 73, 76, 255),
    "pink": (189, 117, 118, 255), "white": (247, 253, 255, 255), "cream": (255, 231, 216, 255),
}
T = (0, 0, 0, 0)


def new(w, h):
    img = Image.new("RGBA", (w, h), T)
    return img, ImageDraw.Draw(img)


def blob(d, box, fill, outline=None):
    d.ellipse(box, fill=fill, outline=outline)


def stones():
    img, d = new(16, 16)
    blob(d, (1, 7, 9, 14), C["stone"], C["outline"])
    blob(d, (7, 5, 15, 14), C["stone"], C["outline"])
    blob(d, (4, 10, 11, 15), C["stone_m"], C["outline"])
    for p in [(3, 9), (9, 7), (10, 8), (6, 12)]:
        d.point(p, C["stone_l"])
    for p in [(12, 12), (13, 11), (8, 14)]:
        d.point(p, C["stone_d"])
    return img


def stump():
    img, d = new(16, 16)
    d.rectangle((3, 7, 12, 14), fill=C["wood"], outline=C["outline"])
    blob(d, (2, 4, 13, 10), C["ring"], C["outline"])
    blob(d, (5, 6, 10, 8), C["wood_l"])
    d.point((7, 7), C["wood_d"])
    d.line((1, 14, 3, 12), fill=C["wood_d"])
    d.line((12, 12, 14, 14), fill=C["wood_d"])
    for y in (10, 12):
        d.point((5, y), C["wood_d"])
        d.point((9, y + 1), C["wood_d"])
    return img


def bramble():
    img, d = new(16, 20)
    rng = random.Random(19)
    blob(d, (0, 6, 15, 19), C["leaf_dd"])
    blob(d, (2, 4, 13, 17), C["leaf_d"])
    for _ in range(26):
        x, y = rng.randint(1, 14), rng.randint(5, 18)
        d.point((x, y), C["leaf"] if rng.random() < 0.6 else C["wood_d"])
    for _ in range(8):  # thorny canes
        x, y = rng.randint(2, 13), rng.randint(6, 17)
        d.line((x, y, x + rng.choice([-2, 2]), y - 2), fill=C["wood"])
    for p in [(4, 9), (10, 7), (12, 13), (6, 15)]:
        d.point(p, C["red_d"])
    return img


def nettles():
    img, d = new(16, 16)
    rng = random.Random(7)
    for x0 in (3, 7, 11):
        h = rng.randint(8, 12)
        d.line((x0, 15, x0, 15 - h), fill=C["leaf_d"])
        for y in range(15 - h + 1, 15, 2):
            d.point((x0 - 1, y), C["leaf"])
            d.point((x0 + 1, y + 1), C["leaf_l"])
            d.point((x0 - 2, y + 1), C["leaf_d"])
            d.point((x0 + 2, y), C["leaf"])
        d.point((x0, 15 - h), C["leaf_ll"])
    return img


def stone_item():
    img, d = new(16, 16)
    blob(d, (2, 4, 14, 13), C["stone"], C["outline"])
    blob(d, (4, 6, 9, 9), C["stone_l"])
    for p in [(11, 10), (10, 11), (7, 11)]:
        d.point(p, C["stone_d"])
    return img


def berries(main, light, dark, leaf=True, seed=1):
    img, d = new(16, 16)
    if leaf:
        d.polygon([(3, 3), (8, 1), (7, 6)], fill=C["leaf"], outline=C["leaf_d"])
        d.line((8, 2, 9, 6), fill=C["wood"])
    for (x, y) in [(5, 7), (10, 6), (7, 10), (2, 10), (11, 11)]:
        blob(d, (x, y, x + 4, y + 4), main, C["outline"])
        d.point((x + 1, y + 1), light)
        d.point((x + 3, y + 3), dark)
    return img


def rosehip():
    img, d = new(16, 16)
    d.line((2, 2, 13, 13), fill=C["wood"])
    for (x, y) in [(2, 5), (8, 2), (7, 8)]:
        blob(d, (x, y, x + 5, y + 6), C["red"], C["outline"])
        d.point((x + 1, y + 2), C["red_l"])
        d.point((x + 2, y), C["leaf_dd"])
    return img


def raspberry():
    img, d = new(16, 16)
    d.polygon([(2, 2), (7, 1), (5, 5)], fill=C["leaf"], outline=C["leaf_d"])
    for (x, y) in [(4, 5), (9, 7), (4, 10)]:
        blob(d, (x, y, x + 5, y + 5), C["red_l"], C["outline"])
        for p in [(x + 1, y + 2), (x + 3, y + 1), (x + 2, y + 3)]:
            d.point(p, C["pink"])
    return img


def signpost():
    img, d = new(24, 32)
    d.rectangle((11, 8, 13, 31), fill=C["wood"], outline=C["outline"])
    d.polygon([(2, 5), (18, 5), (22, 9), (18, 13), (2, 13)], fill=C["wood_l"], outline=C["outline"])
    d.line((5, 9, 16, 9), fill=C["wood_d"])
    d.polygon([(21, 16), (6, 16), (2, 19), (6, 22), (21, 22)], fill=C["wood_l"], outline=C["outline"])
    d.line((7, 19, 18, 19), fill=C["wood_d"])
    return img


if __name__ == "__main__":
    stones().save(OUT + "farm/debris_stones.png")
    stump().save(OUT + "farm/debris_stump.png")
    bramble().save(OUT + "farm/debris_bramble.png")
    nettles().save(OUT + "farm/debris_nettles.png")
    stone_item().save(OUT + "items/stone.png")
    berries(C["berry"], C["bloom"], C["berry_d"]).save(OUT + "forage/sloe.png")
    rosehip().save(OUT + "forage/rosehip.png")
    raspberry().save(OUT + "forage/raspberry.png")
    signpost().save(OUT + "lane/signpost.png")
    print("Stage 19 placeholders written.")
