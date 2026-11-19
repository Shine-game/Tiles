# Vines flower replacement and third-tier butterflies

Small bend/T/X flowers fade away as a covering tier-two flower is drawn. Each small flower checks the 2×2 formations that contain its cell and follows the inverse of the large flower's 0.25-second opacity. It is fully hidden for a completed formation and restored if undo breaks that formation. If multiple large flowers cover it, the greatest coverage wins. Other small junction flowers retain their existing appearance.

`art/themes/vines/sets/tier3.json` configures one butterfly per adjacent same-color pair of 2×2 formations. The shared area is the intersection of their square regions: a 1×2 or 2×1 rectangle. A seeded uniform choice places the butterfly center anywhere inside that overlap and rotates it through 0–360 degrees. Choices remain stable on redraw, resize and undo. The center is constrained to the overlap; wings may extend beyond it.

The butterfly canvas is one square on each axis: one-half of its original two-square size. Pink formations use the original rosa butterfly, violet formations use the original violet butterfly. Neither is recolored. Both large flowers finish their audio and visual effects, then a 0.2-second pause precedes the butterfly and its chime. The delay is authored as `schedule.after_tier2_seconds` in `tier3.json`. The later completion of the two supporting formations controls the start. Butterfly appearance takes 0.18 seconds; settled/gallery drawings show it immediately. Water remains disabled.

Tests: `tests/test_vines_tier3_butterflies.gd` covers both colors, horizontal and vertical overlaps, size, stable placement/rotation, small-flower crossfade, completion and undo restoration.
