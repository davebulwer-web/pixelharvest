# Pixel Harvest — art specification

**This file is the defence against style drift.** Every Pixellab generation uses the spec
and prompt template below, unchanged, for the life of the project. Consistency comes from
mechanical reuse of the same words and the same reference images — not from writing a
better prompt each time.

---

## Locked specification

Do not change these after Stage 1 without an entry in `DECISIONS.md`.

| Property | Value |
|---|---|
| Tile size | 16 × 16 px |
| Character size | 32 × 32 px (occupies 1 tile wide, 2 tall) |
| Character directions | 4 (down, up, left, right) — no diagonals |
| Character animations | idle (2 frames), walk (4 frames), use-tool (3 frames) |
| Perspective | Top-down three-quarter, as Stardew Valley — ground seen from above, objects drawn from the front |
| Light source | Top-left, consistently |
| Outlines | Dark selective outline; no outline where a shape meets its own shadow |
| Palette | `Harvest 32` — see below; `art/palette.png` is the swatch |
| Dithering | None. Flat colour areas with hard-edged shading |
| Background | Transparent for sprites; opaque for tilesets |

## Palette — Harvest 32

Every asset uses only these colours. Anything outside the palette is a drift failure and
gets regenerated or corrected.

```
Soil      #2e1f1a  #4a2f22  #6b4a2f  #8a6340  #b08458
Grass     #1e3a1f  #2f5a2b  #4a7f3a  #6fbf4a  #a8e06b
Sky       #1b2a4a  #2f4a7a  #4a79b8  #8fc4e8
Water     #16444a  #2a7a7a  #4fb8ac
Wood      #3d2a1c  #7a5230  #c49a62
Stone     #22222b  #44444f  #71717e  #a8a8b2
Warm      #7a2630  #c4452f  #e8873a  #f2d06b
Cool      #5a3a6b  #9a5fb0
Neutral   #0d0b12  #f4ece0
```

## Prompt template

Paste this before the subject description, every single time:

> 16-bit top-down three-quarter farming game sprite, Stardew Valley style, flat colours
> with hard-edged shading, dark selective outline, light source top-left, no dithering,
> no anti-aliasing, limited earthy palette of muted greens browns and warm accents,
> transparent background. Subject:

Then the subject, kept short and concrete. Good: *"young farmer in a straw hat and blue
dungarees, walking south"*. Bad: *"a charming farmer character full of personality"* —
Pixellab has nothing to do with adjectives like charming, and they vary the output.

## Reference images

Two reference images, created once and reused forever:

- `art/palette.png` — the 32-colour swatch. Supply as a palette or style reference.
- `art/reference.png` — the first approved character sprite. From Stage 1 onward this is
  the style anchor for every subsequent generation.

**For seasonal tilesets, always use image-to-image from the base tileset**, never a fresh
prompt. Four seasons generated independently will not match; four seasons derived from one
base will. See `DECISIONS.md` 005.

## Who does what

- **Dave** judges whether an asset looks good. That's taste, and it isn't Claude's call.
- **Claude** handles the mechanics: constructing prompts from the template, checking
  dimensions and frame counts, extracting each PNG's palette and flagging any colour
  outside Harvest 32, and recording every generation below.

Claude can verify an asset with a short script — image size, frame grid, transparency,
and the exact set of colours used. That's the part worth automating: catching drift is more
reliable than hoping to avoid it.

## How generations get made

Pixellab isn't in Claude's connector directory, so there's no one-click connection. Two
routes, either fine:

1. **Pixellab's MCP server** — added by hand as a custom connector using the details on
   `pixellab.ai/vibe-coding`. Claude can then generate directly and verify immediately.
   Note that Claude's own sandbox can't reach `api.pixellab.ai`, so a connector is the
   route, not API calls from code.
2. **Pixellab's web editor** — Dave generates using the template above and drops the PNGs
   into `assets/`. Claude then verifies them and reports anything off-spec.

Route 2 works perfectly well and needs no setup. Route 1 mainly saves round-trips.

## Generation log

Every asset, with the exact prompt that made it, so anything can be reproduced or matched.

| Date | Asset | Prompt subject | Size | Notes |
|---|---|---|---|---|
| — | _nothing generated yet; Stage 1 starts with the character_ | | | |
