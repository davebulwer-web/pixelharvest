"""Placeholder art for Stage 19 session 2 (DECISIONS 061), drawn in the palette
until Pixellab replaces it (Stage 23). The two buildings are drawn at the new
building size (art/STYLE.md, "Buildings"): 128 x 96, roof about 45% of the
height, a door opening of at least 24 x 36 px in the middle of the bottom row.

  assets/sprites/lane/pip_cottage.png   Pip's family's cottage: thatched
  assets/sprites/lane/dot_yard.png      Dot the carrier's shed: catslide roof,
                                        wide double doors
  assets/sprites/lane/cart.png          Dot's cart, in her yard
  assets/sprites/farm/old_well.png      the old well, found while clearing
  assets/sprites/items/rusty_tool_head.png

Run from the project folder:  python art/build_stage19_s2_placeholders.py
"""
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
    "rust_d": (143, 51, 63, 255), "rust": (226, 101, 26, 255), "rust_l": (251, 160, 87, 255),
    "leaf_d": (47, 90, 43, 255), "leaf": (74, 127, 58, 255), "red": (172, 59, 70, 255),
    "brick": (143, 51, 63, 255), "brick_l": (196, 73, 76, 255),
}
T = (0, 0, 0, 0)


def new(w, h):
    img = Image.new("RGBA", (w, h), T)
    return img, ImageDraw.Draw(img)


def window(d, x, y, w=14, h=14):
    """A four-pane window with a frame and a sill, top-left at (x, y)."""
    d.rectangle((x, y, x + w - 1, y + h - 1), fill=C["glass"], outline=C["outline"])
    d.line((x + w // 2, y, x + w // 2, y + h - 1), fill=C["wood"])
    d.line((x, y + h // 2, x + w - 1, y + h // 2), fill=C["wood"])
    d.rectangle((x + 1, y + 1, x + w // 2 - 1, y + 3), fill=C["stone_l"])
    d.rectangle((x - 1, y + h, x + w, y + h + 1), fill=C["wood_l"], outline=C["outline"])


def door(d, cx, bottom, w, h, double=False):
    """A wooden door, its opening w x h, centred on cx, standing on bottom."""
    x0, x1 = cx - w // 2, cx + w // 2 - 1
    y0 = bottom - h + 1
    d.rectangle((x0 - 2, y0 - 2, x1 + 2, bottom), fill=C["wood_d"], outline=C["outline"])
    d.rectangle((x0, y0, x1, bottom), fill=C["wood"])
    for x in range(x0 + 3, x1, 4):
        d.line((x, y0 + 1, x, bottom), fill=C["wood_d"])
    if double:
        d.line((cx - 1, y0, cx - 1, bottom), fill=C["outline"])
        d.line((x0, y0, cx - 2, bottom), fill=C["wood_l"])
        d.line((x1, y0, cx, bottom), fill=C["wood_l"])
        d.point((cx - 4, (y0 + bottom) // 2), C["rust_l"])
        d.point((cx + 2, (y0 + bottom) // 2), C["rust_l"])
    else:
        d.rectangle((x1 - 4, (y0 + bottom) // 2, x1 - 3, (y0 + bottom) // 2 + 1), fill=C["rust_l"])
    d.line((x0 - 3, bottom, x1 + 3, bottom), fill=C["stone"])


def pip_cottage():
    """128 x 96. Thatched, rounded eaves, a brick chimney, cream walls."""
    img, d = new(128, 96)
    wall_top = 48
    # Walls, with a shaded band under the eaves and down the right.
    d.rectangle((8, wall_top, 119, 95), fill=C["wall"], outline=C["outline"])
    d.rectangle((9, wall_top + 1, 118, wall_top + 4), fill=C["wall_s"])
    d.rectangle((112, wall_top + 1, 118, 94), fill=C["wall_s"])
    d.line((9, 94, 118, 94), fill=C["wall_d"])
    # Chimney behind the thatch, on the left.
    d.rectangle((22, 4, 33, 30), fill=C["brick"], outline=C["outline"])
    d.rectangle((20, 2, 35, 6), fill=C["brick_l"], outline=C["outline"])
    for y in (12, 18, 24):
        d.line((23, y, 32, y), fill=C["wall_d"])
    # Thatch: a fat rounded hood, darker underneath, ridge on top.
    d.rounded_rectangle((2, 12, 125, 54), radius=14, fill=C["thatch"], outline=C["outline"])
    d.rounded_rectangle((10, 6, 117, 26), radius=8, fill=C["thatch_l"], outline=C["outline"])
    d.line((14, 8, 113, 8), fill=C["thatch"])
    for x in range(8, 122, 6):
        d.line((x, 30, x + 2, 50), fill=C["thatch_d"])
    d.line((5, 52, 122, 52), fill=C["thatch_d"])
    # An eyebrow over the upstairs window.
    d.rounded_rectangle((52, 22, 76, 40), radius=6, fill=C["thatch_l"], outline=C["outline"])
    window(d, 57, 28, 14, 10)
    # Ground-floor windows either side of the door, and the door: opening 24 x 36.
    window(d, 20, 62)
    window(d, 94, 62)
    door(d, 64, 95, 24, 36)
    # Roses by the door (painted on, so nothing stands in the doorway).
    for x, y in [(44, 86), (46, 82), (82, 84), (84, 88)]:
        d.ellipse((x - 3, y - 3, x + 3, y + 3), fill=C["leaf"], outline=C["leaf_d"])
        d.point((x, y - 1), C["red"])
    return img


def dot_yard():
    """128 x 96. A timber carrier's shed with a catslide roof: the slate roof
    sweeps low over a lean-to on the left. Wide double doors, opening 32 x 40."""
    img, d = new(128, 96)
    # Plank walls.
    d.rectangle((6, 46, 121, 95), fill=C["wood_l"], outline=C["outline"])
    for y in range(50, 95, 5):
        d.line((7, y, 120, y), fill=C["wood"])
    d.rectangle((114, 47, 120, 94), fill=C["wood"])
    # Catslide: the main roof high on the right, sweeping low over the
    # lean-to on the left.
    d.polygon([(2, 66), (2, 52), (40, 12), (124, 12), (124, 48), (40, 48), (30, 66)],
              fill=C["slate"], outline=C["outline"])
    d.polygon([(40, 12), (124, 12), (124, 16), (40, 16)], fill=C["slate_l"])
    for y in range(20, 48, 6):
        d.line((44, y, 123, y), fill=C["slate_d"])
    for i, y in enumerate(range(24, 64, 6)):
        x = max(3, 36 - (y - 18))
        d.line((x, y, 38, y), fill=C["slate_d"])
    d.line((40, 12, 40, 48), fill=C["outline"])
    d.line((30, 66, 40, 48), fill=C["outline"])
    # A small window in the lean-to, and a stove pipe.
    window(d, 12, 72, 10, 10)
    d.rectangle((100, 2, 105, 14), fill=C["stone_d"], outline=C["outline"])
    # Painted board over the doors (the words are Stage 23's), and the doors in the middle, where the doorway is.
    d.rectangle((40, 50, 96, 57), fill=C["wall"], outline=C["outline"])
    d.line((44, 53, 92, 53), fill=C["slate"])
    d.line((48, 55, 88, 55), fill=C["slate"])
    door(d, 64, 95, 32, 38, double=True)
    return img


def cart():
    """32 x 24: a two-wheeled carrier's cart, shafts down, seen side on."""
    img, d = new(32, 24)
    d.line((0, 18, 8, 13), fill=C["wood_d"], width=2)
    d.rectangle((6, 5, 29, 14), fill=C["wood_l"], outline=C["outline"])
    d.line((7, 9, 28, 9), fill=C["wood"])
    d.rectangle((9, 2, 15, 6), fill=C["thatch"], outline=C["outline"])  # a parcel
    d.rectangle((17, 3, 24, 6), fill=C["wall_s"], outline=C["outline"])
    d.line((20, 3, 20, 6), fill=C["red"])
    d.ellipse((12, 11, 24, 23), fill=C["wood"], outline=C["outline"])
    d.ellipse((16, 15, 20, 19), fill=C["wood_d"])
    for p in [(18, 12), (18, 22), (13, 17), (23, 17)]:
        d.line((18, 17) + p, fill=C["wood_d"])
    return img


def old_well():
    """16 x 24: a round stone well, capped with an old wooden cover."""
    img, d = new(16, 24)
    d.rectangle((1, 9, 14, 22), fill=C["stone"], outline=C["outline"])
    for y in (13, 17):
        d.line((2, y, 13, y), fill=C["stone_d"])
    for x, y in [(5, 10), (9, 14), (4, 18), (11, 18), (8, 10)]:
        d.line((x, y, x, y + 2), fill=C["stone_d"])
    d.ellipse((0, 5, 15, 13), fill=C["stone_l"], outline=C["outline"])
    d.ellipse((2, 6, 13, 12), fill=C["wood"], outline=C["wood_d"])
    d.line((3, 9, 12, 9), fill=C["wood_d"])
    d.rectangle((6, 7, 9, 8), fill=C["rust"])
    d.line((1, 22, 14, 22), fill=C["stone_d"])
    return img


def rusty_tool_head():
    """16 x 16: an old axe head, rusted, no handle."""
    img, d = new(16, 16)
    d.polygon([(3, 4), (9, 4), (14, 1), (14, 14), (9, 11), (3, 11)], fill=C["rust"], outline=C["outline"])
    d.rectangle((3, 6, 6, 9), fill=C["dark"])  # the eye, where the handle went
    d.line((13, 2, 13, 13), fill=C["rust_l"])
    for p in [(8, 6), (10, 9), (11, 5), (7, 10)]:
        d.point(p, C["rust_d"])
    return img


if __name__ == "__main__":
    pip_cottage().save(OUT + "lane/pip_cottage.png")
    dot_yard().save(OUT + "lane/dot_yard.png")
    cart().save(OUT + "lane/cart.png")
    old_well().save(OUT + "farm/old_well.png")
    rusty_tool_head().save(OUT + "items/rusty_tool_head.png")
