"""Draw the calm hedge and put it in every ground tileset (DECISIONS 087).

    python art/build_calm_hedge.py            draw the calm hedge in
    python art/build_calm_hedge.py --restore  put the old berry hedge back

The hedge (GroundTiles.THICKET: the Lane's hedgerows, the Woods' thickets and
the farm's fields not yet bought) used to be a busy dark tile dotted with red
berries. This draws a calmer one: rounded clumps of leaves in three or four
flat colours, lit from the top, a darker front where the hedge meets the
ground below it, a thin dark outline and a soft shadow on the grass. Like
the Cozy Village & Farm pack's bushes, but drawn here, from scratch, so it is
OUR art and can live in git. Only colours from art/palette.png are used.

What it writes, for each season:

  the plain hedge tile, ground_<season>.png column 8 row 0 (GroundTiles.THICKET)
  the hedge's soft edges, edges_<season>.png rows 22 and 23 (EdgeGround.THICKET
  is 11, two variants a ground: GroundTiles.edge_tile())

in our own tilesets (assets/tilesets/) and, if they're there, the cozy, calm
and harbour test copies in assets/tilesets/cozy/ (git-ignored). Before the
first change it saves the old pictures to art/ground_sources/thicket_berry/,
which is what --restore puts back.

How the shape is made. The edges are a dual grid (GroundEdges): each picture
tile's middle is a corner where four cells meet, and its mask says which of
the four are hedge. Every hedge cell is drawn as four leaf clumps (circles),
in a brick pattern so big areas don't show a grid; the hedge is wherever a
clump covers. Clumps further down are drawn over the ones above, as you'd see
a hedge from above and a little in front. A tile only needs the clumps of its
own four cells: nothing from further away reaches into it, so neighbouring
tiles always join. The plain tile is the all-hedge mask's picture, which is
why the hedge is now laid down as drawn, never turned (GroundTiles.transform_for).
"""
import math
import os
import shutil
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = 16
SEASONS = ['spring', 'summer', 'autumn', 'winter']
PLAIN = (8, 0)                  # GroundTiles.THICKET
EDGE_ROWS = (22, 23)            # EdgeGround.THICKET (11) * 2 variants
SAVED = os.path.join(ROOT, 'art/ground_sources/thicket_berry')

# The tilesets to patch: our own, then the test copies built from them.
SETS = [('assets/tilesets', ''),
        ('assets/tilesets/cozy', ''),
        ('assets/tilesets/cozy', 'calm_'),
        ('assets/tilesets/cozy', 'harbour_')]

CLEAR = (0, 0, 0, 0)
SHADOW = (0, 0, 0, 72)          # the same see-through shadow as the cozy edges


def hexc(h):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


# Per season: outline, face (the side facing you, near the ground), leaf
# shade (the little arcs inside), body, light (the top's rim and the arcs'
# lit side). Winter's hedge is evergreen with snow lying along its top.
COLOURS = {
    'spring': ['2b1e2f', '1e4d3a', '1e4d3a', '2f7a45', '4fa34f'],
    'summer': ['2b1e2f', '1e4d3a', '1e4d3a', '2f7a45', '4fa34f'],
    'autumn': ['3f2a24', '6b4430', '6b4430', 'b86a28', 'e8a23a'],
    'winter': ['2b1e2f', '1e4d3a', '1e4d3a', '2f7a45', '4fa34f'],
}
SNOW_SHADE = 'dfe2e8'

# How the hedge's outline is softened: convex corners rounded off with this
# radius, and the top edge dipping between rounded tops every 8 px.
ROUND = 3
DIP_PERIOD = 8
FACE = 3            # rows of face colour above the ground
SNOW = 3            # rows of snow on top, in winter
TOP_LIGHT = 2       # rows of light along the top, the rest of the year

# The leaves inside: a 16 x 16 motif of a few small arcs, '-' shade and '+'
# light, '.' plain. Sparse on purpose: the hedge should read as one calm mass.
MOTIF = [
    '................',
    '................',
    '..+++...........',
    '.+...-..........',
    '......-.........',
    '..........+++...',
    '.........+...-..',
    '..............-.',
    '................',
    '.....++.........',
    '....+...-.......',
    '.........-......',
    '...............+',
    '..............+.',
    '+.............-.',
    '.-..............',
]


def _cells(mask):
    """Which of the window's pixels are hedge CELLS, before any shaping. The
    window is the tile with 8 px round it: far enough to see every edge that
    shapes the tile's pixels. Those 8 px belong to the same four cells (a
    tile's middle is a corner, its sides are the middles of cells), so they
    copy them."""
    W = T + 16
    grid = [[False] * W for _ in range(W)]
    for wy in range(W):
        for wx in range(W):
            cx = 0 if wx < 16 else 1
            cy = 0 if wy < 16 else 1
            grid[wy][wx] = bool(mask & (1 << (cy * 2 + cx)))
    return grid


# The top edge, by x within a cell: how many pixels it dips, so each cell's
# stretch of hedge has a gently rounded top.
TOP_DIP = [2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2]


def _shape(mask):
    """The hedge's pixels in the window: the cells, their convex corners
    rounded off (a pixel stays only if a ROUND-radius disc that holds it fits
    inside the cells) and the top edge dipping between cells."""
    W = T + 16
    cells = _cells(mask)

    def cell(x, y):
        return cells[min(max(y, 0), W - 1)][min(max(x, 0), W - 1)]

    disc = [(dx, dy) for dy in range(-ROUND, ROUND + 1) for dx in range(-ROUND, ROUND + 1)
            if dx * dx + dy * dy <= ROUND * ROUND + 1]

    def fits(cx, cy):
        return all(cell(cx + dx, cy + dy) for dx, dy in disc)

    shape = [[False] * W for _ in range(W)]
    for y in range(W):
        for x in range(W):
            if not cells[y][x]:
                continue
            # Opening: some disc inside the cells covers this pixel.
            if not any(fits(x - dx, y - dy) for dx, dy in disc):
                continue
            # The top's dips. A window pixel's x % 16 is its x within its cell
            # (the window starts 8 px before the tile, the tile 8 px into a
            # cell), so the dips line up with the cells in every tile.
            dip = TOP_DIP[x % 16]
            if any(not cell(x, y - k) for k in range(1, dip + 1)):
                continue
            shape[y][x] = True
    return shape


def picture(mask, season):
    outline, face, shade, body, light = [hexc(h) for h in COLOURS[season]]
    snow_shade = hexc(SNOW_SHADE)
    W = T + 16
    shape = _shape(mask)

    def inside(x, y):
        if 0 <= x < W and 0 <= y < W:
            return shape[y][x]
        return shape[min(max(y, 0), W - 1)][min(max(x, 0), W - 1)]

    def run(x, y, step):
        """How many hedge pixels from (x, y) straight up (-1) or down (+1)
        before the ground, counting this one, up to 8."""
        n = 0
        while n < 8 and inside(x, y + step * n):
            n += 1
        return n

    img = Image.new('RGBA', (T, T), CLEAR)
    px = img.load()
    for ty in range(T):
        for tx in range(T):
            x, y = tx + 8, ty + 8
            if not inside(x, y):
                # The shadow the hedge throws on the ground just below it.
                if inside(x, y - 1) or inside(x, y - 2):
                    px[tx, ty] = SHADOW
                continue
            if not (inside(x - 1, y) and inside(x + 1, y) and inside(x, y - 1) and inside(x, y + 1)):
                px[tx, ty] = outline
                continue
            up, down = run(x, y, -1), run(x, y, 1)
            leaf = MOTIF[ty % 16][tx % 16]
            if down <= FACE:
                colour = face
            elif season == 'winter' and up <= SNOW:
                colour = hexc('ffffff') if up < SNOW else snow_shade
            elif up <= TOP_LIGHT:
                colour = light
            elif leaf == '-':
                colour = shade
            elif leaf == '+':
                colour = light
            else:
                colour = body
            px[tx, ty] = colour
    return img


def load(path):
    return Image.open(path).convert('RGBA')


def targets():
    for folder, prefix in SETS:
        for season in SEASONS:
            g = os.path.join(ROOT, folder, '%sground_%s.png' % (prefix, season))
            e = os.path.join(ROOT, folder, '%sedges_%s.png' % (prefix, season))
            if os.path.exists(g) and os.path.exists(e):
                yield season, g, e


def save_old():
    """Keep our own berry hedge (ground tile and edge rows) once, for --restore."""
    if os.path.isdir(SAVED):
        return
    os.makedirs(SAVED)
    for season in SEASONS:
        g = load(os.path.join(ROOT, 'assets/tilesets/ground_%s.png' % season))
        e = load(os.path.join(ROOT, 'assets/tilesets/edges_%s.png' % season))
        g.crop((PLAIN[0] * T, PLAIN[1] * T, PLAIN[0] * T + T, PLAIN[1] * T + T)).save(
            os.path.join(SAVED, '%s_plain.png' % season))
        e.crop((0, EDGE_ROWS[0] * T, e.width, (EDGE_ROWS[1] + 1) * T)).save(
            os.path.join(SAVED, '%s_edges.png' % season))


def write(season, ground_path, edges_path, plain, edge_strip):
    g = load(ground_path)
    g.paste(plain, (PLAIN[0] * T, PLAIN[1] * T))
    g.save(ground_path)
    e = load(edges_path)
    e.paste(Image.new('RGBA', (e.width, 2 * T), CLEAR), (0, EDGE_ROWS[0] * T))
    e.paste(edge_strip, (0, EDGE_ROWS[0] * T))
    e.save(edges_path)


def calm(season):
    plain = picture(15, season)
    strip = Image.new('RGBA', (T * T, 2 * T), CLEAR)
    for row in range(2):
        for m in range(1, 15):
            strip.paste(picture(m, season), (m * T, row * T))
    return plain, strip


def main():
    restore = '--restore' in sys.argv
    if restore and not os.path.isdir(SAVED):
        sys.exit('Nothing to restore: %s is missing.' % SAVED)
    if not restore:
        save_old()
    done = 0
    for season, g, e in targets():
        if restore:
            plain = load(os.path.join(SAVED, '%s_plain.png' % season))
            strip = load(os.path.join(SAVED, '%s_edges.png' % season))
        else:
            plain, strip = calm(season)
        write(season, g, e, plain, strip)
        done += 1
    print('%s the %s hedge in %d tilesets.' % ('Put back' if restore else 'Drew',
                                              'berry' if restore else 'calm', done))


if __name__ == '__main__':
    main()
