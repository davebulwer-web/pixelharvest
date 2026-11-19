"""Add the few characters Pixel Harvest's text uses that monogram lacks.

monogram (CC0, datagoblin) covers ASCII and a little more, but the game's text
uses a middle dot (the HUD's "Spring · Mon 1"), en and em dashes and a times
sign ("2 × 2"). Rather than a fallback font (which makes every line taller,
since Godot sizes a line for the tallest font in the chain: DECISIONS 074),
this draws those four in monogram's own grid: one pixel is 64 units, glyphs are
6 pixels wide, the baseline is y = 0.

Run with fontTools (pip install fonttools):
    python art/fonts/extend_monogram.py art/fonts/monogram_original.ttf assets/fonts/monogram.ttf
"""
import sys

from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

PX = 64
ADVANCE = 6 * PX

# Each character: the pixels to fill, as (x, y) with y counted up from the
# baseline. The hyphen sits on rows 3 (y 192-256), so the dot and dashes do too.
GLYPHS = {
    0x00B7: ("middledot", [(2, 3)]),
    0x2013: ("endash", [(x, 3) for x in range(5)]),
    0x2014: ("emdash", [(x, 3) for x in range(6)]),
    0x00D7: ("multiply", [(1, 2), (3, 2), (2, 3), (1, 4), (3, 4)]),
}


def main(source: str, target: str) -> None:
    font = TTFont(source)
    order = font.getGlyphOrder()
    for code, (name, pixels) in GLYPHS.items():
        pen = TTGlyphPen(None)
        for x, y in pixels:
            # One square per pixel, drawn clockwise like monogram's own.
            pen.moveTo((x * PX, y * PX))
            pen.lineTo((x * PX, (y + 1) * PX))
            pen.lineTo(((x + 1) * PX, (y + 1) * PX))
            pen.lineTo(((x + 1) * PX, y * PX))
            pen.closePath()
        glyph = pen.glyph()
        if name not in order:
            order.append(name)
        font["glyf"][name] = glyph
        font["hmtx"][name] = (ADVANCE, min(x for x, _ in pixels) * PX)
        for table in font["cmap"].tables:
            if table.isUnicode():
                table.cmap[code] = name
    font.setGlyphOrder(order)
    font["maxp"].numGlyphs = len(order)
    font.save(target)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
