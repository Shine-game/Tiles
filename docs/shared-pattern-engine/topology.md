# Step 2 — shared topology implementation

Implemented in [`scripts/pattern/topology.gd`](../../scripts/pattern/topology.gd).
This module contains pure geometry and logical-color connectivity. It has no theme,
asset, shader, growth-clock, palette or UI dependencies.

## Public geometry API

| Method | Result / convention |
| --- | --- |
| `value(grid, cell)` | Logical color, or zero outside the board |
| `neighbor_mask(grid, cell)` | Same-color N=1/E=2/S=4/W=8 bits; zero for an empty cell |
| `rotate_mask(mask, turns)` | Clockwise quarter turns, including negative and wrapped counts |
| `canonical(mask)` | Canonical mask and first valid quarter-turn count; empty for invalid input |
| `shape(mask)` | `isolated`, `endpoint`, `straight`, `bend`, `t`, `cross`, or `invalid` |
| `is_straight(mask)` | True only for 5/10; does not decide artwork for other shapes |
| `edge_key(a, b)` | Canonical unordered coordinate pair, ordered by row then column |
| `is_cardinal_offset(delta)` | True only for one-cell orthogonal displacement |
| `support_cells(origin)` | Four 2×2 cells in TL/TR/BL/BR order |
| `is_formation(grid, origin, color)` | Four matching occupied cells at a top-left origin |
| `formations(grid)` | Row-ordered dictionary keyed by top-left origin, with color, supports and center |
| `formation_neighbors(features, origin)` | Same-color adjacent origins in N/E/S/W order, with direction index |
| `adjacent_pairs(features)` | Each same-color orthogonal pair once, in row order, east before south |
| `connected_formations(features, color, minimum_count)` | Connected groups with origins, unique supporting cells, color and centroid |
| `centroid(cells, units_per_cell)` | Mean cell-center position; caller supplies unique cells; default units are cells |
| `sorted_cells(cells)` | Copy ordered by row then column; does not mutate input |

An empty cell also returns mask zero; callers must check occupancy before choosing
isolated-cell artwork. Shape classification alone does not distinguish empty
ground from an occupied isolated tile.

The six canonical masks remain 0, 1, 5, 3, 11, 15, matching Zen's existing motif
orientation. Pattern masks and direction indices now have one shared convention.
Legacy wave/frond traversal can retain a different iteration order: those arrays
are not bit assignments and changing them could alter existing event ordering.

Formation connections require origins one cell apart, so both orientations of a
2×3 rectangle connect two overlapping 2×2s. Color changes, diagonal contacts and
distant formations do not connect. Components count each supporting square once.
Connected-group ordering is deterministic even if input dictionary insertion order
changes. Positions are in cell units; a compatibility adapter may request a
centroid directly in 256-pixel source units to preserve existing float arithmetic.

Topology does not select a theme's centerpiece or change its current straight
cell rendering. Those behavior migrations remain in Steps 5–6.

## Adapters now in use

- `growth.gd`: board lookups, unordered edge identities, 2×2 enumeration and flower
  connections delegate to topology. The public `is_flower()` still accepts the
  old inner-corner coordinate and translates it to a top-left origin. Existing
  wave timing, leaf placement, flowers and link records retain their format.
  Vines and Labyrinth inherit these shared rules.
- `clockwork_growth.gd`: connection masks and straight classification delegate;
  mechanism connections use shared pair enumeration. Wheel selection, pressure
  timing, chain assembly and cap selection remain the existing implementation.
- `coral_growth.gd`: shared direction offsets, adjacency/layout eligibility and
  colony-pair enumeration. Its existing component/colony/anemone records remain.
- `zen_geometry.gd`: keeps its public neighbor/rotation/canonical methods as thin
  adapters. Its rake curves, height generation and shader use remain unchanged.
- `zen_growth.gd`: pond connections use shared same-color formation neighbors;
  sector selection, shared-base transforms and timing remain unchanged.
- `zen_trees.gd`: shared connected formations supply unique territory supports;
  the adapter aggregates old/ready state and requests the legacy source-pixel
  centroid. Historical branches, trunk replacement, season and settled-state
  protection remain owned by the tree behavior.

Zen still inherits Coral's growth scheduler in this step. Removing its inherited
Coral component-building work belongs to later scheduling/model migration; doing
that now would mix Step 3 responsibilities into a topology-only extraction.

## Verification

`tests/test_pattern_topology.gd` checks the 16-mask truth table, canonical turns,
clockwise rotation, same/opposite colors, empty/edge/diagonal cases, 9×9/11×11
boards, dense overlap, both 2×3 orientations, unique-cell centroids, deterministic
pair/component ordering, adapters and randomized boards. Four-cell and pair-count
oracles are independent of the extracted implementation.

Before editing, 580 model states were recorded across Vines, Labyrinth, Clockwork,
Coral and Zen: all 16 masks in both colors, settled/new states, dense 9×9/11×11
boards, removals, and seeded mixed-color before/after boards. The refactored
models produced byte-identical script state for all 580 cases, including event
ordering, timing, component identities and formation/territory metadata. These
large comparison records and the one-off comparison driver stay in the execution
workspace rather than becoming production assets.

Existing theme and UI tests remain applicable. Native Clockwork, pond and tree
checks cover actual rendering/capture behavior in addition to headless topology.
Shading, artwork, palette order, UI layout, appearance versions and game rules
are unchanged. Step 2 did not include common construction state or scheduling;
those are now documented separately in [the Step 3 implementation](state-and-growth.md).
The subsequent [Step 4 foundation](assets-and-rendering.md) adds shared asset
loading and component rendering without changing these topology rules.
