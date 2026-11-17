"""Placeholder art for Stage 21 session 2 (DECISIONS 065), drawn in the palette
until Pixellab replaces it (Stage 23).

  assets/sprites/cove/tam.png               Tam, 56 x 56: the angler's figure
                                            in a navy fisherman's jumper and a
                                            yellow oilskin hat
  assets/sprites/cove/crab_pot_empty.png    a crab pot's float, 16 x 16: slack,
  assets/sprites/cove/crab_pot_set.png      on a taut line (baited),
  assets/sprites/cove/crab_pot_ready.png    and with its flag up (ready to haul)
  assets/sprites/items/handline.png         16 x 16: Tam's handline frame
  assets/sprites/items/crab_pot.png         16 x 16: a crab pot
  assets/sprites/items/brown_crab.png       16 x 16
  assets/sprites/items/lobster.png          16 x 16
  assets/sprites/fish/<id>.png              16 x 16 each: the eleven sea fish

Run from the project folder:  python art/build_stage21_s2_placeholders.py
Safe to run again: it only ever writes the files above.
"""
import colorsys

from PIL import Image, ImageDraw

C = {
    "outline": (46, 31, 26, 255), "dark": (34, 34, 43, 255),
    "stone_d": (68, 68, 79, 255), "stone": (113, 113, 126, 255), "stone_l": (212, 231, 245, 255),
    "wood_d": (74, 47, 34, 255), "wood": (107, 74, 47, 255), "wood_l": (138, 99, 64, 255),
    "paper_d": (171, 129, 108, 255), "paper": (200, 153, 123, 255), "paper_l": (245, 194, 186, 255),
    "wall": (255, 231, 216, 255),
    "red": (172, 59, 70, 255), "red_d": (143, 51, 63, 255), "red_l": (196, 73, 76, 255),
    "glass": (171, 220, 239, 255), "glass_d": (114, 149, 174, 255),
    "orange": (226, 101, 26, 255), "orange_l": (251, 160, 87, 255),
    "leaf_d": (47, 90, 43, 255), "leaf": (74, 127, 58, 255), "leaf_l": (111, 191, 74, 255),
    "olive": (110, 106, 44, 255), "olive_d": (79, 74, 34, 255),
    "white": (247, 253, 255, 255), "grey": (83, 67, 74, 255), "plum": (54, 46, 54, 255),
    "sea_d": (59, 54, 75, 255), "sea": (63, 78, 113, 255), "sea_m": (67, 84, 122, 255),
    "teal": (42, 122, 122, 255), "aqua": (79, 184, 172, 255), "pink": (189, 117, 118, 255),
    "brown": (120, 88, 83, 255), "mud": (74, 55, 55, 255), "lime": (168, 224, 107, 255),
    "yellow": (251, 160, 87, 255),
}
T = (0, 0, 0, 0)
OUT = "assets/sprites/"


def new(w, h):
    img = Image.new("RGBA", (w, h), T)
    return img, ImageDraw.Draw(img)


# --- Tam ----------------------------------------------------------------------

def tam():
    """The angler's figure (56 x 56), clothes turned a navy fisherman's
    jumper and the straw hat a yellow oilskin."""
    img = Image.open(OUT + "town/angler.png").convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if 0.2 < h < 0.6 and s > 0.2:
                rr, gg, bb = colorsys.hsv_to_rgb(0.64, min(1.0, s + 0.2), v * 0.7)
                px[x, y] = (int(rr * 255), int(gg * 255), int(bb * 255), a)
            elif y < 22 and 0.05 < h < 0.15 and s > 0.25 and v > 0.45:
                rr, gg, bb = colorsys.hsv_to_rgb(0.13, 0.75, min(1.0, v * 1.1))
                px[x, y] = (int(rr * 255), int(gg * 255), int(bb * 255), a)
    return img


# --- Crab pot floats --------------------------------------------------------------

def pot_float(state):
    """16 x 16: an orange float on the water, with ripples. 'empty': lying on
    its side; 'set': upright on a taut line; 'ready': upright, flag up."""
    img, d = new(16, 16)
    d.arc((2, 11, 14, 15), 180, 360, fill=C["glass"])
    if state == "empty":
        d.ellipse((4, 9, 12, 13), fill=C["orange"], outline=C["outline"])
        d.line((6, 10, 9, 10), fill=C["orange_l"])
        return img
    d.ellipse((5, 7, 11, 13), fill=C["orange"], outline=C["outline"])
    d.point((7, 8), C["orange_l"])
    d.line((8, 3, 8, 7), fill=C["wood_d"])
    if state == "ready":
        d.polygon([(9, 1), (14, 3), (9, 5)], fill=C["red_l"], outline=C["outline"])
        d.line((8, 0, 8, 7), fill=C["wood_d"])
    return img


# --- Item icons -------------------------------------------------------------------

def handline():
    """A wooden H-frame wound with line, a lead weight hanging off it."""
    img, d = new(16, 16)
    d.rectangle((2, 3, 4, 13), fill=C["wood_l"], outline=C["outline"])
    d.rectangle((11, 3, 13, 13), fill=C["wood_l"], outline=C["outline"])
    d.rectangle((4, 6, 11, 10), fill=C["wall"], outline=C["outline"])
    for y in (7, 9):
        d.line((5, y, 10, y), fill=C["paper_d"])
    d.line((13, 13, 14, 15), fill=C["stone_l"])
    d.point((14, 15), C["stone_d"])
    return img


def crab_pot_icon():
    """A domed willow pot with a net mouth on top and a rope."""
    img, d = new(16, 16)
    d.pieslice((1, 3, 15, 23), 180, 360, fill=C["wood"], outline=C["outline"])
    d.rectangle((1, 12, 15, 14), fill=C["wood_d"], outline=C["outline"])
    for x in (4, 8, 12):
        d.line((x, 5, x, 12), fill=C["wood_l"])
    d.ellipse((6, 3, 10, 6), fill=C["dark"])
    d.line((10, 3, 14, 0), fill=C["paper"])
    return img


def brown_crab():
    img, d = new(16, 16)
    d.ellipse((2, 5, 13, 12), fill=C["orange"], outline=C["outline"])
    d.arc((4, 6, 11, 10), 200, 340, fill=C["orange_l"])
    for box in ((0, 2, 4, 6), (11, 2, 15, 6)):
        d.ellipse(box, fill=C["orange"], outline=C["outline"])
    d.point((2, 3), C["dark"])
    d.point((13, 3), C["dark"])
    for x in (3, 5, 10, 12):
        d.line((x, 12, x - 1 if x < 8 else x + 1, 14), fill=C["outline"])
    return img


def lobster():
    img, d = new(16, 16)
    d.ellipse((6, 3, 10, 13), fill=C["sea"], outline=C["outline"])
    d.polygon([(5, 13), (8, 15), (11, 13)], fill=C["sea_d"], outline=C["outline"])
    d.ellipse((2, 0, 6, 5), fill=C["sea_m"], outline=C["outline"])
    d.ellipse((10, 0, 14, 5), fill=C["sea_m"], outline=C["outline"])
    for y in (6, 8, 10):
        d.line((7, y, 9, y), fill=C["sea_d"])
    d.line((7, 3, 4, 7), fill=C["outline"])
    d.line((9, 3, 12, 7), fill=C["outline"])
    return img


# --- Sea fish ---------------------------------------------------------------------

def fish(body, belly, length=12, depth=5, mark=None, mark_colour=None, flat=False):
    """A side-on fish facing left: body and belly colours, a forked tail, an
    eye, and a pattern ('stripes', 'spots', 'speckle', 'snout', 'eel')."""
    img, d = new(16, 16)
    left = (16 - length) // 2
    right = left + length
    top = 8 - depth // 2
    bottom = top + depth
    if flat:
        top -= 1
        bottom += 1
    if mark == "eel":
        d.rounded_rectangle((0, 6, 15, 10), radius=2, fill=body, outline=C["outline"])
        d.line((1, 9, 14, 9), fill=belly)
        d.point((2, 7), C["dark"])
        return img
    d.polygon([(right - 2, 8), (15, top - 1), (15, bottom + 1)], fill=body, outline=C["outline"])
    d.ellipse((left, top, right, bottom), fill=body, outline=C["outline"])
    d.line((left + 2, bottom - 1, right - 2, bottom - 1), fill=belly)
    if mark == "snout":
        d.line((0, 8, left + 1, 8), fill=body)
    if mark == "stripes":
        for x in range(left + 3, right - 2, 2):
            d.line((x, top + 1, x + 1, top + 2), fill=mark_colour)
    elif mark == "spots":
        for x, y in ((left + 4, top + 2), (left + 7, top + 3), (left + 5, top + 4)):
            d.point((x, y), mark_colour)
    elif mark == "speckle":
        for x in range(left + 3, right - 2, 3):
            d.point((x, top + 2), mark_colour)
            d.point((x + 1, top + 3), mark_colour)
    d.point((left + 2, top + 1 if depth > 3 else top), C["dark"])
    return img


SEA_FISH = {
    "mackerel": lambda: fish(C["teal"], C["stone_l"], mark="stripes", mark_colour=C["dark"]),
    "pollack": lambda: fish(C["olive"], C["paper_l"], length=13, depth=5),
    "bass": lambda: fish(C["stone"], C["white"], length=13, depth=6, mark="speckle", mark_colour=C["stone_d"]),
    "whiting": lambda: fish(C["stone_l"], C["white"], length=11, depth=4),
    "cod": lambda: fish(C["olive_d"], C["paper"], length=14, depth=7, mark="speckle", mark_colour=C["mud"]),
    "plaice": lambda: fish(C["brown"], C["paper"], length=11, depth=7, mark="spots", mark_colour=C["orange"], flat=True),
    "dab": lambda: fish(C["paper_d"], C["paper_l"], length=9, depth=6, flat=True),
    "garfish": lambda: fish(C["aqua"], C["stone_l"], length=12, depth=3, mark="snout"),
    "wrasse": lambda: fish(C["leaf"], C["olive"], length=11, depth=6, mark="spots", mark_colour=C["yellow"]),
    "gurnard": lambda: fish(C["red"], C["paper_l"], length=11, depth=5, mark="speckle", mark_colour=C["red_d"]),
    "conger_eel": lambda: fish(C["grey"], C["stone"], mark="eel"),
}


def save(img, path):
    img.save(path)
    print("built", path)


if __name__ == "__main__":
    save(tam(), OUT + "cove/tam.png")
    for state in ("empty", "set", "ready"):
        save(pot_float(state), OUT + f"cove/crab_pot_{state}.png")
    save(handline(), OUT + "items/handline.png")
    save(crab_pot_icon(), OUT + "items/crab_pot.png")
    save(brown_crab(), OUT + "items/brown_crab.png")
    save(lobster(), OUT + "items/lobster.png")
    for name, draw in SEA_FISH.items():
        save(draw(), OUT + f"fish/{name}.png")
