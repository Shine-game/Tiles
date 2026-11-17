# Shared bend, T and X overlays

`PatternJunctionLayer` is the single overlay loader, assembler and lifecycle
adapter for every theme. It uses same-color square topology: two adjacent ports
are a bend, three are a T, and four are an X (`cross` in configuration). Straights,
endpoints and isolated cells keep their existing behavior.

The source growth and its decorations remain underneath. Legacy bend/T/X center
art is suppressed only for themes that enable the new bindings. Vines is enabled
with the supplied flowers; the other themes can enable the same system when their
three shape-specific assets are supplied. No separate junction renderer is needed.
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
