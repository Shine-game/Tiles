# Coral canonical arm and junction assets

Ordinary arms and junctions each use one source image per logical color. The
shared [pattern assembly](shared-pattern-engine/canonical-assembly.md) supplies
clockwise rotation; logical component IDs and dependencies remain directional.

Keep these ordinary family source PNGs and their import settings:

- `art/themes/coral_reef/artwork/salmon/arm_n.png`
- `art/themes/coral_reef/artwork/turquoise/arm_n.png`
- `art/themes/coral_reef/artwork/salmon/junction_ne.png`
- `art/themes/coral_reef/artwork/turquoise/junction_ne.png`
- `art/themes/coral_reef/masks/junction_ne.png`

There is no external arm mask dependency. The common `linear_reveal` provider
creates the canonical center-to-north field in memory, at the same 8-bit precision
and pixel-center sampling as the original mask. Its values match the former
`arm_n.png` field wherever the arm artwork is visible. Two-front growth and timing
are unchanged. Generated fields are cached and rotate with the source artwork.

All four junctions now also use the retained NE field, rotating with their artwork
without reverse UV compensation. This follows the owner's instruction to use the
remaining canonical mask. The old directional junction fields were not exact
rotations, so their growth contours intentionally change to the canonical NE
contour. Final artwork, topology and dependency timing are unchanged.

The following files are no longer runtime dependencies and can be deleted with
their matching `.png.import` files:

- Both color folders: `arm_e.png`, `arm_s.png`, `arm_w.png`.
- Both color folders: `junction_es.png`, `junction_sw.png`, `junction_wn.png`.
- Masks: **all** `arm_n/e/s/w.png` files.
- Masks: `junction_es.png`, `junction_sw.png`, `junction_wn.png`.

Other components still need their own art/masks: cores, colonies, anemones, ground,
etc. This cleanup list applies to the ordinary arm/junction families only.
Original surplus files may remain in Git; runtime correctness no longer depends
on their presence. Historical package audit records are provenance, not references
that the renderer loads.

`tests/test_coral_arm_rotation.gd` checks both families/colors, canonical textures
and fields, directional transforms, early/mid/final growth, and two-front timing.
Its native reference images are rotated in memory from retained canonical sources;
it never loads removed directional art or masks.
