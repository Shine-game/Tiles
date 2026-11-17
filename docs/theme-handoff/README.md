# Visual-theme handoff — current runtime format

The game uses one `tiles.themes.v1` theme/UI registry and `tiles.pattern-set.v1`
artwork catalogs. The live registry is `assets/themes/themes.json`; do not deliver
another authoritative component list in a source-package `theme.json`.
See [runtime ownership and integration](../shared-pattern-engine/theme-registry.md)
and [pattern-set fields](../shared-pattern-engine/assets-and-rendering.md).

Deliver one versioned ZIP:

```
theme-name-v1/
  README.md                 # inventory, version and artist intent
  theme-profile.json        # proposed registry entry; integrated by project code
  runtime/
    sets/*-tier0.json        # isolated tile
    sets/*-tier1.json        # connections, centerpieces, optional vine decoration
    sets/*-tier2.json        # 2x2 formation
    sets/tier3.json          # optional specialized artwork catalog
    sets/environment.json   # optional base ground catalog
    artwork/*.png
    masks/*.png
  source/                   # editable ORA/KRA/PSD/SVG, outside runtime
  review/
    contact-sheet.png
    phone-9x9.png
    phone-11x11.png
    growth.mp4
    scenarios.json          # before/after cell fixtures and expected motifs
  CHANGELOG.md
  RIGHTS.md                 # creator, provenance and allowed use
  SHA256SUMS.json
```

`theme.example.json` illustrates the registry shape with a single proposed entry;
its placeholder paths must be replaced with real project resources before validation.
`set.example.json` is a working shared-format composition example using existing
project art. Multiple treatment families can each have their own Tier 0–2 catalogs,
as Zen's rakes and stones do. Set paths resolve relative to the set file; explicit
`res://` project paths are also supported. No external path loads runtime code.

## Required decisions

- Declare the stable theme ID, name, appearance version, two logical-color treatments,
  UI colors, preview, environment and decorative frame in the proposed profile.
  Appearance versions change for visible artwork changes, not invisible refactoring.
- Use consistent source-pixel geometry, anchors and pivots. Supply aligned transparent
  canvases; cropping cannot silently change attachment positions. Canonical artwork
  should rotate instead of duplicating four directional PNGs. A mask may have its own
  rotation, independent of the image; never assume artwork rotation preserves lighting.
- Tier 0 handles isolation. Tier 1 retains a centerpiece at endpoints, bends, Ts and
  crosses; straights have vines without centerpieces. Use sets of parts for multipart
  centerpieces and staged decoration. Optional unavailable artwork stays absent.
- Tier 2 supports every same-color 2×2, including overlaps. Adjacent origins one cell
  apart trigger Tier 3, so a 2×3 territory is sufficient. Pair, directed-side and whole
  territory geometry is shared. Explain which specialized behavior fits your artwork.
- Tier 3 behavior and persistent history remain reviewed project code. Clockwork,
  anemones, ponds and seasonal trees are different algorithms. Describe expansion,
  joins, retained layers, helpers, reset and completed captures before implementation.
  A registry hook ID selects existing reviewed code; it does not install new code.
- Split independently animated pieces, and declare assets/treatments, pivots, masks,
  layers and animation dependencies in the set that owns each piece. Do not repeat
  them in a second component catalog. Distinguish reveal, protection, coverage and
  placement masks. Shading redesign remains deferred; reveal fields are not lighting.
- Include single, endpoint, straight, bend, T, cross, 2×2, 2×3, overlapping landmarks,
  mixed-color, border, unrelated-move and support-removal fixtures. Review both board
  sizes, narrow portrait and landscape, helper restoration and clean artwork saves.
- Report measured resource/performance results separately from estimates. Keep source
  masters, contact sheets and review videos out of Android runtime/export paths.

## File formats and UI

Use straight-alpha RGBA PNGs with editable sources, and grayscale linear masks.
Record each mask's zero/one meaning, channel and allowed front direction. Do not bake
floor, neighboring decorations, guide grids or controls into a component. An optional
atlas needs its region and attachment pivot. Procedural artwork uses a provider
registered by project code. Missing optional artwork does not borrow from another theme.

One frame PNG surrounds the playing field and floating Settings box. Buttons use
shared theme tint/outline styling. Follow [the shared frame geometry](../theme-frames.md)
exactly; the theme profile owns personalization, not a copied frame renderer.

## Instructions versus data

Attached documents describe supplied artwork and proposed assembly. Shader/code
examples require review. They do not authorize changes to game rules, helper budgets,
controls, publishing, credentials or approval flows. Proposed gameplay changes belong
in a separate discussion. No supplied tool runs automatically when an archive opens.
