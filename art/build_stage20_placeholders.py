"""Placeholder art for Stage 20 session 1 (DECISIONS 062), drawn in the palette
until Pixellab replaces it (Stage 23 and 24).

  assets/sprites/lane/dot.png          Dot the carrier, 56 x 56 like every
                                       person: the angler's figure recoloured
                                       (a carrier's red coat, a dark cap) with
                                       a satchel across her
  assets/sprites/lane/job_slate.png    the allotment holders' slate by their
                                       gate, 32 x 32: the notice board's
                                       posts with a slate for a board
  assets/sprites/items/parcel.png      16 x 16, brown paper and string
  assets/sprites/items/letter.png      16 x 16, an envelope with a red seal
  assets/sprites/items/flour_sack.png  16 x 16, a small sack of flour

Run from the project folder:  python art/build_stage20_placeholders.py
"""
import colorsys

from PIL import Image, ImageDraw

OUT = "assets/sprites/"
C = {
    "outline": (46, 31, 26, 255), "dark": (34, 34, 43, 255),
    "stone_d": (68, 68, 79, 255), "stone": (113, 113, 126, 255), "stone_l": (212, 231, 245, 255),
    "wood_d": (74, 47, 34, 255), "wood": (107, 74, 47, 255), "wood_l": (138, 99, 64, 255),
    "paper_d": (171, 129, 108, 255), "paper": (200, 153, 123, 255), "paper_l": (245, 194, 186, 255),
    "wall": (255, 231, 216, 255), "wall_s": (245, 194, 186, 255),
    "slate_d": (59, 54, 75, 255), "slate": (63, 78, 113, 255),
    "red": (172, 59, 70, 255), "red_d": (143, 51, 63, 255), "red_l": (196, 73, 76, 255),
}
T = (0, 0, 0, 0)


def new(w, h):
    img = Image.new("RGBA", (w, h), T)
    return img, ImageDraw.Draw(img)


def dot():
    """The angler's figure (56 x 56), clothes and hat turned carrier's red,
    and a satchel strap across her with the bag at her hip."""
    img = Image.open(OUT + "town/angler.png").convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            # Greens and teals (the angler's shirt and waders) become red;
            # the straw hat's browns become a dark cap. Skin and outline stay.
            if 0.2 < h < 0.6 and s > 0.2:
                rr, gg, bb = colorsys.hsv_to_rgb(0.98, min(1.0, s + 0.15), v)
                px[x, y] = (int(rr * 255), int(gg * 255), int(bb * 255), a)
            elif y < 22 and 0.05 < h < 0.15 and s > 0.25 and v > 0.45:
                rr, gg, bb = colorsys.hsv_to_rgb(0.7, 0.3, v * 0.45)
                px[x, y] = (int(rr * 255), int(gg * 255), int(bb * 255), a)
    d = ImageDraw.Draw(img)
    d.line((22, 22, 33, 34), fill=C["wood_d"])  # the strap
    d.rectangle((31, 32, 37, 38), fill=C["wood_l"], outline=C["outline"])  # the satchel
    d.line((32, 34, 36, 34), fill=C["wood"])
    return img


def job_slate():
    """32 x 32: two posts, a slate board chalked with jobs, a little roof."""
    img, d = new(32, 32)
    d.rectangle((4, 22, 6, 29), fill=C["wood"], outline=C["outline"])
    d.rectangle((25, 22, 27, 29), fill=C["wood"], outline=C["outline"])
    d.rectangle((3, 7, 28, 23), fill=C["wood_d"], outline=C["outline"])
    d.rectangle((5, 9, 26, 21), fill=C["slate"])
    d.rectangle((5, 9, 26, 10), fill=C["slate_d"])
    for y, x0, x1 in [(12, 7, 20), (14, 7, 17), (16, 7, 22), (18, 7, 15), (20, 7, 19)]:
        d.line((x0, y, x1, y), fill=C["stone_l"])
    d.point((23, 12), C["stone_l"])
    d.point((24, 16), C["stone_l"])
    d.polygon([(1, 7), (16, 2), (30, 7)], fill=C["red_d"], outline=C["outline"])
    return img


def parcel():
    """16 x 16: brown paper and string."""
    img, d = new(16, 16)
    d.rectangle((2, 4, 13, 13), fill=C["paper"], outline=C["outline"])
    d.rectangle((3, 5, 12, 6), fill=C["paper_l"])
    d.line((7, 4, 7, 13), fill=C["wall"])
    d.line((2, 8, 13, 8), fill=C["wall"])
    d.point((6, 3), C["wall"])
    d.point((8, 3), C["wall"])
    d.line((3, 12, 12, 12), fill=C["paper_d"])
    return img


def letter():
    """16 x 16: an envelope with a red wax seal."""
    img, d = new(16, 16)
    d.rectangle((1, 4, 14, 12), fill=C["wall"], outline=C["outline"])
    d.line((2, 5, 7, 9), fill=C["wall_s"])
    d.line((13, 5, 8, 9), fill=C["wall_s"])
    d.rectangle((7, 8, 8, 9), fill=C["red"])
    d.point((6, 9), C["red_d"])
    d.line((2, 11, 13, 11), fill=C["wall_s"])
    return img


def flour_sack():
    """16 x 16: a small sack, tied at the neck, with flour on it."""
    img, d = new(16, 16)
    d.polygon([(4, 5), (11, 5), (13, 14), (2, 14)], fill=C["wall"], outline=C["outline"])
    d.rectangle((6, 2, 9, 5), fill=C["wall_s"], outline=C["outline"])
    d.line((5, 5, 10, 5), fill=C["wood"])
    d.line((5, 9, 10, 9), fill=C["paper_d"])
    d.line((5, 11, 10, 11), fill=C["paper_d"])
    d.line((3, 13, 12, 13), fill=C["wall_s"])
    return img


if __name__ == "__main__":
    dot().save(OUT + "lane/dot.png")
    job_slate().save(OUT + "lane/job_slate.png")
    parcel().save(OUT + "items/parcel.png")
    letter().save(OUT + "items/letter.png")
    flour_sack().save(OUT + "items/flour_sack.png")
