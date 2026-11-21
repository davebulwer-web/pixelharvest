"""Build the TEST of a proper harbour in the Cove (DECISIONS 080).

    python art/build_harbour_test.py <path to the unzipped CoastBeachFishing folder>

Run art/build_cozy_ground.py and art/build_calm_test.py first: this starts
from the calm test's pictures in assets/tilesets/cozy/ and writes, beside
them, for each season:

  harbour_ground_<season>.png    the calm ground with the Coast pack's rock:
                                 the breakwater's top for the rocks, the same
                                 with a small pool for the rock shelf, and its
                                 wooden deck for the pier
  harbour_edges_<season>.png     the calm edges, the rocks' and the shelf's
                                 soft edge to match, and more rows:
       PIER_ROW (33)             the pier's deck, one picture per mix of open
                                 sides (as the cliffs: 1 N, 2 E, 4 S, 8 W)
       FRONT_ROW (34-37)         what stands in the sea just south of the
                                 harbour's edges, four frames each (the
                                 tileset animates them, frames top to
                                 bottom): the quay wall (plain, with a ladder,
                                 its left and right ends), the pier's posts
                                 (left, middle, right, single), the
                                 breakwater's foot (edge, end)
  harbour_tileset_<season>.tres  the calm tileset pointing at those two, with
                                 the new rows declared and animated

Like the rest of assets/tilesets/cozy/ these stay out of git (the pack's
licence; the repository is public). This script holds no pack art.
SeasonLook uses them while the harbour test is on (Ctrl+H swaps it).
"""
import os
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = 16
SEASONS = ['spring', 'summer', 'autumn', 'winter']
COZY = os.path.join(ROOT, 'assets/tilesets/cozy')

ROCKPOOL, PIER, ROCKS = (3, 3), (5, 3), (6, 3)
EDGE_ROCKPOOL, EDGE_ROCKS, EDGE_GRASS = 3, 10, 9
VARIANTS = 2
PIER_ROW = 33
FRONT_ROW = 34
FRAMES = 4
FPS = 6.0
N, E, S, W = 1, 2, 4, 8

# FRONT_ROW columns (scripts/ground_tiles.gd says the same).
QUAY, QUAY_LADDER, QUAY_LEFT, QUAY_RIGHT = 0, 1, 2, 3
POSTS_LEFT, POSTS_MID, POSTS_RIGHT, POSTS_SINGLE = 4, 5, 6, 7
BREAKWATER, BREAKWATER_END = 8, 9
FRONT_COUNT = 10

CLEAR = (0, 0, 0, 0)
POOL = (62, 201, 168, 255)
POOL_DEEP = (31, 138, 122, 255)
RIM = (43, 30, 47, 255)


def load(path):
    return Image.open(path).convert('RGBA')


def piece(sheet, col, row):
    return sheet.crop((col * T, row * T, col * T + T, row * T + T))


def rock_pool(rock):
    """The breakwater's top with a small, dark rock pool in it (small and
    dark, so a whole shelf of them stays calm)."""
    tile = rock.copy()
    px = tile.load()
    # The shelf is a big area: its light strokes softened to the mid grey.
    for y in range(T):
        for x in range(T):
            if px[x, y] == (162, 167, 181, 255):
                px[x, y] = (107, 111, 128, 255)
    shape = ['.###.', '#####', '.###.']
    for y, line in enumerate(shape):
        for x, c in enumerate(line):
            if c == '#':
                px[5 + x, 6 + y] = POOL_DEEP
    px[7, 6] = POOL
    return tile


def outline_edges(edges, ground_row, fill, rim):
    """`ground_row`'s edge pictures: grass's outline (the calm edges' grass
    row) filled with `fill`, its outermost ring in `rim`."""
    f = fill.load()
    for v in range(VARIANTS):
        row = ground_row * VARIANTS + v
        grass_row = EDGE_GRASS * VARIANTS + v
        edges.paste(Image.new('RGBA', (edges.width, T), CLEAR), (0, row * T))
        for m in range(1, 15):
            gp = piece(edges, m, grass_row).load()
            inside = {(x, y) for y in range(T) for x in range(T) if gp[x, y][3] == 255}
            out = Image.new('RGBA', (T, T), CLEAR)
            o = out.load()
            for (x, y) in inside:
                rimmed = any((x + dx, y + dy) not in inside and 0 <= x + dx < T and 0 <= y + dy < T
                             for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                o[x, y] = rim if rimmed else f[(x + 8) % T, (y + 8) % T]
            edges.paste(out, (m * T, row * T))


def deck_tile(deck, mask):
    """The pier's deck for a cell with these open sides. The set is
    NW N NE W C E / SW S SE narrow-N-S narrow-E-W vertical planks."""
    w, e = bool(mask & W), bool(mask & E)
    n, s = bool(mask & N), bool(mask & S)
    if w and e:
        return piece(deck, 3, 1)
    col = 0 if w else 2 if e else 1
    if n and not s:
        return piece(deck, col, 0)
    if s and not n:
        return piece(deck, col, 1)
    return piece(deck, 3 + col, 0)


def front_frames(coast):
    """column -> four frames."""
    dock = os.path.join(coast, '03_Docks_Harbour')
    wall = load(os.path.join(dock, 'Stone_Quay', 'quay_wall_in_water_16x16_4f.png'))
    posts = load(os.path.join(dock, 'Pier', 'pier_front_posts_in_water_16x16_4f.png'))
    breaker = load(os.path.join(dock, 'Breakwater', 'breakwater_16x16_4f.png'))
    rows = {QUAY: (wall, 1), QUAY_LADDER: (wall, 4), QUAY_LEFT: (wall, 0), QUAY_RIGHT: (wall, 2),
            POSTS_LEFT: (posts, 0), POSTS_MID: (posts, 1), POSTS_RIGHT: (posts, 2), POSTS_SINGLE: (posts, 3),
            BREAKWATER: (breaker, 0), BREAKWATER_END: (breaker, 1)}
    return {col: [piece(sheet, f, row) for f in range(FRAMES)] for col, (sheet, row) in rows.items()}


def write_tres(season):
    with open(os.path.join(COZY, 'calm_tileset_%s.tres' % season), 'rb') as f:
        text = f.read().decode('utf-8')
    for kind in ('ground', 'edges'):
        text = text.replace('res://assets/tilesets/cozy/calm_%s_%s.png' % (kind, season),
                            'res://assets/tilesets/cozy/harbour_%s_%s.png' % (kind, season))
    assert 'cozy/harbour_ground_' in text and 'cozy/harbour_edges_' in text, season
    lines = ['%d:%d/0 = 0' % (m, PIER_ROW) for m in range(16)]
    for col in range(FRONT_COUNT):
        cell = '%d:%d' % (col, FRONT_ROW)
        lines.append('%s/animation_columns = 1' % cell)
        lines.append('%s/animation_frames_count = %d' % (cell, FRAMES))
        for f in range(FRAMES):
            lines.append('%s/animation_frame_%d/duration = %s' % (cell, f, round(1.0 / FPS, 4)))
        lines.append('%s/0 = 0' % cell)
    head, sep, tail = text.partition('\n[resource]')
    assert sep, season
    text = head.rstrip('\n') + '\n' + '\n'.join(lines) + '\n\n[resource]' + tail
    with open(os.path.join(COZY, 'harbour_tileset_%s.tres' % season), 'wb') as f:
        f.write(text.encode('utf-8'))


def build(coast):
    if not os.path.exists(os.path.join(COZY, 'calm_tileset_spring.tres')):
        sys.exit('Run art/build_cozy_ground.py and art/build_calm_test.py first.')
    dock = os.path.join(coast, '03_Docks_Harbour')
    rock = load(os.path.join(dock, 'Breakwater', 'breakwater_top_16x16.png'))
    pool = rock_pool(rock)
    deck = load(os.path.join(dock, 'Pier', 'wood_deck_set_16x16.png'))
    fronts = front_frames(coast)
    for season in SEASONS:
        ground = load(os.path.join(COZY, 'calm_ground_%s.png' % season))
        edges = load(os.path.join(COZY, 'calm_edges_%s.png' % season))
        for cell, tile in ((ROCKS, rock), (ROCKPOOL, pool), (PIER, piece(deck, 4, 0))):
            ground.paste(tile, (cell[0] * T, cell[1] * T))
        outline_edges(edges, EDGE_ROCKS, rock, RIM)
        outline_edges(edges, EDGE_ROCKPOOL, pool, RIM)

        taller = Image.new('RGBA', (edges.width, (FRONT_ROW + FRAMES) * T), CLEAR)
        taller.paste(edges, (0, 0))
        for mask in range(16):
            taller.paste(deck_tile(deck, mask), (mask * T, PIER_ROW * T))
        for col, frames in fronts.items():
            for f, tile in enumerate(frames):
                taller.paste(tile, (col * T, (FRONT_ROW + f) * T))

        ground.save(os.path.join(COZY, 'harbour_ground_%s.png' % season))
        taller.save(os.path.join(COZY, 'harbour_edges_%s.png' % season))
        write_tres(season)
        print('built harbour', season)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    build(sys.argv[1])
