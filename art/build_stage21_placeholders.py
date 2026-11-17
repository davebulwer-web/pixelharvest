"""Placeholder art for Stage 21 session 1 (DECISIONS 064), drawn in the palette
until Pixellab replaces it (Stage 23).

  assets/tilesets/ground_<season>.png, row 3, columns 1-6: the Cove's ground
                                            (GroundTiles.SAND, WET_SAND,
                                            ROCKPOOL, SEA, PIER, ROCKS), the
                                            same in every season
  assets/sprites/cove/lighthouse.png        the old lighthouse, 64 x 128 (the
                                            building size rule: a 26 x 38 px
                                            doorway on the middle two cells)
  assets/sprites/cove/tam_shed.png          Tam's fish shed, 128 x 96, a
                                            tarred catslide roof
  assets/sprites/cove/rosa_cottage.png      Rosa's cottage, 128 x 96, a hipped
                                            slate roof with a chimney
  assets/sprites/cove/tide_board.png        the harbour's tide board, 16 x 32
  assets/sprites/forage/<id>.png            16 x 16 each: the Cove's forage

Run from the project folder:  python art/build_stage21_placeholders.py
Safe to run again: it only ever writes the files above (art/build_ground.py
keeps row 3's columns 1-6 when it rebuilds the ground images).
"""
from PIL import Image, ImageDraw

C = {
    "outline": (46, 31, 26, 255), "dark": (34, 34, 43, 255),
    "stone_d": (68, 68, 79, 255), "stone": (113, 113, 126, 255), "stone_l": (212, 231, 245, 255),
    "wood_d": (74, 47, 34, 255), "wood": (107, 74, 47, 255), "wood_l": (138, 99, 64, 255),
    "paper_d": (171, 129, 108, 255), "paper": (200, 153, 123, 255), "paper_l": (245, 194, 186, 255),
    "wall": (255, 231, 216, 255), "wall_s": (245, 194, 186, 255),
    "red": (172, 59, 70, 255), "red_d": (143, 51, 63, 255), "red_l": (196, 73, 76, 255),
    "glass": (171, 220, 239, 255), "glass_d": (114, 149, 174, 255),
    "orange": (226, 101, 26, 255), "orange_l": (251, 160, 87, 255),
    "leaf_d": (47, 90, 43, 255), "leaf": (74, 127, 58, 255), "leaf_l": (111, 191, 74, 255),
    "olive": (110, 106, 44, 255), "olive_d": (79, 74, 34, 255),
    "white": (247, 253, 255, 255), "grey": (83, 67, 74, 255), "plum": (54, 46, 54, 255),
    "sea_d": (59, 54, 75, 255), "sea": (63, 78, 113, 255), "sea_m": (67, 84, 122, 255),
    "teal": (42, 122, 122, 255), "aqua": (79, 184, 172, 255), "pink": (189, 117, 118, 255),
    "brown": (120, 88, 83, 255), "mud": (74, 55, 55, 255), "lime": (168, 224, 107, 255),
}
T = (0, 0, 0, 0)


def new(w, h):
    img = Image.new("RGBA", (w, h), T)
    return img, ImageDraw.Draw(img)


def speckle(d, colour, seed, count, box=(0, 0, 15, 15)):
    """`count` single pixels of `colour`, placed the same way every run."""
    x0, y0, x1, y1 = box
    n = seed
    for _ in range(count):
        n = (n * 1103515245 + 12345) & 0x7FFFFFFF
        x = x0 + n % (x1 - x0 + 1)
        n = (n * 1103515245 + 12345) & 0x7FFFFFFF
        y = y0 + n % (y1 - y0 + 1)
        d.point((x, y), colour)


# --- Ground tiles (row 3, columns 1-6) ---------------------------------------

def sand():
    img, d = new(16, 16)
    d.rectangle((0, 0, 15, 15), fill=C["wall"])
    speckle(d, C["paper_l"], 3, 22)
    speckle(d, C["paper"], 7, 7)
    speckle(d, C["white"], 9, 4)
    return img


def wet_sand():
    img, d = new(16, 16)
    d.rectangle((0, 0, 15, 15), fill=C["paper"])
    speckle(d, C["paper_d"], 5, 16)
    # Ripples left by the tide.
    for y in (4, 11):
        d.line((1, y, 6, y), fill=C["paper_d"])
        d.line((9, y + 1, 14, y + 1), fill=C["paper_d"])
    speckle(d, C["glass_d"], 11, 3)
    return img


def rockpool():
    img, d = new(16, 16)
    d.rectangle((0, 0, 15, 15), fill=C["stone"])
    speckle(d, C["stone_d"], 13, 18)
    # A pool in the rock, off-centre (the tile is turned at random), with
    # weed at its edge.
    d.ellipse((2, 4, 10, 10), fill=C["teal"], outline=C["stone_d"])
    d.line((4, 6, 6, 6), fill=C["aqua"])
    d.ellipse((11, 10, 14, 13), fill=C["teal"], outline=C["stone_d"])
    d.point((4, 11), C["leaf"])
    d.point((11, 6), C["leaf"])
    d.point((12, 13), C["olive"])
    d.point((1, 2), C["stone_l"])
    d.point((14, 1), C["stone_l"])
    return img


def sea():
    img, d = new(16, 16)
    d.rectangle((0, 0, 15, 15), fill=C["sea"])
    speckle(d, C["sea_m"], 17, 20)
    # Short wave crests.
    d.line((2, 4, 5, 4), fill=C["glass_d"])
    d.line((10, 10, 13, 10), fill=C["glass_d"])
    d.point((3, 3), C["glass"])
    d.point((11, 9), C["glass"])
    return img


def pier():
    img, d = new(16, 16)
    d.rectangle((0, 0, 15, 15), fill=C["wood_l"])
    for y in (3, 7, 11, 15):
        d.line((0, y, 15, y), fill=C["wood_d"])
    for y, x in ((1, 5), (5, 11), (9, 3), (13, 9)):
        d.point((x, y), C["wood"])
    # Nail heads at the ends of the planks.
    for y in (1, 5, 9, 13):
        d.point((1, y), C["stone_d"])
        d.point((14, y), C["stone_d"])
    return img


def rocks():
    img, d = new(16, 16)
    d.rectangle((0, 0, 15, 15), fill=C["stone_d"])
    for box in ((0, 1, 8, 8), (7, 5, 15, 13), (1, 9, 7, 15)):
        d.ellipse(box, fill=C["stone"], outline=C["dark"])
    d.point((3, 3), C["stone_l"])
    d.point((10, 7), C["stone_l"])
    d.point((3, 11), C["stone_l"])
    return img


# --- Buildings ------------------------------------------------------------------

def doorway(d, left, top, right, bottom):
    """A plank door filling the opening from (left, top) to (right, bottom)."""
    d.rectangle((left, top, right, bottom), fill=C["wood_d"], outline=C["outline"])
    d.rectangle((left + 2, top + 2, right - 2, bottom), fill=C["wood"])
    for x in range(left + 5, right - 2, 4):
        d.line((x, top + 2, x, bottom), fill=C["wood_d"])
    d.point((right - 4, (top + bottom) // 2), C["orange"])


def lighthouse():
    """64 x 128: a white tower with a red band, a dark lamp room (the lamp has
    been out for years), on a stone foot. Doorway 26 x 38 across x 19-44."""
    img, d = new(64, 128)
    # The lamp room and its cap.
    d.polygon([(22, 10), (32, 1), (42, 10)], fill=C["red_d"], outline=C["outline"])
    d.rectangle((22, 10, 41, 24), fill=C["dark"], outline=C["outline"])
    d.line((26, 11, 26, 23), fill=C["stone_d"])
    d.line((32, 11, 32, 23), fill=C["stone_d"])
    d.line((37, 11, 37, 23), fill=C["stone_d"])
    d.rectangle((17, 24, 46, 27), fill=C["stone"], outline=C["outline"])
    # The tower, wider at the foot.
    d.polygon([(20, 28), (43, 28), (52, 100), (11, 100)], fill=C["wall"], outline=C["outline"])
    d.polygon([(22, 46), (41, 46), (43, 60), (20, 60)], fill=C["red"], outline=C["outline"])
    d.polygon([(16, 76), (47, 76), (49, 88), (14, 88)], fill=C["red"], outline=C["outline"])
    d.line((38, 30, 46, 98), fill=C["wall_s"])
    # Two small windows up the tower.
    d.rectangle((29, 34, 34, 41), fill=C["glass_d"], outline=C["outline"])
    d.rectangle((29, 64, 34, 71), fill=C["glass_d"], outline=C["outline"])
    # The stone foot.
    d.rectangle((4, 96, 59, 127), fill=C["stone"], outline=C["outline"])
    for y in (103, 111, 119):
        d.line((5, y, 58, y), fill=C["stone_d"])
    for y, xs in ((99, (14, 30, 48)), (107, (8, 24, 52)), (115, (16, 46)), (123, (10, 52))):
        for x in xs:
            d.line((x, y - 3, x, y + 3), fill=C["stone_d"])
    doorway(d, 19, 89, 44, 127)
    return img


def tam_shed():
    """128 x 96: a tarred wooden fish shed with a catslide roof sweeping down
    to the right over a lean-to, nets hung on the wall, crab pots stacked.
    Doorway 28 x 38 across the middle two cells (x 50-77)."""
    img, d = new(128, 96)
    # The wall: dark tarred boards.
    d.rectangle((6, 44, 121, 95), fill=C["plum"], outline=C["outline"])
    for x in range(10, 121, 6):
        d.line((x, 45, x, 94), fill=C["dark"])
    # The roof: a gable on the left, sweeping long and low to the right.
    d.polygon([(0, 48), (34, 6), (60, 6), (127, 54), (127, 60), (0, 54)],
              fill=C["stone_d"], outline=C["outline"])
    for y in range(12, 56, 6):
        d.line((4, y + 38 - min(y, 38), 124, y + 6), fill=C["dark"])
    d.line((34, 7, 60, 7), fill=C["stone"])
    # A tin chimney.
    d.rectangle((40, 0, 45, 10), fill=C["stone"], outline=C["outline"])
    # A window on the left with a lamp in it.
    d.rectangle((16, 60, 35, 76), fill=C["wood"], outline=C["outline"])
    d.rectangle((18, 62, 33, 74), fill=C["glass_d"])
    d.line((25, 62, 25, 74), fill=C["wood"])
    # Nets hung on the right of the wall.
    for x in range(88, 116, 4):
        d.line((x, 62, x + 4, 84), fill=C["paper_d"])
        d.line((x + 4, 62, x, 84), fill=C["paper_d"])
    d.line((86, 61, 118, 61), fill=C["wood_l"])
    # A buoy and a sign.
    d.ellipse((38, 80, 45, 87), fill=C["red_l"], outline=C["outline"])
    d.rectangle((48, 46, 79, 54), fill=C["wood_l"], outline=C["outline"])
    d.line((53, 50, 74, 50), fill=C["teal"])
    doorway(d, 50, 57, 77, 95)
    return img


def rosa_cottage():
    """128 x 96: a whitewashed cottage with a hipped slate roof, a chimney,
    blue shutters and a geranium box. Doorway 26 x 38 across x 51-76."""
    img, d = new(128, 96)
    d.rectangle((14, 7, 23, 26), fill=C["stone"], outline=C["outline"])
    d.rectangle((12, 4, 25, 8), fill=C["stone_d"], outline=C["outline"])
    d.rectangle((6, 44, 121, 95), fill=C["wall"], outline=C["outline"])
    d.rectangle((7, 90, 120, 94), fill=C["wall_s"])
    # Hipped roof: slopes on every side, slate grey.
    d.polygon([(0, 48), (30, 10), (97, 10), (127, 48)], fill=C["sea_m"], outline=C["outline"])
    for y in range(15, 48, 5):
        inset = int((48 - y) * 30 / 38)
        d.line((inset + 1, y, 126 - inset, y), fill=C["sea"])
    d.line((30, 11, 97, 11), fill=C["glass_d"])
    # Windows with blue shutters.
    for x in (18, 90):
        d.rectangle((x, 58, x + 19, 76), fill=C["glass"], outline=C["outline"])
        d.line((x + 9, 58, x + 9, 76), fill=C["glass_d"])
        d.rectangle((x - 5, 58, x - 1, 76), fill=C["teal"], outline=C["outline"])
        d.rectangle((x + 20, 58, x + 24, 76), fill=C["teal"], outline=C["outline"])
        d.rectangle((x - 1, 78, x + 20, 81), fill=C["wood"], outline=C["outline"])
        for fx in range(x + 1, x + 20, 3):
            d.point((fx, 77), C["red_l"])
            d.point((fx + 1, 77), C["leaf_l"])
    doorway(d, 51, 57, 76, 95)
    return img


def tide_board():
    """16 x 32: a board on a post, painted with a wave and a clock face."""
    img, d = new(16, 32)
    d.rectangle((7, 14, 8, 31), fill=C["wood"], outline=C["outline"])
    d.rectangle((0, 1, 15, 15), fill=C["wall"], outline=C["outline"])
    d.rectangle((1, 2, 14, 4), fill=C["teal"])
    d.line((2, 10, 4, 8), fill=C["sea"])
    d.line((4, 8, 6, 10), fill=C["sea"])
    d.line((6, 10, 8, 8), fill=C["sea"])
    d.ellipse((9, 6, 14, 11), fill=C["white"], outline=C["outline"])
    d.line((11, 8, 11, 9), fill=C["outline"])
    d.line((2, 13, 13, 13), fill=C["paper_d"])
    return img


# --- Forage icons -----------------------------------------------------------------

def seashell():
    """A scallop: a fan of ridges from the hinge at the bottom."""
    img, d = new(16, 16)
    d.pieslice((0, 1, 16, 25), 200, 340, fill=C["paper_l"], outline=C["outline"])
    d.rectangle((6, 11, 10, 13), fill=C["paper"], outline=C["outline"])
    for x in (3, 6, 10, 13):
        d.line((8, 11, x, 4), fill=C["pink"])
    return img


def sea_glass():
    img, d = new(16, 16)
    d.polygon([(4, 6), (9, 3), (12, 7), (10, 12), (5, 11)], fill=C["aqua"], outline=C["teal"])
    d.point((7, 6), C["white"])
    d.point((8, 5), C["glass"])
    return img


def seaweed():
    img, d = new(16, 16)
    for x, lean in ((5, -1), (8, 1), (11, 0)):
        d.line((x, 14, x + lean, 3), fill=C["olive"], width=2)
        d.point((x + lean, 6), C["olive_d"])
        d.ellipse((x - 1 + lean, 7, x + 1 + lean, 9), fill=C["olive_d"])
    return img


def samphire():
    img, d = new(16, 16)
    d.line((8, 14, 8, 4), fill=C["leaf"], width=2)
    for y, side in ((6, -1), (8, 1), (10, -1)):
        d.line((8, y + 1, 8 + side * 4, y - 2), fill=C["leaf_l"], width=2)
    d.point((8, 3), C["lime"])
    return img


def driftwood():
    img, d = new(16, 16)
    d.line((1, 11, 14, 5), fill=C["paper_d"], width=4)
    d.line((2, 10, 13, 5), fill=C["stone_l"])
    d.line((9, 7, 12, 11), fill=C["paper_d"], width=2)
    d.point((4, 10), C["brown"])
    return img


def shrimp():
    img, d = new(16, 16)
    d.arc((3, 3, 13, 13), 120, 400, fill=C["orange_l"], width=3)
    d.point((11, 5), C["outline"])
    d.line((12, 4, 15, 1), fill=C["orange"])
    d.line((4, 12, 2, 14), fill=C["orange"])
    return img


def mussels():
    img, d = new(16, 16)
    for box in ((2, 5, 8, 14), (7, 3, 13, 12)):
        d.ellipse(box, fill=C["sea_d"], outline=C["dark"])
    d.line((4, 7, 6, 12), fill=C["sea"])
    d.line((9, 5, 11, 10), fill=C["sea"])
    return img


def winkles():
    img, d = new(16, 16)
    for cx, cy in ((5, 9), (11, 10), (8, 5)):
        d.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), fill=C["mud"], outline=C["dark"])
        d.point((cx, cy), C["brown"])
        d.point((cx + 1, cy - 1), C["paper_d"])
    return img


def shore_crab():
    img, d = new(16, 16)
    d.ellipse((3, 6, 12, 12), fill=C["olive"], outline=C["outline"])
    d.ellipse((1, 3, 4, 6), fill=C["olive"], outline=C["outline"])
    d.ellipse((11, 3, 14, 6), fill=C["olive"], outline=C["outline"])
    for x in (3, 5, 10, 12):
        d.line((x, 12, x - 1 if x < 8 else x + 1, 14), fill=C["outline"])
    d.point((6, 7), C["dark"])
    d.point((9, 7), C["dark"])
    return img


def oyster():
    img, d = new(16, 16)
    d.polygon([(2, 9), (6, 4), (12, 3), (14, 8), (10, 13), (4, 13)], fill=C["stone"], outline=C["outline"])
    d.line((4, 10, 12, 6), fill=C["stone_l"])
    d.ellipse((7, 7, 10, 10), fill=C["white"])
    return img


def save(img, path):
    img.save(path)
    print("built", path)


if __name__ == "__main__":
    tiles = [sand(), wet_sand(), rockpool(), sea(), pier(), rocks()]
    for season in ["spring", "summer", "autumn", "winter"]:
        path = f"assets/tilesets/ground_{season}.png"
        ground = Image.open(path).convert("RGBA")
        for i, tile in enumerate(tiles):
            ground.paste(tile, ((i + 1) * 16, 48))
        save(ground, path)
    save(lighthouse(), "assets/sprites/cove/lighthouse.png")
    save(tam_shed(), "assets/sprites/cove/tam_shed.png")
    save(rosa_cottage(), "assets/sprites/cove/rosa_cottage.png")
    save(tide_board(), "assets/sprites/cove/tide_board.png")
    for name, draw in [("seashell", seashell), ("sea_glass", sea_glass), ("seaweed", seaweed),
                       ("samphire", samphire), ("driftwood", driftwood), ("shrimp", shrimp),
                       ("mussels", mussels), ("winkles", winkles), ("shore_crab", shore_crab),
                       ("oyster", oyster)]:
        save(draw(), f"assets/sprites/forage/{name}.png")
