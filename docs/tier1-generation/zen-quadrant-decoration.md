# Zen stone decorations: quadrant placement

Each stone has four local quadrants around its center. Existing anchors are
assigned to these groups. `spawn.count: [1,2]` chooses one or two decorations;
`spawn.max_per_group: 1` prevents a second decoration in an occupied quadrant.
The planner shuffles anchors, selects compatible artwork, and stops at the target.

All pebble/moss decoration sprites use fixed scale 4. No tile-boundary, radius,
base-overlap or decoration-overlap restriction is applied. In live generation,
occupied-pixel footprints are not generated. One or two decorations are placed
without repeated spatial rejection attempts. Rotation and mirroring follow the
existing rules. Decorations rotate/flip with the main stone.

Decorations use relative z=-1 beneath main stones. The stone layer is z=2 so the
decorations remain above the sand floor. Starting cores and open endpoints use the
same decorated-cell pipeline. Junction artwork, stone sizes, variation and timing
are unchanged.

Verified across all twelve bases and sixteen seeds: one/two decorations, distinct
quadrants, fixed 4x scale, zero rejected candidates and zero raster footprints.
Source and exported-pack checks pass. Rendered Zen check: 3 checks, zero failures.
Local seven-stone cold-board benchmark: 142ms; adding one stone: 97ms. These are
headless local CPU measurements, not Android device timings.
