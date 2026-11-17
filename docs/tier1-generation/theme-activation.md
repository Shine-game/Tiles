# Universal Tier 1 activation — step 6

The four production catalogs are active. `TileBoardView` now owns one
`PatternTier1Layer`, which binds the current structural model to the shared
planner, timeline, component state and presenter. Normal play, theme changes,
palette changes, helper restoration, resizing and gallery captures use this path.

| Theme | New presentation | Retained presentation |
| --- | --- | --- |
| Coral | Canonical arm, both colors, anchor-selected coral sprouts | Ground, cores, directional junctions, colonies and anemones |
| Clockwork | Canonical half-tubes and perpendicular ring overlays | Plates, wheels, couplings, mechanisms, chains, motion and effects |
| Vines | Two native half-stems per edge, selected leaf overlays | Cell washes, holding motifs, links and flowers |
| Zen | One decorated stepping stone per shared stone edge | Isolated/endpoint cores, rake relief, centerpieces, landmarks, ponds and trees |

The old arm/tube/path drawing is suppressed where the new layer draws it.
Structural components remain in their models and common state so higher-tier
requirements and timing remain available. Decoration/base tails extend the visual
construction gate without changing the structural model's duration or higher-tier
start times. One common clock drives all construction. Clockwork removals detach
the complete composed subtree, freeze its current masks, and fade it through
retirement events in that same state/clock. Reset removes the generated trees.

## Configuration for another theme

Generation contains no theme-name branches. Register a catalog and choose an
existing structural source layout in the theme registry's `tier1_artwork` object:

```json
{
  "catalog": "res://art/themes/example/sets/tier1-artwork.json",
  "status": "active",
  "source_layout": "components",
  "component_ports": {
    "arm_n": 0,
    "arm_e": 1,
    "arm_s": 2,
    "arm_w": 3
  }
}
```

The catalog and per-sprite sidecars still define artwork, source dimensions,
light/up markers, attachments, anchor acceptance, rotation, mirroring, selection
counts, spacing and constraints. This registry object only binds board geometry
and painter layers. Unneeded optional values can be omitted.

| Field | Use / default |
| --- | --- |
| `source_layout` | Required when active: `components`, `edge_halves` or `shared_edges` |
| `component_ports` | Required for `components`; map selected model component IDs to N/E/S/W indices 0/1/2/3, or to a direction field name such as `"direction"` |
| `family` | Catalog family, default `default` |
| `size_cells` | Source canvas dimensions before rotation, default `[1,1]` |
| `stroke_seconds` | Full-edge travel for `edge_halves`, default existing `Growth.STEP` (0.14 seconds) |
| `logical_color` | Family color for `shared_edges`, default 2 |
| `duration_sec` | Base appearance interval for `shared_edges`, default 0.24 seconds |
| `layer_z_index` | Layer relative to board, default 1 |
| `decoration_z_index` | Optional override of the presenter's overlay z-index (normally 1) |
| `seed` | Reproducible generation seed, default 10973 |

`components` consumes selected structural events with `center`, `color`, timing
and stable dictionary keys. Each becomes a native arm with its forward constrained
to the configured port. `edge_halves` consumes the model's undirected edges and
creates an outward native half at each endpoint, both bound to the same full-edge
wave. Vines' 255px canvas uses the explicit 255/254 size correction in registry
data to make native center-to-tip distance exactly half a cell. `shared_edges`
consumes the same-color neighbor graph once per east/south pair and places a
freely oriented base at each shared midpoint. Zen uses size 0.7 and family stones.

A future theme using one of these existing model contracts only needs its assets,
metadata, catalog and registry data. A new structural mechanic with a different
model contract needs a source adapter; it does not need another decoration or
rendering algorithm. An integration test introduces a new theme identity and
catalog at runtime and renders it through this unchanged pipeline.

## Palette and persistence

Vines' catalog declares `palette.runtime_palette_policy` as
`hsv_relative_to_source_palette` and `palette.source_colors` for logical colors
1 and 2. The shared shader shifts hue, relative saturation and value to the
selected player pigments while preserving source alpha and texture variation.
Both growing and settled stems/leaves receive treatment. Other catalogs retain
their native artwork colors. Palette changes preserve geometry and reveal history.
These palette fields are optional and schema-validated; they also work for another
theme with a selectable player palette.

Generation uses stable component/anchor identities rather than the placement
counter or view size. Gallery reconstruction therefore selects the same bases,
decorations and mirrors. Theme appearance versions advance to Zen 0.12, Clockwork
1.2, Vines 1.1 and Coral 2.3. Gallery fingerprints also include
`/tier1-generative-v1`, keeping older captures distinct.

## Dense-board optimization

The live layer requests `include_footprints: false`. The planner still constructs
a full raster whenever canvas/base collision or any participant's protected
spacing requires it. Otherwise it checks the attachment, radius and work budget
using cached source geometry, without allocating an unused occupied-cell map.
Public callers default to complete footprints; returned `footprint_computed`
marks optional omission. Selection, radius and constraint equivalence are tested.

A dense 11x11 coral board (418 arms, 3,760 presentation nodes) fell from 36.576s to
2.558s for initial settled construction on this executor. Representative Clockwork,
Vines and Zen initial constructions took 1.132s, 0.622s and 2.453s respectively.
These are desktop executor observations, not mobile performance guarantees.

## Validation limits

Godot 4.6.3 is installed; the project targets 4.7.2. Real OpenGL compatibility
checks use Mesa llvmpipe. Four-theme rendered growth, palette pixels, Clockwork
native operation and incoming-front visibility pass. The Android resource pack
exports and is checked separately; no APK/device run is claimed.

The existing `test_ui.gd` has 24 failing touch/menu assertions in this environment.
The same 24 assertion messages reproduce on the unchanged step-5 baseline, both
in count and order. They are recorded as pre-existing, not counted as passing.
Other checks and detailed counts are recorded in `activation-validation.json`.

Clockwork center rings now use one center anchor and a fixed decoration path.
`center_join_masks` selects endpoints (1,2,4,8) and straights (5,10). The lowest
connected port owns the shared center overlay, while the other half-arm suppresses
its decorations. Both tube bases keep their original growth fields. Ring overlays
sit above ordinary wheel caps so endpoint rings remain visible. Bends, T/X shapes
and isolated cells receive no ring. The alternate ring asset remains available in
the catalog but is not selected by the active fixed-design rule.

Zen stones now use `cell_centers`: each logical-color-2 square receives one
full 255px-canvas stone centered at (x+0.5,y+0.5), at one-cell canvas size.
This includes isolated and endpoint squares; shared-edge placement and legacy
stone cores are suppressed. Rake squares retain their existing rendering.
Small-decoration local scales change from 1 to 1.4 because base canvas size
changes from 0.7 to 1: the resulting on-board size is exactly twice the previous
size (1.4 / 0.7). The visible-radius budget increases proportionally to 11.2px;
canvas, stone-alpha, gap and decoration-overlap checks remain enabled.

Full-square stone timing uses `progression_scale: 2` and `duration_sec: 0.48`.
Zen scales new stone-cell arrival times before scheduling its landmarks, ponds
and trees. Rake arrivals and settled-cell sentinels remain unchanged. Stone
landmarks wait for at least the full stone reveal before their hold/growth phases.
