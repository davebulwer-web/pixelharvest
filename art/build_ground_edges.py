"""Build the soft-edge pictures for every season (Stage 23, DECISIONS 072).

    python3 art/build_ground_edges.py

Reads  assets/tilesets/ground_<season>.png  (the plain ground tiles)
       art/ground_sources/edges/*.png       (Pixellab terrain sets, by mask)
Writes assets/tilesets/edges_<season>.png   (256 x 400)

Layout (scripts/ground_tiles.gd says the same):
  row = ground * 2 + variant, one row per EdgeGround (lowest first) and variant;
  column = the MASK, which corners of the picture tile the ground covers
  (1 top-left, 2 top-right, 4 bottom-left, 8 bottom-right, added up).
  Columns 0 and 15 stay empty (nothing / the plain tile is used instead).
  Row 24: scatter, small things on a clear background (0-5 green, 6-7 stones).

Every edge picture is the ground's OWN plain tile, cut to a shape, with a
one-pixel darker rim, so it joins the plain tiles with no seam in every season.
The shape comes from:
  - a Pixellab terrain set where we have one (grass over the dirt path, the
    look test: its lip and the shadow it throws on the path are kept); its
    shape is used for grass over everything;
  - otherwise a placeholder: a rounded, wobbly line worked out from the four
    corners (smooth blend of the corners plus a little tileable noise), until
    session 5 makes each one with Pixellab.
"""
import math, os, random
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = 16
SEASONS = ['spring', 'summer', 'autumn', 'winter']
PALETTE = [c[:3] for c in Image.open(os.path.join(ROOT, 'art/palette.png')).convert('RGBA').getdata()
           if c[3] > 0]
PALETTE = sorted(set(PALETTE))

# EdgeGround order and each one's plain tile in the ground image (column, row).
GROUNDS = [
    ('sea', (4, 3)), ('water', (5, 0)), ('wet_sand', (2, 3)), ('rockpool', (3, 3)),
    ('sand', (1, 3)), ('path', (2, 0)), ('paving', (0, 3)), ('tilled', (3, 0)),
    ('tilled_wet', (4, 0)), ('grass', (0, 0)), ('rocks', (6, 3)), ('thicket', (8, 0)),
]
VARIANTS = 2
SCATTER_ROW = len(GROUNDS) * VARIANTS
# Pixellab shapes: ground -> source file (16 tiles side by side, by mask).
PIXELLAB = {'grass': 'grass_over_path.png'}


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def nearest(c):
    return min(PALETTE, key=lambda p: sum((a - b) ** 2 for a, b in zip(p, c)))


def tile(img, col, row):
    return img.crop((col * T, row * T, col * T + T, row * T + T)).convert('RGBA')


def rim_colour(plain):
    """The darkest colour of the plain tile, one palette step darker."""
    cols = [p[:3] for p in plain.getdata() if p[3] > 0]
    dark = min(cols, key=lum)
    candidates = [p for p in PALETTE if lum(p) < lum(dark) - 8]
    if not candidates:
        return dark
    target = tuple(int(v * 0.72) for v in dark)
    return min(candidates, key=lambda p: sum((a - b) ** 2 for a, b in zip(p, target)))


# --- shapes: a 16 x 16 grid of 'in' / 'rim' / 'shadow' / None per mask -------

def periodic_noise(seed):
    """A smooth wobble that repeats every tile, so neighbours always meet: a
    few sine waves across and down the tile, at random phases. A line along
    the tile's width is bent by the waves across it, and the other way round."""
    rnd = random.Random(seed)
    waves = [(k, rnd.uniform(0, 2 * math.pi), rnd.uniform(0, 2 * math.pi), w)
             for k, w in ((1, 0.5), (2, 0.3), (3, 0.15))]

    def at(x, y):  # x, y in tile pixels (0..16)
        u, v = x / T, y / T
        return sum(w * (math.sin(2 * math.pi * k * u + a) + math.sin(2 * math.pi * k * v + b))
                   for k, a, b, w in waves) / 2
    return at


def placeholder_shape(mask, ground_index, variant):
    base = periodic_noise(1000 + ground_index * 7)
    extra = periodic_noise(2000 + ground_index * 7 + variant * 31)
    corners = [(mask >> i) & 1 for i in range(4)]  # TL, TR, BL, BR

    def field(x, y):
        u, v = (x + 0.5) / T, (y + 0.5) / T
        f = (corners[0] * (1 - u) * (1 - v) + corners[1] * u * (1 - v)
             + corners[2] * (1 - u) * v + corners[3] * u * v)
        # The extra wobble fades out at the tile's sides, so the two variants
        # always meet each other (and the plain tile) where the line crosses.
        window = math.sin(math.pi * u) * math.sin(math.pi * v)
        return f + 0.28 * base(x + 0.5, y + 0.5) + 0.12 * window * extra(x + 0.5, y + 0.5)

    inside = [[field(x, y) > 0.5 for x in range(T)] for y in range(T)]
    remove_specks(inside)
    return add_rim(inside, field)


def remove_specks(inside, smallest=10):
    """Fill tiny holes and drop tiny islands that don't touch the tile's
    sides (those that do carry on into the next tile, so they stay)."""
    seen = [[False] * T for _ in range(T)]
    for sy in range(T):
        for sx in range(T):
            if seen[sy][sx]:
                continue
            kind = inside[sy][sx]
            stack, cells, touches = [(sx, sy)], [], False
            seen[sy][sx] = True
            while stack:
                x, y = stack.pop()
                cells.append((x, y))
                if x in (0, T - 1) or y in (0, T - 1):
                    touches = True
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < T and 0 <= ny < T and not seen[ny][nx] and inside[ny][nx] == kind:
                        seen[ny][nx] = True
                        stack.append((nx, ny))
            if not touches and len(cells) < smallest:
                for x, y in cells:
                    inside[y][x] = not kind


def add_rim(inside, field):
    """'rim' for inside pixels with an outside neighbour (looked up across the
    tile's sides too, through the same field), 'in' for the rest."""
    def is_in(x, y):
        if 0 <= x < T and 0 <= y < T:
            return inside[y][x]
        return field(x, y) > 0.5
    shape = [[None] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            if not inside[y][x]:
                continue
            edge = any(not is_in(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            shape[y][x] = 'rim' if edge else 'in'
    return shape


def pixellab_shape(src, mask):
    """Read a Pixellab grass-over-path tile: green is the grass, its darkest
    greens the lip, dark browns the shadow the lip throws on the path, and the
    rest of the brown (the path itself) is left clear."""
    im = src.crop((mask * T, 0, mask * T + T, T))
    shape = [[None] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            r, g, b, a = im.getpixel((x, y))
            l = lum((r, g, b))
            if g > r:  # green
                shape[y][x] = 'rim' if l < 105 else 'in'
            elif l < 118:
                shape[y][x] = 'shadow'
    return shape


def render(shape, plain, rim, shadow):
    out = Image.new('RGBA', (T, T), (0, 0, 0, 0))
    for y in range(T):
        for x in range(T):
            k = shape[y][x]
            if k == 'in':
                out.putpixel((x, y), plain.getpixel((x, y)))
            elif k == 'rim':
                out.putpixel((x, y), rim + (255,))
            elif k == 'shadow' and shadow is not None:
                out.putpixel((x, y), shadow + (255,))
    return out


def scatter_piece(detail, plain):
    """What a detail tile adds to its plain tile, on a clear background."""
    out = Image.new('RGBA', (T, T), (0, 0, 0, 0))
    for y in range(T):
        for x in range(T):
            p = detail.getpixel((x, y))
            if p[:3] != plain.getpixel((x, y))[:3]:
                out.putpixel((x, y), p)
    return out


def build(season):
    ground = Image.open(os.path.join(ROOT, f'assets/tilesets/ground_{season}.png')).convert('RGBA')
    out = Image.new('RGBA', (16 * T, (SCATTER_ROW + 1) * T), (0, 0, 0, 0))
    path_plain = tile(ground, 2, 0)
    for gi, (name, (col, row)) in enumerate(GROUNDS):
        plain = tile(ground, col, row)
        rim = rim_colour(plain)
        for variant in range(VARIANTS):
            for mask in range(1, 15):
                if name in PIXELLAB:
                    src = Image.open(os.path.join(ROOT, 'art/ground_sources/edges', PIXELLAB[name])).convert('RGBA')
                    shape = pixellab_shape(src, mask)
                    # The lip's shadow: one shade darker than the path's darkest.
                    shadow = rim_colour(path_plain)
                else:
                    shape = placeholder_shape(mask, gi, variant)
                    shadow = None
                out.paste(render(shape, plain, rim, shadow), (mask * T, (gi * VARIANTS + variant) * T))
    grass = tile(ground, 0, 0)
    pieces = [scatter_piece(tile(ground, c, 1), grass) for c in range(6)]
    pieces.append(scatter_piece(tile(ground, 7, 1), grass))
    pieces.append(scatter_piece(tile(ground, 0, 2), path_plain))
    for i, p in enumerate(pieces):
        out.paste(p, (i * T, SCATTER_ROW * T))
    out.save(os.path.join(ROOT, f'assets/tilesets/edges_{season}.png'))
    print('wrote', f'edges_{season}.png', out.size)


if __name__ == '__main__':
    for s in SEASONS:
        build(s)
