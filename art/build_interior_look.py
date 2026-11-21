"""
build_interior_look.py - furnish the rooms you can walk into (the four shops,
the farmhouse, the tavern: DECISIONS 083; the townsfolk's homes: DECISIONS 084)
from the Cozy Interiors & Town Life pack, by the same author as the ground and
props packs.

    python art/build_interior_look.py <path to the unzipped CozyInteriors folder>

It writes assets/packs/interiors/: one baked picture per room (walls, floor,
rugs, door mats, stools: everything flat that nobody stands behind), the
pictures of the pieces that stand in the room (shelves, counters, barrels,
lights, the bed ...), and interior_look.json saying where each piece goes.
scripts/interior_look.gd (InteriorLook) reads it. Ctrl+R in a room flips it.

The pack's licence lets the game use these pictures but not pass the files on,
and the GitHub repository is public, so assets/packs/ is git-ignored. This
script holds no pack art and is committed: anyone with the pack can rebuild.

The rooms' shapes (size, door) are copied from interior.gd, farmhouse.gd and
tavern.gd, and the homes' from their LocationDefs (room_size, room_door_x). InteriorLook checks them against the room it is dressing and stays
out of the way if they ever differ, so a room changed later never shows a
wrong picture, it just shows ours.

Colours: every picture keeps the pack's colours exactly (it is on the same 55
colour palette as the other packs). At the end the script lists any of them
that are not yet in art/palette.png, as the palette checker would; if Dave
keeps the look, the palette is rebuilt with them (DECISIONS 015, 077).

Rebuilding overwrites files in place and never deletes, so Godot's .import
files next to them stay valid.
"""

import json
import os
import sys

from PIL import Image

T = 16
HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
OUT = os.path.join(PROJECT, 'assets', 'packs', 'interiors')

PACK = ''


def img(rel):
    return Image.open(os.path.join(PACK, rel)).convert('RGBA')


# --- Where the pack keeps things --------------------------------------------

FURN = '03_Furniture/'
SHOP = FURN + 'Shops/'
KITCHEN = FURN + 'Kitchen/'
LIVING = FURN + 'Living_Room/'
BEDROOM = FURN + 'Bedroom/'
TAVERN = FURN + 'Tavern_Inn/'
WORK = FURN + 'Workshops/'
CELLAR = FURN + 'Cellar_Storage/'
TABLETOP = FURN + 'Tabletop/'
LIGHTS = '04_Lights_Decor/Lights/'
WALL = '04_Lights_Decor/Wall_Decor/'
EXTRAS = '02_Walls_Doors/Extras/'
FLOORS = '01_Interior_Tiles/Floors/'
RUGS = '01_Interior_Tiles/Rugs/Fixed/'
MATS = '01_Interior_Tiles/Door_Mats/'
PETS = '06_NPCs_Pets/Pets/'

# The 47 wall-top pieces, in the order the sheet holds them (the pack's guide):
# each is an 8-bit mask N=1 NE=2 E=4 SE=8 S=16 SW=32 W=64 NW=128, a diagonal
# only counting when both sides next to it are wall too.
BLOB = sorted({m for m in range(256) if all(
    not (m & d) or ((m & a) and (m & b))
    for d, a, b in ((2, 1, 4), (8, 4, 16), (32, 16, 64), (128, 64, 1)))})
assert len(BLOB) == 47


# --- Room specs ----------------------------------------------------------------
#
# Cells are the room's own (as in the room scripts): x from 0 at the left
# wall's inside, y 0-1 the back wall's face, the floor from y 2, the door a
# gap in the bottom wall (y = room height).
#
# Every "piece" stands with its picture's bottom-left on the bottom-left of
# its cell: {'pic': ..., 'cell': (x, y)} plus, when needed, 'lift' (pixels up:
# things hung on the wall), 'above' (drawn over people: hanging lights),
# 'solid' (nobody walks through it: one row at its foot, its full width, or
# 'depth' rows),
# 'night' (the picture after dark: windows) and 'frames' (an animation strip,
# read from the file name's _<n>f).

def face(style):
    if style.startswith('wallpaper_'):
        base = '02_Walls_Doors/Wallpapers/%s/%s_face_' % (style[len('wallpaper_'):], style)
    else:
        base = '02_Walls_Doors/%s/%s_wall_face_' % (style, style)
    return {k: base + k + '.png' for k in ('left', 'mid', 'right')}


def tops(style):
    return '02_Walls_Doors/%s/%s_wall_tops_47blob.png' % (style, style)


def window(style):
    return {'pic': '02_Walls_Doors/%s/%s_window_day.png' % (style, style),
            'night': '02_Walls_Doors/%s/%s_window_night.png' % (style, style)}


def curtains(colour):
    return {'pic': EXTRAS + 'window_curtains_%s_day.png' % colour,
            'night': EXTRAS + 'window_curtains_%s_night.png' % colour}


def on_wall(piece, x, lift=8):
    """Something hung on the back wall's face at column x."""
    d = dict(piece) if isinstance(piece, dict) else {'pic': piece}
    d.update(cell=(x, 1), lift=lift)
    return d


def stand(pic, x, y, solid=True, **kw):
    d = {'pic': pic, 'cell': (x, y), 'solid': solid}
    d.update(kw)
    return d


def counter(parts):
    """A row of 16 x 32 counter pieces as one picture (left to right)."""
    return {'composite': [(p, i * T, 0) for i, p in enumerate(parts)], 'size': (len(parts) * T, 32)}


# What our rooms draw, by picture, that the pack's pictures stand in for:
# InteriorLook hides those sprites (their collision stays exactly as it is).
OURS = 'res://assets/sprites/'

SHOP_HIDE = [OURS + 'town/counter.png', OURS + 'town/shelf.png']

ROOMS = {}

# Hollis's Seeds: warm wood, sacks and barrels of what grows.
ROOMS['seed_shop'] = dict(
    size=(12, 8), door=(5, 6), wall='village_wood',
    floor=FLOORS + 'village_wood/floor_village_wood_planks_warm.png',
    floor_b=FLOORS + 'village_wood/floor_village_wood_planks_warm_b.png',
    rugs=[(RUGS + 'rug_green_48x32.png', 4.5, 7)],
    mat=MATS + 'door_mat_brown.png',
    hide=SHOP_HIDE,
    pieces=[
        stand(SHOP + 'goods_shelf_general.png', 0, 2),
        stand(SHOP + 'goods_shelf_general.png', 10, 2),
        stand(CELLAR + 'sack_stack.png', 3, 2),
        stand(CELLAR + 'crate_labeled.png', 8, 2),
        stand(KITCHEN + 'butter_churn.png', 5, 2),
        dict(stand(None, 3, 4), **counter([SHOP + 'shop_counter_plain_left.png',
                                           SHOP + 'shop_counter_scale.png',
                                           SHOP + 'shop_counter_general.png',
                                           SHOP + 'shop_counter_cashbox.png',
                                           SHOP + 'shop_counter_plain_mid.png',
                                           SHOP + 'shop_counter_plain_right.png']),
             solid=False, key='seed_counter'),
        stand(SHOP + 'barrel_carrots.png', 0, 5),
        stand(SHOP + 'barrel_potatoes.png', 0, 6),
        stand(SHOP + 'barrel_apples.png', 11, 5),
        stand(SHOP + 'barrel_flowers.png', 11, 6),
        stand(LIVING + 'plant_flowers.png', 0, 7),
        stand(LIVING + 'plant_fern.png', 11, 7),
        on_wall(window('village_wood'), 2),
        on_wall(window('village_wood'), 9),
        on_wall(WALL + 'herbs_bundle_green.png', 3, 14),
        on_wall(WALL + 'garlic_bundle.png', 8, 14),
        on_wall(WALL + 'calendar.png', 6, 12),
        on_wall(LIGHTS + 'lantern_wall_anim_4f.png', 4, 8),
        on_wall(LIGHTS + 'lantern_wall_anim_4f.png', 7, 8),
    ])

# Marlow's General Store: plaster and birch, a bit of everything.
ROOMS['general_store'] = dict(
    size=(12, 8), door=(5, 6), wall='village_plaster',
    floor=FLOORS + 'Generic/floor_planks_birch.png',
    rugs=[(RUGS + 'rug_blue_48x32.png', 4.5, 7)],
    mat=MATS + 'door_mat_green.png',
    hide=SHOP_HIDE,
    pieces=[
        stand(SHOP + 'goods_shelf_general.png', 0, 2),
        stand(SHOP + 'goods_shelf_tailor.png', 10, 2),
        stand(CELLAR + 'wine_rack.png', 3, 2),
        stand(CELLAR + 'crate.png', 8, 2),
        dict(stand(None, 3, 4), **counter([SHOP + 'shop_counter_plain_left.png',
                                           SHOP + 'shop_counter_cashbox.png',
                                           SHOP + 'shop_counter_general.png',
                                           SHOP + 'shop_counter_plain_mid.png',
                                           SHOP + 'shop_counter_bell.png',
                                           SHOP + 'shop_counter_plain_right.png']),
             solid=False, key='store_counter'),
        stand(CELLAR + 'crate_labeled.png', 0, 5),
        stand(CELLAR + 'crate_dark.png', 0, 6),
        stand(SHOP + 'barrel_fish.png', 11, 5),
        stand(SHOP + 'mannequin_coat.png', 11, 6),
        stand(LIVING + 'plant_succulent.png', 0, 7),
        on_wall(curtains('red'), 2),
        on_wall(curtains('red'), 9),
        on_wall(WALL + 'coat_hooks.png', 4, 12),
        on_wall(WALL + 'wall_map.png', 7, 12),
        on_wall(LIGHTS + 'sconce_iron_anim_6f.png', 6, 8),
    ])

# Mabel's Bakery: cream wallpaper, terracotta tiles, the oven going.
ROOMS['bakery'] = dict(
    size=(12, 8), door=(5, 6), wall='wallpaper_floral_cream', top='village_plaster',
    floor=FLOORS + 'Generic/floor_tiles_terracotta_small.png',
    rugs=[(RUGS + 'rug_cream_48x32.png', 4.5, 7)],
    mat=MATS + 'door_mat_red_welcome.png',
    hide=SHOP_HIDE,
    pieces=[
        stand(KITCHEN + 'bakery_oven_32x48_anim_6f.png', 0, 2),
        stand(SHOP + 'goods_shelf_bakery.png', 10, 2),
        stand(KITCHEN + 'counter_bread_left.png', 3, 2),
        stand(KITCHEN + 'counter_bread_mid.png', 4, 2),
        stand(KITCHEN + 'counter_bread_right.png', 5, 2),
        stand(KITCHEN + 'pantry_shelf.png', 7, 2),
        dict(stand(None, 3, 4), **counter([SHOP + 'shop_counter_plain_left.png',
                                           SHOP + 'shop_counter_bakery.png',
                                           SHOP + 'shop_counter_cashbox.png',
                                           SHOP + 'shop_counter_bakery.png',
                                           SHOP + 'shop_counter_bell.png',
                                           SHOP + 'shop_counter_plain_right.png']),
             solid=False, key='bakery_counter'),
        stand(KITCHEN + 'butter_churn.png', 0, 5),
        stand(CELLAR + 'sack_stack.png', 0, 7),
        stand(KITCHEN + 'icebox.png', 11, 5),
        stand(SHOP + 'barrel_pears.png', 11, 6),
        stand(LIVING + 'plant_flowers.png', 11, 7),
        on_wall(window('village_plaster'), 3),
        on_wall(window('village_plaster'), 8),
        on_wall(WALL + 'menu_chalkboard.png', 5, 14),
        on_wall(WALL + 'decor_plate_red.png', 4, 14),
        on_wall(WALL + 'decor_plate_blue.png', 7, 14),
        on_wall(WALL + 'round_clock.png', 9, 14),
    ])

# Brann's Forge: stone, the forge glowing, tools on the wall.
ROOMS['blacksmith'] = dict(
    size=(12, 8), door=(5, 6), wall='castle',
    floor=FLOORS + 'castle/floor_castle_flagstone.png',
    floor_b=FLOORS + 'castle/floor_castle_flagstone_b.png',
    rugs=[],
    mat=MATS + 'door_mat_brown.png',
    hide=SHOP_HIDE,
    pieces=[
        stand(WORK + 'blacksmith_forge_32x48_anim_6f.png', 0, 2),
        stand(SHOP + 'weapon_rack_axes.png', 10, 2),
        stand(WORK + 'grindstone_anim_4f.png', 3, 2),
        stand(WORK + 'quench_barrel_anim_3f.png', 8, 2),
        dict(stand(None, 3, 4), **counter([SHOP + 'shop_counter_plain_left.png',
                                           SHOP + 'shop_counter_weapons.png',
                                           SHOP + 'shop_counter_plain_mid.png',
                                           SHOP + 'shop_counter_cashbox.png',
                                           SHOP + 'shop_counter_armor.png',
                                           SHOP + 'shop_counter_plain_right.png']),
             solid=False, key='forge_counter'),
        stand(WORK + 'anvil.png', 0, 5),
        stand(CELLAR + 'crate_dark.png', 0, 6),
        stand(WORK + 'plank_pile.png', 10, 7),
        stand(SHOP + 'armor_stand_leather.png', 11, 5),
        on_wall(WORK + 'tool_rack_smith.png', 4, 12),
        on_wall(WORK + 'tool_rack_smith.png', 6, 12),
        on_wall(window('castle'), 8),
        on_wall(WALL + 'horseshoe.png', 3, 16),
        on_wall(LIGHTS + 'wall_torch_anim_6f.png', 2, 12),
        on_wall(LIGHTS + 'wall_torch_anim_6f.png', 9, 12),
    ])

# The farmhouse: log walls, a made bed, a small kitchen corner, a cat.
ROOMS['farmhouse'] = dict(
    size=(8, 6), door=(3, 4), wall='log_cabin',
    floor=FLOORS + 'village_wood/floor_village_wood_planks_warm.png',
    floor_b=FLOORS + 'village_wood/floor_village_wood_planks_warm_b.png',
    rugs=[(RUGS + 'rug_red_48x32.png', 2.5, 5)],
    mat=MATS + 'door_mat_red_welcome.png',
    hide=[OURS + 'farm/bed.png', OURS + 'farm/table.png'],
    pieces=[
        # The bed stands where ours does (its foot on 1,3): ours is hidden,
        # its collision and E-to-sleep stay.
        stand(BEDROOM + 'bed_single_blue_made.png', 1, 3, solid=False),
        stand(BEDROOM + 'nightstand_oak.png', 0, 2),
        stand(KITCHEN + 'counter_plain_single.png', 3, 2),
        stand(KITCHEN + 'icebox.png', 5, 2),
        # The table stands where ours does (6,2): ours is hidden, its box stays.
        stand(LIVING + 'table_oak_small_16x32.png', 6, 2, solid=False),
        stand(LIVING + 'chair_oak_left.png', 7, 2),
        stand(BEDROOM + 'chest_oak_closed.png', 0, 5),
        stand(LIVING + 'grandfather_clock_16x48_anim_4f.png', 7, 4, fps=2),
        stand(LIVING + 'plant_fern.png', 7, 5),
        stand(PETS + 'cat_orange_strips/cat_orange_sleep_4f.png', 6, 4, solid=False, fps=3),
        on_wall(curtains('blue'), 1, 12),
        on_wall(curtains('blue'), 6),
        on_wall(KITCHEN + 'pans_rack_wall.png', 2, 14),
    ])

# The Wheatsheaf: dark planks, a long bar with taps, the fire, lanterns, a cat.
ROOMS['tavern'] = dict(
    size=(16, 10), door=(7, 8), wall='village_wood',
    floor=FLOORS + 'village_wood/floor_village_wood_planks_dark.png',
    rugs=[(RUGS + 'rug_red_64x48.png', 6, 9)],
    stools=[(1, 7), (4, 7), (8, 6), (11, 6), (11, 8), (14, 8)],
    mat=MATS + 'door_mat_brown.png',
    hide=[OURS + 'town/tavern_bar.png', OURS + 'town/tavern_table.png',
          OURS + 'town/barrels.png', OURS + 'town/fireplace.png'],
    pieces=[
        stand(TAVERN + 'bottle_shelf.png', 0, 2),
        stand(TAVERN + 'keg_rack.png', 3, 2),
        dict(stand(None, 0, 4), **counter([TAVERN + 'bar_counter_plain_left.png',
                                           TAVERN + 'bar_counter_mugs_mid.png',
                                           TAVERN + 'bar_counter_taps_mid.png',
                                           TAVERN + 'bar_counter_plain_mid.png',
                                           TAVERN + 'bar_counter_mugs_mid.png',
                                           TAVERN + 'bar_counter_plain_right.png']),
             solid=False, key='tavern_bar'),
        # Where our barrels and fireplace stand (their boxes stay).
        stand(TAVERN + 'barrel_with_tap.png', 6, 3, solid=False),
        stand(TAVERN + 'barrel_with_tap.png', 7, 3, solid=False),
        stand(TAVERN + 'fireplace_stone_48x48_anim_6f.png', 11, 2, solid=False),
        stand(PETS + 'cat_grey_strips/cat_grey_sleep_4f.png', 12, 3, solid=False, fps=3),
        # The three tables (each's left cell, as tavern.gd), set for supper.
        dict(stand(None, 2, 7, solid=False), key='tavern_table_a', composite=[
            (LIVING + 'table_oak_32x32.png', 0, 0), (TABLETOP + 'tabletop_mug.png', 1, 1),
            (TABLETOP + 'tabletop_pie.png', 15, 2)], size=(32, 32)),
        dict(stand(None, 9, 6, solid=False), key='tavern_table_b', composite=[
            (LIVING + 'table_oak_32x32.png', 0, 0), (TABLETOP + 'tabletop_mug.png', 2, 1),
            (TABLETOP + 'tabletop_mug.png', 14, 3)], size=(32, 32)),
        dict(stand(None, 12, 8, solid=False), key='tavern_table_c', composite=[
            (LIVING + 'table_oak_32x32.png', 0, 0), (TABLETOP + 'tabletop_bread_plate.png', 2, 2),
            (TABLETOP + 'tabletop_candle.png', 15, 1)], size=(32, 32)),
        stand(LIVING + 'plant_fern.png', 0, 9),
        stand(LIVING + 'plant_fern.png', 15, 9),
        stand(TAVERN + 'instrument_lute.png', 15, 5),
        on_wall(LIGHTS + 'lantern_wall_anim_4f.png', 2, 10),
        on_wall(LIGHTS + 'lantern_wall_anim_4f.png', 8, 8),
        on_wall(LIGHTS + 'lantern_wall_anim_4f.png', 15, 8),
        on_wall(WALL + 'mounted_antlers.png', 5, 16),
    ])


# --- The townsfolk's homes (DECISIONS 084) -------------------------------------
#
# One room scene (scripts/town/home.gd) serves every home; each home's size,
# door and resting spot are on its LocationDef (data/locations/<id>.tres), and
# copied here. 'depth' makes a solid piece more than one row deep (a bed, a
# wardrobe), so nobody walks over its far end. Each keeps a clear way from
# the door to where its owner stands (the LocationDef's resident_cell).

PETS_STRIP = PETS + '%s_strips/%s_sleep_4f.png'


def pet(kind, x, y):
    return stand(PETS_STRIP % (kind, kind), x, y, solid=False, fps=3)


def table_with(table, key, x, y, things, width=32):
    """A table with things on it, baked as one picture."""
    return dict(stand(None, x, y), key=key, size=(width, 32),
                composite=[(table, 0, 0)] + [(t, tx, ty) for t, tx, ty in things])


# Mayor Bramble: red damask, walnut and a marble fireplace; his portrait over
# the desk, books he hasn't read, a piano for the council's carols.
ROOMS['mayor_house'] = dict(
    size=(12, 8), door=(5, 6), wall='wallpaper_damask_red', top='village_wood',
    floor=FLOORS + 'Generic/floor_parquet_walnut.png',
    rugs=[(RUGS + 'rug_red_64x48.png', 4, 7)],
    mat=MATS + 'door_mat_red_welcome.png',
    pieces=[
        stand(LIVING + 'bookshelf_tall_full_32x48.png', 0, 2),
        stand(LIVING + 'grandfather_clock_16x48_anim_4f.png', 2, 2, fps=2),
        stand(TAVERN + 'fireplace_marble_48x48_anim_6f.png', 5, 2),
        stand(LIVING + 'armchair_red_right.png', 4, 3),
        stand(LIVING + 'armchair_red_left.png', 8, 3),
        stand(WORK + 'globe.png', 11, 2),
        stand(LIVING + 'desk_walnut_48x32.png', 9, 5, depth=2),
        stand(LIVING + 'piano.png', 10, 7),
        stand(BEDROOM + 'bed_double_red_made_walnut.png', 0, 5, depth=2),
        stand(BEDROOM + 'nightstand_walnut_lamp_on.png', 2, 4),
        stand(BEDROOM + 'wardrobe_walnut_closed.png', 0, 7),
        stand(LIVING + 'plant_fern.png', 2, 7),
        on_wall(curtains('red'), 3),
        on_wall(curtains('red'), 9),
        on_wall(LIGHTS + 'sconce_gold_anim_6f.png', 4, 10),
        on_wall(LIGHTS + 'sconce_gold_anim_6f.png', 8, 10),
        on_wall(WALL + 'painting_portrait_32x24.png', 10, 10),
    ])

# Wren: a fisherman's cottage by the river. Rods in the rack, the catch drying,
# a stew on the stove, a trophy on the wall.
ROOMS['wren_cottage'] = dict(
    size=(8, 6), door=(3, 4), wall='village_wood',
    floor=FLOORS + 'log_cabin/floor_log_cabin_wide_planks_worn.png',
    floor_b=FLOORS + 'log_cabin/floor_log_cabin_wide_planks_b.png',
    rugs=[(RUGS + 'rug_green_round_32x32.png', 4, 5)],
    mat=MATS + 'door_mat_green.png',
    pieces=[
        stand(BEDROOM + 'bed_single_green_made.png', 0, 3, depth=2),
        stand(KITCHEN + 'stove_32x32_anim_4f.png', 2, 2, fps=4),
        stand(FURN + 'Tribal_Igloo/fish_drying_rack.png', 4, 2),
        stand(SHOP + 'weapon_rack_staves.png', 6, 2),
        stand(BEDROOM + 'chest_oak_closed.png', 0, 5),
        stand(SHOP + 'barrel_fish.png', 7, 4),
        stand(CELLAR + 'crate_labeled.png', 7, 5),
        on_wall(window('village_wood'), 1),
        on_wall(WALL + 'mounted_fish.png', 4, 16),
        on_wall(LIGHTS + 'lantern_wall_anim_4f.png', 6, 18),
    ])

# Pip's family: sunny yellow paper, Pip's bunk and toy chest, a hamster in its
# wheel, a sea picture for a would-be pirate, and the dog asleep by the table.
ROOMS['pip_cottage'] = dict(
    size=(10, 7), door=(4, 5), wall='wallpaper_dots_yellow', top='village_plaster',
    floor=FLOORS + 'Generic/floor_planks_birch.png',
    rugs=[(RUGS + 'rug_blue_48x32.png', 4, 6)],
    mat=MATS + 'door_mat_red_welcome.png',
    pieces=[
        stand(BEDROOM + 'bed_double_blue_made_birch.png', 0, 3, depth=2),
        stand(BEDROOM + 'nightstand_birch.png', 2, 2),
        stand(KITCHEN + 'counter_drawers_left.png', 3, 2),
        stand(KITCHEN + 'counter_sink_mid.png', 4, 2),
        stand(KITCHEN + 'counter_cutting_right.png', 5, 2),
        stand(KITCHEN + 'icebox.png', 6, 2),
        stand(BEDROOM + 'toy_chest.png', 8, 2),
        stand(BEDROOM + 'bunk_bed_16x48.png', 9, 3, depth=2),
        table_with(LIVING + 'table_round_cloth_blue.png', 'pip_table', 1, 6,
                   [(TABLETOP + 'tabletop_fruit_bowl.png', 8, 3)]),
        stand(LIVING + 'chair_birch_right.png', 0, 6),
        stand(LIVING + 'chair_birch_left.png', 3, 6),
        stand(PETS + 'hamster_wheel_32x32_4f.png', 8, 6, fps=6),
        pet('dog_tan', 7, 4),
        on_wall(curtains('blue'), 1),
        on_wall(KITCHEN + 'cupboard_wall_birch_32x16.png', 3, 16),
        on_wall(WALL + 'painting_seascape_32x24.png', 6, 10),
        on_wall(curtains('blue'), 8),
    ])

# Ivy: mint stripes, plants on every surface, a spinning wheel, tea for two,
# a canary, and a white cat that owns the place.
ROOMS['ivy_cottage'] = dict(
    size=(10, 7), door=(4, 5), wall='wallpaper_stripes_mint', top='village_plaster',
    floor=FLOORS + 'village_plaster/floor_village_plaster_herringbone.png',
    rugs=[(RUGS + 'rug_green_64x48.png', 3, 6)],
    mat=MATS + 'door_mat_green.png',
    pieces=[
        stand(BEDROOM + 'bed_single_purple_made.png', 0, 3, depth=2),
        stand(BEDROOM + 'nightstand_painted_lamp_on.png', 1, 2),
        stand(LIVING + 'bookshelf_half.png', 2, 2),
        stand(BEDROOM + 'dresser_painted.png', 6, 2),
        stand(LIVING + 'plant_fern.png', 8, 2),
        stand(LIVING + 'plant_flowers.png', 9, 2),
        stand(WORK + 'spinning_wheel_anim_4f.png', 8, 4, fps=3),
        stand(LIVING + 'armchair_green_right.png', 7, 6),
        table_with(LIVING + 'table_round_cloth_green.png', 'ivy_table', 8, 6,
                   [(TABLETOP + 'tabletop_teacup.png', 3, 2), (TABLETOP + 'tabletop_teacup.png', 14, 4)]),
        stand(LIVING + 'plant_cactus.png', 0, 5),
        stand(LIVING + 'plant_succulent.png', 0, 6),
        pet('cat_white', 4, 3),
        on_wall(curtains('green'), 4),
        on_wall(WALL + 'flower_box_red.png', 4, 0),
        on_wall(WALL + 'bird_cage_canary_16x32_anim_2f.png', 5, 6),
        on_wall(WORK + 'herb_drying_rack.png', 6, 18),
        on_wall(WALL + 'painting_flowers_32x24.png', 2, 12),
    ])

# Dot the carrier: parcels and sacks everywhere, the packing bench, the round
# pinned on the board, a coat by the door, an unmade bed and her old dog.
ROOMS['dot_yard'] = dict(
    size=(10, 7), door=(4, 5), wall='village_wood',
    floor=FLOORS + 'village_wood/floor_village_wood_planks_worn.png',
    rugs=[(RUGS + 'rug_red_runner_16x48.png', 9, 6)],
    mat=MATS + 'door_mat_brown.png',
    pieces=[
        stand(CELLAR + 'sack_stack.png', 0, 2),
        stand(CELLAR + 'crate_labeled.png', 2, 2),
        stand(WORK + 'workbench_48x32.png', 3, 2),
        stand(TAVERN + 'notice_board.png', 6, 2),
        stand(BEDROOM + 'bed_single_red_unmade.png', 9, 3, depth=2),
        stand(CELLAR + 'barrel_lying.png', 0, 4),
        stand(CELLAR + 'crate.png', 0, 5),
        stand(CELLAR + 'crate_dark.png', 1, 5),
        stand(CELLAR + 'crate_labeled.png', 0, 6),
        stand(BEDROOM + 'coat_rack.png', 8, 2),
        stand(LIVING + 'table_oak_small_16x32.png', 7, 6),
        stand(LIVING + 'stool_oak.png', 6, 6),
        pet('dog_brown', 2, 6),
        on_wall(window('village_wood'), 1),
        on_wall(WALL + 'horseshoe.png', 3, 18),
        on_wall(WALL + 'wall_map.png', 8, 12),
        on_wall(LIGHTS + 'lantern_wall_anim_4f.png', 5, 18),
    ])

# Tam's fish shed: harbour boards, the hammock he naps in between tides, fish
# on the shelf and in the barrels, the chart table, a ship's lantern.
ROOMS['tam_shed'] = dict(
    size=(10, 7), door=(4, 5), wall='harbor',
    floor=FLOORS + 'harbor/floor_harbor_deck_planks.png',
    floor_b=FLOORS + 'harbor/floor_harbor_deck_planks_b.png',
    rugs=[],
    mat=MATS + 'door_mat_brown.png',
    pieces=[
        stand(SHOP + 'goods_shelf_fish.png', 0, 2),
        stand(SHOP + 'barrel_fish.png', 2, 2),
        stand(FURN + 'Ship_Cabin/rum_barrel.png', 3, 2),
        stand(FURN + 'Tribal_Igloo/fish_drying_rack.png', 5, 2),
        stand(FURN + 'Ship_Cabin/hammock_empty_anim_4f.png', 8, 2, fps=2),
        stand(CELLAR + 'barrel_lying.png', 0, 5),
        stand(CELLAR + 'crate.png', 0, 6),
        stand(CELLAR + 'crate_dark.png', 1, 6),
        stand(FURN + 'Ship_Cabin/map_table.png', 7, 6),
        stand(LIVING + 'stool_oak.png', 9, 6),
        stand(SHOP + 'barrel_fish.png', 9, 4),
        on_wall(window('harbor'), 3),
        on_wall(WALL + 'mounted_fish.png', 6, 16),
        on_wall(LIGHTS + 'ship_lantern_16x32_anim_6f.png', 8, 4),
    ])

# Rosa's whitewashed cottage: a market grocer's kitchen, barrels of what's in
# season, geraniums under the windows, a black cat by the stove.
ROOMS['rosa_cottage'] = dict(
    size=(10, 7), door=(4, 5), wall='village_plaster',
    floor=FLOORS + 'adobe/floor_adobe_terracotta.png',
    rugs=[(RUGS + 'rug_red_48x32.png', 4, 6)],
    mat=MATS + 'door_mat_red_welcome.png',
    pieces=[
        stand(KITCHEN + 'stove_32x32_anim_4f.png', 0, 2, fps=4),
        stand(KITCHEN + 'counter_cutting_left.png', 2, 2),
        stand(KITCHEN + 'counter_cutting_right.png', 3, 2),
        stand(KITCHEN + 'dish_shelf.png', 5, 2),
        stand(BEDROOM + 'nightstand_birch.png', 8, 2),
        stand(BEDROOM + 'bed_single_red_made_birch.png', 9, 3, depth=2),
        stand(SHOP + 'barrel_apples.png', 0, 4),
        stand(SHOP + 'barrel_carrots.png', 0, 5),
        stand(SHOP + 'barrel_potatoes.png', 1, 5),
        stand(CELLAR + 'potato_pile.png', 0, 6),
        table_with(LIVING + 'table_oak_32x32_cloth_red.png', 'rosa_table', 7, 6,
                   [(TABLETOP + 'tabletop_bread_plate.png', 2, 2), (TABLETOP + 'tabletop_cheese.png', 15, 3)]),
        stand(LIVING + 'chair_oak_left.png', 9, 6),
        stand(LIVING + 'plant_flowers.png', 9, 4),
        pet('cat_black', 2, 3),
        on_wall(window('village_plaster'), 2),
        on_wall(WALL + 'flower_box_red.png', 2, 0),
        on_wall(window('village_plaster'), 7),
        on_wall(WALL + 'flower_box_red.png', 7, 0),
        on_wall(WALL + 'garlic_bundle.png', 4, 16),
    ])


# --- Building -------------------------------------------------------------------

def frames_of(rel):
    name = os.path.basename(rel)[:-4]
    for part in name.split('_'):
        if part.endswith('f') and part[:-1].isdigit():
            return int(part[:-1])
    return 1


def first_frame(rel):
    im = img(rel)
    n = frames_of(rel)
    return im.crop((0, 0, im.width // n, im.height))


def bake_room(key, spec):
    w, h = spec['size']
    door = spec['door']
    W, H = (w + 2) * T, (h + 2) * T
    out = Image.new('RGBA', (W, H), (0, 0, 0, 0))

    def px(x, y):  # a room cell's top-left in the picture (cell -1,-1 at 0,0)
        return ((x + 1) * T, (y + 1) * T)

    # Floor: the inside below the face, and the door's gap.
    floor = img(spec['floor'])
    floor_b = img(spec['floor_b']) if spec.get('floor_b') else floor
    cells = [(x, y) for y in range(2, h) for x in range(w)] + [(x, h) for x in door]
    for x, y in cells:
        out.alpha_composite(floor_b if (x * 3 + y * 5) % 7 == 0 else floor, px(x, y))

    # Wall tops: everything round the room that isn't floor or face.
    def is_top(x, y):
        if y >= h + 1 or y < -1 or x < -1 or x > w:
            return True  # off the picture: wall goes on
        if 0 <= x < w and 0 <= y <= 1:
            return False  # the face
        if 0 <= x < w and 2 <= y < h:
            return False  # the floor
        if y == h and x in door:
            return False
        return True

    sheet = img(tops(spec.get('top', spec['wall'])))
    for y in range(-1, h + 1):
        for x in range(-1, w + 1):
            if not is_top(x, y):
                continue
            n, e, s, wv = is_top(x, y - 1), is_top(x + 1, y), is_top(x, y + 1), is_top(x - 1, y)
            m = (1 if n else 0) | (4 if e else 0) | (16 if s else 0) | (64 if wv else 0)
            if n and e and is_top(x + 1, y - 1): m |= 2
            if s and e and is_top(x + 1, y + 1): m |= 8
            if s and wv and is_top(x - 1, y + 1): m |= 32
            if n and wv and is_top(x - 1, y - 1): m |= 128
            i = BLOB.index(m)
            out.alpha_composite(sheet.crop(((i % 8) * T, (i // 8) * T, (i % 8 + 1) * T, (i // 8 + 1) * T)), px(x, y))

    # The face: two cells tall across the back.
    faces = face(spec['wall'])
    for x in range(w):
        part = 'left' if x == 0 else 'right' if x == w - 1 else 'mid'
        out.alpha_composite(img(faces[part]), px(x, 0))

    # Rugs (cell x may be a half: centred between cells), mats, stools.
    for rel, x, bottom in spec.get('rugs', []):
        rug = img(rel)
        out.alpha_composite(rug, (int((x + 1) * T), (bottom + 2) * T - rug.height))
    for x in door:
        out.alpha_composite(img(spec['mat']), px(x, h))
    for x, y in spec.get('stools', []):
        out.alpha_composite(img(LIVING + 'stool_oak.png'), px(x, y))

    name = '%s_room.png' % key
    out.save(os.path.join(OUT, name))
    return name, out


def save_picture(rel, used):
    """Copy one pack picture into the output folder (once)."""
    name = 'p_' + os.path.basename(rel)
    if name not in used:
        used[name] = img(rel)
        used[name].save(os.path.join(OUT, name))
    return name


def build_piece(p, used):
    entry = {'cell': list(p['cell'])}
    if 'composite' in p:
        canvas = Image.new('RGBA', p['size'], (0, 0, 0, 0))
        for rel, x, y in p['composite']:
            canvas.alpha_composite(first_frame(rel), (x, y))
        name = 'c_%s.png' % p['key']
        canvas.save(os.path.join(OUT, name))
        used[name] = canvas
        entry['picture'] = name
        entry['width'] = canvas.width
    else:
        entry['picture'] = save_picture(p['pic'], used)
        frames = frames_of(p['pic'])
        if frames > 1:
            entry['frames'] = frames
        entry['width'] = used[entry['picture']].width // frames
        if p.get('night'):
            entry['night'] = save_picture(p['night'], used)
    for k in ('lift', 'above', 'solid', 'fps', 'depth'):
        if p.get(k):
            entry[k] = p[k]
    return entry


def main():
    global PACK
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    PACK = sys.argv[1]
    if not os.path.isdir(os.path.join(PACK, '03_Furniture')):
        sys.exit('That folder has no 03_Furniture: point at the unzipped CozyInteriors folder.')
    os.makedirs(OUT, exist_ok=True)

    used = {}
    data = {'rooms': {}}
    for key, spec in ROOMS.items():
        bg, bg_img = bake_room(key, spec)
        used[bg] = bg_img
        data['rooms'][key] = {
            'size': list(spec['size']),
            'door': list(spec['door']),
            'background': bg,
            'hide': spec.get('hide', []),
            'pieces': [build_piece(p, used) for p in spec['pieces']],
        }
    with open(os.path.join(OUT, 'interior_look.json'), 'w', newline='\n') as f:
        json.dump(data, f, indent=1)

    # The palette checker's view: every colour must be one of the pack's (we
    # keep them exactly), and these are the ones art/palette.png lacks.
    with open(os.path.join(PACK, 'Palette', 'cozy_interiors_palette_55.hex')) as f:
        pack_colours = {tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) for h in f.read().split()}
    ours = {c for _, c in Image.open(os.path.join(HERE, 'palette.png')).convert('RGB').getcolors(1 << 24)}
    seen = set()
    for name, picture in used.items():
        for _, (r, g, b, a) in picture.getcolors(1 << 24):
            if a:
                seen.add((r, g, b))
    stray = seen - pack_colours
    if stray:
        sys.exit('Colours outside the pack palette (a bug here): %s' % sorted(stray))
    new = sorted(seen - ours)
    print('%d rooms, %d pictures in %s' % (len(data['rooms']), len(used), OUT))
    print('%d colours used, all on the pack palette; %d not yet in art/palette.png: %s'
          % (len(seen), len(new), ' '.join('#%02x%02x%02x' % c for c in new)))


if __name__ == '__main__':
    main()
