# Step 6 — Coral ordinary sets

This document records the ordinary-tier migration checkpoint. Tier 2 has since
migrated through the [shared formation assembly](tier2-assembly.md).

Coral Tier 0/1 now use live shared sets. The approved appearance change removes
cores from straight cells, retaining their two arms. Isolated tiles and endpoints
keep the core. Bends, Ts and crosses keep the core plus respectively one, two or
four applicable junction pieces. The appearance version is now `2.2`; older
saved artwork PNGs remain readable and new saves have a distinct fingerprint.

The [canonical assembly correction](canonical-assembly.md) removes external arm
mask dependencies and shares the retained NE junction mask across directions.

## Live configuration

- [Tier 0](../../art/themes/coral_reef/sets/tier0.json): isolated color-specific core.
- [Tier 1](../../art/themes/coral_reef/sets/tier1.json): endpoint, branching center,
  vines, declared propagation values and explicitly unused run decoration.
- [`coral_sets.gd`](../../scripts/coral_sets.gd): loads both definitions, binds
  salmon/turquoise treatments and existing event uniforms, and supplies the
  project-owned reveal shader through the shared material registry.

Each part declares source texture variants, pivot, canvas size, orientation,
painter group, event band, animation duration/dependencies, reveal field semantics
and independent mask UV rotation. All four arm directions still use one canonical
`arm_n.png` image per treatment and one generated linear reveal field. Junction
artwork uses one canonical image per treatment and the retained NE mask. Both
artwork and field rotate together through the shared assembly.

Shared `PatternCellSets` selection now supports optional `requires_mask` bits
(N/E/S/W = 1/2/4/8). A part is selected only when all required same-color ports
exist. An omitted requirement is unconditional. This allows a branching composition
to share four junction definitions without drawing unsupported corners. The set
loader rejects fractional and out-of-range masks. This filtering also selects
ordinary arm parts; no Coral shape geometry is hardcoded into the shared selector.

The growth adapter reads ordinary metadata, dependencies, anchors and propagation
values from the live sets. Existing public timing constants remain compatibility
mirrors. The renderer uses shared variant binding, persistent sprites, materials
and reveal completion while retaining Coral's painter groups and ordinals.
Static generic composition displays original artwork without an unbound event
shader; live events supply private reveal materials and clocks.

## Lifecycle and boundaries

Extending an endpoint into a straight removes its core while retaining existing
arm nodes. Turning a straight into a branching cell, or restoring an endpoint,
requires a core again. If animated, that new core starts at time zero even though
the cell is already occupied; it is not mislabeled as settled old artwork. Helpers
using settled restoration show the appropriate completed composition immediately.

Ordinary tiny fingers stay omitted for phone readability. No run decoration asset,
spacing policy, shading correction or new artwork is introduced. Original PNGs,
masks and shader sources are untouched. `theme.json` now declares the same
canonical sources as the sets; it remains the source adapter for higher tiers
and ground, rather than the active ordinary contract.
Colonies, anemones, formation support, timing, feature order, audio, water, UI and
logical puzzle rules retain their existing behavior. Zen's inherited wave adapter
still produces the same Zen state. Export explicitly includes both JSON sets.

## Verification

`tests/test_coral_sets.gd` passes 1,365 headless checks and 1,369 native checks. It covers both treatments and all 16 masks, multipart port
requirements, source metadata, pivots, shader/mask rotations, declared timings,
persistent nodes, core removal/regrowth/restoration, mixed-color boundaries,
static composition, higher-tier ownership boundaries and export/version data.
Native checks additionally verify continuous alpha through both straight
orientations without replacement cores.

Native real-board comparisons cover both colors, all shapes and a straight-run
fixture at three growth phases. The original Tier 0/1 migration matched all 84 non-straight cell captures.
The later canonical correction intentionally changes rotated junction growth
contours; the native rotation suite now compares every direction to the canonical
NE field. Straight core suppression remains the approved finished-art change.
Across 580 model fixtures, all non-core events and state match; 16 duration changes
are exactly the extra time needed for newly required cores on existing cells.
This comparison explicitly accounts for those core lifecycle changes rather than
claiming complete byte identity. Existing Coral scenario, rotation, audio, shared
asset, Clockwork/Zen set and UI suites also pass.
