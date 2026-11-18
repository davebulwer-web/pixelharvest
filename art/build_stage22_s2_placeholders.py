"""Placeholder art for Stage 22 session 2 (DECISIONS 068), drawn in the palette
until Pixellab replaces it (Stage 23 and 24). The buildings follow the building
size rule (art/STYLE.md): a door opening of at least 24 x 36 px on the two
middle cells of the bottom row, roofs 40-50% of the height, all sloping.

  assets/sprites/town/nell.png             Nell, 56 x 56: Mabel's figure in a
                                           bottle-green dress, sleeves rolled
  assets/sprites/town/tavern.png           the Wheatsheaf, 160 x 128: the
                                           biggest building in town, thatched,
                                           a hanging sign and bay windows
  assets/sprites/town/mayor_house.png      the mayor's house, 128 x 112: a
                                           hipped slate roof, a porch
  assets/sprites/town/town_hall.png        the town hall, 128 x 112: slate
                                           with dormers and a clock
  assets/sprites/town/wren_cottage.png     Wren's cottage, 96 x 96: gabled,
                                           nets drying on the wall
  assets/sprites/lane/ivy_cottage.png      Ivy's cottage, 96 x 96: a catslide
                                           roof, roses and a water butt
  assets/sprites/town/tavern_bar.png       the bar, 48 x 24 (two side by side)
  assets/sprites/town/tavern_table.png     a table with two stools, 32 x 24
  assets/sprites/town/fireplace.png        an inglenook fireplace, 32 x 40
  assets/sprites/town/chalkboard.png       Nell's chalkboard, 32 x 24
  assets/sprites/town/dartboard.png        the dartboard, 16 x 24
  assets/sprites/town/barrels.png          two barrels, 32 x 24
  assets/sprites/dishes/ploughmans.png     16 x 16 each: the tavern's food
  assets/sprites/dishes/hotpot.png
  assets/sprites/dishes/fish_supper.png

Run from the project folder:  python art/build_stage22_s2_placeholders.py
Safe to run again: it only ever writes the files above.
"""
import colorsys

from PIL import Image, ImageDraw

OUT = "assets/sprites/"
C = {
    "outline": (46, 31, 26, 255), "dark": (34, 34, 43, 255),
    "stone_d": (68, 68, 79, 255), "stone": (113, 113, 126, 255), "stone_l": (212, 231, 245, 255),
    "wood_d": (74, 47, 34, 255), "wood": (107, 74, 47, 255), "wood_l": (138, 99, 64, 255),
    "thatch_d": (120, 88, 83, 255), "thatch": (171, 129, 108, 255), "thatch_l": (200, 153, 123, 255),
    "wall": (255, 231, 216, 255), "wall_s": (245, 194, 186, 255), "wall_d": (189, 117, 118, 255),
    "glass": (171, 220, 239, 255), "glass_d": (114, 149, 174, 255),
    "slate_d": (59, 54, 75, 255), "slate": (63, 78, 113, 255), "slate_l": (67, 84, 122, 255),
    "red": (172, 59, 70, 255), "red_d": (143, 51, 63, 255), "red_l": (196, 73, 76, 255),
    "orange": (226, 101, 26, 255), "orange_l": (251, 160, 87, 255),
    "leaf_d": (47, 90, 43, 255), "leaf": (74, 127, 58, 255), "leaf_l": (111, 191, 74, 255),
    "olive": (110, 106, 44, 255), "white": (247, 253, 255, 255), "grey": (83, 67, 74, 255),
    "brick": (143, 51, 63, 255), "brick_l": (196, 73, 76, 255), "chalk": (54, 46, 54, 255),
    "gold": (251, 160, 87, 255), "lamp": (255, 231, 150, 255),
}
T = (0, 0, 0, 0)


def new(w, h):
    img = Image.new("RGBA", (w, h), T)
    return img, ImageDraw.Draw(img)


def window(d, x, y, w=14, h=14, lit=False):
    """A four-pane window with a frame and a sill, top-left at (x, y)."""
    d.rectangle((x, y, x + w - 1, y + h - 1), fill=C["lamp"] if lit else C["glass"], outline=C["outline"])
    d.line((x + w // 2, y, x + w // 2, y + h - 1), fill=C["wood"])
    d.line((x, y + h // 2, x + w - 1, y + h // 2), fill=C["wood"])
    if not lit:
        d.rectangle((x + 1, y + 1, x + w // 2 - 1, y + 3), fill=C["stone_l"])
    d.rectangle((x - 1, y + h, x + w, y + h + 1), fill=C["wood_l"], outline=C["outline"])


def door(d, cx, bottom, w, h, colour="wood"):
    """A plank door, its opening w x h, centred on cx, standing on bottom."""
    x0, x1 = cx - w // 2, cx + w // 2 - 1
    y0 = bottom - h + 1
    d.rectangle((x0 - 2, y0 - 2, x1 + 2, bottom), fill=C["wood_d"], outline=C["outline"])
    d.rectangle((x0, y0, x1, bottom), fill=C[colour])
    for x in range(x0 + 3, x1, 4):
        d.line((x, y0 + 1, x, bottom), fill=C["wood_d"])
    d.rectangle((x1 - 4, (y0 + bottom) // 2, x1 - 3, (y0 + bottom) // 2 + 1), fill=C["orange_l"])
    d.line((x0 - 3, bottom, x1 + 3, bottom), fill=C["stone"])


def recolour(img, test, hue, sat_add=0.2, val_mul=1.0):
    """Turn every pixel `test(h, s, v)` picks to `hue`, keeping its shading."""
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if test(h, s, v):
                rr, gg, bb = colorsys.hsv_to_rgb(hue, min(1.0, s + sat_add), min(1.0, v * val_mul))
                px[x, y] = (int(rr * 255), int(gg * 255), int(bb * 255), a)
    return img


# --- Nell ---------------------------------------------------------------------

def nell():
    """Mabel's figure (56 x 56), her pale blue dress and apron turned a deep
    bottle green, so the two women read apart."""
    img = Image.open(OUT + "town/baker.png").convert("RGBA")
    return recolour(img, lambda h, s, v: 0.45 < h < 0.75 and v > 0.4, 0.36, 0.35, 0.55)


# --- Buildings --------------------------------------------------------------------

def tavern():
    """160 x 128: the Wheatsheaf. A long thatched roof (the top 58 px) with two
    eyebrow windows and a brick chimney at each end, cream walls with dark
    timbers, bay windows lit warm either side, a hanging sign with a sheaf,
    and the doorway (28 x 38 px) in the middle two cells."""
    img, d = new(160, 128)
    # Chimneys behind the thatch.
    for x in (16, 132):
        d.rectangle((x, 2, x + 11, 30), fill=C["brick"], outline=C["outline"])
        d.rectangle((x - 2, 0, x + 13, 4), fill=C["brick_l"], outline=C["outline"])
    # The wall, with timbers.
    d.rectangle((6, 56, 153, 127), fill=C["wall"], outline=C["outline"])
    d.rectangle((7, 122, 152, 126), fill=C["wall_s"])
    for x in (6, 40, 118, 153):
        d.rectangle((x - 1, 57, x + 1, 126), fill=C["wood_d"])
    d.rectangle((7, 86, 152, 88), fill=C["wood_d"])
    # The thatch: a long rounded hood over the whole front.
    d.rounded_rectangle((0, 12, 159, 62), radius=16, fill=C["thatch"], outline=C["outline"])
    d.rounded_rectangle((10, 6, 149, 28), radius=9, fill=C["thatch_l"], outline=C["outline"])
    for x in range(6, 156, 6):
        d.line((x, 32, x + 2, 58), fill=C["thatch_d"])
    d.line((4, 60, 155, 60), fill=C["thatch_d"])
    # Two eyebrow windows upstairs (Nell's rooms).
    for cx in (48, 112):
        d.rounded_rectangle((cx - 13, 24, cx + 13, 44), radius=6, fill=C["thatch_l"], outline=C["outline"])
        window(d, cx - 7, 30, 14, 10)
    # Bay windows, lit, either side of the door.
    for x in (14, 120):
        d.rectangle((x - 2, 92, x + 27, 98), fill=C["wood_l"], outline=C["outline"])
        window(d, x, 98, 26, 16, lit=True)
    # The hanging sign: a bracket out from the wall, a board with a sheaf.
    d.line((92, 66, 112, 66), fill=C["wood_d"], width=2)
    d.rectangle((98, 68, 116, 84), fill=C["olive"], outline=C["outline"])
    for x in (103, 107, 111):
        d.line((x, 81, 107, 72), fill=C["gold"])
    d.line((102, 77, 112, 77), fill=C["orange"])
    # The door, a lantern either side.
    door(d, 80, 127, 28, 38)
    for x in (60, 100):
        d.rectangle((x - 2, 96, x + 2, 102), fill=C["lamp"], outline=C["outline"])
    return img


def mayor_house():
    """128 x 112: a square brick house with a hipped slate roof (the top 50
    px), two chimneys, sash windows and a porch over the door."""
    img, d = new(128, 112)
    for x in (22, 96):
        d.rectangle((x, 4, x + 9, 26), fill=C["brick"], outline=C["outline"])
        d.rectangle((x - 1, 2, x + 10, 6), fill=C["stone"], outline=C["outline"])
    d.rectangle((6, 48, 121, 111), fill=C["brick_l"], outline=C["outline"])
    for y in range(52, 111, 5):
        d.line((7, y, 120, y), fill=C["brick"])
    # Hipped roof: a trapezium, slopes on all sides.
    d.polygon([(0, 52), (26, 10), (101, 10), (127, 52)], fill=C["slate"], outline=C["outline"])
    for y in range(16, 52, 5):
        inset = int((52 - y) * 26 / 42)
        d.line((inset + 1, y, 126 - inset, y), fill=C["slate_d"])
    d.line((26, 11, 101, 11), fill=C["slate_l"])
    # Sash windows, two up (on the wall under the eaves), two down.
    for x in (16, 98):
        window(d, x, 60, 14, 16)
        window(d, x, 86, 14, 16)
    # The porch: a little gable on two posts over the door.
    d.polygon([(44, 70), (64, 58), (84, 70)], fill=C["slate"], outline=C["outline"])
    for x in (46, 81):
        d.rectangle((x, 70, x + 1, 111), fill=C["wall"], outline=C["outline"])
    door(d, 64, 111, 26, 38, colour="red_d")
    return img


def town_hall():
    """128 x 112: the town hall. Pale stone, a tall slate roof (the top 52 px)
    with three dormers and a clock in the gable, tall windows, double door."""
    img, d = new(128, 112)
    d.rectangle((4, 50, 123, 111), fill=C["stone_l"], outline=C["outline"])
    for y in range(56, 111, 8):
        d.line((5, y, 122, y), fill=C["glass_d"])
    d.polygon([(0, 54), (16, 14), (111, 14), (127, 54)], fill=C["slate_d"], outline=C["outline"])
    for y in range(20, 54, 5):
        inset = int((54 - y) * 16 / 40)
        d.line((inset + 1, y, 126 - inset, y), fill=C["slate"])
    # A clock gable in the middle of the roof, and two dormers.
    d.polygon([(48, 30), (64, 2), (80, 30)], fill=C["stone_l"], outline=C["outline"])
    d.ellipse((57, 12, 71, 26), fill=C["white"], outline=C["outline"])
    d.line((64, 19, 64, 14), fill=C["outline"])
    d.line((64, 19, 68, 19), fill=C["outline"])
    for x in (22, 92):
        d.rectangle((x, 26, x + 13, 42), fill=C["stone_l"], outline=C["outline"])
        d.polygon([(x - 2, 28), (x + 6, 20), (x + 15, 28)], fill=C["slate_d"], outline=C["outline"])
        d.rectangle((x + 3, 30, x + 10, 40), fill=C["glass"], outline=C["outline"])
    # Tall windows, steps, a notice either side of the door.
    for x in (12, 32, 84, 104):
        window(d, x, 62, 12, 26)
    door(d, 64, 111, 28, 40, colour="wood_d")
    d.rectangle((50, 104, 78, 106), fill=C["stone"])
    return img


def wren_cottage():
    """96 x 96: a gabled cottage, end on (the top 44 px is roof), a nets-and-
    floats wall by the door, a rod against it."""
    img, d = new(96, 96)
    d.rectangle((70, 4, 79, 22), fill=C["stone_d"], outline=C["outline"])
    d.rectangle((6, 44, 89, 95), fill=C["wall"], outline=C["outline"])
    d.rectangle((7, 90, 88, 94), fill=C["wall_s"])
    d.polygon([(0, 48), (48, 4), (95, 48)], fill=C["wood"], outline=C["outline"])
    for y in range(12, 48, 5):
        half = int((y - 4) * 48 / 44)
        d.line((48 - half + 2, y, 48 + half - 2, y), fill=C["wood_d"])
    window(d, 41, 24, 14, 12)
    window(d, 12, 58)
    # Nets hung on the wall, with orange floats; a rod leaning by the door.
    d.rectangle((62, 54, 86, 76), fill=C["thatch_l"], outline=C["outline"])
    for x in range(64, 86, 4):
        d.line((x, 55, x, 75), fill=C["thatch_d"])
    for y in range(58, 76, 4):
        d.line((63, y, 85, y), fill=C["thatch_d"])
    for x in (66, 76, 84):
        d.ellipse((x - 2, 72, x + 2, 76), fill=C["orange"], outline=C["outline"])
    d.line((32, 50, 26, 95), fill=C["wood_d"])
    door(d, 48, 95, 26, 36)
    return img


def ivy_cottage():
    """96 x 96: a little cottage with a catslide roof sweeping low on the
    left (the top 46 px is roof), roses round the door, a water butt."""
    img, d = new(96, 96)
    d.rectangle((66, 2, 75, 20), fill=C["brick"], outline=C["outline"])
    d.rectangle((8, 46, 89, 95), fill=C["wall"], outline=C["outline"])
    d.rectangle((9, 90, 88, 94), fill=C["wall_s"])
    d.polygon([(0, 66), (0, 52), (30, 10), (95, 10), (95, 50), (28, 50), (20, 66)],
              fill=C["red"], outline=C["outline"])
    for y in range(16, 50, 5):
        d.line((32, y, 94, y), fill=C["red_d"])
    d.line((30, 10, 30, 50), fill=C["outline"])
    window(d, 66, 58)
    window(d, 70, 24, 12, 10)
    for x, y in [(30, 64), (28, 72), (31, 80), (64, 84), (66, 78)]:
        d.ellipse((x - 3, y - 3, x + 3, y + 3), fill=C["leaf"], outline=C["leaf_d"])
        d.point((x, y - 1), C["red_l"])
    d.rectangle((10, 78, 20, 94), fill=C["wood"], outline=C["outline"])
    d.line((10, 84, 20, 84), fill=C["wood_d"])
    door(d, 48, 95, 26, 36, colour="leaf")
    return img


# --- Inside the tavern -----------------------------------------------------------------

def tavern_bar():
    """48 x 24: a length of bar, polished top, panelled front, a pump."""
    img, d = new(48, 24)
    d.rectangle((0, 6, 47, 23), fill=C["wood"], outline=C["outline"])
    d.rectangle((0, 4, 47, 8), fill=C["wood_l"], outline=C["outline"])
    for x in range(4, 46, 11):
        d.rectangle((x, 11, x + 7, 20), fill=C["wood_d"])
    d.rectangle((20, 0, 22, 5), fill=C["stone_l"], outline=C["outline"])
    d.rectangle((19, 0, 23, 1), fill=C["red"])
    return img


def tavern_table():
    """32 x 24: a round table with a stool either side, a jug on it."""
    img, d = new(32, 24)
    for x in (1, 25):
        d.ellipse((x, 14, x + 6, 18), fill=C["wood_l"], outline=C["outline"])
        d.line((x + 3, 18, x + 3, 23), fill=C["wood_d"])
    d.ellipse((6, 6, 25, 14), fill=C["wood_l"], outline=C["outline"])
    d.rectangle((14, 14, 17, 23), fill=C["wood_d"], outline=C["outline"])
    d.rectangle((13, 3, 17, 9), fill=C["stone_l"], outline=C["outline"])
    return img


def fireplace():
    """32 x 40: a stone inglenook with a fire in it and a beam over."""
    img, d = new(32, 40)
    d.rectangle((0, 4, 31, 39), fill=C["stone"], outline=C["outline"])
    for y in range(8, 39, 6):
        d.line((1, y, 30, y), fill=C["stone_d"])
    d.rectangle((0, 4, 31, 9), fill=C["wood_d"], outline=C["outline"])
    d.rectangle((6, 16, 25, 39), fill=C["dark"], outline=C["outline"])
    d.polygon([(9, 39), (12, 28), (15, 34), (17, 24), (20, 33), (23, 39)], fill=C["orange"])
    d.polygon([(13, 39), (16, 31), (19, 39)], fill=C["lamp"])
    d.rectangle((8, 36, 23, 39), fill=C["wood"])
    return img


def chalkboard():
    """32 x 24: a framed blackboard with chalk lines and a price."""
    img, d = new(32, 24)
    d.rectangle((0, 0, 31, 23), fill=C["wood"], outline=C["outline"])
    d.rectangle((2, 2, 29, 21), fill=C["chalk"])
    for y, w in ((5, 20), (9, 16), (13, 22), (17, 12)):
        d.line((5, y, 5 + w, y), fill=C["stone_l"])
    d.point((26, 17), C["orange_l"])
    return img


def dartboard():
    """16 x 24: a dartboard on its cabinet, darts in it."""
    img, d = new(16, 24)
    d.rectangle((0, 0, 15, 23), fill=C["wood_d"], outline=C["outline"])
    d.ellipse((1, 4, 14, 17), fill=C["dark"], outline=C["outline"])
    d.ellipse((3, 6, 12, 15), fill=C["red"])
    d.ellipse((5, 8, 10, 13), fill=C["wall"])
    d.ellipse((6, 9, 9, 12), fill=C["leaf"])
    d.point((7, 10), C["red_l"])
    for x, y in ((4, 7), (10, 12)):
        d.line((x, y, x + 2, y - 2), fill=C["stone_l"])
    return img


def barrels():
    """32 x 24: two barrels on their sides, taps in them."""
    img, d = new(32, 24)
    for x in (0, 16):
        d.ellipse((x, 4, x + 15, 23), fill=C["wood"], outline=C["outline"])
        d.ellipse((x + 3, 7, x + 12, 20), fill=C["wood_l"], outline=C["wood_d"])
        d.line((x + 1, 10, x + 14, 10), fill=C["stone_d"])
        d.line((x + 1, 17, x + 14, 17), fill=C["stone_d"])
        d.rectangle((x + 7, 12, x + 8, 15), fill=C["stone_l"])
    return img


# --- The tavern's food ---------------------------------------------------------------------

def ploughmans():
    """Bread, a wedge of cheese, a pickled onion, on a board."""
    img, d = new(16, 16)
    d.rectangle((1, 10, 14, 13), fill=C["wood_l"], outline=C["outline"])
    d.ellipse((2, 5, 8, 10), fill=C["orange_l"], outline=C["outline"])
    d.polygon([(8, 10), (14, 10), (14, 5)], fill=C["lamp"], outline=C["outline"])
    d.ellipse((5, 8, 8, 11), fill=C["wall"], outline=C["outline"])
    return img


def hotpot():
    """A brown pot, its lid of sliced potato, steam rising."""
    img, d = new(16, 16)
    d.rectangle((2, 8, 13, 14), fill=C["red_d"], outline=C["outline"])
    d.ellipse((2, 5, 13, 10), fill=C["orange_l"], outline=C["outline"])
    for x in (4, 7, 10):
        d.arc((x - 1, 6, x + 2, 9), 180, 360, fill=C["orange"])
    for x in (5, 9):
        d.line((x, 4, x + 1, 1), fill=C["stone_l"])
    return img


def fish_supper():
    """Battered fish and chips in paper."""
    img, d = new(16, 16)
    d.polygon([(1, 13), (8, 4), (15, 13)], fill=C["white"], outline=C["outline"])
    d.ellipse((3, 7, 12, 11), fill=C["orange_l"], outline=C["outline"])
    for x in (4, 7, 10, 12):
        d.line((x, 10, x + 1, 13), fill=C["lamp"])
    return img


def main():
    jobs = {
        "town/nell.png": nell,
        "town/tavern.png": tavern,
        "town/mayor_house.png": mayor_house,
        "town/town_hall.png": town_hall,
        "town/wren_cottage.png": wren_cottage,
        "lane/ivy_cottage.png": ivy_cottage,
        "town/tavern_bar.png": tavern_bar,
        "town/tavern_table.png": tavern_table,
        "town/fireplace.png": fireplace,
        "town/chalkboard.png": chalkboard,
        "town/dartboard.png": dartboard,
        "town/barrels.png": barrels,
        "dishes/ploughmans.png": ploughmans,
        "dishes/hotpot.png": hotpot,
        "dishes/fish_supper.png": fish_supper,
    }
    for path, make in jobs.items():
        make().save(OUT + path)
        print("wrote", OUT + path)


if __name__ == "__main__":
    main()
