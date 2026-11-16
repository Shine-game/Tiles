# Step 6 — Vines ordinary sets

This document records the ordinary-tier migration checkpoint. Tier 2 has since
migrated through the [shared formation assembly](tier2-assembly.md).

Vines Tier 0/1 now use live shared sets and registered procedural part providers.
The approved appearance change removes holding/frond motifs from straights.
Isolated tiles, endpoints, bends, Ts and crosses retain the existing motif. The
connection curves, edge foliage and diffuse cell wash remain on straight paths.
The appearance revision is `1.0`; historical unversioned gallery artwork remains
readable and is not deduplicated against the new appearance.

## Live configuration and providers

- [Tier 0](../../art/themes/vines/sets/tier0.json): isolated holding motif and wash.
- [Tier 1](../../art/themes/vines/sets/tier1.json): shape roles, holding motif, wash,
  connection/foliage proportions and an explicitly unused run-decoration role.
- [`vines_sets.gd`](../../scripts/vines_sets.gd): shared set loading, topology-role
  selection, immediate drawing dispatch, center identities and construction events.
- [`vines_renderer.gd`](../../scripts/vines_renderer.gd): the existing ordinary
  procedural art, extracted from the board into named registered providers.

Both logical colors use the current palette's pigment/blossom functions. All five
palette pairs remain available; no colors are baked into a replacement sprite
pack. Set parameters describe frond reach, leaf dimensions, alpha, accents and
wash proportions. One canonical frond uses the shared assembly orientation for
all ports. Its original L/R/N/S painter order is preserved for alpha blending.

The common renderer now exposes `register_draw_part_provider(id, callback)` and
`draw_parts(parts, view, context)`. Callbacks receive the live part metadata and
cell/edge context synchronously inside the host's `_draw`. A batch validates
before invoking any provider. Unknown callbacks fail with diagnostics. Immediate
parts are not node factories: `ensure()` rejects that misuse rather than building
a second sprite tree. Set files contain registered IDs, not executable paths.

The board dispatches the Vines set provider and retains reusable curve/brush
primitives. Ordinary wash, edge and holding implementations have moved out of
`board_view.gd`; the legacy whole-theme Vines callback has been removed. Existing
flower and flower-link drawing stays in its current higher-tier hooks and painter
order. Labyrinth's separate procedural adapter was unchanged at this checkpoint and
has subsequently been removed with that theme.

## Construction and preserved behavior

Center records have stable `vines/center/color/y/x` identities in the shared
construction state, separately from the occupied cell/wash record. Extending an
endpoint into a straight removes its motif. Turning a straight into a bend or T
adds a new motif at time zero even though the cell was already occupied. Existing
motifs stay settled through unrelated moves; new cells use their existing arrival
time. The shared clock drives the original pop curve and gates placement until
new motifs finish. Settled Undo/Erase restoration shows the correct finished role.

Two-front edge growth, leaf spawn choices, persistent edge direction, ripple/star
phases and sound scheduling continue through `Growth` and its existing hooks.
No new run-length spacing rule was introduced. Existing per-edge leaves and
transient stars are part of the vine, not a reactivated optional decoration slot.
Flowers, higher-tier links, logical rules, masks, shading, surfaces and UI retain
their existing behavior. Export explicitly includes both live JSON sets.

## Verification

`test_vines_sets.gd` passes 500 headless checks and 512 native checks. It covers
all 16 masks, both colors and all five palettes, source
role selection, registered immediate drawing, atomic failure handling, component
identity/removal/regrowth, mixed-color boundaries, retained edge direction,
construction completion, helper restoration and export/gallery versioning.
Native checks additionally use the actual game and gallery in all five palettes,
including existing flowers and higher-tier links.

All 580 growth-model snapshots remain byte-identical. At three growth phases,
all 84 non-straight cell captures match the pre-migration Vines pixels. Straights
and the straight-run fixture are the intended appearance change. Sixteen native
full-board captures across the other four themes and both board sizes also match.
Existing growth, shared state, Labyrinth, UI, shared asset and theme-set suites
remain applicable. No separate preview interface or source-image edits were added.
