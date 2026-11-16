# Step 7 — shared Tier 2 assembly

Tier 2 is now implemented through common formation records and live sets for all
four active themes. Existing artwork, variants, timing, overlap eligibility,
layering, motion, audio and saved appearance revisions are preserved.

## Shared formation contract

[`formation_assembly.gd`](../../scripts/pattern/formation_assembly.gd) builds on
the existing pure topology module:

- `collect(before, after)` returns every eligible same-color 2×2, including
  overlaps, with a top-left `origin`, four `cells`, cell-space `center`, logical
  `color`, `old` support status and canonical `tier2/color/y/x` identity.
- `perimeter()` preserves the clockwise support order used by Vines' edge gate.
- `prerequisite_ready()` reads the set's support parts, port prefix/names and
  floor time, and samples their actual existing completion events. Clockwork
  waits for wheels and inner tubes; Coral waits for its internal arms.
- `assemble()` emits the configured parts through a project-owned callback,
  applying relative offsets or predecessor dependencies. The complete existing
  events remain available for two-front/mask arrival calculations.
- `completion()` uses a declared complete offset or the latest emitted end.
  Clockwork explicitly retains its 1.95 s offset, preserving original numeric
  readiness as well as the hatch's phase sequence.
- `validate_schedule()` checks durations, offsets and dependency order when sets
  are enabled, before a malformed schedule reaches the assembler.
- `bind_records()` adapts current model keys/times to the common record.
  `state_events()` publishes those records to the common construction state,
  namespaced by theme, with supports and ownership metadata.

Models expose `tier2_records()` through one interface. Their existing public
corner/origin keys remain compatible with motion, sound and Tier 3 consumers.
Canonical formation state replaces the coarse Vines/Zen formation entries;
Clockwork/Coral additionally retain the necessary per-part construction records.
A support deletion removes the affected identity, and helpers recover it using
its stable order. Unrelated moves preserve settled records.

Clockwork's helper preservation can leave supported parts growing on rebased
clocks even though their cells are now marked old. Its adapter supplies child
record identities, allowing the common lifecycle to honor unfinished parts rather
than prematurely settling the formation. Private reveal/motion hooks still own
individual sprites and shaders.

## Live Tier 2 sets

| Family | Definition | Preserved specifics |
| --- | --- | --- |
| Clockwork | [tier2.json](../../art/themes/clockwork_workshop/sets/tier2.json) | Four staged parts, support-wheel power, opposite-metal L03, rise shaders and painter layers |
| Coral | [tier2.json](../../art/themes/coral_reef/sets/tier2.json) | Body/folds/fingers, original growth fields and body-dependent timing in persistent colony groups |
| Zen rakes | [rakes-tier2.json](../../art/themes/zen_garden/sets/rakes-tier2.json) | Pattern first, 0.10 s hold, 0.45 s fade; half-size lantern with original pedestal pivot |
| Zen stones | [stones-tier2.json](../../art/themes/zen_garden/sets/stones-tier2.json) | Four origin-selected rocks, pattern first, unchanged phase order and stable painter order |
| Vines | [tier2.json](../../art/themes/vines/sets/tier2.json) | Existing procedural flower, support foliage, petals, palette colors and 0.36 s pop |

The Clockwork and Coral set catalogs now own their Tier 2 metadata and persistent
sprites as well as ordinary parts. Their old specialized assembly branches have
been replaced by the shared multipart scheduler. Tier 3 and ground retain their
current adapters. Clockwork's animation, retirement, phase, pressure and sound
hooks keep their original component IDs.

Zen's landmark node retains its identity, clipping shader and fade hook, but reads
artwork, variant policy, pivot, filtering, extent and timing from the live set.
The common renderer's `max_extent_cells` sizes a texture by its largest side while
preserving aspect ratio. This matters for the non-square rock 02/04 masters; the
lantern stays attached at source pivot `(627,1090)`. Lower-layer suppression reads
the formation policy, retaining the ordinary four-cell pattern underneath.

Vines' flower drawing has moved from the board to a registered immediate provider
in `vines_renderer.gd`. `vines_growth.gd` retains the shared edge graph while
reading flower duration and its existing link-overlap fraction from the same set.
The normal flower sound trigger uses that model duration. The early flower/link
animation overlap is preserved; it has not been changed to wait for every petal.

## Boundaries and verification

There are no new images, masks, shaders, preview screens or puzzle rules. All five
Tier 2 definitions are included by the existing export filters. Appearance
versions stay unchanged because the rendered result is unchanged.

`test_tier2_sets.gd` passes 353 checks for schedules, exact support/identity data,
both board sizes/colors, overlapping formations, mixed colors, actual shared state,
unrelated moves, affected-only removal, helper restoration and partial Clockwork
construction. It also checks the lantern pivot/size, every rock variant's aspect
ratio, source timing/metal policies and invalid schedule/extent handling.

All 464 recorded growth-model snapshots match byte for byte. All 256 native board
captures match exactly across four themes, both colors, 9×9/11×11 boards, 2×2,
2×3, 3×2 and 3×3 patterns, and four growth phases. These also exercise existing
chains, anemones, ponds, trees and links. Existing native Clockwork, Coral rotation,
Zen landmarks/ponds/trees, Vines and gallery suites pass, alongside headless theme,
shared-state and UI checks. Original artwork files remain untouched.

Step 8 subsequently consolidated the [Tier 3 connection interface](tier3-connections.md)
while retaining each theme's specialized behavior and historical state.
