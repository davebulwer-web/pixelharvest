"""Build the extra rows of each season's ground image (DECISIONS 031, 032).

assets/tilesets/ground_<season>.png is a 144-px-wide atlas of 16x16 tiles:

  row 0  one tile per kind of ground (see scripts/ground_tiles.gd). This script
         changes only two of them: column 2, the dirt path (redrawn from
         art/ground_sources/dirt_path.png), and in winter column 8, the thicket
         (spring's bushes recoloured to lie under snow).
  row 1  eight grass details: plain grass with a small thing drawn in the middle,
         from art/ground_sources/grass_details/<season>.png (128x16).
  row 2  four path details, the same idea on the dirt path, from
         art/ground_sources/path_details/<season>.png (64x16).
  row 3  column 0, the paving of the town square, from art/ground_sources/cobbles.png.
         Columns 1-6 (the Cove's sand, wet sand, rockpools, sea, pier and rocks)
         are left as they are: art/build_stage21_placeholders.py draws them.

Pixellab's terrain tool draws in its own colours, so the dirt and cobbles are
mapped onto palette shades by brightness rank (darkest pixels to the darkest
shade), the same as DECISIONS 026. Winter versions are recolours onto snow and
ice shades (DECISIONS 030).

A detail never touches a tile's outer pixels, so detail tiles meet their
neighbours exactly as the plain tile does: no seams.

Run from the project root:  python3 art/build_ground.py
Safe to run again: it only ever reads the sources and row 0's other tiles.
"""
from PIL import Image

SEASONS = ["spring", "summer", "autumn", "winter"]
SRC = "art/ground_sources"
GRASS_DETAILS = 8  # GroundTiles.GRASS_DETAIL_COUNT
PATH_DETAILS = 4   # GroundTiles.PATH_DETAIL_COUNT


def hexrgb(h: str) -> tuple:
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def lum(c: tuple) -> float:
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]


def ramp(tile: Image.Image, shades: list, weights: list) -> Image.Image:
    """Map the tile's colours, darkest first, onto `shades`. `weights` says what
    share of the tile's pixels (by count, darkest first) each shade takes."""
    out = tile.convert("RGBA")
    px = out.load()
    counts: dict = {}
    for x in range(16):
        for y in range(16):
            counts[px[x, y][:3]] = counts.get(px[x, y][:3], 0) + 1
    total = sum(counts.values())
    mapping, seen = {}, 0
    bounds = [sum(weights[: i + 1]) * total for i in range(len(weights))]
    for col in sorted(counts, key=lum):
        mid = seen + counts[col] / 2
        i = next((k for k, b in enumerate(bounds) if mid <= b), len(shades) - 1)
        mapping[col] = hexrgb(shades[i]) + (255,)
        seen += counts[col]
    for x in range(16):
        for y in range(16):
            px[x, y] = mapping[px[x, y][:3]]
    return out


def recolour(tile: Image.Image, pairs: dict) -> Image.Image:
    out = tile.copy()
    px = out.load()
    table = {hexrgb(a): hexrgb(b) for a, b in pairs.items()}
    for x in range(16):
        for y in range(16):
            c = px[x, y][:3]
            if c in table:
                px[x, y] = table[c] + (255,)
    return out


def with_details(base: Image.Image, strip: Image.Image, count: int) -> list:
    tiles = []
    for i in range(count):
        d = strip.crop((i * 16, 0, i * 16 + 16, 16))
        px = d.load()
        for x in range(16):
            for y in range(16):
                if x in (0, 15) or y in (0, 15) or px[x, y][3] < 128:
                    px[x, y] = (0, 0, 0, 0)
                else:
                    px[x, y] = px[x, y][:3] + (255,)
        tiles.append(Image.alpha_composite(base.copy(), d))
    return tiles


# The dirt path: mostly the mid brown, its grain in the dark brown.
dirt = ramp(Image.open(f"{SRC}/dirt_path.png"), ["#6b4a2f", "#8a6340"], [0.17, 0.83])
# Winter's path is trodden snow: the same grain, in ice blues on pale snow.
dirt_winter = recolour(dirt, {"#8a6340": "#d4e7f5", "#6b4a2f": "#abdcef"})
# The town square: mortar, stone shadow, stone, highlight.
cobbles = ramp(Image.open(f"{SRC}/cobbles.png"),
               ["#785853", "#ab816c", "#c8997b", "#ffe7d8"], [0.22, 0.28, 0.35, 0.15])
cobbles_winter = recolour(cobbles, {"#785853": "#abdcef", "#ab816c": "#d4e7f5",
                                    "#c8997b": "#f7fdff", "#ffe7d8": "#f7fdff"})

for season in SEASONS:
    path = f"assets/tilesets/ground_{season}.png"
    row0 = Image.open(path).convert("RGBA").crop((0, 0, 144, 16))
    winter = season == "winter"
    path_tile = dirt_winter if winter else dirt
    row0.paste(path_tile, (32, 0))
    if winter:
        # Winter thicket is spring's bushes under snow: the same shapes, leaves
        # and berries recoloured to snow and its shadow.
        spring = Image.open("assets/tilesets/ground_spring.png").convert("RGBA")
        row0.paste(recolour(spring.crop((128, 0, 144, 16)), {
            "#1e3a1f": "#abdcef", "#2f5a2b": "#d4e7f5", "#4a7f3a": "#f7fdff",
            "#8f333f": "#abdcef", "#c4494c": "#f7fdff"}), (128, 0))

    out = Image.new("RGBA", (144, 64), (0, 0, 0, 0))
    out.paste(row0, (0, 0))
    grass = row0.crop((0, 0, 16, 16))
    gd = Image.open(f"{SRC}/grass_details/{season}.png").convert("RGBA")
    pd = Image.open(f"{SRC}/path_details/{season}.png").convert("RGBA")
    for i, t in enumerate(with_details(grass, gd, GRASS_DETAILS)):
        out.paste(t, (i * 16, 16))
    for i, t in enumerate(with_details(path_tile, pd, PATH_DETAILS)):
        out.paste(t, (i * 16, 32))
    out.paste(cobbles_winter if winter else cobbles, (0, 48))
    # Row 3's other columns (the Cove's ground, DECISIONS 064) are drawn by
    # art/build_stage21_placeholders.py: keep them as they are.
    out.paste(Image.open(path).convert("RGBA").crop((16, 48, 144, 64)), (16, 48))
    out.save(path)
    print("built", path)
