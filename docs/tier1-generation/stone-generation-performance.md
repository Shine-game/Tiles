# Stone generation performance

Large 2.8x decorations caused hundreds of candidates per stone to be rasterized
before failing radius or tile-boundary checks. Those checks now run first using
cached silhouette radius and convex-hull extrema. Valid candidates still use the
same full raster collision checks and the same size, selection and density rules.
Unchanged placement plans are also reused at the theme layer.

Local Godot 4.6.3 headless measurement, seven stones: planning 2605ms -> 218ms;
complete cold board assembly 2974ms -> 333ms; adding one stone 665ms -> 145ms.
These are local CPU timings, not a promise of identical Android performance.

Sixty rotated/reflected footprints matched the exact raster bounds and radius.
The seven sampled plans kept identical placement fingerprints against the old
planner. Planner, integration, variety, core decoration and exported-pack checks
passed. Detailed measurements are in `stone-generation-performance.json`.
