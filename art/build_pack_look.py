"""Build the TEST of the bought packs' props, festival dressing and wooden UI
(DECISIONS 081).

    python art/build_pack_look.py <CozyVillageFarm> <CoastBeachFishing> <SeasonsFestivals> <GameUIKit>

(the four unzipped pack folders). Writes assets/packs/, which is kept out of
git like assets/tilesets/cozy/ (the packs' licence; the repository is
public). This script holds no pack art, only which pictures to take and
where they go:

  props/      pictures for our own objects (bench, lamp post, fences, ...):
              PackLook shows them instead of ours. Fences and walls are the
              packs' 4-bit sheets (index = N*8 + E*4 + S*2 + W*1, 4 x 4).
  harbour/    the Cove's harbour clutter: bollards, crates, nets, buoys ...
  festival/   the five town days' dressing (four festivals and market day).
  ui/         the Wood theme: panel, buttons, hotbar slots, portrait frame.
  pack_look.json  what goes where: read by scripts/pack_look.gd.

A piece is drawn with its bottom middle on the bottom middle of its cell,
like our objects; `lift` raises it (kites, the bunting), `frames` cuts a
strip into frames side by side, `above` draws it over people (the packs say
lights and bunting are overlays). Pieces are only looks: nothing walks into
them, nothing is saved.
"""
import json
import os
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets/packs')

# Our object id -> (pack, path). Joined ones are 4-bit sheets.
PROPS = {
    'bench': ('cozy', '04_Props/bench.png'),
    'lamp_post': ('cozy', '04_Props/lamp_post_off.png'),
    'old_well': ('cozy', '03_Buildings/well.png'),
    'hay_bale': ('cozy', '04_Props/hay_bale.png'),
    'log_pile': ('cozy', '04_Props/log_pile.png'),
    'notice_board': ('cozy', '04_Props/notice_board.png'),
    'scarecrow': ('cozy', '04_Props/scarecrow.png'),
    'bee_hive': ('cozy', '04_Props/beehive.png'),
    'cart': ('cozy', '04_Props/cart_produce.png'),
}
JOINS = {
    'fence': ('cozy', '04_Props/Fences/fence_wood_autotile_16.png'),
    'garden_fence': ('cozy', '04_Props/Fences/fence_white_autotile_16.png'),
    'stone_wall': ('cozy', '04_Props/Fences/stone_wall_autotile_16.png'),
}

HB = '04_Beach_Town_Buildings/Harbour_Props/'
DP = '03_Docks_Harbour/Props/'
FP = '03_Festival_Props/'
FL = '04_Festival_Lights/'

# name -> (pack, path, frames)
PICTURES = {
    # The harbour (Cove).
    'bollard': ('coast', DP + 'bollard_iron_12x14.png', 1),
    'rope_post': ('coast', DP + 'rope_post_16x16.png', 1),
    'dock_lamp': ('coast', DP + 'dock_lamp_off_12x32.png', 1),
    'life_ring_post': ('coast', DP + 'life_ring_post_16x30.png', 1),
    'crate_stack': ('coast', HB + 'crate_stack_16x24.png', 1),
    'crate_fish': ('coast', HB + 'crate_fish_16x16.png', 1),
    'barrel': ('coast', HB + 'barrel_plain_14x16.png', 1),
    'rope_coil': ('coast', HB + 'rope_coil_big_20x14.png', 1),
    'net_rack': ('coast', HB + 'net_rack_full_34x30.png', 1),
    'drying_rack': ('coast', HB + 'fish_drying_rack_36x28_pingpong_3f.png', 3),
    'net_pile': ('coast', HB + 'net_pile_24x14.png', 1),
    'anchor': ('coast', HB + 'anchor_big_24x28.png', 1),
    'buoy_red': ('coast', HB + 'buoy_red_16x20_pingpong_3f.png', 3),
    'buoy_striped': ('coast', HB + 'buoy_striped_16x20_pingpong_3f.png', 3),
    # Flower show (spring).
    'maypole': ('seasons', FP + 'Spring_Flower_Festival/maypole_48x64_6f.png', 6),
    'flower_arch': ('seasons', FP + 'Spring_Flower_Festival/flower_arch.png', 1),
    'flower_barrel_pink': ('seasons', FP + 'Spring_Flower_Festival/flower_barrel_pink.png', 1),
    'flower_barrel_yellow': ('seasons', FP + 'Spring_Flower_Festival/flower_barrel_yellow.png', 1),
    'banner_spring': ('seasons', FP + 'Common/festival_banner_spring.png', 1),
    'bunting_pastel': ('seasons', FL + 'Bunting/bunting_pastel_4bit.png', 0),
    # Fishing contest (summer, at the pond).
    'kite': ('seasons', FP + 'Common_Animated/kite_flying_32x32_4f.png', 4),
    'lemonade': ('seasons', FP + 'Summer_Beach_Fireworks_Festival/lemonade_stand.png', 1),
    'picnic_blanket': ('seasons', FP + 'Summer_Beach_Fireworks_Festival/picnic_blanket_red.png', 1),
    'cooler': ('seasons', FP + 'Summer_Beach_Fireworks_Festival/cooler.png', 1),
    'umbrella': ('seasons', FP + 'Summer_Beach_Fireworks_Festival/beach_umbrella_teal.png', 1),
    'bunting_rainbow': ('seasons', FL + 'Bunting/bunting_rainbow_4bit.png', 0),
    # Harvest fair (autumn).
    'harvest_banner': ('seasons', FP + 'Harvest_Festival/harvest_banner.png', 1),
    'booth_pumpkins': ('seasons', FP + 'Harvest_Festival/booth_pumpkins.png', 1),
    'hay_stack': ('seasons', FP + 'Harvest_Festival/hay_bale_stack.png', 1),
    'corn_bundle': ('seasons', FP + 'Harvest_Festival/corn_stalk_bundle.png', 1),
    'pumpkin_grin': ('seasons', FP + 'Harvest_Festival/carved_pumpkin_grin_unlit.png', 1),
    'pumpkin_happy': ('seasons', FP + 'Harvest_Festival/carved_pumpkin_happy_unlit.png', 1),
    'wheelbarrow_pumpkins': ('seasons', FP + 'Harvest_Festival/wheelbarrow_pumpkins.png', 1),
    'cider_barrel': ('seasons', FP + 'Harvest_Festival/cider_barrel_stand.png', 1),
    'bunting_harvest': ('seasons', FL + 'Bunting/bunting_harvest_4bit.png', 0),
    # Lantern night (winter).
    'festive_tree': ('seasons', FP + 'Winter_Festival/festive_tree_lights_4f.png', 4),
    'winter_banner': ('seasons', FP + 'Winter_Festival/winter_banner.png', 1),
    'luminaria': ('seasons', FL + 'Lamps/luminaria_paper_2f.png', 2),
    'double_lantern': ('seasons', FL + 'Lamps/double_lantern_post_2f.png', 2),
    'lantern_string': ('seasons', FL + 'Lantern_String/lantern_string_4bit_on_off_2f.png', 0),
    # Market day.
    'fair_banner': ('seasons', FP + 'Market_Fair/fair_banner.png', 1),
    'balloon_cart': ('seasons', FP + 'Market_Fair/balloon_cart_2f.png', 2),
    'popcorn_cart': ('seasons', FP + 'Market_Fair/popcorn_cart.png', 1),
    'flag_pole': ('seasons', FP + 'Market_Fair/flag_pole_red_2f.png', 2),
}


def piece(location, event, cell, name, lift=0, above=False, join=0):
    """`join`: for a 4-bit sheet, which piece (N*8 + E*4 + S*2 + W*1).
    Market day's pieces stand aside when a festival shares its day."""
    out = {'location': location, 'event': event, 'cell': list(cell), 'picture': name}
    if event == 'market_day':
        out['alone'] = True
    if lift:
        out['lift'] = lift
    if above:
        out['above'] = True
    if join:
        out['join'] = join
    return out


def string(location, event, row, x0, x1, name, lift):
    """A string of lights or bunting from x0 to x1 along `row`, over people."""
    out = []
    for x in range(x0, x1 + 1):
        join = (4 if x < x1 else 0) | (1 if x > x0 else 0)
        out.append(piece(location, event, (x, row), name, lift, True, join))
    return out


def layout():
    p = []
    # The Cove's harbour: the quay (rows 14-19), pier x8-9, breakwater x18-19.
    for x in (1, 5, 12, 16):
        p.append(piece('cove', '', (x, 19), 'bollard'))
    for x in (7, 10):
        p.append(piece('cove', '', (x, 19), 'rope_post'))
    p += [piece('cove', '', (6, 14), 'dock_lamp'), piece('cove', '', (19, 18), 'dock_lamp'),
          piece('cove', '', (14, 17), 'life_ring_post'),
          piece('cove', '', (13, 14), 'crate_stack'), piece('cove', '', (14, 14), 'crate_fish'),
          piece('cove', '', (12, 14), 'barrel'), piece('cove', '', (3, 18), 'rope_coil'),
          piece('cove', '', (1, 15), 'net_rack'), piece('cove', '', (18, 15), 'drying_rack'),
          piece('cove', '', (5, 17), 'net_pile'), piece('cove', '', (17, 18), 'anchor'),
          piece('cove', '', (4, 23), 'buoy_red'), piece('cove', '', (13, 24), 'buoy_striped')]

    # Flower show: a maypole west of the square, flowers at its gates, bunting.
    e = 'flower_show'
    p += [piece('town', e, (30, 19), 'maypole'), piece('town', e, (20, 21), 'flower_arch'),
          piece('town', e, (14, 16), 'flower_barrel_pink'), piece('town', e, (26, 16), 'flower_barrel_yellow'),
          piece('town', e, (14, 21), 'flower_barrel_yellow'), piece('town', e, (26, 21), 'flower_barrel_pink'),
          piece('town', e, (12, 16), 'banner_spring')]
    p += string('town', e, 15, 15, 25, 'bunting_pastel', 28)

    # Fishing contest at the pond (x31-36, rows 2-3; the path up to it x36-37;
    # the forge's roof just south, Wren's cottage from x41).
    e = 'fishing_contest'
    p += [piece('town', e, (40, 5), 'picnic_blanket'), piece('town', e, (38, 5), 'cooler'),
          piece('town', e, (29, 5), 'umbrella'), piece('town', e, (39, 11), 'lemonade'),
          piece('town', e, (25, 4), 'kite', 40), piece('town', e, (39, 3), 'kite', 44)]
    p += string('town', e, 4, 30, 35, 'bunting_rainbow', 20)

    # Harvest fair.
    e = 'harvest_fair'
    p += [piece('town', e, (30, 19), 'booth_pumpkins'), piece('town', e, (12, 16), 'harvest_banner'),
          piece('town', e, (14, 16), 'corn_bundle'), piece('town', e, (26, 16), 'corn_bundle'),
          piece('town', e, (14, 21), 'hay_stack'), piece('town', e, (16, 21), 'pumpkin_grin'),
          piece('town', e, (24, 21), 'pumpkin_happy'), piece('town', e, (26, 21), 'cider_barrel'),
          piece('town', e, (12, 17), 'wheelbarrow_pumpkins')]
    p += string('town', e, 15, 15, 25, 'bunting_harvest', 28)

    # Lantern night.
    e = 'lantern_night'
    p += [piece('town', e, (30, 19), 'festive_tree'), piece('town', e, (12, 16), 'winter_banner'),
          piece('town', e, (14, 16), 'double_lantern'), piece('town', e, (26, 16), 'double_lantern')]
    for x in (16, 18, 22, 24):
        p.append(piece('town', e, (x, 21), 'luminaria'))
    p += string('town', e, 15, 15, 25, 'lantern_string', 28)

    # Market day.
    e = 'market_day'
    p += [piece('town', e, (20, 21), 'fair_banner'), piece('town', e, (13, 20), 'balloon_cart'),
          piece('town', e, (27, 20), 'popcorn_cart'), piece('town', e, (14, 16), 'flag_pole'),
          piece('town', e, (26, 16), 'flag_pole')]
    return p


# The Wood theme (nine-slice margins from the kit's Database/ui_database.csv).
UI = {
    'panel': ('01_Frames_Windows/Wood/panel_48x48.png', 8),
    'button_hover': ('02_Buttons_Controls/Wood/button_M_hover.png', 6),
    'button_focus': ('02_Buttons_Controls/Wood/button_M_hover.png', 6),
    'button_pressed': ('02_Buttons_Controls/Wood/button_M_pressed.png', 6),
    'slot': ('04_HUD/Hotbar/wood/slot_normal_18x18.png', 4),
    'slot_selected': ('04_HUD/Hotbar/wood/slot_selected_18x18_4f.png', 4),
    'portrait_frame': ('05_Dialogue/Wood/portrait_frame_54x54.png', 4),
}


def main(cozy, coast, seasons, ui):
    packs = {'cozy': cozy, 'coast': coast, 'seasons': seasons, 'ui': ui}
    for path in packs.values():
        if not os.path.isdir(path):
            sys.exit('No such folder: %s' % path)
    for sub in ('props', 'harbour', 'festival', 'ui'):
        os.makedirs(os.path.join(OUT, sub), exist_ok=True)

    def copy(pack, rel, dest):
        img = Image.open(os.path.join(packs[pack], rel)).convert('RGBA')
        img.save(os.path.join(OUT, dest))
        return img

    data = {'sprites': {}, 'joins': {}, 'pictures': {}, 'pieces': layout(), 'ui': {}}
    for oid, (pack, rel) in PROPS.items():
        copy(pack, rel, 'props/%s.png' % oid)
        data['sprites'][oid] = 'props/%s.png' % oid
    for oid, (pack, rel) in JOINS.items():
        copy(pack, rel, 'props/%s.png' % oid)
        data['joins'][oid] = 'props/%s.png' % oid
    for name, (pack, rel, frames) in PICTURES.items():
        folder = 'harbour' if pack == 'coast' else 'festival'
        img = copy(pack, rel, '%s/%s.png' % (folder, name))
        entry = {'file': '%s/%s.png' % (folder, name), 'frames': frames}
        if frames == 0:
            entry['sheet'] = True  # 4-bit, 4 x 4 of 16 x 16 (on/off: the first 64 x 64)
        if 'pingpong' in rel:
            entry['pingpong'] = True
        assert frames == 0 or img.width % frames == 0, name
        data['pictures'][name] = entry
    for key, (rel, margin) in UI.items():
        img = copy('ui', rel, 'ui/%s.png' % key)
        if key == 'slot_selected':  # its frames are side by side: keep the first
            img.crop((0, 0, 18, 18)).save(os.path.join(OUT, 'ui/%s.png' % key))
        data['ui'][key] = {'file': 'ui/%s.png' % key, 'margin': margin}

    # Pictures an earlier build took that this one doesn't.
    made = set(data['sprites'].values()) | set(data['joins'].values()) | \
        {e['file'] for e in data['pictures'].values()} | {e['file'] for e in data['ui'].values()}
    for sub in ('props', 'harbour', 'festival', 'ui'):
        for name in os.listdir(os.path.join(OUT, sub)):
            if name.endswith('.png') and '%s/%s' % (sub, name) not in made:
                os.remove(os.path.join(OUT, sub, name))
                if os.path.exists(os.path.join(OUT, sub, name + '.import')):
                    os.remove(os.path.join(OUT, sub, name + '.import'))

    names = set(data['pictures'])
    for p in data['pieces']:
        assert p['picture'] in names, p
    with open(os.path.join(OUT, 'pack_look.json'), 'w') as f:
        json.dump(data, f, indent=1)
    print('built %d props, %d joined, %d pictures, %d pieces, %d ui' % (
        len(data['sprites']), len(data['joins']), len(data['pictures']), len(data['pieces']), len(data['ui'])))


if __name__ == '__main__':
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    main(*sys.argv[1:])
