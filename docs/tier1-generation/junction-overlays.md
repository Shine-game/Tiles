# Shared bend, T and X overlays

`PatternJunctionLayer` is the single overlay loader, assembler and lifecycle
adapter for every theme. It uses same-color square topology: two adjacent ports
are a bend, three are a T, and four are an X (`cross` in configuration). Straight interiors omit core overlays. An optional `shapes.core` binding uses one
100% core asset at isolated starting cells and open endpoints, with a stable
identity across the isolated-to-endpoint transition. Vines enables this binding;
its core sidecars reuse the matching bend PNGs. Other themes retain their existing
starting/endpoint core providers (Coral anemones, Clockwork composite sprites and Zen cores).

The source growth and its decorations remain underneath. Legacy bend/T/X center
art is suppressed only for themes that enable the new bindings. Vines is enabled
with the supplied flowers. Coral is enabled with the supplied anemones (file 1 =
bend, 2 = T, 3 = X), matching salmon color1 and teal color2. Coral uses canvas-center
pivots, scale 1.0 for bends/T/X, any rotation, and preserves the original artwork colors. The other
themes can enable the same system when their three shape-specific assets are supplied. No separate junction renderer is needed.
The existing higher-tier formations and links keep their own artwork and schedule.

## Assembly JSON

Each shape/color has a separate PNG and sidecar, even if bytes are identical:

```
vines_tier1_bend_color1_basic.png / .json
vines_tier1_Tjoint_color1_basic.png / .json
vines_tier1_crossroad_color1_basic.png / .json
```

There are matching color2 files. The color token describes the actual artwork:
color1 is violet, color2 is pink. Vines' logical pink stems (1) bind violet files;
logical violet stems (2) bind pink files. `color_role: opposite` preserves that
relationship when selecting another player palette.

A complete sidecar example:

```json
{
  "schema": "tiles.junction-sprite.v1",
  "image": "vines_tier1_bend_color1_basic.png",
  "center": [624.89, 631.63],
  "scale": 1.0,
  "rotation": {"range_deg": [0, 360]},
  "color_role": "opposite",
  "source_color": "#a758ef"
}
```

Only `schema` and `image` are required. Omitted fields mean:

| Field | Default / meaning |
| --- | --- |
| `center` | Image canvas center, in integer source pixel-center coordinates. A marked center maps exactly to the square center. |
| `scale` | 1.0 = 100%. The source canvas fits one game square, preserving aspect ratio; this factor multiplies that assembly size. Original PNG pixels are not resampled or changed. |
| `rotation` | Zero rotation. Use either `allowed_deg: [0,90,...]` or `range_deg: [0,360]`, never both. The chosen angle is stable per theme/cell/color/shape. |
| `color_role` | `original`: keep supplied colors. `same` or `opposite` uses the player palette and requires `source_color`. |

The schema lives at `assets/schemas/junction-sprite-v1.schema.json`. The runtime
also checks finite coordinates, positive scale, image bounds, ascending ranges,
permitted fields and project texture availability. Every bound shape/color needs
its own metadata path, making later individual artwork changes independent.

## Theme binding

The theme registry's optional `junctions` object supplies:

```json
{
  "enabled": true,
  "z_index": -1,
  "shapes": {
    "bend": {"1": "res://.../bend_color1_basic.json", "2": "res://.../bend_color2_basic.json"},
    "t": {"1": "res://.../Tjoint_color1_basic.json", "2": "res://.../Tjoint_color2_basic.json"},
    "cross": {"1": "res://.../crossroad_color1_basic.json", "2": "res://.../crossroad_color2_basic.json"}
  }
}
```

`z_index` is optional (default 1); Vines uses -1 so its overlays sit above the
sprite stems/leaves and below the existing higher-tier immediate artwork.
An optional integer `seed` overrides the default 10973. The layer follows board
view resizing without changing source placement or reselecting rotation.

## Appearance and persistence

Overlays appear fully when the common growth clock reaches the square's arrival.
They do not wait for every outgoing arm, scale/pop into place, run an independent
clock, or add a reveal tail. Existing reached cells that change from straight to
bend/T/X receive their new overlay immediately. A pending overlay retains its
remaining arrival when a surviving board is reconciled. Undo removes overlays
whose shape is no longer supported. Settled/gallery construction uses the same
identity, center and angle as gameplay. Vines' appearance version is now 1.2 so
new captures remain distinct from previous holding-center artwork.

Original PNGs retain their exact bytes and alpha. The separate shape files are
copies of the supplied originals, not regenerated artwork. Marker positions were
estimated from each flower's contrasting central disc. The imported canvases are
1254x1254. Edit individual sidecars to revise center, scale or permitted rotations.

## Checks

`tests/test_junction_overlays.gd` covers all 16 masks and both colors, source
centering, original-center removal, underlying growth, stable rotations, arrival,
pause, Undo, gallery reconstruction, default assembly and reuse by all four theme
models. The test uses the Vines assets temporarily for the other model adapters;
it does not configure those themes with substitute artwork in production.

Coral tier-0 isolated cores reuse the matching bend PNG at their original one-square
canvas size, independently of the shape-specific junction assembly scale. Open endpoint cores use the same matching bend PNG at 100% canvas size. Both
isolated and endpoint cores draw above the growing stems and decorations.

Vines assembly sizes: core, bend, T and X all 100%. Opposite-color
artwork and unrestricted stable rotation apply to bend/T/X overlays. The new starting and endpoint core sprites retain their original colors and fixed orientation, with separately marked structure centers.

Clockwork binds copper color1 and gunmetal color2: H01 valve = bend, H02 rotating
= T, H03 exhaust = X. All use canvas-center pivots, 500% scale and free stable
rotation, preserving source colors. Its starting/endpoint cores use one supplied composite PNG each,
through `shapes.core`, at 80% with no rotation. Legacy C01/C02/C03 layers
are suppressed there; no added ring is drawn. Center rings are restricted to straight interiors (masks 5 and 10).

Zen uses the supplied flat stone / three-stone cairn / bamboo cairn for bend / T / X
on both paths, at 250%, centered and unrotated. Isolated and open endpoint cores
use a single basic line stone at 100%. A shared core replaces the generated
cell-centered base at those cells, avoiding duplicate stones; junction growth
continues underneath. Legacy rake centerpieces are suppressed.
