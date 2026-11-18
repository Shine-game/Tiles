# Vines tier-two post

The live assembly is `art/themes/vines/sets/tier2.json`, composition `flower`, part `flower`. Its `vines.layered_post` provider replaces the procedural flower previously used for each completed 2×2 formation. Both logical colors use the same supplied artwork, with no recoloring.

The six original 255×255 RGBA images are preserved under `art/themes/vines/artwork/tier2/`. Their original registration metadata is retained in `source_registration.json`. They share one coordinate system, so do not trim transparent padding or separately recenter individual layers.

Assembly coordinates are source pixels, with X right and Y down. `center_px` and `post_center_px` are [126.5, 124.5], the center of the post's supplied visible bounds. This point is placed at the formation center. `post_foot_px` is [127.297, 243.409], copied from the source metadata. `canvas_px` is [255,255]. `size_cells` is [2,2], so the registered canvas occupies the formation's two-square height and width. Scaling belongs here; source PNGs are unchanged.

The `layers` array controls painter order and animation. Each layer has an image, origin, start and duration. The current sequence is:

1. Post: bottom-up reveal, 0–0.35 seconds.
2. Climbing vine: bottom-up reveal, 0.35–1.0 seconds.
3. Upper-right flower: opens from its marked growth point, 1.0–1.2 seconds.
4. Middle-left flower: 1.2–1.4 seconds.
5. Lower-right flower: 1.4–1.6 seconds.
6. Upper bud: 1.6–1.8 seconds.

The four flower origins are copied directly from `layers.json`. Opening scales each flower around that point and restores exact source alignment at full size. Finished assemblies and undo restorations show every layer immediately. Construction waits until all six layers finish. Existing formation prerequisites, links and their overlap policy remain in effect.

To tune the sequence, edit each layer's `animation.start_seconds` and `duration_seconds`, then keep the parent `animation.duration_seconds` equal to the last layer's end. `tests/test_vines_layered_post.gd` checks source dimensions, sequencing, formation detection, completion and settled restoration.
