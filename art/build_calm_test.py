"""Build the TEST of calmer cliffs and calmer paving (DECISIONS 078).

    python art/build_calm_test.py <path to the unzipped CozyVillageFarm folder>

Run art/build_cozy_ground.py first: this starts from what it made in
assets/tilesets/cozy/ and writes, beside it, for each season:

  calm_ground_<season>.png      the cozy ground with a calmer paving tile
  calm_edges_<season>.png       the cozy edges with paving's edge to match and
                                two more rows (CLIFF_ROW, CLIFF_ROW + 1): the cliffs
  calm_tileset_<season>.tres    the cozy tileset pointing at those two, with
                                the cliff row declared

Like the rest of assets/tilesets/cozy/ these stay out of git (the pack's
licence; the repository is public). This script holds no pack art.

SeasonLook uses them while the calm test is on (Ctrl+K swaps it in the game).

The cliffs. Ours are one square tile repeated, speckled dark grey: a hard
band round every map and a dark block in the Cove. The pack draws a cliff as
raised ground: a grassy top (snowy in winter) with a dark outline where it
stops, and a brown earth face along its south side. Its sheet
(01_Terrain/Cliffs/cliffs_<season>.png) is a 3 x 3 top (corners, sides,
middle) above a row of three face pieces. A cliff cell here takes its piece
from which of its four neighbours are NOT cliff (GroundTiles.cliff_tile):

  column = 1 (north open) + 2 (east) + 4 (south) + 8 (west)
  south open  -> a face piece (its left or right end where west or east is
                 open; both: left half of one, right half of the other)
  otherwise   -> a top piece: the top row where north is open, the middle
                 row where not; the left/right column where west/east is open

A face one tile high reads as a low step, so where a cliff is two cells or
more from top to bottom its face is two tiles high: a second row of pictures
(CLIFF_ROW + 1, same columns) holds the face's upper half (its grassy lip,
no foot), used for a cell whose south neighbour is cliff but the cell below
that isn't; the lower half (no lip, the foot) is then the south-open piece.
A cliff only one cell high keeps the whole one-tile face.

The paving. The cozy pack's stone path is small bright cobbles, the busiest
thing on the quay and the town square. The calm paving is big flagstones
in two of the pack's greys, no highlights: two courses of 16 x 8 slabs a
half slab apart. Its soft edge takes grass's outline (as the path does in
build_cozy_ground.py) filled with the flagstones and rimmed in the seam
colour.
"""
import os
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = 16
SEASONS = ['spring', 'summer', 'autumn', 'winter']
COZY = os.path.join(ROOT, 'assets/tilesets/cozy')

PAVING = (0, 3)
EDGE_PAVING = 6
EDGE_GRASS = 9
VARIANTS = 2
CLIFF_ROW = 31  # and 32: scripts/ground_tiles.gd

N, E, S, W = 1, 2, 4, 8

FILL = (0xa2, 0xa7, 0xb5, 255)
SEAM = (0x6b, 0x6f, 0x80, 255)
CLEAR = (0, 0, 0, 0)


def load(path):
    return Image.open(path).convert('RGBA')


def piece(sheet, col, row):
    return sheet.crop((col * T, row * T, col * T + T, row * T + T))


def halves(left, right):
    """Left half of one tile, right half of another."""
    out = left.copy()
    out.paste(right.crop((T // 2, 0, T, T)), (T // 2, 0))
    return out


def cliff_tile(sheet, mask):
    """The cliff picture for a cell whose open sides are `mask`."""
    if mask & S:
        row = 3
    elif mask & N:
        row = 0
    else:
        row = 1
    w, e = bool(mask & W), bool(mask & E)
    if w and e:
        return halves(piece(sheet, 0, row), piece(sheet, 2, row))
    return piece(sheet, 0 if w else 2 if e else 1, row)


def face_upper(tile):
    """A face piece's top part: lip and earth, its foot (the last two rows)
    swapped for two rows of plain earth from higher up."""
    out = tile.copy()
    out.paste(tile.crop((0, 4, T, 6)), (0, 14))
    return out


def face_lower(tile):
    """A face piece's bottom part: its grassy lip (the first four rows)
    swapped for four rows of plain earth from lower down."""
    out = tile.copy()
    out.paste(tile.crop((0, 10, T, 14)), (0, 0))
    return out


def flagstones():
    """Two courses of 16 x 8 slabs, the second half a slab along."""
    tile = Image.new('RGBA', (T, T), FILL)
    px = tile.load()
    for x in range(T):
        px[x, 7] = SEAM
        px[x, 15] = SEAM
    for y in range(0, 7):
        px[15, y] = SEAM
    for y in range(8, 15):
        px[7, y] = SEAM
    return tile


def paving_edges(edges):
    """Paving's edge pictures: grass's outline (its pixels, from the cozy
    edges' grass row) filled with the flagstones, the outermost ring of it in
    the seam colour."""
    flag = flagstones()
    f = flag.load()
    for v in range(VARIANTS):
        row = EDGE_PAVING * VARIANTS + v
        grass_row = EDGE_GRASS * VARIANTS + v
        edges.paste(Image.new('RGBA', (edges.width, T), CLEAR), (0, row * T))
        for m in range(1, 15):
            g = piece(edges, m, grass_row)
            gp = g.load()
            inside = {(x, y) for y in range(T) for x in range(T) if gp[x, y][3] == 255}
            out = Image.new('RGBA', (T, T), CLEAR)
            o = out.load()
            for (x, y) in inside:
                rim = any((x + dx, y + dy) not in inside and 0 <= x + dx < T and 0 <= y + dy < T
                          for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                # Read half a tile off, as the dual grid sits (see build_cozy_ground.py).
                o[x, y] = SEAM if rim else f[(x + 8) % T, (y + 8) % T]
            edges.paste(out, (m * T, row * T))


def write_tres(season):
    with open(os.path.join(COZY, 'ground_tileset_%s.tres' % season), 'rb') as f:
        text = f.read().decode('utf-8')
    for kind in ('ground', 'edges'):
        text = text.replace('res://assets/tilesets/cozy/%s_%s.png' % (kind, season),
                            'res://assets/tilesets/cozy/calm_%s_%s.png' % (kind, season))
    assert 'cozy/calm_ground_' in text and 'cozy/calm_edges_' in text, season
    # Declare the cliff row in the edges source (it ends where [resource] starts).
    rows = ''.join('%d:%d/0 = 0\n' % (m, r) for r in (CLIFF_ROW, CLIFF_ROW + 1) for m in range(16))
    head, sep, tail = text.partition('\n[resource]')
    assert sep, season
    text = head.rstrip('\n') + '\n' + rows + '\n[resource]' + tail
    with open(os.path.join(COZY, 'calm_tileset_%s.tres' % season), 'wb') as f:
        f.write(text.encode('utf-8'))


def build(pack):
    if not os.path.exists(os.path.join(COZY, 'ground_tileset_spring.tres')):
        sys.exit('Run art/build_cozy_ground.py first.')
    for season in SEASONS:
        ground = load(os.path.join(COZY, 'ground_%s.png' % season))
        edges = load(os.path.join(COZY, 'edges_%s.png' % season))
        ground.paste(flagstones(), (PAVING[0] * T, PAVING[1] * T))
        paving_edges(edges)

        # Two more rows at the bottom for the cliffs.
        taller = Image.new('RGBA', (edges.width, (CLIFF_ROW + 2) * T), CLEAR)
        taller.paste(edges, (0, 0))
        sheet = load(os.path.join(pack, '01_Terrain', 'Cliffs', 'cliffs_%s.png' % season))
        for mask in range(16):
            tile = cliff_tile(sheet, mask)
            if mask & S and not mask & N:
                tile = face_lower(tile)
            taller.paste(tile, (mask * T, CLIFF_ROW * T))
            upper = face_upper(cliff_tile(sheet, (mask | S) & ~N))
            taller.paste(upper, (mask * T, (CLIFF_ROW + 1) * T))

        ground.save(os.path.join(COZY, 'calm_ground_%s.png' % season))
        taller.save(os.path.join(COZY, 'calm_edges_%s.png' % season))
        write_tres(season)
        print('built calm', season)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    build(sys.argv[1])
