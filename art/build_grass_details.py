"""Build row 1 (the grass details) of each season's ground tileset.

DECISIONS 031. For each season, art/grass_details/<season>.png is a 128x16 strip
of eight small details (tuft, flower, pebble...) on a transparent background,
one per 16x16 cell. Each is drawn over that season's plain grass tile (row 0,
column 0 of assets/tilesets/ground_<season>.png) and the results become row 1.

Pixels on a tile's outer edge are dropped from the detail, so a detail tile
meets its neighbours exactly as plain grass does: no seams.

Run from the project root:  python3 art/build_grass_details.py
Safe to run again: row 0 is read, never changed.
"""
from PIL import Image

SEASONS = ["spring", "summer", "autumn", "winter"]
COUNT = 8  # GroundTiles.GRASS_DETAIL_COUNT

for season in SEASONS:
    path = f"assets/tilesets/ground_{season}.png"
    sheet = Image.open(path).convert("RGBA")
    row0 = sheet.crop((0, 0, 144, 16))
    grass = row0.crop((0, 0, 16, 16))
    details = Image.open(f"art/grass_details/{season}.png").convert("RGBA")
    assert details.size == (16 * COUNT, 16), f"{season} details must be {16*COUNT}x16"

    out = Image.new("RGBA", (144, 32), (0, 0, 0, 0))
    out.paste(row0, (0, 0))
    for i in range(COUNT):
        d = details.crop((i * 16, 0, i * 16 + 16, 16))
        px = d.load()
        for x in range(16):
            for y in range(16):
                if x in (0, 15) or y in (0, 15) or px[x, y][3] < 128:
                    px[x, y] = (0, 0, 0, 0)
                else:
                    px[x, y] = px[x, y][:3] + (255,)
        out.paste(Image.alpha_composite(grass.copy(), d), (i * 16, 16))
    out.save(path)
    print("built", path)
