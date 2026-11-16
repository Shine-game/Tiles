# Step 8 — shared Tier 3 connections

Tier 3 now uses `scripts/pattern/connection_assembly.gd` for the shared boundary
between formation geometry and theme behavior. This is a small integration layer
above the pure topology module, not a replacement renderer or a second state store.
There are no intended visual changes.

## Uniform rules

- Only cardinally adjacent, nonempty, same-color 2×2 formations connect.
  Overlapping formations remain eligible: a 2×3 field has two formations and one join.
- Pair records visit each join once, in row/column order, east before south.
  `pairs(features, key_offset)` accepts origin keys or the older Vines corner keys.
  Its `a`/`b` and `members` keep consumer keys; `origins` and `cells` use board origins.
- Directed side records visit both facing sides of each join. They preserve feature
  insertion order and N/E/S/W side order, including existing random-once plant order.
- Territory records collect at least two connected formations, with optional color
  filtering. Supports are the sorted unique union of occupied cells; centroids count
  each occupied square once. Diagonal contact never joins territories.
- A connection is old only when all its supporting formations are old. Prerequisites
  use the latest member time, with an explicit field, floor and optional delay.
  `start` settles old connections at the existing `-100` sentinel; `ready` retains
  raw prerequisite times for theme-specific scheduling.
- Pair identities normalize endpoint order and color. Directed records add a side
  identity. Territory identities describe sorted membership, independent of traversal.
  Records are derived values; planning does not mutate model events.

## Live consumers and retained differences

| Theme | Shared input | Theme-owned behavior |
| --- | --- | --- |
| Vines | Pairs; latest flower start plus fractional delay | Link drawing, star pop and completion timing |
| Clockwork | Pairs; latest mechanism ready time with floor zero | Chains, caps, pressure, shutters, motion, audio and retirement |
| Coral | Pairs; latest colony ready time | Anemone foot, oral disc and masked regional growth dependencies |
| Zen stones | Directed sides, color 2; latest landmark ready time | Supplied watershed masks, peak preservation and lateral vegetation |
| Zen rakes | Territories, color 1; latest landmark ready time | Seasonal trunk/branch generation, persistent history and source-pixel centroid arithmetic |

For vertical stone joins the upper formation floods south and the lower one north;
for horizontal joins the left floods east and the right west. Only the two facing
watersheds activate. The shared planner does not choose masks or vegetation.

A territory's structural identity **must not replace a tree's historical identity**.
Expansion changes membership and center, while existing branch IDs and positions
survive. The specialized tree module still replaces its trunk, adds bridging limbs,
and restores lineage through Undo/capture snapshots. Existing per-part adapters feed
the common component-state lifecycle; no duplicate parent state is introduced.
Likewise, Clockwork's rebased surviving chain clocks remain renderer-owned.

Tier 3 appearance metadata and specialized shaders retain their current consumers.
This step does not pretend that tree history, pond masks and Clockwork mechanisms
can be described by one sprite recipe. Tier 0/1/2 set loading and common rendering
continue unchanged. Remaining metadata consolidation belongs to Step 9.

## Verification

- 78 focused checks cover all cardinal joins, both facing sides, translated Vines
  keys, mixed colors, diagonal rejection, unique supports, IDs, readiness and
  overlapping dense 9×9/11×11 boards.
- All 464 before/after model snapshots match byte for byte, and all 256 real-game
  rendered frames match exactly across four themes, both colors, 9×9/11×11 boards,
  2×2/2×3/3×2/3×3 layouts and four animation phases.
- Existing state, chain-arrival, pond, tree, Vines and gallery tests exercise the
  retained specialized behavior and historical state.

The native gallery suite passes its 104 checks and retains its pre-existing
shutdown resource-leak diagnostic. This refactor does not change gallery ownership.
