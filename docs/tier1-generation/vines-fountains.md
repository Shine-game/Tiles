# Vines fountains (tiers two and three)

Tier two places one supplied fountain sprite at each completed 2×2 formation center. This replaces the six-layer post assembly and its sequential opening animation; those layers are removed from the live artwork directory. The two unrelated flower images included in the archive are not part of this fountain assembly.

The assembly is `art/themes/vines/sets/tier2.json`. It chooses pink artwork for logical color 1 and violet artwork for logical color 2, following the existing vines color mapping. `size_cells` specifies a 2×2 canvas. The original 255×255 PNGs are preserved, without recoloring or resizing. Each fountain fades in over 0.25 seconds and retains its authored orientation.

Each PNG has a sidecar in `art/themes/vines/artwork/tier2/`. Pixel coordinates use top-left origin, X right and Y down. `center_px` marks the visible central outlet: violet [127,106], pink [127,119]. These points were marked by inspecting the artwork. The marked point is placed at the 2×2 formation center. `water_origin_px` currently equals `center_px`; it can be adjusted independently for future artwork. Scaling belongs to the assembly, with a per-sprite `scale` defaulting to 1.

Tier three connects the same adjacent, same-color formations as before. A water arc replaces the previous vine-and-star link. Water starts once both fountains finish appearing (`link_overlap_fraction: 1.0`). Its endpoints are obtained from the same metadata transform used for fountain placement. Horizontal connections arc upward; vertical connections arc leftward to keep a visible curve.

The `water` object in the assembly controls arc height, stream width, water color, droplet count and travel duration. Current settings: height 0.45 square, width 0.035 square, seven moving droplets and 0.8-second travel. `scripts/vines_fountain_water.gd` animates continuously on its own visual clock after construction ends. It does not keep the placement gate open; undoing the connection stops processing, and normal scene-tree pause freezes the animation.

Validation: `tests/test_vines_fountains.gd` checks both palette mappings, center transforms at multiple sizes, horizontal/vertical geometry, sequencing, settled animation, undo cleanup and placement completion. The live layout was also rendered for inspection.
