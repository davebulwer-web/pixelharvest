"""Placeholder art for Stage 20 session 2 (DECISIONS 063), drawn in the palette
until Pixellab replaces it (Stage 23 and 24).

  assets/sprites/farm/workbench.png         the old farmer's workbench under
                                            a lean-to, 16 x 24: a plank roof,
                                            the bench with a saw and a mallet
  assets/sprites/farm/workbench_broken.png  the same, one leg short and
                                            tipped, nothing on it
  assets/sprites/decorations/stone_wall.png a length of dry-stone wall, 16 x 16
  assets/sprites/decorations/bird_box.png   a bird box on a post, 16 x 32
  assets/sprites/decorations/log_pile.png   a stack of logs, 16 x 16
  assets/sprites/town/bakery.png            Mabel's bakery, 96 x 96 (the
                                            building size rule: a 28 x 36 px
                                            doorway on two cells, a steep red
                                            tiled roof with a chimney, a bow
                                            window full of bread)
  assets/sprites/dishes/bread_roll.png      16 x 16 each: the bakery's goods
  assets/sprites/dishes/cheese_scone.png
  assets/sprites/dishes/fruit_loaf.png
  assets/sprites/dishes/pasty.png

Run from the project folder:  python art/build_stage20_s2_placeholders.py
"""
from PIL import Image, ImageDraw

OUT = "assets/sprites/"
C = {
    "outline": (46, 31, 26, 255), "dark": (34, 34, 43, 255),
    "stone_d": (68, 68, 79, 255), "stone": (113, 113, 126, 255), "stone_l": (212, 231, 245, 255),
    "wood_d": (74, 47, 34, 255), "wood": (107, 74, 47, 255), "wood_l": (138, 99, 64, 255),
    "paper_d": (171, 129, 108, 255), "paper": (200, 153, 123, 255), "paper_l": (245, 194, 186, 255),
    "wall": (255, 231, 216, 255), "wall_s": (245, 194, 186, 255),
    "red": (172, 59, 70, 255), "red_d": (143, 51, 63, 255), "red_l": (196, 73, 76, 255),
    "brown_d": (96, 41, 52, 255), "glass": (171, 220, 239, 255), "glass_d": (114, 149, 174, 255),
    "orange": (226, 101, 26, 255), "orange_l": (251, 160, 87, 255),
    "leaf": (74, 127, 58, 255), "leaf_l": (111, 191, 74, 255), "olive": (110, 106, 44, 255),
    "white": (247, 253, 255, 255), "grey": (83, 67, 74, 255),
}
T = (0, 0, 0, 0)


def new(w, h):
    img = Image.new("RGBA", (w, h), T)
    return img, ImageDraw.Draw(img)


def workbench(broken=False):
    """16 x 24: a lean-to's plank roof on two posts, the bench under it."""
    img, d = new(16, 24)
    # Back board (the lean-to's wall) and its roof.
    d.rectangle((1, 4, 14, 15), fill=C["wood_d"], outline=C["outline"])
    for y in (7, 10, 13):
        d.line((2, y, 13, y), fill=C["wood"])
    d.polygon([(0, 5), (15, 5), (15, 2), (0, 0)], fill=C["wood_l"], outline=C["outline"])
    if not broken:
        # Tools hung on the board: a saw and a mallet.
        d.line((3, 8, 7, 8), fill=C["stone_l"])
        d.line((3, 9, 7, 9), fill=C["stone"])
        d.rectangle((8, 7, 9, 9), fill=C["wood"])
        d.rectangle((11, 7, 13, 9), fill=C["wood_l"], outline=C["outline"])
        d.line((12, 10, 12, 12), fill=C["wood"])
    # The bench top and legs.
    if broken:
        d.polygon([(1, 15), (14, 18), (14, 20), (1, 17)], fill=C["wood_l"], outline=C["outline"])
        d.rectangle((2, 17, 3, 23), fill=C["wood"], outline=C["outline"])
        d.rectangle((12, 20, 13, 22), fill=C["wood"], outline=C["outline"])  # the short leg
    else:
        d.rectangle((0, 15, 15, 18), fill=C["wood_l"], outline=C["outline"])
        d.line((1, 16, 14, 16), fill=C["paper"])
        d.rectangle((2, 18, 3, 23), fill=C["wood"], outline=C["outline"])
        d.rectangle((12, 18, 13, 23), fill=C["wood"], outline=C["outline"])
        # The stones propping the mended leg.
        d.rectangle((11, 22, 14, 23), fill=C["stone"], outline=C["stone_d"])
        # A plank and a coil of twine on the bench.
        d.rectangle((3, 13, 8, 14), fill=C["paper"], outline=C["outline"])
        d.ellipse((10, 12, 13, 14), fill=C["olive"], outline=C["outline"])
    return img


def stone_wall():
    """16 x 16: a short run of dry-stone wall, flat stones in courses."""
    img, d = new(16, 16)
    d.rectangle((0, 5, 15, 15), fill=C["stone"], outline=C["outline"])
    for row, y in enumerate((5, 8, 11)):
        x = 0 if row % 2 == 0 else -3
        while x < 16:
            d.rectangle((max(0, x), y, min(15, x + 5), y + 3), fill=C["stone"], outline=C["stone_d"])
            d.line((max(1, x + 1), y + 1, min(14, x + 4), y + 1), fill=C["stone_l"])
            x += 6
    d.rectangle((0, 3, 15, 5), fill=C["stone_d"], outline=C["outline"])  # the cope stones
    for x in (1, 5, 9, 13):
        d.line((x, 3, x, 5), fill=C["stone"])
    return img


def bird_box():
    """16 x 32: a bird box with a sloping lid on a tall post."""
    img, d = new(16, 32)
    d.rectangle((7, 14, 8, 31), fill=C["wood"], outline=C["outline"])
    d.rectangle((3, 6, 12, 15), fill=C["wood_l"], outline=C["outline"])
    d.polygon([(1, 7), (8, 2), (14, 7)], fill=C["wood_d"], outline=C["outline"])
    d.ellipse((6, 8, 9, 11), fill=C["dark"])
    d.point((7, 13), C["wood_d"])
    d.line((4, 14, 11, 14), fill=C["wood"])
    return img


def log_pile():
    """16 x 16: logs stacked three, two, one, cut ends showing."""
    img, d = new(16, 16)
    for cx, cy in [(3, 12), (8, 12), (13, 12), (5, 8), (10, 8), (8, 4)]:
        d.ellipse((cx - 3, cy - 3, cx + 2, cy + 2), fill=C["paper"], outline=C["wood_d"])
        d.point((cx, cy), C["wood_l"])
        d.point((cx - 1, cy - 1), C["paper_d"])
    return img


def bakery():
    """96 x 96: Mabel's bakery. A steep red tiled roof (the top 44 px) with a
    chimney, a cream wall, a bow window of loaves on the left, a sign over
    the door, the doorway (28 x 36 px) across the middle two cells."""
    img, d = new(96, 96)
    # Chimney first, so the roof overlaps its foot.
    d.rectangle((68, 2, 77, 18), fill=C["red_d"], outline=C["outline"])
    d.rectangle((67, 1, 78, 4), fill=C["stone"], outline=C["outline"])
    # The wall.
    d.rectangle((4, 42, 91, 95), fill=C["wall"], outline=C["outline"])
    d.rectangle((5, 90, 90, 94), fill=C["wall_s"])
    # The roof: a steep gable seen from the front, tiles in rows.
    d.polygon([(0, 46), (14, 8), (81, 8), (95, 46)], fill=C["red"], outline=C["outline"])
    for y in range(13, 46, 5):
        inset = int((46 - y) * 14 / 38)
        d.line((inset + 1, y, 94 - inset, y), fill=C["red_d"])
        for x in range(inset + 4 + (y // 5 % 2) * 3, 94 - inset, 6):
            d.point((x, y - 1), C["red_l"])
    d.line((14, 9, 81, 9), fill=C["red_l"])
    # A little dormer in the roof.
    d.rectangle((40, 18, 55, 32), fill=C["wall"], outline=C["outline"])
    d.polygon([(37, 20), (47, 12), (58, 20)], fill=C["red_d"], outline=C["outline"])
    d.rectangle((43, 22, 52, 30), fill=C["glass"], outline=C["outline"])
    d.line((47, 22, 47, 30), fill=C["outline"])
    # The bow window, full of bread.
    d.rectangle((8, 54, 31, 80), fill=C["wood_d"], outline=C["outline"])
    d.rectangle((10, 56, 29, 76), fill=C["glass"])
    d.line((16, 56, 16, 76), fill=C["glass_d"])
    d.line((23, 56, 23, 76), fill=C["glass_d"])
    for x, y in [(11, 68), (18, 66), (24, 69), (13, 73), (21, 73)]:
        d.ellipse((x, y, x + 5, y + 3), fill=C["orange_l"], outline=C["paper_d"])
    d.rectangle((7, 80, 32, 82), fill=C["wood"], outline=C["outline"])
    # A second window right of the door.
    d.rectangle((66, 56, 85, 74), fill=C["wood_d"], outline=C["outline"])
    d.rectangle((68, 58, 83, 72), fill=C["glass"])
    d.line((75, 58, 75, 72), fill=C["glass_d"])
    d.line((68, 65, 83, 65), fill=C["glass_d"])
    # The sign over the door: a loaf on a board.
    d.rectangle((34, 44, 61, 53), fill=C["wood"], outline=C["outline"])
    d.ellipse((41, 46, 54, 51), fill=C["orange_l"], outline=C["paper_d"])
    d.line((44, 48, 51, 48), fill=C["paper"])
    # The doorway: 28 x 36 px, two cells across the middle (x 34-61).
    d.rectangle((34, 59, 61, 95), fill=C["wood_d"], outline=C["outline"])
    d.rectangle((36, 61, 59, 95), fill=C["wood"])
    d.line((47, 61, 47, 95), fill=C["wood_d"])
    d.line((48, 61, 48, 95), fill=C["wood_d"])
    d.rectangle((38, 64, 45, 72), fill=C["glass"], outline=C["wood_d"])
    d.rectangle((50, 64, 57, 72), fill=C["glass"], outline=C["wood_d"])
    d.point((45, 80), C["orange"])
    d.point((50, 80), C["orange"])
    # Flower boxes by the step.
    for x in (6, 66):
        d.rectangle((x, 84, x + 22, 88), fill=C["wood"], outline=C["outline"])
        for fx in range(x + 2, x + 21, 4):
            d.point((fx, 83), C["leaf_l"])
            d.point((fx + 1, 82), C["red_l"])
    return img


def bread_roll():
    img, d = new(16, 16)
    d.ellipse((2, 5, 13, 13), fill=C["orange_l"], outline=C["outline"])
    d.arc((4, 6, 11, 10), 200, 340, fill=C["wall"])
    d.line((5, 11, 10, 11), fill=C["orange"])
    return img


def cheese_scone():
    img, d = new(16, 16)
    d.rectangle((3, 6, 12, 13), fill=C["paper"], outline=C["outline"])
    d.ellipse((3, 3, 12, 8), fill=C["orange_l"], outline=C["outline"])
    d.point((6, 5), C["orange"])
    d.point((9, 4), C["orange"])
    d.line((4, 9, 11, 9), fill=C["paper_l"])
    return img


def fruit_loaf():
    img, d = new(16, 16)
    d.rectangle((1, 5, 14, 13), fill=C["wood_l"], outline=C["outline"])
    d.rectangle((2, 5, 13, 7), fill=C["wood"])
    for x, y in [(4, 9), (8, 10), (11, 8), (6, 12), (12, 11)]:
        d.point((x, y), C["brown_d"])
    return img


def pasty():
    img, d = new(16, 16)
    d.chord((1, 3, 14, 18), 180, 360, fill=C["orange_l"], outline=C["outline"])
    d.line((1, 10, 14, 10), fill=C["outline"])
    for x in range(3, 13, 2):
        d.point((x, 9), C["orange"])
    d.line((4, 6, 10, 6), fill=C["wall"])
    return img


if __name__ == "__main__":
    workbench().save(OUT + "farm/workbench.png")
    workbench(broken=True).save(OUT + "farm/workbench_broken.png")
    stone_wall().save(OUT + "decorations/stone_wall.png")
    bird_box().save(OUT + "decorations/bird_box.png")
    log_pile().save(OUT + "decorations/log_pile.png")
    bakery().save(OUT + "town/bakery.png")
    bread_roll().save(OUT + "dishes/bread_roll.png")
    cheese_scone().save(OUT + "dishes/cheese_scone.png")
    fruit_loaf().save(OUT + "dishes/fruit_loaf.png")
    pasty().save(OUT + "dishes/pasty.png")
