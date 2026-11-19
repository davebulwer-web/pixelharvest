"""Build the soft-edge pictures for every season (Stage 23, DECISIONS 072).

    python3 art/build_ground_edges.py

Reads  assets/tilesets/ground_<season>.png  (the plain ground tiles)
       art/ground_sources/edges/*.png       (Pixellab terrain sets, by mask)
Writes assets/tilesets/edges_<season>.png   (256 x 496)

Layout (scripts/ground_tiles.gd says the same):
  row = ground * 2 + variant, one row per EdgeGround (lowest first) and variant;
  column = the MASK, which corners of the picture tile the ground covers
  (1 top-left, 2 top-right, 4 bottom-left, 8 bottom-right, added up).
  Columns 0 and 15 stay empty (nothing / the plain tile is used instead).
  Row 24: scatter, small things on a clear background (0-5 green, 6-7 stones).
  Rows 25-26: grass over pond water, with a sandy, stony bank (two variants).
  Rows 27-30: the foam on the sea's edge, four frames of each mask, one under
  the other (the tileset animates them: frame N of column M is row 27 + N).

Every edge picture is the ground's OWN plain tile, cut to a shape, with a
one-pixel darker rim, so it joins the plain tiles with no seam in every season.
The shape comes from Pixellab's terrain tool (/create-tileset, standard,
16 px, transition 0.25, seed 7), one set per ground (session 5, DECISIONS 073):
  - grass over the dirt path (session 4's look test): its lip and the shadow
    it throws are kept; used for grass over everything but pond water;
  - every other ground: Pixellab draws the SAME outline for every pair made
    with one seed (shape.png, taken from the wet-sand-over-sea set), and only
    the band along it differs: a dark rim, a lighter lip, a wet darkening
    outside, a sandy bank. So each ground's own set is read pixel by pixel
    against that outline: its own colours become our plain tile's, its band
    becomes our rim / darkest / lightest shades, a dark band outside the
    outline becomes a see-through shadow over whatever lies below;
  - grass over pond water gets its own rows, with the bank's sand and stones
    coloured from the season's sand tile;
  - the foam is worked out from the outline: a ring one to three pixels out
    on the sea, breathing in and out over four frames.
The placeholder shapes (a wobbly line through the four corners) are still
here, for any ground without a Pixellab set.
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
BANK_ROW = SCATTER_ROW + 1          # grass over pond water, two variants
FOAM_ROW = BANK_ROW + VARIANTS      # four frames, one row each
FOAM_FRAMES = 4
SOURCES = os.path.join(ROOT, 'art/ground_sources/edges')
# Grass keeps session 4's own shape (Dave approved that look).
PIXELLAB = {'grass': 'grass_over_path.png'}
# Every other ground: its own Pixellab set (16 tiles by mask, lower | upper),
# read against the shared outline.
BANDED = {
    'water': 'water.png', 'wet_sand': 'wet_sand.png', 'rockpool': 'rockpool.png',
    'sand': 'sand.png', 'path': 'path.png', 'paving': 'paving.png',
    'tilled': 'tilled.png', 'tilled_wet': 'tilled_wet.png', 'rocks': 'rocks.png',
    'thicket': 'thicket.png',
}
BANK = 'grass_bank.png'
# A see-through shadow / lightening, so it suits whatever ground lies below.
SHADOW = (0, 0, 0, 72)
LIGHTEN = (255, 255, 255, 56)


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


# --- session 5: Pixellab sets read against the shared outline ---------------

def load_outline():
    """shape.png: white where the upper ground is, for each mask."""
    im = Image.open(os.path.join(SOURCES, 'shape.png')).convert('L')
    return {m: [[im.getpixel((m * T + x, y)) > 127 for x in range(T)] for y in range(T)]
            for m in range(16)}


def depth(inside):
    """How far each pixel is from the outline: 1, 2, 3... inside (1 touches
    the outside) and -1, -2, -3... outside."""
    from collections import deque
    far = 99
    d = [[far] * T for _ in range(T)]
    around = [(dx, dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy]
    for side in (True, False):
        q = deque()
        for y in range(T):
            for x in range(T):
                if inside[y][x] == side and any(
                        0 <= x + dx < T and 0 <= y + dy < T and inside[y + dy][x + dx] != side
                        for dx, dy in around):
                    d[y][x] = 1
                    q.append((x, y))
        while q:
            x, y = q.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < T and 0 <= ny < T and inside[ny][nx] == side and d[ny][nx] > d[y][x] + 1:
                    d[ny][nx] = d[y][x] + 1
                    q.append((nx, ny))
    return [[d[y][x] if inside[y][x] else -d[y][x] for x in range(T)] for y in range(T)]


def colours_of(im, mask):
    return set(p[:3] for p in im.crop((mask * T, 0, mask * T + T, T)).getdata())


def mean_lum(im, mask):
    px = [p[:3] for p in im.crop((mask * T, 0, mask * T + T, T)).getdata()]
    return sum(lum(p) for p in px) / len(px)


def shades(plain):
    """The plain tile's darkest and lightest colours."""
    cols = sorted(set(p[:3] for p in plain.getdata() if p[3] > 0), key=lum)
    return cols[0], cols[-1]


def ramp(plain):
    """The plain tile's main colours (each at least an eighth of it, so a
    berry or a fleck never becomes a whole band), plus its rim colour."""
    from collections import Counter
    count = Counter(p[:3] for p in plain.getdata() if p[3] > 0)
    total = sum(count.values())
    main = [c for c, n in count.items() if n * 8 >= total] or [count.most_common(1)[0][0]]
    return main + [rim_colour(plain)]


def render_banded(src, mask, outline, plain, keep_light_outside=True):
    """One edge picture: the outline cut from our plain tile, with the band
    Pixellab drew along it turned into our own shades: each band pixel takes
    the colour of ours whose brightness sits as far from our tile's as the
    band's sits from Pixellab's own tile (so it works in every season)."""
    upper, lower = colours_of(src, 15), colours_of(src, 0)
    ul, ll = mean_lum(src, 15), mean_lum(src, 0)
    shades_here = ramp(plain)
    ours = sum(lum(p[:3]) for p in plain.getdata()) / (T * T)
    d = depth(outline)
    out = Image.new('RGBA', (T, T), (0, 0, 0, 0))
    for y in range(T):
        for x in range(T):
            c = src.getpixel((mask * T + x, y))[:3]
            if d[y][x] > 0:
                if c in upper:
                    p = plain.getpixel((x, y))
                else:
                    target = ours + (lum(c) - ul)
                    p = min(shades_here, key=lambda s: abs(lum(s) - target)) + (255,)
            else:
                if c in lower:
                    continue
                if lum(c) < ll - 15:
                    p = SHADOW
                elif lum(c) > ll + 15 and keep_light_outside:
                    p = LIGHTEN
                else:
                    continue
            out.putpixel((x, y), p)
    return out


def render_bank(src, mask, outline, grass, sand):
    """Grass over pond water: grass where Pixellab drew grass, the bank's sand
    and stones in our sand's colours (dark stones and the lip in rim colours).
    Told apart by hue: green is grass, blue-green is the pond, the rest bank."""
    sand_rim = rim_colour(sand)
    sand_dark = shades(sand)[0]
    grass_rim = rim_colour(grass)
    out = Image.new('RGBA', (T, T), (0, 0, 0, 0))
    for y in range(T):
        for x in range(T):
            c = src.getpixel((mask * T + x, y))[:3]
            if is_pond(c):
                continue
            if g_ish(c):
                # The grass's own darker lip, in our grass's rim colour.
                p = grass_rim + (255,) if lum(c) < 125 else grass.getpixel((x, y))
            elif lum(c) < 140:
                p = sand_rim + (255,)
            elif lum(c) < 175:
                p = sand_dark + (255,)
            else:
                p = sand.getpixel((x, y))
            out.putpixel((x, y), p)
    return out


def is_pond(c):
    return c[2] >= c[1] - 10 and c[2] > c[0] + 20


def g_ish(c):
    return c[1] >= c[0] and c[1] > c[2] + 30


def foam_frames(outline):
    """The foam on the sea round the land in `outline`: four frames of a
    ring that runs out from the shore and back (1, 2, 3, 2 pixels out), a
    bright line with a paler fringe, broken here and there so it fizzes."""
    white = nearest((255, 255, 255)) + (255,)
    pale = nearest((180, 225, 235)) + (200,)
    d = depth(outline)
    reach = [1, 2, 3, 2]
    frames = []
    for f in range(FOAM_FRAMES):
        im = Image.new('RGBA', (T, T), (0, 0, 0, 0))
        r = reach[f]
        for y in range(T):
            for x in range(T):
                k = -d[y][x]
                if k <= 0:
                    continue
                broken = (x * 7 + y * 13 + f * 5) % 9 == 0
                if k == r and not broken:
                    im.putpixel((x, y), white)
                elif k == r + 1 and (x + y + f) % 3 != 0:
                    im.putpixel((x, y), pale)
                elif k < r and (x * 3 + y * 5 + f) % 7 == 0:
                    im.putpixel((x, y), pale)
        frames.append(im)
    return frames


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
    out = Image.new('RGBA', (16 * T, (FOAM_ROW + FOAM_FRAMES) * T), (0, 0, 0, 0))
    path_plain = tile(ground, 2, 0)
    outline = load_outline()
    for gi, (name, (col, row)) in enumerate(GROUNDS):
        plain = tile(ground, col, row)
        rim = rim_colour(plain)
        for variant in range(VARIANTS):
            for mask in range(1, 15):
                if name in BANDED:
                    # Both variants alike: two different Pixellab outlines
                    # wouldn't meet where neighbouring tiles join.
                    src = Image.open(os.path.join(SOURCES, BANDED[name])).convert('RGBA')
                    pic = render_banded(src, mask, outline[mask], plain,
                                        keep_light_outside=(name != 'wet_sand'))
                    out.paste(pic, (mask * T, (gi * VARIANTS + variant) * T))
                    continue
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
    # Grass over pond water, with its bank.
    bank_src = Image.open(os.path.join(SOURCES, BANK)).convert('RGBA')
    grass_plain, sand_plain = tile(ground, 0, 0), tile(ground, 1, 3)
    for variant in range(VARIANTS):
        for mask in range(1, 15):
            out.paste(render_bank(bank_src, mask, outline[mask], grass_plain, sand_plain),
                      (mask * T, (BANK_ROW + variant) * T))
    # The foam: frame N of mask M at row FOAM_ROW + N.
    for mask in range(1, 15):
        for f, im in enumerate(foam_frames(outline[mask])):
            out.paste(im, (mask * T, (FOAM_ROW + f) * T))
    out.save(os.path.join(ROOT, f'assets/tilesets/edges_{season}.png'))
    print('wrote', f'edges_{season}.png', out.size)


if __name__ == '__main__':
    for s in SEASONS:
        build(s)
