# Coral plate and radial petals

The plate formation is internally the colony in `sets/tier2.json`. Its existing
`colony_body` artwork is retained. The two old folds and two old fingers are
replaced by eight radial petal slots. Petals begin after the plate is fully
revealed, then grow simultaneously along their authored axes.

Both uploaded archives contain 22 actual petal PNG/JSON pairs, although their
source manifests list only 12. Only sprites 1–12 are enabled in the selection catalog; 13–22 are unused. Color1 is
salmon, color2 teal. Matching dimensions and marker geometry were checked across
colors; transparent original PNG bytes are preserved.

Each imported metadata sidecar maps `attachment_point_px` to `attachment` and
`axis.to_px` to `direction`. The supplied axis.from_px matches the attachment.
The supplied confidence label describes these points as raster estimates. No
pixel-derived replacement markers were invented.

`artwork/petals/radial.json` defines count 8, seed 10973, scale 1. Each formation
selects eight distinct source designs from sprites 1–12 without replacement, randomly chooses
original/X-reflected forms, and chooses a seeded starting angle in [0,360).
The desired growth directions are phase + slot*45 degrees. Rotation compensates
for the reflected source direction. Every source attachment maps to the plate
center. Native sprite-pixel scale is used; edit catalog.scale to tune it later.

The shared `scripts/pattern/radial_petals.gd` handles selection and marker-based
assembly. Coral retains its existing structural event clock and directional
reveal material. The completed colony timing includes all eight petals, so
higher formations and the placement gate wait for the full bloom. Choices stay
stable across redraws, undo and gallery reconstruction.

Source, exported resource pack, exact-transform/spacing/scheduling regressions,
and an OpenGL render in both colors passed. No Android device test was run.
