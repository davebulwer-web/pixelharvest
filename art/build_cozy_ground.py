"""Build the TEST ground look from the Cozy Village & Farm asset pack.

    python art/build_cozy_ground.py <path to the unzipped CozyVillageFarm folder>

Writes assets/tilesets/cozy/ (ground_<season>.png, edges_<season>.png and
ground_tileset_<season>.tres for each season). That folder is in .gitignore:
the pack's licence forbids passing its pictures on as files, and the GitHub
repository is public, so the pictures stay on Dave's PC only. This script
holds no pack art itself, so it can live in the repo.

SeasonLook uses the cozy tilesets when they exist and the switch is on
(Ctrl+G flips it in the game). See DECISIONS 076.

What it does, season by season. It starts from our own ground pictures (so
everything the pack has no tile for keeps ours: the rock shelf, the rocks,
the hedges, the cliffs, the pier) and puts the pack's in their places, in
our layout (GroundTiles), so no code needs to know which look is showing:

  ground_<season>.png  grass, flowery grass, grass and path details, the
                       path, tilled and watered soil, the pond (ice in
                       winter), paving, sand, wet sand (the pack's sand,
                       darkened) and the sea (the pack's deep water).
  edges_<season>.png   the soft edges, in our dual-grid layout (one row per
                       ground and variant, one column per corner mask).
                       The pack's corner autotiles are the same idea (its
                       bits are TL TR BL BR, ours 1 2 4 8), so:
       grass           the pack's grass over dirt, grass pixels only; its
                       drop shadow becomes a see-through shadow, so it suits
                       whatever lies below
       pond bank       the pack's grass over water, kept whole (winter: its
                       snow over ice)
       paving          the pack's stone path over grass, stones only
       sand            the pack's sand over water, sand pixels only
       foam            the rest of that sheet: the pale surf line and the
                       shadow round the sand (still: the pack's animated
                       sheet only ripples the water)
       wet sand        sand's shape, in the darkened sand
       pond over sea   the pack's water over deep water
       path, tilled,   no pack sheet: grass's outline, filled with the
       watered tilled  ground's own tile, rimmed in its darkest colour
       scatter         left empty: the calmer look is the point
  The rock shelf, rocks and hedge rows keep our own edges.

Colours: the pack's own 46 colours are kept exactly (DECISIONS 076); none of
them is in art/palette.png, so the palette checker will list them. That is
expected while this is a test.
"""
import os
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = 16
SEASONS = ['spring', 'summer', 'autumn', 'winter']
OUT = os.path.join(ROOT, 'assets/tilesets/cozy')

# Our layout (scripts/ground_tiles.gd).
GRASS, GRASS_ALT, PATH, TILLED, TILLED_WET, WATER = (0, 0), (1, 0), (2, 0), (3, 0), (4, 0), (5, 0)
PAVING, SAND, WET_SAND, SEA = (0, 3), (1, 3), (2, 3), (4, 3)
GRASS_DETAIL_ROW, PATH_DETAIL_ROW = 1, 2
EDGE = {'sea': 0, 'water': 1, 'wet_sand': 2, 'rockpool': 3, 'sand': 4, 'path': 5, 'paving': 6,
        'tilled': 7, 'tilled_wet': 8, 'grass': 9, 'rocks': 10, 'thicket': 11}
VARIANTS = 2
SCATTER_ROW = 24
BANK_ROW = 25
FOAM_ROW = 27
FOAM_FRAMES = 4
SHADOW = (0, 0, 0, 72)
CLEAR = (0, 0, 0, 0)

# The pack's corner layout (its _AUTOTILE_LAYOUT_GUIDE.png): the 4 x 4 sheet
# read left to right, top to bottom, as TL TR BL BR bits.
PACK_ORDER = ['0001', '0011', '0010', '1110', '0101', '1111', '1010', '1101',
              '0100', '1100', '1000', '1011', '0000', '0110', '1001', '0111']
PACK_CELL = {}
for _i, _bits in enumerate(PACK_ORDER):
    _mask = int(_bits[0]) * 1 + int(_bits[1]) * 2 + int(_bits[2]) * 4 + int(_bits[3]) * 8
    PACK_CELL[_mask] = (_i % 4, _i // 4)


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def load(path):
    return Image.open(path).convert('RGBA')


def sheet_tiles(img, frame=0):
    """mask -> 16 x 16 tile from a pack autotile sheet (one frame of it)."""
    return {m: img.crop((frame * 64 + c * T, r * T, frame * 64 + c * T + T, r * T + T))
            for m, (c, r) in PACK_CELL.items()}


def put(img, cell, tile):
    img.paste(tile, (cell[0] * T, cell[1] * T))


def edge_row_put(edges, ground, mask_tiles):
    """Both variant rows of `ground` get the same pictures (one outline)."""
    for v in range(VARIANTS):
        row = EDGE[ground] * VARIANTS + v
        clear_row(edges, row)
        for m, t in mask_tiles.items():
            if 0 < m < 15:
                put(edges, (m, row), t)


def clear_row(edges, row):
    edges.paste(Image.new('RGBA', (edges.width, T), CLEAR), (0, row * T))


def diff_tile(tile, lower, keep=None):
    """The pixels of `tile` that differ from the all-lower tile; `keep(x, y,
    colour)` may say which of those to keep."""
    out = Image.new('RGBA', (T, T), CLEAR)
    a, lo, o = tile.load(), lower.load(), out.load()
    for y in range(T):
        for x in range(T):
            if a[x, y] != lo[x, y] and (keep is None or keep(x, y, a[x, y])):
                o[x, y] = a[x, y]
    return out


def darkest_rim(tile, palette):
    """One step darker than the tile's darkest colour, from the pack palette."""
    cols = {p[:3] for p in tile.getdata() if p[3] > 0}
    dark = min(cols, key=lum)
    darker = [p for p in palette if lum(p) < lum(dark) - 8]
    if not darker:
        return dark + (255,)
    target = tuple(int(v * 0.72) for v in dark)
    return min(darker, key=lambda p: sum((a - b) ** 2 for a, b in zip(p, target))) + (255,)


def nearest(c, palette):
    return min(palette, key=lambda p: sum((a - b) ** 2 for a, b in zip(p, c[:3]))) + (255,)


class Shape:
    """An outline read from a pack sheet: per mask, which pixels are the upper
    ground ('in'), its outline ('rim') and its drop shadow ('shadow')."""

    def __init__(self):
        self.kind = {}  # mask -> {(x, y): 'in' | 'rim' | 'shadow'}

    def picture(self, fill, rim):
        """Pictures by mask: `fill` (a plain 16 x 16 tile, read half a tile
        off, as the dual grid sits) for 'in', `rim` colour, shadow see-through."""
        pics = {}
        f = fill.load()
        for m, kinds in self.kind.items():
            out = Image.new('RGBA', (T, T), CLEAR)
            o = out.load()
            for (x, y), k in kinds.items():
                if k == 'in':
                    o[x, y] = f[(x + 8) % T, (y + 8) % T]
                elif k == 'rim':
                    o[x, y] = rim
                else:
                    o[x, y] = SHADOW
            pics[m] = out
        return pics


def grass_shape(sheets):
    """Grass's outline from its sheets over several lowers: a pixel is grass
    where every sheet draws the same colour there and it differs from the
    lower; 'rim' if it's the darkest grass colour; other changed pixels are
    the shadow it throws (they differ by lower)."""
    tiles = [sheet_tiles(s) for s in sheets]
    full = tiles[0][15]
    upper_cols = {p for p in full.getdata()}
    shape = Shape()
    for m in range(1, 15):
        kinds = {}
        for y in range(T):
            for x in range(T):
                cols = [t[m].getpixel((x, y)) for t in tiles]
                lows = [t[0].getpixel((x, y)) for t in tiles]
                changed = [c != lo for c, lo in zip(cols, lows)]
                if all(changed) and len(set(cols)) == 1:
                    kinds[(x, y)] = 'in' if cols[0] in upper_cols else 'rim'
                elif changed[0]:
                    lo = lows[0]
                    if lum(cols[0]) < lum(lo):
                        kinds[(x, y)] = 'shadow'
        shape.kind[m] = kinds
    return shape


def grass_pictures(sheet, shape):
    """The grass's own pixels from `sheet` (not a fill), with see-through shadow."""
    t = sheet_tiles(sheet)
    pics = {}
    for m, kinds in shape.kind.items():
        out = Image.new('RGBA', (T, T), CLEAR)
        o = out.load()
        for (x, y), k in kinds.items():
            o[x, y] = SHADOW if k == 'shadow' else t[m].getpixel((x, y))
        pics[m] = out
    return pics


def sand_split(anim, frames=FOAM_FRAMES):
    """From the animated sand-over-water sheet: per mask, the sand pixels
    (sand coloured and the same in every frame) and, per frame, the foam (the
    other changed pixels)."""
    frames = [sheet_tiles(anim, f) for f in range(frames)]
    sand_cols = {p for p in frames[0][15].getdata()}
    sand, foam = {}, [dict() for _ in frames]
    shape = Shape()
    for m in range(16):
        s = Image.new('RGBA', (T, T), CLEAR)
        kinds = {}
        fo = [Image.new('RGBA', (T, T), CLEAR) for _ in frames]
        for y in range(T):
            for x in range(T):
                cols = [fr[m].getpixel((x, y)) for fr in frames]
                lows = [fr[0].getpixel((x, y)) for fr in frames]
                is_sand = len(set(cols)) == 1 and cols[0] in sand_cols and cols[0] != lows[0]
                if m == 15:
                    is_sand = True
                if is_sand:
                    s.putpixel((x, y), cols[0])
                    kinds[(x, y)] = 'in'
                else:
                    for f in range(len(frames)):
                        if cols[f] != lows[f]:
                            fo[f].putpixel((x, y), cols[f])
        sand[m] = s
        shape.kind[m] = kinds
        for f in range(len(frames)):
            foam[f][m] = fo[f]
    return sand, foam, shape


def recolour(img, mapping):
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if px[x, y][3] > 0 and px[x, y][:3] in mapping:
                px[x, y] = mapping[px[x, y][:3]] + (px[x, y][3],)
    return out


def write_tres(season):
    """A copy of our season's ground tileset with the two pictures swapped
    for the cozy ones (same layout, same collision, same foam animation)."""
    src = 'ground_tileset.tres' if season == 'spring' else 'ground_tileset_%s.tres' % season
    with open(os.path.join(ROOT, 'assets/tilesets', src), 'rb') as f:
        text = f.read().decode('utf-8')
    for kind in ('ground', 'edges'):
        text = text.replace('res://assets/tilesets/%s_%s.png' % (kind, season),
                            'res://assets/tilesets/cozy/%s_%s.png' % (kind, season))
    assert 'tilesets/cozy/ground_' in text and 'tilesets/cozy/edges_' in text, src
    with open(os.path.join(OUT, 'ground_tileset_%s.tres' % season), 'wb') as f:
        f.write(text.encode('utf-8'))


def build(pack):
    terrain = os.path.join(pack, '01_Terrain')
    base = lambda *p: load(os.path.join(terrain, 'Base_Tiles', *p))
    auto = lambda *p: load(os.path.join(terrain, 'Autotiles', *p))
    with open(os.path.join(pack, 'Palette', 'cozy_village_palette.hex')) as f:
        palette = [tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) for h in f.read().split()]
    os.makedirs(OUT, exist_ok=True)

    # The still sheet, not the animated one: only the still one has the pale
    # surf line along the sand (the animated one just ripples the water), so
    # the foam stays still: all four frames alike.
    sand_still = auto('common', 'sand_over_water.png')
    sand_pics, foam_pics, sand_shape = sand_split(sand_still, frames=1)
    foam_pics = foam_pics * FOAM_FRAMES
    sand_tile = base('common', 'sand_1.png')
    # Wet sand: each sand colour a step darker, on the pack's palette.
    wet_map = {}
    for c in {p[:3] for p in sand_tile.getdata()} | {p[:3] for m in sand_pics for p in sand_pics[m].getdata() if p[3]}:
        wet_map[c] = nearest(tuple(int(v * 0.84) for v in c), [p for p in palette if lum(p) < lum(c) - 6] or palette)[:3]
    wet_tile = recolour(sand_tile, wet_map)
    sea_tile = base('common', 'deep_water.png')
    pond_sheet = auto('common', 'water_over_deep_water_anim_4f.png')
    pond_tiles = sheet_tiles(pond_sheet, 0)

    for season in SEASONS:
        ground = load(os.path.join(ROOT, 'assets/tilesets/ground_%s.png' % season))
        edges = load(os.path.join(ROOT, 'assets/tilesets/edges_%s.png' % season))
        g = lambda n: base(season, n)

        grass, grass2, grass3, flowers = g('grass_1.png'), g('grass_2.png'), g('grass_3.png'), g('grass_flowers.png')
        dirt, dirt2, stone = g('dirt_1.png'), g('dirt_2.png'), g('stone_path.png')
        tilled, watered = base('common', 'soil_tilled.png'), base('common', 'soil_watered.png')
        pond = base('common', 'ice.png' if season == 'winter' else 'water.png')

        # --- plain tiles -----------------------------------------------------
        put(ground, GRASS, grass)
        put(ground, GRASS_ALT, flowers)
        for i, t in enumerate([grass2, grass3, grass2, grass3, flowers, grass2, grass3, grass]):
            put(ground, (i, GRASS_DETAIL_ROW), t)
        put(ground, PATH, dirt)
        for i, t in enumerate([dirt2, dirt, dirt2, dirt2]):
            put(ground, (i, PATH_DETAIL_ROW), t)
        put(ground, TILLED, tilled)
        put(ground, TILLED_WET, watered)
        put(ground, WATER, pond)
        put(ground, PAVING, stone)
        put(ground, SAND, sand_tile)
        put(ground, WET_SAND, wet_tile)
        put(ground, SEA, sea_tile)

        # --- edges -----------------------------------------------------------
        over = [auto(season, n) for n in ('grass_over_dirt.png', 'grass_over_sand.png',
                                          'grass_over_tilled_soil.png', 'grass_over_watered_soil.png')]
        shape = grass_shape(over)
        edge_row_put(edges, 'grass', grass_pictures(over[0], shape))
        for name, fill in (('path', dirt), ('tilled', tilled), ('tilled_wet', watered)):
            edge_row_put(edges, name, shape.picture(fill, darkest_rim(fill, palette)))

        stone_sheet = sheet_tiles(auto(season, 'stone_path_over_grass.png'))
        edge_row_put(edges, 'paving', {m: diff_tile(stone_sheet[m], stone_sheet[0]) for m in range(16)})

        edge_row_put(edges, 'sand', sand_pics)
        edge_row_put(edges, 'wet_sand', {m: recolour(p, wet_map) for m, p in sand_pics.items()})

        if season == 'winter':
            water_shape = Shape()
            for m in range(1, 15):
                water_shape.kind[m] = {(x, y): 'in' for y in range(T) for x in range(T)
                                       if pond_tiles[m].getpixel((x, y)) != pond_tiles[0].getpixel((x, y))}
            edge_row_put(edges, 'water', water_shape.picture(pond, darkest_rim(pond, palette)))
            bank = sheet_tiles(auto('winter', 'snow_over_ice.png'))
        else:
            edge_row_put(edges, 'water', {m: diff_tile(pond_tiles[m], pond_tiles[0]) for m in range(16)})
            bank = sheet_tiles(auto(season, 'grass_over_water.png'))
        bank_pics = {m: diff_tile(bank[m], bank[0]) for m in range(16)}
        for v in range(VARIANTS):
            clear_row(edges, BANK_ROW + v)
            for m in range(1, 15):
                put(edges, (m, BANK_ROW + v), bank_pics[m])

        clear_row(edges, SCATTER_ROW)
        for f in range(FOAM_FRAMES):
            clear_row(edges, FOAM_ROW + f)
            for m in range(1, 16):
                put(edges, (m, FOAM_ROW + f), foam_pics[f][m])

        ground.save(os.path.join(OUT, 'ground_%s.png' % season))
        edges.save(os.path.join(OUT, 'edges_%s.png' % season))
        write_tres(season)
        print('built', season)

    with open(os.path.join(OUT, 'README.txt'), 'w', newline='\r\n') as f:
        f.write('TEST ground look built from the Cozy Village & Farm asset pack by\n'
                'art/build_cozy_ground.py (DECISIONS 076).\n\n'
                'Not in git (.gitignore): the pack licence forbids passing its pictures on\n'
                'as files, and the GitHub repository is public. Ctrl+G in the game swaps\n'
                'between this look and our own. Deleting this folder puts our own look\n'
                'back for good.\n')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    build(sys.argv[1])
