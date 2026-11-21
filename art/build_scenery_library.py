"""Build Dave's scenery picture library (DECISIONS 082).

    python art/build_scenery_library.py <CozyVillageFarm> <CoastBeachFishing> <SeasonsFestivals>

(the unzipped pack folders). Writes assets/scenery/, a folder of single
pictures Dave drags into the scenery scenes (scenery/<map>.tscn) in the Godot
editor. assets/scenery/ is kept out of git like assets/packs/: the packs'
licence forbids passing their pictures on, and the repository is public. This
script holds no pack art, only which folders to take and where they go.

What it does to the pictures:

- Copies them unchanged, one folder per kind (nature, props, harbour, seaside,
  creatures, festival), with frame sizes taken out of the names
  ("crate_plain_16x16.png" becomes "crate_plain.png").
- Keeps the frame count at the end of a name: "buoy_red_pingpong_3f.png" is a
  strip of 3 frames side by side. The game animates any picture named like
  that (Scenery), and the editor shows its first frame (SceneryLayer).
- Cuts the joining 4-bit sheets (fences, walls, bunting, string lights) into
  pieces that stand alone: a horizontal run, a vertical run and a post for
  fences and walls, a horizontal span for bunting and lights. A 4-bit sheet
  is 4 x 4 pieces, piece index N*8 + E*4 + S*2 + W*1, as in PackLook.
- Leaves out ground tiles, autotiles, buildings, characters, items, UI and
  the animals' many-row sheets (they need more than a picture to look right).
"""
import os
import re
import shutil
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "scenery")

# (pack, folder in the pack, folder in the library, keep(relative path) -> bool)
def _all(_rel):
    return True


def _no_autotiles(rel):
    return "autotile" not in rel and "4bit" not in rel and "_sheet" not in rel


def _moored(rel):
    return "moored" in rel and "rider_overlay" not in rel


def _beach_props(rel):
    # Not the villagers' walk sheets (people, not scenery) or the swimmers' masks.
    return "water_line_mask" not in rel and "Villagers" not in rel and "_sheet" not in rel


SOURCES = [
    ("cozy", "02_Nature", "nature", _no_autotiles),
    ("seasons", "02_Seasonal_Nature", "nature", _no_autotiles),
    ("cozy", "04_Props", "props", _no_autotiles),
    ("cozy", "09_Beach_Fishing", "seaside", _all),
    ("coast", "02_Water_Shore_Animated/Sea_Rocks", "seaside/rocks", _all),
    ("coast", "02_Water_Shore_Animated/Tide_Pools", "seaside/tide_pools", _all),
    ("coast", "02_Water_Shore_Animated/Sandbars", "seaside/sandbars", _all),
    ("coast", "10_Beach_Life_Props", "seaside/beach", _beach_props),
    ("coast", "03_Docks_Harbour/Props", "harbour", _all),
    ("coast", "04_Beach_Town_Buildings/Harbour_Props", "harbour", _all),
    ("coast", "05_Boats", "harbour/boats", _moored),
    ("coast", "07_Sea_Creatures", "creatures", _all),
    ("seasons", "03_Festival_Props", "festival", _no_autotiles),
    ("seasons", "04_Festival_Lights", "festival/lights", _no_autotiles),
]

# 4-bit sheets cut into stand-alone pieces: (pack, file, library file stem,
# {suffix: piece index}). A sheet named ..._on_off_2f is two sheets side by
# side (lit, then unlit): its pieces come out as 2-frame strips.
H, V, POST = 5, 10, 0
JOINS = [
    ("cozy", "04_Props/Fences/fence_wood_autotile_16.png", "props/fences/fence_wood", {"horizontal": H, "vertical": V, "post": POST}),
    ("cozy", "04_Props/Fences/fence_white_autotile_16.png", "props/fences/fence_white", {"horizontal": H, "vertical": V, "post": POST}),
    ("cozy", "04_Props/Fences/fence_dark_autotile_16.png", "props/fences/fence_dark", {"horizontal": H, "vertical": V, "post": POST}),
    ("cozy", "04_Props/Fences/stone_wall_autotile_16.png", "props/fences/stone_wall", {"horizontal": H, "vertical": V, "post": POST}),
]

FRAME_SIZE = re.compile(r"_\d+x\d+(?=_|$)")


def _clean(name):
    """crate_plain_16x16 -> crate_plain; keeps _pingpong_3f, _4f and so on."""
    return FRAME_SIZE.sub("", name.lower())


def _piece(sheet, index, origin_x=0):
    size = sheet.height // 4
    x = origin_x + (index % 4) * size
    y = (index // 4) * size
    return sheet.crop((x, y, x + size, y + size))


def _save(img, rel):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def _cut_joins(packs, written):
    jobs = list(JOINS)
    # Every bunting, lantern string and string light sheet: a horizontal span.
    lights = os.path.join(packs["seasons"], "04_Festival_Lights")
    for folder, _dirs, files in os.walk(lights):
        for f in sorted(files):
            if f.endswith(".png") and "4bit" in f:
                rel = os.path.relpath(os.path.join(folder, f), packs["seasons"])
                stem = _clean(f[:-4]).replace("_4bit", "")
                jobs.append(("seasons", rel, "festival/lights/" + stem + "_span", {"": H}))
    winter = os.path.join(packs["seasons"], "03_Festival_Props")
    for folder, _dirs, files in os.walk(winter):
        for f in sorted(files):
            if f.endswith(".png") and "4bit" in f:
                rel = os.path.relpath(os.path.join(folder, f), packs["seasons"])
                stem = _clean(f[:-4]).replace("_4bit_autotile", "").replace("_4bit", "")
                jobs.append(("seasons", rel, "festival/" + stem, {"horizontal": H, "vertical": V, "post": POST}))
    for pack, rel, stem, pieces in jobs:
        sheet = Image.open(os.path.join(packs[pack], rel)).convert("RGBA")
        two = sheet.width == 2 * sheet.height  # lit and unlit side by side
        for suffix, index in pieces.items():
            name = stem + ("_" + suffix if suffix else "")
            if two:
                lit = _piece(sheet, index, 0)
                unlit = _piece(sheet, index, sheet.height)
                strip = Image.new("RGBA", (lit.width * 2, lit.height))
                strip.paste(lit, (0, 0))
                strip.paste(unlit, (lit.width, 0))
                name = name.replace("_on_off_2f", "") + "_on_off_2f"
                _save(strip, name + ".png")
            else:
                _save(_piece(sheet, index), name + ".png")
            written.add(name + ".png")


def main(cozy, coast, seasons):
    packs = {"cozy": cozy, "coast": coast, "seasons": seasons}
    if os.path.isdir(OUT):
        # Keep Godot's .import files beside pictures that stay (deleting them
        # makes Godot show nothing until it imports again).
        for folder, _dirs, files in os.walk(OUT):
            for f in files:
                if f.endswith(".png"):
                    os.remove(os.path.join(folder, f))
    written = set()
    count = 0
    for pack, src, dest, keep in SOURCES:
        base = os.path.join(packs[pack], src)
        for folder, _dirs, files in os.walk(base):
            for f in sorted(files):
                if not f.endswith(".png"):
                    continue
                rel = os.path.relpath(os.path.join(folder, f), base)
                if not keep(rel.replace(os.sep, "/")):
                    continue
                parts = rel.split(os.sep)
                # One level of the pack's folders is kept ("Trees", "Bushes");
                # the deeper ones (summer/, recolors/) fold into it.
                sub = _clean(parts[0]) if len(parts) > 1 else ""
                name = _clean(f[:-4]) + ".png"
                out_rel = "/".join(p for p in (dest, sub, name) if p)
                if out_rel in written:
                    stem = _clean(parts[-2]) if len(parts) > 1 else pack
                    out_rel = "/".join(p for p in (dest, sub, stem + "_" + name) if p)
                written.add(out_rel)
                os.makedirs(os.path.dirname(os.path.join(OUT, out_rel)), exist_ok=True)
                shutil.copyfile(os.path.join(folder, f), os.path.join(OUT, out_rel))
                count += 1
    _cut_joins(packs, written)
    with open(os.path.join(OUT, "README.txt"), "w", newline="\n") as fh:
        fh.write(
            "Dave's scenery pictures, cut from the bought packs by\n"
            "art/build_scenery_library.py (DECISIONS 082). Kept out of git: the\n"
            "packs' licence forbids passing these pictures on.\n\n"
            "Drag any of them into a scenery scene (scenery/<map>.tscn).\n"
            "A name ending _3f, _4f ... is an animation strip: the game plays it.\n"
            "A name with _spring/_summer/_autumn/_winter changes with the season\n"
            "when the other seasons' pictures are here too.\n"
            "A name with _on_off is lit after dark.\n")
    print("copied %d pictures, cut %d pieces" % (count, len(written) - count))


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print(__doc__)
        sys.exit(1)
    main(*sys.argv[1:])
